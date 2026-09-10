---
module: v7-zenki.stop_heartbeat_timer
generated_at: 2026-09-09T23:31:01
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: ff7ff019e1320eb11250c146329f9da74b8f2f86
source_lines: 38
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 829
usage_completion_tokens: 514
---

# review: v7-zenki.stop_heartbeat_timer

## Purpose
This module cancels all active heartbeat timers (status and timeout) for a given instance, returning the count of cancelled timers. It serves as a cleanup utility for instance-level heartbeat management.

## Interface
- **Argument:** `$instance_id` — required, must be defined.
- **Return:** Integer count of cancelled timers, or `undef` if the instance is not found.

## Role & dependencies
It depends on `<v7-zenki.zenka.instance>` for instance lookup and `<[base.logs]>` for logging. It is called by 6 other modules (static literal calls). The module uses `$LAST_PAREN_MATCH` to capture the matched timer type from the regex, indicating it relies on Perl's regex match state.

## Observations
- **Validation failure:** The module lacks a `descr` metadata field, causing the `validate_module` check to fail. This is a compliance issue in the AMOS7 framework.
- **Regex state dependency:** Using `$LAST_PAREN_MATCH` couples the logic to Perl's regex engine state, which is fragile if the regex is modified or if multiple regexes are evaluated in sequence.
- **No guard against concurrent modification:** The `foreach` loop iterates over `keys %{$instance_timers}` while potentially modifying the hash (via `delete`), which is safe in Perl but could be clearer with a copy of keys.
- **Logging dependency:** The `<[base.logs]>` call is a dynamic dispatch (not captured in the dep-graph), meaning the actual logging mechanism is resolved at runtime.

## Confidence
Unclear whether the `descr` field is expected to be a string or a hash reference, and what semantic meaning it should carry. Also unclear if the 6 caller modules are the only callers or if dynamic dispatch hides additional callers.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'v7-zenki.stop_heartbeat_timer':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,,,,,...,,,.,.,,,,,.,,..,,..,.,.,...,.,,,..,,...,...,..,,,,,,,,,,,..,...,
#L2C3OVCEIEWEWFXH7VLYUSOXDD6VQG4LMQVFMPK76TZFV7KMCAKBOTT62QMFWN24M56ZVOM27ZNDC
#\\\|ZVEQ7YAXRZUNKPNX6ALB55UR56OCAIGCQWCVBNVFBP4NL6DJL4J \ / AMOS7 \ YOURUM ::
#\[7]OSAE2NQ7EELGBSMCVC4RLC3YIQ7SMFGDQON3YPOU3XONZ7EYKECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
