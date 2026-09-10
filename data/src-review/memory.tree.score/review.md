---
module: memory.tree.score
generated_at: 2026-09-09T23:27:29
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 68d8a3e4791e791f034b24e7a84782cfaf147690
source_lines: 119
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1758
usage_completion_tokens: 766
---

# review: memory.tree.score

## Purpose
This module computes a three-pass weighted score for a branch's children, combining recency, focus relevance, and IDF rarity, then applies a curve-based falloff by rank before reordering children by descending score.

## Interface
**Input:** A params hash containing a `node` key pointing to a branch object with `children` (arrayref) and `curve_type` (string, defaults to `'sigmoid'`).
**Output:** The same branch object, with children reordered by descending `score` and each child annotated with `w_base`, `w_focus`, `w_idf`, `w_combined`, and `score`.

## Role & dependencies
Called by 6 modules (static literal calls). Notably depends on:
- `base.ntime_BASE32_to_numerical` — converts timestamps
- `memory.focus` — topic matching with boost multipliers
- `memory.score.idf_cache` — cached IDF wordcount table
- `memory.tree.score.idf_weight` — IDF weight computation
- `memory.tree.score.rank_falloff` — curve-based rank decay

## Observations
- **Not in subroutine whitelist** — `validate_module` warns this module is absent from the whitelist, suggesting it may be dynamically dispatched or undocumented.
- **Eval-based fallback** — the `eval` block around `memory.focus.matches` is a defensive pattern but obscures control flow; the stub fallback is only triggered on exception.
- **Optional IDF cache** — if the cache is empty, all children receive neutral IDF weight (1.0), which may mask missing data.
- **Invariant check** — the `warn` for `rank_falloff` violation is a runtime guard, not a hard failure.
- **AMOS7 signature** — the encoded signature at the bottom confirms Protocol-7 provenance.

## Confidence
Unclear about the exact semantics of `base.ntime_BASE32_to_numerical` and `memory.focus.matches` without their source. Also unclear whether `memory.score.idf_cache` is always populated or if the "no cache" path is a common case.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'memory.tree.score'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,,.,,.,,,,,.,..,,.,,,,..,,,,,.,.,.,.,,,,,..,,...,...,...,..,,,,.,.,.,,,.,
#V7STP3S7W374XK2AG5G7B4LEP6JWSZW4RO6GJOZL6GSGSYN3VGDCAZQS5WLDC33BJR4ZAV3F6ZICK
#\\\|O4N7XJ44KFRCNO4VWJZDBLE7JWB3PMCZAXIUWDJPGUDQDCN7OBT \ / AMOS7 \ YOURUM ::
#\[7]Z4HRXQFEZD3KZVTK7V7GD6WXDP5HRRS5BYTS6DWFJASK3WV6QCDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
