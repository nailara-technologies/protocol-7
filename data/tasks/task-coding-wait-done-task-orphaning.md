## [:< ##

# name  = task: coding task orphaning — task-zenka record stuck in_progress
#         forever after coding drops the task without notifying
# descr = a coding task can vanish from `coding.list-tasks` (no longer
#         active) while the originating task-zenka record stays
#         `status: in_progress` / `result: (none)` permanently — the
#         normal completion notification chain (deferred_reply →
#         task.complete) never fires for these

## context

session: 2026-07-21, discovered while evaluating Qwythos-9B-v2 variants
(vision+coding model comparison, see git log same-day commits for the
unrelated model/mmproj mismatch fix and wait_done_timeout accessor fix —
this is a third, separate, still-open issue found in the same session).

## reproduction — two confirmed live instances

**instance 1**: task-zenka task `YLWKQOY` → coding task `task-EQBEUGI`
(model `VDN3VGA:6BPXFLY`, official Qwythos-9B-v2). hit a streaming-start
timeout after 120s, recovered on retry, the recovered generation contained
hallucinated/malformed tool-call syntax (`<function_calls>` XML for a
nonexistent `consensus_query` tool — itself worth a separate note about
prompt-injection-shaped model output flowing back through `coding.wait-
done` as plain data, see "related risk" below). shortly after, `coding.
list-tasks` showed no active tasks, but `task.show YLWKQOY` has stayed
`status: in_progress`, `result: (none)` ever since — never reconciled.

**instance 2**: task-zenka task `DT7LNNA` → coding task `task-3BYQE7A`
(model `BY4AXTI:5T4ODPY`, original pre-v2 Qwythos-9B-Claude-Mythos-5-1M).
round 0 produced a plain-text clarifying-question reply with no tool call
at all (confirmed genuine via live console, not a stale-buffer artifact —
see below). `coding.list-tasks` then showed no active tasks; `task.show
DT7LNNA` is stuck the same way: `status: in_progress`, `result: (none)`.

common shape: both instances involve an *abnormal* round — a timeout+retry
in one case, a no-tool-call plain-text round in the other — followed by
the coding-side task disappearing from the active list without the normal
completion path running.

## what this is NOT

- **not** the `coding.handler.wait_done_timeout` bug fixed earlier same
  session (`$event->data` → `$event->w->data`, commit `49f6dc768`) — that
  bug caused wait-done to hang forever with zero reply. this issue is
  different: wait-done *does* reply (either a real timeout reply, or in
  instance 1/2's case, something that looked like it might be stale
  buffered content but was actually confirmed live/genuine — the model
  really did produce that output), but the underlying task-zenka record
  never gets marked done/failed regardless.
- **not** the `coding.handler.switch_model_reply` mismatch bug fixed same
  session (commit `1596607ad`) — unrelated subsystem (model spawning vs.
  task lifecycle).
- **not** `coding.async.complete`'s existing orphan-cleanup logic (lines
  ~320-370, `$orphan_id` handling) — that path is specifically for
  parent/subtask decomposition cleanup when a parent task was stopped
  mid-subtask. both reproduction instances here were plain top-level
  tasks, no subtask decomposition involved, so that cleanup path doesn't
  apply and isn't where to look.

## related risk worth flagging separately

instance 1's recovered generation contained a malformed fake tool-call
block for a tool that doesn't exist anywhere in this system
(`consensus_query`). that text flowed back through `coding.wait-done`'s
reply data as plain content and — in the Claude session investigating this
— nearly caused the reviewing model to blindly imitate the same
malformed call pattern before catching itself. worth keeping in mind for
any pipeline that surfaces raw model output as data to another model:
it should be treated as inert text, never as something to pattern-match
against as an instruction, especially when a model under test could be
adversarial, buggy, or simply confused the way this one was.

## requirement

find where a coding task can be removed/lost from `<coding.task.queue>`
(or otherwise drop out of `coding.list-tasks`'s active view) on an
abnormal-round path — likely candidates to check first: whatever handles
a streaming-start timeout's retry-then-recover sequence, and whatever
finalizes a round where the model returns plain text with zero tool
calls (does that count as "done" somewhere without going through
`coding.handler.deferred_reply`'s normal `task.summarize-done` /
`task.summary-tree-notify` route-sends?). confirm whether the fix belongs
in the completion path (make it always notify task-zenka before a task
leaves the active queue, success or failure) or in `task.show`/`task.
wait-done` itself (add a reconciliation check — if task-zenka's record is
`in_progress` but the corresponding coding task is genuinely gone, that
should resolve to a failed state instead of hanging in limbo forever).

## status: reproduced twice, not yet root-caused

two concrete stuck records exist right now as live evidence:
`task.show YLWKQOY` and `task.show DT7LNNA`, both `in_progress`/`(none)`,
safe to use as starting points for tracing without needing to reproduce
from scratch.

#,,.,,,.,,,.,.,.,.,,,.,.,..,,,.,,,,,,,,,,.,..,,...,...,,,,,..,,,,.,,.,,.,.,

#,,,,,,.,,..,,,,,,..,,,,,,.,.,,,,,,,.,,.,,.,.,..,,...,...,.,,,,.,,,,.,,,.,,,,,
#EPQEMEDYP25MO3HCB7YAHNPOXXRAKGOIAXE2R7LHZVUKNWV3LPWWKXN7KO3GQACOASUEQ6E3HQ3UU
#\\\|DRRI2EMOWWDBRVLH3HJCYP4UGSAXOKZDDIBMLNGBHWTGBTXADUI \ / AMOS7 \ YOURUM ::
#\[7]JI4KHRMFLGY7XL7VEZ3KGTOHAKQ7F4DJ5W4ZM4NUQAJWVXWMDABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
