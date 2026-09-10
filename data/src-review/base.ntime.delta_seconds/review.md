---
module: base.ntime.delta_seconds
generated_at: 2026-09-09T23:41:55
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 4b0ea011a5163925df90c1d669a6d4c7d819cbec
source_lines: 59
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1089
usage_completion_tokens: 598
---

# review: base.ntime.delta_seconds

## Purpose
This module computes the delta between two network time values, returning a formatted string representing the time difference in seconds. It handles both numeric and BASE32-encoded time inputs, with an optional end time that defaults to the current time.

## Interface
**Arguments:** `$ntime_start` (required), `$ntime_end` (optional).
**Returns:** A formatted string `"%.*f"` containing the delta in seconds, or `undef` on error.

## Role & dependencies
This module is called by 6 other modules (static literal calls). It depends on:
- `regex.base.base_32` — for time validation regex
- `base.ntime_BASE32_to_numerical` — for decoding BASE32 time values
- `base.s_warn` — for warning output
- `base.ntime` — for generating current time

## Observations
- **Validation failure:** The module lacks a required `descr` metadata field, causing validation to fail.
- **Fragile global state:** `$LAST_PAREN_MATCH` is a global variable used to determine precision, creating coupling and potential race conditions.
- **Malformed regex:** `qr|^$base_regex$|` is syntactically incorrect — `$base_regex` is a scalar variable, not a regex pattern. This should be `qr|$base_regex|` or similar.
- **Hardcoded divisor:** The division by `4200` is arbitrary and undocumented, making the output scale opaque.
- **Style:** The module uses Perl 5.10+ features (`//`) and embedded comments with signatures, consistent with AMOS7 conventions.

## Confidence
Unclear whether `$LAST_PAREN_MATCH` is intended to be a module-level package variable or a global — this affects thread safety and testability. Also unclear if the `4200` divisor is a known constant or an implementation detail.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.ntime.delta_seconds':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,.,,..,,...,,,.,,..,..,,,..,,,.,,.,,.,,,,,,,..,,...,...,.,.,..,,...,,.,,...,
#JDGYYZO6V3MOQHH62FJRHPG7ZTNZEVGSHE6UIQIYP3RDYY5EUBIRMR2ZXO4PMTPDR26FADY3O5DIU
#\\\|5Z4QMZ64MNMDQDLS5XJYCYN5UZH6S6NGNZ6U4LHYZLAXWDVC5HR \ / AMOS7 \ YOURUM ::
#\[7]PPSRRRXYRJGK4V5CLQWYF4A7HG3MVRGRDK66MIC4BCUYFYELQIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
