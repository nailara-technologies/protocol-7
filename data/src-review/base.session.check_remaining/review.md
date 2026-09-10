---
module: base.session.check_remaining
generated_at: 2026-09-09T23:04:32
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a2799953391c057fcb920ac096195b8bee030271
source_lines: 76
dep_graph_callers: 8
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1281
usage_completion_tokens: 717
---

# review: base.session.check_remaining

## Purpose
This module monitors session counts and logs remaining sessions, triggering a "closing_last" callback when sessions reach zero. It also performs a sanity check on v7-zenki systems to verify intentional shutdowns.

## Interface
Takes two arguments: `$exit_count` (default 0) and `$silence` (default FALSE). Returns early if the v7-zenki fail count threshold is not met; otherwise executes the closing callback. No explicit return value is documented.

## Role & dependencies
Called by 8 other modules via static literal calls. Heavily relies on external modules: `base.cfg_bool`, `base.log`, `base.logs`, `base.cnt_s`, `base.code.call_expected`, `base.mod.exists`, and `v7-zenki.check_remaining.fail_count`. The `callback.session.closing_last` data structure is a key dependency.

## Observations
- **Fragility**: The v7-zenki fail_count mechanism (`<v7-zenki.check_remaining.fail_count>`) is a global state that persists across calls, making the module's behavior dependent on prior execution history.
- **Coupling**: The module tightly couples to `callback.session.closing_last` and `v7-zenki` type checks, making it difficult to reuse in contexts without these structures.
- **Style**: The `format.log_singular` warning (3 occurrences) suggests inconsistent pluralization handling in log messages.
- **Logic**: The `if ($session_count == 1)` block extracts a single session ID but only uses it to check the mode — the `$session_id` variable is assigned but never actually used downstream.
- **Readability**: The `#PCFUYHWD5LOMX333T4GR3WCYJ3U7GNK27OEOEIACN3MV7UGUTHCKRMYDGXVPIPMZS7WI2JHVMSV7O` signature comment is non-standard and may hinder maintenance.

## Confidence
Unclear whether `<callback.session.closing_last.params>` is guaranteed to be an array reference or could be a scalar, which would break `@*` unpacking. Also unclear if `v7-zenki.check_remaining.fail_count` is reset anywhere, potentially causing false negatives after long-running processes.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.session.check_remaining'

WARNINGS:
  ⚠ format.log_singular : 3 occurrences [ first at line 23 ]
```

#,,..,..,,,,,,,..,,.,,.,,,,,,,...,.,.,,,,,,.,,..,,...,..,,,..,.,.,..,,..,,,.,,
#NZ6ANHDJ6MZ5ZH5MQ6KKMPT3X5MQYJ5O6I2N4AJWPIACNHMSF4SDSQSXT55WHMBQL7WHNUTHYL7Y2
#\\\|ZNG6JCJWQDPAOZWAGQVYOIVFM3MAWXT34EQF35DCXP22KU2JUY6 \ / AMOS7 \ YOURUM ::
#\[7]EP675YV5E5J2XJWMII3K6S64LRHRTIA4H43E2KJF5QUPWMWTGQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
