---
module: base.cfg_bool
generated_at: 2026-09-09T10:02:56
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: f35649aac822916b22c066300d935e910405aa40
source_lines: 27
dep_graph_callers: 98
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 721
usage_completion_tokens: 525
---

# review: base.cfg_bool

## Purpose
This module interprets boolean configuration options and returns TRUE or FALSE based on string matching. It accepts a single argument (defaulting to FALSE) and normalizes common boolean representations into Perl boolean values.

## Interface
- **Argument**: `$option_value` (string, shifted from `@_`, defaults to `FALSE`)
- **Returns**: `TRUE`, `FALSE`, or `undef` (on unrecognized input)

## Role & dependencies
This is a utility module with 98 static literal callers in the dependency graph. It depends on `base.s_warn` (invoked via `<[base.s_warn]>` for unrecognized options). The module serves as a canonical boolean parser for the AMOS7 codebase.

## Observations
- **Fragility**: The regex patterns are case-insensitive but rely on exact word boundaries (`^` anchor). A string like `"yes "` (with trailing space) would fail to match.
- **Coupling**: The `<[base.s_warn]>` call couples this module to the warning system, but the call is only triggered on failure, making it a soft dependency.
- **Style**: The AMOS7 signature block at the bottom is a codebase-specific convention. The `##` comments appear to be documentation markers.
- **Potential issue**: The default of `FALSE` when no argument is passed means `shift // FALSE` will return `FALSE` (a bareword) rather than `undef`, which could be ambiguous in some contexts.

## Confidence
Unclear whether `FALSE` (the bareword) is a defined constant in this codebase or if it's a typo for `0` or `undef`. The regex uses `FALSE` as a literal string in the default, which is unusual for Perl.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.cfg_bool'
No issues found.
```

#,,..,.,.,,.,,.,,,,.,,,.,,..,,,..,,,.,,,,,.,.,..,,...,..,,.,,,.,.,,,,,.,.,...,
#XJMIUKKW5GGWEZPTMI2UQJBATEFN6MBWO7LW2ZEJXU7CILFHWGYB2L2ZQVHBXA2N6VN4GG7PNNO6M
#\\\|DPLCMFNC2BX67VO43CWPAUW5DUSW5UW2DBMKMXR7SKBEEJBWAJK \ / AMOS7 \ YOURUM ::
#\[7]YZNXCRQ2B6JGEXYUPU7Q56HGXJGLQFTZ3NDFQGUTBLIMJ7YK7QBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
