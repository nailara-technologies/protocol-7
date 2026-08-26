# Round-Based Scheduling & Subtask Spawn

## Date
April 2026

## Status
COMPLETE — full round-trip verified 2026-04-30

## Architecture

Round-based scheduling breaks the async inference callback chain into discrete jobqueue jobs.
Each inference round becomes a separate jobqueue job (`task_id.round_N`).

Key difference from old behavior:
- **Before**: `tools_done` → directly calls `send_request` (callback chain)
- **After**: `tools_done` → enqueues next round via `coding.task.enqueue_round` (jobqueue driven)

This makes the jobqueue the sole scheduler, avoiding concurrent execution issues.

## Subtask Spawn Flow

```
Parent task (streaming)
  └─→ model calls subtask_spawn tool
  └─→ Parent transitions: streaming --spawn_subtask→ subtask
  └─→ Child task created, enqueued, runs independently
  └─→ Child completes
  └─→ coding.async.complete injects result into Parent messages
  └─→ Parent transitions: subtask → streaming (via state_machine)
  └─→ Parent next round enqueued via enqueue_round
  └─→ Parent resumes inference with child result in context
```

## Files Added/Modified

| file | change |
|------|--------|
| `src/coding.task.enqueue_round` | NEW - enqueue inference round as jobqueue job |
| `src/coding.task.execute_round` | NEW - job callback: execute one round |
| `src/coding.tools.handler.subtask_spawn` | NEW - spawn child task with parent tracking |
| `src/coding.async.state_machine` | MODIFIED - `tools_done` → enqueue round |
| `src/coding.async.send_request` | MODIFIED - injected message + pause support |
| `src/coding.async.complete` | MODIFIED - resume parent on child completion |
| `src/coding.callback.http_complete` | MODIFIED - partial content recovery |
| `src/coding.callback.http_error` | MODIFIED - duplicate retry prevention |
| `src/coding.callback.retry_request` | MODIFIED - clear retry_pending flag |
| `src/coding.async.request` | MODIFIED - stale connection cleanup |
| `cfg/zenki/coding/zenka.v7` | MODIFIED - `round_scheduling.enabled = yes` |

## Bugs Fixed

### 1. Duplicate Requests
**Symptom**: After HTTP error, two `send_request` calls appeared in logs, creating duplicate connections.

**Root causes**:
- `http_error` scheduled retry timer without checking if one was already pending
- `execute_round` jobqueue callback could re-execute while retry timer was pending

**Fix**:
- `http_error`: check `$state->{'retry_pending'}`, return early if set
- `retry_request`: clear `retry_pending` before calling `send_request`
- `execute_round`: skip execution if `retry_pending` is true
- `async.request`: check for existing `http_state->{'sock'}`, cancel stale connection

### 2. Lost Partial Content on Connection Close
**Symptom**: "connection closed with no data" even when bytes were received.

**Root cause**: `http_complete` only checked `$state->{'response_text'}` and `$state->{'content'}`, but `chunk_handler` stores accumulated content in `$state->{'chunk_context'}->{'content'}`. Also checked `$http_state->{'body'}` which never existed (only `buffer` exists).

**Fix**:
- Check `$state->{'chunk_context'}->{'content'}` as fallback
- Check `$http_state->{'buffer'}` instead of non-existent `body`
- If partial content exists, transition to `finish_stop` with what we have

### 3. Parent Not Resuming from Subtask
**Symptom**: Child completed but parent stayed in `subtask` state forever.

**Root cause**: `coding.async.complete` injected child result and enqueued parent's next round, but did NOT transition parent state from `subtask` to `streaming`. The follow-up `send_request` preserved the `subtask` state, and when response arrived, `finish_stop` was an invalid transition from `subtask`.

**Fix**: Set `$parent_state->{'state'} = 'streaming'` before calling `enqueue_round`.

### 4. Orphaned Child Tasks
**Symptom**: Multiple child tasks spawned, only one tracked by parent.

**Root cause**: Model can send multiple `subtask_spawn` tool calls in one response. The first created a child and set `pending_subtask`. The second also created a child (before rejection check), overwrote `pending_subtask`, and returned error. The first child became orphaned.

**Fix**: Move rejection check **before** `coding.task.enqueue`. If parent already has `pending_subtask`, reject before creating any child task.

### 5. Wrong Child Resuming Parent
**Symptom**: First child completed and resumed parent, even though parent was waiting for second child.

**Root cause**: `coding.async.complete` only checked if parent was in `subtask` state, not whether the completing child was the one the parent was actually waiting for.

**Fix**: Verify `( $parent_state->{'pending_subtask'} // '' ) eq $task_id` before resuming parent.

### 6. String Priority Warning
**Symptom**: `argument 'normal' isn't numeric in sort` in `jobqueue.get_next_job`.

**Root cause**: `coding.intake.normalize_task` sets priority to strings (`critical`, `high`, `normal`, `low`), but `jobqueue.get_next_job` uses numeric `<=>` sort.

**Fix**: `coding.task.enqueue_round` maps string priorities to numbers before creating jobqueue job.

## Configuration

```
coding.async.round_scheduling.enabled = yes
```

## Testing Results

- Simple task (no tools): ✅ completed
- Tool-using task: ✅ completed after retry
- Subtask spawn → child completes → parent resumes: ✅ completed end-to-end
- Duplicate subtask rejection: ✅ working
- Partial content recovery: ✅ working (538 bytes recovered)

## Post-Handover Fixes (Claude sessions, Apr 29-30 2026)

These bugs were resolved after kimi's handover:

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| Silent timeout (most cases) | Two llama-server processes spawned simultaneously, 2nd stole VRAM | `<coding.spawning_in_progress>` guard in `async_spawn_inference_servers` |
| Stale PID kill race | `waitpid` no-op on non-child, `pgrep` saw just-killed pid as foreign | `@killed_stale_pids` tracked in port scan, skipped in foreign check |
| Subtask "backend not available" | Parent held lock in `subtask` state; child's LWP health check raced with active stream | `subtask_spawn` releases parent lock; `select_backend` uses cached `'ready'` status |
| `http_complete` fallthrough on subtask | No `subtask` case — fell through to lock-release code unnecessarily | Explicit `subtask` case added, returns cleanly |
| Timeout with no recovery | Server in silent-hang state, next task also hangs | `http_error` schedules deferred respawn on timeout after all retries |

## Known Limitations

- Full parallel task execution would require per-task isolation of globals. The round-based approach avoids this by never running tasks concurrently.
- Server-side incomplete responses (no `finish_reason`) still occur occasionally; client-side retry handles them.

#,,,.,..,,..,,..,,,..,,.,,.,.,,.,,..,,,,,,.,.,..,,...,...,..,,.,.,..,,,.,,.,,,
#NVDHBOTBKR5WYYTKVW7L7T7GPXONB4LCWY3BVGKVUCVNHJGRQO7TPK347SYVIKCQ7OUSOPS3HKNZU
#\\\|LDOQKQ3KLE5RP57UR45ULHS4ESVJI6ZMXZFIHELKPFIP7KKXJBT \ / AMOS7 \ YOURUM ::
#\[7]KTK7AZ6IQO4YRMPMHMFV7LMARTCUIPQXX52B6OJICZRKJY5OIMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
