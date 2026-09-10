---
module: route.bmw384.visual.arc-opacity-map
generated_at: 2026-09-09T23:49:03
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 5ea29e74545f5931b78a440206d1a11bda354abc
source_lines: 64
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1169
usage_completion_tokens: 679
---

# review: route.bmw384.visual.arc-opacity-map

## Purpose

Computes per-arc opacity modifiers for subtractive translucency effects. It builds an occupancy map from a list of module names, then calculates a modifier for each of 26 arcs based on neighbor occupancy patterns and a configurable intensity/expanse.

## Interface

- **Arguments**: `$names` (arrayref of module names), `$by_name` (BMW384 index hashref), `$mode` (integer: 0=disabled, 1=CW/CCW, 2=CCW, 3=CW), `$intensity` (float, defaults to config or 0.5), `$expanse` (integer, defaults to config or 3).
- **Returns**: A hashref mapping arc indices (0–25) to opacity modifier values in [0.25, 1.0].

## Role & dependencies

Fits into the BMW384 translucency pipeline. Depends on `$by_name` (external index lookup) and a config file (`route.bmw384.cfg`). Called by 6 modules via static literal dispatch. Notably uses `%mod` as a local hash and relies on a 26-element circular buffer for arc topology.

## Observations

- **Fragility**: The `last` statement after finding the first colored neighbor means only the nearest neighbor contributes to resilience, while all unoccupied neighbors contribute to leak. This asymmetry may be intentional but is worth verifying.
- **Coupling**: The `0.5` intensity scaling factor is hardcoded; the comment claims it "matches original" but there's no reference to verify this.
- **Style**: The data signature comment at the bottom is non-functional and adds noise.
- **Warning**: The module is not in the subroutine whitelist, which may indicate it's untracked or newly added.
- **Edge case**: When `$mode == 0`, the function returns `{}` immediately, bypassing all computation.

## Confidence

Unclear whether the `0.5` intensity scaling is empirically validated against a prior implementation. Also unclear what the "original" behavior was that this is meant to match.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'route.bmw384.visual.arc-opacity-map'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,,.,,.,.,,.,,...,.,.,,,,,,,.,.,,,.,.,,,,,..,,...,...,..,,.,,,,.,,...,,,,,
#RNYJPTJTQIXIEX6S3DLMS5FGMLXE3I6P4CRCFGHCNIQB43WUYHFMQOZ3ORA24MGMABQ52RGX3I4PS
#\\\|FUTZ44VEBEFQRRSU5YF5MNR2KXUBXAHFLUXCJYD72MN6CDYRUCB \ / AMOS7 \ YOURUM ::
#\[7]GNF2373DYWYZF4ZEVNAKORBP52D6ZY3K5V5RYYJRXMJHG6QLWQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
