---
module: base.parser.duration
generated_at: 2026-09-09T10:21:54
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: c05fb8e95d4c44bea1d06d38d87b969193a2c153
source_lines: 93
dep_graph_callers: 15
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1455
usage_completion_tokens: 697
---

# review: base.parser.duration

## Purpose
This module converts a Unix timestamp into a human-readable duration string (e.g., "3d 4h 12m 30s"), ignoring leap years entirely. It formats the result with optional precision control.

## Interface
**Arguments:** `$start_time` (Unix timestamp, required), `$precision` (optional float, defaults to 2 decimal places).
**Returns:** A formatted string like `"3d 4h 12m 30s"` or `"n/a"` on invalid input.

## Role & dependencies
Fits into the `base.parser` family as a duration formatter. Notable callees: `Time::Seconds` (from `base.time`), `ONE_YEAR()`, `ONE_DAY()`, `ONE_HOUR()`, `ONE_MINUTE()`, and `base.cnt_s` for pluralization. Called by 15 other modules (static literal calls).

## Observations
- **Validation failure:** The module lacks a signature footer, causing `validate_module` to fail.
- **Unclear logic:** `$result{'yday'}` is referenced in a conditional but never assigned anywhere in the code.
- **Formatting quirks:** The regex substitutions at the end (`s| days? (\d+)h |d $1 |`) appear to be post-processing cleanup that may not always apply correctly.
- **Edge case:** The condition `if ( $result{'years'} and not $result{'days'} )` produces `"X year(s)"` without a day component, but the `elsif` branch produces `"%dy"` — inconsistent output format.
- **Precision handling:** The `sprintf` format string `"%.*f"` is used correctly for decimal seconds, but the final `push` for seconds lacks the precision argument.

## Confidence
Unclear whether `Time::Seconds` is a custom AMOS7 class or an external module. The `ONE_YEAR()` function's implementation is not visible here, so the accuracy of year calculations cannot be verified.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.parser.duration':

ERRORS:
  ✗ missing signature footer
```

#,,.,,.,,,..,,.,,,,,,,..,,,.,,.,.,,.,,,.,,,..,..,,...,..,,,,.,..,,,,,,.,.,..,,
#5SG2LMFFNCS6ZRFER2ULRV6OXMMRL43TMNZOMHK4HZZMIWSQQBUJDHWC332JH33S2BUMG5KAICLTM
#\\\|GQMRHHE424DUDI3ZNNGQ76LNK5YT2XUVEJOEOPH5R56JBFUKRVY \ / AMOS7 \ YOURUM ::
#\[7]MR6I5OYCMLGVXX547UL6FFHV5RVANZXUFWB67JO72BHEJ2NA44BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
