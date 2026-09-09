---
module: base.reverse-sort
generated_at: 2026-09-09T10:05:58
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a07ceabe22ddcfcee2ad53ae1607e545676b0d5d
source_lines: 15
dep_graph_callers: 50
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 601
usage_completion_tokens: 503
---

# review: base.reverse-sort

## Purpose
This module sorts a list of parameters by string length in descending order, filtering out undefined values. It returns an empty list when no parameters are provided.

## Interface
- **Input:** `@params` (retrieved from `base.context.list`), passed as `@ARG`
- **Output:** A sorted list of defined values, ordered by descending string length

## Role & dependencies
This module depends on `base.context.list` for parameter retrieval. It is called by 50 modules (per the dep-graph), indicating it's a utility used across the codebase. The `sort` and `grep` builtins are the primary dependencies.

## Observations
- **Fragility:** The `grep {defined}` filter silently drops undefined values without warning, which may hide data loss.
- **Coupling:** Relies on `base.context.list` — a single point of failure if that module changes.
- **Style:** The signature footer is present in the source but the validation reports it as missing — a potential false positive or format mismatch.
- **Edge case:** Empty input returns `()` rather than an empty list reference, which may break callers expecting a list context.
- **Convention check passed** — no style violations detected.

## Confidence
Unclear why the validation reports a "missing signature footer" when one is visibly present in the source. The footer format may not match the validator's expected pattern. Also unclear whether returning `()` vs `()` is intentional or a bug.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.reverse-sort':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer
```

#,,,,,.,.,.,.,,,,,,,.,,,.,...,..,,.,,,.,.,...,..,,...,...,..,,,..,..,,,.,,,.,,
#7DX2KHIK6GQR5X5PS23ELJQ7PN2PZT6T6XE73QPG4BR5TAHMQK3AFVZAYLWVHYX4VWBZASDJ54R4I
#\\\|R2ZOWW55XOPQ62OR2LIW3DBV6PP7DPTP63GWAGG6C7PLNJE6WWZ \ / AMOS7 \ YOURUM ::
#\[7]KS4FF32PYAVE2LPOOP773BMCSWCBCEB7B32PHACZE5XY7QOHOWCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
