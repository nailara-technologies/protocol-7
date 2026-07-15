## [:< ##

# name  = task: coding zenka model self-test cycle
# descr = run a calibration benchmark after each model load to acquire
#         per-model timeout multipliers. expandable to model fallback,
#         consensus ranking, and archived per-attempt results.

## context

the coding zenka already has:
- `coding.cfg.timeout_stats` — statistical adaptive timeout (future task)
- `coding.async_spawn_inference_servers` — model loading infrastructure
- `llm.service.consensus_vote` — multi-model voting
- task zenka — state machine iterator for batch processing

this task adds the self-test cycle that feeds the timeout stats and
enables intelligent model selection and fallback.

design context: `data/md/design/CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-VALIDITY.md`
                (section 3)
relates to: [[topic-coding-state-machine]], [[topic-task-coordination]],
            `data/tasks/coding-model-selection-template.md`

## the self-test cycle

after each model load completes, before the model is marked available
for production tasks:

```
1. send calibration prompt (fixed, short, known-good)
2. record: time-to-first-token (TTFT), total tokens, total time
3. compute: tokens_per_second, estimated timeout multiplier
4. store in coding.cfg.timeout_stats[model_id]
5. if test fails (timeout, error, garbage output): mark model suspect
   → try fallback model
   → if no fallback: log warning, proceed anyway (degraded mode)
6. mark model available for production
```

## calibration prompts

run as a fixed sequence per model load. each prompt must be:
- short (fast to process, low variance)
- deterministic (same answer every time — checkable)
- exercises the model's reasoning path (not pure recall)

```
prompt 1 (arithmetic): "What is 7 × 13? Reply with only the number."
expected: "91"

prompt 2 (predation riddle): "put a cat and a mouse in a room, close
  the door and wait.., who is the remaining animal?"
expected: "cat" (case-insensitive, trimmed — exactly 3 characters)
```

the division-by-13 calibration has a pleasant harmonic property. the
riddle was chosen live (2026-06-20 session) after observing the local
model answer it correctly once, then incorrectly/contradictorily on a
second unconstrained run — it's a good calibration case precisely
because it has exactly one correct short answer but a known failure
mode (verbose self-contradiction) that's easy to detect mechanically:
checking the trimmed answer length/content catches both "wrong content"
and "didn't follow the brevity instruction" in one comparison.

if the model answers anything other than the expected string for either
prompt: suspect, log, proceed with a warning annotation in
`coding.cfg.model_status`, AND trigger the anomaly follow-up below.

## anomaly follow-up

when a calibration answer doesn't match the expected string exactly
(after trim + case-fold): don't just log pass/fail — automatically
re-prompt the same model, same context, asking it to explain its own
reasoning for the answer it just gave. archive the follow-up
explanation alongside the original mismatch.

```
1. self_test.evaluate finds answer != expected
2. immediately send follow-up prompt to the SAME model:
   "explain your reasoning for that answer, step by step"
   (no new context — same conversation/session if the inference
   backend supports continuation, otherwise replay the original
   prompt + answer + the follow-up question together)
3. archive the explanation in
   $data{coding}{self_test}{$epoch}{$model_id}{anomaly}{$prompt_id} =
     { answer => <original mismatched answer>,
       explanation => <follow-up response>,
       expected => <expected string> }
4. mark model suspect (existing behavior, unchanged)
5. do NOT block availability on this — the follow-up is diagnostic,
   not gating; degraded mode proceeds as already specified above
```

this turns every calibration failure into a labeled training/diagnostic
sample instead of a silent pass/fail bit — the explanation is what
distinguishes "model is just unreliable" from "model has a specific,
nameable confusion" (e.g. tonight's case: pattern-matching the riddle
against the wrong genre of lateral-thinking puzzle instead of
recognizing predation).

## timeout multiplier calibration

the self-test TTFT becomes the baseline for this model:

```perl
my $ttft_seconds = $self_test_result->{ttft};
my $baseline_tps = $self_test_result->{tokens_per_second};

# store in stats ring (rolling window of N self-tests per model)
push @{ $data{coding}{cfg}{timeout_stats}{$model_id}{ttft_samples} },
    $ttft_seconds;

# compute p95 multiplier
my $p95_ttft = percentile_95( @ttft_samples );
$data{coding}{cfg}{timeout_stats}{$model_id}{ttft_p95}   = $p95_ttft;
$data{coding}{cfg}{timeout_stats}{$model_id}{baseline_tps} = $baseline_tps;
$data{coding}{cfg}{timeout_stats}{$model_id}{multiplier}  = $p95_ttft * 1.5;
```

this feeds directly into the statistical adaptive timeout described
in `topic-next-steps` — no separate task needed for the data structure.

## model fallback chain

on production task failure (timeout, error):

```
current model fails
  → check fallback_chain config for current model
  → if fallback available: resubmit task to fallback model
  → log: which model failed, which fallback used, failure reason
  → if fallback also fails: escalate (return error to caller)
```

fallback chain configured per-model in zenka config:

```
coding.cfg.model_fallback.DVEAZIA = CSABG4A   # Glitter fails → DeepSeek
coding.cfg.model_fallback.CSABG4A = none       # DeepSeek is the last resort
```

## testing a non-loaded model (2026-06-21, DONE — live-confirmed end to end)

`coding.self-test-run`'s `model_id` is optional — defaults to
`<inference.model.amos_id>`, the currently-loaded model.

if a `model_id` IS given and differs from the currently-loaded one: it
switches to it, runs the self-test, and switches back — via
`coding.cmd.switch-model`, as a proper async timer-driven state machine
(see "blocking poll bug" section below for the implementation), with
dependency-state blocking for regular tasks during the window (see
"self-test as a dependency state" below). all three original blocking
design questions are resolved and live-tested:

```
live confirmation (2026-06-21): coding.self-test-run KVRBYTQ:BZHYASQ
(while IXNBXVI:U2XBEXQ was loaded) correctly: switched to KVRBYTQ,
spawned it, ran the calibration against it under its OWN correctly-
labeled identity (2/2 passed), then unconditionally switched back to
IXNBXVI (2/2 passed), and delivered "self-test complete for
KVRBYTQ:BZHYASQ: 2/2 passed" as the final deferred reply. full
sequence verified in the live console log, not just trusted from a
summary.
```

remaining known issue, not a regression: the auto-trigger from
`monitor_inference_startup` (which fires self_test.run on EVERY
readiness event, with no suppression yet) ALSO ran during this same
window, causing a visible duplicate test — this is exactly the
already-documented "two more triggers" suppression issue below, now
actually observed live instead of theoretical. not a new bug; fix
remains the same (a suppression marker self-test-run sets before
switching, that the auto-trigger checks and skips on).

## switch-model race condition (2026-06-21, FIXED — also found+fixed:
model_id staleness AND a completely disconnected model-id field)

status: the shared-global race below is FIXED (params now travel with
each reply via base.route.add's existing 'params' plumbing, confirmed
delivered to handlers per coding.handler.command.process_reply). the
async-rewrite (blocking-poll bug, separate section below) is also
FIXED and live-tested. ONE MORE issue found during live-testing the
fixed version: `inference-status`'s `model_id` field reflects
configured INTENT (set by switch_model_reply the instant it starts
processing), not actual serving state (only true once spawn_smart's
kill+respawn completes) — confirmed live: a readiness check using
model_id alone could pass while the OLD process was still genuinely
serving. FIXED: poll_switch and self-test-run now track the PID
running before each phase started, and require BOTH ready-status AND a
DIFFERENT pid than before — model_id checks were dropped from the
AND-condition entirely (kept only as a non-blocking log line), because
of the SECOND, deeper issue found next.

**second issue, also FIXED**: `inference-status`'s `model_id` field
(`coding.inference_servers.gpu.model`) is sourced from
`<inference.model.amos_id>` (set by `monitor_inference_startup`), which
is a SEPARATE global from `<inference.backend.gpu.model_id>` (the one
`switch_model_reply` was updating) — `<inference.model.amos_id>` was
never updated by switch-model at all, so it stayed frozen at whatever
`coding.cfg.start_model` was at boot, regardless of how many switches
happened. this explained BOTH the model-id-based readiness check never
matching (since it could never become the target checksum) AND the
earlier "self-test auto-fires mislabeled" observation (monitor_startup
always labelled the model from this same frozen field). separately,
**also found**: the `backend eq 'auto'` mode (the default, used by
every test) updated neither `inference.backend.gpu.model_id` nor
`cpu.model_id` either — the update logic only matched literal
`'gpu'`/`'cpu'`/`'both'`, never `'auto'`. all three now fixed in
`coding.handler.switch_model_reply`: a `$mark_backend_updated` helper
updates the correct per-backend field AND `<inference.model.amos_id>`,
called from every successful spawn path including auto's gpu-then-cpu
fallback.

original race description below, for context:

confirmed live via the switch-test-restore wrapper above: a real,
pre-existing concurrency bug in `coding.cmd.switch-model` /
`coding.handler.switch_model_reply`, not introduced by self-test but
reliably triggered by it.

```
<coding.pending_model_switch_checksum> (+_name +_backend) are single
SHARED globals, never actually cleared (switch_model_reply line 94 has
a comment claiming clearing "happens anyway on next switch" - it does
not, there is no clearing code at all). if a second switch-model call
fires before the first's async model-path-lookup reply arrives, the
second call's globals overwrite the first's. when the FIRST reply
finally lands, switch_model_reply reads the (now-clobbered) globals -
so it can set <inference.backend.gpu.model_id> to the SECOND request's
checksum while the server actually spawned is running the FIRST
request's model file [ confirmed: log showed Kimi-K2's actual gguf path
loading while the log line said "switching to IXNBXVI:U2XBEXQ" ]. this
is a real config/reality mismatch, not just a cosmetic log confusion -
inference-status's model_id field can lie about which model is
genuinely loaded during the race window.

root fix (not yet implemented): protocol-7.command.send.local's reply
registration already has an unused 'params' => {} field
(coding.cmd.switch-model:66-70) that flows through base.route.add's
reply config (confirmed: base.protocol-7.command.send.local:57-65)
specifically for passing request-scoped context to a reply handler -
switch_model_reply should read checksum/name/backend from there instead
of the shared globals. NOT yet confirmed: the exact mechanism by which
'params' actually reaches the handler function when the reply arrives -
needs tracing the remaining base.route.* reply-dispatch side before
implementing.

this is core, widely-used model-switching infrastructure, not scoped to
self-test - fix it as its own task, not bundled into the self-test
wrapper's narrower concerns below.
```

## blocking poll bug — root cause of "switch never completes" (2026-06-21,
RESOLVED design, not yet implemented)

confirmed live, twice: the switch+restore wrapper's `$poll_model_ready`
helper uses `<[base.sleep]>->(0.5)` in a tight loop. this BLOCKS THE
ENTIRE EVENT LOOP for up to 120s. the things being polled for —
the models-zenka reply arriving over the cube connection,
`monitor_inference_startup`'s `event.add_io` watcher reading the new
server's stdout to detect "ready" — only get processed when control
returns to the event loop. while blocked in `base.sleep`, NONE of that
runs, so the condition being polled for can never become true until
the poll loop itself gives up and the function returns. confirmed via
log: two switch-model calls (test target, then restore) both got
silently queued and only processed back-to-back once the blocking
function finally returned — not when they should have, sequentially,
as each actually completed.

this is fundamentally different from `self_test.run`'s blocking HTTP
calls to llama-server (those block on a FOREIGN process's socket —
llama-server keeps computing independently regardless of our event
loop, so blocking on it is fine, if non-ideal). blocking on our OWN
event loop's continued operation is self-defeating and can never work,
at any timeout value.

**the fix**: rewrite the switch path as a proper async state machine,
reusing the exact deferred-reply pattern already established in this
exact codebase by `coding.cmd.ask-reply` / `coding.handler.deferred_reply`:

```
1. coding.self_test.cmd.self-test-run, when a switch is needed:
   - capture $call->{'reply_id'}
   - store tracking state (reply_id, target checksum, original
     checksum, phase, started timestamp) keyed by a generated id
   - mark coding.dep.gpu_self_test_pending NOT ready (existing mechanism)
   - fire-and-forget the switch-model call (unchanged - it's already
     async by design)
   - register ONE event.add_timer (interval ~0.5-1s, repeat=>TRUE,
     handler=>coding.self_test.handler.poll_switch, data=>{the tracking
     id}) - NOT a blocking sleep loop
   - return { mode => qw| deferred | } immediately

2. new module coding.self_test.handler.poll_switch (timer tick, fires
   without blocking anything else):
   - read tracking state by id from timer data
   - call coding.cmd.inference-status (cheap, just reads already-
     updated $data tree state, no blocking I/O of its own)
   - phase 'switching' + status ready+model matches  -> cancel timer,
     run coding.self_test.run [ still does blocking HTTP to llama-server
     - acceptable, same as the already-working calibration-only case -
     transition phase to 'restoring', re-register the SAME timer
   - phase 'switching' + crashed/elapsed-too-long -> log, skip the test,
     transition straight to 'restoring', re-register the timer
   - phase 'restoring' + status ready+model matches original -> mark
     dependency ready again, call jobqueue.check_dependencies, resolve
     via <[base.callback.cmd_reply]>->( $reply_id, {...} ) with the
     self-test result (or an error summary if the switch/restore itself
     failed), cancel timer, delete tracking state
   - phase 'restoring' + crashed/elapsed-too-long -> same resolution
     path but with a failure summary - dependency MUST still be marked
     ready and check_dependencies MUST still fire, even on total failure,
     so a stuck gpu_self_test_pending dependency can never block regular
     tasks forever
```

the "model already matches, no switch needed" common-case path is
UNCHANGED — it stays a direct synchronous call to `coding.self_test.run`,
since that path never depended on this process's own event loop for
anything (only on llama-server, a foreign process).

## recurring http_500 specifically on prompt 2 after fresh spawn (2026-06-21,
flagged, pattern not yet root-caused)

observed at least twice tonight: prompt 1 (arithmetic) succeeds cleanly
shortly after a fresh server spawn, but prompt 2 (the riddle) fails
with a raw `http_500` from llama-server itself — not an empty/wrong
answer, an actual server error. follow_up's request for the same
prompt also gets http_500. pattern: always the SECOND request shortly
after spawn, never the first. possible causes, not yet investigated:
the server logging "ready" before it's actually fully settled (some
internal init still finishing in the background), or a per-request
state issue specific to this reasoning model when a second request
arrives in quick succession after the first. worth a dedicated
investigation once the async rewrite above is confirmed stable —
don't conflate this with the blocking-poll bug, it's a different
failure mode (a real llama-server error, not a stuck poll).

## generic result-constraint + tiered escalation (2026-06-21, DESIGNED,
NOT YET IMPLEMENTED — capture before context handover)

user's design, fully thought through, not yet built. generalizes the
self-test strict-match problem (DVEAZIA answering "## Solution... **91**"
instead of "91", "The cat will catch the mouse... the cat is the
remaining animal" instead of "cat" — both substantively CORRECT,
flagged FAIL only by literal string comparison) into a reusable
mechanism for ANY task, not just self-test calibration.

```
1. generic `result_constraint` field on a task (self-test's calibration
   check becomes just one consumer of this, not a special case):
   - word_count (e.g. max 1 word)
   - numeric (one or more numbers)
   - sprintf-style template the answer must match

2. on task completion, check the result against the constraint with a
   plain DETERMINISTIC structural check first (regex / word-count /
   sprintf-match) - cheap, no inference call. only escalate if this
   fails.

3. tier 1 escalation (cheap): if structural check fails, ask the SAME
   model, SAME context (no new prompt needed, just a short follow-up -
   "please summarize your final answer in one word" or whatever the
   constraint implies) to reformat its OWN answer. re-check the
   structural constraint against THIS new answer. this must happen
   BEFORE switching back to the original model (only relevant when a
   switch occurred) - it needs the test model still loaded.

4. tier 2 escalation (only if tier 1 also fails): a full inference-based
   semantic judgment - "does this answer correctly convey X, despite
   not matching the literal format" - asked AFTER switching back (when
   a switch occurred), or in a FRESH context with the same model (when
   no switch occurred, to avoid anchoring the judge on the model's own
   already-wrong framing from the contaminated original context).

key insight, possibly not yet obvious even to the user when they
proposed it: sequencing tier 2 AFTER switch-back means the judging
model is whichever model is now active going forward ANYWAY - this is
cross-model assertion (already flagged elsewhere in this doc as
speculative/phase-3+) arriving for free as a side effect of timing,
not a separate mechanism requiring its own switch. directly resolves
the "can an incoherent model reliably judge its own incoherence"
concern.

cost ordering is deliberately cheap-first: most real-world mismatches
(verbose-but-correct answers, the common case) resolve at tier 1's
reformat request, which is far cheaper than a full semantic-judgment
pass. tier 2 stays rare.

NOT YET DESIGNED IN DETAIL: exact data shape for `result_constraint`,
where structural-check code lives, exact wiring into self_test.evaluate
vs. a more general coding.task.* hook, exact follow-up prompt wording
per constraint type. this section is the captured INTENT, not a spec
ready to dispatch - needs the same level of precision pass the other
features in this doc got before implementation.
```

## drain_pipe resilience (2026-06-21, flagged, smaller, likely related)

observed alongside the blocking-poll bug's double-kill race: `event`
warnings `'coding.handler.drain_pipe' was unexpectedly closed` and
`cannot restart 'coding.handler.drain_pipe' because there is nothing to
watch`. `coding.handler.drain_pipe` itself already handles closed-fd
cases defensively (checks `fileno`, handles EBADF/EINVAL/EOF, cancels
cleanly) — the warning text ("cannot restart") suggests something
ELSE is calling a restart/re-arm on a drain watcher reference without
checking `is_active` first, most likely in whatever kills the old
server during a model switch (`coding.cancel_watcher.backend_monitor`
creates the drain watchers; trace forward from there for a restart
call missing an `is_active` guard). possibly self-resolves once the
double-kill race above is fixed (no more overlapping kill+respawn
cycles to race against) — worth a guard regardless, cheap insurance.

## two more triggers that compound the race (2026-06-21 — #1 and #2 FIXED
+ live confirmed, #3 still open)

```
1. FIXED + LIVE CONFIRMED (see data/tasks/coding-task-model-pinning.md
   for the full account): task model-pinning was real but half-built -
   parsed, never enforced, and the upstream intake parser was actually
   destroying the :model: marker before it ever reached enforcement
   code. now fully implemented, and live-verified via direct
   /proc/<pid>/cmdline inspection (not just label/self-test trust) that
   the pinned model actually loads. along the way, also found and fixed
   a deeper pre-existing bug: coding.handler.await_resources's twin-
   handover watchdog never retired itself and got re-armed on every
   coding.reload, silently substituting the boot-default model during
   any switch while showing a correct-looking label.

2. FIXED + LIVE CONFIRMED: self-test no longer auto-fires redundantly
   during a self-test-driven switch. added <coding.self_test_switch_in_progress>
   - set TRUE in self-test-run right before initiating the switch, checked
   in coding.handler.monitor_inference_startup's readiness branch (skips
   the auto <[coding.self_test.run]> call when set), cleared FALSE in
   poll_switch's $finish helper [ covers both the switch's and the
   restore's readiness events, since $finish only runs once at the very
   end of the whole cycle ]. confirmed live: a full switch-test-restore
   run now shows exactly ONE self-test execution (the explicit one), not
   two - previously every cycle ran the test twice.

3. STILL OPEN, now genuinely the next thing: the explicit self-test-run
   command should support specifying an alternate test suite/prompt list
   (not just the hardcoded 2-prompt calibration array), since switch-
   test-restore used for model evaluation rather than pure calibration
   would want different prompts per invocation.
```

## self-test as a dependency state (2026-06-21, open design, architecture
agreed)

user's call, and the right one: don't hand-roll blocking/polling inside
`self_test.run` for the switch-and-test window above. reuse the EXACT
mechanism that already gates "is the GPU/CPU server ready" -
`<dependency.object>` + `jobqueue.check_dependencies` (see
`coding.handler.monitor_inference_startup`'s existing
`<coding.dep.gpu_server>` / `<coding.dep.cpu_server>` pattern).

```
add a new dependency (e.g. coding.dep.gpu_self_test_pending) that:
  - gets marked "not ready" the moment a self-test-triggered model
    switch begins
  - any task that would route to that backend during this window waits
    on it, via the same dependency-checking path normal tasks already
    go through for server-readiness - no new task-routing logic needed,
    just one more dependency entry in the same check
  - gets marked "ready" again once: the test completes AND (if a
    switch happened) the original model is confirmed restored and
    ready - not just when the test's own HTTP calls return

this is the actual mechanism that satisfies "block regular tasks until
complete" - not a sleep loop, not a manual queue. tasks already know
how to wait on dependency objects; self-test-in-progress just becomes
one more state expressible in that same system.
```

**RESOLVED (2026-06-21)** — the dependency-chain mechanism already
supports this with zero changes to routing/enqueue/check_dependencies:

```
coding.task.enqueue gates every gpu-routed task on coding.dep.gpu_server's
object_id (modules/coding.task.enqueue:60-76). base.dependency.ok walks
EVERY dependency chained to that object_id and ANDs their type-callbacks
together (modules/base.dependency.ok:33-64) - same pattern already used
for memory_gpu/memory_system (modules/coding.init_code:~307-334).

minimal integration:
1. register a new dependency type/object: coding.dep.gpu_self_test_pending,
   with a type callback (dependency.setup.type pattern) that returns
   false while a self-test-triggered switch+test+restore is in flight,
   true otherwise
2. one new line near the existing memory_gpu/memory_system chain adds:
   <[dependency.add]>->( <coding.dep.gpu_server>, <coding.dep.gpu_self_test_pending> );
3. mark the new dependency object not-ready at the start of a switch-
   triggered self-test, ready again once the test completes AND (if a
   switch happened) the original model is confirmed restored and ready
4. call jobqueue.check_dependencies after marking it ready again [ same
   as monitor_inference_startup already does after server readiness ]

no changes needed to coding.routing.decide_service, coding.task.enqueue,
or jobqueue.check_dependencies - any task already routed to gpu and
depending on coding.dep.gpu_server is automatically blocked the moment
this new chained dependency exists and returns false.
```

## cross-model assertion (2026-06-21, speculative, phase 3+)

raised alongside the above: a model producing incoherent output likely
also can't reliably assess its own incoherence — self-assessment is
exactly the capability most likely to degrade together with general
output quality, not independently of it. the switch-mechanism above
makes a different angle available: once switching is reliable, a
KNOWN-GOOD model could be the one performing the assertion/analysis
step on another model's self-test results, instead of relying on
consensus_vote across models that might share the same failure mode,
or relying on the model under test to judge itself.

not designed in detail - flagged because it's a natural extension once
switch-and-restore exists, not because it's ready to build. revisit
after the dependency-state mechanism above actually ships.

## result archival

each self-test result archived with epoch-scoped key:

```
$data{coding}{self_test}{$epoch}{$model_id}{timestamp} = <ntime>
$data{coding}{self_test}{$epoch}{$model_id}{ttft}      = <seconds>
$data{coding}{self_test}{$epoch}{$model_id}{tps}       = <tokens/sec>
$data{coding}{self_test}{$epoch}{$model_id}{passed}    = TRUE/FALSE
$data{coding}{self_test}{$epoch}{$model_id}{answer}    = <model output>
$data{coding}{self_test}{$epoch}{$model_id}{prompt_id} = <which calibration prompt>
$data{coding}{self_test}{$epoch}{$model_id}{anomaly}{$prompt_id} = {
    answer => <mismatched answer>, explanation => <follow-up response>,
    expected => <expected string> }    # only present on mismatch
```

older epochs can be squashed/archived. current epoch self-tests
always available for timeout calibration.

## consensus ranking (phase 2)

after multiple models have completed their self-tests:

```
send same calibration task to all loaded models simultaneously
collect all responses
run through llm.service.consensus_vote
rank models by: correctness + speed + consistency
store ranking in coding.cfg.model_ranking
use ranking for task routing (prefer top-ranked for quality tasks,
accept lower-ranked for speed tasks)
```

this may share a state-machine iterator with the task zenka batch
processor — the common pattern: send N tasks, collect N results,
aggregate. extract that into a shared `batch.collect.*` module
when the duplication becomes clear.

## modules

```
coding.self_test.run          run calibration prompt sequence, record results
coding.self_test.evaluate     check answer correctness; on mismatch,
                              trigger coding.self_test.follow_up
coding.self_test.follow_up    re-prompt the model to explain its
                              reasoning for a mismatched answer
coding.self_test.archive      store result (+ anomaly explanation if
                              any) in epoch-scoped data tree
coding.self_test.multiplier   compute timeout multiplier from sample set
coding.self_test.cmd.status   show self-test results per model
coding.self_test.cmd.run-now  trigger manual self-test for a model
```

## integration point

in `coding.async_spawn_inference_servers` or
`coding.handler.monitor_inference_startup`, after readiness is confirmed:

```perl
# model is ready — run self-test before marking available
<[coding.self_test.run]>->( $model_id );

# if self-test passes: mark available
$data{coding}{model}{$model_id}{available} = TRUE;

# if self-test fails: log + mark suspect (still available, degraded)
$data{coding}{model}{$model_id}{suspect} = TRUE;
warn "model $model_id failed self-test — degraded mode";
```

## validation

```bash
# trigger model reload + watch for self-test
p7c coding.self_test.status
# → shows all models with last self-test timestamp, TTFT, pass/fail

# manual trigger
p7c coding.self_test.run-now DVEAZIA
# → runs calibration, shows result

# check timeout multiplier was updated
p7c coding.self_test.status
# → multiplier column updated from new TTFT sample
```

## dispatch prompt

implement the coding zenka model self-test cycle.

1. create `modules/coding.self_test.run` — sends the calibration prompt
   sequence (arithmetic "7 × 13", then the cat/mouse riddle) to the
   specified model via the existing HTTP inference API
   (`coding.handler.process-queued-task` pattern), records TTFT +
   total time + answer per prompt, calls coding.self_test.evaluate +
   archive for each

2. create `modules/coding.self_test.evaluate` — checks answer against
   the prompt's expected string (trim + case-fold), returns TRUE/FALSE;
   on FALSE, calls `coding.self_test.follow_up` before returning

3. create `modules/coding.self_test.follow_up` — sends a second prompt
   to the same model asking it to explain its reasoning for the
   mismatched answer; returns the explanation text for archival

4. create `modules/coding.self_test.archive` — stores result (+ anomaly
   explanation if any) in `$data{coding}{self_test}{<epoch>}{<model_id>}`
   tree

5. create `modules/coding.self_test.multiplier` — percentile_95 of
   TTFT samples × 1.5 → stores in `coding.cfg.timeout_stats`

6. create `modules/coding.self_test.cmd.status` — SIZE reply showing
   all models × last self-test timestamp / TTFT / pass/fail / multiplier
   / anomaly count

7. create `modules/coding.self_test.cmd.run-now` — accepts model_id arg,
   triggers immediate self-test sequence, returns result (+ anomaly
   explanations if any)

8. wire into `coding.handler.monitor_inference_startup`: after readiness
   confirmed, call `coding.self_test.run` before marking model available

check existing `coding.handler.process-queued-task` for the HTTP
inference pattern to reuse. check `coding.cfg.timeout_stats` data path
to confirm it's initialized in `coding.init_code` or add it there.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,..,,.,,,,.,,..,.,.,.,,,,..,...,.,,,,.,,.,,,..,,...,...,.,.,,,.,,..,,,.,,..,
#N6XB7GU5JU7BXBEVX76YM6UYX3QLLXYQZTA35HMOLAXYAR54QGYGQYORUSTURR4UCOIUPO564JOYO
#\\\|LPE57MQZ5ZXL7AQES3G6A7HMHUW7LEADYV2YO5TPRPSEERWCE2W \ / AMOS7 \ YOURUM ::
#\[7]UE7QR4EGAVCJENVEYZMTJCR5WADNPYCJQQFEELADFPLKV5JNI2AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
