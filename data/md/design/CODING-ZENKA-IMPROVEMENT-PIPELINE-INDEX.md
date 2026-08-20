## [:< ##

# coding zenka improvement pipeline — root index

session: 2026-06-20. this document is itself an instance of the
principle it organizes: bounded nesting makes completeness checkable,
and a catch-all guarantees nothing in the set below goes stale or
forgotten. read alongside `FIELD-COHERENCE-SYNTHESIS.md`, which already
does the same job for the older topology/vision document set — this
index is the same role applied specifically to the concrete,
implementable coding-zenka pipeline that grew out of tonight's session.

## the pipeline, in dependency order

```
tier 0 (LANDED, 2026-06-20):
  src/X-11.cmd.set_geometry, X-11.cmd.move-window,
  X-11.handler.screen_change — WM.update before/after ConfigureWindow
  fix; confirmed live by user. not gated, already shipped.

  src/coding.tools.http_inference_client, coding.self_test.run,
  coding.self_test.evaluate, coding.self_test.follow_up,
  coding.self_test.archive, coding.self_test.multiplier,
  coding.self_test.cmd.self-test-status, coding.self_test.cmd.self-test-run
  — implemented this session across three real passes: first dispatch
  had fatal bugs (wrong call syntax, hashref-as-object bugs, closure
  mismatch); second dispatch fixed those but two more bugs only
  surfaced under a real live run: monitor_inference_startup called
  self_test.run before $server->{'model'} was set (silent no-op every
  time), and max_tokens=128 left a reasoning model's answer empty
  (entire budget spent on the <think> trace). both fixed and
  RECONFIRMED LIVE 2026-06-21: "2/2 passed", clean [self_test]-prefixed
  logging added throughout. also live-confirmed: extracting an inline
  helper sub via the extract-inline-subs coding-task template works
  correctly end-to-end (coding.self_test.multiplier's _percentile_95).

  open, non-blocking: coding.self_test.follow_up hit one live http_500
  from the inference server — diagnostic-explanation path only, not
  core pass/fail; worth a look, not urgent.

tier 1 — data/tasks/coding-model-self-test-cycle.md
  status: DONE, including switch-to-a-non-loaded-model + restore, live-
  confirmed end to end 2026-06-21: "self-test complete for
  KVRBYTQ:BZHYASQ: 2/2 passed" while IXNBXVI:U2XBEXQ was loaded,
  correctly switched/tested/restored. async state machine via
  event.add_timer (no blocking poll), deferred-reply pattern copied
  from coding.cmd.ask-reply, dependency-object blocking reused from the
  existing GPU/CPU server-readiness mechanism.

  along the way, found and fixed THREE real pre-existing bugs in core
  switch-model infrastructure (not scoped to self-test, but only
  surfaced by exercising it live): (1) shared global pending-state in
  switch_model_reply got clobbered by overlapping switch-model calls —
  fixed by passing checksum/name/backend through base.route.add's
  existing 'params' plumbing instead; (2) <inference.model.amos_id>
  (what monitor_inference_startup/inference-status actually label the
  running model from) was never updated by any switch path — fixed by
  updating it from every successful spawn; (3) the default 'auto'
  backend mode updated neither per-backend model_id field at all (only
  literal 'gpu'/'cpu'/'both' matched) — fixed alongside (2). readiness
  detection itself also hardened: keys off a CHANGED pid rather than
  the model_id label, since the label updates earlier than the actual
  process swap completes.

  FIXED + LIVE CONFIRMED: self-test no longer auto-fires redundantly
  during a self-test-driven switch (coding.self_test_switch_in_progress
  suppression flag, checked by monitor_inference_startup). a full
  cycle now shows exactly one self-test execution, not two.

  still open: configurable test suites (the calibration prompt list is
  still hardcoded to the arithmetic+riddle pair).

  also flagged: cross-model assertion (a known-good model judging
  another model's self-test results, since an incoherent model likely
  can't reliably
  assess its own incoherence) — speculative, phase 3+, not designed.

tier 1.5 — data/tasks/coding-task-model-pinning.md
  status: DONE, live-verified via direct /proc/<pid>/cmdline inspection
  (not label/self-test trust alone). was genuinely half-built (a
  :model:CHECKSUM: marker was parsed but never enforced), and the
  upstream intake parser was silently destroying the marker before it
  ever reached working code. fixed: the intake collision, the missing
  enforcement (new coding.task.ensure_model_pinned + a
  model_checksum_loaded dependency type, hooked into coding.task.execute
  via the same get_job_data+move_job('depending') re-defer pattern
  coding.callback.http_error already uses), and a deep pre-existing bug
  in coding.handler.await_resources (a :twin:-handover watchdog that
  never retired itself and got re-armed on every coding.reload,
  silently substituting the boot-default model during any switch while
  showing a correct-looking label — this is what made earlier passes
  at this LOOK done when they weren't). still open, deliberately
  deferred per the user: automatic batch-grouping of multiplexed tasks
  by pinned model, to avoid switch overhead — a latency optimization,
  not required for functional correctness.

tier 2 — data/tasks/coding-self-error-processing-cycle.md
  status: design captured, marked NOT READY TO DISPATCH. three open
  decisions block dispatch: exact error-surfacing hook point in
  coding.async.state_machine, the confidence-threshold mechanism for
  promotion, the format of the shared assertion-criteria rubric.
  depends on: tier 1 being live (its motivating case — the self-test
  module bugs — came from tier 1's own implementation).

tier 3 — data/md/design/CODING-CHANGE-ACCOUNTING-ARCHITECTURE.md
  status: PLANNED, GATED. depends on: tier 2 stable in production with
  a non-trivial confirmed-pattern library. contains, as of this
  session: deferred success accounting, two-stage graphical→math
  representation, dynamic buffers (reuses tier 1's percentile_95
  multiplier pattern), the self-scaling -N..+N priority queue with
  task-file+subtask-block entries, BASE32 C25519 addressing, and the
  catch-all no-stale-reference guarantee this index itself reuses.

lateral, not strictly sequenced:
  data/md/design/TASK-CUBE-CONSENSUS-ARCHITECTURE.md — BFT consensus
  + clocked rotation scheduling. tier 3's queue topology section
  extends this doc's rotation primitive with the urgency/priority
  mechanism it didn't originally specify. read together.

  data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md +
  read-me/documentation/dev/NRT.NRD.asc — resource/token economics.
  tier 3 reuses NRT's epoch-scoped archival shape pattern (via tier 1,
  which originated it for self-test results).

  data/yaml/reasoning-templates/demystification-through-correspondence.yaml
  — not part of the implementation chain, but the discipline this
  whole session's design work (including this index) was produced
  under: every claim above should hold with no residue if translated
  to plain engineering terms. self-check this index periodically
  against that template.

  data/md/development/RESONANCE-FIELD-EMERGENCE.md — the vision-level
  material this pipeline's concrete mechanisms instantiate (resonance
  as structure×throughput, the recursive parent-as-sum-of-children
  principle that grounds "completeness is a parent property insured
  by bounded nesting" above). not gated, not dispatchable — pure
  context for why these mechanisms take the shape they do.
```

## the catch-all this index itself provides

```
if a future session creates a new doc that logically belongs in this
pipeline and forgets to add it here: that is exactly the stale-
reference failure mode tier 3 describes. the reassertion mechanism for
THIS document is manual but cheap — any future read of this index
against a `find data/tasks data/md/design -newer <this file>` should
surface candidates. this index does not yet have tier 3's automated
catch-all (it can't — tier 3 doesn't exist as running code yet); it is
currently a hand-maintained stand-in for what tier 3 will eventually
automate for arbitrary code change-tracking. when tier 3 ships, revisit
whether this index itself should become one of its tracked groups.
```

## status tracking (update this section as tiers progress)

```
tier 0: LANDED
tier 1: DONE — live-validated 2026-06-21, "2/2 passed"
tier 2: NOT READY — 3 open decisions block dispatch
tier 3: GATED — awaiting tier 2 stability milestone
```

#,,..,.,,,,,.,,,,,...,.,.,.,.,,,,,,,,,,..,..,,..,,...,...,...,...,,,,,...,,,.,
#GTXY44EK7EG4TSPVR7CMJIPXNPDQXBWSTWGESQVBFVAUUF2YNOICQVIACLMYWS43TNASFJSA4AOSU
#\\\|LCPFGPTZPFFTEY76KUITF43MSMFNDKDZWA5LQ74DZFXLVXG427X \ / AMOS7 \ YOURUM ::
#\[7]NRW6SKIEQPOG5L3XORBJSXX5IKBR4IYHNAEXOXVNC4O2GZC6TABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
