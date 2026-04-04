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

## CRITICAL BUGS — Async Tool Loop (Active Debugging)

**Status**: Infrastructure committed, basic streaming works, tool loop cycles but model repeats same response
**Root Cause**: Assistant message with `tool_calls` not being added to conversation history
**Impact**: Model doesn't "see" that it made tool calls → infinite repetition → max rounds exceeded

### Data Flow Issue
```
Expected: Model → chunks → tool_calls[] → assistant_msg → tool_results[] → next_request
Actual:   Model → chunks → tool_calls[] → (lost) → tool_results[] → next_request

Result: roles=[system,user,tool,tool,tool] — missing "assistant" with tool_calls!
```

### Bug #1: Duplicate Round Increment (FIXED)
**Location**: `modules/coding.async.state_machine` line 162 AND `modules/coding.async.send_request` lines 25,35
**Issue**: Round incremented twice per cycle (+2 instead of +1) → hits limit of 10 quickly
**Fix**: Removed increment from `send_request`, only `state_machine` increments

### Bug #2: Missing Assistant Message with tool_calls (IN PROGRESS)
**Location**: `modules/coding.async.state_machine` TOOL_EXEC handler vs `tools_done` handler
**Issue**:
- `tool_executor` clears `pending_tools` from state before `state_machine` can read it
- `tools_done` handler reads `tool_calls` from `$data` but it may be empty
- Assistant message with `tool_calls` array never added to conversation history

**Data flow analysis**:
```perl
# In state_machine transition to TOOL_EXEC:
$state->{'pending_tools'} = $data->{'tool_calls'};  # stores here

# In tool_executor:
$state = <[coding.async.state_manager]>->('get', $task_id);
my $tool_calls = delete $state->{'pending_tools'};  # CLEARED here!

# Back in state_machine 'tools_done' handler:
my $tool_calls = $data->{'tool_calls'} // [];  # expects from data, may be empty
```

**Fix in progress**: Pass `tool_calls` explicitly in transition data

### Bug #3: tool_calls Array Not Passed in Transition Data (IN PROGRESS)
**Location**: `modules/coding.async.tool_executor` line ~95
**Issue**: `tool_calls` must be passed back to state_machine in transition data
**Code**:
```perl
<[coding.async.state_machine]>->('transition', $task_id, {
    'event'        => 'tools_done',
    'tool_results' => \@tool_results,
    'tool_calls'   => $tool_calls,  # ADD THIS
});
```

### Bug #4: HARDCODED Round Limit of 10 (FIXED)
**Location**: `modules/coding.async.send_request` line 26
**Issue**: Round limit was hardcoded to 10
**Fix**: Added `<coding.async.max_rounds>` config with default of 50
- Set in `modules/coding.init_code`: `<coding.async.max_rounds> //= 50`
- Used in `send_request`: `my $max_rounds = <coding.async.max_rounds> // 50`

### Bug #5: Task Result Empty Despite Correct Buffer (FIXED)
**Location**: `modules/coding.async.complete_task` line 19  
**Issue**: Result retrieval used `//` (defined-or) which doesn't fall through on empty strings
```perl
# BUG: response_text = '' (defined but empty), so returns '' not final_content
result => $state->{'response_text'} // $state->{'final_content'} // ...
```
**Fix**: Use `||` (logical or) which treats empty string as falsy:
```perl
# FIXED: prioritizes final_content, falls through properly
my $result_text = $state->{'final_content'}
    || $state->{'content'}
    || $state->{'response_text'}
    || '';
```
**Result**: `coding.get-result` now returns actual task output instead of empty string

### Debug Log Pattern to Watch For
```
# BAD — missing assistant:
send_request: task=<id> round=3 messages=4 roles=[system,user,tool,tool]

# GOOD — has assistant with tool_calls:
send_request: task=<id> round=3 messages=5 roles=[system,user,assistant,tool,tool]
```

### Files Modified (need testing)
- `modules/coding.async.state_machine` — transition handling, round increment
- `modules/coding.async.send_request` — removed duplicate round increment
- `modules/coding.async.tool_executor` — pass tool_calls in transition data
- `modules/coding.callback.http_complete` — debug logging

### Testing

**Enable async mode:**
```bash
p7c coding.tree-write coding.async.enabled 1
p7c 'coding.tree-read coding.async.enabled'
```

**Submit test task:**
```bash
p7c coding.submit 'read file README.md and summarize'
```

**Monitor:**
```bash
tail -f /dev/shm/.7/STDOUT/NIW7OAQ | grep -E "tool_calls|state_machine|send_request|roles="
```

## What Needs Doing

### 1. Async HTTP Integration → STABILIZATION
**Priority: CRITICAL** | **Where**: coding zenka

**All Critical Bugs Fixed:**
- ✅ **Bug #1**: Duplicate round increment (removed from send_request)
- ✅ **Bug #2/#3**: Assistant message with `tool_calls` now correctly added to conversation history (Claude Opus fixed data flow)
- ✅ **Bug #4**: Hardcoded round limit → now configurable (`coding.async.max_rounds`, default 50)
- ✅ **Bug #5**: Task result empty despite correct buffer → fixed `//` vs `||` operator bug in complete_task

**Status**: Tool execution loop working end-to-end:
- Tasks complete with correct results (verified: `coding.get-result` returns actual output)
- Message history properly includes assistant with tool_calls
- Round counter increments correctly (+1 per cycle)
- Buffer shows correct model output

**Remaining work**:
- Test edge cases (multi-tool calls, errors, rate limiting)
- Monitor for any remaining state management issues
- Consider removing blocking mode fallback once stable

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
- `modules/coding.async.state_machine` — BUG #2, #4: transition handling, hardcoded limit
- `modules/coding.async.send_request` — BUG #4: hardcoded limit, check round logic
- `modules/coding.async.tool_executor` — BUG #3: pass tool_calls in transition data
- `modules/coding.async.chunk_handler` — tool call accumulation from streaming chunks
- `modules/coding.callback.http_complete` — finish_reason detection
- `modules/coding.async.request` — callback setup

### Documentation
- `CLAUDE.md` — full system reference
- `ai-mem/kimi/MEMORY.md` — persistent context index
- `memory/topic-namespace-tree-intelligence.md` — tree architecture
- `memory/topic-task-coordination.md` — task dispatch roadmap
- `data/yaml/context-templates/` — all coding zenka templates

### Notes for Claude
The async infrastructure streams correctly but the tool execution loop has data flow issues. The critical missing piece is the assistant message with `tool_calls` not being added to conversation history. Fix this and the hardcoded round limit (10 → configurable).
