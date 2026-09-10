---
module: base.X-11.get_window_geometry
generated_at: 2026-09-09T22:55:06
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 09eacd3f8867e01d9d3b0159d390d2840c9aa887
source_lines: 47
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1027
usage_completion_tokens: 622
---

# review: base.X-11.get_window_geometry

## Purpose

This module retrieves the geometry (width, height, x, y) of an X11 window by sending a command through a cube socket connection. It parses the response and returns a hash of coordinates and dimensions, or `undef` on failure.

## Interface

**Arguments:**
- `$id` (required): numerical window ID (validated with regex `^\d+$`)
- `$user` (optional, default `'cube'`): user context
- `$cmd_path` (optional, default `''`): command path prefix

**Return:** Hash reference `{ x => $x, y => $y, width => $w, height => $h }` on success, `undef` on failure.

## Role & dependencies

Fits into the X11 geometry query workflow. Notable callees:
- `<[base.gen_id]>` — generates a command ID
- `<[base.net.send_to_socket]>` — sends the request via socket
- `<[base.log]>` — logs failures

## Observations

- **Fragility:** The regex `m{^\($cmd_id\)(TRUE|FALSE) }` requires a space after the boolean, but the success pattern `m|^\($cmd_id\)TRUE (.+)$|` does not — this is inconsistent and could cause false negatives.
- **Coupling:** Tightly coupled to the cube socket protocol; the `cmd_path` is optional but its usage (`$cmd_path .= '.' if length($cmd_path)`) suggests it's meant to be a prefix, not a full path.
- **Style:** The comment `## X-11.get_geometry returns "w h x y" ##` contradicts the actual return hash keys (`width`, `height`, `x`, `y`) — the docstring is misleading.
- **Validation failures:** Missing `descr` metadata field and the module is not in the subroutine whitelist, indicating it may not be properly registered in the AMOS7 framework.

## Confidence

Unclear whether the `cmd_path` is truly optional or if it's expected to always be provided in production. Also unclear if the space requirement in the failure regex is intentional or a bug.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.X-11.get_window_geometry':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 39 ]
  ⚠ module not found in subroutine whitelist
```

#,,,,,,,,,,,,,.,,,...,.,.,..,,,,,,.,,,.,,,.,,,..,,...,..,,...,,,,,,.,,,..,..,,
#AXLD26EKXAEYCJZTKQWWN3NHRGRL5C253ZZXN3IVR32C5JLAIDUYHFFN3G4XHM3EVE2GPHM2EUDVU
#\\\|TDZJE6MN44IGSJDX6C3ZTENMZLWUCW6AMXUJHP5F4Y234D2OXE7 \ / AMOS7 \ YOURUM ::
#\[7]X6WQ27RI5QNMH3TQLDTIEOWS3NELZPHD63IGUVQF4VR4TNPZQGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
