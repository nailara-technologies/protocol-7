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

#,,,,,..,,..,,,,,,.,,,,..,,.,,.,.,,,.,..,,..,,..,,...,...,..,,,,.,..,,,,,,,,.,
#7LAGM7SDDAGISI5L6DSH6L5H7USBBTILBI7FMNPHZHRD7R6V5ZGI5CXGF3CN6RMMYHOMJ3V56AI4E
#\\\|23KNIVYI3PBYYEATX6E3QQ6KRMG43G4C3KQJQJM3LJYBG2TVCGD \ / AMOS7 \ YOURUM ::
#\[7]X4GXRR36IZCPHPMHW2GUNZ4ZA4HWVB6RVBW6ZGZCPHZQ3WMRXQDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
