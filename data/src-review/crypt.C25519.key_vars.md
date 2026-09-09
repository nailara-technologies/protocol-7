---
module: crypt.C25519.key_vars
generated_at: 2026-09-09T10:05:00
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 09c0c56d6aa13597e3467195fd0deb4afa0ae4d7
source_lines: 125
dep_graph_callers: 63
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1843
usage_completion_tokens: 988
---

# review: crypt.C25519.key_vars

## Purpose
This module resolves and returns a hash reference of key-related variables for C25519 (Ed25519) cryptographic operations. It determines the effective user identity, resolves the home directory, and constructs paths for key storage directories and files.

## Interface
**Argument:** `$key_name` (optional, shifted from `@ARGV`). If undefined, defaults to `<crypt.C25519.base_key_name>` or a user-specific default.
**Return:** A hash reference containing `uid`, `gid`, `usr_name`, `usr_home`, `key_dir`, `auth_dir`, `known_hosts_dir`, `incoming_dir`, `key_name`, `key_basepath`, `key_file_ext`, `key_filename`. Returns `undef` on failure.

## Role & dependencies
Called by 63 modules via static literal dispatch. Heavily depends on `<crypt.C25519.base_key_name>`, `<crypt.C25519.usr_name>`, `<crypt.C25519.key_usr_home>`, and base utilities (`<[base.get_homedir]>`, `<[base.log]>`, `<[base.s_warn]>`, `<[file.last_existing_dir_path]>`, `<[file.catfile]>`).

## Observations
- **Validation FAILED**: Missing `descr` metadata field and signature footer — though a footer *is* visibly present in the source, creating a contradiction with the check output.
- **Style warning**: `format.log_singular` used at line 42 (singular form of a plural message).
- **Security**: Uses `$ENV{'USER'}` and `getpwuid($EUID)` to bind key access to the effective user. Non-root users require writable parent directories for key directory creation.
- **Fragility**: The "bare call" pattern (`<crypt.C25519.base_key_name> //= $key_name`) mutates global state during initialization, which the comment flags as a previously-bug-prone pattern.
- **Coupling**: Tightly coupled to the `<crypt.C25519.*>` module namespace; any change to base key name logic propagates here.

## Confidence
Unclear whether the signature footer is truly missing (the check says so, but the source shows one). The validation failure may indicate a different footer format is expected than what's present.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'crypt.C25519.key_vars':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 42 ]
```

#,,,,,.,,,.,.,...,,,,,,.,,,..,.,,,,..,..,,,.,,..,,...,...,.,.,,,.,,,,,..,,.,,,
#KBHB2KSNAFDVQACQO7ZNLPA6T6NPT4EDGFXJ665THIILGQEUUJGLFYASQCS5PP3YWTWSPXCZ5B5LC
#\\\|3IDBYFHNKIC47PGL4Q2JJMF7XAMN3OEMCVKER55O23HTZHOCPY5 \ / AMOS7 \ YOURUM ::
#\[7]NQSPMODX4KIICX2E4XMM7ZXXXAJQMDMCYTLA6NVO6ABJ3B6GHCAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
