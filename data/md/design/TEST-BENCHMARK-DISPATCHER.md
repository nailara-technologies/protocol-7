# test & benchmark dispatcher — design

## purpose

shared dispatcher infrastructure serving two consumers:

```
consumer 1 — module/zenka test harness   [ correctness, regression ]
consumer 2 — model benchmark suite       [ scoring, selection, consensus ]
```

both submit canonical tasks with known expected outputs and collect
scored results. the dispatcher is the common layer — suite definitions,
job submission, result collection, and scoring live here once.

---

## position in the stack

```
[ suite yaml ]  →  [ dispatcher ]  →  [ coding zenka task queue ]
                        ↓
                [ result collector ]
                        ↓
              [ scorer / report ]  →  [ benchmark.store / test report ]
```

the dispatcher re-uses the existing coding zenka task infrastructure
rather than building a parallel queue. this means model benchmarks and
module tests run through the same async tool loop, with the same
timeout and retry logic already in place.

---

## suite definition format

suites are yaml files in `data/yaml/test-suites/`:

```yaml
suite: tool_call_basic
version: 1
description: basic tool invocation accuracy
workload_type: tool_call        # [ tool_call | code_edit | reasoning |
                                #   vision_desc | context_retain | format_comply ]
tasks:
  - id: tc_read_file_01
    prompt: "read the first 5 lines of src/coding.init_code"
    expect:
      tool_called: read_file
      args_contain:
        path: coding.init_code
      output_contains: "name.*=.*coding.init_code"
    scoring:
      method: regex_match        # [ exact | regex_match | llm_assert | tool_check ]
      weight: 1.0

  - id: tc_search_code_01
    prompt: "find all modules that call base.logs"
    expect:
      tool_called: search_code
      output_contains: "base.logs"
    scoring:
      method: regex_match
      weight: 1.0
```

suite versioning matters — scores are only comparable within the same
suite version. bump version when task definitions change.

---

## dispatcher modules

```
models.benchmark.runner     submit one task from suite against one model/backend
models.benchmark.suite      load + validate suite yaml, enumerate tasks
models.benchmark.store      persist scores, rolling averages, history
models.benchmark.compare    given two models + role, recommend winner
models.benchmark.report     human-readable run summary
```

### models.benchmark.runner interface

```perl
<[models.benchmark.runner]>->({
    suite    => 'tool_call_basic',   ## suite name or path
    task_id  => 'tc_read_file_01',  ## specific task, or undef for all
    model    => 'Qwen3-30B-A3B',    ## model identifier
    backend  => 'gpu',              ## gpu | cpu
    runs     => 3,                  ## repeat count for variance averaging
})
```

returns: `{ success, scores => [...], pass_rate, duration }`

### scoring methods

```
exact          result string matches expected exactly
regex_match    expected.output_contains pattern found in result
tool_check     correct tool was called with expected args
llm_assert      secondary model evaluates quality [ for open-ended tasks ]
```

`llm_assert` scoring uses a lightweight model (coordinator role) to
assess whether the output satisfies the task intent — suitable for
reasoning and vision workloads where exact matching is impractical.

---

## result flow to benchmark.store

scores are appended to `data/json/benchmark-scores.jsonl`:

```json
{ "suite": "tool_call_basic", "suite_version": 1,
  "task_id": "tc_read_file_01", "model": "Qwen3-30B-A3B",
  "pass": true, "score": 1.0, "duration_ms": 1240,
  "timestamp": 1775460000, "run_index": 0 }
```

rolling averages per model per workload_type computed on read by
`models.benchmark.store` — no separate aggregation job needed.

---

## connection to autonomous model management

the dispatcher feeds layer 2 (benchmarking) of the autonomous
management design. when `models.local_discover` finds a new model:

```
new model detected
    → benchmark queue entry created
    → dispatcher runs canonical suite
    → scores stored in benchmark.store
    → models.benchmark.compare recommends role
    → proposal submitted to consensus group (layer 3)
```

see `AUTONOMOUS-MODEL-MANAGEMENT.md` for the full four-layer design.

---

## connection to module/zenka testing

the same dispatcher infrastructure handles module tests — suite yaml
defines the prompt, expected tool calls and output, scoring method.
the only difference is the _target_: model benchmarks target a model
backend, module tests target the zenka + module under test.

a `test_target` field in the suite yaml selects the mode:

```yaml
test_target: model              ## benchmark mode — scores a model
test_target: zenka.coding       ## module test mode — tests a zenka
```

for module test mode the dispatcher routes through the test zenka
(see `MODULE-TEST-ZENKA.md`) rather than directly to the GPU backend.

---

## implementation sequence

```
[ ] data/yaml/test-suites/ directory + first suite yaml (tool_call_basic)
[ ] models.benchmark.suite  — load + validate suite yaml
[ ] models.benchmark.runner — submit task, collect result, score
[ ] models.benchmark.store  — append to jsonl, compute rolling averages
[ ] models.benchmark.compare — recommend winner from score history
[ ] models.benchmark.report — human-readable summary for whats-next context
[ ] wire runner into models.local_discover (new model → auto-benchmark)
[ ] models.benchmark.runner: test_target routing (model vs zenka)
```

#,,..,..,,,.,,..,,,.,,,..,..,,,,,,.,.,.,.,,,.,..,,...,...,.,.,.,,,,.,,..,,,,,,
#5YEVVMVKHAB33JXK6PM6CFC6GJ5KRDUQQSDDKHGVDHBYYMMJOWDNPVR3V3ROU7YMO7UAYX6XDB3OY
#\\\|MLBCKRZ4QR2MU6PXKX2B7JABWQNMYHJUV7ELVFIJ4QZOKHRQ6UX \ / AMOS7 \ YOURUM ::
#\[7]QIBT7W45KORRPHB3VPEF334Y3V4G2OSV5DTF57265S4UADJASMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
