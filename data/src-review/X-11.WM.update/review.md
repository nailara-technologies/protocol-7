---
module: X-11.WM.update
generated_at: 2026-09-09T22:44:17
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 331edabf96cdbb4202dfc65b2a52b329bce4924f
source_lines: 125
dep_graph_callers: 12
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1789
usage_completion_tokens: 668
---

# review: X-11.WM.update

## Purpose
This module attempts to invoke a window manager's `update` method via `<X-11.WM>->update`, retrying up to 13 times with decreasing log verbosity. If the WM update fails, it falls back to constructing a window registry by querying the root window tree and collecting titled windows.

## Interface
No explicit arguments or return value. It mutates `<X-11.WM>` in place (populating `byid`) and logs errors at levels 2→1→0.

## Role & dependencies
Called by 12 other modules (static literal calls). It depends on `<X-11.WM>`, `<X-11.obj>`, `<X-11.pool.query>`, `<[base.logs]>`, and `<[base.caller>`. The `find_title` closure recursively traverses the window tree to locate titled descendants.

## Observations
- **Validation failures**: Missing `descr` metadata field and absent from the subroutine whitelist — both flagged by the deterministic checks.
- **Fragile fallback**: The `QueryTree` fallback assumes every window has a title; it silently skips unmapped windows and windows without titles, potentially leaving gaps in the registry.
- **Recursive closure**: `$find_title` is assigned inside its own body (`$find_title = sub { ... $find_title->($child) ... }`), which is valid but unusual and harder to reason about.
- **Error suppression**: The `try_title` helper swallows all errors from `GetProperty` calls, making debugging difficult.
- **Magic numbers**: `$rescan_retries = 13` and the log-level decrement logic are opaque without documentation.
- **Style**: The module uses Protocol-7's `<[...]>` dynamic dispatch syntax throughout, which is consistent with the codebase but reduces static analyzability.

## Confidence
Unclear whether the `WM_NAME`/`_NET_WM_NAME` fallback chain covers all possible title atoms on all window managers. Also unclear whether the `sort` call on `<X-11.WM>` is idempotent or could cause side effects on repeated calls.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'X-11.WM.update':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,...,.,.,.,.,...,..,,,,,,,,,,.,,,.,.,,.,,..,,...,...,,..,.,.,.,.,.,.,...,
#CXLPKH5NB3G77DS7UXN6GOC3FCW6SMQKSDTY3S35YCIWLSSFOORT5575TZMCDEACCQ3W476XAHANQ
#\\\|U6ISM2VULWGM4XRYD77YEYT7B75FPU3R77C4UHCSDX67IJS3RFV \ / AMOS7 \ YOURUM ::
#\[7]QVAH4O63SYKOWW7GKV7RPXHATMGKH7EWPFFA76IWRCRE4KHE66CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
