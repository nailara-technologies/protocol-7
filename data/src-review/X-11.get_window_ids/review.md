---
module: X-11.get_window_ids
generated_at: 2026-09-09T22:47:34
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: aec41deaa3b21c9c899c5918296e51387fa39b24
source_lines: 53
dep_graph_callers: 11
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1114
usage_completion_tokens: 535
---

# review: X-11.get_window_ids

## Purpose

This module retrieves a sorted list of X11 window IDs from the current display. It attempts to use the `_NET_CLIENT_LIST` property as the primary source, falling back to the WM registry when that property is unavailable.

## Interface

No explicit arguments or parameters. Returns a sorted list of window IDs (numeric values).

## Role & dependencies

The module depends on `X-11.obj`, `X-11.xlib.display`, and `X-11.WM`. It uses `InternAtom`, `ListProperties`, and `GetProperty` X11 protocol calls. It is called statically by 11 other modules (per the dep-graph). Notable internal state includes `$client_list`, `$wmname`, and `$type_utf8` atoms.

## Observations

- **Validation failure**: The module lacks a `descr` metadata field, causing the `validate_module` check to fail. This is a structural compliance issue.
- **Fallback coupling**: The fallback to `<X-11.WM>->sorted->@*` couples the module to the WM registry implementation, which may not always be available or consistent.
- **Error handling**: The `eval` blocks catch protocol errors (e.g., `BadAtom` when querying a non-existent atom), but the warning via `<[base.str.eval_error]>` is only emitted inside the `eval` scope, potentially hiding errors from callers.
- **State reliance**: The module depends on `state` variables being initialized before use, which assumes a specific initialization order in the caller.
- **Style**: The module uses AMOS7-specific syntax (`<...>`, `qw|...|`, `state`) consistent with the Protocol-7 codebase.

## Confidence

Unclear whether the fallback to `<X-11.WM>->sorted->@*` is reliable across all X11 server configurations, particularly in headless or minimal WM environments.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'X-11.get_window_ids':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,...,,.,,...,,.,,,,.,,,.,.,,,..,,...,..,,..,,...,...,,,.,..,,..,,,,,,.,.,
#MI4AZOVJ7TBEHF6ATDMEHGIEYMKFPXCDVRKWRW5MYMAXOVPAXIQ6ZFHU6CRUIQHU65FSUT4ZFP5AS
#\\\|QQTBJEA6AO4DUJOJY3MVUOCFLMYV4IWFMTM775YVVANKNQUPRQD \ / AMOS7 \ YOURUM ::
#\[7]ARDRMKWE3NE5W5FN3TJAMIH5P374NK6WKD4KD35AWU4QYBMT42BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
