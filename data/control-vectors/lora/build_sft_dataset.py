#!/usr/bin/env python3
## build_sft_dataset.py -- expand the p7-idiom material into a gradient-  ##
## training SFT set [ order of hundreds ], same 8 idiom categories that    ##
## ../score.py measures.                                                   ##
##                                                                         ##
## output : dataset/sft.jsonl, one {system,user,think,content} per line.   ##
## the training script renders ChatML as :                                 ##
##   <|im_start|>system\nSYS<|im_end|>\n<|im_start|>user\nUSER<|im_end|>\n ##
##   <|im_start|>assistant\n<think>\nTHINK\n</think>\n\nCONTENT<|im_end|>  ##
## matching qwen3.5-fixed.jinja's generation prompt [ thinking enabled ].  ##
##                                                                         ##
## held-out discipline [ hazard 3 ] : the 3 canonical eval prompts from    ##
## ../run_gens.sh [ P_A/P_B/P_C ] and this task's second held-out set      ##
## [ P_D/P_E/P_F, see run_gens_lora.sh ] are NEVER emitted, neither as     ##
## user prompts nor as near-verbatim content. EXCLUDED_PHRASES below is    ##
## asserted against every example before write.                            ##
##                                                                         ##
## seeds : the 46 control-vector positives [ ../build_dataset.py PAIRS ]   ##
## are included as SFT examples [ high-quality in-style material, none of  ##
## them is a held-out prompt ], re-surfaced variants make up the rest.     ##
## deterministic : --seed fixes all randomness.                            ##

import json
import random
import re
import sys

SYSTEM = "You are a protocol-7 developer."

## --- held-out prompts [ must never appear in training data ] ------------##
P_A = ("Write a protocol-7 module body that reads a threshold from config "
       "with a default of 30 and logs a warning if a value exceeds it.")
P_B = ("Show the p7c command to list all loaded modules in the coding zenka "
       "with verbose output, and briefly say what the flag does.")
P_C = ("Explain in one paragraph why comments in this codebase are "
       "lowercase with square-bracket annotations.")
## second, never-before-used held-out set [ this task's addition ] :
P_D = ("Write a protocol-7 module coding.helper.enforce_quota that reads a "
       "per-job byte quota from config [ default 4096 ] and logs a warning "
       "when a job's usage exceeds it, returning FALSE in that case.")
P_E = ("Show the p7c command to rebuild the cube session table index as a "
       "dry run with forced locking, and explain what each flag does.")
P_F = ("Explain in one paragraph why handlers in this codebase return a "
       "mode/data reply hash instead of a bare status string.")

HELD_OUT = [P_A, P_B, P_C, P_D, P_E, P_F]

## distinctive fragments of the held-out prompts -- a training example     ##
## containing one of these in EITHER role is rejected [ near-paraphrase    ##
## guard, hazard 3's "close paraphrase" risk ]                             ##
EXCLUDED_PHRASES = [
    "default of 30", "threshold from config",
    "list all loaded modules", "loaded modules in the coding zenka",
    "lowercase with square-bracket annotations",
    "enforce_quota", "byte quota", "per-job byte",
    "session table index", "forced locking",
    "bare status string",
]

## ------------------------------------------------------------------ pools

ZENKAS = ["coding", "httpd", "cube", "nshell", "models", "web-browser",
          "fetch", "crypt", "event"]

HELPER_MODS = [
    "coding.helper.format_duration", "coding.helper.job_age",
    "coding.helper.sanitize_path", "coding.helper.parse_size",
    "coding.helper.queue_depth", "coding.helper.retry_count",
    "coding.helper.slots_free", "coding.helper.model_display_name",
    "coding.helper.elapsed", "coding.helper.is_ready",
    "coding.helper.vram_free_mb", "coding.helper.pid_alive",
    "coding.helper.read_json", "coding.helper.write_json",
    "coding.helper.task_label", "coding.helper.round_robin",
    "coding.helper.next_slot", "coding.helper.hash_reply",
    "coding.helper.trim_log", "coding.helper.utf8_clean",
    "base.parser.ellipse_center", "base.parser.split_flags",
    "base.ntime", "base.waitpid", "base.gen_id",
    "base.assert.harmony", "base.mod.exists",
    "base.code.call_optional", "base.code.call_expected",
    "file.write_timestamped", "event.add_timer", "event.add_io",
]

HANDLER_MODS = [
    "coding.handler.retry_job", "coding.handler.poll_server",
    "coding.handler.socket_readable", "coding.handler.queue_check",
    "coding.handler.reap_children", "coding.handler.flush_buffer",
    "coding.handler.reload_models", "coding.handler.ping_backend",
    "httpd.handler.request_done", "cube.handler.route_reply",
]

CFG_KEYS = [
    ("coding.cfg.job_retry_limit", "3"),
    ("coding.cfg.memory_index_max_lines", "180"),
    ("coding.http-timeouts.stall", "77"),
    ("inference.backend.cpu.threads", "8"),
    ("inference.model.temperature", "0.7"),
    ("inference.model.context_length", "32768"),
    ("coding.cfg.max_parallel_jobs", "4"),
    ("coding.cfg.log_level", "2"),
    ("coding.cfg.watchdog_interval", "13"),
    ("coding.cfg.queue_max_depth", "64"),
    ("coding.cfg.spawn_cooldown", "7"),
    ("httpd.cfg.listen_backlog", "32"),
    ("cube.cfg.route_cache_ttl", "60"),
    ("fetch.cfg.download_retries", "5"),
]

LOG_MSGS = [
    "'%s failed to load config'", "'%s called without a job id'",
    "'retry limit : %d'", "'[spawn] binary not executable: %s'",
    "'%s exceeds %d lines [ move detail to a topic file ]'",
    "'job %s finished with mode %s'", "'backend %s not ready'",
    "'%s: queue depth %d'", "'watcher cancelled for %s'",
    "'%s reloaded [ %d modules ]'",
]

VARS = ["$job_id", "$task_id", "$pid", "$backend", "$module_name",
        "$session_id", "$model_path", "$req_id", "$slot", "$worker"]

NOUNS = ["job", "task", "request", "worker", "session", "backend",
         "server", "watcher", "timer", "module"]

FLAGS = [":verbose:", ":dry-run:", ":force:", ":reload:", ":quiet:",
         ":stats:", ":reset:", ":follow:"]

CMDS = [
    ("coding.build-modules", "rebuild the coding zenka modules"),
    ("coding.model.reload", "reload the active model config"),
    ("httpd.vhost.add", "add a virtual host to the httpd zenka"),
    ("cube.session.list", "list active routing sessions"),
    ("crypt.credential.rotate", "rotate a credential slot"),
    ("models.adapter.repair", "repair a model adapter registration"),
    ("fetch.queue.flush", "flush pending download jobs"),
    ("nshell.term.reset", "reset a stuck nshell terminal"),
    ("coding.queue.pause", "pause the coding task queue"),
    ("event.watcher.prune", "prune dead io watchers"),
]

PROSE_TOPICS = [
    ("why deferred replies carry their own timeout handling on the caller side",
     "a deferred reply means the handler could not answer in-line [ the work continues on the event loop ]. the caller keeps the timeout because only the caller knows how long an answer is still useful -- the handler just promises a reply hash [ mode and data ] later, not a deadline."),
    ("how a zenka knows which modules it actually has loaded",
     "module presence lives in <base.p7_mod.loaded> [ ground truth for this zenka ] -- check it with <[base.mod.exists]>->('ns'), never by comparing the zenka name or by writing exists $code{'literal.name'} inline [ the referenced-sub scanner flags those ]."),
    ("what happens when cube receives a message for an unknown session name",
     "cube looks the name up in its session table, finds nothing, and hands back a false-mode reply [ mode false, data says unknown session ] -- it does not guess a route or broadcast. the sender zenka sees the false mode and decides itself whether to retry, fall back, or give up."),
    ("why TRUE and FALSE are used instead of 1 and 0",
     "TRUE and FALSE are named constants [ 5 and 0 underneath ], not literals -- the name carries the intent [ a truth value ], where a bare 1 reads as arithmetic. it also keeps return sites greppable : 'return TRUE' is unambiguous in a way 'return 1' never is."),
    ("why :flag: syntax is used instead of --long-flags",
     ":keyword: marks functional intent at a glance [ readable in code, command strings, network messages and docs alike ], and any zenka in a routing chain can recognize and act on :flag: tokens without separate flag-parsing logic -- no ambiguity about whether something is a mode flag or a data value. --flag style is reserved for external tools."),
    ("what mode and data mean in a command reply",
     "every command reply is a hash with 'mode' and 'data' : mode says how the command ran [ true, false, deferred, .. ], data carries the payload [ or the error text when mode is false ]. callers branch on mode first and only touch data afterwards."),
    ("why runtime-resolved values never get written back into the start file",
     "reload re-parses the start file and re-applies every key [ a configured value is re-set, an absent one is cleared ] -- a runtime-resolved path written back into the file would be re-applied on every reload and clobber the freshly resolved one. resolution results live in runtime state, never in cfg."),
    ("why presence checks go through base.mod.exists and not zenka names",
     "a zenka name says nothing about what is compiled into the process [ modules load per-zenka from the start file ]. <[base.mod.exists]>->('ns') reads <base.p7_mod.loaded> [ the actual loaded-module registry ], so the check answers the real question : is the code here, not who am i."),
    ("why the spawn path kills the whole process group and not just the pid",
     "the inference server forks worker children [ and may restart its own helpers ] -- killing only the parent pid leaves orphans holding the gpu. a negative pid to kill() takes the whole process group, and the orphan scan later matches pid + binary from the timestamped pid file against /proc."),
    ("how the coding zenka reaches a command on another zenka",
     "routing goes through the cube zenka [ the message router ] -- the coding zenka sends the command name, cube looks the target up in its session table, forwards it, and hands back the reply hash [ mode and data ]. there is no direct socket between the two zenki."),
]

## ------------------------------------------------------- think snippets

THINK_PLANS = [
    "the caller wants {what} -- keep it in p7 idiom : {idioms}. short answer, no wrapper prose.",
    "{what}. use {idioms} and stay lowercase in the comment. nothing else needed.",
    "this is a {shape} answer : {idioms}. keep the body tight and idiomatic.",
    "p7 form for {what} : {idioms}. resist the perl-standard-library reflex, call through <[module]>->() instead.",
]

IDIOM_PHRASES = {
    "invoke": "<[module]>->() invocation",
    "cfg": "bare <config.key> access",
    "bool": "TRUE/FALSE constants",
    "mode": "a mode/data reply hash",
    "flag": ":flag: syntax",
    "comment": "## lowercase comments with [ bracket ] annotations",
}


def think_for(what, idiom_keys, rng):
    idioms = " + ".join(IDIOM_PHRASES[k] for k in idiom_keys)
    t = rng.choice(THINK_PLANS)
    return t.format(what=what, idioms=idioms,
                    shape=rng.choice(["one-liner", "short-body", "long-body",
                                      "prose", "command"]))


## ------------------------------------------------------------ generators
## each gen_* returns ( user, think, content )

def gen_invoke_oneliner(rng):
    mod = rng.choice(HELPER_MODS)
    var = rng.choice(VARS)
    noun = rng.choice(NOUNS)
    user = rng.choice([
        f"Call the helper module {mod} with the {noun} id and keep the result.",
        f"Invoke {mod} on {var} and store what it returns.",
        f"Write one line that calls {mod} with {var}.",
    ])
    body = rng.choice([
        f"my $result = <[{mod}]>->({var});",
        f"my $result = <[{mod}]>->( {var} );",
    ])
    return user, think_for(f"a call to {mod}", ["invoke"], rng), body


def gen_optional_call(rng):
    mod = rng.choice([m for m in HELPER_MODS if m.startswith("coding.helper")])
    var = rng.choice(VARS)
    user = rng.choice([
        f"Call {mod} if it is loaded, skip quietly otherwise.",
        f"Use {mod} only when present in this zenka, no error otherwise.",
    ])
    content = (
        f"## optional call : silent skip when the helper is not compiled in this zenka\n"
        f"my $result = <[base.code.call_optional]>->(\n"
        f"    qw| {mod} |, {var}\n"
        f");"
    )
    return user, think_for(f"an optional call to {mod}",
                           ["invoke", "comment"], rng), content


def gen_cfgaccess(rng):
    key, default = rng.choice(CFG_KEYS)
    varname = key.split(".")[-1].replace("-", "_")
    user = rng.choice([
        f"Read {key} from config, default to {default} if unset.",
        f"Write the line that reads {key} with a fallback of {default}.",
        f"Get the configured {varname.replace('_', ' ')} [ default {default} ].",
    ])
    content = f"my ${varname} = <{key}> // {default};"
    return user, think_for(f"a config read of <{key}>", ["cfg"], rng), content


def gen_cfg_clamp_log(rng):
    key, default = rng.choice(CFG_KEYS)
    varname = key.split(".")[-1].replace("-", "_")
    cap = int(default) * 3 if default.isdigit() else 9
    user = (f"Read {key} from config [ default {default} ], clamp it to at "
            f"most {cap}, and log the value at level 2.")
    content = (
        f"my ${varname} = <{key}> // {default};\n"
        f"${varname} = {cap} if ${varname} > {cap};"
        f"    ## clamp : configured values past {cap} wedge the backend\n"
        f"<[base.logs]>->( 2, '{varname.replace('_', ' ')} : %s', ${varname} );"
    )
    return user, think_for(f"a clamped config read of <{key}>",
                           ["cfg", "invoke", "comment"], rng), content


def gen_truefalse(rng):
    noun = rng.choice(NOUNS)
    state = rng.choice(["done", "ready", "active", "paused", "stale"])
    mod = f"coding.helper.{noun}_is_{state}"
    user = rng.choice([
        f"Write the body of {mod} that returns TRUE when the {noun} state "
        f"is '{state}', FALSE otherwise.",
        f"Write a predicate {mod} [ TRUE iff state eq '{state}' ].",
    ])
    content = (
        f"my ${noun}_id = shift // return FALSE;\n"
        f"my $state = <coding.{noun}s>->{{${noun}_id}}{{'state'}} // qw| unknown |;\n"
        f"\n"
        f"return TRUE if $state eq qw| {state} |;\n"
        f"return FALSE;"
    )
    return user, think_for(f"the {mod} predicate", ["bool", "cfg"], rng), content


def gen_bool_return(rng):
    cond = rng.choice(["$write_ok", "$sent", "$found", "$changed",
                       "$reloaded", "$flushed"])
    user = rng.choice([
        f"Return true if {cond} is set, false otherwise.",
        f"Write the two return lines branching on {cond}.",
        f"Branch on {cond} : TRUE when set, FALSE otherwise.",
    ])
    content = f"return TRUE if {cond};\nreturn FALSE;"
    return user, think_for(f"a boolean return on {cond}", ["bool"], rng), content


def gen_guard_falsemode(rng):
    var = rng.choice(VARS)
    caller = rng.choice(HANDLER_MODS)
    what = var.lstrip("$").replace("_", " ")
    user = rng.choice([
        f"Write a handler skeleton that logs a warning and returns a "
        f"false-mode reply when the {what} is missing.",
        f"Guard the handler : no {what} -> log at level 0 and bail with a "
        f"false-mode reply.",
        f"In {caller}, refuse to run without a {what} [ log + false-mode "
        f"reply ].",
    ])
    content = (
        f"## missing {what} : log and bail [ false-mode reply to the caller ]\n"
        f"unless ( defined {var} and length {var} ) {{\n"
        f"    <[base.logs]>->( 0, '%s called without a {what}', qw| {caller} | );\n"
        f"    return {{ 'mode' => qw| false |, 'data' => 'missing {what}' }};\n"
        f"}}"
    )
    return user, think_for(f"a missing-{what} guard",
                           ["invoke", "mode", "comment"], rng), content


def gen_modedata_reply(rng):
    mode, payload = rng.choice([
        ("true", "{ 'path' => $out_path }"),
        ("true", "{ 'matches' => \\@files }"),
        ("true", "{ 'pid' => $pid, 'port' => $port }"),
        ("false", "'invalid arguments'"),
        ("false", "'binary not executable'"),
        ("false", "'unknown session'"),
        ("deferred", "'request queued'"),
        ("deferred", "'retry scheduled'"),
    ])
    desc = {
        "true": "a successful command",
        "false": "a command that failed",
        "deferred": "a handler that queued the request instead of answering now",
    }[mode]
    user = rng.choice([
        f"Write the reply hash for {desc} carrying {payload}.",
        f"Write the return value for {desc} [ payload {payload} ].",
        f"Show the return statement for {desc} with {payload} as payload.",
    ])
    note = rng.choice([
        f"## mode {mode} = the command ran [ caller reads the payload out of data ]"
        if mode == "true" else
        f"## mode {mode} [ data carries the reason ]"
        if mode == "false" else
        f"## not an answer yet : caller waits for the deferred reply",
        f"## mode {mode} + data payload",
    ])
    content = f"{note}\nreturn {{ 'mode' => qw| {mode} |, 'data' => {payload} }};"
    return user, think_for(f"a {mode}-mode reply", ["mode"], rng), content


def gen_event_timer(rng):
    handler = rng.choice(HANDLER_MODS)
    delay = rng.choice(["0.7", "1.3", "5", "13", "30"])
    var = rng.choice(VARS)
    user = rng.choice([
        f"Register a deferred timer that runs {handler} after {delay} seconds.",
        f"Schedule {handler} {delay} seconds from now, non-blocking.",
    ])
    content = (
        f"## deferred timer [ non-blocking, handler runs on the event loop ]\n"
        f"<[event.add_timer]>->(\n"
        f"    {{   'after'   => {delay},\n"
        f"        'handler' => qw| {handler} |,\n"
        f"        'data'    => {{ 'id' => {var} }},\n"
        f"    }}\n"
        f");"
    )
    return user, think_for(f"an event timer for {handler}",
                           ["invoke", "comment"], rng), content


def gen_io_watcher(rng):
    handler = rng.choice(HANDLER_MODS)
    var = rng.choice(["$socket", "$fh", "$listen_fd", "$pipe"])
    user = (f"Register an io watcher on {var} with {handler} as the "
            f"callback, readable events only.")
    content = (
        f"## io watcher [ readable edge only, stays on the event loop ]\n"
        f"my $watcher = <[event.add_io]>->(\n"
        f"    {{   'fd'      => {var},\n"
        f"        'handler' => qw| {handler} |,\n"
        f"        'data'    => {{ 'backend' => $backend }},\n"
        f"        'poll'    => qw| re |\n"
        f"    }}\n"
        f");"
    )
    return user, think_for(f"an io watcher via event.add_io",
                           ["invoke", "comment"], rng), content

def gen_comment(rng):
    topic, code = rng.choice([
        ("it skips dotfiles", "next if $file =~ /^\\./;"),
        ("it skips undefined entries", "next unless defined $watcher;"),
        ("it gives up after three attempts", "while ( $attempts-- > 0 ) {"),
        ("it kills the whole process group", "kill( 'KILL', -$old_pid );"),
        ("it clamps the value to the configured ceiling",
         "$retries = 9 if $retries > 9;"),
        ("it re-arms the stall timer on every chunk",
         "$stall_timer->again();"),
    ])
    note = rng.choice(["[ dotfiles ]", "[ undef slots get skipped ]",
                       "[ bounded on purpose ]", ""])
    user = rng.choice([
        f"Add a comment above this line explaining {topic}.\n{code}",
        f"Write the comment line for : {code} [ explains {topic} ]",
        f"Comment this in codebase style [ {topic} ] :\n{code}",
    ])
    comment = f"## {topic} {note}".rstrip()
    content = f"{comment}\n{code}"
    return user, think_for("a comment line", ["comment"], rng), content


def gen_colonflag_cmd(rng):
    cmd, desc = rng.choice(CMDS)
    n_flags = rng.choice([1, 1, 2])
    flags = rng.sample(FLAGS, n_flags)
    flag_str = " ".join(flags)
    user = rng.choice([
        f"Show the p7c command to {desc} with {' and '.join(f.strip(':') for f in flags)} output, and say what the flag{'s' if n_flags > 1 else ''} do{'es' if n_flags == 1 else ''}.",
        f"Write the p7c invocation to {desc} [ {flag_str} ].",
    ])
    explains = "; ".join(
        f"{f} {FLAG_MEANINGS.get(f, 'changes the run mode')}" for f in flags)
    content = (f"p7c {cmd} {flag_str}\n\n{explains}. "
               f"re-run without the flags to apply the default behavior.")
    return user, think_for(f"the p7c {cmd} invocation", ["flag"], rng), content


FLAG_MEANINGS = {
    ":verbose:": "turns on per-step output",
    ":dry-run:": "only reports what would happen [ nothing touched ]",
    ":force:": "overrides the safety check [ use after a suspected fault ]",
    ":reload:": "re-reads the config before acting",
    ":quiet:": "suppresses progress output",
    ":stats:": "prints counters at the end",
    ":reset:": "clears cached state first",
    ":follow:": "keeps streaming updates until interrupted",
}


def gen_prose(rng):
    topic, text = rng.choice(PARSE_TOPICS)
    user = rng.choice([
        f"Explain {topic}.",
        f"In one paragraph, explain {topic}.",
        f"Briefly : {topic}?",
    ])
    return user, think_for(f"an explanation of {topic}",
                           ["comment"], rng), text


def gen_config_fragment(rng):
    key, default = rng.choice(CFG_KEYS)
    comment = rng.choice([
        "## fires on genuine silence [ no chunk for N seconds ] ##",
        "## below this, fail outright [ not worth it ] ##",
        "## bounded on purpose [ a wedged backend must not spin forever ] ##",
        "## re-armed on every change ##",
    ])
    user = rng.choice([
        f"Write the config line setting {key} to {default}, with a comment.",
        f"Write a config fragment for {key} = {default}.",
    ])
    content = f"{comment}\n{key} = {default}"
    return user, think_for(f"a config fragment for {key}",
                           ["comment"], rng), content


def gen_commit(rng):
    subj, body = rng.choice([
        ("coding: fix setpgid race with manual fork/exec",
         "IPC::Open3 gives no hook between fork and exec, so setpgid always lost the race [ EACCES, confirmed live ]. fork manually and call POSIX::setpgid in the child before exec, with an exec-status pipe mirroring open3's own failure detection."),
        ("coding: cap context at the timeout-recovery ceiling",
         "a recovered spawn was re-requesting the full context [ oom on a 12g card ]. cap ctx to the recovery ceiling and log the reduction [ level 1, spawn buffer ]."),
        ("httpd: re-arm the stall timer on every chunk",
         "the stall timeout was measuring total elapsed time [ long legitimate streams got cut ]. re-arm on every received chunk instead -- it now fires on genuine silence only."),
        ("cube: refuse routes to sessions marked draining",
         "a draining zenka kept receiving new tasks during handover [ race with the twin's startup ]. check the draining flag in the route lookup and hand back a false-mode reply instead."),
    ])
    user = rng.choice([
        f"Write a commit message for this change : {subj.lower()}",
        f"Write the commit message : {subj.lower()}",
        f"Draft the commit message for : {body[:60]}...",
    ])
    content = f"{subj}\n\n{body}"
    return user, think_for("a commit message", ["comment"], rng), content


def gen_header(rng):
    mod = rng.choice([m for m in HELPER_MODS if "helper" in m])
    descr = mod.split(".")[-1].replace("_", " ")
    param = rng.choice(VARS)
    ret = rng.choice(["result | undef [ unparseable input ]",
                      "TRUE | FALSE", "reply hash [ mode, data ]",
                      "formatted string"])
    user = rng.choice([
        f"Write the metadata header lines for a module named {mod}.",
        f"Write the p7 module header for {mod} [ {descr} ].",
    ])
    content = (f"## [:< ##\n\n# name  = {mod}\n# descr = {descr}\n"
               f"# param = {param}\n# return = {ret}")
    return user, think_for(f"the module header for {mod}",
                           ["comment"], rng), content


def gen_module_body(rng):
    ## long-form mixed body : cfg read + guard + invoke + bool/modedata ##
    key, default = rng.choice(CFG_KEYS)
    varname = key.split(".")[-1].replace("-", "_")
    handler = rng.choice(HANDLER_MODS)
    noun = rng.choice(NOUNS)
    var = rng.choice(VARS)
    helper = rng.choice([m for m in HELPER_MODS if "helper" in m])
    user = rng.choice([
        f"Write a protocol-7 handler body for {handler} : read {key} "
        f"[ default {default} ], bail with a false-mode reply when the "
        f"{noun} id is missing, and run the {noun} through {helper}.",
        f"Write the {handler} body -- config read with fallback, a "
        f"missing-arg guard, then the actual call.",
    ])
    content = (
        f"my ${varname} = <{key}> // {default};\n"
        f"\n"
        f"## missing {noun} id : log and bail [ false-mode reply ]\n"
        f"unless ( defined {var} and length {var} ) {{\n"
        f"    <[base.logs]>->( 0, '%s called without a {noun} id', qw| {handler} | );\n"
        f"    return {{ 'mode' => qw| false |, 'data' => 'missing {noun} id' }};\n"
        f"}}\n"
        f"\n"
        f"## hand the {noun} to the helper [ it owns the retry logic ]\n"
        f"my $result = <[{helper}]>->( {var}, ${varname} );\n"
        f"\n"
        f"return TRUE if $result;\n"
        f"return FALSE;"
    )
    return user, think_for(f"the {handler} body",
                           ["cfg", "invoke", "mode", "bool", "comment"],
                           rng), content


GENERATORS = [
    (gen_invoke_oneliner, 34),
    (gen_optional_call, 22),
    (gen_cfgaccess, 30),
    (gen_cfg_clamp_log, 26),
    (gen_truefalse, 26),
    (gen_bool_return, 16),
    (gen_guard_falsemode, 26),
    (gen_modedata_reply, 30),
    (gen_event_timer, 20),
    (gen_io_watcher, 14),
    (gen_comment, 22),
    (gen_colonflag_cmd, 26),
    (gen_prose, 20),
    (gen_config_fragment, 16),
    (gen_commit, 8),
    (gen_header, 12),
    (gen_module_body, 32),
]

PARSE_TOPICS = PROSE_TOPICS  ## alias, keeps gen_prose readable

## ------------------------------------------------------------------ main

def load_seed_positives():
    ## the 46 control-vector positives as ( user, positive ) -- they are  ##
    ## already in-style training material. EXCLUDED : pair 41 [ 'reads a  ##
    ## line-count threshold from config and logs a warning when exceeded' ##
    ## is the same request shape as canonical held-out P_A -- hazard 3's  ##
    ## close-paraphrase risk, dropped to keep validation meaningful ]     ##
    sys.path.insert(0, "/data/projects/protocol-7/data/control-vectors")
    import importlib
    bd = importlib.import_module("build_dataset")
    return [(user, pos) for _pid, user, pos, _neg in bd.PAIRS
            if _pid != 41]


def violates_exclusion(text):
    low = text.lower()
    for phrase in EXCLUDED_PHRASES:
        if phrase.lower() in low:
            return phrase
    return None


def main(outdir, seed=1337):
    rng = random.Random(seed)
    examples = []
    seen_users = set()

    ## 1. seed positives [ think span synthesized, content verbatim ]
    for user, pos in load_seed_positives():
        think = think_for(user[:60].lower().rstrip("."),
                          ["invoke", "comment"], rng)
        examples.append({"system": SYSTEM, "user": user,
                         "think": think, "content": pos})
        seen_users.add(user)

    ## 2. generated variants
    for gen, count in GENERATORS:
        made = 0
        attempts = 0
        while made < count and attempts < count * 40:
            attempts += 1
            user, think, content = gen(rng)
            if user in seen_users:
                continue
            seen_users.add(user)
            examples.append({"system": SYSTEM, "user": user,
                             "think": think, "content": content})
            made += 1
        if made < count:
            print(f"WARNING: {gen.__name__} only made {made}/{count} unique",
                  file=sys.stderr)

    rng.shuffle(examples)

    ## 3. held-out exclusion asserts [ hazard 3 ]
    held_norm = {re.sub(r"\s+", " ", h.strip().lower()) for h in HELD_OUT}
    for ex in examples:
        unorm = re.sub(r"\s+", " ", ex["user"].strip().lower())
        assert unorm not in held_norm, f"HELD-OUT PROMPT LEAKED: {ex['user']}"
        for field in ("user", "content"):
            bad = violates_exclusion(ex[field])
            assert not bad, f"excluded phrase '{bad}' in: {ex['user']}"

    import os
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(outdir, "sft.jsonl")
    with open(path, "w") as f:
        for ex in examples:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    ## 4. rubric coverage stats [ reuse the fixed rubric, unchanged ]
    sys.path.insert(0, "/data/projects/protocol-7/data/control-vectors")
    import score as score_mod
    tot = {}
    chars = 0
    for ex in examples:
        s, _a = score_mod.score_text(ex["content"])
        chars += len(ex["content"])
        for k, v in s.items():
            tot[k] = tot.get(k, 0) + v
    print(f"wrote {len(examples)} examples -> {path}")
    print(f"content chars total {chars} [ avg {chars // len(examples)} ]")
    print("rubric category hits over the whole set :",
          ", ".join(f"{k}={v}" for k, v in sorted(tot.items())))
    for k in ("invoke", "cfgaccess", "truefalse", "modedata"):
        assert tot.get(k, 0) >= 60, f"structural category {k} under-covered"


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "dataset"
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1337
    main(out, seed)

#,,,,,,,,,.,.,.,.,..,,,..,,..,,,.,,,.,...,.,,,..,,...,...,,,,,.,.,,..,.,,,.,.,
#C33NMNFFXUWSG53GIXMVH5NT77WXFSORYLE5V5G222KAYD2ECEP67AEM7QIM6DLJWOQRSNMS53HKE
#\\\|J5EZ6ATP7ITJCE5NIA6NWVXTA2KDOQHTQZM2PEA7D3I6E5DAO2L \ / AMOS7 \ YOURUM ::
#\[7]7Z2PVPYUBCSEHLU377PLN44SXCZFXS2F3KFXCENY2AVNZ5KMS2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
