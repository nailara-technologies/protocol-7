# Coding Zenka Subtask Queue & Tool Fixes (May 5 2026)

> Extracted from MEMORY.md. See main memory for cross-references.

## Testing Context
- Model: Qwen3-4B-Qwen3.6-plus-Reasoning-Slerp (FPI66SQ:CRID5OA)
- Inference: llama-server-cuda-fa, n_ctx=90077, reasoning_effort=low
- Built-in jinja template + XML tool instructions in system prompt

## Fixes Applied

**1. Subtask Queue Drain — Duplicate Enqueue Prevention**
- `coding.async.complete` deletes next task from `<coding.task.queue>` BEFORE calling `coding.task.enqueue`
- On enqueue failure, restores task back to queue so retry can succeed
- Parent stays in `subtask` state while queue has items; transitions to `streaming` when empty
- File: `modules/coding.async.complete`

**2. SIGCHLD Zombie / Server Crash Handler**
- Rewritten to loop `waitpid(-1, WNOHANG)` matching `base.sig_chld` pattern
- Matches reaped PIDs against `<coding.inference_servers>` (gpu/cpu backends)
- Exponential backoff restart: 5s, 10s, 20s, 30s, 60s (max 5 attempts)
- Silently ignores spurious signals (no "no zombies to reap" noise)
- File: `modules/coding.handler.inference_server_sigchld`

**3. Stop-Task Cascade**
- `coding.cmd.stop-task` sets `stop_requested` on target task
- Walks `<coding.task.subtask_queue>` to flag all queued children
- Walks `<coding.task.parent>` to flag active children not in queue
- Clears queue so `async.complete` won't advance to next subtask
- File: `modules/coding.cmd.stop-task`

**4. Stop-Task Queue Guard**
- `coding.async.complete` checks `parent_state->{'stop_requested'}` before advancing queue
- If stopped: cancels all remaining orphans, clears queue, transitions parent to `streaming`
- File: `modules/coding.async.complete`

**5. Retry Counter Logic**
- `coding.async.send_request` consumes `retry_pending` flag to distinguish retries from fresh requests
- Preserves `retry_count` across retries; only resets to 0 on genuine fresh starts
- Prevents `retry_request` from clearing flag prematurely
- File: `modules/coding.async.send_request`

**6. Think-Block Extraction**
- `coding.async.chunk_handler` extracts inline `<think>...</think>` blocks from `content` into `reasoning` buffer
- Strips stray leading `</think>` tags
- Prevents reasoning from leaking into visible tool output
- File: `modules/coding.async.chunk_handler`

**7. Tool Format in System Prompt**
- Added explicit XML `<tool_call>` instructions to system prompt (template-agnostic)
- Works with both replacement jinja template and built-in template
- File: `modules/coding.system_prompt`

**8. list_files Enhancements**
- Shows pattern in header: `[ pattern: 'X' ]`
- Added `sort=name|size|mtime` and `order=asc|desc` parameters
- File: `modules/coding.tools.handler.list_files`

**9. tree_list Fallback Resolution**
- Fallback 1: exact flat-key match in `%data`
- Fallback 2: prefix search (`$path.*`) over `%data` keys when `base.resolve_key` returns empty
- File: `modules/coding.tools.handler.tree_list`

**10. init_code Re-init Safety**
- Dependency object creation wrapped in `if (not $already_initialized)` guard
- Prevents `<dependency.object>` leaks on coding zenka reload
- File: `modules/coding.init_code`

**11. task_file_search Tool (NEW)**
- Unified search across active and archived task locations
- Phase 1: filename regex match across 4 known directories
- Phase 2 (depth=2): `grep -ril` content fallback if no filename matches
- File: `modules/coding.tools.handler.task_file_search`

## Model Behavior Observations

**Qwen3 jinja template compatibility:**
- Replacement template (`qwen3.5-fixed.jinja`) works for 9B models
- Same template causes hangs with some modified 4B variants
- Current approach: built-in template + XML tool instructions in system prompt

**Context size tuning:**
- n_ctx=100777+ causes 777s timeouts with this model
- n_ctx=90077 with `reasoning_effort=low` is current sweet spot

**finish=undef vs finish=stop:**
- `finish=undef` (connection closed without finish_reason) → enqueues another round
- `finish=stop` with no tool calls → completes normally (model chose not to use tools)

#,,,.,,.,,,,.,,,.,...,,,.,,,,,..,,,.,,.,,,,,.,..,,...,...,,,,,.,.,.,.,..,,.,.,
#SG25LZEXZWVEPHHN6PJLZ7FHJDL4HOJUDNYUYQIPO4HX4IIS6PUEMZXWWRPDHSQLJ7UMQSUO5F7W6
#\\\|JW42LFBT3KVI3H5PDRC5CNOEOAPID3IZ2YAF2RGWRFYFUZLJE2Q \ / AMOS7 \ YOURUM ::
#\[7]CNB65YF465HNXVI5VW2C5FGFUQKHXEDUFVRCRWLRJ27ZD6A3P4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
