---
module: ascii.frame.render
generated_at: 2026-09-09T22:39:38
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 0e52f44a9bf16b500fa97c7f36bc91e9c42189e3
source_lines: 310
dep_graph_callers: 13
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3627
usage_completion_tokens: 1140
---

# review: ascii.frame.render

## Purpose

This module renders ASCII art frames by combining a frame descriptor (borders, corners, slots) with slot values into a formatted string. It computes the required frame width from content and borders, then renders top/bottom borders and content rows with proper padding and alignment.

## Interface

**Input:** A hashref `$params` containing:
- `descriptor` → hashref with `border`, `corners`, `min_width`, `padding`, `slots`, `static_rows`, `margin`
- `values` → hashref mapping slot names to their values

**Output:** A newline-joined string representing the rendered frame, or `undef` if the descriptor has no keys.

## Role & dependencies

Called by 13 modules via static literal dispatch. It recursively calls `ascii.frame.render` for composed slots and `ascii.frame.render.border_line` for border rendering. It serves as the primary content renderer for the ASCII frame system.

## Observations

- **Width calculation bug in composed slots:** For `composed` type slots, `$required_width` is set to `$content_width` where `content_width = inner_width - border_left - border_right`. This compares *inner content width* against *outer frame width*, which underestimates the required width. The `inner_width` is the total inner frame width, not just content.

- **Double-border risk:** Composed slots render their inner frame (which already has borders), then the outer frame applies its own borders on top. The comment claims "inner frame line already has its own borders pad or trim to fit outer frame width" — but the code simply wraps the inner output with outer borders, potentially creating nested borders.

- **Fragile static row stripping:** The `static_rows` stripping logic assumes borders are prepended/appended to static content. If static rows don't match the border pattern, they're rendered with borders anyway — a silent mismatch.

- **`block` slot padding:** The fill width calculation uses `$frame_width` but subtracts `$lpad` and `$rpad` — these are *outer* padding values, not inner padding. If a block slot has its own internal padding, this misaligns.

- **`composed` slot width:** The `required_width` computation for composed slots uses `inner_width - borders` as the content width, but the rendering trims to `$frame_width`. These two paths are inconsistent.

## Confidence

Uncertain whether the `composed` slot's `inner_width` field is meant to be the *total* inner frame width or just the *content* width. The width computation and rendering logic appear to treat them differently, which could cause misalignment between computed width and actual rendered width.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'ascii.frame.render'
No issues found.
```

#,,.,,...,...,.,,,,,,,,.,,,,.,..,,.,,,.,.,...,..,,...,...,,,.,,,.,..,,.,.,,..,
#IMGJSBIDJI36PI6RFTYNOBO56OI2UA7QGWAZMB7GCFAVEKEDZBFH4LVDOE2RL5A4SDCXVSQLSGGWM
#\\\|ZUYMQDLIIGSBZNSCMK3TV74HAD6IMWMOPSHT7DA2GCXOLKL2VXX \ / AMOS7 \ YOURUM ::
#\[7]PDLJC4F5UF6PB5OQ45WUJVWUQOKIWNQ5YMDRKDNZ5VR4VG3DPSAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
