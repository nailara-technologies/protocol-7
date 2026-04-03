# Async Tool Execution Loop — Debug State

## status: CRITICAL BUG (as of 2026-04-02)

### what works
- async HTTP streaming with SSE chunk parsing (Qwen3.5 reasoning_content + content)
- state machine module with 7 states: STREAMING, TOOL_EXEC, USER_INPUT, SUBTASK, PAUSED, COMPLETE, ERROR
- chunk_handler accumulates tool_calls by index from streaming deltas
- buffer.model_output renders chat-style box drawing output

### what's broken
tasks complete after first response — tool execution loop never triggers.
expected flow: STREAMING → (finish_reason=tool_calls) → TOOL_EXEC → execute → STREAMING → ... → COMPLETE
actual flow: STREAMING → http_complete fires → task completes immediately

### suspected failure points (from HANDOVER.md)
1. **chunk_handler tool call accumulation** — partial tool_calls merging by index may have edge cases
2. **http_complete completion logic** — added finish_reason check but debug logs don't appear
3. **state machine not driving the loop** — STATE_TOOL_EXEC handler should call tool_executor, which transitions back to STREAMING via tools_done event
4. **callback registration** — coding.callback.http_* extracted from inline subs, wrappers in coding.async.request may not invoke correctly

### key files
- `modules/coding.async.state_machine` — state transitions, TOOL_EXEC handler
- `modules/coding.async.chunk_handler` — tool call accumulation from streaming chunks
- `modules/coding.callback.http_complete` — should defer completion when tool_calls pending
- `modules/coding.async.request` — callback setup, wrappers
- `modules/coding.async.tool_executor` — tool dispatch + results collection
- `modules/coding.async.send_request` — builds follow-up request with tool results

### testing procedure
```bash
p7c coding.tree-write coding.async.enabled 1   # enable async mode
p7c coding.submit 'read file README.md and summarize'  # triggers tool use
tail -f /dev/shm/.7/STDOUT/NIW7OAQ | grep -E "tool_calls|state_machine|tool_exec|finish_reason"
```

### debug steps needed
1. add verbose logging to chunk_handler — verify tool_calls accumulation
2. add logging to http_complete — see finish_reason and tool_calls count
3. verify state_machine.transition called with finish_tool_calls event
4. check tool_executor invoked and completes
5. verify send_request builds correct message history with tool results

#,,.,,,,,,..,,...,...,..,,.,.,,.,,,..,,,.,.,,,..,,...,...,,.,,,,,,,,.,,..,...,
#CHAOFFAKWTMZ4T6JJBQZ67MHX6WK3M5DJOPUJQ4VVBO3O2GHJHPJH5FZPP4DUU3DX2AEAVRE4F4VU
#\\\|QI663KV5XJ33NXEFSG7GCV6FB6FOBQZDPIKKVUGGFSRMRKCYFXE \ / AMOS7 \ YOURUM ::
#\[7]4KIEH3PSEZRXZXCMQT7YYIZCQAUGS4UN673TQOIRBKIAFY7ANWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
