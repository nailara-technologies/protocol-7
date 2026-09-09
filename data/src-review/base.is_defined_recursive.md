---
module: base.is_defined_recursive
generated_at: 2026-09-09T10:07:46
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 8778b06ed9bcdb96b78075c758aac7780bb4362f
source_lines: 32
dep_graph_callers: 40
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 819
usage_completion_tokens: 641
---

# review: base.is_defined_recursive

## Purpose
This module checks whether a given key exists and is defined within a hash reference (defaulting to `*data{HASH}`). It traverses a hierarchical key path and returns a boolean indicating the presence and definition status of the final key.

## Interface
- **Arguments**: `$data_key_str` (string, the key path to check), `$data_ref` (optional hash reference, defaults to `*data{HASH}`)
- **Returns**: `TRUE` (key exists and is defined), `FALSE` (key not present), `undef` (invalid key string parameter)

## Role & dependencies
The module is called by 40 other modules (per the dep-graph). It depends on `base.parser.data_hkey_tree` for parsing the key string into a tree of keys. It's a utility for safe key access without triggering undefined value warnings.

## Observations
- **Validation failure**: `validate_module` reports "missing signature footer" despite a footer appearing at the bottom. This is a contradiction that needs investigation — the footer format may not match AMOS7 expectations.
- **Line too long**: The description line exceeds 78 characters (80 > 78), violating module convention.
- **Redundant return statements**: Three consecutive `return` statements (lines 27–29) are mutually exclusive; only one will ever execute. This is logically sound but stylistically redundant.
- **Early exit on invalid syntax**: If `@dtree` is empty, the function returns `undef` without a clear message, which may confuse callers expecting a boolean.
- **No error handling**: If `$data_ref` is not a hash reference, the code will die on the first `foreach` iteration.

## Confidence
Unclear why `validate_module` fails with "missing signature footer" when the footer is visibly present in the source. The footer format may differ from what the validator expects, or the validator may have a bug.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
## convention violations [ 1 files scanned, 1 issues ] ##

[src/base.is_defined_recursive]
  L4     line_too_long     80>78  # descr = return TRUE if %data key exists, 5 when defined and 0 when n
```

### validate_module

```
Validation FAILED for 'base.is_defined_recursive':

ERRORS:
  ✗ missing signature footer
```

#,,,,,,..,,,.,,,.,...,,..,,.,,..,,.,.,.,,,,,,,..,,...,..,,..,,,..,,,.,...,,,.,
#D5YU3E2AK6BGDEPAP537E4NQQWOCTQSOILQRFDI4GQN6GU375UYHJ3FIBDMSV7H32ITLVCHM7UID6
#\\\|XPGLGV3DCVT4JYFRJLYMRRI5AGKBZUFAJB5IUMBA6CMPAHAHTDI \ / AMOS7 \ YOURUM ::
#\[7]3E2AKXK5RK6QHRK2CEKBZQLBWKI5TY57PNL4P3BDRFIGN7ML2CAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
