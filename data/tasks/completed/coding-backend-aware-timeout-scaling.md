## [:< ##

# name  = task: derive backend-aware timeouts from live t/s measurement
# descr = gpu-tuned http/self-test timeout constants are ~7-8x too tight
#         for cpu inference -- fix by measuring real throughput live,
#         not by guessing a fixed multiplier.

## context

found 2026-08-26 live-testing the CPU spawn path fixes (same day). once
CPU inference actually worked, its self-test kept hitting timeout
ceilings that were only ever tuned against GPU behavior, because CPU
never worked before today.

live evidence, not a guess:

- gpu prompt1 ttft : consistently ~4-8s across several runs
- cpu prompt1 ttft : 46.85s -- ~7-8x slower
- gpu heavy reasoning prompt (tier1 reformat) : ~118-125s
- cpu same prompt : genuine failure at 904s, past even the 777s extended
  hard ceiling -- also ~7-8x, and it still lost
- the self-test cycle's OWN overall watchdog
  (`<coding.cfg.self_test_max_total>`, ~1700s default, computed in
  `coding.init_code`) also aborted a cpu round mid-flight: `[poll_probe]
  probe 4779119 exceeded 1700s total budget : aborting` /
  `[self_test] complete : ... : 1/2 passed`
- cleaner same-session, same-model, back-to-back pair [ cpu's cycle
  completed, gpu's started immediately after, both against
  `M7XXVGY:AH6BYCA` ] : prompt1 [ simple literal ] cpu=48.96s gpu=4.66s
  -> **~10.5x** ; prompt3 [ simple literal, same shape as prompt1 ]
  cpu=63.23s gpu=6.75s -> **~9.4x** -- consistent with each other,
  tighter than the cross-run ~7-8x estimate above. prompt2 [ the
  reasoning/tier1-reformat prompt ] is NOT a clean hardware comparison
  the same way : cpu=88.22s vs gpu=124.15s ttft in this same pair -- gpu
  came out SLOWER here, because reasoning-trace length varies per run
  [ sampling, no fixed seed ] and dominates that prompt's timing more
  than raw throughput does. this is the concrete case the seed-sync idea
  below exists to fix -- without it, prompt2-class timings aren't
  comparable across backends at all, only prompt1/prompt3-class ones are

so it's not just the two `coding.handler.http_timeout` ceilings (soft
127s, hard `<coding.http-timeouts.request-completed> // 780`) -- the
whole chain is undersized for cpu: soft ceiling -> hard ceiling ->
overall cycle watchdog -> the self-test-retry wait-ceiling fix landed
the same day (`src/coding.helper.trigger_backend_self_test`), which
reuses `self_test_max_total` as its own basis and therefore inherits
the same problem.

## why not just multiply everything by a fixed number

considered and rejected: tripling (or any fixed multiplier) either
undershoots real CPU behavior (a flat ratio doesn't hold across
prompt types -- observed ~7-8x here, but this is one model, one CPU
config) or, if picked generously, needlessly dilates GPU's already
well-tuned, tight failure-detection window for no reason. GPU and CPU
need their own ceilings, not one shared inflated constant.

## the better approach (user's idea, 2026-08-26)

measure tokens/second LIVE, while a round is still in progress, instead
of hardcoding any ratio:

- the async streaming client already has per-request chunk-arrival
  visibility [ confirmed live : "stream is alive [chunks=420]" in
  `coding.handler.http_timeout`'s log lines ] -- `src/coding.handler.http_io`
  (`$state->{'last_activity'}`) and `src/coding.async.chunk_handler` are
  the two files to check first for what's already tracked per chunk vs.
  what still needs adding (arrival timestamps + token counts, not just a
  raw chunk count).
- gpu finishes its round well before cpu does [ observed live, every run
  today ] -- so gpu's own t/s for the SAME model is available as a live
  comparison baseline WHILE cpu is still mid-round, not after the fact.
- for precision, sync the random seed between the gpu and cpu self-test
  runs of the same model so token counts/content are directly comparable
  rather than approximately so.
- the ratio can then be used to DYNAMICALLY recalculate/update cpu's
  remaining timeout ceiling for the round still in flight, not just set
  a static per-backend default -- and can factor in configured thread
  count vs. real core count, not just a single scalar ratio.
- user's suggestion: `base.curve.*` (see `src/base.curve.eval.position`,
  `src/base.curve.eval`, `src/base.curve.cancel`) may already provide the
  right interpolation/curve-fitting primitives for this -- worth checking
  before building new math from scratch. related prior art:
  `data/yaml/archive/completed-coding-tasks/base-curve-system.yaml` and
  `data/ai-mem/claude/topic-base-curve-system.md`.

## tps was already half-built, then left dead (checked 2026-08-27)

the self-test cycle this whole system runs on was designed and
completed earlier (`data/tasks/completed/coding-model-self-test-cycle.md`),
whose own step 3 was "compute: tokens_per_second, estimated timeout
multiplier." checking the actual code: only the TTFT half of that ever
got wired -- `coding.self_test.handler.poll_probe` computes real
time-to-first-token per prompt, feeds `coding.self_test.multiplier`
(rolling per-model `ttft_p95`, produces a real `multiplier` shown in
`self-test-status`) -- that's the working half, and the "ttft=5.83s"
style lines in the live logs come from it.

the tokens_per_second half was never wired at all. grepped the whole
`src/` tree for `\btps\b`: the ONLY hit is
`coding.self_test.archive:21` -- `$store->{'tps'} = $result->{'tps'}
// 0;`. the archive slot exists, gets written to the per-model/per-
epoch stats tree every self-test cycle, and nothing anywhere computes
a real value for `$result->{'tps'}` -- it has always silently stored
`0`. so the storage + consumer side (archive struct,
`coding.self_test.cmd.self-test-status` could easily add a column) is
already there and doesn't need building -- what's missing is purely
the producer: actually counting tokens generated over elapsed time
during a probe and setting `$result->{'tps'}` in
`coding.self_test.handler.poll_probe` before it reaches the archive
call. that's the concrete starting point for the live t/s measurement
in "the better approach" above, not something to design from scratch.

## relation to the "per-model statistics" direction

raised the same session, separately: this live t/s measurement is the
concrete first implementation of that broader per-model-statistics
direction, not a separate thing. the per-backend hash-keyed state
pattern already established today across `coding.helper.
trigger_backend_self_test`, `coding.helper.self_test_guard_watcher`, and
the earlier model-path dependency work is the same substrate a
per-model/per-slot statistics store would need -- generic by backend/
slot id, not hardcoded gpu/cpu. see the "future: generalized multi-slot
/ multi-model support" section in
`data/tasks/coding-cpu-and-hybrid-offload-path.md` for the related
multi-slot scoping already captured.

## scope (not yet broken into concrete steps -- needs its own design pass)

1. instrument live t/s tracking in the streaming path (chunk timestamps
   + token counts, likely in `coding.handler.http_io` /
   `coding.async.chunk_handler`).
2. expose a per-backend, per-round t/s figure derivable mid-round, not
   only after completion.
3. investigate `base.curve.*` for reuse before building new
   interpolation/scaling math.
4. use the derived ratio to set/adjust, per backend: the self-test
   per-request soft ceiling, the http hard ceiling
   (`coding.handler.http_timeout`'s `<coding.http-timeouts.request-
   completed>`), and the overall cycle watchdog
   (`<coding.cfg.self_test_max_total>`) -- all three, not just one,
   since they're the same underlying problem observed at three different
   layers.
5. decide static-per-backend-default vs. genuinely-dynamic-mid-round
   rescaling -- the user's framing suggests the latter is the real goal
   (recalculate cpu's remaining ceiling while it's still running, once
   gpu's baseline is available), which is more involved than a one-time
   backend-aware default.

## second live reproduction + "stuck vs slow" framing (2026-08-27)

live-verifying the just-landed `coding-self-test-true-parallelization`
fix reproduced the exact same failure shape as the first evidence
above, one day later, different probe id: cpu prompt2 soft-ceilinged at
127s, extended once to the 777s hard ceiling ("stream is alive
[chunks=399] : extending to full 777s in place"), then STILL hit
"genuine failure after 904 seconds [ceiling=777, stream_alive=1]" --
note `stream_alive=1` logged AT THE MOMENT of failure. the retry also
timed out, and the round's own overall watchdog then fired: `[poll_probe]
probe 5709741 exceeded 1700s total budget : aborting` / `[self_test]
complete : ... : 1/2 passed`. same pattern as probe 4779119, confirming
this isn't a one-off.

the parallelization fix's value showed live in the same run: gpu
finished its full 3/3 pass in ~24s total while cpu was still deep in
this retry/timeout cycle -- gpu was NOT held hostage behind cpu's slow,
ultimately-aborted round, which is exactly what that fix was for.

the user's framing of the deeper fix, prompted by this run: timeouts
should distinguish STUCK (no progress -- catch fast) from SLOW (progress
continuing, just taking longer -- let it run, potentially a very long
time or effectively unbounded). especially relevant for CPU-only /
remote / background deployments with smaller models, where only
eventual completion matters, not wall-clock duration -- "a user can go
to sleep and return in a few hours." per the user: "we are almost
already" doing this -- correct, and reading the actual code confirms
exactly where the existing mechanism stops short of it:

- **`coding.handler.http_timeout`'s soft->hard extension is ONE-SHOT,
  not repeating.** `stream_alive` (chunks flowing within the 77s stall
  window) already gates the soft-ceiling extend at line ~64
  (`if ($stream_alive and $ceiling_used < $hard_ceiling)`), but the
  moment `$ceiling_used` reaches `$hard_ceiling` that condition can
  never be true again, so the SAME stream-alive check that justified the
  first extension is computed again at the failure log line (`stream_alive=1`
  printed right there, see live evidence above) and then simply
  ignored. the fix this task's "better approach" section already
  proposes (dynamic t/s-based rescaling) would help, but the simpler,
  more directly-aligned-with-the-framing fix: keep extending
  `$ceiling_used` by another `$hard_ceiling`-sized (or configurable)
  window EVERY time `$stream_alive` is true at trip time, with no cap on
  the number of extensions -- the 77s stall window (`coding.handler.http_io`,
  re-armed per chunk) remains the only thing that can actually kill a
  live request. this turns "hard ceiling" into what it already almost is
  in spirit (a re-check interval), not a true ceiling.
- **`coding.self_test.handler.poll_probe`'s `max_total` watchdog
  (~line 38) has NO liveness check at all** -- it's `$elapsed > $max_total`
  on wall-clock time alone, by explicit design ("bounded, never
  unbounded... a state machine phase with no ceiling is an unbounded
  wait wearing a costume"). that design comment is correct for a
  genuinely-stuck phase, but the same phase can be legitimately still
  producing tokens through `http_timeout`'s own re-checks the whole
  time -- this watchdog currently can't tell the difference and aborts
  a productive round exactly like a hung one. same fix shape: gate the
  abort on stream liveness (reachable via `$state->{'http_state'}`),
  not on elapsed time alone.

**not implemented, deliberately** -- this is safety-critical watchdog
machinery with a documented history of drifting out of sync across its
several layers (see `[[feedback-check-existing-safety-nets-before-adding-new-one]]`),
same caution that applied to the parallelization task. needs its own
task file with a full audit pass (all callers/assumptions of
`max_total` and the http hard-ceiling, same rigor as the parallelization
task got) before any code changes, not a quick patch. captured here as
the concrete direction + exact code citations so that audit doesn't
have to re-derive them.

not urgent -- self-test on CPU degrades gracefully today (partial
results via its own internal per-prompt retry-after-failure, not a
crash or hang), filed same day as the CPU spawn fixes that made this
gap observable at all.

## audit verdict (2026-08-27, kimi k2.7)

**the two gaps from "## second live reproduction" are real and still present
in the current source.** independently re-read the files named below; nothing
here relies on the earlier summary.

- `src/coding.handler.http_timeout:64` (`if ($stream_alive and $ceiling_used <
  $hard_ceiling)`): the extension branch is **one-shot**. once the soft ceiling
  has been escalated to `$hard_ceiling` (line 95), the next trip computes
  `$stream_alive` again (lines 60-62), logs it (`stream_alive=1` in the
  genuine-failure line at 107-116), and then falls through to hard-fail because
  `$ceiling_used == $hard_ceiling`. the stall watcher (`coding.handler.http_io`,
  re-armed per chunk) is already the right liveness signal; this branch just
  stops listening to it after the first extension.

- `src/coding.self_test.handler.poll_probe:38-39` (`$elapsed > $max_total`):
  the overall cycle watchdog has **no liveness check at all**. it reads
  `<coding.cfg.self_test_max_total>` (~1700s by default, computed once in
  `coding.init_code:39-62`) and aborts purely on wall-clock elapsed time. the
  comment at lines 26-37 is explicit about the "bounded, never unbounded"
  design and cites the need to stay in sync with
  `coding.handler.verify_inference_startup` because of the premature-resume
  race fixed in commit `5d32f8783` (the source comments call it `4c3cf0e73`,
  but that hash does not exist in this repo; `git log --all --grep` resolves
  the incident to `5d32f8783`).

**other elapsed-time-only ceilings found in the same chain** (all read
independently; this is the full grep sweep, not just the candidate list):

- `src/coding.handler.verify_inference_startup:53-83`: the fallback queue-
  resume deferral is itself a wall-clock ceiling in disguise. it counts
  `queue_resume_defer_count` up to `defer_ceiling = int((self_test_budget +
  120) / 2)` and reschedules every 2s, so it fires roughly
  `self_test_budget + 120` seconds after the server reports ready. it does
  not look at whether the self-test probe is still producing chunks. this is
  a direct dependency: if `self_test_max_total` is replaced by a liveness-
  aware model, this fallback becomes the new premature-resume timer and will
  force-open the task queue mid-self-test.

- `src/coding.self_test.handler.poll_switch:22-29,241-283,326-355`: the
  switch-test-restore state machine caps each phase at
  `<coding.cfg.switch_model_max_wait> // 300` seconds with the same
  `$elapsed > $max_wait` pattern and no probe-liveness check. the `testing`
  phase (lines 264-283) is the one that matters here: a self-test that
  legitimately runs past 300s is treated as a timeout and the state machine
  falls through to restore. the switching/restoring phases wait for server
  process readiness (pid change + `ready` status), not request progress, but
  they should still be reviewed for generous backend-aware defaults.

- `src/coding.handler.defer_seed_restart:42-54`: a 120s hard ceiling on
  waiting for the backend to become idle before a cat-test seed-retry
  respawn. it checks `lock`/`queue` (line 59) but not whether the lock holder
  is still making progress, so a live-but-slow self-test can cause it to
  give up on the retry.

- `src/coding.helper.trigger_backend_self_test:212-213,281-304`: the safety-
  net timer for guard-contention retries uses `self_test_retry_max` or
  `self_test_max_total` seconds with no liveness check. this one is
  *downstream* of `poll_probe`: it only fires if the per-backend guard slot
  never clears. under a liveness-aware `poll_probe` it would correctly never
  fire for a slow-but-live probe, but its derivation and log text should be
  updated so it is explicitly documented as a "guard never cleared" net, not
  a "self-test took too long" net.

**places checked and found clean (already liveness-aware or not a ceiling):**

- `src/coding.handler.http_stall_timeout`: fires only on genuine silence,
  independent of total elapsed time.
- `src/coding.handler.http_data_start_timeout`: fires only if no first chunk
  arrives, which is the right ttft/connection-acceptance signal.
- `src/coding.detect_stream_repetition` + `src/coding.handler.http_io_parse_line`:
  catches content-degenerate streams that are technically alive.
- `src/coding.async.http_client:167-172` and `src/coding.async.request:80-82`
  are timer *arms*, not decision gates; the actual elapsed-time decisions
  live in the handlers above.

**cross-dependency / "what would break" assessment:**

the critical coupling is between `poll_probe`'s `max_total` and
`verify_inference_startup`'s fallback-resume ceiling. commit `5d32f8783`
explicitly fixed the same class of bug: an independently-derived ceiling
fired before self-test had actually concluded. if `max_total` becomes
liveness-aware (or unbounded), the fallback at `verify_inference_startup`
must be updated in the same pass or it becomes the new early-fired ceiling.
`trigger_backend_self_test`'s guard-wait safety net also derives from the
same number but is semantically a hung-guard net, so it is safe to leave it
as a long absolute cap as long as its purpose is re-labeled.

`poll_switch`'s `testing` phase `max_wait` is independent of
`self_test_max_total` and will become the effective hard cap for any
`coding.self-test-run` switch-test-restore path once self-tests can exceed
300s. that cap needs to be either tied to the same liveness signal or given
a backend-aware default well above CPU worst case.

`defer_seed_restart`'s 120s wait is a secondary effect: a seed-retry path
triggered by a cat-test failure will currently give up if the backend is
busy with a slow-but-live probe.

`coding.cmd.round-progress` (line 68) and `coding.cmd.round-time` (line 26)
read `$state->{'timeout_ceiling'}` as a display denominator. if that value
becomes dynamic or unbounded, the percentage/bar math will need to handle
"no fixed ceiling yet" gracefully instead of showing a stale or overflowing
progress ratio.

there is no other code that assumes the current `self_test_max_total`
(~1700s) fires within a bounded window for correctness. real tasks are gated
by `queue_paused` during self-test; the risk is premature resume, not
permanent stall. the stall watcher and repetition checker already cover
genuine hangs at the per-request layer.

**absolute outer cap : resolved design (2026-08-27, user + claude)**

a flat per-backend config number was the first idea, but rejected for the
same reason a flat cpu/gpu ratio was rejected earlier in this file: it
doesn't account for model size or per-model speed, so it's either too
tight for a big/slow model or needlessly loose for a small/fast one.

**decided approach: auto-mode, derived live from measured tokens/second,**
not a static config number:

- `cap = (context_size / live_tps) * margin` — the theoretical time to
  fill the model's full available context at its currently-observed
  generation rate, plus a safety margin (e.g. +30%, exact value tunable).
  this is deliberately generous, not a tight bound -- its only job is to
  scale the last-resort backstop with real backend throughput and model
  size instead of guessing a fixed number, not to closely track normal
  request duration (that's requirement 1's job, the per-request extension
  interval -- keep these two layers conceptually separate, don't conflate
  them in implementation).
- **measure tps from time-since-first-token, not time-since-request-start.**
  TTFT is a separate, already-tracked signal
  (`coding.self_test.multiplier`'s `ttft_p95`) -- mixing it into the tps
  denominator understates throughput and undersizes the cap for any model
  with slow-first-token-but-fast-steady-state behavior.
- **minimum-sample noise floor before trusting a live estimate**, same
  reason `ttft_p95` requires enough samples before use: tps computed from
  only the first few post-TTFT chunks is noisy. fall back to a static
  per-backend default cap (the originally-proposed config knob, now a
  fallback rather than the primary mechanism) until the live estimate
  stabilizes, then let the live value take over.
- **must FREEZE on stall, never recompute through one.** this is the
  critical correctness requirement, flagged by the user before any code
  was written: if tps keeps recalculating using `elapsed-since-request-
  start` (or since-first-token) as the denominator while chunks stop
  arriving, elapsed keeps growing with no new tokens, driving measured
  tps toward zero -- which drives `context_size / tps` toward INFINITY.
  that's exactly backwards: a stalled stream should make the cap
  irrelevant (the stall watcher kills it first), never balloon it. the
  fix: gate recalculation on the SAME liveness signal the stall watcher
  already uses (`chunks_received`, `last_activity`,
  `stall_timeout_sec` in `coding.handler.http_io`'s state) -- while live,
  keep updating the rolling tps estimate and the derived cap; the instant
  that signal says stalled, freeze both at their last good value and let
  the (short, per-chunk) stall watcher do its job independently. the two
  mechanisms must never fight each other.
- **connects directly to the dead `tps` field found in this file's
  "tps was already half-built" section** (`coding.self_test.archive:21`,
  `$store->{'tps'} = $result->{'tps'} // 0`) -- this design finally gives
  that field a real producer and a real live consumer, not just an
  archive column nobody reads. the archived per-model/per-backend history
  could additionally seed an initial cross-backend cap estimate before a
  live sample exists this round (eg use gpu's last known tps for the same
  model as cpu's starting-point default), the same cross-backend-baseline
  idea already proposed in "the better approach" section above -- but
  that's a refinement, not required for a first working version.

the exact margin percentage, minimum-sample threshold, and static
fallback-default values are implementation-time tuning, not blocking
design decisions.

**what implementation actually requires (none of this is done yet):**

0. **new: live tps tracking + auto-cap derivation.** the producer half of
   the "absolute outer cap" design above -- doesn't exist yet anywhere.
   needs: a per-round accumulator (token/chunk count + first-chunk
   timestamp, likely alongside the existing chunk-arrival tracking in
   `coding.handler.http_io`), a rolling tps calculation gated on the
   minimum-sample floor, and the `context_size / tps * margin` derivation
   exposed somewhere both `http_timeout` and `poll_probe` (items 1 and 2
   below) can read it from. must freeze on the same liveness signal used
   for stall detection, per the design above -- this is the one part of
   this requirement list that's new construction, not a modification of
   existing ceiling logic.

1. `src/coding.handler.http_timeout:64` — replace the one-shot
   `$ceiling_used < $hard_ceiling` condition with a repeating extend: as
   long as `$stream_alive` is true at trip time, push the deadline out by
   another window (e.g., another `$hard_ceiling` or a new config
   `coding.cfg.round_liveness_extend_sec`) and re-arm the timer. enforce
   the absolute outer cap from item 0 here. also decide whether the
   task-based branch (lines 65-79) should keep using
   `coding.async.round_soft_restart` or also extend in place; if it stays,
   document why self-test and tasks differ.

2. `src/coding.self_test.handler.poll_probe:38-39` — before the `$elapsed >
   $max_total` abort, read liveness from `$state->{'http_state'}`
   (`chunks_received`, `last_activity`, `stall_timeout_sec`) and skip the
   abort while the current request is still alive. enforce the absolute
   outer cap from item 0. the `watchdog_abort` path at lines 44-55 should
   stay, but only fire for stalled/dead probes.

3. `src/coding.handler.verify_inference_startup:53-83` — the fallback
   queue-resume ceiling must be kept in sync with the new self-test bound.
   if `self_test_max_total` becomes liveness-aware / unbounded, this
   fallback cannot remain a simple `self_test_budget + 120` wall-clock
   counter; it must either check the same liveness signal or derive from
   the same large absolute cap. this is the highest-risk touch point after
   `poll_probe` itself because of the `5d32f8783` precedent.

4. `src/coding.self_test.handler.poll_switch:22-29,264-283` — the `testing`
   phase `max_wait` must be made liveness-aware (check the probe's
   `http_state` liveness) or at least given a backend-aware default that
   does not cap CPU self-test at 300s. the switching/restoring phases
   should be reviewed for generous defaults but can likely keep wall-clock
   caps because they wait on process readiness, not streaming progress.

5. `src/coding.handler.defer_seed_restart:42-54` — the 120s idle-wait ceiling
   should become liveness-aware: if the backend lock is held by a live
   self-test probe, wait until the probe completes or stalls rather than
   giving up at a flat 120s.

6. `src/coding.helper.trigger_backend_self_test:212-213,281-304` — keep the
   safety-net timer but update its derivation and log text so it is clearly
   a "guard slot never cleared" fallback, not a generic self-test duration
   limit. under a liveness-aware `poll_probe` it will only fire for genuine
   guard hangs, which is the desired semantics.

7. `src/coding.self_test.run:40` and `src/coding.self_test.async_probe:18` —
   the default per-request `timeout` of 127s becomes the initial trip
   interval, not a hard cap, once requirement 1 lands. decide whether to
   keep the literal default or derive the first trip from the same backend-
   aware base used for the extend window.

8. `src/coding.cmd.round-progress:68` and `src/coding.cmd.round-time:26` —
   update the progress displays to handle a dynamic or unbounded
   `timeout_ceiling` (e.g., show elapsed time and liveness state rather than
   a fixed percentage) so they do not mislead once the hard ceiling stops
   being a fixed number.

**existing test coverage a future implementation would need to update or
extend:**

- `bin/test-scripts/test-coding-self-test-retry.pl` exercises the guard
  contention / watcher / safety-net path but stubs time at a fixed value
  and does not simulate a streaming probe. it would need new scenarios:
  slow-but-live probe does not trigger the safety-net timer, and
  `verify_inference_startup`-style fallback does not resume the queue
  prematurely.
- no standalone harness currently covers `coding.handler.http_timeout`'s
  soft/hard extension logic or `coding.self_test.handler.poll_probe`'s
  `max_total` watchdog. a new test file (or extension of the existing
  harness) should simulate chunk arrival timestamps and confirm that live
  streams extend while stalled streams still fail fast.

## do NOT touch

promoted from "places checked and found clean" above -- these are
confirmed already correct, don't modify them as part of this task:

- `src/coding.handler.http_stall_timeout` -- already the right
  genuine-silence detector, independent of total elapsed time.
- `src/coding.handler.http_data_start_timeout` -- already the right
  ttft/connection-acceptance signal.
- `src/coding.detect_stream_repetition` / `src/coding.handler.http_io_parse_line`
  -- degenerate-content detection, orthogonal to timing.
- `src/coding.async.http_client:167-172` / `src/coding.async.request:80-82`
  -- these are timer *arms* only, not decision gates; leave them alone,
  the actual elapsed-time decisions live in the handlers this task
  changes.

also out of scope, different systems entirely, don't conflate:

- `coding.routing.select_backend` / `coding.cmd.switch-model` /
  `coding.handler.spawn_smart` -- the OTHER "auto" concept in this
  codebase (backend selection for spawning/routing, see
  `coding-startup-auto-backend-selection.md`), unrelated to timeout
  ceilings.
- `coding.self_test.multiplier`'s `ttft_p95` tracking -- read from (per
  the tps-noise-floor design above), never modified by this task.

## validation

1. `bin/dev/ptd -c` on every changed file.
2. `bin/test-scripts/test-coding-self-test-retry.pl` must still fully
   pass -- it's the harness for the just-landed parallelization work and
   exercises the same `poll_probe`/guard machinery items 1-2 touch. a
   regression here would mean the liveness changes broke per-backend
   guard semantics, not just timeout semantics.
3. new standalone test file needed (style of the existing harness,
   execution-free -- stub time/chunks, no live zenka), covering at
   minimum:
   - a live stream (chunks keep arriving) extends past the old flat
     hard ceiling repeatedly, never hard-fails while alive.
   - a stalled stream still fails fast at the short per-chunk stall
     window, NOT at the (now much larger) outer cap.
   - the auto-cap computes correctly from simulated tps once the
     minimum-sample threshold is met.
   - the auto-cap FREEZES (asserted: value unchanged across ticks) once
     a stall is detected, even though elapsed time keeps advancing --
     this is the one behavior that's actively wrong if inverted.
   - before the minimum-sample threshold, the static per-backend
     fallback cap is used, not a garbage/zero live estimate.
   - `poll_probe`'s `max_total` abort fires ONLY for genuinely stalled
     probes in the new version, never for slow-but-live ones.
   - `verify_inference_startup`'s fallback-resume ceiling does not fire
     prematurely once `poll_probe`'s ceiling becomes liveness-aware --
     this is the direct `5d32f8783`-class regression check.
4. no live zenka restart at any point -- validation is standalone-script
   only, same rule as the parallelization task.

#,,,.,,..,,..,,..,,,,,,.,,,.,,,.,,..,,...,..,,..,,...,...,,.,,.,,,..,,,.,,,.,,
#GTSWT26KJKUG37WQCDUWRCX5AUJWQLZATGFYO35FXZEPU3TIEFP6LG6M7QQYTUZLNFPOHYYK5Q2UQ
#\\\|4SW3XWXOEHX4MBJGJSHA57YASGMAJGEEYDAY35Q7IKEQITRIO6M \ / AMOS7 \ YOURUM ::
#\[7]6574P7PWCW7RNF4EDL5FZLUKKTJCHFLMVO6JRODZ4Y75VFECR2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
