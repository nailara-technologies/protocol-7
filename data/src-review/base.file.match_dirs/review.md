---
module: base.file.match_dirs
generated_at: 2026-09-09T23:39:40
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 46345ed63507b9b405f154b70c7dbed53f6aa07e
source_lines: 117
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1478
usage_completion_tokens: 634
---

# review: base.file.match_dirs

## Purpose
This module recursively scans a directory tree for subdirectories matching one or more wildcard patterns (e.g., `*`, `**`). It returns matching directory paths, optionally appending to a provided array reference.

## Interface
- **Arguments**: `[result_array_ref]` (optional append mode), `<search_path>`, `<dir_name_pattern(s)>`
- **Return**: Array of matching directory paths (list context) or array reference (scalar context)
- **Patterns**: `*` matches `[^\.]*`, `**` matches `.*`

## Role & dependencies
Fits into the `base.file` namespace as a directory-matching utility. Notable callees: `<[base.eval.comp_regex]>` (regex compilation), `<[base.s_warn]>` (warning output), `<[base.sort]>` (sorting), `catfile` (path joining). Called by 6 modules via static literal dispatch.

## Observations
- **Fragility**: The `recursion_entered` flag logic is convoluted and appears to have a dead branch (`if ( not $recursion_entered )` nested inside itself). The `undef $regex_aref->@*` line is unreachable.
- **Coupling**: Tightly coupled to `<[base.eval.comp_regex]>` and `<[base.s_warn]>` — hard to swap implementations.
- **Style**: Heavy use of AMOS7-specific syntax (`<[...]>` calls, `qw|...|`, `->@*` dereferencing) makes it opaque to non-AMOS7 readers.
- **Validation failure**: The module lacks a required `descr` metadata field, causing validation to fail.
- **Edge case**: Trailing slashes are stripped from the search path, but the behavior with empty pattern arrays returns `undef` with a warning.

## Confidence
Unclear whether the `recursion_entered` flag is intended to prevent re-scanning or if it's a bug. The nested `if ( not $recursion_entered )` block appears logically dead. Also unclear if the `append mode` (array ref) is meant to accumulate results across recursive calls or just pass through.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.file.match_dirs':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,..,..,,...,,,.,,.,,..,,,,,,.,,,,,,,,,,,...,..,,...,..,,.,.,..,,,.,,,..,,,.,
#MXT4ILHWKKIAJ4F7U3T6VRQ64TCMXFBXTTKWTR4FAQPPRXSXGTU4XCOMDMIM7VVPMESCA7UA4EFN4
#\\\|B6TOT7BQTBCGAAHR2OEKKTF3Y2JG5XKM5LNG5CJZ725QHQMVYQS \ / AMOS7 \ YOURUM ::
#\[7]LYZJOQAKCQSWKHQ3JN2EVN7TTFZRV23CGI6Q6LEAEXOA437DIGAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
