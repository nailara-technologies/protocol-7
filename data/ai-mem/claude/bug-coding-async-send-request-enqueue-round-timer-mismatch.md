---
name: bug-coding-async-send-request-enqueue-round-timer-mismatch
description: FIXED 2026-08-19 — coding.async.send_request's queue_paused retry timer used a 'params' key event.add_timer never reads and called coding.task.enqueue_round as a timer-handler when it's direct-call shaped, silently dropping any task retried while queue_paused was set
metadata:
  type: project
---

**Symptom**: jobsite assessment task stuck `in_progress` for 2.5+ hours
(coding-zenka internal id `task-4GEIBBA`, outer task-queue id `EIGJ6FY`),
`round=0`, `http_state.chunks_received=0` the entire time, `retry_pending`
still `TRUE`. `coding.list-tasks`/`coding.round-progress` showed it frozen
forever with no error, no completion. Two other, unrelated bugs
([[bug-jobsite-pending-count-leak-nonassessing-cycle]],
[[project-coding-zenka-bug-catalog-2026-08-15]]'s list-tasks delta-time
defect) were found and fixed in the same session before this one was
pinned down — don't assume a single stuck-task report has one cause.

**Root cause**: `src/coding.async.send_request`'s `queue_paused` branch
(hit when a task retries while `<coding.task.queue_paused>` is set — true
during any self-test-after-respawn or crash-restart cycle, not just this
one) rescheduled itself via:
```perl
<[event.add_timer]>->({ 'after' => 5.0,
    'handler' => 'coding.task.enqueue_round',
    'params'  => { 'task_id' => $task_id, 'round' => $round } });
```
`base.event.add_timer` has no concept of a `'params'` key — it only ever
reads `'data'` (confirmed: zero other `event.add_timer` call sites in the
whole codebase use `'params'`). And `coding.task.enqueue_round` is
direct-call shaped (`my ($task_id, $round) = @ARG`) — every other caller
(`coding.async.state_machine`, `coding.callback.http_complete`,
`coding.async.complete`, `coding.cmd.task-append`) invokes it as
`<[coding.task.enqueue_round]>->($task_id, $round)`, never as a timer
handler. When the mis-wired timer fired, `enqueue_round` received the raw
Event watcher object as `$task_id` and `undef` as `$round`, hit its own
`return {...'round required'} unless defined $round;` guard, and returned
silently — no log line, no reschedule, task dropped for good.

**Diagnostic trail that pinned it** (reusable technique): grepped the live
merged log (`/dev/shm/.7/STDOUT/<id>`, see
[[feedback-kimi-v7-console-hint]]) for the stuck task's internal id and
found the exact death point —
```
async.request: error for task-4GEIBBA: Data start timeout
async.request: retrying task-4GEIBBA [attempt 1/1]
send_request: queue paused : rescheduling task-4GEIBBA in 5s   <- last mention, ever
```
no `enqueue_round:` line ever follows (it logs unconditionally on entry in
the working path), which is the fingerprint. Confirmed live via `devmod`
(`coding.set coding.task.queue_paused 1`, then
`coding.eval-code $code{'coding.async.send_request'}->('<task_id>')`,
watch the log 5s later) both before the fix (nothing happens) and after
(reschedule loop correctly repeats, then resumes cleanly once unpaused).

**Fix**: added `src/coding.handler.enqueue_round_timer` as a thin
timer-shape adapter (`shift->w->data` → direct call), and pointed
`send_request`'s reschedule at it with the payload under `'data'` instead.

**Blast radius**: general, not jobsite-specific — ANY coding-zenka task
(consensus-voting participant, coding-self-improvement task, anything)
that hits a retryable HTTP error while `queue_paused` happens to be true
was silently and permanently lost. This is very likely the mechanism
behind other historical "task just vanished" reports in this codebase,
including the still-not-fully-explained trigger in
[[topic-coding-zenka-wedged-backend-queue-gridlock-2026-08-05]] (that
incident's specific `verify_inference_startup` 120s fail-open trigger is
still a separate, real gap, but the "exact line where a request can go
missing" it flagged as unlocated is this one).

**How to apply**: if a coding-zenka task is reported stuck at `round=0`
with zero chunks received, check the live log for
`send_request: queue paused : rescheduling <id> in 5s` with no
`enqueue_round:` line following — that was this bug's fingerprint before
the fix landed (commit `dd162183b`). After the fix, expect to see the
`enqueue_round:` line every 5s while paused, and an actual `send_request:
task=... round=... messages=...` line once unpaused.

#,,..,,,,,.,,,,..,..,,,,,,.,.,,,.,.,.,,,,,.,.,..,,...,..,,.,.,,,,,,.,,...,.,,,
#GDU4OSFJMQZP2G4XLF5CVMDKAV7DHXNB7X7T5ZPSAJZHFF4HYWXDIV7PB3SQTUNORVRIEMPUWJNY6
#\\\|4KJV4M3MA52PVFS5YO6JOE3YMUMIKAWUF2UAL67A56C2K5EWLC2 \ / AMOS7 \ YOURUM ::
#\[7]GZ33TW3XNVDYJBZLQVAZYGMXB57DUNOGHW6K5VHASWW75DSKYSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
