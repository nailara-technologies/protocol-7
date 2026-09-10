---
module: crypt.C25519.load_keypair
generated_at: 2026-09-09T10:17:09
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 39d6db02af85cd49cc482ac6ffd59b3b10161ae3
source_lines: 399
dep_graph_callers: 18
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 4618
usage_completion_tokens: 714
---

# review: crypt.C25519.load_keypair

## Purpose
This module loads or generates C25519 (Ed25519) keypairs, supporting multiple modes: generating from a seed phrase, loading from encrypted/decrypted files, loading public-only keys, and handling virtual keys backed by `.vp` comparison files.

## Interface
**Arguments:** `$name_param` (key name), `$key_password` (optional), `$ask_for_password` (optional, default TRUE), `$pwd_retry_on_error` (optional, default FALSE), `$test_key_chksum` (optional).
**Returns:** On success, returns `TRUE` or `(TRUE, $key_checksum)` in list context. On failure, returns `FALSE` or `(FALSE, undef)`.

## Role & dependencies
This is a central key management routine called by 18 other modules. It heavily relies on `crypt.C25519.key_vars` for path resolution, `crypt.C25519.gen_keys` for generation, `crypt.C25519.decrypt_priv_keystr`/`decrypt_secret_key` for decryption, and `Crypt::Misc::decode_b32r` for base32 decoding. It also depends on `base.logs`, `base.perlmod.load`, and `file.slurp`.

## Observations
- **High coupling:** The function is ~300 lines with deeply nested conditionals, making it difficult to reason about individual code paths.
- **Format warning:** 19 occurrences of `format.log_singular` suggest inconsistent logging patterns (first at line 45).
- **Missing metadata:** The module lacks a `descr` field and signature footer, violating module convention.
- **Error handling:** The `REENTER_GEN_ENTROPY` label and `RE_READ_PWD` label create non-linear control flow that may be hard to trace.
- **Branch complexity:** The `elsif` chain has at least 6 distinct branches with overlapping conditions (e.g., `-r $secret_key_file` appears in multiple branches with different implications).

## Confidence
Unclear on the exact semantics of `$test_key_chksum` — whether it's used for validation or just passed through. Also unclear whether the `.vp` file comparison is a security feature or a convenience check.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'crypt.C25519.load_keypair':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer

WARNINGS:
  ⚠ format.log_singular : 19 occurrences [ first at line 45 ]
```

#,,.,,...,,,,,,..,,,.,,,.,,,,,..,,,..,,.,,,..,..,,...,...,...,...,,..,.,,,,.,,
#SVFP6JH354EMVT6W5SLLY3N4XRP36TPW6SYTEHUFGIZWLMQ7ROPUZD5HXM2XVDXWZVBWLVH57XOGM
#\\\|PYW3SEB5KLIK3EHRSEAMNHQL2YB6ZV3YOQZQ526UDAJACJYDFIP \ / AMOS7 \ YOURUM ::
#\[7]JH3X7QWPA5IX6W7HMIV2CUULFCHLOEWHCMPXK3LZHLFWAIZMPWAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
