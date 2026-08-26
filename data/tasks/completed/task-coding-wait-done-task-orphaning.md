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

## reproduction — five confirmed live instances, one clean discriminator

**instance 1**: task-zenka task `YLWKQOY` → coding task `task-EQBEUGI`
(model `VDN3VGA:6BPXFLY`, official Qwythos-9B-v2, Q8_0). hit a
streaming-start timeout after 120s, recovered on retry, the recovered
generation contained hallucinated/malformed tool-call syntax
(`<function_calls>` XML for a nonexistent `consensus_query` tool — itself
worth a separate note about prompt-injection-shaped model output flowing
back through `coding.wait-done` as plain data, see "related risk" below).
shortly after, `coding.list-tasks` showed no active tasks, but `task.show
YLWKQOY` has stayed `status: in_progress`, `result: (none)` ever since.

**instance 2**: task-zenka task `DT7LNNA` → coding task `task-3BYQE7A`
(model `BY4AXTI:5T4ODPY`, original pre-v2 Qwythos-9B-Claude-Mythos-5-1M).
round 0 produced a plain-text clarifying-question reply with **no tool
call at all** (confirmed genuine via live console, not a stale-buffer
artifact). same orphan shape.

**instance 3**: task-zenka task `TV5SXQY` → coding task `task-GDKIIQA`
(model `L7NRHPY:6WOOFAQ`, llmfan46 Heretic build, Q6_K). round 0, plain-
text clarifying question, **no tool call**. same orphan shape.

**instance 4**: task-zenka task `M2BRZHA` → coding task `task-7Y644GA`
(model `2HZQLFQ:LEMT26Q`, official Qwythos-9B-v2, Q6_K — same model as
instance 1, different quant). round 0, plain-text clarifying question,
**no tool call**. same orphan shape.

**counter-example (does NOT orphan)**: task-zenka task `DFSRIAQ` → coding
task `task-CNNW3XI` (same `VDN3VGA:6BPXFLY` as instance 1). model
substituted its own target module instead of the one named in the
instructions — a real deviation — but it *did* call `read_module` (a real
tool call) and then `task_complete`. `task.show DFSRIAQ` resolved cleanly
to `status: done` with a result. no orphaning.

**the discriminator**: across all five data points, orphaning correlates
exactly with whether the round contained a tool call, not with which
model, which quant, or whether the round's content was otherwise "normal."
every zero-tool-call plain-text round we observed orphaned; every round
with at least one tool call (even a wrong/substituted one, even the
malformed-hallucinated one in instance 1) eventually resolved through the
normal completion path or an explicit `coding.stop-task`. strong candidate
root cause: whatever finalizes a round likely branches on "did this round
contain a tool call" and the no-tool-call branch skips notifying task-
zenka entirely, rather than something failure/retry-specific.

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

primary lead, given the discriminator above: find whatever finalizes a
round where the model's reply contains **zero tool calls** (a bare
plain-text response, e.g. `chunk_handler`/`state_machine` in the
`coding.*` inference pipeline — look for the branch that checks for
extracted tool_calls and see what the "none found" path does). the
hypothesis is that this path either does nothing (leaves the round
awaiting a continuation that never comes) or clears the task from
`<coding.task.queue>` directly without routing through `coding.handler.
deferred_reply` the way every other exit path (success, failure, stopped)
does. compare directly against the working paths: a round WITH a tool
call flows through `tool_executor` → eventually `task_complete` →
`[on-task-complete]` → `coding.handler.deferred_reply` → `task.summarize-
done`/`task.summary-tree-notify`. find the equivalent (or missing)
handling for the zero-tool-call case.

secondary/fallback fix, if the completion-path fix turns out to be
non-trivial: add a reconciliation check in `task.show`/`coding.wait-done`
— if task-zenka's record is `in_progress` but the corresponding coding
task is genuinely gone from `coding.list-tasks`, resolve it to a failed
state instead of hanging in limbo forever. this doesn't fix the root
cause but bounds the damage.

## status: RESOLVED — root-caused and fixed 2026-07-22 (one day after
##         filing), re-verified live 2026-08-21

root cause (as hypothesized above): `coding.async.chunk_handler` — when
`finish_reason` was `tool_calls`/`function_call` but the streamed
tool_calls array came back empty (server quirk: model claimed a tool call
but delivered none), the outer branch fired but the inner `@tool_calls`
guard was false, so no state_machine transition ever dispatched. sm_state
stayed `streaming` forever, `models.handler.task-result` was never
invoked, and `task.complete`/`task.fail` never fired. fixed in commit
`bc10c8d4d` ("fix: coding task orphaning on zero-tool-call rounds") by
moving the tool_calls-array check into the outer condition and letting
empty-tool_calls finishes fall through to the normal stop path (xml/json
fallback parse, then `finish_stop`). follow-up hardening: `1cf273981`
(2026-07-22, tool-call-shaped-but-unparseable content: bounded
format-reminder retry, then clean fail) and `87e208f9d` (2026-07-31,
reasoning-only stream close without finish_reason: bounded answer-nudge
retry, then clean fail).

note: plain `git log -- src/coding.*` after the 2026-08-20
modules/->src/ rename (5255a50a3) shows only the rename commit; the fix
is only visible with `git log --follow`. the "not fixed by any commit"
assessment was an artifact of that.

live re-verification 2026-08-21: task-zenka task `SREOIFI` -> coding task
`task-OSHHIIA`, plain-text zero-tool-call reply ("Paris.", finish_stop
path, no tool_executor invocation) resolved cleanly to `status: done`
via on_task_complete -> deferred_reply -> models.handler.task-result ->
task.complete. the chain works end-to-end for the exact reproduction
condition.

the four original stuck records (YLWKQOY, DT7LNNA, TV5SXQY, M2BRZHA) no
longer exist: the task zenka was restarted since and its persisted queue
(/var/protocol-7/task/queue.yaml) is empty as of 2026-08-21. they were
pre-fix artifacts, intentionally left as historical evidence per the fix
commit message. coding-zenka-side logs from 2026-07-21 additionally show
the coding tasks themselves (task-EQBEUGI, task-3BYQE7A) actually
completed and fired deferred_reply — they vanished from `coding.list-
tasks` because that command only lists active/pending tasks, and a
completed task moves to the completed list.

#,,,.,.,,,,,.,,..,,.,,,,,,..,,...,...,.,,,,,,,..,,...,...,,..,.,,,.,,,,..,,,.,
#C4L7GAJMGEPHI4VXBCJCJHEBNFJQGXW2YCKB2E2MTDP35PRHF7MWB5SW2ZW7S7UGMN4QPTRLYGXX6
#\\\|TLJVNW5NZPSLA4OVY6OXQKKYVMSJNUHKY5YDW3EYNXCKE555PJS \ / AMOS7 \ YOURUM ::
#\[7]2CP7Y43CMFM3U26UBDMZJD6QR2UGX7VXMTZSC6ZGX5JQREX6B6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
