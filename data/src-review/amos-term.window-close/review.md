---
module: amos-term.window-close
generated_at: 2026-09-09T23:50:11
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 907d5d0eafd03777cd8e873b10b1dc184b734a46
source_lines: 49
dep_graph_callers: 5
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 865
usage_completion_tokens: 568
---

# review: amos-term.window-close

## Purpose
This module closes a GTK3 terminal window by hiding it while preserving its buffer state. It handles cleanup of render timers, updates the window's visible flag, and transitions the window to a "hidden" state (state=2).

## Interface
- **Argument:** `$window_id` — a string identifier for the target window.
- **Return:** The `$window_id` on success, or `undef` if the window is not found.

## Role & dependencies
This is a leaf module in the dependency graph (5 modules call it statically). It relies on:
- `<amos-term.windows.by_id>` — window lookup hash
- `<base.logs>` — logging dispatcher
- `<amos-term.session.set_state>` — session state mutation
- `Glib::Source` — GTK timer cancellation

## Observations
- **Fragility:** The render timer cancellation assumes the key exists (`exists $window->{'watcher'}->{'render'}`), which is safe, but the GTK window reference is dereferenced without a null check before calling `hide()`.
- **Coupling:** The module tightly couples to GTK3's `hide()` method and the `Glib::Source` API, making portability difficult.
- **Style:** The data signature comment at the bottom is non-standard and may confuse static analysis tools.
- **Validation:** The module passed `validate_module` but triggered a "not found in subroutine whitelist" warning, suggesting it may not be registered in the module registry.
- **Convention:** No violations were found in the `module_convention_check` (max_line=78, max_descr=55).

## Confidence
Unclear whether the `state=2` value is consistently defined across the codebase as "hidden" — this appears to be a magic number that could be misinterpreted.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'amos-term.window-close'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,..,,,.,,..,,...,,,.,,,,,,.,,,,,,..,,,.,,..,,...,...,,,.,..,,...,,.,,.,,,
#OXNB6F7PBOEAZ5JMR5XKA4YQJ7QG3X45LX35DM6GWQH4AHYXW642SYWTLMNFFI4756LFGSSCCWH2A
#\\\|HEUUGIEBPBY3BM3K7W7BH5POJV6XPZTZHLVKPREVXRQTYBGEXI3 \ / AMOS7 \ YOURUM ::
#\[7]ULSWI6ASGYBPT5547CHUOZFHCV4K6FIC5C2SALJZ6FNZBB2RCABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
