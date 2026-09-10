---
module: coding.async.send_request
generated_at: 2026-09-09T23:43:08
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 863dd24e6e59d933961bc17069bd2d921df20468
source_lines: 355
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 4326
usage_completion_tokens: 885
---

# review: coding.async.send_request

## Purpose
This module sends the next inference request after tool execution completes. It orchestrates state transitions, manages context windows, handles tool use, and manages edge cases like queue pauses, compaction, and context overflow.

## Interface
**Argument:** `$task_id` (string, required). Returns `{ success => FALSE, error => '...' }` on failure, or `{ success => TRUE, ... }` with optional fields like `task_id`, `compacting`, `stopped`, `paused`.

## Role & Dependencies
Fits into the async inference pipeline as the bridge between tool execution and model invocation. Notable callees: `coding.async.state_machine`, `coding.async.request`, `coding.async.fail_task`, `coding.async.complete_task`, `coding.async.compact_context`, `coding.parser.model_selection`, `coding.sanitize.jinja_messages`, `coding.inference_servers`, `event.add_timer`.

## Observations
- **Context overflow handling** is proactive: it estimates token usage before sending and fails cleanly rather than allowing silent truncation.
- **Model selection blocks** are stripped from messages after routing, preventing double-processing.
- **Tool use** is dynamically detected via `:no_tools:` prefix in the description.
- **Streaming** is enabled by default for resilience against connection drops.
- **Retry logic** consumes flags to prevent infinite loops.
- **Context pressure warnings** are injected when `max_tokens` is severely capped (< 3000), prompting the model to adapt.
- The `no_tools` flag is set via description prefix matching, which is a fragile pattern (regex on description).
- The `model_selection` block parsing relies on a regex that may be brittle against malformed input.
- The `chars_per_token_pre = 3.2` constant is a heuristic that may drift across locales or encoding.

## Confidence
Unclear on the exact semantics of `coding.async.state_machine` transitions (e.g., what states exist beyond `get`, `pause`). The `coding.async.state_manager` call for retry_pending appears to be a separate module from `state_machine` — potential naming inconsistency. The `coding.task.enqueue_round_timer` adapter comment suggests a prior bug where `params` keys were silently dropped; this is now mitigated by routing through the thin adapter.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'coding.async.send_request'
No issues found.
```

#,,..,.,,,.,,,..,,,.,,,,,,...,,.,,,.,,,,.,,,,,..,,...,...,,,.,.,.,,,,,...,.,.,
#2UBJJOM3K7BT2533XX7L4AMZ432J4B2PSG2N7SBS2TB4VXOGBTP6JSFJF6XKOU3ZDC5HQING3X6BO
#\\\|EG4DRITANKVG3CV2B4TG5YMV3CYFN3JJWSCHQM4QEHUVGSDI5EC \ / AMOS7 \ YOURUM ::
#\[7]OLGKF3IIFE6RO4BPDWF3PRGPIV5UMF3NACX6U65K4ICBC75OJABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
