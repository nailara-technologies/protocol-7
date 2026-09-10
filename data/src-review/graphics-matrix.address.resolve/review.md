---
module: graphics-matrix.address.resolve
generated_at: 2026-09-09T23:46:07
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 3d98af84999923a7beccd7dc2b8d3aa592d8879d
source_lines: 107
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1611
usage_completion_tokens: 863
---

# review: graphics-matrix.address.resolve

## Purpose

This module resolves various addressing schemes into grid coordinates (selX, selY, selZ). It accepts a single string input and dispatches it through multiple parsing paths—directional routing, checksum lookup, octal-7 packed, base32 label, decimal coordinates, or label lookup—returning the resolved coordinates along with the scheme used.

## Interface

**Input:** A single string argument (default empty string).

**Output:** A hashref containing:
- `selX`, `selY`, `selZ` — resolved integer coordinates
- `scheme` — the parsing scheme that matched
- `channel` — channel label if a channel qualifier was present
- `data` — error message if resolution failed (optional)

## Role & Dependencies

Called by 6 modules (per the dependency graph). Notable callees:
- `graphics-matrix.channel.select` — resolves channel prefixes
- `graphics-matrix.cursor` — provides current selection coordinates
- `graphics-matrix.address.checksum` — hash lookup for checksum-based addresses
- `graphics-matrix.address.label` — hash lookup for label-based addresses
- `Crypt::Misc::decode_b32r` — external module for base32 decoding

## Observations

- **Fragility:** The module relies on external modules (`Crypt::Misc`) and hash lookups that may not be available in all environments. The `eval` around `decode_b32r` is a reasonable safeguard but could mask real errors.
- **Coupling:** Tightly coupled to `graphics-matrix.cursor` for coordinate state; changes to cursor semantics would ripple through.
- **Style:** AMOS7-specific syntax (`qw| ... |`, `shift // ''`) is consistent with the codebase. The deterministic check confirms no convention violations.
- **Potential issue:** The `channel` extraction returns early on `false` mode, but the caller may expect a consistent return structure. The `data` field is only set on failure paths.

## Confidence

Unclear whether `Crypt::Misc::decode_b32r` returns a raw string or a packed structure — the `unpack` call assumes a 3-byte output, but the module doesn't document the expected output format of that external function.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'graphics-matrix.address.resolve'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,,.,,..,,...,,..,,,,,...,,,.,,.,,.,,,,,,,..,,...,..,,...,.,.,.,.,..,,.,,,
#MEPRSXT4FIVNF2543RBZIUEDU46OGO5SVHIE3FPFTBGIGOR4LHJLAUSQL5SJZLMQOS2OBSIWVR6MG
#\\\|2YJCBX7S7EPSEGHLACRTO7O7CFXDK2Y72JKJ2BAZIWM3Z3IDP6D \ / AMOS7 \ YOURUM ::
#\[7]YDSIJA3RUJBGKNLN5XFAHQ3NGHSV4ZFJYYC7P4USZDML36W6RODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
