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
  modules/X-11.cmd.set_geometry, X-11.cmd.move-window,
  X-11.handler.screen_change — WM.update before/after ConfigureWindow
  fix; confirmed live by user. not gated, already shipped.

  modules/coding.tools.http_inference_client, coding.self_test.run,
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
  status: DONE for the core calibration cycle (live-validated).
  EXTENDED, NOT YET IMPLEMENTED (2026-06-21): testing a non-loaded
  model via switch-model + restore, gated on introducing self-test as
  a dependency-object state (reusing the same mechanism that already
  gates GPU/CPU server readiness, not a new poll/sleep loop) so
  regular tasks block correctly during the switch window. also flagged:
  cross-model assertion (a known-good model judging another model's
  self-test results, since an incoherent model likely can't reliably
  assess its own incoherence) — speculative, phase 3+, not designed.

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

#,,,,,,.,,.,,,,..,,,,,,,.,.,.,,,.,.,,,..,,...,..,,...,...,,.,,.,.,.,,,,.,,,..,
#5HSSGJYG76WDNTUPNGJFD33UPYEVELFI7RD7CCBBMIMYL2B2KVFVTFAAJXLF3IKXLSLHICKPKXJW6
#\\\|EFRV5EWUCGRAUV4OMDDZDOWDNRYVHP64YNRL7JUIPVGSSRIZUGT \ / AMOS7 \ YOURUM ::
#\[7]B2UXFN4HXQI4SDFEEQUQUUTBQ7FTWGBP3OHGMENHGU24CR6YZYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
