---
module: base.file.all_links
generated_at: 2026-09-09T22:55:44
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 22fee313af5bc10e4090bb7a8754ac24057c75fd
source_lines: 74
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1211
usage_completion_tokens: 588
---

# review: base.file.all_links

## Purpose
This module recursively traverses a directory tree and returns a hash reference mapping each symlink to its target path. It also handles recursive directory traversal, optionally collecting symlinks within subdirectories.

## Interface
- **Arguments**: `$path_parameter` (directory path), `$result_href` (optional hash reference accumulator), `$silence` (optional flag to suppress warnings).
- **Returns**: A hash reference mapping file paths to symlink targets, or `undef` on error.

## Role & dependencies
This module is a leaf in the dependency graph (9 modules call it statically). It depends on several base utilities: `base.s_warn`, `base.logs`, `base.caller`, `base.str.os_err`, `base.sort`, and `catfile`. It also calls `file.all_links` for recursive subdirectory processing.

## Observations
- **Missing metadata**: The `descr` field is absent, causing validation failure. This is a structural compliance issue.
- **Not whitelisted**: The module is not in the subroutine whitelist, triggering a warning.
- **Silence flag logic**: The `$silence //= 0` default conflicts with the `$silence = 5` assignment in the `silent-recursive` branch — unclear whether `5` is a sentinel value or a bug.
- **Symlink detection**: Uses `-l` test, but the `next` condition `not -d $file_path and not -l $file_path` skips both non-directories and non-symlinks, meaning only symlinks and directories are processed.
- **Result assignment**: `$result_href->{$file_path} = $result if -l $file_path` inside the recursive branch is redundant since symlinks are already handled in the `elsif` block above.

## Confidence
Unclear whether `$recursion_entered = 5` and `$silence = 5` are intentional sentinel values or a bug. The purpose of the `silent-recursive` mode is also not fully clear from the code alone.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.file.all_links':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,,.,,..,,,.,,...,.,.,,,,,,,.,..,,.,,,,,.,..,,...,...,..,,.,,,.,.,,,.,..,,
#RCCKSBXHKC5772ESHFLCUQHNETL62KCQP5E37B4FV3VT3GZDEIDI55CAMTDMQA665R7IMMCODUZE6
#\\\|BHRHTEBT5G62E5RAV7VGQWB346P2H7NGJ2ZDNRHLRJDFYEXFULJ \ / AMOS7 \ YOURUM ::
#\[7]JNMDNU4XYW74377TU36PIAZL6GPGR7LWTEEW3YODTR2VHHC3C6CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
