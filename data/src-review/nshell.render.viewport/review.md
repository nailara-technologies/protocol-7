---
module: nshell.render.viewport
generated_at: 2026-09-09T23:15:16
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: f5eb62c65d636d9ca0a454adf74b85684cedaca3
source_lines: 153
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2080
usage_completion_tokens: 615
---

# review: nshell.render.viewport

## Purpose
This module renders a single-line viewport with horizontal scrolling when content exceeds terminal width. It displays configurable overflow markers (`<` / `>`) at line edges and maintains a `view_offset` to keep the cursor visible within the viewport.

## Interface
Takes `$editor` and `$colors` as arguments. No explicit return value — it prints directly to STDOUT and flushes.

## Role & dependencies
Fits into the `nshell.render` subsystem. Notable callees: `editor.control.get_value`, `editor.control.get_cursor`, `nshell.cfg.term_cols`, `nshell.cfg.overflow_marker_left/right`, `nshell.state`, and `AMOS7::TERM::terminal_size()`. It reconstructs the byte view at the boundary to remain byte-identical to the old `AMOS7::TERM` path.

## Observations
- **Fragility**: The `terminal_size()` fallback uses `eval` with a bare `// 80` — if `terminal_size()` throws an exception, it silently falls back to 80. The `eval` block is not wrapped in a `try/catch` equivalent.
- **Coupling**: Tightly coupled to `nshell.cfg` and `nshell.state` for config and state persistence. The `view_offset` is mutated directly in the state hash.
- **Style**: The code uses a mix of Perl idioms — `//` for defaults, `//=''` for empty defaults, and `// 0` for numeric defaults. The `eval` usage for `terminal_size()` is unusual and may be a workaround for a missing API.
- **Potential issue**: The `min_content_w = 4` floor could cause incorrect scrolling behavior for very short lines with markers enabled.
- **Check outputs**: The module passed `validate_module` and `module_convention_check` with no violations, but the warning about missing subroutine whitelist suggests it may not be formally registered in the module registry.

## Confidence
Unclear whether `AMOS7::TERM::terminal_size()` is a real module or a placeholder stub. The `eval` fallback behavior is not well-documented in the code.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'nshell.render.viewport'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,..,,,..,.,,,..,,.,.,,,,,,,,,,,,,,..,.,,,..,,...,...,,..,,..,,..,..,,..,,
#IXVGTG5GDSHJQFY5R2YISGARA7ZDRXUC7NGK2IJDGBD75W3TZ4OQAQPACG4ONSTXAZEOHVI4A2ZGM
#\\\|A4TTC45XBSCT76JXM7WRQXVV6MCXHVBBZAUJ445FCJQDC5SWTIV \ / AMOS7 \ YOURUM ::
#\[7]OJUPREUFO5NCIXNDCMGH736BDZ7DXQWJKJTAWTIEDW4EDYDHAEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
