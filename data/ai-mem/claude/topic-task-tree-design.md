---
name: task tree design
description: unified task/subtask tree with history archive, multi-parent grouping, passive+active deps
type: project
originSessionId: 34ca9c97-628c-46af-82f3-d04a171ae8f0
---
Generic node graph covering both task zenka and coding zenka subtasks.
Nodes can freely be members of multiple parents simultaneously.

**Why:** Completed tasks were being cleared from lookup scope, breaking
task.cmd.summarize. coding zenka subtree and task zenka are parallel disconnected
universes. History needs to survive restarts and be queryable.

**How to apply:** Reference this when implementing task.persist.history,
task.cmd.complete archive move, or dependency checking in task.cmd.next/claim.

## Task record additions

```yaml
parent_id: PPPPPPP          # primary parent task (optional)
children: [AAAAAAA, ...]    # child task ids
groups: [GGGGGGG, ...]      # multi-parent membership (any node can be in N groups)
depends_on: [XXXXXXX, ...]  # passive deps — task unclaimable until all are 'done'
requires:                   # active deps — executed before dispatch
  - type: switch-model
    model: EMQFUAA:VWI5WKQ
    restore: true           # resolved via <[base.cfg_bool]>
  - type: worker
    model: ZDMAPAY:AR3OCKQ
```

## Boolean fields

All boolean fields on task/dep records use `true`/`false` strings,
resolved at read time via `<[base.cfg_bool]>->( $val // 'false' )`.
Never use 1/0 for boolean task record fields.

## Dependency types

**Passive** (`depends_on`) — pure graph constraint, no side effects.
Checked at task.cmd.next / task.cmd.claim. Task stays 'pending' until
all listed task ids have status 'done'.

**Active** (`requires`) — executable setup hooks, run sequentially by
the dispatcher before the task body starts. Known types:
- `switch-model` — coding zenka calls switch-model; `restore: true` reverts after completion
- `worker` — shorthand: route subtask to specific model without full switch
- `tool-set` — restrict available tools for this task
- `zenka` — ensure a zenka is online before dispatching
- `await-event` — suspend task until named external status slot becomes true;
  slot written by any zenka (Gmail, site-yaml, timer, etc.) via variable watcher

## External status slots

Tasks can expose named watcher slots under `<task.state.TASKID.slotname>`.
Any zenka writes to the slot; the state machine wakes the task automatically.
No polling — purely reactive, native to the event loop.

Examples:
- `email_reply` — Gmail zenka detects matching inbound reply
- `application_sent` — send action confirmed complete
- `report_due` — timer watcher fires at agreed date
- `new_content` — site-yaml detects new offers/episodes on next fetch

Slots are ephemeral (watcher re-registered on restart), slot names persisted
in the task record so they survive restarts. Same lifecycle as coding.state watchers.

## History / archive

Completed tasks move from `<task.queue>` to `<task.history>` on complete/fail.
`task.persist.save` writes both `queue.yaml` and `history.yaml`.
All cmd modules (result, show, summarize) check `<task.queue>` first, then `<task.history>`.
Keeps live queue bounded; history queryable indefinitely.

## State sharing — convergence point

Currently task zenka (`<task.queue>`) and coding zenka (`<coding.task.queue>`)
are separate trees referencing each other by ID. Next step: same underlying tree,
each zenka holds a live cursor/view into it. Authoritative node owned by one zenka,
others hold references — same orbital ring model.

Once state is genuinely shared, distributed case emerges for free: a task node on
a remote P7 instance is just a tree node reachable via longer route. Watchers fire
regardless of whether the writing zenka is local or remote. Tree has no location,
only addresses — local and distributed are the same operation at different latencies.

Remote inference workers (ik_llama.cpp) are task workers farther away in address
space — dependency graph unchanged, only routing depth differs.

## Valued tree relationship

Tasks link to valued tree via `node_id` field (already in task records).
The valued tree handles priority/ref-count propagation.
Task tree parent/child is a separate (simpler) layer on top.
`queue_order` remains live-queue-only for next/claim iteration.

#,,,,,..,,...,,,.,.,,,...,,,,,,,,,,.,,,.,,,.,,..,,...,...,..,,,..,,.,,..,,,..,
#7O6HWSLKKFJIOEN5NJFHN6HARDD2QWFAHBCI7OTEDFFQ3VPZHYT4SEP3AW4SGWZAJY2M6FZX64YUE
#\\\|UCAYWAMNHMBA36JCQS4364CB7HLAQKOYRT3V3GGRPN7BO35FWAZ \ / AMOS7 \ YOURUM ::
#\[7]XNSRLSCWJW44ATLNRWSOXLKYSVLPKCHQUMZWOJPPOTBH4YRMGMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
