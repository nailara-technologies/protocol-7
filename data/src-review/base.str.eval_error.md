---
module: base.str.eval_error
generated_at: 2026-09-09T10:02:27
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 59f578e7e7406b5d0d120edcc8ad54d4faa08827
source_lines: 11
dep_graph_callers: 104
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 584
usage_completion_tokens: 433
---

# review: base.str.eval_error

## Purpose

This module is a thin wrapper that delegates error formatting to `base.format_error`. It takes an `$EVAL_ERROR` value and an optional shift parameter (defaulting to -1), returning the formatted result as a scalar.

## Interface

- **Arguments**: `$EVAL_ERROR` (required), optional shift parameter (defaults to `-1`)
- **Return value**: A scalar string produced by `base.format_error`

## Role & dependencies

The module is called by 104 other modules (per the dep-graph), making it a significant dependency in the codebase. It relies entirely on `base.format_error` for its core logic, acting as a simple adapter layer.

## Observations

The module is functionally minimal — essentially a one-liner delegating to another module. The deterministic check outputs flag two issues: the missing `descr` metadata field and the missing signature footer. These are structural compliance issues that may affect tooling or build pipelines. The module's fragility is high: any change to `base.format_error`'s signature or behavior directly impacts all 104 callers without any buffering or abstraction. The default shift of `-1` is opaque without documentation.

## Confidence

Unclear whether the missing `descr` field is a critical blocker or a soft requirement. Unclear if the 104 callers are statically linked or dynamically dispatched (the dep-graph note says conditional/dynamic dispatch is NOT captured, so the true count may be higher).

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.str.eval_error':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer
```

#,,,,,,,.,...,,.,,.,.,,..,..,,.,.,,,.,.,,,,,,,..,,...,..,,,.,,,..,.,.,,,.,,.,,
#T3MIQL5D7WBNY44MB3NUDU6BC4KLEB2HH266CLK6CEC5SSPMRZ6SCE25WOVPZUK3FSEE2WXUIJ3WE
#\\\|VLTRTWWKWYCEMLJYLFEVYZQHLBWYCCYTZQRHCLARY4ABVTGJYGO \ / AMOS7 \ YOURUM ::
#\[7]CANKR7522M7T3YKTCQUDEO5D4MPFWTT73E6GVIZLQG2LRUP4OODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
