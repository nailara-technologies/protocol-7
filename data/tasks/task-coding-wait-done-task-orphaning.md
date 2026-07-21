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

## status: reproduced five times, one clean discriminator identified, not
##         yet root-caused in code

four concrete stuck records exist right now as live evidence, all
`in_progress`/`(none)`, safe to use as starting points for tracing without
needing to reproduce from scratch: `task.show YLWKQOY`, `task.show
DT7LNNA`, `task.show TV5SXQY`, `task.show M2BRZHA`.

#,,.,,,.,,,.,.,.,.,,,.,.,..,,,.,,,,,,,,,,.,..,,...,...,,,,,..,,,,.,,.,,.,.,

#,,,,,,,.,.,,,,..,.,,,,..,,,.,,.,,.,,,,,,,..,,..,,...,...,.,,,,,.,.,.,...,,.,,
#7GRQFLNOBBPSWCUBHQBU5CBDJ2D7E2NCCJY7YM342ZAHAWIZF5R5RHGMMLEKRSELRUTATWW7MEIRO
#\\\|ORC6RVMUYYEX7UDL3EX2IIR7BQX3MGMSDU3SALKG5CXF6VWMJNK \ / AMOS7 \ YOURUM ::
#\[7]CDVRXP4RRU6POTHJ7FONV4WBR7K4POOMVBTQZ44M33E3XG7QVODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
