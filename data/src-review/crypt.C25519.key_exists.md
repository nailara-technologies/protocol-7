---
module: crypt.C25519.key_exists
generated_at: 2026-09-09T10:09:17
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: b1281dc509d957b595c1410c34d2bdbcb536d16d
source_lines: 47
dep_graph_callers: 29
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 958
usage_completion_tokens: 560
---

# review: crypt.C25519.key_exists

## Purpose

This module checks whether a given key name or filename exists within the user's key directory. It supports both key filename syntax and key name syntax matching against files in the key directory, returning a boolean or a special code for virtual seed-phrase keys.

## Interface

**Arguments:** `$name` — a key name or filename to search for.

**Returns:** `TRUE` if the key is found, `FALSE` if not found, or `4` if a single virtual seed-phrase key is found. Returns `undef` on error (missing parameters or regex definitions).

## Role & dependencies

This module is called by 29 other modules (static literal calls). It depends on:
- `<crypt.C25519.regex.key_files>` — regex for key file patterns
- `<crypt.C25519.get_usr_keys_dir>` — provides the key directory path
- `<file.get-non-dirs>` — retrieves non-directory entries from the key directory

## Observations

The module has two validation failures: missing `descr` metadata field and a missing signature footer. The `state $key_dir //= ...` uses a once-evaluated default, which is appropriate for a directory path. The double `grep` pattern (filter non-dirs, then match names) is functional but could be simplified. The return value `4` for virtual seed-phrase keys is an unusual convention that callers must handle. The regex construction `$match_re = qr|^(\Q$name\E$re_kfiles)$|` properly escapes the name but relies on `$re_kfiles` being defined at runtime.

## Confidence

Unclear whether the `4` return value is consistently handled by all 29 callers. Also unclear if the `state` variable's default is always initialized before first use in all execution paths.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'crypt.C25519.key_exists':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer
```

#,,..,..,,..,,.,.,.,,,.,,,,,,,...,.,.,..,,,.,,..,,...,...,,.,,,,,,.,,,.,.,,,.,
#N7L6KB6YSMXKZQ7NULZXWTFRF7OHGBRQGGRL2BHHHKXV727V6ULR6LBNGWF2MXD6OZCVJW3ELHH3C
#\\\|WODWZL25ASR4XXNDRJDSHPMHYXQOEK23DMMGTLYU2D2TRYSVZIH \ / AMOS7 \ YOURUM ::
#\[7]H77HZXXX27OPPJ52QNAEA4G77GQRLOE23TGN7BOVCDWWSVUHWSCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
