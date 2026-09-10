---
module: crypt.C25519.key_bin_checksums
generated_at: 2026-09-09T22:48:34
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: df9847cabd73b5a6d3859d5e3089659068d4138e
source_lines: 108
dep_graph_callers: 11
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1559
usage_completion_tokens: 597
---

# review: crypt.C25519.key_bin_checksums

## Purpose

This module generates harmonized checksums for binary key strings, supporting both combined and separate checksum computation. It validates key lengths against a whitelist (32, 64, or 97 bytes) and produces formatted checksum strings using template-based hashing.

## Interface

**Arguments:** `@ARG` — array of binary key strings. Returns `undef` if zero or more than two keys are supplied.

**Return value:** A formatted string combining checksums, or `undef` on validation failure.

## Role & dependencies

The module is called by 11 other modules (static literal calls). It depends on:
- `AMOS7::TEMPLATE::template_timeout()` / `reset_temp_valid_timeout()` — for validation timeout management
- `<[chk-sum.amos.truth_template_chksum]>` — a template-based checksum function
- `<[base.reverse-sort]>` and `<[base.s_warn]>` — utility functions

## Observations

- **Template expansion:** The `pubkey_str_truth_template` is dynamically extended for encrypted key cases, suggesting the checksum function must handle variable-length templates.
- **Virtual key handling:** 97-byte keys are treated as "virtual" with a shortened timeout (13 vs 47), implying a different validation path.
- **Template timeout mechanism:** The `template_timeout` calls appear to be a validation guard — unclear what triggers a timeout failure.
- **Encrypted key detection:** Relies on exact length (9) and string equality to `qw| [enc-key] |` — brittle if the marker changes.
- **Combined checksum logic:** When two keys are present, the private key checksum is computed with a repeated pubkey checksum pattern (`sprintf` with `x 3`), suggesting a specific AMOS7 protocol requirement.

## Confidence

Unclear whether the `template_timeout` mechanism can actually fail or is purely advisory. The exact semantics of the `:virtual::` marker in the checksum output are not evident from the source alone.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'crypt.C25519.key_bin_checksums'
No issues found.
```

#,,,,,.,,,..,,...,..,,...,,,.,,.,,,,,,,..,..,,..,,...,..,,...,...,,,,,..,,,..,
#I34XHO35NBQ6FUFQSMAR7624JJLZ3QGJNNHKNBZGKQQWS64MU2XQ74IXWENKCTNEFSZDBMC3CJDUO
#\\\|BRPZZPLKDBZVPUF2YBSLGPBGOG5DPI5P3PVS3IZRWD7MNUYHP4O \ / AMOS7 \ YOURUM ::
#\[7]GDLLIPK2KUL3WUU5ZMNDE5C2YTN6VAA4WBK5TTUYN7SO3E7ZY4DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
