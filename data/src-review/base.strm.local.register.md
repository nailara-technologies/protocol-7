---
module: base.strm.local.register
generated_at: 2026-09-09T10:20:06
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 20ed0d255caa7a98f1765e1c2b747677eed626b4
source_lines: 47
dep_graph_callers: 16
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 953
usage_completion_tokens: 683
---

# review: base.strm.local.register

## Purpose
This module registers a local STRM (stream) consumer for a given command ID. It tracks per-command buffers and watchers, preventing duplicate registrations on active slots.

## Interface
- **Arguments**: `$cmd_id` (numeric string), `%opts` hash with optional keys: `watcher`, `on_eof`, `max_buf`
- **Returns**: `TRUE` on successful registration, `FALSE` if the slot is already claimed

## Role & dependencies
This module is called by 16 other modules (static literal calls). It depends on:
- `base.logs` — for logging messages
- `base.strm.local` — the registry hash storing per-cmd_id state
- `base.ntime` — for recording registration timestamps

It serves as a gatekeeper for local stream consumers, enforcing a one-watcher-per-slot invariant.

## Observations
- **Duplicate guard**: The module refuses duplicate registrations with a detailed log including bytes consumed and start time. This is a defensive design choice against multi-reply fan-out collisions.
- **Validation check discrepancy**: The deterministic check reports "missing signature footer," yet the source contains a full signature footer (SJG7RNWYXV4QRD7U7ZIDHAWX5Q6GGUUFS6ZPR2SRQ6ST26WKXYBMCRXDKGPUYPC3GAIWQMZFZIL7E). This may indicate a false positive or a stricter format requirement than the check output suggests.
- **Style**: The module uses AMOS7's `<[module]>` syntax for module calls, consistent with the codebase. The `//=` idiom for hash initialization is idiomatic Perl.
- **Fragility**: The `max_buf` default of `0` may be ambiguous — unclear whether this means "unlimited" or "disabled."

## Confidence
Unclear whether the validation check's "missing signature footer" error is a false positive or indicates a stricter footer format requirement than what's present. The signature appears complete but may need a specific prefix/suffix not visible in the excerpt.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.strm.local.register':

ERRORS:
  ✗ missing signature footer
```

#,,..,,..,.,,,,,,,.,,,..,,.,.,,,,,.,,,,,.,,,,,..,,...,..,,..,,.,,,...,,,,,,.,,
#45QJTPG3CJGNJA6PFU3CZGDUIWVPLU2ZCK77YCMH6HK2JMXFE57ELOJJ52PIE4GYRQ7I7Z5LQI3VQ
#\\\|D26NRG2EBQBY6DWSGRLRQTZC6RQOKS5YQDHYF6UG4YN6M2FZ7YV \ / AMOS7 \ YOURUM ::
#\[7]OOYX6VSITD2O5QO3L3BF3QNVTVN6VV2MMNGH4GYU2R3EVQAWIECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
