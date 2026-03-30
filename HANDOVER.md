# Session Handover — 2026-03-30

## What Just Happened

Massive technical debt cleanup across 3 sessions:
- **Inline sub extraction complete**: all pager.*, plugin.storage.*, context.* namespaces
  cleaned — 45+ subs extracted to .util.* modules with source call sites updated
- **Coding zenka tool loop hardened**: task_complete + escalate stop signals prevent
  infinite loops, record_question/record_suggestion collect off-band observations
- **extract-inline-subs template** refined through 8+ autonomous tasks — handles return
  sub unwrap, one-call-per-round, task_complete, known pitfalls documented
- **Loader crash fixes**: removed 5 .disabled modules, fixed regex/interpolation/log bugs
- **Observations stash working**: JSONL at /var/protocol-7/coding/observations/

## What Needs Doing — Functionality Upgrades

### 1. Namespace Tree Intelligence — Layer 1: Tree Read/Write Tools
**Priority: high** | **Where**: coding zenka tools + context-tree modules

The unified namespace tree vision is documented but nothing is built yet.
Layer 1 = give the model tools to read and write the tree:
- `tree_read` — read a branch or node from %data / context-tree
- `tree_write` — write/update a node
- `tree_list` — list children of a branch
- `tree_search` — find nodes matching a pattern

This enables the model to build persistent knowledge outside its context window.
See: `memory/topic-namespace-tree-intelligence.md` for full architecture.

### 2. Task Zenka State Machine Expansion
**Priority: high** | **Where**: task zenka modules, models.task.*

Current: pending -> claimed -> done/failed
Target: open -> assigned -> in_progress -> blocked -> review -> completed -> archived

Key missing pieces:
- `task.next` — autonomous work routing (pick best next task)
- `task.handover` — session context packaging for continuity
- File watcher for external yaml changes

See: `memory/topic-task-coordination.md`

### 3. Coding Zenka Verbosity Reset
**Priority: quick** | **Where**: configuration/zenki/coding/start

Verbosity is at 3 (debug) from loop diagnosis. Revert to 2 after confirming
no remaining issues.

### 4. Coding Zenka Tool Refinements
**Priority: medium** | **Where**: coding.tools.*

From observations stash and tool-suggestions memory:
- replace_in_file dry_run mode (preview before commit)
- replace_in_file line_numbers in result
- ptd_check integration into extraction workflow
- Batch validation for multiple modules

### 5. Multi-Model Consensus Testing
**Priority: medium** | **Where**: llm.service.consensus_vote.*

Modules extracted (commit 526d91760) but untested. Needs:
- Real model provider wiring
- 5-of-7 algorithm group testing
- Integration with task dispatch

### 6. Signature System Bugs
**Priority: low-medium** | **Where**: bin/Protocol-7 sourcecode

- **missing-endline bug**: footer glues to last code line when file lacks trailing
  newline. pre-commit rejects as "no separator endline"
- **Variant B oscillation**: double-footer on never-signed non-empty files

### 7. Self-Improving Loop Closure
**Priority: vision** | **Where**: llm coordination zenka (not yet built)

The coding zenka can now: extract, review, observe, self-fix, and stop cleanly.
Next step toward autonomous operation:
- Token budget awareness (21% weekly remaining, resets Friday)
- Session-limit tracking and reset schedules
- Affinity-based routing (kimi=sustained impl, claude=design/review)
- task.next picking work autonomously between sessions

## Coding Zenka Task Submission

```bash
## submit a task with template
p7c coding.submit ':template: <name>' ':context: modules/<file>' ':description: <text>' ':priority: 5'

## available templates
ls data/yaml/context-templates/   # extract-inline-subs, whats-next, cmd-style-fix, etc.

## check task status
p7c coding.queue
p7c coding.show <task-id>
```

## Key Files for Next Session

- `CLAUDE.md` — full system reference
- `memory/MEMORY.md` — persistent context index
- `memory/topic-namespace-tree-intelligence.md` — tree architecture vision
- `memory/topic-task-coordination.md` — task dispatch state + roadmap
- `memory/topic-self-improving-system.md` — autonomous operation vision
- `data/yaml/context-templates/` — all coding zenka templates
- `modules/coding.tools.definitions` — 22 tool schemas
- `modules/coding.tools.dispatch` — tool dispatch routing
- `modules/coding.handler.process-queued-task` — inference loop with stop signals
