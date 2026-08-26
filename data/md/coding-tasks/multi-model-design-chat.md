
 .:[  multi-model design chat interface  ]:.

## Context

`models.chat` already routes queries through multiple models and aggregates
responses. What's missing is an interactive interface suitable for design
sessions — where multiple models can participate in a shared conversation,
see each other's contributions, and build on them collaboratively.

Current workaround: copy-paste between separate nshell sessions per model.
This works but breaks flow and loses the shared context that makes design
sessions productive.

## Goal

A shell-compatible interactive chat interface where:
- Multiple models participate in the same conversation thread
- Each model sees prior contributions from all participants
- The human can direct questions to specific models or broadcast to all
- Context accumulates across turns without manual copy-paste
- File content can be inlined directly into the conversation

## Inline File Expansion

A key feature for design sessions — reference file content directly in messages:

```
[::file:: 'data/md/coding-tasks/indexcube-routing-stack.md' ]
[::code:: 'src/base.parser.decode_harmonized_refstr'    ]
[::tail:: 'src/source.init_code' 60                     ]
```

Expansion happens before the message is sent to models — they receive the
actual content, not the reference. The bracket syntax keeps the human's
message readable while delivering full context to the models.

Variants:
- `[::file::]`  — full file content
- `[::code::]`  — file with line numbers (for code discussion)
- `[::tail::]`  — last N lines
- `[::head::]`  — first N lines
- `[::grep::]`  — matching lines with context

## Conversation Format

```
[human]  → broadcast or directed: [kimi] how should we handle signing?
[kimi]   → response, visible to all models in next turn
[claude] → builds on kimi's response with own perspective
[human]  → follow-up, or summary request: [all] summarize the decision
```

Each turn is stamped with model identity. The thread is a structured log,
exportable as a coding task doc or design decision record.

## Directed vs Broadcast

```
question                       →  broadcast to all active models
[kimi] question                →  directed to kimi only, others see it
[kimi,claude] question         →  directed to subset
[all] question                 →  explicit broadcast (same as untagged)
/switch kimi                   →  change default model for next N turns
/add deepseek                  →  add model to active session
/remove claude                 →  remove model from active session
```

## Design Decision Recording

At any point:
```
/decision                      →  models summarize current consensus
/task                          →  export thread as a coding task .md file
/sign                          →  sign the current decision with AMOS7
```

The `/task` export produces a file in `data/md/coding-tasks/` with the
conversation thread as context and the emerged design as the spec — the
format used throughout the codebase already.

## Implementation Path

### Phase 1 : Single-model with file expansion
Extend nshell or add a `models.design` command that accepts inline file
references and expands them before routing to one model. Proves the
expansion syntax without multi-model complexity.

### Phase 2 : Sequential multi-model
Route each human turn to all active models sequentially, collect responses,
display in order. No inter-model awareness yet — each model sees human turns
only. Simple but usable for parallel perspectives.

### Phase 3 : Shared context multi-model
Each model's response is appended to the shared thread and sent as context
to subsequent models. Models can now build on each other's contributions.
This is the design meeting mode.

### Phase 4 : Async parallel with aggregation
Route to all models simultaneously, collect responses as they arrive,
display incrementally. Reduces latency for large groups. Requires the
non-blocking infrastructure already present in coding zenka.

## Relationship to Existing Infrastructure

- `models.chat`: already routes queries and aggregates — Phase 1-2 can
  reuse its routing logic directly
- `coding.complete-analysis`: multi-turn conversation handling — the
  continuation chain is already implemented
- `nshell`: interactive loop already handles user input and display —
  can be extended or forked as `bin/models-chat`
- `base.parser.list`: structured output for model response display
- AMOS7 signing: `/sign` command uses existing signing infrastructure

## Fine-Tuning Needed in models.chat

Before the design chat layer can be built reliably:
- Verify streaming vs batch response handling for long design discussions
- Confirm context window management across multi-turn threads
- Test model switching mid-conversation without context loss
- Validate that finish_reason detection works correctly for all active
  backends (fix already applied in coding zenka — verify propagated)

## Files

```
bin/models-chat                         ## new: interactive design chat shell
src/models.chat.design_session      ## session state management
src/models.chat.expand_inline_refs  ## [::file::] expansion
src/models.chat.export_task         ## /task → coding task .md
```

#,,.,,,..,,,.,,,.,,,.,,..,,,.,,,,.,.,,,,.,,,.,,..,,.,,,.,..,.,,,,.,..,,...,..

#,,..,.,,,,,.,.,,,.,.,,,,,,.,,...,,,,,..,,.,.,..,,...,...,...,.,,,.,.,,,,,,,,,
#CHDQEFHX2DY5EMDBHVI4YJUJKPSY4PVYEBXZUNA3GLDQXDBKQ4NRUS3M7MUDG3RZQJ53EU2YRNM24
#\\\|IFLVOJJWWNZ7NRDUH36RL6RQCU4A62SNEYRJNSRB4O2QH4NAP3R \ / AMOS7 \ YOURUM ::
#\[7]W233UUA4P6HQRJLUUU3I3RBOSA6F5ST3GJFZ5VQUAAK4EGEZFYAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
