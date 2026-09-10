---
module: keys.get_keyfiles
generated_at: 2026-09-09T23:25:33
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: ea1f87aaa5b77de122273c9a6b7c95cce736a1eb
source_lines: 19
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 672
usage_completion_tokens: 541
---

# review: keys.get_keyfiles

## Purpose
This module retrieves keyfiles from `crypt.C25519.keyfiles` and returns them as an array. If no keyfiles are present, it outputs an error message using AMOS7's C-format constants before returning an empty array.

## Interface
- **Input:** None (no arguments)
- **Output:** Returns `@k_files` — an array of keyfile paths, or an empty array if none exist.

## Role & dependencies
This module serves as a keyfile loader, likely used by higher-level cryptographic operations. It depends on:
- `crypt.C25519.keyfiles` — a data file containing keyfile paths
- `AMOS7::C` — for formatting error messages with protocol constants

The module is called statically by 6 other modules (per the dep-graph), indicating it's a utility called directly rather than through dispatch.

## Observations
- **Fragility:** The module assumes `crypt.C25519.keyfiles` exists and is readable. If the file is missing or inaccessible, it silently returns an empty array instead of failing loudly.
- **Style:** The error message uses `sprintf` with AMOS7 constants (`$C{'0'}`, `$C{'R'}`, `$C{'T'}`), which is consistent with the protocol but may be opaque to readers unfamiliar with the constant set.
- **Validation failures:** The module lacks a `descr` metadata field and is not in the subroutine whitelist, suggesting it may be undocumented or unregistered in the AMOS7 toolchain.
- **Coupling:** The module is tightly coupled to the existence and format of `crypt.C25519.keyfiles`, making it brittle to filesystem changes.

## Confidence
Unclear whether the empty array return on failure is intentional (graceful degradation) or a bug. The module's role in the broader system is unclear without seeing its callers.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'keys.get_keyfiles':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,.,,,.,,,,,.,.,,,.,.,.,.,...,,,.,..,,,.,,..,,...,...,.,,,...,.,,,,,.,..,,
#BTNFFGWMJ37QU5YSNLRW5IS7XAFMYULKEDEQXFFYLCANKSFW6RCSIDGW3KAG7N3SYCP5GE6HSBYOY
#\\\|63IQ4QXTERITTY22IBMIGWZLLER4QJUUEZM6LVHB2N2KLMI4USH \ / AMOS7 \ YOURUM ::
#\[7]BYR3APUBWYB7QSRKP5GVMCI52NWPTVKPBQQ4V5Y6SKCSUGMGIEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
