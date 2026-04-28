# Round-Based Scheduling & Subtask Spawn

## Date
April 2026

## Status
IMPLEMENTED & TESTED

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
| `modules/coding.task.enqueue_round` | NEW - enqueue inference round as jobqueue job |
| `modules/coding.task.execute_round` | NEW - job callback: execute one round |
| `modules/coding.tools.handler.subtask_spawn` | NEW - spawn child task with parent tracking |
| `modules/coding.async.state_machine` | MODIFIED - `tools_done` → enqueue round |
| `modules/coding.async.send_request` | MODIFIED - injected message + pause support |
| `modules/coding.async.complete` | MODIFIED - resume parent on child completion |
| `modules/coding.callback.http_complete` | MODIFIED - partial content recovery |
| `modules/coding.callback.http_error` | MODIFIED - duplicate retry prevention |
| `modules/coding.callback.retry_request` | MODIFIED - clear retry_pending flag |
| `modules/coding.async.request` | MODIFIED - stale connection cleanup |
| `configuration/zenki/coding/start` | MODIFIED - `round_scheduling.enabled = yes` |

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

## Known Limitations

- The llama-server occasionally returns incomplete responses (no `finish_reason`). This is a server-side issue, not related to scheduling. Client-side retry handles it.
- Full parallel task execution would require per-task isolation of globals (`coding.tool_loop.stop`, `coding.loop_detect_count`, etc.). The round-based approach avoids this by never running tasks concurrently.

#,,.,,,..,,,.,,,,,.,,,,..,,.,,..,,,..,,,.,,..,..,,...,...,...,..,,,..,.,,,,..,
#VK3LUDEB5EOU6E6FK3XVWJUV2RBKCIHMWAC7VY2XCYTXNIPT37IUAJVD3NEWZ4MS4ZYZO75F2M3PI
#\\\|5W7DS4WUQUVQBVTPXI7FM7CLPPM4CEKILLUORXAVBI63PSUVRY5 \ / AMOS7 \ YOURUM ::
#\[7]TNHXC6O5EDGLCFVUXSNGMRS43L4UWDAPXVNBQ5PWM7XECU4J4EBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
