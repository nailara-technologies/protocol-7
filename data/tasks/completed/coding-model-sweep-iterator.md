## [:< ##

# name  = task: async per-backend model-sweep iterator
# descr = checkpointed, user-triggered iterator that drives switch-model +
#         self-test across the model registry, per backend, recording
#         results into the status table from the status-tracking task.

## depends on

`data/tasks/coding-model-status-tracking.md` landing first and being
committed. this task reads and writes through that task's two new
modules (`coding.model_status.record`, `coding.model_status.cmd.
model-status`) -- do not start this dispatch until those exist in the
tree, and mirror their actual committed shape, not this document's
description of them, if the two disagree.

## scope

read ONLY the "part 2 -- async sweep iterator" section of
`data/md/design/MODEL-STATUS-TRACKING.md` (from "once the status table
exists..." to the end of that file). "part 1" is the dependency above,
already built -- do not re-read it as scope, do not modify anything from
that task's file list except where explicitly named below.

## what this actually is, concretely (resolving the design doc's framing)

the design doc frames this as "drives self-test cycles" -- the natural,
lowest-risk way to do that is NOT to reinvent spawn+test orchestration.
`src/coding.cmd.switch-model` already does exactly "switch to model X on
backend Y, respawn, run a post-switch self-test" as a single command
(`src/coding.self_test.handler.poll_switch` is its timer-driven state
machine, ending in a terminal phase once the post-switch self-test in its
`testing` phase completes). **this task is an orchestration loop that
calls `switch-model` once per candidate, waits for that switch's
`poll_switch` cycle to reach a terminal phase, then advances to the next
candidate** -- not a second self-test driver. this also means task 1's
write sites (already wired into `poll_probe`'s `done` phase) fire
automatically on every sweep step with zero new code needed to record
results -- the sweep loop's only job is picking the next candidate and
waiting.

read `src/coding.self_test.handler.poll_switch` in full before starting
-- it is both the state-machine shape to mirror for the new per-backend
sweep cursor AND the actual mechanism each sweep step waits on.

## the 4 states, filter modes (already decided, do not re-derive)

```
default            untested only [ no (checksum,backend) entry in
                    coding.model_status ]
:re-test-failed:    also include startup-failure / inference-failures /
                    resource-insufficient
:re-test-success:   also include functional
```

modes combine (`:re-test-failed: :re-test-success:` == full sweep,
ignoring current status). **single-colon `:keyword:` convention** --
confirmed real, consistently used elsewhere (`:load:` in
`src/keys.select_archive_path`, `:sigs:` in `src/keys.console.list`,
`:any:` in `src/protocol.sftp.connect_callback`, `:stage:` in
`src/sourcecode.console.update-signatures`), **not** `--flag`
unix-style, which does not belong in a p7c command context.

parsing must handle TWO tokens combining in one `$params->{'args'}`
string plus a backend name in the same string -- `keys.console.list`'s
whole-string-equality style (`$param eq qw| :sigs: |`) only fits a
single standalone token and does not apply here. instead mirror
`src/sourcecode.console.update-signatures:17`'s substitutive-extraction
style: `my $stage_files = $command_params =~ s| *:stage: *| |;` --
extract `:re-test-failed:` and `:re-test-success:` from the args string
via the same `s| *:keyword: *| |` substitution (each sets a boolean,
independent of order or presence of the other), and whatever remains in
the string after both substitutions is the optional backend argument
(`gpu`/`cpu`/`both`, trimmed).

## candidate list + pre-filter (per backend, independent cursors)

iterate `<coding.model_metadata>` (same registry `spawn_smart` already
reads from -- NOT `models.registry.*`, do not touch that unrelated
family). for each entry (skip anything matching `/mmproj/i`, same skip
`spawn_smart` already applies at its own line 53):

- resolve current status via task 1's `coding.model_status` read path
  (read the in-memory hash directly, `<coding.model_status>->{$amos}
  {$backend}`, same fallback-to-disk shape as `coding.model_status.
  cmd.model-status` if it's not yet loaded this session) and apply the
  filter mode.
- pre-filter by fit: `$entry->{'size_gb'}` against free VRAM (gpu) / free
  RAM (cpu). **this exact math already exists, duplicated, inside
  `spawn_smart` at lines 176-232** (nvidia-smi query for gpu, `/proc/
  meminfo` MemAvailable for cpu, `+512MB`/`+1024MB` overhead). extract it
  into a new shared helper first -- `src/coding.helper.check_resource_fit`,
  params `{ backend, size_gb }`, returns `{ fits => TRUE|FALSE, free_mb
  => N, required_mb => N }` -- then call it from BOTH `spawn_smart` (
  replacing its inline duplicate) and this sweep's pre-filter. do not
  leave two independently-maintained copies of the same threshold math;
  this is a genuine shared-logic extraction, not scope creep -- do it as
  the first step of this task, before the sweep code itself.
- a model failing the fit check is simply excluded from this backend's
  candidate list for this run -- it is NOT written to `coding.model_status`
  as `resource-insufficient` here (that write only happens for a REAL
  spawn attempt inside `spawn_smart` itself, per task 1). this pre-filter
  is purely "don't bother attempting," not a status verdict.

build gpu's candidate list and cpu's candidate list independently -- they
may be completely disjoint. no cross-backend coordination needed (no
shared list to double-claim from).

## persisted, resumable cursor (checkpointed, per backend)

new store, same load-merge-write pattern as `coding.self_test.archive` /
task 1's `coding.model_status.record` (mirror task 1's own committed
`coding.model_status.record` file directly for the persistence shape --
you are applying an already-approved pattern to a second use case, not
inventing a new one):

- file: `state/model_sweep_cursor.yaml`, one entry per backend:
  ```yaml
  gpu:
    filter: "re-test-failed"     # or "default" / "full"
    candidates: [ checksum1, checksum2, ... ]   # frozen at sweep start
    idx: 3
    started: <ntime>
  cpu:
    ...
  ```
- `candidates` is frozen at sweep-start time (computed once from the
  pre-filter + status-filter above), not recomputed each tick -- a
  registry change mid-sweep doesn't retroactively alter an in-progress
  run's list, matching `poll_switch`'s own "state captured at start,
  walked to completion" shape.
- on zenka restart mid-sweep: if a cursor file exists with `idx <
  scalar @candidates`, the sweep is resumable from `idx` -- do not
  silently drop it, but also do not auto-resume it (see "user-triggered
  only" below) -- surface it via the status command instead.

## the loop itself

new module `src/coding.model_sweep.handler.poll_sweep`, timer-driven,
mirror `poll_switch`'s overall shape (state on the watcher via
`$event->w->data`, re-scheduled via `event.add_timer` until terminal):

- each tick: if the current candidate's switch-model + self-test cycle
  (tracked via the same `switch_id`/`poll_switch` state
  `coding.cmd.switch-model` already creates) has reached a terminal
  phase, advance `idx`, persist the cursor, and if more candidates remain
  issue the next `switch-model` call for `(candidates[idx], backend)`;
  otherwise just reschedule and keep waiting on the current one.
- when `idx` reaches the end of `candidates`: mark this backend's sweep
  done (clear or archive its cursor entry), log a one-line summary
  (counts per resulting status, read back from `coding.model_status`
  after the sweep completes -- don't accumulate counts separately, the
  status table is already the source of truth).
- this needs task JEG's fix (`src/coding.handler.spawn_smart`'s
  self-test-cancellation-before-force-kill block, already landed --
  confirmed present at `spawn_smart` lines 77-127 as of this writing) --
  it's what keeps a tight switch-model loop like this one from leaving a
  zombie self-test guard between every candidate. don't re-verify or
  re-implement it, just confirm (read the block) that it's there before
  building on top of it.

## commands (2, both user-triggered, both new `.cmd.` files)

1. `src/coding.model_sweep.cmd.model-sweep` -- starts a sweep.
   params: `backend` (`gpu`|`cpu`|`both`, default `both`) and the
   `:re-test-failed:`/`:re-test-success:` filter tokens (parsed from
   `$params->{'args'}`, same whole-string-token style as the precedents
   above). refuses to start (returns an error reply, doesn't clobber) if
   a sweep is already in progress for a requested backend -- check the
   cursor file / in-memory state first.
2. `src/coding.model_sweep.cmd.model-sweep-status` -- reports, per
   backend: idle / in-progress (`idx`/total, current candidate) /
   resumable-but-not-running (a cursor exists with `idx < total` but no
   active timer). mirror `coding.self_test.cmd.self-test-status`'s
   reply shape (read it for the pattern).

registration: same 2-step mechanical process as task 1 -- add
`model-sweep` and `model-sweep-status` to `cfg/zenki/coding/zenka.v7`'s
`keywords =` list, then regenerate `cfg/zenki/coding/subroutines.
load-early` via `bin/dev/gen-sub-whitelist coding` (do not hand-edit
that file).

## deliberately user-triggered, not automatic (already decided, do not relitigate)

no timer fires this on its own, no registry-change hook auto-starts it.
two independent reasons from the design doc: cost (repeated multi-
gigabyte model loads/cycles is real time+I/O, shouldn't run unsupervised
until its safety/cost profile is known from manual runs), and
`:re-test-success:` specifically exists as a deliberate "I changed
something upstream of every model (binary recompile, driver update,
threading config), go recheck" user action -- it has no meaningful
automatic trigger condition, the status table has no way to know that
kind of change happened on its own.

## explicitly out of scope

- anything from task 1's file list except the 3 named exceptions above
  (`spawn_smart`'s VRAM/RAM check extraction, and the 2 new `keywords =`
  entries in `zenka.v7`, and running `gen-sub-whitelist`) -- do not
  re-touch `coding.model_status.record`, `poll_probe`, or
  `verify_inference_startup`.
- `llm.service.consensus_vote` -- a future consumer of `coding.
  model_status` once this and task 1 both exist, not part of either task.
- `models.registry.*` -- unrelated module family, do not touch.
- no live network/filesystem execution, no starting a zenka, no actually
  running a sweep -- this task is design-complete code, verified
  execution-free (see below), left for the user to run live.

## validation (execution-free)

- `bin/dev/ptd -c` on every changed/new file.
- trace the resource-fit extraction by hand: confirm `spawn_smart`'s two
  call sites (gpu/cpu) produce IDENTICAL free_mb/required_mb numbers
  through the new helper as they did inline before the extraction --
  this is a pure refactor at that call site, behavior must not change.
- trace one full hypothetical sweep by hand for a 3-candidate gpu list
  with `idx` starting at 0: state what happens on tick 1 (issues
  switch-model for candidate 0), what a terminal `poll_switch` phase
  looks like for you to detect, and what the cursor file contains after
  candidate 0 finishes and before candidate 1 starts.
- confirm `bin/dev/gen-sub-whitelist coding` picks up the 2 new `.cmd.`
  modules.
- do NOT start a zenka or run `p7c coding.model-sweep` live -- for the
  user to do after review.

#,,,.,,.,,.,,,..,,.,,,...,...,,,,,...,,,.,,,,,..,,...,...,.,.,.,.,,,.,...,..,,
#AUZI6U7NHZUZRM6MFGA2GOFSF76CNEFM67GMEVYTZFZYICQNRLNWTPBSGVKPZUAK27B4DQATGRNNI
#\\\|A73Y27X4TZ4OOBYTELWQRXDD2HFJ23VS26352TN62RDEMFY654Y \ / AMOS7 \ YOURUM ::
#\[7]ZAKQ3BSSVUOJOALPLEP5RAI7LXUVVRW4RDEOV7KNVCHEAMJ5TWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
