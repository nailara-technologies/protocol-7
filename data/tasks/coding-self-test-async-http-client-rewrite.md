## task: convert coding self-test from the blocking HTTP client to the async streaming client

### goal

the coding zenka's model self-test cycle (`coding.self_test.run` /
`coding.self_test.evaluate`) currently makes its inference calls through
`coding.tools.http_inference_client` — a **blocking** `LWP::UserAgent->post`
with `stream: false`. every such call freezes the coding zenka's entire
single-threaded event loop for the duration of the request (up to the 90s
timeout, twice per prompt with the retry, plus up to two more for tier1
reformat).

replace that transport with the project's existing **non-blocking** streaming
path (`coding.async.http_client` + `coding.handler.http_io`), driven by a
timer-based state machine in the same style as the one already used inside
this very subsystem (`coding.self_test.handler.poll_switch`).

this is a **transport** change only. the self-test's prompts, hints, guards
and timeout value are settled — see "what NOT to change" below.

---

### background

**why this matters.** on 2026-07-31 an *unbounded* blocking `waitpid` in
`coding.spawn_inference_server` wedged the whole zenka: unresponsive to
`coding.heart`, session still connected but nothing processed, and **no v7
restart recovery** — heartbeat/restart is confirmed not enabled for on-demand
zenki yet. it had to be restarted by hand. the self-test's blocking HTTP
client is the same category of risk: bounded (90s) rather than unbounded, and
so not yet proven to have caused a freeze, but on the same code path and
becoming an active supervisor-conflict hazard the moment on-demand heartbeat
lands.

**the proven-good pattern already exists.** real task inference uses
`coding.async.request` → `coding.async.http_client` →
`coding.handler.http_io` → `coding.handler.http_io_parse_line` →
`on_chunk` callback. it uses `stream: true` SSE, non-blocking sockets via
`event.add_io`, a prompt-size-scaled *data-start* timeout, a cold-start grace
window, and — importantly — a **stall/idle timeout** (`coding.http-timeouts.stall`,
default 77s, re-armed on every chunk in `coding.handler.http_io:70-80`)
instead of a flat total-duration ceiling.

**the open empirical puzzle.** self-test's `http_500` failures do NOT
correlate with total duration. one run passed cleanly at `ttft=69.27s`
against a client whose whole budget was ~90s; another still 500'd well past
its 120s timeout in the same session. raising the timeout (30→60→90→120→240,
each tested live) never eliminated it. the leading hypothesis, never yet
tested: `stream: false` means one long silent read, which may be hitting an
**idle/silence cutoff** (server-side or network-side) that streaming avoids
by keeping bytes trickling in — independent of total duration. this is why
**step 1 below is a cheap isolated experiment, not the rewrite.**

full session history: `data/ai-mem/claude/topic-coding-self-test-http500-and-hint-fixes-2026-07-31.md`.
read it first. everything in it is settled background — do not re-litigate
any of it.

---

### where to implement

primary:

| file | current role | change |
|---|---|---|
| `modules/coding.tools.http_inference_client` | blocking client | step 1 only: `stream` flag experiment |
| `modules/coding.self_test.run` | straight-line loop over 2 prompts | → timer-driven state machine |
| `modules/coding.self_test.evaluate` | synchronous tier1 reformat, up to 2 attempts | → continuation-driven |
| `modules/coding.self_test.handler.poll_switch` | switch→test→restore state machine | new `testing` phase |
| `modules/coding.handler.monitor_inference_startup` | auto-trigger + cat-fail/seed-retry logic | → completion callback |
| `modules/coding.self_test.cmd.self-test-run` | manual trigger, direct-return reply | → `mode => deferred` + callback |

new modules (suggested names):

- `coding.self_test.handler.poll_probe` — the per-self-test-run state machine
  timer handler (the analogue of `poll_switch`)
- `coding.self_test.async_probe` — issues one non-blocking inference request
  with a self-test-owned callback set, accumulates SSE, invokes a completion
  continuation

**explicitly out of scope**: `coding.self_test.follow_up` and
`coding.self_test.tier2_judge` also call the blocking client. leave them
alone. they run *after* the test completes, on the disposition/judgment path,
not inside the server-readiness path that the freeze risk lives on. converting
them is a separate, lower-value task.

---

### implementation spec

#### step 1 — verify the streaming-vs-duration hypothesis FIRST [ cheap, isolated ]

do this before touching anything else. it may explain the `http_500`s on its
own, in which case the rest of this task changes character entirely.

in `coding.tools.http_inference_client` (line 37, `stream => JSON::PP::false`),
switch the request body to `stream => JSON::PP::true` and accumulate the SSE
response **synchronously** — still blocking LWP, no event-loop conversion.
`LWP::UserAgent` supports a content callback:

**critical — this step removes the only bound that currently exists, unless
you add one.** `LWP::UserAgent`'s `timeout` is an **inactivity** timeout, not
a total-duration one: the request is aborted if no activity is observed on the
connection for `timeout` seconds. that is exactly *why* `stream: false` trips
at 90s today — one long silent generation is one long inactivity gap. flip to
`stream: true` and bytes arrive continuously, so LWP's timeout **never
fires**, converting a bounded 90s block into an *unbounded* one — on a live
zenka with no heartbeat recovery. that is the precise failure class of the
`waitpid` incident this whole task exists to prevent.

so the deadline must be enforced by hand, inside the content callback.
returning from the callback does **not** abort the transfer — you must `die`
inside it. the existing `eval` at `coding.tools.http_inference_client:46-95`
already catches that and maps it to `request_failed`, so the return contract
is unchanged:

```perl
## step-1 experiment only : still blocking, but keeps bytes flowing so a  ##
## silence-based cutoff can't trip. accumulate deltas exactly like        ##
## coding.async.chunk_handler does [ content / reasoning_content /        ##
## inline <think> ] and synthesize the same return shape as before        ##
my $content   = '';
my $reasoning = '';
my $finish_reason = '';

## LWP's own timeout is an INACTIVITY timeout - streaming keeps the       ##
## connection active, so it can never fire. enforce a real wall-clock     ##
## ceiling here or this call becomes unbounded [ see note above ]         ##
my $deadline = <[base.time]>->(9) + $timeout;

my $response = $ua->post(
    $completion_url,
    'Content-Type' => 'application/json',
    Content        => $json_body,
    ':content_cb'  => sub {
        my ( $chunk, $resp, $proto ) = @_;
        ## die - NOT return - is what actually aborts the transfer. the   ##
        ## enclosing eval maps it to 'request_failed', same as today      ##
        die 'self_test_stream_deadline'
            if <[base.time]>->(9) > $deadline;
        ## split on lines, strip 'data: ' prefix, skip [DONE], decode json ##
        ## then accumulate delta.content / delta.reasoning_content         ##
    },
);
```

keep the existing `<think>` stripping and `finish_reason` capture — the return
contract (`mode`/`data`/`reasoning`/`finish_reason`) must be byte-identical to
today's, so no caller changes.

**decision gate — record the outcome before proceeding:**

- **500s stop** → the silence-cutoff hypothesis is confirmed. steps 2-6
  become a *hygiene refactor* with no urgency; do them deliberately, one at a
  time, or defer them entirely and close this task with the finding recorded.
- **500s persist** → duration/idle is not the cause. the async conversion is
  then justified purely on the event-loop-freeze risk, not on fixing the 500s.
  proceed to step 2, and say so plainly in the commit message so nobody later
  believes the rewrite was a 500 fix.

do not skip this gate. the failure mode this section exists to prevent is
treating step 1 as a warm-up and doing the rewrite regardless.

---

#### step 2 — the task-queue bypass decision [ settled, do not re-open ]

**call `coding.async.http_client` directly with a self-test-owned callback
set. do NOT route through `coding.async.request`.**

reasoning, each point verifiable in the code:

1. `coding.async.request:17-19` does
   `my $task = <coding.task.queue>->{$task_id}; return { success => FALSE,
   error => "task not found" } unless defined $task;` — it **hard-fails before
   it ever reaches the HTTP call** for anything that isn't a real queued task.
   "reuse it fully" would mean fabricating a fake task-queue entry plus
   `async.task_state` init plus a state-machine lifecycle. that is strictly
   *more* work than bypassing, not less.
2. `coding.async.chunk_handler` is unusable for a probe: it does
   `<coding.task.queue>->{$task_id}` lookups (lines 169, 292), drives
   `coding.async.state_machine` transitions, re-dispatches rounds via
   `coding.async.send_request`, and parses tool calls. a calibration probe has
   none of that. self-test needs its **own** minimal accumulator instead — a
   ~30-line delta accumulator mirroring `chunk_handler:26-105` (content,
   `reasoning_content`, inline `<think>` extraction, `finish_reason`) and
   nothing else.
3. `coding.async.http_client` itself is fully generic: `($url, $body,
   $callbacks)`, no task coupling. the only task-shaped thing it reads is
   `$callbacks->{'backend'}` (for cold-start grace) and
   `$callbacks->{'task_id'}` (stored on `$state`).
4. passing `task_id => ''` makes the shared downstream handlers degrade to
   safe no-ops rather than misbehaving:
   - `coding.abort.check_stream:11-12` — `return undef unless length $task_id`
   - `coding.handler.http_timeout:32-36` — `length($task_id) ? state_manager
     get : undef`, so the soft-ceiling/`round_soft_restart` branch is skipped
     and it falls through to plain `on_error`
   - `coding.handler.http_stall_timeout` / `http_data_start_timeout` — both
     only call `$callbacks->{'on_error'}` and `http_cleanup`

so: `http_client` yes, `request`/`chunk_handler`/`callback.http_*` no.

**backend lock — real hazard, handle explicitly.** `coding.async.backend_acquire`
and `backend_release` are pure lock primitives over `<coding.state.backend>`,
independent of the task queue, so they *look* safe to reuse with a pseudo-id.
they are not, on one path: if the lock is held, `backend_acquire:32-38` pushes
the pseudo-id onto `$bs->{'queue'}`, and later `backend_release:28-36` shifts
it off and calls `<[coding.async.send_request]>->($pseudo_id)` on an id with no
task and no state — self-test corrupting the real-task path.

**recommended remedy** (smaller, no splice-ordering subtlety): never enqueue.
check the lock first and only acquire when it is free:

```perl
## serialize against real task inference without ever entering the        ##
## backend queue : a queued pseudo-id would later be handed to            ##
## coding.async.send_request by backend_release, which has no task for it ##
my $bs = ( <coding.state.backend> // {} )->{$backend} // {};
if ( defined $bs->{'lock'} ) {
    ## busy : do NOT call backend_acquire. re-check on the next tick      ##
    return TRUE;    ## keep the repeating timer alive, stay in this phase ##
}
<[coding.async.backend_acquire]>->( $probe_id, $backend );
```

alternative (if you prefer symmetry with the real path): call
`backend_acquire` unconditionally and, on `acquired == FALSE`, immediately
splice the pseudo-id back out of
`<coding.state.backend>->{$backend}{'queue'}`. equivalent, more moving parts.

release with `<[coding.async.backend_release]>->( $probe_id, $backend )` on
*every* terminal path — success, error, timeout, and state-machine abort.

---

#### step 3 — `coding.self_test.async_probe` [ new module ]

one non-blocking inference request. returns immediately; the caller supplies a
continuation.

```perl
## [:< ##

# name  = coding.self_test.async_probe
# descr = single non-blocking self-test inference probe [ SSE streaming ]

my $params  = shift // {};
my $url     = $params->{'url'};
my $prompt  = $params->{'prompt'};
my $backend = $params->{'backend'} // 'gpu';
my $timeout = $params->{'timeout'} // 90;
my $on_done = $params->{'on_done'};    ## coderef : ( $result_hashref ) ##

## LOAD-BEARING : the SAME id poll_probe used to acquire the backend lock. ##
## ownership split : poll_probe acquires [ step 2 ], async_probe releases   ##
## [ $finish below ]. if this is undef/empty, backend_release:13-19 fails   ##
## its holder guard, returns FALSE, and logs at level 2 ONLY - the gpu lock ##
## stays held forever, every real task queues behind it, and nothing is     ##
## visible at default log level. worse than the wedge this task fixes       ##
my $probe_id = $params->{'probe_id'} // '';

## normalize to the completions endpoint, same as                          ##
## coding.tools.http_inference_client:19-24                                ##
my $completion_url = $url;
if ( $completion_url !~ m{/v1/chat/completions$} ) {
    $completion_url =~ s{/+$}{};
    $completion_url .= '/v1/chat/completions';
}

## same body shape as coding.tools.http_inference_client, but streaming ##
my $body = {
    model       => $params->{'model_id'} // '',
    messages    => [ { role => 'user', content => $prompt } ],
    max_tokens  => $params->{'max_tokens'} // 4096,
    temperature => 0.3,
    stream      => JSON::PP::true,
};

my $acc = { content => '', reasoning => '', finish_reason => '' };
my $settled = FALSE;    ## on_error and on_complete can BOTH fire : guard ##

my $finish = sub {
    my ($result) = @_;
    return if $settled;
    $settled = TRUE;
    <[coding.async.backend_release]>->( $probe_id, $backend );
    $on_done->($result) if ref $on_done eq qw| CODE |;
};

my $callbacks = {
    task_id => '',    ## deliberate : see step 2, makes shared handlers ##
                      ## degrade to no-ops rather than touching a task  ##
    backend => $backend,
    timeout => $timeout,

    on_chunk => sub {
        my ($data) = @_;

        ## self-test IS the first request after a spawn : clear the      ##
        ## cold-start grace the same way coding.callback.http_chunk:22-34 ##
        ## does, or the flag stays set and the next REAL request gets a   ##
        ## 90s data-start window it hasn't earned                         ##
        my $srv = ( <coding.inference_servers> // {} )->{$backend};
        delete $srv->{'cold_start'} if $srv && $srv->{'cold_start'};

        ## accumulate delta.content / delta.reasoning_content /          ##
        ## finish_reason — mirror coding.async.chunk_handler:26-105, but ##
        ## NOTHING else from it [ no state_machine, no task.queue ]      ##
    },

    on_complete => sub {
        ## strip inline <think>..</think> out of content into reasoning, ##
        ## strip a stray leading </think> — identical to                 ##
        ## coding.tools.http_inference_client:74-78 so downstream        ##
        ## check_constraint sees exactly what it sees today              ##
        $finish->(
            {   mode          => qw| true |,
                data          => $acc->{'content'},
                reasoning     => $acc->{'reasoning'},
                finish_reason => $acc->{'finish_reason'},
            }
        );
    },

    on_error => sub {
        my ($error) = @_;
        ## map to the SAME error strings self_test.run already matches   ##
        ## on : http_5\d\d  /  request_failed. http_io:109-123 reports   ##
        ## "HTTP error: <code>" — translate, do not invent new tokens,   ##
        ## or the existing retry + capture_server_tail logic stops       ##
        ## recognizing failures                                          ##
        my $code = $error =~ m{HTTP error:\s*(\d+)} ? "http_$1" : 'request_failed';
        $finish->( { mode => qw| false |, data => $code } );
    },
};

my $http = <[coding.async.http_client]>->( $completion_url, $body, $callbacks );
$finish->( { mode => qw| false |, data => 'request_failed' } )
    if !$http->{'success'};

return TRUE;
```

notes:
- **lock ownership**: `poll_probe` acquires (step 2), `async_probe` releases
  (`$finish`). the `probe_id` must be the *same value* on both sides — pass it
  through explicitly, never re-generate it. every terminal path goes through
  `$finish`, which is why the release lives there and nowhere else.
- the `$settled` guard is not optional: `on_error` (from a timeout handler)
  and a late `on_complete` can both fire for the same request.
- the existing one-retry-on-5xx logic stays, but moves up into the state
  machine (step 4) — a retry is now "re-enter the same phase", not a loop.

---

#### step 4 — `coding.self_test.run` → timer-driven state machine

model this **exactly** on `coding.self_test.handler.poll_switch`. do not
invent a new async style; that file is the established precedent inside this
same subsystem.

structure, mirroring `cmd.self-test-run:119-164`:

```perl
## caller side [ in coding.self_test.run ] ##
$data{'coding'}{'self_test_probe_state'} //= {};
my $probe_id = <[base.gen_id]>->( $data{'coding'}{'self_test_probe_state'} );

$data{'coding'}{'self_test_probe_state'}{$probe_id} = {
    'model_id'   => $model_id,
    'url'        => $url,
    'backend'    => $backend,
    'timeout'    => $timeout,
    'epoch'      => <[base.time]>->(3),
    'prompts'    => \@prompts,     ## unchanged content, see below ##
    'idx'        => 0,             ## which prompt we are on ##
    'phase'      => qw| probe |,
    'results'    => [],
    'pass_count' => 0,
    'test_count' => 0,
    'all_passed' => TRUE,
    'on_done'    => $params->{'on_done'},   ## caller continuation ##
    'gap_until'  => 0,
};

<[event.add_timer]>->(
    {   'interval' => 0.5,
        'repeat'   => TRUE,
        'handler'  => qw| coding.self_test.handler.poll_probe |,
        'data'     => { 'probe_id' => $probe_id },
        'desc'     => "self-test probe $probe_id"
    }
);

return { mode => qw| deferred | };
```

`coding.self_test.handler.poll_probe` phases (per prompt index):

| phase | on entry | on tick | exit |
|---|---|---|---|
| `gap` | set `gap_until = now + 1.5` | wait until `now >= gap_until` | → `probe` |
| `probe` | lock free? acquire + `async_probe`, set `in_flight` | wait for `in_flight` to clear | → `evaluate` or `probe_retry` |
| `probe_retry` | one retry on `http_5\d\d` / `request_failed` | — | → `probe` (once) or `fail` |
| `evaluate` | run tier0, then tier1 reformat attempts async (step 5) | wait | → `record` |
| `record` | archive + multiplier, advance `idx` | — | → `gap` (next prompt) or `done` |
| `done` | build summary, cancel timer, invoke `on_done` | — | terminal |

**the 1.5s inter-prompt gap at `self_test.run:94` is currently a blocking
`<[base.sleep]>->(1.5)`. it must NOT survive as a sleep** — it becomes the
`gap` phase above (a `gap_until` timestamp checked on each 0.5s tick). do not
silently drop it either; the spacing itself was a real, separately-confirmed
fix this session.

everything else in `self_test.run` moves into the state machine unchanged in
*meaning*:

- the `!$inference_ok` hard-fail path (`self_test.run:219-243`) — including
  `capture_server_tail` + `ellipse_center` truncation — becomes the `fail`
  branch of `probe_retry`. **keep the hard fail**: evaluate must still be
  skipped entirely when the initial call failed (this is the spurious-pass fix
  from today, confirmed live).
- the empty-content-with-reasoning diagnostic (`self_test.run:199-209`) moves
  into the `evaluate` entry.
- `$result_record` construction, `coding.self_test.archive` and
  `coding.self_test.multiplier` (lines 309-344) move into the `record` phase
  verbatim.
- the summary hashref and `mode => all_passed ? true : false` (lines 352-364)
  become the argument to `on_done`, not a `return`.

---

#### step 5 — `coding.self_test.evaluate` → continuation-driven

tier0 (`coding.self_test.check_constraint`, lines 20-34) is deterministic and
stays synchronous — no change.

only `$try_reformat` (lines 143-222) makes an inference call. it currently
runs up to two attempts sequentially (base hint, then strict hint on lines
224-239), each with its own one-retry-on-5xx loop — a straight-line 4-deep
blocking nest.

invert it into a sub-phase sequence inside `poll_probe`'s `evaluate` phase:

```
tier1_a      → async_probe with $with_mismatch_hint->( $base_hint->() )
tier1_a_retry→ one retry on 5xx / request_failed
tier1_b      → async_probe with $with_mismatch_hint->( $strict_hint->($reason) )
tier1_b_retry→ one retry
```

carry the accumulated `@attempts` array (hint / reformatted / reason / ok /
server_tail — lines 188-218) in the probe state hash, since it feeds
`coding.self_test.cmd.self-test-detail`.

keep intact and unchanged: `$base_hint`, `$strict_hint`,
`$with_mismatch_hint`, and — critically — the `$content_already_correct`
computation (lines 47-61) and its early-return guard at line 128. that guard
is this session's fix and has **not yet been exercised live**; a rewrite that
loses it silently regresses a known bug.

either keep `coding.self_test.evaluate` as the module that *computes hints and
checks constraints* (called synchronously from `poll_probe` at each sub-phase
boundary, with the inference removed), or fold it into `poll_probe` entirely.
the first is preferable — smaller diff, keeps the hint logic in one readable
place, keeps `self-test-detail` working.

---

#### step 6 — the four call-site inversions

**6a. `coding.handler.monitor_inference_startup:129-218`** — the auto-trigger.
today it calls `self_test.run` synchronously at line 131 and then, at lines
146-217, inspects `$st_result` for a failed `prompt_id 2` and decides whether
to bump `<coding.self_test_seed_retry_count>` and schedule
`coding.handler.spawn_servers_deferred` for a fresh-seed restart.

move lines 146-217 verbatim into an `on_done` closure passed to
`self_test.run`. everything after it (the dependency reset at lines 220-233,
`jobqueue.check_dependencies`, and the
`coding.cancel_watcher.backend_monitor` call at line 238) must stay where it
is and run **immediately**, not inside the callback — the watcher must be
cancelled and dependencies rechecked as soon as the server is ready,
independent of how long the probe takes. this is the ordering change most
likely to be got wrong.

**consequence to handle, not just an ordering note.** today those three run
*after* a blocking self-test, so self-test has de facto exclusive access to
the freshly-spawned server. running them immediately means real tasks can
start streaming while the probe is still in flight — and if the probe then
fails the cat test, the seed-retry path (lines 193-204) sets
`status = restart_needed` and respawns, killing the server **mid-task**. the
backend lock keeps the probe itself correct; it does not cover this. before
triggering the seed-retry respawn, check for in-flight task inference (a held
`<coding.state.backend>->{$backend}{'lock'}` held by someone other than the
probe, or a non-empty queue) and defer the restart until it clears.

note the closure captures `$test_model_id` and `$backend`; `$server` is a live
hashref from `<coding.inference_servers>` and may have been replaced by a
newer spawn by the time the callback fires — re-fetch it inside the callback
rather than capturing it, and bail if the pid no longer matches (same stale
guard shape as lines 14-27).

**6b. `coding.self_test.cmd.self-test-run:57-84`** — the already-loaded fast
path. today it calls `self_test.run`, then runs `apply_tier2` on any
`needs_tier2` results, then `return $format_result->(...)`.

convert to the deferred-reply pattern this same file already uses for the
switch path (lines 145-164): capture `$call->{'reply_id'}`, pass an `on_done`
that runs the `apply_tier2` block and then
`<[base.callback.cmd_reply]>->( $reply_id, $format_result->(...) )`, and
`return { mode => qw| deferred | }`.

`$format_result` (lines 27-55) needs no change — just gets invoked later.

**6c. `coding.self_test.handler.poll_switch:160-201`** — the switch-driven
path, and the most intricate of the inversions. today, inside the `switching`
phase, it calls `self_test.run` synchronously (line 170), stashes the return
in `$state->{'result'}`, then immediately fires the restore `switch-model` and
flips to phase `restoring`.

insert a new **`testing`** phase between them:

```
switching  → target ready → start async self_test.run, phase = testing
testing    → probe still running : return TRUE and wait
           → on_done fires : store $state->{'result'}, initiate restore,
             phase = restoring, started = now, prior_pid = $gpu_pid
restoring  → [ unchanged ]
```

the `on_done` closure writes `$state->{'result'}` and performs exactly what
lines 180-199 do today. `$apply_pending_tier2` (lines 120-147) and the
`restoring` phase are unchanged — they already read `$state->{'result'}`.

guard the `testing` phase with its own timeout (reuse
`<coding.cfg.switch_model_max_wait>` semantics, or a smaller dedicated value):
if the probe never calls back, the switch state machine must not hang forever
holding `<coding.self_test_switch_in_progress>` TRUE. on that timeout, fall
through to `restoring` with `$state->{'error'}` set — the existing error path
already handles it.

**6d. reply-formatting** — `$format_result` exists in *two* copies
(`cmd.self-test-run:27-55` and `poll_switch:86-110`). they are now identical.
consider extracting to `coding.self_test.helper.format_result` while you are
in here — optional, but this task touches both.

---

#### step 7 — mandatory incremental testing

this is a **live-production, already-fragile-this-session** code path. today's
session broke it twice by changing more than one thing before observing. do
not big-bang this.

one restart-and-observe cycle **per numbered step**, in order:

1. **after step 1** — restart, watch a full self-test cycle. record whether
   `http_500` still appears. **stop and evaluate the gate** before continuing.
2. **after step 3** — `async_probe` written but not yet wired in. exercise it
   from a throwaway command against the live server; confirm the returned
   hashref is shape-identical to `http_inference_client`'s, and confirm the
   backend lock is acquired and released (log level 2:
   `backend_acquire: ... acquired gpu lock` / `backend_release: ... released`).
   confirm `<coding.state.backend>->{gpu}{queue}` is still empty afterwards.
3. **after step 4** — self-test runs both prompts via the state machine, but
   `evaluate` still blocking. confirm `coding.heart` responds *while a probe
   is in flight* — this is the whole point of the exercise; if it doesn't,
   something is still blocking.
4. **after step 5** — full async path. confirm a verbose-but-correct cat
   answer still reaches tier1 and that `$content_already_correct` suppresses
   the `mismatch_hint` (still unverified live from today — check
   `coding.self-test-detail` output for the exact hint text sent).
5. **after each of 6a / 6b / 6c separately** — never together. 6a: restart
   the zenka and watch the auto-trigger fire + the seed-retry decision still
   work on a genuine cat-test failure. 6b: `p7c coding.self-test-run` returns
   a real reply, not a hang and not `HASH(0x...)`. 6c: `p7c
   coding.self-test-run <other_model_id>` completes the full
   switch→test→restore round trip.

lessons from today that must not be relearned: **bounded, never unbounded** —
every wait gets a ceiling and a fallback path; a state machine phase with no
timeout is an unbounded wait wearing a costume. and **idempotency guards** —
`verify_inference_startup` needed one because multiple restart paths each
scheduled their own timer with no cancellation; the probe state machine has
the same exposure if a second self-test can start while one is in flight.
guard it (a `<coding.self_test_probe_in_flight>` flag, or check for an
existing entry in `self_test_probe_state` for the same backend).

---

### what NOT to change

settled on 2026-07-31, confirmed live, do not revisit:

- **the riddle prompt wording** (`self_test.run:48-49`): `'put a cat and a
  mouse in a room, close the door and wait.., who is the remaining animal?'`
  — "the remaining animal" is a deliberate recurring motif across the design
  docs (`data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md`), not an
  accidental ambiguity. do not reword. do not re-add a "reply with only the
  animal name" instruction — removing it was a confirmed fix.
- **the `mismatch_hint` content** (`self_test.run:72-74`): two wordings were
  tested live; the current short Socratic one is understood not to reliably
  flip a committed wrong answer, and **that is expected** — the test measures
  seed-to-seed reasoning coherence, not tier1's persuasiveness. do not try to
  improve it.
- **the `$content_already_correct` guard** (`evaluate:47-61`, 128): carry it
  across intact.
- **the 90s timeout value** (`self_test.run:25`, `evaluate:17`): a deliberate
  middle ground, not a converged value. the real fix is transport, not
  duration. do not tune it as part of this task.
- **the hard-fail-before-evaluate behaviour** (`self_test.run:219-243`) and
  the 1.5s inter-prompt spacing: both are this session's confirmed fixes.
- **`max_tokens => 4096`** for the initial self-test call.

this task is about the **transport mechanism** (blocking vs async). the
self-test's logic and content are not in scope.

---

### verify

```bash
grep -n "http_inference_client" modules/coding.self_test.* modules/coding.handler.monitor_inference_startup
grep -n "base.sleep\|select( undef" modules/coding.self_test.*
grep -n "stall\|data-start\|cold_start" modules/coding.async.http_client
grep -n "task_id" modules/coding.abort.check_stream modules/coding.handler.http_timeout
```

after conversion, the first grep should return **no hits** in
`coding.self_test.run` / `coding.self_test.evaluate` (hits remaining in
`follow_up` / `tier2_judge` are expected and out of scope), and the second
should return no blocking sleeps in the converted files.

---

### test plan

```bash
## 1. step-1 gate : does streaming alone fix the 500s ?
p7c coding.self-test-run
p7c coding.self-test-detail          ## per-prompt detail incl. server tail

## 2. the load-bearing check : zenka stays responsive during a probe
##    run these two concurrently — heart must reply immediately
p7c coding.self-test-run &
sleep 2; p7c coding.heart

## 3. auto-trigger path [ 6a ] : restart and watch the readiness self-test
p7c v7.restart coding
p7c coding.self-test-status

## 4. switch path [ 6c ] : full switch -> test -> restore
p7c coding.self-test-run <other_model_checksum>
```

expected after full conversion: `coding.heart` replies within normal latency
at every point during a self-test, including mid-inference; self-test results
(pass/fail, tier, ttft, server tail on failure) are identical in shape and
content to what `coding.self-test-detail` shows today.

---

## signatures_note

these are **module files** — every one ends with a 4-line `#,,,` AMOS7 data
signature block. do not hand-write, edit, or copy those blocks. leave signing
to `bin/Protocol-7 sourcecode update-signatures`. new modules
(`coding.self_test.async_probe`, `coding.self_test.handler.poll_probe`) must
also be registered in `configuration/zenki/coding/start` and
`configuration/zenki/coding/subroutines.load-early`.

---

### dispatch

model: kimi
reasoning: high

prompt: |
  implement the task at data/tasks/coding-self-test-async-http-client-rewrite.md

  read data/ai-mem/claude/topic-coding-self-test-http500-and-hint-fixes-2026-07-31.md
  FIRST — it is settled background, do not re-litigate any of it.

  step 1 is a decision gate. do it, observe the result, and report back
  before proceeding to step 2. do not treat it as a warm-up.

  this is a live-production path. one restart-and-observe cycle per numbered
  step, in order — never batch changes.

  use $ARG not @_ where the file already does; lowercase comments; bracket
  annotations [ like this ]; do not touch the trailing signature blocks.

#,,.,,,.,,.,,,..,,.,,,,..,,..,.,.,,.,,,,,,,.,,..,,...,...,,..,..,,,.,,,..,...,
#DJHYTBH4L6ZLOAWVBOUMDTXO6IP7PRWJQJ7FCVCILP43ZQ5DIV2MMHMZJURXPPYT7PGMJG2YXMPTI
#\\\|RCHN24XVS5WBPEHWYPH6HD3FPWMJNE5ATZ3H74VGJ46UDBOPIDQ \ / AMOS7 \ YOURUM ::
#\[7]3FMR4FUZJCWKHHNRTUDVS7PDKKRNI7OBL2XTCE7EU6PVXB5JVEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
