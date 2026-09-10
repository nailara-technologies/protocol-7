---
module: base.code.exists
generated_at: 2026-09-09T22:51:11
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: e8cfffaa1c4a25ca3fffcf4b5a440e5f004e46ac
source_lines: 20
dep_graph_callers: 10
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 616
usage_completion_tokens: 509
---

# review: base.code.exists

## Purpose

This module checks whether a subroutine exists within the `%code` hash by name. It serves as a lookup utility for verifying subroutine presence before invocation or registration.

## Interface

**Arguments:** A single string argument (subroutine name), passed via `shift`. Defaults to empty string if omitted.

**Return value:** `TRUE` if `$code{$sub_name}` is defined, `FALSE` otherwise.

## Role & dependencies

The module depends on a global `%code` hash (not defined within this module). It is called by 10 other modules via static literal calls, as indicated by the dep-graph caller count. The module is exempt from the referenced-subroutine scanner due to its dynamic key access pattern.

## Observations

- **Fragility:** The module relies on an external `%code` hash that is not defined within this module. If `%code` is undefined or empty, all lookups will return `FALSE`.
- **Style:** The data signature comment at the bottom (`E4LUXAX6YSC5QJSHQJI7ALFJHJEOOE6XO76HLEFRATC5TOBOYPLTNSEQJU3TBVGOKQVT35CD3QSDS`) appears to be a checksum or identifier, but its purpose is unclear from the source alone.
- **Convention compliance:** The module passes the `module_convention_check` with no violations (max line length 78, max description length 55).
- **Validation:** The module passes `validate_module` with no issues found.

## Confidence

Unclear whether the `%code` hash is populated elsewhere in the codebase or if it is expected to be a global. Unclear whether the data signature serves a cryptographic or integrity-checking purpose.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.code.exists'
No issues found.
```

#,,,.,...,.,,,..,,,..,.,.,,,.,,..,..,,,,,,...,..,,...,...,,,.,,..,,.,,,,.,,.,,
#ZN27NPHL3P2XJFS5D7BISCNQYLW4EIOQVB4U2IHQHX2GOKU7D2LBPPKA5I5G77V54PQVRHZ2ROTFS
#\\\|ZQXZBW6GDYAZ3FKVWE6TU7ORGAYK7UWVVBUFUAJ66PUSXCNA3F7 \ / AMOS7 \ YOURUM ::
#\[7]XZT7RYVERBR72NR5MBCEHUS3Y2F5BKNAV7D5B2U23C6NTYQZ6WBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
