---
module: coding.async.stream_tps
generated_at: 2026-09-09T22:59:16
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 32b527852bb195856e5fe6e9f4970ccddd3f8fe6
source_lines: 141
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2253
usage_completion_tokens: 635
---

# review: coding.async.stream_tps

## Purpose
This module tracks live token throughput per in-flight request and derives an absolute outer timeout cap from observed generation rates. It measures real-time tokens/sec and scales a backstop timeout based on model context size and observed throughput, with a static per-backend fallback until sufficient samples are collected.

## Interface
Takes a `$mode` string and `$state` hashref. Modes: `update` (feed chunk-arrival observation), `get_cap` (return current absolute cap), `get_tps` (return last measured tokens/sec), `is_alive` (liveness signal). Returns a scalar (cap, tps, boolean) or a hashref with `mode`/`data` on error.

## Role & dependencies
Fits into the timeout stack as a live-derived backstop. Called from `coding.handler.http_io` after the parse loop. Depends on `coding.cfg.round_cap_*` configuration values, `coding.inference_servers` for backend context size, and a custom `<[base.time]>` accessor. Notably shares the `stream_alive` liveness signal with `coding.handler.http_timeout` and the stall watcher.

## Observations
- **Fragility**: `stream_alive` depends on `<[base.time]>->(3)` — unclear what this accessor does and whether it's stable across deployments.
- **Coupling**: The `recompute` subroutine assumes a chunk just arrived when called from `update`, making it unsafe to call during stalls (correctly gated by `get_cap`).
- **Style**: Uses `@ARG` instead of `@_`, and `shift` for mode — non-idiomatic Perl that may confuse readers.
- **Bare keys warning**: `modedata.bare_keys` at line 135 — the `mode => qw| false |` hash uses bare keys, which the validator flagged.
- **Margin constant**: `1.3` is hardcoded; unclear if this is tuned or arbitrary.

## Confidence
Unclear what `<[base.time]>->(3)` returns or whether it's a stable accessor. Unclear whether `coding.inference_servers` is always available or if `$n_ctx` could be `undef` in edge cases.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'coding.async.stream_tps'

WARNINGS:
  ⚠ modedata.bare_keys : 2 occurrences [ first at line 135 ]
```

#,,,.,,,.,,.,,,.,,,,,,...,,.,,.,,,,.,,,..,..,,..,,...,...,...,,.,,,,.,.,,,.,,,
#RJQTFYUBTNBNR5H7MFANYRVY6TDLSYYKGMKQBJNVBLDCDPYXBAIISDIFAKTL5T7OSGS6HS2RM3HDS
#\\\|HGF3ACWCKDY2WGYY7C4RAWKHSMFVQKZVMZGZ5VGS6HEPWGRMAAQ \ / AMOS7 \ YOURUM ::
#\[7]P33O33XLY2U5GVA7FTT2Q6KBMSHKZT3CRYTZ6BYHRVA7KJTP4WBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
