---
module: base.source.collect_file_list
generated_at: 2026-09-09T10:22:11
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 7fbe4c8e7beb5c774f406a58787e188931a8cc4a
source_lines: 276
dep_graph_callers: 15
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3133
usage_completion_tokens: 558
---

# review: base.source.collect_file_list

## Purpose
This module collects and resolves file paths from source file lists, supporting wildcards, recursive directory scanning, and exclusion patterns. It normalizes paths to absolute form, deduplicates results, and returns a sorted list of source paths.

## Interface
**Arguments:** An array or array reference of source file paths (strings or directory paths).
**Return value:** An array of deduplicated, sorted absolute source paths. Returns `undef` on fatal errors.

## Role & dependencies
This module is a utility in the `base.source` namespace, called by 15 other modules. It depends on several internal AMOS7 functions: `<[base.getcwd]>`, `<[base.s_warn]>`, `<[base.logs]>`, `<[base.exit]>`, `<[base.sort]>`, `<[file.match_dirs]>`, and `<[file.all_files]>`. It also uses Perl's `File::Spec` module.

## Observations
- **Missing metadata:** The deterministic check reports a missing `descr` field and signature footer — a validation failure that should be addressed.
- **Fragile error handling:** The `$error_exit` flag is set but inconsistently used; some branches call `<[base.exit]>` while others only `warn` and `return undef`.
- **Complex glob logic:** The wildcard matching section is dense and hard to follow, with multiple `grep`/`map` chains that could be simplified.
- **Potential false positives:** The comment `## improve : could have false positives ## [ LLL ]` hints at a known issue in the exclusion pattern matching logic.
- **Style:** Uses AMOS7-specific syntax (`<[func]>` calls, `qw|...|` quoting) that may be unfamiliar to Perl developers outside this codebase.

## Confidence
Unclear whether `<[file.all_files]>` handles permission errors gracefully, and whether the `uniq` call is a custom AMOS7 function or a typo for a standard utility.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.source.collect_file_list':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer
```

#,,.,,,,.,...,,..,...,...,...,.,,,.,.,,,.,,..,..,,...,...,...,,,,,...,,,,,,.,,
#UWIC5NNV6XILKEAQFP3J6TR2GHE22IEUBMEHPKPAIZXS4MRXTXRIP5EBRMZC4FTHTZYPJIXPWX73I
#\\\|OORGHFZVHY66IN3IVPDUGXW3LG3VOWTF32CMJ2F74XBVZ3DN44B \ / AMOS7 \ YOURUM ::
#\[7]BNHA436NT2XREQCNGRPJ5ZO5KM2KFKZUAYT2ENVHEDV5GADTW2CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
