---
module: task.persist.save
generated_at: 2026-09-09T23:17:22
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 7e415dc46e7ba41790dd3c9416177f4753941ff0
source_lines: 48
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 864
usage_completion_tokens: 611
---

# review: task.persist.save

## Purpose
This module persists the task queue and task history to disk as YAML files. It serializes both the current queue state and historical records, writing them to `queue.yaml` and `history.yaml` respectively in the zenka directory.

## Interface
- **Arguments:** None (relies on global `task.queue`, `task.queue.order`, `task.history`, and `base.ntime`)
- **Return value:** Boolean `$ok` — `TRUE` if both files were written successfully, `FALSE` otherwise

## Role & dependencies
This module is a leaf in the dependency graph (7 modules call it statically). It depends on:
- `format.yaml.dump_str` — for YAML serialization
- `file.zenka_dir.write` — for file I/O
- `task.queue`, `task.history`, `task.queue.order` — global task state
- `base.ntime` — for timestamping
- `utf8::encode` — for encoding YAML strings

## Observations
- **Fragility:** The module assumes `task.queue`, `task.history`, and `base.ntime` are always defined globally. No guards against `undef` on these inputs.
- **Coupling:** Tightly coupled to `file.zenka_dir.write` — if that module's semantics change (e.g., returns a different type), this breaks.
- **Style:** The `utf8::encode` call is placed after the `else` branch, meaning it only runs on success — a minor but odd placement.
- **Warning:** `validate_module` reports "module not found in subroutine whitelist" — suggests this module may not be registered in the module registry, which could affect tooling or introspection.
- **Convention check passed** — no violations detected in naming or formatting.

## Confidence
Unclear whether `file.zenka_dir.write` returns a boolean or a filehandle — the `defined` check suggests it returns a value that may be `undef` on failure, but the exact semantics are not visible here. Also unclear if `task.queue` and `task.history` are guaranteed to be defined at call time.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'task.persist.save'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,,.,,.,,,.,.,,,,,,,,,,..,,,.,...,,.,,,,,,..,,...,...,...,.,,,..,,,,,,,,,,
#SUHIOIRSJ6ZWZSGNWLOSFW7E646G6AYUIM2CBTQ52SNPG37MUQUFSCKIDOWGVCQZO5USDCZOTJI62
#\\\|VFGR2HNMI33QMPVHKRKTHJGHMWBGWJBN6PI3X7ZBI7SF4OOE5HP \ / AMOS7 \ YOURUM ::
#\[7]2YF4EVJUZURD25CLZ3DRGO3UHB4NGHQ63K5JNDZYHUYA6CKZKMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
