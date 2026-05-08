---
name: task coordination architecture
description: current state and roadmap for task zenka as coordinator between kimi, coding, models, and future LLM zenki
type: project
originSessionId: 982c43a3-00c1-40ac-9d1c-a6fafdb428c8
---
## current state (2026-05-08, session 14)

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

### next steps (priority order)
1. **task.cmd.wait-timeout module** — internal timer for wait-done timeout (needs registered handler, not coderef)
2. **task.cmd.next gradient test** — create tasks with `node_id` set, verify valued tree gradient sorting works
3. **meta-session-summary wiring** — `meta.session-summary` tree node → trigger `task.cmd.handover` at session end (Stop hook or coding zenka template)
4. **model evaluation workflow** — first automated comparison run using iteration loop

### access permissions (cube/access.zenki — models user)
`task.queue task.show task.claim task.start task.complete task.fail task.wait-done`

### task zenka start config
`modules.load = auth net protocol io.unix calc format.yaml task valued`
`access.cmd.usr.cube` includes: `create continue queue show result claim complete fail reset start next handover wait-done valued-list valued-query valued-stats`

#,,,.,.,,,..,,.,,,.,.,,..,,,.,...,...,,.,,...,..,,...,..,,...,,,,,,,.,,.,,,,,,
#RKMTSYKDFRRYRVAS5GIRGRRMWYVT2PCGF24ZDOWVX45NOYSPTQB7ORBB3GFJDX3LE23LYP2HYMHUW
#\\\|YMGY5OSON2ALBF26GVA5NKFQFPZTSEEDZ7GOHA4U6FZYR55VO7J \ / AMOS7 \ YOURUM ::
#\[7]WCLDNM4J5LULM4ND5L4ZFYWSWCYI4MCPFTJX4FBQJUXOLJUOFKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
