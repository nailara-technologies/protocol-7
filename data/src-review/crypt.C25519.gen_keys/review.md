---
module: crypt.C25519.gen_keys
generated_at: 2026-09-09T10:20:28
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 45a271a95a39174181d0a077f02f0b2f5aed1c49
source_lines: 124
dep_graph_callers: 16
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1962
usage_completion_tokens: 958
---

# review: crypt.C25519.gen_keys

## Purpose
This module generates C25519 (Ed25519) key pairs, supporting three modes: loading a pre-defined "global-root" key for speed, deriving a secret key from a passphrase, or generating a random key. It stores the resulting key pair in a global hash and locks the private/secret keys in memory.

## Interface
- **Arguments:** `$key_name_param` (string, optional), `$key_seed_passphrase` (string, optional), `$secret_key` (string, optional, must be 32 bytes if provided)
- **Returns:** A hash reference containing the key pair and the key name on success; `undef` on failure; `FALSE` if a key with the same name already exists.

## Role & dependencies
This module is a leaf in the dependency graph (16 modules call it statically). It depends on:
- `crypt.C25519.key_vars` — for key name resolution
- `base.s_warn`, `base.logs` — logging utilities
- `base.prng.bytes` — random byte generation
- `base.ntime.b32` — timestamp encoding
- `event.once` — rate limiting
- `AMOS7::13::key_32` — key derivation from passphrase
- `Crypt::Ed25519` — Ed25519 key generation and public key extraction
- `IO::AIO::aio_mlock` — memory locking for security

## Observations
1. **Validation failure:** The module lacks a required `descr` metadata field, causing the `validate_module` check to fail.
2. **Unreachable code:** The `goto SKIP_GENERATING` label is only reachable via the hardcoded global-root key path; the final key generation block is always executed regardless.
3. **Infinite loop risk:** The `while (not $TRUE)` loop could hang if `Crypt::Ed25519::eddsa_public_key` or the truth assertion consistently fails.
4. **Memory lock misuse:** `IO::AIO::aio_mlock` is called on the hash reference (`$keys{'C25519'}{$name}`) rather than the actual key string values, which may not achieve the intended memory protection.
5. **Hardcoded values:** The global-root key is embedded directly, making the module less maintainable and harder to audit.

## Confidence
Unclear whether `Crypt::Ed25519::eddsa_public_key` is a real module or a Protocol-7 shim; unclear whether `IO::AIO::aio_mlock` accepts a hash reference or requires a scalar reference to the key data.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'crypt.C25519.gen_keys':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,..,...,,..,,,.,,.,,,..,.,,,.,.,...,.,.,,..,..,,...,...,...,..,,,,.,.,.,.,.,
#SV2OY7YAGDXMHWFN67XFXWHUDIDWNVHXGACLFYTHQGIQZTWTUGJ25ZCZ7FBHNGGH67HZZEHM3I4NM
#\\\|DVOKJSIPPQ7NO2EGQ54THLJ4WVNHUAFMAUW5N5OEBUQFMLOHHPC \ / AMOS7 \ YOURUM ::
#\[7]YACNNIRPEONNSTM3OJWARMLJ56LIN6JBZ232QD7O7THPKKGZUADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
