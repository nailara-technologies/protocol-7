#!/usr/bin/env python3
## build_dataset.py -- render the p7-idioms contrastive pair set into
## positive.txt / negative.txt [ one chat-template-formatted line per pair,
## newlines escaped as literal \n per cvector-generator's own convention ].
##
## pairs live in PAIRS below as ( id, user, positive, negative ). the system
## turn is minimal and identical across all pairs [ isolates the idiom trait,
## not a persona ]. run check_tokens.sh afterwards for the hazard-4
## length-matching pass.
##
## pass 2 [ 2026-09-08 ] : pass-1 token check showed 17 pairs over the 10%
## delta threshold, avg turn 47 tokens [ target 60-120 ] and a consistent
## negative-side-shorter sign skew. fixes : lengthened the short side of
## every imbalanced pair with trait-neutral content, extended short pairs
## toward pair-8 length, added pairs 43-46 [ rows ~1957 -> ~2500 ].

import sys

SYSTEM = "You are a protocol-7 developer."

PAIRS = [

## --- the 10 worked exemplars from the task file [ pairs 1-10 ] --- ##
## verbatim, except pair 8's negative side : lengthened [ trait-neutral     ##
## verbosity ] to fix a -26 token delta [ 28% ] found by check_tokens.sh.   ##
## pairs 1, 3, 6, 7, 10 stay short with small %-exceeding deltas by design  ##
## [ trait coverage -- the task file's own caveat on pairs 6 and 7 ], and   ##
## their delta signs are mixed, which largely cancels under --method mean   ##

( 1, "Write one line that logs a warning when a config module fails to load.",
"<[base.logs]>->( 0, '%s failed to load config', $module_name );",
"warn sprintf( '%s failed to load config', $module_name );" ),

( 2, "Call the helper module coding.helper.foo with the job id and keep the result.",
"my $result = <[coding.helper.foo]>->($job_id);",
"my $result = Coding::Helper::Foo::run($job_id);" ),

( 3, "Return true if the write succeeded, false otherwise.",
"return TRUE if $write_ok;\nreturn FALSE;",
"return 1 if $write_ok;\nreturn 0;" ),

( 4, "Read the thread count from config, default to 8 if unset.",
"my $threads = <inference.backend.cpu.threads> // 8;",
"my $threads = $config->{'inference'}{'threads'} // 8;" ),

( 5, "Add a comment above this line explaining it skips dotfiles.",
"## skip hidden files [ dotfiles ]\nnext if $file =~ /^\\./;",
"# Skip hidden files (dotfiles).\nnext if $file =~ /^\\./;" ),

( 6, "Show the p7c command to run a build with verbose output.",
"p7c coding.build :verbose:",
"p7c coding.build --verbose" ),

( 7, "Name a new helper module in the coding zenka for parsing timestamps.",
"coding.helper.parse_timestamp",
"Coding::Helper::ParseTimestamp" ),

( 8, "Schedule a retry of the job 5 seconds from now and return from the handler.",
"""## schedule the retry [ non-blocking, handler runs on the event loop ]
<[event.add_timer]>->(
    {   'after'   => 5,
        'handler' => qw| coding.handler.retry_job |,
        'data'    => { 'job_id' => $job_id },
    }
);

return { 'mode' => qw| deferred |, 'data' => 'retry scheduled' };""",
"""# Schedule the retry (blocking wait on the current thread).
use Time::HiRes qw(sleep);

sleep(5);
my $status = retry_job(
    $job_id,
    { attempts => 1 },
);
if ( !$status ) {
    warn "retry_job failed for job $job_id";
}

return { success => 1, message => 'Retry scheduled' };""" ),

( 9, "Explain how the coding zenka reaches a command on the httpd zenka.",
"routing goes through the cube zenka [ the message router ] -- the coding zenka sends httpd.status, cube looks the name up in its session table, forwards it, and hands back the reply hash [ mode and data ]. there is no direct socket between the two zenki.",
"Routing goes through the Cube agent (the message router). The Coding agent sends httpd.status, Cube looks the name up in its session table, forwards it, and returns the response object (with mode and data). There is no direct socket between the two agents." ),

( 10, "Write the return value for a command that got invalid arguments.",
"return { 'mode' => qw| false |, 'data' => 'invalid arguments' };",
"return { success => 0, error => 'Invalid arguments' };" ),

## --- expanded set [ pairs 11-46 ] : pair-8-shaped bodies, prose, config, ##
## --- commit-message and command shapes mixed in deliberately           -- ##

( 11, "Write a handler skeleton that logs a warning and returns a false-mode reply when the job id is missing.",
"""## missing job id : log and bail [ false-mode reply to the caller ]
unless ( defined $job_id and length $job_id ) {
    <[base.logs]>->( 0, '%s called without a job id', qw| coding.handler.run_job | );
    return { 'mode' => qw| false |, 'data' => 'missing job id' };
}""",
"""# Missing job id: log an error and return a failure response.
if ( !defined($job_id) || !length($job_id) ) {
    my $caller = 'coding.handler.run_job';
    warn sprintf( "%s called without a job id", $caller );
    return { success => 0, error => 'Missing job id' };
}""" ),

( 12, "Read the retry limit from config, default to 3, and clamp it to at most 9.",
"""my $retries = <coding.cfg.job_retry_limit> // 3;
$retries = 9 if $retries > 9;    ## clamp : a wedged backend must not retry forever
<[base.logs]>->( 2, 'retry limit : %d', $retries );""",
"""my $retries = $config->{'coding'}{'job_retry_limit'} // 3;
if ( $retries > 9 ) { $retries = 9; }    # Clamp: a wedged backend must not retry forever.
printf( STDERR "retry limit: %d\\n", $retries );""" ),

( 13, "Call coding.helper.format_size if it is loaded, skip quietly otherwise.",
"""## optional call : silent skip when the helper is not compiled in this zenka
my $size_str = <[base.code.call_optional]>->(
    qw| coding.helper.format_size |, $size_bytes
);
$size_str //= sprintf( '%d bytes', $size_bytes );    ## fallback when helper absent""",
"""# Optional call: skip quietly when the helper module is not loaded here.
my $size_str = Coding::Helper::FormatSize::format($size_bytes)
    if defined &Coding::Helper::FormatSize::format;
$size_str //= sprintf( "%d bytes", $size_bytes );    # fallback when helper absent""" ),

( 14, "Show the p7c command to rebuild the coding zenka modules as a dry run with verbose output, and say what the flags do.",
"""p7c coding.build-modules :dry-run: :verbose:

:dry-run: only reports what would be rebuilt [ no files touched ]; :verbose: turns on per-module build output. re-run without :dry-run: to apply.""",
"""p7c coding.build-modules --dry-run --verbose

--dry-run only reports what would be rebuilt (no files are touched); --verbose turns on per-module build output. Re-run without --dry-run to apply the build.""" ),

( 15, "Register an io watcher on the socket with coding.handler.socket_readable as the handler.",
"""my $watcher = <[event.add_io]>->(
    {   'fd'      => $socket,
        'handler' => qw| coding.handler.socket_readable |,
        'data'    => { 'backend' => $backend },
        'poll'    => qw| re |
    }
);""",
"""my $watcher = Event::IO->new(
    fd      => $socket,
    handler => \\&Coding::Handler::socket_readable,
    data    => { backend => $backend },
    poll    => 're',
);
$watcher->register();
$watchers{$backend} = $watcher;""" ),

( 16, "Explain why the codebase uses TRUE and FALSE instead of 1 and 0.",
"""TRUE and FALSE are named constants [ 5 and 0 underneath ], not literals -- the name carries the intent [ a truth value ], where a bare 1 reads as arithmetic. it also keeps return sites greppable : 'return TRUE' is unambiguous in a way 'return 1' never is.""",
"""TRUE and FALSE are simply constants (5 and 0 respectively) rather than literals. The name documents intent (a truth value), where a bare 1 looks like arithmetic. It also makes return sites greppable: "return TRUE" is unambiguous in a way "return 1" never is.""" ),

( 17, "Write the config lines enabling partial gpu offload with a minimum of 6 layers.",
"""## hybrid fallback : reduce -ngl instead of refusing the spawn outright ##
coding.cfg.partial_offload_enable = yes
coding.cfg.partial_offload_min_layers = 6  ## below this, fail outright [ not worth it ] ##""",
"""# Hybrid fallback: reduce the -ngl layer count instead of refusing the spawn outright.
partial_offload_enable = true
partial_offload_min_layers = 6  # Fail outright below this (partial offload is not worth it).""" ),

( 18, "Write the body of coding.helper.job_is_done that returns TRUE when the job state is 'done', FALSE otherwise.",
"""my $job_id = shift // return FALSE;
my $state  = <coding.jobs>->{$job_id}{'state'} // qw| unknown |;

return TRUE if $state eq qw| done |;
return FALSE;""",
"""my $job_id = shift or return 0;
my $state  = $jobs{$job_id}->{state} || 'unknown';

return 1 if $state eq 'done';
return 0;""" ),

( 19, "Add a comment block above this retry loop explaining it gives up after three attempts.",
"""## bounded retry : give up after 3 attempts [ a wedged backend must not  ##
## spin the event loop forever -- the caller re-queues on its own timer ] ##
while ( $attempts-- > 0 ) {""",
"""# Bounded retry: give up after 3 attempts (a wedged backend must not
# spin the event loop forever -- the caller re-queues on its own timer).
while ( $attempts-- > 0 ) {""" ),

( 20, "Write a log line at level 2 that reports the resolved model path, ellipsized to 60 characters.",
"""## log the resolved path [ ellipsized : full paths blow out the log line ]
my $path_display = <[base.parser.ellipse_center]>->( $model_path, 60 );
<[base.logs]>->( 2, ':. %s', $path_display );""",
"""# Log the resolved path (ellipsized: long full paths would blow out the log line).
my $display_path = substr( $model_path, 0, 60 ) . '...';
printf( STDERR "model path: %s\\n", $display_path );""" ),

( 21, "Write the reply hash for a successful command returning the generated file path.",
"""## mode true = the command ran [ caller reads the path back out of data ]
return { 'mode' => qw| true |, 'data' => { 'path' => $out_path } };""",
"""# Success response (the caller reads the path back out of the result hash).
my $reply = { success => 1, result => { path => $out_path, bytes => $size } };
return $reply;""" ),

( 22, "Explain how a zenka knows which modules it actually has loaded.",
"""module presence lives in <base.p7_mod.loaded> [ ground truth for this zenka ] -- check it with <[base.mod.exists]>->('ns'), never by comparing the zenka name or by writing exists $code{'literal.name'} inline [ the referenced-sub scanner flags those ].""",
"""Module presence is tracked in the base.p7_mod.loaded registry (the ground truth for this agent). Check it with base.mod.exists('ns'), never by comparing the agent name or by writing exists $code{'literal.name'} inline (the referenced-sub scanner flags those).""" ),

( 23, "Write a guard that calls v7.teardown only when the v7 namespace is actually compiled into this zenka.",
"""## presence check first [ never assume a namespace is compiled in ]
<[base.code.call_expected]>->(
    <[base.mod.exists]>->(qw| v7 |), qw| v7.teardown |
);
## call_expected : loud error when v7.teardown itself is missing""",
"""# Check first (never assume a namespace is compiled into this agent process).
if ( V7->can('teardown') ) {
    V7::teardown();
} else {
    warn sprintf( "V7 namespace not loaded, skipping teardown" );
}""" ),

( 24, "Write a commit message for a change that fixes a race where a child process group was not set before exec.",
"""coding: fix setpgid race with manual fork/exec

IPC::Open3 gives no hook between fork and exec, so setpgid always lost the race [ EACCES, confirmed live ]. fork manually and call POSIX::setpgid in the child before exec, with an exec-status pipe mirroring open3's own failure detection.""",
"""Fix process group race in spawn path

Replaced IPC::Open3 with a manual fork/exec so setpgid() can run in the child before exec (the old code always lost the race with EACCES). Adds an exec-status pipe to detect exec failures, matching Open3's own behavior. No behavior change beyond the ordering fix.""" ),

( 25, "Write the return statement for a handler that queued the request instead of answering now.",
"""## not an answer yet : the caller waits for the deferred reply [ timeout   ##
## handling stays on the caller side ]                                     ##
return { 'mode' => qw| deferred |, 'data' => 'request queued' };""",
"""# No answer yet: the caller waits for the async response (timeout handling
# stays on the caller side).
return { status => 'queued', async => 1, message => 'Request queued for later processing' };""" ),

( 26, "Write the line that stores the spawned server pid and binary into a timestamped pid file under the zenka state dir.",
"""## timestamped pid file [ the orphan scan later reads pid + binary back  ##
## out of it and matches them against /proc ]                            ##
<[file.write_timestamped]>->( "$zenka_dir/$pid_rel", "$pid $binary" );""",
"""# Timestamped pid file: the orphan scan later reads pid + binary back out
# of it and matches them against /proc.
write_file( "$zenka_dir/$pid_rel", { timestamp => time(), content => "$pid $binary" } );""" ),

( 27, "Write a bounded loop that regenerates a seed until it passes the harmony assertion, at most 57 attempts.",
"""## iterate until harmonically valid [ bounded ]
my $attempts = 57;
while ( $attempts-- and <[base.assert.harmony]>->($seed) == 0 ) {
    ( $seed = join( '', <[base.ntime]>->(13), $fortuna->int32 ) ) =~ s|\\.||g;
}""",
"""# Retry until the seed passes the harmony check (bounded: 57 attempts max).
my $attempts = 57;
while ( $attempts-- && !seed_is_harmonic($seed) ) {
    $seed = int( rand( 2**31 ) ) ^ time();
    $attempts == 0 and warn "harmony check still failing after 57 tries";
}""" ),

( 28, "Read the temperature from config with a fallback of 0.7 and append it to the server command list.",
"""my $temperature = <inference.model.temperature> // 0.7;
push @cmd, qw| --temp |, $temperature;    ## fixed flag, configured value
<[base.logs]>->( 2, ': temperature %s', $temperature );""",
"""my $temperature = $config->{'inference'}{'model'}{'temperature'} || 0.7;
push( @cmd, '--temp', $temperature );    # fixed flag, configured value
printf( STDERR "temperature: %s\\n", $temperature );""" ),

( 29, "Explain what the cube zenka does when it receives a message addressed to a session name it does not know.",
"""cube looks the name up in its session table, finds nothing, and hands back a false-mode reply [ mode false, data says unknown session ] -- it does not guess a route or broadcast. the sender zenka sees the false mode and decides itself whether to retry, fall back, or give up.""",
"""Cube looks the name up in its session table, finds nothing, and returns a failure response (success: 0, error: unknown session). It does not guess a route or broadcast. The sending agent sees the failure and decides itself whether to retry, fall back, or give up.""" ),

( 30, "Write a bounded reap loop that polls waitpid up to 30 times with a 0.1 second sleep between polls.",
"""## bounded reap poll, NOT a blocking waitpid [ a child stuck in D-state  ##
## would freeze this zenka's whole event loop ]                          ##
my $reap_attempts = 30;
while ( $reap_attempts-- > 0 ) {
    last if <[base.waitpid]>->($old_pid) > 0;
    select( undef, undef, undef, 0.1 );
}""",
"""# Bounded reap loop (a blocking waitpid could hang if the child gets
# stuck, so poll instead).
my $reap_attempts = 30;
while ( $reap_attempts-- > 0 ) {
    last if waitpid( $old_pid, POSIX::WNOHANG ) > 0;
    Time::HiRes::sleep(0.1);
}""" ),

( 31, "Append the flags to the server command list that enable the jinja chat engine and point it at the fixed template file.",
"""## jinja template engine [ the fixed template works around qwen3.5 template bugs ]
push @cmd, qw| --jinja |;
push @cmd, '--chat-template-file', $tmpl_file;""",
"""# Enable the jinja template engine (the fixed template works around the
# qwen3.5 template bugs).
push( @cmd, '--jinja' );
push( @cmd, '--chat-template-file', $tmpl_file );""" ),

( 32, "Write an unless-guard that logs and returns a false-mode reply when the configured server binary is not executable.",
"""unless ( -x $binary ) {
    <[base.logs]>->( 0, '[spawn] binary not executable: %s', $binary );
    return { 'mode' => qw| false |, 'data' => 'binary not executable' };
}""",
"""if ( !-x $binary ) {
    printf( STDERR "[spawn] ERROR: binary not executable: %s\\n", $binary );
    my $reply = { success => 0, error => 'Binary not executable' };
    return $reply;
}""" ),

( 33, "Write the line computing per-layer VRAM cost from total model size and layer count, with a comment noting it is a first-order approximation.",
"""## per-layer vram cost : file size / layer count [ first-order approx --  ##
## embedding and lm-head tensors aren't offloadable layers ]              ##
my $per_layer_mb = $model_size_mb / $layer_count;""",
"""# Per-layer VRAM cost = file size / layer count (first-order approximation:
# ignores the embedding and lm-head tensors, which are not offloadable layers).
my $per_layer_mb = $model_size_mb / $layer_count;""" ),

( 34, "Write the p7c command to rotate the auth-relay credential slot, forcing regeneration, and note when forcing is appropriate.",
"""p7c crypt.credential.rotate :slot:auth-relay :force:

:slot: picks which credential to rotate; :force: regenerates even while the current slot is still valid [ use after a suspected leak ].""",
"""p7c crypt.credential.rotate --slot auth-relay --force

--slot picks which credential to rotate; --force regenerates even while the current slot is still valid (use after a suspected leak).""" ),

( 35, "Write a config fragment setting the http stall timeout to 77 seconds, with a comment explaining when it fires.",
"""## stall timeout : fires on genuine silence [ no chunk for N seconds ],   ##
## independent of total elapsed time -- re-armed on every chunk            ##
coding.http-timeouts.stall = 77""",
"""# Stall timeout: fires on genuine silence (no chunk for N seconds),
# independent of total elapsed time; re-armed on every chunk.
coding.http-timeouts.stall = 77""" ),

( 36, "Explain in one paragraph why this project uses :flag: syntax instead of --long-flags in command arguments.",
""":keyword: marks functional intent at a glance [ readable in code, command strings, network messages and docs alike ], and any zenka in a routing chain can recognize and act on :flag: tokens without separate flag-parsing logic -- no ambiguity about whether something is a mode flag or a data value. --flag style is reserved for external tools.""",
"""The :keyword: syntax marks functional intent at a glance (readable in code, command strings, network messages and docs alike), and any agent in a routing chain can recognize and act on :flag: tokens without separate flag-parsing logic, and without ambiguity about whether a token is a mode flag or a data value. The --flag style is reserved for external tools.""" ),

( 37, "Write the metadata header lines for a module named coding.helper.parse_duration that parses human durations into seconds.",
"""## [:< ##

# name  = coding.helper.parse_duration
# descr = parse human durations [ '5m', '2h' ] into seconds
# param = $duration_str
# return = seconds | undef [ unparseable input ]""",
"""#!/usr/bin/perl
# Module: coding.helper.parse_duration
# Description: Parses human durations ('5m', '2h') into seconds.
# Params: $duration_str. Returns: seconds, or undef on unparseable input.""" ),

( 38, "Write a small block that kills a whole server process group given its pid, and logs what it did.",
"""## negative pid = kill the whole process group [ server + forked workers ]
kill( 'KILL', -$old_pid );
<[base.logs]>->( 1, '[spawn] killed old server group [pid:%d]', $old_pid );""",
"""# Negative pid = kill the whole process group (the server plus any of its
# forked worker children).
kill( 9, -$old_pid );
printf( "[spawn] killed old server group [pid:%d]\\n", $old_pid );""" ),

( 39, "Write the return value for a search command that completed and carries a list of matched file names.",
"""## mode true + data payload [ matches list under its own key ]
return { 'mode' => qw| true |, 'data' => { 'matches' => \\@files } };""",
"""# Success: return the list of matched files in the response payload.
my $reply = { success => 1, files => \\@files, count => scalar(\\@files) };
return $reply;""" ),

( 40, "Explain what 'mode' and 'data' mean in a protocol-7 command reply.",
"""every command reply is a hash with 'mode' and 'data' : mode says how the command ran [ true, false, deferred, .. ], data carries the payload [ or the error text when mode is false ]. callers branch on mode first and only touch data afterwards.""",
"""Every command response is a hash with 'mode' and 'data': mode reports how the command ran (true, false, deferred, etc.), and data carries the payload (or the error text when mode is false). Callers branch on mode first and only touch data afterwards.""" ),

( 41, "Write a block that reads a line-count threshold from config [ default 180 ] and logs a warning when a memory index file exceeds it.",
"""my $max_lines = <coding.cfg.memory_index_max_lines> // 180;
if ( $line_count > $max_lines ) {
    <[base.logs]>->( 0, '%s exceeds %d lines [ move detail to a topic file ]', $index_path, $max_lines );
}""",
"""my $max_lines = $config->{'coding'}{'memory_index_max_lines'} // 180;
if ( $line_count > $max_lines ) {
    warn sprintf( "%s exceeds %d lines (move detail to a topic file)", $index_path, $max_lines );
}""" ),

( 42, "Write a loop that skips undefined watcher entries and cancels the ones that are active.",
"""## skip slots never registered [ undef ] ; cancel the live ones ##
for my $watcher (@watchers) {
    next unless defined $watcher;
    $watcher->cancel() if $watcher->is_active();
}""",
"""# Skip slots never registered (undef); cancel the live ones.
foreach my $watcher (@watchers) {
    next if !defined($watcher);
    $watcher->cancel() if $watcher->is_active();
}""" ),

( 43, "Register a deferred timer that polls a spawned server's child processes, starting after 0.7 seconds.",
"""## backoff poll for forked worker children [ 0.7s x 1.6 each miss ]
<[event.add_timer]>->(
    {   'after'   => 0.7,
        'handler' => qw| coding.handler.register_server_children |,
        'data'    => {
            'backend'    => $backend,
            'parent_pid' => $pid,
            'interval'   => 0.7
        }
    }
);""",
"""# Poll for the forked worker children (initial delay 0.7 seconds).
my $timer;
$timer = AnyEvent->timer(
    after => 0.7,
    cb    => sub {
        Coding::Handler::register_server_children(
            { backend => $backend, parent_pid => $pid, interval => 0.7 }
        );
        scalar($timer);    # keep the timer referenced
    },
);""" ),

( 44, "Write the metadata hash stored for a freshly spawned inference server, with backend, port, pid, seed and model fields.",
"""<coding.inference_servers>->{$backend} = {
    'backend' => $backend,
    'port'    => $port,
    'pid'     => $pid,
    'seed'    => $seed,
    'model'   => $amos_id,    ## amos checksum [ may be overwritten by ready path ]
    'status'  => qw| starting |,
};""",
"""$inference_servers{$backend} = {
    backend => $backend,
    port    => $port,
    pid     => $pid,
    seed    => $seed,
    model   => $amos_id,    # amos checksum (may be overwritten by ready path)
    n_ctx   => $ctx_size,
    status  => 'starting',
    start_time => time(),
};""" ),

( 45, "Explain why a runtime-resolved value like a model path must not be written back into the zenka start file.",
"""reload re-parses the start file and re-applies every key [ a configured value is re-set, an absent one is cleared ] -- a runtime-resolved path written back into the file would be re-applied on every reload and clobber the freshly resolved one. resolution results live in runtime state [ <inference.model.path> ], never in cfg.""",
"""On reload the agent re-parses the start file and re-applies every key (a configured value is re-set, an absent one is cleared). A runtime-resolved path written back into the file would be re-applied on every reload and clobber the freshly resolved one. Resolution results live in runtime state, never in the config file.""" ),

( 46, "Write a guard that refuses a gpu spawn when a foreign llama process is already running, logging the offenders.",
"""## foreign llama process = vram collision risk [ refuse rather than oom ]
if (@foreign_procs) {
    <[base.logs]>->(
        0, '[spawn] foreign llama process detected, refusing gpu spawn : %s',
        join( '; ', @foreign_procs )
    );
    return { 'mode' => qw| false |, 'data' => 'gpu spawn blocked' };
}""",
"""# A foreign llama process means a VRAM collision risk (refuse, don't OOM).
if ( scalar(@foreign_procs) ) {
    printf( STDERR "[spawn] ERROR: foreign llama process, refusing gpu spawn: %s\\n",
        join( '; ', @foreign_procs ) );
    return { success => 0, error => 'GPU spawn blocked' };
}""" ),

]


def esc(s):
    ## cvector-generator runs string_process_escapes per line : escape ##
    ## backslash first, then newline/tab, so content survives intact   ##
    return (s.replace('\\', '\\\\')
             .replace('\n', '\\n')
             .replace('\t', '\\t'))


def render(user, reply):
    return ("<|im_start|>system\\n" + esc(SYSTEM)
            + "<|im_end|>\\n<|im_start|>user\\n" + esc(user)
            + "<|im_end|>\\n<|im_start|>assistant\\n" + esc(reply))


def main(outdir):
    pos_lines, neg_lines = [], []
    for pid, user, pos, neg in PAIRS:
        pos_lines.append(render(user, pos))
        neg_lines.append(render(user, neg))
        assert esc(user) and pos.strip() and neg.strip(), pid
        if pos == neg:
            print(f"pair {pid}: IDENTICAL SIDES [ hazard 6 ]", file=sys.stderr)
            sys.exit(1)
    with open(f"{outdir}/positive.txt", "w") as f:
        f.write("\n".join(pos_lines) + "\n")
    with open(f"{outdir}/negative.txt", "w") as f:
        f.write("\n".join(neg_lines) + "\n")
    print(f"wrote {len(PAIRS)} pairs to {outdir}/positive.txt + negative.txt")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")

#,,,.,,.,,,,,,,.,,,..,.,,,..,,..,,,,,,.,.,...,..,,...,...,..,,...,..,,.,.,...,
#LE2AU7OGXIS4FCX2UGTLA6EIN74WRW5FMEX7O4HQWFVKQ4LQK5TVDZTH63HL67FZSLARBHYMIPMS2
#\\\|PNLDBXGCXDSI26RPPXO6WL7ZXPDWARQIQKADR3NA2KUF3CU6XXO \ / AMOS7 \ YOURUM ::
#\[7]LRGCMTIT2ZLYSMGEYGTDBWDPK4XSU5VR4JNW352M5CMX764LSEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
