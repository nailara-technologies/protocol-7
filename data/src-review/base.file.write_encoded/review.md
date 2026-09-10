---
module: base.file.write_encoded
generated_at: 2026-09-09T23:10:09
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 780673282568294acf123d302d0b679ac4d65fe8
source_lines: 61
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1101
usage_completion_tokens: 911
---

# review: base.file.write_encoded

## Purpose
Writes data to a file with a specified encoding, overwriting any existing content. It accepts an encoding parameter (raw, bytes, or encoding(...)) and a list of content values to write.

## Interface
- **Arguments**: `$encoding` (encoding format), `$write_file_path` (target file), `@file_content` (scalars, arrays, or refs)
- **Returns**: `TRUE` on success, `undef` on failure

## Role & dependencies
Called by 7 modules (per dep-graph). Uses `<[base.s_warn]>` for warnings and `<[base.str.os_err]>` for OS error strings. Validates encoding via regex before attempting `binmode`.

## Observations
- **Critical bug**: The `binmode` error message has a mismatched format string. It declares `'binmode[ $encoding ] : %s <{C1}>'` but passes two arguments (`$write_file_path` and `<[base.str.os_err]>`). This will cause a runtime error or produce a malformed warning.
- The `binmode` failure only triggers a warning and continues execution, potentially leaving the file in an inconsistent state.
- The encoding regex `^:(raw|bytes|encoding\([^\)]+\))$` allows `encoding(...)` but doesn't validate the inner content, which could lead to unexpected behavior.
- The module passes validation checks (module_convention_check and validate_module both report no issues), but these checks may not catch runtime-level bugs like the format string mismatch.

## Confidence
I am confident about the `binmode` error message bug — the format string clearly has one `%s` placeholder but two arguments are passed. I am less certain whether the encoding regex is sufficient for all intended use cases, as the check outputs report no violations but don't test runtime behavior.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.file.write_encoded'
No issues found.
```

#,,.,,.,,,,,,,,..,,,.,,.,,...,,..,,,,,...,...,..,,...,...,..,,.,.,,..,...,.,.,
#6ZURJOBPOCFVANIRDSY7UH5MW3ZCPWLOGLKGMFYGX6FUZJ6KPMYK7532X2VIZYGRNHYHL7PFBRD2C
#\\\|BR666VEFSJBIFSXVO23ZMBLN6YS42BXL4VRGORRQNNWBNG7P7JH \ / AMOS7 \ YOURUM ::
#\[7]KHI2RHLYFSE2VVQTWSDBPBMMZUIOGUMS7UO22KJ7DSJZVALBCYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
