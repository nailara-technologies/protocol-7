---
module: crypt.C25519.encrypted_key
generated_at: 2026-09-09T22:48:18
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 0b4f715fc4966894e40fcde3d1fb1abbb3c38579
source_lines: 153
dep_graph_callers: 11
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2008
usage_completion_tokens: 687
---

# review: crypt.C25519.encrypted_key

## Purpose
This module determines the encryption status of a cryptographic key by examining key files (private, public, secret) and their formats. It returns whether a key is encrypted, unencrypted, or has an unknown status.

## Interface
**Input:** `$name` — a key name or absolute path to a key file.
**Returns:** One of `TRUE` (encrypted), `FALSE` (unencrypted), `UNKNOWN`, or error codes `-1` through `-5`.

## Role & dependencies
This module is a utility called by 11 other modules (per the dep-graph). It relies heavily on internal AMOS7 infrastructure:
- `crypt.C25519.regex` — key file pattern matching
- `crypt.C25519.key_vars` — resolves key filename variants
- `crypt.C25519.key_name_and_type` — extracts key type from path
- `file.slurp` — reads file contents
- `crypt.C25519.get_type_from_key_str` — parses key format
- `base.logs` / `base.log` — logging

## Observations
- **Fragile coupling:** The module tightly couples to internal AMOS7 modules (`crypt.C25519.*`, `file.slurp`, `base.*`). Any change to these would break this module.
- **Error code proliferation:** Returns `-1` through `-5` for different failure modes, making callers difficult to reason about.
- **Style:** Uses AMOS7-specific syntax (`<module.function>` call syntax, `qw| ... |` arrays, `->$*` for scalar refs).
- **Validation failure:** The module lacks a `descr` metadata field (ERROR), which may hinder tooling integration.
- **Line 114 warning:** A singular/plural format issue in a log message suggests potential inconsistency in logging conventions.

## Confidence
Unclear whether the `-5` return value for "virtual key" is intentional or a bug, given that virtual keys are described as "never encrypted" yet return a negative error code instead of `FALSE`. Also unclear whether `UNKNOWN` is a valid return value or a sentinel for "no conclusion reached."

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'crypt.C25519.encrypted_key':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 114 ]
```

#,,,.,,..,.,.,.,,,...,,,.,...,,,,,,,.,,,.,,,,,..,,...,...,...,,,.,.,,,.,,,,,.,
#3MPE4KSOT25CGJ7O2JE6TIHSG2HPFNN4BK3AVXDVQXFD6CYDBKOSJUESKOO4Q5QLOS4LUSQZVNGIY
#\\\|3UE7MJ7CNUTURRNBFS2ZMCVRQ7USLK3GFCURQNZDYFSN26VU3IY \ / AMOS7 \ YOURUM ::
#\[7]QL54UNNIZP3RNU3GM6AK6XJQGFTXKWUVSQTNEBQLREXD3456OMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
