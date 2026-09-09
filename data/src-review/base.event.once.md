---
module: base.event.once
generated_at: 2026-09-09T10:08:59
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 8e08854dde700d64852776c39bafbfb1c7a46b16
source_lines: 14
dep_graph_callers: 30
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 579
usage_completion_tokens: 605
---

# review: base.event.once

## Purpose
This module provides a one-shot event loop that processes events once and invokes the callback for the event with the highest priority. It wraps `Event::loop` with an optional timeout parameter.

## Interface
- **Argument**: `$timeout` (optional, defaults to `0`)
- **Return**: The return value of `Event::loop($timeout)` — unclear from this module alone what that is.

## Role & dependencies
This module sits in the `base.event` namespace and depends on `Event::loop` (from the `Event` module). It is called by 30 other modules (per the dep-graph), suggesting it's a utility for single-shot event processing. Notable callee: `Event::loop`.

## Observations
- **Fragility**: The module is extremely thin — essentially a one-liner wrapper. It delegates all logic to `Event::loop`, making it a thin facade with no internal state or error handling.
- **Coupling**: Tightly coupled to `Event::loop` — any change in that module's signature or behavior directly impacts this one.
- **Style**: The signature footer is present in the provided source, yet the deterministic check reports `✗ missing signature footer`. This is a contradiction — either the validation is stale, or the source shown is incomplete. This discrepancy needs investigation.
- **Potential issues**: No error handling around `Event::loop` — if that call fails, the failure propagates uncaught. The "once" semantics are entirely dependent on `Event::loop`'s behavior, which is opaque here.

## Confidence
Unclear why the validation reports a missing signature footer when the source clearly contains one. Unclear what `Event::loop` returns or whether it handles errors internally. The module's behavior is entirely opaque beyond its single call site.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.event.once':

ERRORS:
  ✗ missing signature footer
```

#,,,.,,..,.,,,.,.,,..,...,..,,.,.,,.,,...,,..,..,,...,...,..,,,,.,,,.,,..,...,
#CVYOO7GCVAG5VX72VNV46YRI4AQ25DK3U2DMU37VUDD6YNGEA45AE35NAIRILHKRLIZT6UMREBE66
#\\\|JZUB4FALK43JORC6YDHFF65UBXLMY3UJD552VVI7OGBCJSZZC4R \ / AMOS7 \ YOURUM ::
#\[7]PSGZBGBPXS3YPWSPFMSLN3IEKJ4WDL5D2ZTRFIXOKPCCNNLSOIBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
