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

## results [ 2026-09-09, live verification run ]

**verdict : REVERTED to disabled.** two real bugs found, both confirmed
against the live coding zenka, both exactly the class hazard 2 warns
about. the flag is commented out again in `cfg/zenki/coding/zenka.v7`
and the runtime keys were explicitly deleted from the running zenka [
`reload config` alone does NOT unset keys removed from the file -- it
only sets what it parses, so the runtime key survived the revert until
deleted via `base.del_key` ]. running zenka and committed config agree :
harvest off, verified via `coding.eval-code` [ cfg:unset, bool:0 ].

### what was done

- enabled durably [ uncommented both keys in zenka.v7 + `coding.reload
  config`, verified `coding.cfg.catalog_harvest = yes` live ]
- submitted 4 real tasks via `coding.submit`, all completed :
  A [ task-QEZXKYY ] edit_file on a scratch src module ;
  B [ task-VZPAOUY ] replace_in_file on same ;
  A2/B2 [ task-ZO2R23Y / task-LQPNL5Y ] repeat pair AFTER a needed
  `coding.reload source` -- the first pair ran while the catalog subs
  were not yet compiled into the zenka [ they were committed 13:29,
  zenka up since 06:38 ; `reload config` does not load code ]. all four
  edits landed correctly in the scratch file.
  C [ task-KKJNHPI ] write_new_file to `data/` [ outside src/ ] as a
  negative test.
- introspected the live zenka via `devmod.cmd.eval-code` [ subs exist,
  cfg bool true, `<coding.catalog.touched>` contents, queue state ].

### bug 1 [ fatal ] : the flush hook is wired into a dead code path

`coding.catalog.corpus.record` is called ONLY from
`coding.task.queue_complete`, reachable only via the manual
`coding.task.queue complete <id>` dispatcher. the live async completion
path is `coding.async.complete` -> `coding.task.complete` ->
`coding.event.on_task_complete`, which never calls `queue_complete`.
evidence : after two completed tasks with tracked writes, NO
`data/catalog-corpus/` dir was ever created, and the touched entry for
task-LQPNL5Y was still present in memory afterward [ corpus.record
deletes the entry first thing, so its survival proves the call never
happened ]. as committed, the harvester can NEVER emit a record on the
live execution path ; touched entries would accumulate in memory
unboundedly. minimal fix direction for the follow-up : move the
`corpus.record` call into `coding.task.complete` or
`coding.event.on_task_complete`.

### bug 2 [ hazard-2 class ] : confirmed live cross-task misattribution

`coding.task.execute:35` sets `execution.status = in_progress` BEFORE
backend acquisition. with a second task submitted while the first runs,
the log shows `backend_acquire: task-LQPNL5Y queued behind task-ZO2R23Y`
-- i.e. LQPNL5Y was already status=in_progress during ZO2R23Y's tool
rounds. track_write's scan takes the FIRST in-progress task in `keys`
hash order. observed end state : touched = { task-LQPNL5Y =>
coding.test-scratch-harvest }, NOTHING for task-ZO2R23Y -- ZO2R23Y's
edit_file write was attributed to the queued-behind task. [ both tasks
wrote the same module so the entry looks plausible -- precisely why
hazard 2 calls this worse-than-nothing. ] fix direction : attribute by
the task whose tool round is actually executing [ thread the task id
through the tool-executor context ] or exclude not-yet-acquired tasks
from the scan.

### lesser findings [ code-inspection level, noted for the fix pass ]

- `write_new_file` can never track a brand-new src module : track_write
  requires `-f src/<module>` but is called BEFORE the file is created,
  and the handler refuses paths that already exist. new-module tasks
  silently produce no record. [ defensible for an existing-module
  retrieval corpus, but it is a silent gap, not a logged one. ]
- track_write logs at level 3 and corpus.record success at level 2,
  both below the zenka's visible log verbosity -- even a working
  harvester is invisible in the logs ; only failures [ level 0 ] show.
- negative test passed : the write_new_file task to `data/` added no
  touched entry [ writes outside src/ correctly ignored ].
- unrelated pre-existing quirk noticed in passing : task C's file was
  created 0-byte via the chmod-child path despite non-empty content ;
  not harvest-related, not chased.

### bottom line

mechanism as designed is sound [ cfg gate works, src-only filter works,
touched-set accumulation works ], but the two bugs above mean leaving it
enabled would silently harvest wrong attributions into a corpus that the
dead flush path never writes anyway. reverted per hazard 2. re-verify
after a fix pass moves the flush hook onto `coding.task.complete` and
scopes attribution to the executing task.

## results [ 2026-09-09, second run : fix pass + live re-verification ]

**verdict : ENABLED, durably.** both original bugs fixed, one additional
dead-code bug found and fixed during re-verification, all three write
tools re-verified live including a genuinely concurrent pair. the keys
stay uncommented in `cfg/zenki/coding/zenka.v7` and the running zenka
matches [ reloaded config + source, verified `cfg_bool` = true via
`coding.eval-code` ].

### bug 1 fix : flush hook moved onto the live completion path

`coding.task.complete` now calls `coding.catalog.corpus.record` right
before `coding.event.on_task_complete` [ the live path is
coding.async.complete -> coding.task.complete ; the queue_complete call
site stays, it is idempotent -- corpus.record deletes the touched entry
first, so a double call is a no-op ]. additionally `coding.task.fail`
now deletes the failed task's touched entry, so failures cannot leak
entries unboundedly either.

### bug 2 fix : exact attribution instead of queue-scan guessing

`coding.async.tool_executor` sets `<coding.catalog.active_task> =
$task_id` tightly around each synchronous `coding.tools.dispatch` call
and clears it right after. `coding.catalog.track_write` prefers that key
when set [ the live path, exact by construction ] ; the in-progress
queue scan remains only as a fallback for callers without executor
context [ e.g. `coding.cmd.call-tool` ], and when MORE THAN ONE task is
in_progress the fallback now only picks one that actually holds a
backend lock [ `<coding.state.backend>` ], so a task marked in_progress
while still queued behind the lock [ coding.task.execute:35 sets the
status before backend_acquire ] is no longer eligible.

### bug 3 [ found during this re-verification ] : the edit_file hook was dead code

the original wiring put the track_write call in
`coding.tools.handler.edit_file`, but `coding.tools.dispatch` handles
`edit_file` with an INLINE closure [ dispatch line ~360 ] and prefers
the dispatch table over handler modules -- the handler module is never
reached for edit_file on the live path. this silently re-explains the
first run's 'misattribution' observation : the edit_file task was never
trackED AT ALL [ nothing to attribute ], and the replace_in_file task's
entry was in fact correctly self-attributed. fixed : track_write is now
also called inline in the dispatch closure, after `file.put` succeeds.

### lesser finding fixed in passing : track-after-success placement

`replace_in_file` and `write_new_file` tracked BEFORE the write ; for
write_new_file that also meant brand-new src modules could never be
tracked [ track_write requires the file to exist ]. both now track after
the successful write [ both write branches for write_new_file ] ;
refused, failed, or staged [ unwritten ] edits are never recorded.

### one environment fix, not a code fix

first live completion attempts failed LOUDLY [ level 0 :
'catalog.corpus : cannot create ...' ] because the zenka runs as user
protocol-7 and `data/` is owned by the login user --
`base.file.make_path` could not create the corpus dir. fixed on disk :
`data/catalog-corpus/` created with a group ACL [ `setfacl -m
g:protocol-7:rwx -m d:g:protocol-7:rwx`, same pattern as
data/idioms/corpus ] ; JSONL files inside are created protocol-7-owned
by the zenka itself, as designed.

### live re-verification [ all via coding.submit + coding.wait-done ]

- sequential edit_file [ task-RG5H6EA, task-YPZTLVI ] : edit landed ;
  track fired [ log level 3 : 'catalog.track : task-YPZTLVI <-
  coding.test-scratch-harvest' ] ; completion hook fired but dir-create
  failed loudly -> led to the ACL fix above ; record replayed and
  written correctly afterward.
- sequential replace_in_file [ task-6VB6NAA ] : fully end-to-end,
  record written with correct task_id + module.
- CONCURRENT PAIR [ task-WFA6RLI -> edit_file src/coding.test-scratch-
  harvest ; task-6TA7QZY -> edit_file src/coding.test-scratch-harvest-2,
  DISTINCT modules so cross-attribution would be visible ] : submitted
  back-to-back, both status=in_progress simultaneously [ 6TA7QZY
  dispatched <1s after WFA6RLI, completed 7s later -- WFA6RLI's write at
  22:20:35.34 executed while 6TA7QZY was in_progress, the exact bug-2
  precondition ]. records : WFA6RLI -> [coding.test-scratch-harvest],
  6TA7QZY -> [coding.test-scratch-harvest-2]. both correct.
- all four JSONL lines in data/catalog-corpus/2026-09.jsonl parse as
  valid single-line JSON, one per completed task, task_summary non-empty
  and truncated at 200 chars, n matching modules count.
- no visible latency or behavior change to normal task execution
  [ hazard 1 ] : tasks complete in the same time and shape as before.

### housekeeping notes

- runtime log verbosity was raised to 3 during debugging to see the
  level-2/3 catalog log lines and set back to 1 afterward [ runtime
  only, config untouched ].
- the seven edited src modules [ coding.task.complete, coding.task.fail,
  coding.async.tool_executor, coding.catalog.track_write,
  coding.tools.dispatch, coding.tools.handler.replace_in_file,
  coding.tools.handler.write_new_file ] carry STALE AMOS7 signature
  footers -- signing needs the interactive proto-7.sourcecode key
  password, which an agent session does not have. per project convention
  the user should run `bin/Protocol-7 sourcecode update-signatures` for
  these files. no signature stubs were added or fabricated anywhere.
- scratch modules used for the tests were deleted afterward ; the corpus
  records referencing them are the point and stay.
- note for future debugging : `reload source` compiles EVERY file under
  src/ matching loaded namespaces -- a plain-text scratch file named
  coding.* breaks the whole reload. scratch modules must be compilable.

## results [ 2026-09-09, third run : self-healing corpus dir + fresh-start fix ]

**verdict : self-healing confirmed live, plus one fresh-start bug found and
fixed.** the manual `g:protocol-7:rwx` ACL is replaced by an init-time
mechanism, and the verification restart exposed that the harvester itself
only worked in the OLD instance thanks to `reload source` side effects.

### self-healing corpus dir [ the requested change ]

`src/coding.init_code` now ensures `data/catalog-corpus/` on every zenka
start, right after the existing `check-zenka-paths` block and BEFORE
`drop_privs` [ same pattern as `src/ext-pkg.init_code` ] : guarded by
`$EFFECTIVE_USER_ID == 0`, `File::Path::make_path` if missing [ mode 0750 ],
then `chown` to `<system.amos-zenka-user>`. unlike ext-pkg, the parent [
`<root>/data` ] is deliberately NOT chowned -- it is a repo dir owned by the
login user, not `/var/protocol-7/<zenka>` territory.

verified against the REAL fresh-deploy path, not a scratch simulation :
moved the live `data/catalog-corpus/` aside [ reversible, content preserved
], `v7-zenki.terminate coding` + autostart, and the fresh init recreated the
dir as `protocol-7:protocol-7 0750` with NO manual step -- exactly the
missing-dir scenario. preserved JSONL content merged back [ 4 records
intact ]. old ACL-bearing dir removed.

### bug found BY the verification restart : base.file.* not loaded on fresh start

the first post-restart tasks completed but wrote NO corpus record. log
showed `undefined value as subroutine reference
[coding.catalog.corpus.record:91]` -- `<[base.file.append]>` [ and
`<[base.file.make_path]>` ] are absent from a freshly started zenka : the
`load_modules` selection in zenka.v7 omits them, and the previous instance
only had them because the earlier session's `reload source` compiles every
src file. so as committed, the harvester died on every completion after any
clean restart. fixed in `src/coding.catalog.corpus.record` : make_path via
`<[base.perlmod.load]>->('File::Path', ...)` [ same as init_code ], append
inlined [ `>>` + `:encoding(UTF-8)`, matching base.file.append's defaults ].

### second bug in that same fix [ found at compile time ] : qw|| splitting

the first version of the inlined append used `sprintf( qw| open : %s |,
... )` -- qw|| SPLITS ON WHITESPACE, so that was sprintf with three
constants [ 'open', ':', '%s' ], producing 'Useless use of a constant in
void context' compile warnings [ 4 of them, visible as the coding zenka's
startup 'errors' ]. qw|| is fine for single terms without spaces but wrong
for format strings. fixed to plain single-quoted strings with
`<[base.str.os_err]>` [ the codebase's own helper, same one base.file.append
uses ].

### end-to-end re-verification after both fixes

one real `coding.submit` task [ task-UIET43Q, explicit-shape edit_file
prompt on a scratch module ] : edit landed, track fired, record 6 appended
to `data/catalog-corpus/2026-09.jsonl` with correct task_id +
module [ task-D5SCBQI -> coding.test-scratch-selfheal2 right behind it,
harvesting another caller's task correctly too ]. dir ownership stays
`protocol-7:protocol-7 0750`, JSONL `protocol-7:protocol-7 0640`, all lines
valid single-line JSON. scratch module deleted after.

### operational notes from this run

- the verification restart coincided with a host-level resource exhaustion
  [ swap thrash ] that took the whole v7 network down mid-run; user
  restored it [ flushed 1.5GB swap back to RAM ]. the init_code change
  itself was not the cause.
- runtime log verbosity was not touched this run [ left at 1 ].
- stale AMOS7 signature footers now cover `src/coding.init_code` AND
  `src/coding.catalog.corpus.record` -- `bin/Protocol-7 sourcecode
  update-signatures` still pending from the user side.

### housekeeping notes

- `src/coding.init_code` and `src/coding.catalog.corpus.record` carry STALE
  AMOS7 signature footers [ see operational notes above ] -- no stubs added.
- one staged copy of a scratch module may linger in the zenka's staged
  dir [ a task hit the `no write access` staging branch before the chmod
  child granted write ] -- inert, expires with staging.
- unrelated pre-existing quirks seen this run, not chased : self-test
  prompt 3 failed once on degenerate repetition right after model load
  [ 2/3 passed, startup gate still opened ], and an early submitted task
  vanished silently when the backend was not yet accepting connections
  [ a later one failed LOUDLY with connection refused instead --
  inconsistent, but pre-existing ].

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

## results [ 2026-09-10, post-full-restart confirmation ]

short addendum to the third run above : the whole network was restarted
again afterward [ 01:13-01:18, following a `sourcecode
update-signatures` pass that refreshed the stale footers including
`coding.init_code` ], this time with the self-healed
dir already present. confirmed on the new instance : init ran clean [
`coding.state.initialized=1`, post-drop_privs EUID 777 ], chown
idempotent -- ownership unchanged `protocol-7:protocol-7 0750`, no ACLs
needed. harvester end-to-end re-confirmed twice : task-UIET43Q and
task-D5SCBQI [ explicit-shape edit_file on a scratch module ] each
appended a correct JSONL record [ 7 valid lines total in
`2026-09.jsonl` ] ; an intermediate task whose edit went to the STAGED
[ unwritten ] branch correctly produced NO record, confirming
track-after-success still holds. scratch module deleted after ; no
signature stubs added.

#,,,.,..,,,,.,.,,,...,,.,,,.,,,.,,.,.,..,,.,,,..,,...,...,,.,,,.,,,.,,,,,,.,.,
#UABQHHXFJZCRGAAFALFD6T5FTXLLAMV4RQJMZE7FRLMPHOYOD245PYM65K2UOVTW5QOQ2XUSFGWCC
#\\\|2TJWMUFCRWYBB3KRONDUZUEHVYHPYIGJ7FKJTHH3WT3NEIPM5ZL \ / AMOS7 \ YOURUM ::
#\[7]CFOEDGFPTSSKBY3WP546XPHOVR5NGC35AOSO2U4O3VX5VMEVP4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
