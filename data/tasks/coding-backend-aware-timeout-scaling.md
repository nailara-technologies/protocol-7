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

#,,,,,,,,,.,,,,..,..,,,,,,,,.,,,,,.,.,..,,,,,,..,,...,..,,..,,,..,,.,,,,,,,.,,
#HSGNSZRA6Y4YCUHF52QRIRN4HWCKW2TOKC6ELUJ2YQUIIVMMICIRKVPWROSGO7YB62L5JCRPLRADM
#\\\|TT3MYXDLWUEW74DBN6HZBDWZX7IXT3G4O27DG36MFH7WPYL2BVA \ / AMOS7 \ YOURUM ::
#\[7]GAVUHWDCKRATPVBDO6JDAR5AHXC2BLBG3EVVBCQOCET5HQDGOEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
