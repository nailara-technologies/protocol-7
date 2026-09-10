---
module: window.place.find_safe_position
generated_at: 2026-09-09T23:34:19
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 90f45e1cb28d27d92003ecc720338a9b0df1f6b0
source_lines: 76
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1232
usage_completion_tokens: 636
---

# review: window.place.find_safe_position

## Purpose
This module attempts to find a safe window position by iteratively testing candidate rectangles. It performs an actual move operation followed by a geometry readback for each candidate, returning the first one that successfully lands at the requested coordinates.

## Interface
- **Arguments**: `$window_id` (string/identifier) and `$candidates` (array reference of hash references, each containing `x`, `y`, `width`, `height`).
- **Return**: A hash reference merging the candidate's metadata with the actual achieved geometry, or `undef` if no candidate succeeds.

## Role & dependencies
This is a recovery utility for the class of bug where a requested window position silently fails after a monitor topology change. It depends on three external modules: `base.X-11.move-window`, `base.X-11.get_window_geometry`, and `base.logs`. The module is called by 6 other modules (per the dep-graph), indicating it's a utility used in multiple places.

## Observations
- **Fragility**: The module relies on runtime behavior of `move-window` and `get_window_geometry` — if either changes, this module breaks without compile-time detection.
- **Coupling**: It tightly couples to the exact field names (`x`, `y`, `width`, `height`) via hash slice syntax.
- **Style**: Uses hash slice `@{$candidate}{qw| x y width height |}` which is readable but slightly verbose.
- **Warning**: The deterministic check flags this module as "not found in subroutine whitelist" — a maintenance concern for static analysis tools.
- **Logic**: The `next if not defined $x or not defined $y` guard is sensible; undefined dimensions are skipped.

## Confidence
Unclear whether the placeholder syntax `<[base.X-11.move-window]>` is a macro substitution or a literal string in the source. If literal, the code would fail at runtime. Unclear whether the 6 caller count includes only static literal calls or also dynamic dispatch targets.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'window.place.find_safe_position'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,.,,,...,.,,,.,,,,..,..,,,..,,..,,,.,.,.,..,,...,...,...,,,,,...,...,..,,
#DHBDS6YNZ5TNB4HWLSLQWVHZGZ3BWMXGX4KRB6ENPUBOBFY56LU466L3GT3IIGJHIEQEY4F6UDJEU
#\\\|AJPCZIMYGH55FX7LKRNBYW6WQCVGO6P6YYJWTAWKJKUBYOYMGQC \ / AMOS7 \ YOURUM ::
#\[7]P23GF3YK7E34DHKOGL7LW2N3V2PYPOBCVUVQYA535SJILZV4U2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
