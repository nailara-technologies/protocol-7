---
name: task coordination architecture
description: current state and roadmap for task zenka as coordinator between kimi, coding, models, and future LLM zenki
type: project
---

## current state (Mar 23 2026)

### what works today

- **task zenka**: live, YAML persistence via format.yaml, AMOS checksum IDs, ntime.b32 timestamps
  - commands: create, show, queue, claim, complete, fail, reset
  - notify mechanism: notifies models zenka on task creation
  - no polling — event-driven via notify
- **models zenka**: event-driven dispatch with jobqueue + dispatch_slot dependency
  - claims tasks, routes to backend (kimi or coding) based on `:model:` prefix
  - single-task concurrency via dispatch_slot callback
  - task-result handler completes/fails tasks based on backend reply
- **kimi zenka**: websocket client to kimi-web, receives prompts via ask-reply
  - on-demand startup (1800s idle timeout)
  - auto-approve tool calls in task mode
  - session persistence + reconnect resilience
  - reconnect preserves busy status to avoid spurious init retries (commit `0799bb8d6`)
- **MCP server**: claude code has direct tool-call access to task queue
  - p7_task_create, p7_task_show, p7_task_queue, p7_command

### flow: task creation → completion

```
claude code (MCP) → task.create → task zenka stores + notifies models
  → models.cmd.task-notify claims task
  → models.handler.task-poll-step fetches details, determines backend
  → models.task.enqueue → jobqueue with dispatch_slot dependency
  → models.task.execute → protocol-7.route-send to kimi.ask-reply
  → kimi.wire.prompt sends to kimi-web websocket
  → kimi-web processes, ContentPart events accumulate
  → TurnEnd → kimi fires deferred reply back to models
  → models.handler.task-result → task.complete
```

### what's partially implemented

- **task zenka state machine** (task-zenka-implementation.yaml step 3):
  open → assigned → in_progress → blocked → review → completed → archived
  — currently only: pending → claimed → done/failed
- **task.next** (step 5): autonomous work routing — not yet built
- **task.handover** (step 7): session context packaging — not yet built
- **file watcher** (step 6): watch yaml directory for external changes — not yet built

### what's designed but not built

- **llm coordination zenka** (llm-coordination-zenka.yaml):
  token-budget-aware scheduling, session-limit tracking, reset schedules,
  user-as-zenka model, affinity-based routing (kimi=sustained implementation,
  claude=design/review, user=decisions/domain)
- **multi-model consensus** (llm.service.consensus_vote):
  cubic topology voting, harmonic certainty — modules extracted (commit `526d91760`)
  but untested, needs refinement for 5-of-7 algorithm group and real model providers

## architectural questions (open)

1. **where does coordination logic live?**
   - currently: models zenka owns dispatch + routing
   - option A: keep models as dispatcher, task zenka as storage only
   - option B: task zenka becomes coordinator, models becomes just a registry
   - option C: extract coordination into shared modules, either zenka can host
   - leaning: keep working systems alive, extract overlaps into generic modules

2. **polling vs event-driven**
   - models→task: already event-driven (notify on create)
   - original kimi design had 30s polling — replaced with notify+dispatch
   - future zenki should use notify pattern, not polling

3. **multi-agent concurrency**
   - dispatch_slot currently allows one task at a time globally
   - future: per-backend slots (kimi slot, coding slot, remote-node slot)
   - task.assign prevents overlap by design (atomic claim)

4. **task decomposition for autonomy**
   - key insight: tasks must be executable without questions
   - task.next should filter on `executable_without_input: true`
   - handover packaging for session boundaries

## reference files

- `data/yaml/coding-tasks/llm-coordination-zenka.yaml` — vision + token budget design
- `data/yaml/coding-tasks/task-zenka-implementation.yaml` — implementation checklist (steps 1-7)
- `data/md/coding-tasks/task-zenka-kimi-coordination.md` — original task+kimi design doc
- `modules/models.init_code` — dispatch_slot dependency setup
- `modules/models.handler.task-poll-step` — async claim+dispatch chain
- `modules/models.task.execute` — jobqueue callback, route-send to backend
- `modules/models.handler.task-result` — complete/fail based on backend reply
- `modules/kimi.cmd.ask-reply` — entry point for kimi dispatch
- `modules/kimi.handler.ws_message` — TurnEnd handling, reconnect resilience
- `modules/kimi.connect` — websocket lifecycle, preserved-prompt busy status
- `modules/task.cmd.*` — task zenka command modules

## near-term next steps

- refine kimi workflow resilience (in progress — init retry fix deployed)
- test multi-model consensus with real providers beyond kimi-web
- task.next command for autonomous work pickup
- per-backend dispatch slots for parallel kimi + coding execution
- generic coordination modules extractable from models zenka

#,,.,,,,,,...,.,,,,.,,..,,,..,.,,,.,.,,,.,,,.,..,,...,...,,.,,,,,,,.,,,..,,..,
#QRYKQ7SVLBGSZ3KMC6JF4WEGIZ6CPUAMFLH45YJZBZGVBNWINUB7GZ5X2WLC4COUHZFB7E2SIVSCK
#\\\|BEAYP27LP7WTVBCIDXFIMBZ7Y3MDB42IYUGW4IH7DYN2THMGYB5 \ / AMOS7 \ YOURUM ::
#\[7]AKFCG3VSMWH5SY7FLBURHGAXJUBCPTK47IM6RQRFBEVWODCKJ6CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
