---
module: base.n2u_time
generated_at: 2026-09-09T23:04:13
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 1a7fb9cdec19235ad85b3105c4d370ef461ee5ce
source_lines: 47
dep_graph_callers: 8
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 923
usage_completion_tokens: 537
---

# review: base.n2u_time

## Purpose
This module converts numerical nailara network time values to Unix time-stamps. It accepts a network time value and an optional precision parameter, then returns a cleaned Unix timestamp.

## Interface
- **Arguments**: `$network_time` (required, numeric string), `$precision` (optional, integer 0–13)
- **Return**: A cleaned Unix timestamp string, or `undef` if input is invalid

## Role & dependencies
The module is called by 8 other modules (per the dep-graph). It depends on two other base modules: `base.ntime_ustart` (provides the epoch offset of 1023228000) and `base.round_truncate` (applies rounding). The division by 4200 is the core conversion factor.

## Observations
- **Fragility**: The regex `m|\.(\d+)0*$|` for inheriting precision is brittle — it assumes trailing zeros after the decimal point, which may not hold for all inputs.
- **Coupling**: The module relies on `base.ntime_ustart` being defined via `//=`; if that module is missing or altered, behavior breaks silently.
- **Style**: The data signature at the bottom (base64-like string with AMOS7 markers) is non-standard and could confuse static analysis tools.
- **Precision handling**: The "samitizing" step strips trailing zeros and zeros before non-zero digits, which may alter expected precision semantics.
- **Validation**: The deterministic check reports no violations and validation passed, suggesting the module conforms to Protocol-7 conventions.

## Confidence
Unclear whether the `base.round_truncate` function handles negative numbers or edge cases like `0.000`. The precision inheritance logic (defaulting to 17 if too large) seems arbitrary without documentation.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.n2u_time'
No issues found.
```

#,,..,,.,,,..,,,.,,..,,,.,,,.,,,,,,,.,.,.,,,.,..,,...,...,,,.,,.,,,,,,,..,.,,,
#CLR4EG2DHPUSD4TUJXQN4PKQQVVKZF5AGZ6TKZR6KNQVBTEX4ICH6QVIK5TA2222L6LTFHB5PRQ3Y
#\\\|MQRVPFNNARTKIMOGMTHXMQ2CLJBYF4VBGPNPBVUCX56QBXGM6AS \ / AMOS7 \ YOURUM ::
#\[7]2DMX5WAG4QZHOV6XUPYCS6IP27HXSHZO6PPXZYLTPKGIYAUOV2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
