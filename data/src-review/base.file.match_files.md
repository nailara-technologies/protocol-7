---
module: base.file.match_files
generated_at: 2026-09-09T10:18:29
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 972aba15f6b9c80bfeb2e4be5c4b7c2baaab53e1
source_lines: 117
dep_graph_callers: 17
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1480
usage_completion_tokens: 587
---

# review: base.file.match_files

## Purpose
This module recursively scans a directory tree for files matching wildcard patterns (`*` and `**`). It converts wildcard patterns to compiled regexes, matches them against file paths, and returns matching file paths in either list or array reference context.

## Interface
- **Arguments**: `[result_array_ref]` (optional append mode), `<search_path>`, `<file_name_pattern(s)>`
- **Return**: List of matching file paths (or array reference in scalar context)
- **Context**: Returns `undef` on error (e.g., invalid regex, unreadable directory)

## Role & dependencies
This module is a leaf in the dependency graph (17 callers with static literal calls). It depends on:
- `base.eval.comp_regex` — converts wildcard patterns to regex
- `base.s_warn` — warning output
- `base.sort` — sorts directory entries
- `catfile` — path concatenation (external)
- `base.file.match_files` — recursive self-call for subdirectories

## Observations
- **Fragility**: The module has incomplete metadata (missing `descr` field, missing signature footer) — validation FAILED per the deterministic check.
- **Coupling**: Tightly coupled to `base.eval.comp_regex` and `base.s_warn`, making it hard to test in isolation.
- **Style**: Uses AMOS7-specific pragmas (`##` comments) and inline type checks (`ref $ARG[0] eq qw| ARRAY |`).
- **Potential issue**: The regex compilation error handling returns `undef` immediately, which may propagate silently to callers expecting a list.
- **Edge case**: The `last` after a match prevents matching multiple patterns per file, which may be intentional but isn't documented.

## Confidence
Unclear whether the `last` after a match is intentional (first-match semantics) or a bug (should continue to try all patterns). Also unclear if `catfile` is a standard Perl function or another AMOS7 module.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.file.match_files':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer
```

#,,,,,,,,,...,,,,,,,,,..,,,,,,.,.,,.,,...,,..,..,,...,..,,.,.,.,,,.,.,,.,,,,,,
#DDEAXYVWCKAAVV44UMKKKET4GIZR5DLDTFNG45AFCHRJLBSC3M3DVXDFJIV45IEHF2EAPXFCVBODO
#\\\|2HLX5EMUT5GODYQIS6B4AMKDBKTM3NG3YVNJDUUCAFVLM32WLVE \ / AMOS7 \ YOURUM ::
#\[7]QYAD7Z4FMFYD2GBRD4SFXU3O7IUDZADFDL32EOXV2LTSI2LMIMDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
