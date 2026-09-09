---
module: base.parser.timestamp
generated_at: 2026-09-09T10:19:50
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 3ea05f3ba3d99ff9699defc5373eb2fffbda94f9
source_lines: 34
dep_graph_callers: 16
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 912
usage_completion_tokens: 656
---

# review: base.parser.timestamp

## Purpose
This module converts a numeric time value into formatted timestamp and date strings. It accepts either a Unix timestamp or a network time value (via `base.n2u_time`), then outputs formatted strings based on the requested mode.

## Interface
- **Arguments**: `$mode` (default: `qw| time-stamp |`), `$time` (default: `<[base.time]>`)
- **Return**: A space-joined string of formatted date and/or time components
- **Modes**: `time-stamp`, `time`, or `date`

## Role & dependencies
It serves as a utility parser for time values, called by 16 other modules (per the dep-graph). It depends on `base.time` (default argument) and `base.n2u_time` (for network time conversion). It uses Perl's built-in `localtime()` function.

## Observations
- **Line length violation**: The `module_convention_check` reports line 4 exceeds 78 characters (79 > 78).
- **Fragile regex**: The numeric mode detection regex `m|^(\d+)(\.\d+)?$|` only accepts integers or decimals, not epoch timestamps with milliseconds.
- **Tight coupling**: The module assumes `base.n2u_time` exists and behaves predictably; failure there would silently produce incorrect output.
- **Ambiguous mode handling**: The regex reassigns `$time` to `$1` when a numeric pattern is found, but the original `$time` argument is lost — unclear if this is intentional.
- **Style**: The comment block at the end appears to be a data signature (BNXQDAJIVPENMPMPXXZ46U3BUD3HCKXB54DRXNEHCG6OTOECAS4IGFGB5LXNYZZZCXTAQNUQU7IVQ), which is unusual for a Perl module.

## Confidence
Unclear whether the regex-based mode detection is intended to override the explicit `$mode` argument, or if it's meant only for auto-detection. The interaction between the regex branch and the explicit mode parameter is not well documented.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
## convention violations [ 1 files scanned, 1 issues ] ##

[src/base.parser.timestamp]
  L4     line_too_long     79>78  # descr = returns diffenent time-stamp strings for specified unix-\cur
```

### validate_module

```
Validation PASSED for 'base.parser.timestamp'
No issues found.
```

#,,..,.,.,.,,,.,,,,,,,,,,,,,,,,,.,,,,,,.,,,,.,..,,...,...,...,,..,,,,,,.,,...,
#GJB7OC5XFCSI2COVNIPBSFUKDJUDZVHZPQZH3VSSGGHLQKRJ3IH5BQJST4LCEHA7RFM3X7YGOBXJO
#\\\|BR6SYZQ5DT4JQZDXRC7C44RNZNXRTDBYFIT5EYKMG6XFY6PHDJR \ / AMOS7 \ YOURUM ::
#\[7]GF7CACVGLTY3CH723OBMY4374FQEBNYWJIUK2H7IYCYMVZDWDUDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
