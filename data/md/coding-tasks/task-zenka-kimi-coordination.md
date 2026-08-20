# Task: `task` zenka + kimi-web auto-pickup

## Goal

eliminate manual copy-paste between claude code and kimi sessions.
claude code writes tasks to a shared `task` zenka via `p7 task.create`.
the kimi zenka polls for pending tasks and auto-submits them. results
are written back to the task record and readable via `p7 task.get`.

---

## Part 1 — `task` zenka

### data model

each task is a hashref stored in `<task.queue>` keyed by task id:

```perl
{
    id          => 'AMOS7_chksum',   ## 7-char unique id ##
    status      => 'pending',        ## pending | claimed | done | failed ##
    created_at  => $ntime_b32,
    updated_at  => $ntime_b32,
    description => 'what to do',
    context     => 'optional background / file refs',
    result      => undef,            ## filled on done/failed ##
    agent       => undef,            ## who claimed it [ 'kimi', etc. ] ##
}
```

id is generated from AMOS7 checksum of `"$ntime_b32:$description"` —
use `$code{'chk-sum.amos'} // $code{'base.chk-sum.amos'}` for
swap-boundary safety [ see CLAUDE.md swap-boundary section ].

### commands to implement

#### `task.create`

- param: `description` (required), `context` (optional)
- generates id, sets status=pending, stores in `<task.queue>`
- appends id to `<task.queue.order>` aref [ preserves insertion order ]
- logs at level 1: `:. task created [ %s ]`, id
- returns `{ mode => 'size', data => $id }`

#### `task.list`

- param: `status` filter (optional — default: all)
- returns tasks in insertion order from `<task.queue.order>`
- output: one line per task: `ID STATUS description...`
  truncate description to 60 chars if needed
- returns `{ mode => 'size', data => $formatted_list }`

#### `task.get`

- param: task id (required)
- returns full task record as formatted multiline text:
  ```
  id          : ABCDEFG
  status      : done
  created_at  : 3PRJPU5QOQ
  updated_at  : 3PRJPU6RRR
  description : implement X
  context     : see src/foo.bar
  result      : <kimi output>
  ```
- returns `{ mode => 'size', data => $text }` or error if not found

#### `task.claim`

- param: id, agent (required)
- sets status=claimed, agent=$agent, updated_at=now
- returns error if not in pending state
- returns `{ mode => 'true' }`

#### `task.complete`

- param: id, result (required)
- sets status=done, result=$result, updated_at=now
- returns error if not in claimed state
- returns `{ mode => 'true' }`

#### `task.fail`

- param: id, result (error message, optional)
- sets status=failed, result=$result, updated_at=now
- returns `{ mode => 'true' }`

#### `task.reset`

- param: id
- sets status back to pending, clears agent, updated_at=now
- allows retry after failed or stuck claimed tasks
- returns `{ mode => 'true' }`

### persistence

on each mutation (create/claim/complete/fail/reset), serialize
`<task.queue>` to disk using `JSON::XS` or `Storable::dclone` +
`file.put`. path: `<task.cfg.persist_path>` defaulting to
`/var/protocol-7/task/queue.json`.

on init, load the file if it exists to restore queue across restarts.

### config [ cfg/zenki/task/start ]

```
system.zenka.name = task
modules.load      = auth net protocol

access.cmd.usr.cube = commands heart reload verify-instance \
                      create list get claim complete fail reset

[load_modules:<modules.load>]
[init_modules]
[base.net.connect:'unix']
[get_session_id]
[zenka.loop]
```

---

## Part 2 — kimi auto-pickup

### location

add a polling timer to `src/kimi.init_code` that checks for pending
tasks and auto-submits them.

### polling loop

```
interval : 30 seconds, repeat : TRUE
```

in the timer callback (`kimi.handler.task-poll`):

1. send `task.list` with status filter `pending` via `protocol-7.route-send`
2. if response is empty / no pending tasks → return
3. take the FIRST pending task id from the list
4. send `task.claim` with `agent=kimi`
5. on claim success: fetch full task via `task.get`
6. build prompt from description + context:
   ```
   [task ABCDEFG]
   DESCRIPTION

   CONTEXT
   ```
7. submit to kimi via `kimi.cmd.ask-reply` with a reply handler
8. in reply handler: call `task.complete` with the response text

### guard: only one task in flight at a time

use `<kimi.task.active_id>` flag — set on claim, clear on complete/fail.
skip polling if flag is set.

### on kimi disconnect / restart

if `<kimi.task.active_id>` is set when connection drops, call
`task.reset` on that id so it re-enters the pending queue.

---

## acceptance criteria

- [ ] `p7 task.create "do something"` returns a task id
- [ ] `p7 task.list` shows it as pending
- [ ] kimi zenka picks it up within 30s and claims it automatically
- [ ] kimi zenka submits the prompt and writes result back
- [ ] `p7 task.get ID` shows status=done and contains the response
- [ ] `p7 task.list status=pending` is empty after completion
- [ ] restart of task zenka restores queue from disk
- [ ] if kimi disconnects mid-task, task reverts to pending

---

## related files

- `src/kimi.init_code` — add polling timer here
- `src/kimi.cmd.ask-reply` — existing prompt submission
- `src/kimi.handler.ws_message` — response arrives here via TurnEnd
- `cfg/zenki/kimi/start` — kimi zenka config
- `src/base.ntime.b32` — timestamps
- `bin/Protocol-7` — module loading / code hash structure
- CLAUDE.md — swap-boundary dispatch pattern for amos checksum

## notes

- the `task` zenka follows the standard zenka pattern exactly —
  see `cfg/zenki/calc/start` as a minimal reference
- `kimi.cmd.ask-reply` already supports a reply callback via `reply_id` —
  use that mechanism for the result write-back
- keep the prompt format simple — kimi should receive the task as plain
  text, not wrapped in complex structure
- do NOT implement task dependencies, priorities, or multi-agent routing
  in this pass — those are future extensions

#,,,,

#,,,.,,.,,..,,,,.,,,.,,.,,,.,,.,.,...,,..,,,.,..,,...,...,,,.,,.,,,,,,..,,..,,
#YZB4NDP4M37ZWCRMFBALKJYP562RMEWFHMHI2LVPIWEN7UUSCFXIWSGALGXRBPRZS7WH4FAOO5DGW
#\\\|LGRT4G3NO4RSC2C3E7KD7YYQGQTFAI5UYDE2K37FU72AE3SR32Y \ / AMOS7 \ YOURUM ::
#\[7]YA6XQUQYUDBHZBZTWWDX77RES3Z4TSWERQRNEX6AGC6OL4DIJMDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
