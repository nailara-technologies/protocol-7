---
module: base.dependency.install_callbacks
generated_at: 2026-09-09T23:39:09
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: dd50462d97b6e969828a2c4f12f5fe71b39fc8e6
source_lines: 45
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 968
usage_completion_tokens: 497
---

# review: base.dependency.install_callbacks

## Purpose
This module registers dependency check and resolve callbacks by object type. It scans a code reference hash for functions matching `callback.object.TYPE` and `resolve.object.TYPE` patterns, then invokes `dependency.setup` for each discovered type.

## Interface
Takes an optional `$name_prefix` argument (defaults to `<system.zenka.name>`). Returns the number of object types registered.

## Role & dependencies
Fits into the dependency resolution pipeline by populating type-specific callback/resolver mappings. Notable callees: `<[base.log]>` for logging, `<[dependency.setup]>` for type initialization. The module relies on an external `%code` hash (likely populated by a caller).

## Observations
- **Fragility**: The regex patterns assume a strict naming convention (`callback.object.TYPE` / `resolve.object.TYPE`). Any deviation breaks registration silently.
- **Coupling**: Depends on the global `%code` hash, making it hard to test in isolation.
- **Style**: The `format.log_singular` warning (3 occurrences) indicates log messages may incorrectly use singular forms when multiple items are involved.
- **Edge case**: If no callbacks are found, it logs a message but still returns `0` — the caller must handle this case.
- **Macro usage**: `<[base.log]>` and `<[dependency.setup]>` are Protocol-7 macros; their exact behavior is unclear from this module alone.

## Confidence
Unclear whether `%code` is a global or passed as a parameter. Unclear whether the log macros handle pluralization internally or if the warning is a separate linting concern.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.dependency.install_callbacks'

WARNINGS:
  ⚠ format.log_singular : 3 occurrences [ first at line 17 ]
```

#,,,.,.,.,,.,,,,.,...,,,,,.,.,.,,,,,.,..,,,,,,..,,...,..,,.,.,.,,,..,,.,.,,.,,
#CYELLOGBP3ZNOOUKHQXPXLVTLHKFWRIQQFAEYFZ7QBWVSWUK4IY3QEQZ2SWGB3SCIYAQLWTUG54MY
#\\\|QLM6JPEPHAXBGYKRKOBFNSEOUKQ67NBREKRIMAEKBWRLM2YRGUI \ / AMOS7 \ YOURUM ::
#\[7]AZR4ILKVCKGNM5UW4TNRQTB4QVU4VZHKNUQES2EWPHQJTNKC2ABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
