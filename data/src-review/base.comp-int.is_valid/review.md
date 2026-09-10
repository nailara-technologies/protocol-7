---
module: base.comp-int.is_valid
generated_at: 2026-09-09T23:03:29
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 34bcb7debf2776f7842de286d30cc896247b9d4d
source_lines: 43
dep_graph_callers: 8
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 816
usage_completion_tokens: 689
---

# review: base.comp-int.is_valid

## Purpose
This module validates BER-encoded compressed integers (template 'w'), which are sequences of bytes where each byte's most significant bit indicates continuation (1 = more bytes follow, 0 = last byte). It returns the count of bytes in a valid compressed integer, or FALSE if the input is unterminated.

## Interface
- **Input:** `$compressed_int` — a string of bytes representing the compressed integer.
- **Output:** Returns the number of bytes if valid, or `FALSE` if the input is unterminated (missing the terminating zero-bit byte).

## Role & dependencies
This module is called by 8 other modules (per the dependency graph). It serves as a validation utility for BER-encoded data. Notable internal usage: `vec()` for bit extraction, `split` for byte iteration, and a custom `<{C1}>` warning format.

## Observations
- **Fragility:** The function returns `FALSE` on failure rather than `undef` or `0`, which may cause confusion in Perl's truthy/falsy evaluation. The `warn` call uses a custom format `<{C1}>` that is not standard Perl — unclear if this is a Protocol-7 convention or a potential portability issue.
- **Style:** The `truefalse.bool_assign` warning at line 15 indicates use of `TRUE`/`FALSE` constants instead of `1`/`0`, which the validator flags as a style violation.
- **Edge case:** An empty string triggers the early `warn` and returns `undef`, but a string of all `1`-bit bytes (e.g., `"\xFF\xFF"`) would loop through all bytes and return `FALSE` — behavior is consistent but may surprise callers expecting a numeric return.
- **Coupling:** The module depends on no external modules, making it self-contained.

## Confidence
Unclear whether the `<{C1}>` warning format is a Protocol-7 convention or a potential bug. Also unclear whether returning `FALSE` (boolean) instead of `undef` is intentional or a design oversight.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.comp-int.is_valid'

WARNINGS:
  ⚠ truefalse.bool_assign : 2 occurrences [ first at line 15 ]
```

#,,,,,...,,.,,,,,,,,,,.,,,,,.,..,,,.,,,.,,..,,..,,...,...,,,.,,,,,..,,,,,,...,
#2I23G3WBXFOED7DARFYUR5CDHISJBLIKRRIMDCZNS3P3E57O4S7LD4JF2ZVVX3ZUDDMJY4UVUIPSE
#\\\|C4DYGTW7MV4CJROFPVJH4LDKBCUVSCAWU7HTDG2PTDM5VGVCXID \ / AMOS7 \ YOURUM ::
#\[7]I7TUXW7I43RM7IDTBJWDNZHF436ZO6YPJV4PNAIT5BMAANV5CYCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
