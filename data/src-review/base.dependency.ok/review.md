---
module: base.dependency.ok
generated_at: 2026-09-09T22:45:10
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 980d1ef7818b066e5923a5c84a872f47304786a5
source_lines: 128
dep_graph_callers: 12
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1791
usage_completion_tokens: 643
---

# review: base.dependency.ok

## Purpose

This module determines whether all dependencies for a given object ID have been fulfilled. It returns `TRUE` when dependencies are satisfied, `FALSE` when they are not, or `undef` when the object ID is not found or the dependency chain is broken.

## Interface

**Arguments:**
- `$object_id` (string, optional): The object ID to check. Defaults to empty string.
- `$event_id` (string, optional): An optional event ID passed to callbacks.

**Return value:**
- `TRUE` — dependencies are fulfilled (or object_id is 0, meaning "no dependencies")
- `FALSE` — a dependency is unmet and no resolve hook succeeded
- `undef` — object ID not found, chain object not found, or no valid callback exists

## Role & dependencies

This module is a dependency resolver hook used by the AMOS7 system. It relies on several virtual variables:
- `<dependency.object>` — maps object IDs to their metadata
- `<dependency.chain>` — maps object IDs to their dependency chains
- `<dependency.setup.type>` — stores per-type callback and resolve hooks
- `<[base.log]>`, `<[base.logs]>` — logging utilities
- `<[base.ntime]>`, `<[base.ntime.delta_seconds]>` — time utilities
- `<[base.str.eval_error]>` — error capture utility

## Observations

The module implements a debounced resolve hook that prevents repeated invocation of resolve callbacks within `<dependency.resolve.min_interval>` (default 5) seconds. The comment documents a critical bug: comparing raw `ntime` deltas against a plain `5` resulted in a near-no-op debounce (~1.2ms instead of 5s), causing redundant cube instances to spawn during boot. This was confirmed in production.

The `format.log_singular` warning (4 occurrences) suggests the logging format strings may need review for consistency.

The module uses `eval` blocks to catch resolve hook failures, which is appropriate for a dependency check that should not fail the entire system.

## Confidence

Unclear whether the resolve hook debouncing is applied per-chain-object or globally. The code stores `$last_resolve` per `$chain_object_id`, but the exact semantics of "per chain object" in the comment versus the implementation could be clearer.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.dependency.ok'

WARNINGS:
  ⚠ format.log_singular : 4 occurrences [ first at line 16 ]
```

#,,..,,.,,,.,,,,.,,,,,...,..,,,,.,..,,..,,,,.,..,,...,...,.,,,..,,...,,..,,.,,
#FITRZXBHLRM2EPVK3LJUYIWXIR2M7B6OAAZDIJVYLI4DASOOODGCQMDSNOT4NAZ5WM4E3WM6YYSDS
#\\\|W3VM5DGJ576POWFDUYFQKJBHTJA4LA5TKKQYGE3KRZJBMTL4TGY \ / AMOS7 \ YOURUM ::
#\[7]CFCUVT2XQOYC4KXDFIFSKNSHWB275Q7AK33OWYRK3YU7ISCQIODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
