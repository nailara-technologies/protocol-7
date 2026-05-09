---
name: task coordination architecture
description: current state and roadmap for task zenka as coordinator between kimi, coding, models, and future LLM zenki
type: project
originSessionId: 982c43a3-00c1-40ac-9d1c-a6fafdb428c8
---
## current state (2026-05-09, session 15)

### fully working pipeline
- `p7c task.create ":local: ..."` → notify → claim → in_progress → done
- state flow: pending → claimed → in_progress (task.start) → done/failed
- `p7c task.wait-done TASKID` — deferred reply via `base.callback.cmd_reply` + `reply_id`
  - `task.cmd.complete/fail` fire the deferred reply when done
  - already-done check at call time for fast tasks
- `bin/task-wait` — external polling script for scripts/MCP use
- valued tree: 18 seed nodes loading clean, persist/restore working, `utf8::encode` writes
- `p7c task.valued-list/query/stats` — working via hyphenated cmd modules in task zenka

### key architecture notes
- task zenka is single-threaded — `event.once` cannot dispatch external commands while a handler runs
  - this is why `coding.wait-done` works (internal async callbacks) but task.wait-done needed deferred pattern
- `task.cmd.complete/fail` accept `claimed` OR `in_progress` status
- valued commands exposed as `task.valued-*` (hyphenated) to avoid cube sub-routing clash
- cube/access.zenki controls which zenki can route to which commands — `p7c reload` after editing
- `v7.restart cube` restarts all zenki at once (fastest config reload path)
- YAML data files must NOT have `## [:< ##` P7 headers — YAML::XS chokes on them

### session 15 additions (2026-05-09)
- `:review:` task type: `p7c task.create ":review: module.name"` auto-routes to coding zenka
  with review-cycle template (models.handler.task-poll-step rewrites description)
- consensus_query tool live in coding zenka — perspective injection, LWP blocking
- sliding-compact template: tree_read/write state, tested on 5000-line doc end-to-end
- task.cmd.summarize planned: coding zenka cmd + task zenka cmd + valued tree storage
  with model pinning (cpu backend default, AMOS ID in request body for future routing)
- note_read pagination needed: 287+ line notes exceed tool output budget

### next steps (priority order)
1. **dispatch pending tasks** — event-loop-safety-template, summarize-context-command, cpu-spin-debug
2. **note_read pagination** — offset/limit on sections, reuse pager pattern
3. **task.cmd.wait-timeout module** — internal timer for wait-done timeout
4. **:model: switching actually works** — coding.task.execute compare + switch-model call
5. **task.cmd.next gradient test** — create tasks with node_id, verify valued tree gradient
6. **model evaluation workflow** — first automated comparison run using iteration loop

### access permissions (cube/access.zenki — models user)
`task.queue task.show task.claim task.start task.complete task.fail task.wait-done`

### task zenka start config
`modules.load = auth net protocol io.unix calc format.yaml task valued`
`access.cmd.usr.cube` includes: `create continue queue show result claim complete fail reset start next handover wait-done valued-list valued-query valued-stats`

#,,,.,...,.,.,...,,,,,.,,,.,.,.,.,,..,.,.,,..,..,,...,.,.,,..,.,,,...,,..,.,.,
#ND366V7C6IY7RQRR3TSW2SQMGSDJMA65JUSW622FMOITKEQYKBVSNDTD7OHM2WCGMOKDJBC3KQLDQ
#\\\|FNLTCEL3WVGWQQ5HBMPR2EGQYLIUHU4IURGT7YHHW7Z72KUQG53 \ / AMOS7 \ YOURUM ::
#\[7]HOGKKK4JOU4WMHZMQ7NZT2EYTUUW43XFGNCQBHJEHEXUUP4NUYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
