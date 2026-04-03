# Session Handover — 2026-04-02

## What Just Happened

### Async HTTP Streaming Infrastructure (Major)
Completed full async inference pipeline for coding zenka:
- `coding.async.http_client` — non-blocking HTTP with event-based I/O
- `coding.handler.http_io` — SSE chunk parsing, chunked encoding support
- `coding.async.chunk_handler` — extract content/reasoning_content from deltas
- `coding.async.state_machine` — manage streaming → tool_exec → streaming loop
  - States: STREAMING, TOOL_EXEC, USER_INPUT, SUBTASK, PAUSED, COMPLETE, ERROR
  - Validated transitions with history tracking
  - Pause/resume support for rate limiting, user confirmation, subtask spawning
- `coding.async.tool_executor` — dispatch tool calls, collect results, resume streaming
- `coding.buffer.model_output` — chat-like formatting with box drawing

Enables true async task multiplexing: multiple concurrent inference streams
without blocking the event loop.

### Tree Tools Layer 1 (Complete)
Exposed %data namespace to coding zenka:
- `coding.tools.handler.tree_read` / `coding.cmd.tree-read`
- `coding.tools.handler.tree_write` / `coding.cmd.tree-write`
- `coding.tools.handler.tree_list` / `coding.cmd.tree-list`

Wraps existing `base.resolve_key` / `base.set_key` infrastructure.

### Context Template System (Complete)
63 templates in `data/yaml/context-templates/`:
- Template resolution with budget allocation
- Context providers: git.recent_changes, task.active, modules.list
- Dynamic system messages for kimi_web and coding zenka

### Vision System Overhaul
- Shared HTTP backend for all vision operations
- OOM protection and adaptive polling
- mmproj detection fixes for vision models

### Infrastructure Hardening
- Inference server crash detection and auto-restart
- Retry on timeout/5xx errors in inference loop
- Intelligent loop detection with model assertion
- Task stop signals: `task_complete` (clean exit), `escalate` (human handover)

### kimi-web Zenka (Complete)
Child-bearing zenka for spawning kimi-cli web sub-agents:
- Agent registry with health tracking
- Parallel inference dispatch
- Graceful shutdown with context preservation

### Templates Added
Autonomous task templates for self-directed work:
- `extract-inline-subs` — return sub unwrap, one-call-per-round
- `namespace-audit`, `sub-task-decompose`, `tree-explore`
- `review-and-improve`, `autonomous-direction`, `integrate-recent`
- `p7-style-enforce`, `header-tags-fix`, `fix-format-issues`
- `git-diff-review`, `regex-style-fix`, `param-validation-fix`
- `error-resilience`, `cross-namespace-wiring`
- `observations-triage`, `post-task-verify`
- `zenki-create`, `zenki-feature-port`, `footer-cleanup`

### Bug Fixes
- NShell history navigation off-by-one (Ctrl+O cycle)
- Plugin initialization order (load_plugins before init_modules)
- pager.source.file-list regex crash
- B32: prefix handling in single-line mode
- Jinja template sanitization (namespace() outputs)

## CRITICAL: Async Tool Execution Loop Broken

**Status**: Infrastructure committed, basic streaming works, tool loop fails  
**Issue**: Tasks complete after first response instead of executing tools and continuing  
**Files**: `modules/coding.async.*`, `modules/coding.callback.http_*`, `modules/coding.handler.http_io`

### Current Behavior
- Async mode streams response correctly (chunks received, parsed)
- Model responds with text OR generates tool_calls in delta chunks
- `http_complete` callback fires, task completes immediately
- Tool execution loop never triggered

### Expected Flow
```
STREAMING → (finish_reason=tool_calls) → TOOL_EXEC → execute tools → 
STREAMING (new request with tool results) → (finish_reason=stop) → COMPLETE
```

### Suspected Issues

1. **chunk_handler tool call accumulation**: 
   - Streaming tool_calls come in partial chunks by index
   - Current code merges by index but may have edge cases
   - Need to verify accumulated tool_calls are valid and complete

2. **http_complete completion logic**:
   - Added check for `finish_reason eq 'tool_calls'` to defer completion
   - May not be working - debug logs don't appear
   - State machine transition may not be triggered

3. **State machine not driving the loop**:
   - `STATE_TOOL_EXEC` handler should call `coding.async.tool_executor`
   - Tool executor dispatches tools, then transitions back to `STREAMING`
   - `tools_done` event should trigger `send_request` for next round
   - Something in this chain is broken

4. **Callback registration**:
   - `coding.callback.http_*` modules extracted from inline subs
   - Wrappers in `coding.async.request` may not be calling correctly
   - Verify callbacks are actually invoked (add debug logging)

### Debug Steps Needed

1. Add verbose logging to `chunk_handler` to verify tool_calls accumulation
2. Add logging to `http_complete` to see finish_reason and tool_calls count
3. Verify `state_machine.transition` is called with `finish_tool_calls` event
4. Check if `tool_executor` is invoked and completes successfully
5. Verify `send_request` builds correct message history with tool results

### Files Modified (need signing to test)
- `modules/coding.callback.http_complete` — debug logging added
- `modules/coding.async.chunk_handler` — tool call merging
- `modules/coding.async.request` — uses extracted callbacks

### Testing

**Enable async mode (required before each test):**
```bash
# Enable async mode - REQUIRED or it falls back to blocking mode
p7c coding.tree-write coding.async.enabled 1

# Verify it's enabled
p7c 'coding.tree-read coding.async.enabled'
```

**Submit test task:**
```bash
# Task that should trigger tool use
p7c coding.submit 'read file README.md and summarize'

# Or with template
p7c coding.submit ':template: code-review' ':context: modules/coding.async.request'
```

**Monitor execution:**
```bash
# Watch for tool execution in logs (in another terminal)
tail -f /dev/shm/.7/STDOUT/NIW7OAQ | grep -E "tool_calls|state_machine|tool_exec|finish_reason"

# Check task status
p7c coding.status
p7c 'coding.tree-read coding.task.queue.<task-id>.execution'

# Get result when done
p7c coding.get-result <task-id>
```

**Expected behavior when working:**
- Task shows `status: in_progress` while tools execute
- Log shows `state_machine` transition events
- Multiple inference rounds (streaming → tool_exec → streaming)
- Final result appears after all tools complete

## What Needs Doing

### 1. Async HTTP Integration Testing → DEBUG AND FIX TOOL LOOP
**Priority: CRITICAL** | **Where**: coding zenka

New async infrastructure is committed but **tool execution loop is broken**:
- ✅ Streaming with Qwen3.5 works (reasoning_content + content)
- ❌ Tool execution loop: streaming → tool_exec → streaming (BROKEN)
- Test STATE_PAUSED for rate limiting scenarios
- Validate concurrent task multiplexing

### 2. Namespace Tree Intelligence — Layer 2
**Priority: high** | **Where**: context-tree modules

Layer 1 (tree_read/write/list) is complete. Layer 2 = search and intelligence:
- `tree_search` — find nodes matching pattern
- `tree_diff` — compare branches across time
- `tree_prune` — archive old branches
- Persistent storage: Tie::Dir or similar for %data persistence

See: `memory/topic-namespace-tree-intelligence.md`

### 3. Task Zenka State Machine Expansion
**Priority: high** | **Where**: task zenka modules

Current: pending -> claimed -> done/failed
Target: open -> assigned -> in_progress -> blocked -> review -> completed -> archived

Missing:
- `task.next` — autonomous work routing
- `task.handover` — session context packaging
- File watcher for external yaml changes

### 4. Multi-Model Consensus Testing
**Priority: medium** | **Where**: llm.service.consensus_vote.*

Modules extracted but untested. Needs:
- Real model provider wiring
- 5-of-7 algorithm group testing
- Integration with task dispatch

### 5. Self-Improving Loop Closure
**Priority: vision** | **Where**: llm coordination zenka

Current: coding zenka can extract, review, observe, self-fix, stop cleanly
Next steps:
- Token budget awareness
- Session-limit tracking
- Affinity-based routing (kimi=sustained impl, claude=design/review)
- task.next picking work autonomously

## Coding Zenka Task Submission

```bash
## submit a task with template
p7c coding.submit ':template: <name>' ':context: modules/<file>' ':description: <text>' ':priority: 5'

## available templates
ls data/yaml/context-templates/   # 63+ templates

## check task status
p7c coding.queue
p7c coding.show <task-id>
```

## Key Files for Next Session

### Async Debugging (PRIORITY)
- `modules/coding.async.state_machine` — state transitions, verify TOOL_EXEC handler
- `modules/coding.async.chunk_handler` — tool call accumulation from streaming chunks
- `modules/coding.callback.http_complete` — should defer completion when tool_calls pending
- `modules/coding.async.request` — callback setup, verify wrappers call extracted modules
- `modules/coding.async.tool_executor` — tool dispatch, results collection
- `modules/coding.async.send_request` — builds follow-up request with tool results

### Documentation
- `CLAUDE.md` — full system reference
- `ai-mem/kimi/MEMORY.md` — persistent context index
- `memory/topic-namespace-tree-intelligence.md` — tree architecture
- `memory/topic-task-coordination.md` — task dispatch roadmap
- `data/yaml/context-templates/` — all coding zenka templates

### Notes for Claude
The async infrastructure is 90% complete. The issue is likely in the handoff between:
1. HTTP completion detecting tool_calls
2. State machine transitioning to TOOL_EXEC
3. Tool executor running and transitioning back
4. New inference request being sent

Look for: missing state machine calls, incorrect finish_reason checks, callback wrappers not working.
