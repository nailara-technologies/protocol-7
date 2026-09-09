---
module: base.sort
generated_at: 2026-09-09T10:02:18
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 0c386070d02ab0712f8542cb1ee5179f520ccfba
source_lines: 15
dep_graph_callers: 107
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 585
usage_completion_tokens: 541
---

# review: base.sort

## Purpose
This module sorts a list of parameters by string length in descending order, filtering out undefined values. It serves as a utility for ordering context-provided parameters by their length.

## Interface
**Arguments:** `@params` — obtained via `base.context.list` (static literal call).  
**Return:** A sorted list of defined elements, ordered by descending length. Returns `()` if no parameters are provided.

## Role & dependencies
The module is called by 107 other modules (per the dep-graph). It depends on `base.context.list` for parameter retrieval. The sort uses Perl's built-in `sort` with a custom comparator (`length $a <=> length $b`) and `grep {defined}` for filtering.

## Observations
- **Validation failure:** The module fails the `validate_module` check due to a missing or invalid `descr` metadata field. This is a compliance issue in the AMOS7 framework.
- **Fragility:** The module relies on `base.context.list` for its input, coupling it tightly to that context mechanism. If `base.context.list` changes behavior, this module breaks.
- **Style:** The data signature comment at the bottom appears to be a checksum or signature marker (`I22JUVAE7WEZGHVL2N5QRBWLT2TOZKEOQID4E6YG32ZA6YSBXKMCFHYR5PC3ZHAI274KKGVL5YHXC`), which is non-standard Perl and may hinder readability or tooling.
- **Edge case:** The `grep {defined}` silently drops `undef` values without warning, which may be intentional but could hide bugs if `undef` was expected to be preserved.

## Confidence
Unclear whether the `descr` field is required by the AMOS7 specification or if it's a legacy field that can be omitted. The data signature's purpose is also unclear from the source alone.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.sort':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,,.,,..,.,.,.,,,,,,,...,,,.,,.,,..,,..,,,,.,..,,...,.,.,..,,.,,,,,.,,,,,,.,,
#2VB46S3YK7IHSAEGDXK4ZG5ILEZ5OSKYZABOPYLCZE3OEAVFLE2N2KFCACZRRMMXRNW63QSZAYANM
#\\\|ZAYTIDVFCAULWWNPHS74PIROB7D54IZTUS2JMCA2SZJK5JUZRUY \ / AMOS7 \ YOURUM ::
#\[7]PRNCRPOTICJHVMNDSKOD35MCZTGFBEHXB4NGYUW7YA2FQJX5TADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
