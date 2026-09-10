---
module: sourcecode.source_path_set_up
generated_at: 2026-09-09T23:17:09
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: de264808515d6ff1208f898ee65d3377ca0bde77
source_lines: 73
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 956
usage_completion_tokens: 416
---

# review: sourcecode.source_path_set_up

## Purpose
This module establishes the source file collection paths for the AMOS7 system. It defines a whitelist of directories to include and exclusions to skip, then changes to the system root path and returns the resulting file list.

## Interface
**Arguments:** None (relies on `<system.root_path>` global).
**Returns:** A file list from `base.source.collect_file_list`, or `undef` if `chdir` fails.

## Role & dependencies
Called by 7 other modules (static literal calls). It depends on `<system.root_path>` and `<base.source.collect_file_list>`. It serves as a bootstrap module for source file enumeration.

## Observations
- **Fragility:** The module assumes `<system.root_path>` is always valid and writable; failure silently returns `undef` without propagating the error context.
- **Coupling:** Hard-coded paths (e.g., `bin/admin/**`, `data/md/**`) are tightly coupled to a specific project layout. Any structural change requires editing this module.
- **Style:** The exclusion list uses glob patterns (`!*.sh$`) which may behave unexpectedly with certain shell/perl globbing rules.
- **Metadata:** Fails the `validate_module` check due to missing `descr` field and absence from the subroutine whitelist.
- **Readability:** The long array literal with mixed inclusions/exclusions is dense and hard to scan.

## Confidence
Unclear whether `<system.root_path>` is guaranteed to exist or be a directory. Unclear if the glob patterns are evaluated literally or expanded by Perl's globbing mechanism.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'sourcecode.source_path_set_up':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,...,,..,,.,,,,.,.,.,.,,,,,,,,.,,.,.,,.,,..,,...,...,..,,,.,,...,,,,,,,.,
#NDJTNDMOTIWMDL5MMGEMHMVKGG5SUA26XFP2CVLXF2BQN4OIRJRVYOOYPTCB6BEH2ABPROKPLGATM
#\\\|QRSDEWAFGODFBLM7W5EC6FHXZRYAPT7ERNUZYCCTZYMUBPK6UEE \ / AMOS7 \ YOURUM ::
#\[7]HC2PL72Q4T7P5AS7QSXDBLMKK5UCYPYQ47BJYPXKRU6NZPXHBADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
