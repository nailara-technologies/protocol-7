# autonomous model management — design & vision

## core idea

model groups that validate their own composition through observed outcomes,
not human curation. self-organizing selection pressure on the model population:
better models get discovered, tested, proposed, ratified, and integrated
automatically. human role shifts to setting thresholds and reviewing anomalies.

---

## four-layer architecture

```
layer 1 — discovery       new models appear (hf, local scan, remote nodes)
layer 2 — benchmarking    canonical workloads scored per model per capability
layer 3 — consensus       groups ratify membership changes via score evidence
layer 4 — management      on-demand fetch, deploy, zero, replace lifecycle
```

---

## layer 1 — model discovery

already partially implemented:
- `models.local_discover` — scans local paths, detects vision/quant/family
- `invoke-model-recover` — fetches from hf by db metadata or direct id
- `models.registry.*` — central registry with amos7 checksum ids

missing:
- hf api polling for new versions of known model families
- version comparison (detect when a known repo has a newer file)
- automatic trigger: new model found → enter benchmark queue

---

## layer 2 — benchmark suite

### canonical workload types

```
tool_call       ## structured tool invocation, argument parsing accuracy
code_edit       ## edit_file / replace_in_file correctness, no regressions
reasoning       ## multi-step logic, correct conclusion rate
vision_desc     ## image description accuracy vs reference (vision models)
context_retain  ## correct answer after N rounds of conversation
format_comply   ## output follows requested format consistently
```

### scoring

- each workload is a deterministic prompt + expected output or assertion
- score = pass rate over K runs (accounts for temperature variance)
- scores stored per model per workload type in outcomes.json (already exists)
- thresholds per workload type configurable per group
- **multi-parameter, not pass/fail alone (2026-08-27)**: correctness is one
  axis among several — latency (ttft), throughput (tokens/sec), memory
  footprint, and processing speed all feed the same suitability score.
  `base.curve.*` (`src/base.curve.eval.position`, `src/base.curve.eval`,
  `src/base.curve.cancel`) is the intended fitting/interpolation primitive
  for combining them, already flagged as reusable prior art in
  `data/tasks/coding-backend-aware-timeout-scaling.md`. real per-parameter
  signal now exists to feed it: `coding.async.stream_tps` (live tokens/sec,
  landed 2026-08-27) and the `coding.self_test.archive` `tps` field it
  finally gave a producer to (previously dead, `// 0` always) are working
  substrate, not aspirational — this layer no longer needs new
  instrumentation to start from, just the curve-fitting/aggregation on top.
- **the suite itself should improve, not just the model pool**: later
  passes can optimize the canonical tasks/prompts and system messages
  themselves toward broadest success coverage across models, not only
  score models against a fixed suite. a benchmark suite that never adapts
  can systematically favor whichever model happens to match its original
  phrasing — this closes that loop, at the cost of needing suite-version
  discipline (see notes below) to keep score history comparable across
  suite revisions.
- **P7 native-idiom conformance as a first-class dimension of
  `format_comply`**, not just generic output-format matching: does the
  model's code/edits use the project's own native routines and structures
  (`base.*` primitives, swap_subs-aware naming, the P7 macro syntax) rather
  than reinventing them or importing foreign idiom. same lens the kimi
  dispatch style guardrails already apply informally at dispatch time
  (`data/yaml/code-style/CONVENTIONS.yaml`, the kimi-dispatch-workflow
  context template) — this generalizes it into a scored, structural signal
  instead of a per-dispatch reminder.

### shadow evaluation against real tasks, with optional live-apply

a benchmark "task" doesn't have to be synthetic. when a real item from the
task queue is used as the workload — run in parallel/shadow against one or
more candidate models alongside (or instead of) the production model — the
same scoring pipeline applies, AND, if the candidate's result clears both
the quality/correctness threshold and the style-alignment check above, the
result can be applied as the real task's actual output instead of being
discarded as pure benchmark exhaust. turns evaluation traffic into
occasionally-useful production work rather than pure overhead, but needs:
- a clear boundary on which task types are safe to shadow this way (never
  anything with side effects that can't be produced twice — file writes,
  network calls with side effects — without careful idempotency handling)
- the group's existing quorum/ratification machinery (layer 3) gating the
  apply decision, not a silent auto-swap
- this is squarely a layer 2 + layer 3 interaction, not a new layer

### existing foundation

- `outcomes.json`, `get_statistics`, `check_cache_first` — already tracking
  per-model success rates in coding zenka
- extend to structured suite: add workload_type field, canonical task ids
- `llm.service.consensus_vote` — already extracted, untested — drives
  layer 3. **2026-08-27**: confirmed still local-only and still hardcoded
  to three specific small models (Qwen2.5-7B, Mathstral-7B, Aya-23-8B) that
  don't correspond to anything in the current live model registry (`p7c
  coding.list coding-models` — ~87 real entries, none matching). this is
  the concrete trigger for revisiting this doc — todo `Q5D` flagged the
  README overclaiming remote-API participation in this voting (fixed
  separately, see README's Multi-Model Consensus bullet), and the natural
  follow-up question — "just update the hardcoded list" — is exactly what
  this whole document exists to avoid doing again. the fix for
  `llm.service.consensus_vote`'s model list is THIS system landing, not
  another static edit.
- `coding.async.stream_tps` + `coding.self_test.archive`'s tps field —
  landed 2026-08-27, real per-model/per-round throughput signal, feeds the
  multi-parameter scoring above directly
- **`models.decision.*` / `models.statistics.invocation_tracking`, found
  2026-08-27 and previously missing from this table entirely.** real,
  shipped code, NOT the same thing as this doc's proposed benchmark
  harness — it's the *consumer* end: `models.decision.recommendation_base.
  calculate_composite_score` combines `success_rate`/`latency`/`cost`/
  `availability` (fixed weights 0.4/0.3/0.2/0.1, confirmed by direct read)
  from fields that must already exist on a model's registry entry;
  `models.decision.recommendation_engine.get_model_recommendations`
  genuinely iterates the full ~87-entry registry (not just models with
  history), but an untested model just silently defaults toward a
  near-zero score rather than being flagged unknown. **the producer side
  is dormant**: `models.statistics.invocation_tracking.record_invocation`
  is reachable from exactly one place in the entire codebase — its own
  command entry point (`models.cmd.record_invocation`) — nothing in real
  task-completion flow calls it automatically, confirmed via full
  caller-grep. `models.cmd.recommend` is live and callable but its output
  is only as meaningful as the currently-unpopulated stats feeding it. the
  ~961-line architecture doc this was built from
  (`data/asc/what-AI-thinks/markdown-form/protocol7/architecture/
  models-zenka-complete-architecture.md`) matches the shipped code's shape
  closely but doesn't mention this dormancy anywhere. **implication for
  layer 2 / topic 1 below**: don't reuse `models.decision.*` as the
  benchmark runner, but its composite-score/weighted-dimension pattern is
  a second real precedent (alongside `iteration.score_result`) worth
  mirroring, and landing the benchmark harness would REVIVE this cluster
  by finally giving `record_invocation` real data to feed on, not
  duplicate it.

---

## layer 3 — consensus groups

### group composition

a group is a set of models with defined roles:
```
coordinator     ## routes tasks, aggregates results (lightweight, fast)
specialist[]    ## domain-specific models (code, vision, reasoning, ...)
arbiter[]       ## tie-breaking, quality assessment
```

### membership changes via evidence

a model proposes or is proposed for membership change:
1. benchmark scores above threshold for target role
2. proposal submitted to existing group with score evidence
3. group votes — existing members assess the evidence, not the raw output
4. 4-crossing consent protocol (from harmonic math work) gates ratification
5. change takes effect only after quorum

this is a much easier consensus problem than agreeing on outputs — the group
agrees on numeric scores and thresholds, not on subjective quality.

### self-assessment loop

groups periodically re-evaluate their own members:
- if a member's rolling score drops below threshold → demotion proposal
- if a better model exists for the role → replacement proposal
- group can shrink, grow, or swap members autonomously within policy bounds

---

## layer 4 — on-demand model lifecycle

builds directly on invoke-model-recover work:

```
present     file exists, size > 0     [ active ]
zeroed      file exists, size = 0     [ reclaimed, re-downloadable ]
missing     file does not exist       [ not yet fetched ]
quarantine  failed benchmark, held    [ not deployed until re-tested ]
```

lifecycle transitions:
```
discovered → benchmark_queue → benchmarked → candidate → active
active → demoted → zeroed          (lru pressure or score drop)
active → quarantine → re-test      (anomalous score drop)
candidate → rejected               (score below threshold)
```

### zero-config operation

- new hf model detected → auto-fetch → auto-benchmark → auto-propose
- lru zeroing frees space when disk pressure rises
- permanent `:keep:` flag for models that must stay local
- lan-first fetch: check neighbour nodes before going to hf

---

## prerequisite: the testing harness

before groups can self-manage, we need:

1. **`models.benchmark.runner`** — submits canonical tasks, collects scores
2. **`models.benchmark.suite`** — yaml definitions of canonical workloads
3. **`models.benchmark.store`** — persists scores, rolling averages, history
4. **`models.benchmark.compare`** — given two models + role, recommend winner

these are the minimum viable pieces before consensus-based management is useful.

---

## relation to existing work

| component | status | relation |
|-----------|--------|----------|
| `outcomes.json` + statistics | working | extend to benchmark suite |
| `llm.service.consensus_vote` | extracted, untested | drives group voting |
| `invoke-model-recover` | working | model fetch pipeline |
| `models.local_discover` | working | discovery layer |
| `models.registry.*` | working | central registry |
| task zenka state machine | working | benchmark job queue |
| 4-crossing consent protocol | designed | membership ratification |
| 9p lazy storage | designed | zero/restore lifecycle |
| `base.curve.*` | working (used elsewhere) | multi-parameter score fitting |
| `coding.async.stream_tps` | working, landed 2026-08-27 | live throughput scoring signal |
| `coding.self_test.multiplier` (ttft_p95) | working | latency scoring signal, same pattern to generalize |
| `iteration.loop` + `iteration.score_result` | working | criteria-based scoring engine, single-model retry — precedent for topic 1's per-workload scoring |
| `models.decision.recommendation_base` (composite_score) | working, consumer-side only | weighted multi-dimension scoring precedent — pattern to mirror, not code to reuse directly |
| `models.statistics.invocation_tracking` | shipped but dormant, found 2026-08-27 | the producer this whole system would finally feed |

---

## implementation sequence

```
[ ] benchmark suite yaml — define 6 canonical workload types
[ ] models.benchmark.runner — submit + score one workload against one model
[ ] models.benchmark.store — persist scores, extend outcomes.json schema
[ ] models.benchmark.compare — recommendation from score history
[ ] wire benchmark queue into model discovery (new model → auto-test)
[ ] llm.service.consensus_vote testing — validate with real model providers
[ ] group membership protocol — propose/ratify/demote with score evidence
[ ] on-demand fetch trigger — benchmark queue entry triggers download
[ ] self-assessment loop — periodic re-evaluation of active group members
```

---

## subsystem decomposition — candidate design documents (2026-08-27)

this doc has grown into an umbrella covering several genuinely separable
subsystems, each with its own open design questions that don't need to be
resolved together. splitting it lets each get a proper design pass and its
own task file(s) without one giant, permanently-half-finished document.
six topics, in dependency order — later ones need earlier ones to exist
first, not necessarily to be *finished*, but to have settled interfaces.

### 1. benchmark harness & multi-parameter scoring

**foundational — nothing else here works without this.** covers: running
one canonical workload against one model and getting a score back.
**spun off as its own doc, 2026-08-27**: see
[`MODEL-BENCHMARK-HARNESS.md`](./MODEL-BENCHMARK-HARNESS.md) — includes
two real precedents to mirror (`iteration.score_result`'s criteria
engine, `models.decision.recommendation_base`'s weighted-composite-score
pattern) found while researching this split, plus the discovery that
`models.statistics.invocation_tracking` is shipped but entirely dormant
(reachable from nowhere except its own command). summary below kept for
the decomposition overview; the linked doc is authoritative. a smaller,
prerequisite-free companion piece — coarse functional status (untested/
functional/inference-failures/startup-failure) plus an async sweep
iterator to populate it — is its own doc:
[`MODEL-STATUS-TRACKING.md`](./MODEL-STATUS-TRACKING.md). buildable and
useful before the full benchmark harness lands.

requirements to settle:
- canonical workload format (the 6 types already listed under layer 2) —
  concrete yaml schema, not just names
- the `base.curve.*`-based multi-parameter aggregation itself: which
  parameters (correctness, ttft, tokens/sec, memory) get which weight, is
  the weighting per-role (a coordinator cares about latency more than a
  specialist does) or global, how is a single suitability number derived
  from the curve fit
- P7 native-idiom conformance as a `format_comply` sub-dimension: what
  exactly gets checked (macro syntax use, `base.*` primitive reuse,
  swap_subs-aware naming) and how it's scored, not just flagged
- suite-version tagging so score history stays comparable across suite
  revisions (already noted in `## notes` below — belongs here concretely)
- the suite-self-improvement loop (optimizing prompts/system messages
  toward broadest cross-model coverage) — this is the least-specified
  piece of the whole doc and probably deserves its own sub-document once
  the rest of the harness exists to run experiments against

### 2. score storage & history

tightly coupled to #1 (the harness needs somewhere to write to) but a
distinct interface concern: how scores get queried by consensus (#4) and
lifecycle (#5) later, not just how they get written.

requirements to settle:
- schema extension to `outcomes.json` (workload_type field, canonical
  task ids, per-parameter breakdown alongside the aggregate score)
- rolling-window/retention policy — how much history is kept per
  model/role/workload before old scores are pruned or down-weighted
- `models.benchmark.compare`'s actual recommendation algorithm — given
  two models' score histories for the same role, what decides a winner
  (not just "higher score," given multi-parameter scoring from #1)

### 3. model discovery & auto-enqueue

**independent of #1/#2** — can be designed and even partially built in
parallel, converges with the benchmark side only at the "new model →
enters benchmark queue" trigger point.

requirements to settle:
- hf api polling cadence and scope (which model families get watched)
- version-comparison logic: detecting a known repo has a newer file
  without re-downloading to check
- dedup against `models.registry.*` — a rediscovered already-known model
  must not re-enter the queue
- the actual auto-enqueue trigger and what benchmark-queue entry shape it
  produces for #1's harness to consume

### 4. consensus / group membership protocol

**depends on #1 + #2 existing** (or at least their interfaces being
settled) — evidence-based proposals need real scores to cite.

requirements to settle:
- group composition mechanics: how coordinator/specialist/arbiter roles
  are assigned, can a model hold multiple roles across groups
  simultaneously
- the 4-crossing consent protocol's actual integration point — this doc
  currently just says it "gates ratification," the real interface between
  a benchmark-evidence proposal and that protocol needs its own spec
- threshold configuration: per-workload, per-role, per-group, or some
  combination — and who sets them (the "human role shifts to setting
  thresholds" framing in `## core idea` needs a concrete surface for that)
- self-assessment loop cadence and the anomaly-detection safeguard
  (sudden score drop → flag before autonomous demotion) — what counts as
  "sudden," how false-positive-prone this needs to tolerate being

### 5. model lifecycle management

**depends on #3** (discovery feeds the pipeline) **and #4** (consensus
decisions drive promotion/demotion) — comes last structurally, though the
raw fetch/zero mechanics could be prototyped independently sooner.

requirements to settle:
- the present/zeroed/missing/quarantine state machine's actual triggers
  and transition guards (already sketched in layer 4, needs to become
  concrete state-transition code, not just a diagram)
- LRU zeroing policy under disk pressure — what "pressure" threshold,
  interaction with the permanent `:keep:` flag
- lan-first fetch: neighbour-node discovery protocol, fallback ordering
  to hf, and how this interacts with the existing 9p lazy storage design

### 6. shadow evaluation & live-apply pipeline

**depends on #1** (reuses the scoring pipeline) **and #4** (live-apply
must be gated through consensus quorum, not a silent auto-swap) — a
later cross-cutting addition, not a prerequisite for anything above.

requirements to settle:
- task-type safety classification: which queue task types are safe to
  shadow-run against a candidate model at all (no unrepeatable side
  effects — file writes, network calls with side effects — without
  idempotency handling first)
- parallel-execution/capture infrastructure: running a candidate
  alongside (or instead of) the production model without disrupting the
  primary task's own timing/state
- the concrete apply-vs-discard decision: how "clears the quality AND
  style-alignment thresholds" from #1 actually gates whether a shadow
  result becomes the real task's output

---

## notes

- benchmark suite should be versioned — score comparisons only valid within
  same suite version
- models can belong to multiple groups with different roles in each
- the coordinator role is critical path — it must be highly reliable;
  may need a dedicated always-on small model (4B candidate on remote server)
- human override always available: manual `:keep:`, `:reject:`, `:demote:`
  flags bypass autonomous decisions
- anomaly detection: sudden score drop on a stable model → flag for review
  before autonomous demotion (could be a benchmark bug, not model regression)

```

#,,..,,,.,,..,,.,,,,.,,,,,..,,..,,,,.,,..,.,,,..,,...,..,,.,,,..,,,,,,,,.,,..,
#FDNIUMW3A26LKOUFA2NZZG4FNGSX724CQYP6X3LNOBGOQPO2LBFVUQVHT4ADH3T7YERT5R7GHL4BE
#\\\|VCIBNSWEVR2I72UTOWC7JGK6CIK4EMICTKVVEKE2YEBEYIEBAYD \ / AMOS7 \ YOURUM ::
#\[7]IHEQI6UMK2DMYQIIUOPCC5UXGRCMIB6HFXOYUSS57ORM2QXVPOCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
