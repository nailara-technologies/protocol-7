---
module: source.extract_sig_body
generated_at: 2026-09-09T10:25:07
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 5729b0cff98885200cd583cb8deebbbb8e844f5b
source_lines: 834
dep_graph_callers: 14
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3997
usage_completion_tokens: 712
---

# review: source.extract_sig_body

## Purpose

This module extracts code signature footers from source code files. It identifies and removes signature blocks (marked by `#` lines with 70+ character runs of `.`/`,`), optionally stripping placeholder stubs and fake footers before extraction. It operates in three modes: `strict`, `repair`, and `info`.

## Interface

**Arguments:**
- `$src_ref`: scalar reference to source string (required)
- `$strip`: optional flag (`'strip'` or `0/1`) to remove stub footers
- `$mode`: optional mode string (`strict`, `repair`, `info`)

**Return:** Modified source reference with footer removed, plus a `$footer_data` hash containing extraction metadata (signature type, checksum info, error flags).

## Role & Dependencies

Called by 14 modules (static literal calls). Depends on `<source.chksum_bitsize>` for bit-size configuration and `<base.s_warn>` / `<base.logs>` for logging. The module is a utility for signature handling within the AMOS7 signing pipeline.

## Observations

- **Validation gaps**: The `validate_module` check reports missing `descr` metadata and absence from the subroutine whitelist — this module should be registered in the module registry.

- **Regex fragility**: The flexible repair mode uses interpolated regex patterns (`$signature_marker`) inside `qr//` delimiters, which is error-prone. The `last` statements inside nested loops may not exit all loops as intended.

- **State mutation**: The module mutates `$$src_ref` directly without returning the modified value — callers must reassign. The `$footer_data` hash is built but never returned or stored anywhere visible.

- **Stub stripping logic**: The placeholder stub removal uses `s///` with `sg` flags but the captured content is discarded — this is correct but the regex patterns for old/new format stubs may not cover all variants.

- **The `seperator_endline_absent` flag** is set but never used downstream — appears to be dead code.

- **The `endline-state-encoded` field** in `$footer_data` is hardcoded to `5` with a comment "endline state unchanged" — unclear what this encodes.

## Confidence

Unclear what the `endline-state-encoded` field is supposed to represent — the comment says "unchanged" but the value `5` has no documented meaning. Also unclear whether the module is meant to be called with a reference to a filehandle or a string reference, given the `ref $src_ref` check.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'source.extract_sig_body':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,.,,,,,,,,.,,,,,,,,,,,.,,..,,,,,,,,,,,..,..,,...,...,,,,,.,,,.,.,.,,,,,.,
#3KIUABWEYTBU4DRX6SCURAAYXEGVJT5ES3LKI63JR27FHTGQBFMSTN6Y6KHHJWV3ORK3J4F54XMQ6
#\\\|WSQNGTGRZ4ZUWTR2XKKKBLZGZEADBWWWCIP6SSAI75UAUPTRLIC \ / AMOS7 \ YOURUM ::
#\[7]33YDA35S5XQFY2CKMZTHGZSAHYGJGOLUCAYVDWQ47LHJHQ6OY2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
