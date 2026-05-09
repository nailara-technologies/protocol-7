# remove blocking inference path — coding.handler.process-queued-task

**Priority:** High
**Type:** Cleanup — Dead Code Removal
**Component:** coding.task.execute, coding.cmd.complete-analysis, coding.handler.process-queued-task

## Context

Investigation confirmed (task V7CUGSQ, 2026-05-09):
- `coding.async.enabled = 1` is set in production — async path always active
- Blocking path only reached when `coding.async.request` fails to start
- Blocking path is dead code in normal operation
- Async path is strictly better: 13 min timeout vs 5 min, streaming, retry
  timers, subtask spawning, user input, better error handling — zero gaps

## What to Remove

### 1. coding.task.execute — remove blocking fallback

**File:** `modules/coding.task.execute`

The blocking fallback is at the end of the function after the async path:
```perl
my $async_mode = <coding.async.enabled> // FALSE;
if ($async_mode) {
    my $async_result = <[coding.async.request]>->(...);
    if (!$async_result->{'success'}) {
        ## Async start failed, fall back to blocking ##  ← remove this branch
    } else {
        return { success => TRUE, mode => 'deferred', task_id => $task_id };
    }
}
## BLOCKING MODE:                                        ← remove all of this
my $result = <[coding.handler.process-queued-task]>->(...)
```

Replace with: if async fails to start, fail the task with a clear error.
Do not fall back to blocking. The async path failure reason is already logged.

### 2. coding.cmd.complete-analysis — redirect to async

**File:** `modules/coding.cmd.complete-analysis`

Currently calls `coding.handler.process-queued-task` via jobqueue callback.
Redirect to use `coding.async.request` directly, or route through
`coding.task.execute` (which already uses async when enabled).

Read the module first to understand the exact call pattern, then redirect.

### 3. Delete blocking handler

**File:** `modules/coding.handler.process-queued-task`

Once callers are removed, delete this module (992 lines, LWP dependency).
Use `remove_file` tool with reason "blocking inference path removed — superseded
by coding.async.* (coding.async.enabled=1 since production deployment)".

Also check for and remove:
- `kimi.handler.process-queued-task` if it has the same LWP blocking pattern
- Any LWP::UserAgent inference code that only served the blocking path

## Execution Order

1. Read `modules/coding.task.execute` — find and remove the blocking fallback branch
2. Read `modules/coding.cmd.complete-analysis` — find and redirect the handler call
3. `ptd -c` on both modified modules
4. Read `modules/coding.handler.process-queued-task` — verify no remaining callers
   use `search_code(pattern: "process-queued-task")` to confirm
5. Delete `modules/coding.handler.process-queued-task` with `remove_file`
6. Check `modules/kimi.handler.process-queued-task` — assess separately

## Acceptance Criteria

- `search_code(pattern: "process-queued-task")` returns no hits in active modules
- `coding.task.execute` has no LWP or blocking inference code
- `coding.cmd.complete-analysis` routes through async path
- `ptd -c` passes on all modified modules
- `p7c coding.list-tasks` still shows tasks dispatching correctly after restart
- test: `p7c task.create ":local: hello world"` completes successfully

## Notes

- signatures_note: leave signing to the system, no stub lines
- do NOT remove the async modules (coding.async.*) — they are the replacement
- if coding.cmd.complete-analysis is complex, use note_write to document
  what it does before changing it
- kimi.handler.process-queued-task: read it first, assess separately —
  it may use a different (non-LWP) pattern for the kimi backend
- async.enabled flag: do NOT remove it — keep it as a kill-switch even
  after the blocking path is gone (set to 0 would just cause task failures
  with a clear error, which is safer than a silent freeze)

#,,,,,..,,,..,,,.,,,,,,.,,.,.,.,,,..,,...,,..,..,,...,...,,,,,.,,,..,,..,,.,,,
#YFOXHJV6P5VBGFZVO7GQSLOPXKNDKB7S2H4GZOF55AUEDMLEHHGHXE7GMFOVWLPPOO2BARMBD675C
#\\\|5ZFHCKKSUOTYPJXHMGLFFQLW5AO7X43DT7FYFFJL6MBLTZU67MX \ / AMOS7 \ YOURUM ::
#\[7]TXGKY2M4PBMOZGSPITIU6B5QW2JX463256EFG5UABHML7WAVDGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
