---
module: editor.control.get_display_value
generated_at: 2026-09-09T23:44:56
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: bb03fdf2db1353dae872f5736c017268b75941ef
source_lines: 101
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1578
usage_completion_tokens: 634
---

# review: editor.control.get_display_value

## Purpose

This module converts stored field values into display-ready strings, acting as the boundary between what a field HOLDS and what a renderer may PUT ON SCREEN. It handles masked fields, list summaries, and cycler fields, returning a display string or `undef` if the value is undefined.

## Interface

**Arguments:** `$editor_state` (HASH), `$field` (name string).  
**Returns:** A display string (masked, summarized, or rendered) or `undef` if the value is undefined.

## Role & dependencies

Called by 6 modules (static literal calls). It depends on:
- `editor.control.get_value` — retrieves the raw stored value
- `editor.control.list.summary` — generates list field summaries
- `editor.control.cycler.render` — renders cycler choice sets

It is zenka-agnostic: custom rendering via `display_override` is delegated to caller-specific code rather than leaking caller knowledge into this shared module.

## Observations

- **Masked fields** use a `mask_stars` array for per-character star counts; if desynced, it falls back to flat masking (`*` × length). This is a safety fallback but may hide real password length.
- **Cycler fields** render choices with the current one bracketed (e.g., `+ [full_name] | phone | shell`). The width reservation is handled by `user-edit.form.build_frame` using the same code to prevent drift.
- **`display_override`** allows per-field custom rendering without extending this module, preserving modularity.
- The deterministic check reports no convention violations and validation passed.

## Confidence

Unclear on the exact behavior of `editor.control.list.summary` and `editor.control.cycler.render` — their internal logic is opaque here. Also unclear whether `display_override` is commonly used or a rare edge case.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'editor.control.get_display_value'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,,..,..,,,.,,.,.,.,.,...,.,.,,,,,,,,,,.,,..,,...,...,.,.,...,.,.,.,,,..,,
#5XG6VWFRPSY7H7QNQ5ODWBQ4PWIMB27J6FIYQZ2SN7X24CZHOJE33XHXCRWTEDOKGHML7EHC5S7AG
#\\\|ED3CMS6O45TBUL7U4WWG4ADGEYKT5A2NZTQZKIB6HDOIWJEH7LP \ / AMOS7 \ YOURUM ::
#\[7]X76OT73F2TNX7UXBPL3A2D6LRCQP6CXLYKUKLUSMIXDZH7HDKACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
