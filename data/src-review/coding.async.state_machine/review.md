---
module: coding.async.state_machine
generated_at: 2026-09-09T22:43:06
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 1fd25bf887b4105b54108bb86caa7b3e4fc4e4fd
source_lines: 614
dep_graph_callers: 13
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3963
usage_completion_tokens: 922
---

# review: coding.async.state_machine

## Purpose
This module manages the lifecycle of async inference tasks through a finite state machine. It handles transitions between states like `streaming`, `tool_exec`, `user_input`, `subtask`, `paused`, and `complete` based on events triggered during task execution.

## Interface
- **`get`**: Returns the current state hash for a given `$task_id`.
- **`set`**: Merges data into the task state hash; logs state changes if a `state` key is present.
- **`init`**: Creates a new task state with default fields including `messages`, `tools`, `tool_calls`, `paged_reads`, and `history`.
- **`cleanup`**: Deletes the task state from the registry.
- **`transition`**: Validates an event against the transition table, records the transition in history, and dispatches to handlers (e.g., `tool_executor`). Returns the updated state.

## Role & dependencies
The module is a central coordinator for async task execution. It depends on:
- `<coding.async.task_state>` — the global state registry
- `<[base.logs]>` — logging interface
- `<[base.ntime]>` / `<[base.time]>` — timestamping
- `<coding.async.tool_executor>` — executes tool calls
- `<coding.buffer.model_output>` / `<coding.buffer.task_write>` — output buffering
- `<coding.task.queue>` — task metadata lookup
- `<coding.tool.detect_loop>` — loop detection for tool call recursion

## Observations
1. **Line too long (L5, 96 chars)** — violates the 78-char convention. The purpose comment is dense and could be split.
2. **Truncated source** — the file is 614 lines but only 14000 chars are visible. The `transition` handler's loop detection logic is cut off mid-string, making full analysis impossible.
3. **Fragile transition lookup** — `$TRANSITIONS{$current}->{$event}` relies on `$current` matching a constant key exactly. If a state is ever set manually via `set` with a non-constant value, transitions silently fail.
4. **Tight coupling** — the module directly calls `<coding.async.tool_executor>` and `<coding.async.complete_task>` inside `transition`, making it harder to test in isolation.
5. **Regex for JSON stripping** — the `$json_tc_re` pattern is complex and may have edge cases with nested braces or escaped characters.

## Confidence
Unclear about the full behavior of the loop detection logic (truncated), the exact semantics of `round_started` stamping, and whether `<coding.async.complete_task>` is idempotent or requires specific state preconditions.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
## convention violations [ 1 files scanned, 1 issues ] ##

[src/coding.async.state_machine]
  L5     line_too_long     96>78  # purpose = Manage: streaming → tool_exec | user_input | subtask | pau
```

### validate_module

```
Validation PASSED for 'coding.async.state_machine'
No issues found.
```

#,,,.,,,.,,..,,.,,.,,,,..,...,..,,,,.,..,,,,.,..,,...,...,.,.,,,,,...,,.,,,,,,
#AIKG2LLE6MJAKNFZS5KDI7JL2UJSUGE5SFUN5H4WAZY62VNAAH6EICC5CRDWKYERLQWKFXS3AVYSC
#\\\|QJ46OLGO275GX5JXYDRFQGFM3BACTVTXBF73XMSW642AA7PDFTU \ / AMOS7 \ YOURUM ::
#\[7]B3O5L3LVEYOGAG4LQPG6S2ANTEG43Z2NNUZCSKKJKHRBZ6XFVOAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
