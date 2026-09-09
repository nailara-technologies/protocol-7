## [:< ##

# name  = task: verify the catalog-retrieval harvester live
# descr = confirm coding.catalog.* actually works against a real queue
# param = small, bounded -- good fit for a short session window

## context

follow-on from `data/tasks/coding-catalog-retrieval-phase2.md`, whose
closing state was: three corpus-enrichment strategies failed on
historical-commit data, the real fix is harvesting genuine
`task_summary` + touched-module pairs from live `coding.submit` traffic,
and that harvester (`src/coding.catalog.track_write`,
`src/coding.catalog.corpus.record`, wired into the three write-tool
handlers plus `coding.task.queue_complete`) is already built, committed
(`e1b1292f4`), and off by default (`coding.cfg.catalog_harvest`
commented out in `cfg/zenki/coding/zenka.v7`).

**it has never run against a real task.** both the building agent and
this task file say the same thing: task-id resolution (the in-progress
queue scan in `track_write`) and the append path (`corpus.record`'s
JSONL write) are verified by direct code inspection only -- reasoning
about the code, not watching it run. the idiom-gate task's own
production-integration bugs (a permission-denied corpus dir, a shared
pretty-printing JSON encoder breaking the one-line-per-record contract)
were BOTH the kind of thing that only surfaces by actually running it
live -- don't assume this harvester is different just because it was
written carefully.

## confirmed mechanism [ read directly from the two modules ]

- `coding.catalog.track_write` : called from the three write-tool
  handlers [ `edit_file`, `replace_in_file`, `write_new_file` ] with
  `{ target => <path> }`. resolves the module name from the path,
  confirms it's a real file under `src/`, finds the currently
  `in_progress` task by scanning `<coding.task.queue>` [ same pattern
  `record_observation` already uses, since a tool handler isn't handed
  a task id directly ], and accumulates touched module names in
  `<coding.catalog.touched>->{$task_id}`. no-ops entirely if
  `coding.cfg.catalog_harvest` is unset -- confirmed via `base.cfg_bool`
  check at the top of the module.
- `coding.catalog.corpus.record` : called from
  `coding.task.queue_complete`. pulls the accumulated touched-set for
  the completed task id, pairs it with `task_summary` [ truncated to
  200 chars, matching `coding.prompt.assemble`'s own template-var bound
  deliberately, so the harvested text matches what an auto-inject
  provider would actually query with ], and appends one JSONL line
  `{ ts, task_id, task_summary, modules, n }` to
  `data/catalog-corpus/YYYY-MM.jsonl`. same no-op-if-disabled guard.
- `data/catalog-corpus/` is gitignored [ real task text, unlike the
  idiom corpus which stores only a prompt checksum ] and deliberately
  NOT pre-created on disk -- letting the zenka create it on first write
  gives correct `protocol-7`-user ownership by construction, avoiding
  the exact permission bug the idiom-gate task hit by hand-creating
  `data/idioms/corpus/` as a different user first.

## hazards

1. **this changes live coding-zenka behavior the moment it's enabled**
   -- every file write during every task will now scan the task queue
   and append to a JSONL file. low cost per the code, but confirm there
   is no visible latency/behavior change to normal task execution before
   leaving it on.
2. **don't leave it enabled by accident if verification fails.** if
   task-id resolution is wrong [ e.g. multiple in-progress tasks
   confusing the scan, or the scan finding nothing when a write happens
   from an unexpected code path ], revert `coding.cfg.catalog_harvest`
   to commented-out and say so plainly in results -- a harvester that
   silently mis-attributes touched modules to the wrong task is worse
   than no harvester, since bad records look identical to good ones
   downstream.
3. **git commands on this host need `-c color.ui=false`** -- found this
   session debugging the phase-2 leakage probe : this repo sets
   `color.ui = always`, so git emits ANSI escapes even into a pipe,
   breaking naive line-start regex anchors. irrelevant to this specific
   task [ no git scripting involved ] but worth carrying forward as a
   standing hazard for anything that touches git output programmatically
   on this host.

## scope

1. enable `coding.cfg.catalog_harvest` [ runtime `coding.set`, or
   uncomment in `zenka.v7` + reload -- your call, but if you use the
   runtime-only route, confirm it's reverted or made durable before
   finishing, don't leave the running zenka and the committed config
   disagreeing silently ].
2. submit 3-5 real small tasks via `coding.submit` that involve actual
   file writes [ e.g. trivial, safe edits to a scratch or already-
   understood module ], enough to exercise `edit_file`/`write_new_file`/
   `replace_in_file` at least once each if practical.
3. confirm, for each: `data/catalog-corpus/<YYYY-MM>.jsonl` gets
   created [ first write ] with correct ownership, one JSONL line per
   completed task, valid JSON, `modules` matching what was actually
   written, `task_summary` correctly truncated and non-empty.
4. spot-check task-id resolution specifically under the one condition
   most likely to break it : two tasks in flight at once, if that's
   easy to arrange -- confirm each write gets attributed to the right
   task, not cross-contaminated.
5. decide, based on what's found : leave enabled (config-gated on,
   durably) or revert to disabled -- either is a valid outcome, say
   which and why.
6. append results to this task file. no AMOS7 signature stubs on any
   new file.

#,,..,.,,,,,,,,,,,,..,.,.,,.,,.,,,.,.,,,.,,.,,..,,...,..,,.,,,,.,,,,.,.,,,...,
#GVXJ4OCAWEXWVIGMSS7PQDBM52GJICGLN7OWGVVA5SHKAE6374IIOCURXQ7UE74SYBCQHIYGC5S4G
#\\\|QBGD2TNGHD56LDWKJXY5NKP2DTQW2GVOL5SUGM2DA7SXG52NDOM \ / AMOS7 \ YOURUM ::
#\[7]DETWPLJRKNZ4G3COIFVYAEQQHLWLY2BTJJXBYQQUQJCDELUGL6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
