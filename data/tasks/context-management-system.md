# task: context management system

## overview

improve the coding zenka's context handling from its current state into a
first-class manageable object with visual clarity, surgical editing tools,
lifecycle commands, and multi-model orchestration for compaction and recovery.

work in phases — each phase is independently useful and verifiable.

**signatures_note**: do not investigate or modify AMOS7 signatures. leave
signature lines at end of module files untouched.

---

## phase 1 : visual improvement

the current context display is minimal. improve it so each round is clearly
delimited and informative at a glance:

- round header shows: round number, role, token count, CTX% at that point,
  timestamp if available, tool call count if any
- visual separator between rounds (consistent with p7 style — lowercase,
  bracket annotations)
- for tool rounds: show tool name + truncated args inline in the header
- for assistant rounds with thinking: show thinking token count separately
  from output token count
- `coding.show-buffer model_output_` should show a clean scrollable summary
  of the full context shape at a glance

look at existing `coding.show-buffer model_output_` output and the modules
that produce it to understand current state before changing anything.

---

## phase 2 : round management commands

add commands to surgically modify the context without re-running inference:

**`coding.context-drop <task_id> <round_n>`**
- remove round N and its pair (assistant+tool or user+assistant) from context
- refuse if it would make the context incoherent (e.g. orphaned tool result)
- log what was dropped and new token count

**`coding.context-reset <task_id> <round_n>`**
- truncate context back to end of round N
- useful for rewinding after a bad turn without starting over

**`coding.context-edit <task_id> <round_n> <content>`**
- replace the content of a specific round's message
- expose as a model tool too (see phase 3) so the model can self-correct

**`coding.context-show <task_id> [round_n]`**
- show full content of round N, or summary of all rounds if omitted
- include token counts per round

---

## phase 3 : model self-editing tool

add a tool the model can call during a task to edit its own context:

**`edit_context_round`** tool:
- args: `round_index` (int), `new_content` (string), `reason` (string)
- allows model to correct a previous turn, remove hallucinated tool output,
  or annotate a round with a note
- requires `reason` field — logged for audit
- restricted to editing assistant and tool rounds only (not user turns)
- model cannot edit round 0 (system prompt)

this enables self-repair without full re-inference and supports the
'reinterpret a round after code reload' use case: reload modules, then
let model re-examine a prior tool result in the new code context.

---

## phase 4 : compaction and infrastructure commands

**`coding.context-compact <task_id> [model_override]`**
- trigger compaction immediately, optionally with a different model
- log which model performed compaction and resulting token savings
- the compaction model can be larger-context but lower quality — fine for
  summarization work

**`coding.context-compact-auto`** config keys:
- `coding.context.compaction.model` — model id to use for compaction
  (can differ from work model)
- `coding.context.compaction.threshold` — CTX% at which auto-compact fires
- `coding.context.compaction.strategy` — `summarize` | `drop-thinking` |
  `drop-tool-internals` | `cascade` (try each in order)

**`coding.apply-template <task_id> <template_name>`**
- apply an infrastructure utility template to the current task's context
  as an injected system/user message without starting a new round
- examples: `whats-next`, `post-task-verify`, `p7-style-enforce`
- different from `coding.task-append` — this injects at the infrastructure
  level, not as a user turn

---

## phase 5 : multi-model orchestration

**model role configuration:**
```
coding.model.work       = <model_id>   ## primary work model
coding.model.compact    = <model_id>   ## compaction / summarization
coding.model.fallback   = <model_id>   ## fallback when work model at context limit
coding.model.review     = <model_id>   ## code review / verification pass
```

**fallback behaviour** (size/requirement based):
- when work model hits context ceiling: auto-switch to fallback model
  with compacted context, continue task
- fallback model selection: prefer larger context, tolerate lower quality
- on fallback: log clearly, preserve task continuity, allow manual
  `coding.switch-model` to return to work model after compaction

**`coding.model-handoff <task_id> <target_model>`**
- explicit hand-off: compact current context, switch model, resume task
- useful for: escalating a stuck task to a larger model, handing off
  a near-complete task to a lighter model for cleanup

**round tagging by model:**
- each round header should record which model produced it
- visible in `coding.context-show` output
- preserved across model switches so audit trail is clear

---

## scope notes

- read existing context management modules before adding anything:
  `coding.async.compact_context`, `coding.async.state_machine`,
  `coding.task.*`, `coding.handler.process-queued-task`
- the model_output buffer display logic is a good starting point for
  phase 1 — find where round headers are written and extend there
- use `note_write` to record design decisions and open questions
  as you go — do not try to hold everything in context
- use `task_complete` when done with each phase so progress is checkpointed
- $ARG not $_ for loop variables
- do not add inline subroutines — extract to named modules
- verify syntax with `ptd -c modules/<name>` after each module change

#,,..,,,,,,,.,,,,,,,.,,,,,..,,..,,,,.,..,,,..,..,,...,...,...,..,,.,.,...,...,
#UKNLY54TUKU2PSNMIF5Z7A3NQVTLUFIHHCXEXD3FIKPW63BOLUZQ4NNSVHS3UG3EMFSFGOM6BJ7Q2
#\\\|2AZWTIFYMYM5QETXM4ZPEAEEQTM5JA2ULFZSILVLP63GEXQVDHW \ / AMOS7 \ YOURUM ::
#\[7]PYYJQXLH7GFT5FRKERJMR3BQMAIAIJVLBOCMG7OQ5IDNV3J6TQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
