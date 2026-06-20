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
  coding.self_test.cmd.status, coding.self_test.cmd.run-now
  — implemented + reviewed this session (two passes: first dispatch
  had fatal bugs, second dispatch fixed all of them, verified on disk).
  status: built, not yet live-tested end-to-end against the real
  inference server.

tier 1 — data/tasks/coding-model-self-test-cycle.md
  status: spec complete, modules implemented (see tier 0). pending:
  live validation run.

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
tier 1: MODULES BUILT — awaiting live end-to-end validation
tier 2: NOT READY — 3 open decisions block dispatch
tier 3: GATED — awaiting tier 2 stability milestone
```

#,,.,,,.,,,,,,,,,,,.,,...,,.,,,..,.,,,,.,,,.,,..,,...,...,..,,..,,,..,,,,,.,.,
#764UTNADO4EVLGFFAXT7DEJYZAX3ODDLVLYZLVTZF4VNL6F4JOX6GSR7T4J3P5F2TQGUJD7WFL4V2
#\\\|F2GX73TJBT73JZIK26VUIIIL3VMF2EWK53AU2WEIU7K5AIAYVRV \ / AMOS7 \ YOURUM ::
#\[7]YQROLXCU3PENZTYDX4BZC74HUERP3E4XWKU2HFKN7JXEWVDCBGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
