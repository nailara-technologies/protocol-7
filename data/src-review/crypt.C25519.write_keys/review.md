---
module: crypt.C25519.write_keys
generated_at: 2026-09-09T22:46:02
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 563ee2805cfbeb5300106601fd692cd7f58d960e
source_lines: 204
dep_graph_callers: 12
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2721
usage_completion_tokens: 779
---

# review: crypt.C25519.write_keys

## Purpose
This module writes C25519 cryptographic keys (secret, private, public) to disk with optional encryption via Twofish. It also optionally erases keys from memory after writing.

## Interface
**Arguments:** `$name_param` (key name), `$key_password` (optional encryption password), `$erase_keys` (default TRUE).
**Returns:** In scalar context, a boolean write status. In list context, a tuple of `(status, key_checksum)`.

## Role & dependencies
Called by 12 modules (static literal calls). It depends on `crypt.C25519.key_vars` for key metadata, `base.s_warn`, `base.logs`, `base.log`, `base.ntime.b32`, `system.zenka.name`, `system.zenka.verbosity.console`, `AMOS7::13::key_32`, `AMOS7::Twofish::key_init`, `AMOS7::Twofish::encrypt`, `chk-sum.bmw.L13-str`, `crypt.C25519.key_bin_checksums`, `crypt.C25519.chksum_cache.add`, and `crypt.C25519.unload_key`.

## Observations
- **Fragility:** The `wantarray` check at line 100 is brittle — if a caller changes context, behavior changes silently.
- **Coupling:** Heavy dependency on `crypt.C25519` internal functions (`key_vars`, `chksum_cache`, `unload_key`), making it hard to reuse without the full module.
- **Style:** The `next` statement at line 41 is unreachable (the `if` condition always evaluates to true or false, making the `next` dead code).
- **Warning:** `format.log_singular` violation at line 39 — the log message uses `%s` format but the singular/plural form isn't handled.
- **Security:** File permissions are set correctly (0640 for public, 0600 for secret/private), but the `chown` call only warns on failure rather than failing the operation.
- **Logic:** The `rename` at line 117 will fail if `$tmp_fname` doesn't exist, but the `open` at line 63 already fails if the directory doesn't exist — this is a minor redundancy.

## Confidence
Unclear whether `crypt.C25519.key_vars` is a subroutine or a hash reference (syntax `<[crypt.C25519.key_vars]>->($name_param)` suggests a method call on a reference). Unclear if `chk-sum.bmw.L13-str` is a module or a subroutine call.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'crypt.C25519.write_keys'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 39 ]
```

#,,..,...,...,,..,.,.,,,,,...,..,,,,.,.,,,,,,,..,,...,...,,.,,..,,..,,,..,,..,
#5II6DOODABGLQ7UFS26NYUAP75YMFFGZU5IJ3CA7ER3DU4TV67ZPOZXI4PFDJNM72XUKWSBE6GJKW
#\\\|IQAP7FBJMRKZ3PVRIWSFSN6W3HVN3SXX4PCKI7RV76EU7V54LWF \ / AMOS7 \ YOURUM ::
#\[7]XBX55YWZ2IKKLERXSU4PQCUUMFW7YOGLTKGNFFXAF5ULBJQ7RCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
