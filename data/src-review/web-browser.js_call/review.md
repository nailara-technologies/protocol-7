---
module: web-browser.js_call
generated_at: 2026-09-09T22:50:20
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a4357830f5fa959df837b3eb56d9245128f832c7
source_lines: 71
dep_graph_callers: 11
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1186
usage_completion_tokens: 603
---

# review: web-browser.js_call

## Purpose
Executes JavaScript on a web-browser view and invokes a callback with the result. It validates the target view and JavaScript enablement before execution.

## Interface
- **Arguments**: `$js_string` (JS code), `$result_callback` (subref), `$re_cb_params` (optional params), `$target_view` (optional view id)
- **Returns**: Warns and returns if view unavailable or JS disabled; otherwise proceeds with evaluation.

## Role & dependencies
Called by 11 modules via static literal calls. Depends on `<web-browser.overlay.index>`, `<web-browser.gtk_obj.view>`, and `<[base.log]>`. Uses GTK+ view API (`evaluate_javascript`, `evaluate_javascript_finish`).

## Observations
- The `elsif` branch for `'web-browser.handler.auto_scroll'` is empty — no logic executes, making this conditional dead code.
- Error handling relies on fragile regex stripping (`s| at /usr/.+\n$||; s|^[^ ]+ ||;`) to sanitize exception messages.
- `format.log_singular` warnings appear 3 times (line 28+), suggesting inconsistent pluralization in log messages.
- The module is not in the subroutine whitelist, which may indicate it's considered internal or unstable.
- The `eval` block around `evaluate_javascript_finish` is a reasonable safety measure, but the error message transformation could lose meaningful context.

## Confidence
Unclear whether the empty `elsif` branch is intentional (placeholder) or an oversight. The regex-based error sanitization is fragile and may strip legitimate diagnostic information.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'web-browser.js_call'

WARNINGS:
  ⚠ format.log_singular : 3 occurrences [ first at line 28 ]
  ⚠ module not found in subroutine whitelist
```

#,,,,,,,,,,,,,,,,,,,,,.,.,...,..,,.,.,.,.,...,..,,...,..,,,..,,.,,..,,,..,..,,
#XOUWGT3PS5M642NYRBO3HPPZPHWE3ADK7KNUKCZQVNF4PRVHCVQLPUWGQPKT4PUKQAMIREK53VHKG
#\\\|CG75R54CD24X42IRN3MJ42Z2TEZDHK3GOE3NMZ7XY4B5FTIKGDD \ / AMOS7 \ YOURUM ::
#\[7]D34ONIYALTB6553DGR5S36DCQ7QANNKDMBZUTV5VDQB7XEW3ESCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
