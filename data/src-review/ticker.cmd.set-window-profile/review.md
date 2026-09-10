---
module: ticker.cmd.set-window-profile
generated_at: 2026-09-09T23:17:44
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 3ecbac73541d3571261a55b6b1d8f00b70bb910d
source_lines: 87
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1220
usage_completion_tokens: 719
---

# review: ticker.cmd.set-window-profile

## Purpose
This module switches the ticker window's placement profile at runtime. It validates the requested profile against a predefined set (fullscreen, bottom-strip, top-strip, bottom-right, top-right, center, saved, config), calculates the resulting geometry, and applies it to the ticker window.

## Interface
**Input:** A hash reference with an `args` key containing the profile name (defaults to `'bottom-strip'`).
**Output:** A hash with `mode` (boolean-like) and `data` (status message). Returns `{ mode => 'false', data => '...' }` on failure, `{ mode => 'true', data => '...' }` on success.

## Role & dependencies
This is a command handler invoked by the ticker subsystem. It depends on:
- `<ticker.window.profile>` — must be set before calling
- `<ticker.obj.window>` — the ticker window object
- `<ticker.mouse.swap_edge>` — determines if per-monitor placement is active
- `<ticker.select_monitor>` — used when swap mode is enabled
- `<window.gtk.profile.apply>` — applies the calculated geometry
- `<base.logs>` — logs the result

## Observations
- **Fragility:** The module assumes `<ticker.window.profile>` is already set externally; no fallback is provided if it's undefined.
- **Coupling:** Tightly coupled to GTK window geometry via `<window.gtk.profile.apply>`. The legacy X11 coordinate variables (`<x11.window.width>`, etc.) suggest a dual-backend architecture that may be redundant.
- **Style:** AMOS7 syntax is used throughout (e.g., `<[window.gtk.get_screen_size]>`). The regex literal spans multiple lines with `x` modifier.
- **Potential issue:** The monitor offset is only applied when `$monitor` is defined, but `$monitor` is only set inside the `if ( <[base.cfg_bool]>->(<ticker.mouse.swap_edge>) )` block. If swap mode is off, `$monitor` remains undefined and the offset is skipped — this appears intentional but could be clearer.

## Confidence
Unclear whether `<ticker.window.monitor>` being set to `follow-pointer` or `cycle` affects the geometry calculation beyond the monitor offset logic. The `saved` and `config` profiles are accepted but their behavior is not documented in this module.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'ticker.cmd.set-window-profile'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,.,.,.,,,.,.,,..,,.,,,,.,.,,,...,.,,,...,..,,...,...,,..,.,.,..,,.,.,.,.,
#H3J64UXXBLQ6Q2C2OXXZ36ZFR3LOXTMFRCO347ZGTM2MK5M53XWCJAZDYI5YI6ZGFOTA5KQGYRAB2
#\\\|BRSJ4TTQXHREPTWTYVKYFJMMY4RCUV565UZRJTAIY7FRPAP6C64 \ / AMOS7 \ YOURUM ::
#\[7]RJIWGS4D2KPBQ44IGAKG5BNM2TJAVSM6EWUWVFKLDPHU7E5Z4SAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
