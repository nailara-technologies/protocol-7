---
module: crypt.C25519.key_exists
generated_at: 2026-09-09T22:36:36
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 174b96e37f5c0c85250394d4e8d2b1b761271c48
source_lines: 48
dep_graph_callers: 29
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 960
usage_completion_tokens: 628
---

# review: crypt.C25519.key_exists

## Purpose
This module checks whether a given key name or filename exists within the user's key directory for C25519 (Ed25519) cryptographic operations. It returns a boolean indicating presence, or `4` to signal a virtual key (seed phrase).

## Interface
- **Input**: `$name` — a key name or filename string (required, otherwise warns and returns `undef`)
- **Output**: `TRUE` (key found), `FALSE` (key not found), `4` (single virtual seed-phrase key found), or `undef` (on error)

## Role & dependencies
This is a utility called by 29 other modules (static literal calls). It depends on:
- `crypt.C25519.regex.key_files` — regex for key file patterns
- `crypt.C25519.get_usr_keys_dir` — cached via `state` for the key directory path
- `file.get-non-dirs` — retrieves non-directory entries from the key directory

## Observations
- **Caching**: The `state $key_dir //= ...` pattern avoids repeated directory lookups — good for performance.
- **Virtual key detection**: Returns `4` when exactly one key matches and it ends with `:seed-phrase`, distinguishing virtual from real keys.
- **Regex construction**: The `qr|^(\Q$name\E$re_kfiles)$|` pattern safely interpolates the name into a regex using `\Q...\E` for literal matching.
- **Style**: The `##[ once ]##` and `##[ comment ]##` annotations follow AMOS7 conventions. No convention violations reported by the checker.
- **Potential fragility**: If `$re_kfiles` is undefined, the module warns and returns `undef` — callers must handle this. The `-r` check on `$key_dir` is noted as already warned in `get_usr_keys_dir`.

## Confidence
Unclear whether `file.get-non-dirs` handles symlinks or special files — the module assumes it returns only regular files. Also unclear if the regex pattern in `key_files` is guaranteed to be non-empty and well-formed.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'crypt.C25519.key_exists'
No issues found.
```

#,,,.,...,,.,,,,,,,..,,.,,,,,,.,.,,,,,..,,...,..,,...,..,,..,,..,,.,,,,.,,,,.,
#3YBJCYXJB6BYZWZDRTSCBJTO3K5LBKBNPXZ4WQVVSKBUVIEJZH5MAVTVSN27OZ75ZGFRI7QXG4YCU
#\\\|3LFYVPMWDVCZH5VWH7QJ6VOIP5KFLWHX5WLPURDL4COETXH5P2W \ / AMOS7 \ YOURUM ::
#\[7]LFWCGAG5GXOHQDITDW5QDF5UPQH4NFYWZZ5PRSIER7W5L2OAECCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
