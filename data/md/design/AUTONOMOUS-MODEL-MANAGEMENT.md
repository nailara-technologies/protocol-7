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

### existing foundation

- `outcomes.json`, `get_statistics`, `check_cache_first` — already tracking
  per-model success rates in coding zenka
- extend to structured suite: add workload_type field, canonical task ids
- `llm.service.consensus_vote` — already extracted, untested — drives layer 3

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

#,,,,,,,.,...,.,,,,,,,...,..,,,,.,,,.,,.,,,,,,..,,...,...,.,,,.,,,.,.,.,,,,,,,
#FARL65KCM233ISYG5LVWNT5DOC3SOZRWR4NW7KOKOS5PRSMKR5TS6JPKG25N2U5UWID3LIW7YBM66
#\\\|AQBTEV6DV2S57CH6ZQ7OHODLSLJTSUQEYOXREFKY62LTRNL7QEP \ / AMOS7 \ YOURUM ::
#\[7]B5TMFWVWQ6ECEEXY6LUQYT4S3G3NU7ZS7LR4JJPJDV7DUFBQKEBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
