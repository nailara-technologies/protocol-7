---
module: base.file.open
generated_at: 2026-09-09T22:40:56
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 78a8fdfcb4b2c9b69003995eac9b924efaa90bcf
source_lines: 90
dep_graph_callers: 13
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1375
usage_completion_tokens: 875
---

# review: base.file.open

## Purpose
This module opens a file and returns a file handle. It supports optional encoding, mode specification, file creation, and permission setting. On failure, it logs errors and returns `undef`.

## Interface
- **Arguments**: `<file_path>[, <encoding>][, <mode>][, <create>[, perm]]`
- **Returns**: A file handle on success, `undef` on failure.

## Role & dependencies
Called by 13 modules via static literal dispatch. Depends on `File::Spec`, `File::stat`, and several internal AMOS7 utilities: `<[base.log]>`, `<[base.s_warn]>`, `<[base.logs]>`, `<[base.str.os_err]>`, `<[base.caller]>`.

## Observations
- **`O_CREAT()`** is not a standard Perl function — this is a potential runtime error or indicates a custom AMOS7 extension.
- **`File::stat::stat($requested_file_path)`** uses an unusual syntax; standard usage is `File::stat::stat($file)` or `stat($file)`.
- **`index( $perm, qw| 0 |, 0 ) == 0`** is a convoluted octal-detection check.
- **`join( ' ', $mode, @encoding )`** for `open()` is non-standard; `open()` expects a mode string like `'<:raw'`, not a joined list.
- **`index( $mode, qw| >> | ) == -1`** for append-mode detection is fragile — `>>` is a two-character sequence, and `index` may behave unexpectedly with array arguments.
- **`format.log_singular` warning** at line 18 indicates a style violation in the log message format.
- The `chmod` fallback block unconditionally unlinks the file when chmod fails (unless append mode), which could be a data-loss risk.

## Confidence
Unclear whether `O_CREAT()` is a custom AMOS7 macro or a bug. Unclear the exact semantics of `File::stat::stat` in this context.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.file.open'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 18 ]
```

#,,,,,,..,..,,...,.,.,,..,..,,,,,,...,.,,,.,,,..,,...,..,,..,,,,,,,,.,,,,,,,,,
#XIRZAUNAF5OHZ6EYK4P6ZOVQSQOHOYB4MGLAT24422P5R3FAFK6W3ZQLZEDXNSDQIWV2KHAW446QI
#\\\|EJF4IITJ7OVMDMCK6GAON7TJNBSVCRQQCGH2JR6XIM27ZXGVVPM \ / AMOS7 \ YOURUM ::
#\[7]5MS4GZARYL4LQRTOV3QZB3EQZI2R4UFPGBVKWZ5WRLJGSJHRSOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
