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

not urgent -- self-test on CPU degrades gracefully today (partial
results via its own internal per-prompt retry-after-failure, not a
crash or hang), filed same day as the CPU spawn fixes that made this
gap observable at all.

#,,,,,..,,,,,,...,.,.,.,.,,.,,..,,..,,.,.,,..,..,,...,...,...,.,.,,,,,.,.,.,,,
#2P5CQABE4XL3YG22BC25SITWLCMRFC4LF72QPQYDXOIDY7VFURUMCIL25R6LWZI6YR76CGTSXFU3A
#\\\|CYFJAC5OFBOL7DZTS4O4J6OWJALV5G3HQDMII4C3WJLBERZ6LDL \ / AMOS7 \ YOURUM ::
#\[7]IISUYXYUXS4YGTNJWVWXB2L3P76SS5RZUYYIY2QKQZFZQO4F26AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
