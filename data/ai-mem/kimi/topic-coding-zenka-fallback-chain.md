# coding zenka fallback chain + user-interaction tools

Implemented 2026-08-09.

## what changed

- New tool handlers under `coding.tools.handler.*`:
  - `ask_user_choice` — routes to `protocol-7-menu.cmd.input-choice`
  - `ask_user_text` — routes to `protocol-7-menu.cmd.input-text`
  - `ask_user_stream` — routes to `amos-term.interaction.ask`
  - `suggest_new_topic` — records a `topic-proposal` observation with an
    `audit_trail` of fallback-chain steps
  - `flush_pending_questions` — presents queued non-urgent choice questions
  - `write_answered_note` — shared helper that writes answers back to notes
    (section `answered-question`, tag `answered-question`)
- `coding.handler.user_stream_reply` — async reply handler for the amos-term
  interaction buffer; writes replies to notes.
- `coding.tools.handler.task_complete` now flushes the pending question queue
  before completing the task.
- `coding.tools.definitions` registers the four new model-facing tools.
- `coding.cmd.call-tool` includes the new tools in its direct-dispatch table.
- `data/yaml/context-templates/system-tools.yaml` documents the fallback chain
  and the new tools, including the visible `[out-of-scope: general knowledge]`
  flag for `offer_general_answer`.

## batching decision

The task file left the exact batching mechanism as an open design question.
I chose the simplest reasonable path:

- Non-urgent `ask_user_choice` items go into `<coding.pending_questions>`.
- Urgent items (`urgent=true`) pop the dialog immediately.
- The queue is flushed once, before `task_complete`, by
  `coding.tools.handler.flush_pending_questions`.
- Unanswered items are returned to the queue so the user gets another chance
  at the next checkpoint.

I deliberately did **not** add an idle timer because calling GTK modal dialogs
from an event timer handler re-enters the main loop and adds deadlock risk for
minimal gain. If later usage shows we need earlier flushing, a timer can be
added by resetting it on every queued item and having it call the same flush
module.

## non-obvious gotchas

- `protocol-7-menu.cmd.*` modules expect a command-style `$call` argument. The
  generated cmd header accepts either a hashref (taken as `$call`) or a scalar
  (placed into `$call->{'args'}`), so passing `{ args => ... }` works for a
  direct `$code{...}` invocation.
- Avoid literal `$code{'protocol-7-menu.cmd.input-choice'}` in the source: the
  referenced-sub scanner would flag it if protocol-7-menu is not loaded in the
  coding zenka. Use a dynamic `$code{$target}` after a `base.code.exists`
  guard instead.
- `amos-term.interaction.ask` is optional; the handler checks presence via
  `base.code.exists` and returns a clean failure if the interaction channel is
  not loaded.
- `suggest_new_topic` embeds the audit trail in the observation `content`;
  `record_observation` already stores `category`, so `topic-proposal` is kept
  as the category rather than a separate tag.
- All answers are written back to notes with section `answered-question` and
  tag `answered-question`, satisfying the close-the-loop requirement for
  `note_search` step 5.

## verification checklist

- [ ] A no-match query runs the six-step chain and records the checked steps
      (visible in the model's final reply / self-test-detail output).
- [ ] `offer_general_answer` replies start with `[out-of-scope: general knowledge]`.
- [ ] `suggest_new_topic` entries include the `fallback_chain checked:` list.
- [ ] A repeated question is found by `note_search` before re-triggering an
      `ask_user_*` tool.

## files touched

- `src/coding.tools.handler.ask_user_choice`
- `src/coding.tools.handler.ask_user_text`
- `src/coding.tools.handler.ask_user_stream`
- `src/coding.tools.handler.suggest_new_topic`
- `src/coding.tools.handler.flush_pending_questions`
- `src/coding.tools.handler.write_answered_note`
- `src/coding.tools.handler.task_complete`
- `src/coding.handler.user_stream_reply`
- `src/coding.tools.definitions`
- `src/coding.cmd.call-tool`
- `data/yaml/context-templates/system-tools.yaml`

#,,,.,,.,,...,...,,,,,,,,,,..,.,,,.,,,,,,,...,..,,...,...,...,..,,,..,,,,,,..,
#XBUBCELRCDHTMASA7IRBH3R7CNO5LEIPY5BH6EILAXQML2HUMV3RXGWVVU64XCYZVYAVHGVD52YMK
#\\\|IHPTQ5ITVMF764FARKLGIOFWW6Y7NZBZHXBSQJ5OOMJIUSVC2Z7 \ / AMOS7 \ YOURUM ::
#\[7]ZZDSXGFXLKMQW524FDM74DQCHO23QDZ5G4LVF3CWL6ROXOLHMQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
