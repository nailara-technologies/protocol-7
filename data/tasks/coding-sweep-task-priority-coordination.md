## [:< ##

# name  = task: model-sweep yields to real task inference
# descr = nothing today stops a model-sweep [ or any switch-model call ]
#         from killing a real, in-flight task's inference server out from
#         under it. this task makes real task activity win by default,
#         reusing an existing idle-wait precedent rather than inventing
#         one, plus an explicit opt-out for a deliberately uninterrupted
#         test run.

## why now

scoped immediately after landing the model-sweep state machine
(`coding-test-iteration-state-machine.md`, commit `bc81c9d82`) and
using it live -- surfaced a separate, more fundamental gap in the same
session: nothing in `coding.spawn_inference_server`'s kill-old-process
logic checks whether a real task request is in flight before killing
the process group, and `coding.task.ensure_model_pinned` (the
mechanism a queued task uses to auto-load its own required model --
checksum comes from the task's own params, e.g. jobsite's
`:model:<checksum>:` prompt token from `jobsite.util.build_prompt:47`,
sourced from the live-configurable `jobsite.cfg.assessment_model`)
fires `switch-model` with zero awareness of an active sweep.

**this is not new infrastructure to invent** -- `coding.handler.
vision_switch_poll` already solves this for its own narrower case (a
vision-model `:switch:` waiting for the task queue to go idle before
switching), with a working `waiting_idle -> switching` two-phase timer
and a proven idle predicate mirrored from `coding.handler.
drain_check`: zero active (non-completed, non-failed) tasks in
`<coding.task.queue>`, and no backend lock held anywhere in
`<coding.state.backend>` (`vision_switch_poll:69-80`; note this
predicate is **global**, not per-backend -- it loops both `gpu` and
`cpu` and counts the whole task queue unfiltered, same as
`drain_check`).

**this doc went through one implementation-focused Opus review already
and was substantially restructured as a result** -- the first draft's
scope #3 (auto-`model-sweep-pause` the sweep, then fire the task's
switch) was actually broken, not just imprecise: `model-sweep-pause`
is asynchronous (only honored once the *current* candidate's cycle
naturally terminates, which can be minutes), so "pause then switch"
still raced exactly the collision this task exists to prevent. Worse,
the review found the natural-seeming "just let the task's pin wait"
fallback doesn't work either: `ensure_model_pinned` is the *only* fire
site anywhere in the tree for loading a pinned model, and skipping the
switch call with no re-fire mechanism means the task's dependency
object never resolves -- it parks in `depending` status
(`coding.task.execute:91-107`) **permanently**. What's below reflects
the corrected design, not the original.

## scope

### 1. `yielding` -- sweep-axis, in-memory only, the single yield mechanism

before `poll_sweep`'s `$start_candidate` fires (the same `idle`-phase
gate the pause-request check already occupies, and which must run
**after** that check -- pause always wins over yield, see "ordering"
below), check the SAME global idle predicate `vision_switch_poll` uses.
extract it first into a shared helper, `coding.helper.backend_idle`
(zero new logic, a straight lift of `vision_switch_poll:69-80` /
`drain_check`'s existing body) -- this task adds two real callers
beyond `vision_switch_poll` itself (this scope, and scope #3's drain
check), which is exactly the point past which duplicating it stops
being justified. `vision_switch_poll` switches to calling the helper
too (one line), so there is exactly one idle predicate in the tree, not
two that can drift.

if not idle: set `<coding.model_sweep_state>->{$backend}{'yielding'} =
TRUE` (an in-memory flag on the EXISTING in-memory sweep-state hash --
**never written to the persisted cursor file**, same derived-vs-
persisted discipline the prior task already established for
`crash-looping`). skip `$persist_cursor` entirely for this tick -- the
cursor already ticks at 1s intervals (`cmd.model-sweep`'s timer
interval), and a long yield must not rewrite the YAML file once a
second for nothing. clear the flag and proceed to `$start_candidate`
the moment the predicate goes idle again -- no operator action, no
resume command, self-clearing by construction.

**bounded, matching `vision_switch_poll`'s own bound (300s) for
consistency**: if `yielding` has been continuously true past that
window, this is no longer "let real work finish," it's "the queue
never goes idle" -- transition to a REAL, persisted `paused` (cursor
written, timer cancelled, `paused_reason = 'yield-timeout'`), through
the exact same pause mechanics `model-sweep-pause`/circuit-breaker
pauses already use. resuming a `yield-timeout` pause still requires
`:force:` under the existing (unnarrowed) resume gate -- deliberate:
indefinite starvation is worth an explicit acknowledgement before
blindly resuming into the same contention, same reasoning as a breaker
trip, no special-casing of the resume gate needed for this case.

**ordering, stated explicitly so it isn't re-derived at implementation
time**:
- the existing pause-request check (`poll_sweep`'s current `idle`-
  branch gate) runs FIRST and is terminal -- a pause arriving while
  `yielding` is honored on the very next tick, never starved by an
  ongoing yield.
- the circuit breaker and `yielding` are structurally mutually
  exclusive, not just unlikely to collide: the breaker trips inside
  the `waiting`-phase advance (`poll_sweep`'s `!defined $switch_state`
  branch) and cancels the timer before any `idle`-branch code -- where
  `yielding` is checked -- can run on that cycle.
- `yielding` must never overwrite `$state->{'state'}` when it's
  already `paused` or `pause-requested`.

`model-sweep-status` reports `yielding` on the sweep axis (a fourth
observable value alongside `idle`/`running`/`pause-requested`/
`paused`), with the same log style `vision_switch_poll` already uses
for its own progress line (`waiting for idle : %d active task(s), %d
in flight`).

### 2. `:no_yield:` -- explicit, opt-in, uninterrupted run

new single-colon token, same substitutive-extraction parsing as the
existing `:re-test-failed:`/`:re-test-success:`/`:force:` (order-
independent, no substring overlap with any of them, confirmed safe).
**named `:no_yield:`, not `:lock:`** -- `lock` collides directly with
`<coding.state.backend>->{$backend}{'lock'}`, the very field the idle
predicate this task adds reads; a same-named-but-unrelated key one
call away from the real lock is exactly the kind of confusion worth
avoiding at naming time, not after a bug report.

accepted by `coding.model-sweep` and `model-sweep-resume`. when set,
scope #1's idle check is skipped entirely for this run -- `yielding`
never triggers, the sweep proceeds through its candidates regardless
of task activity. lives as a new field on the in-memory sweep state
AND the persisted cursor entry (so it survives pause/resume and a
zenka restart) -- **every site that rebuilds that entry from a fixed
field list must carry it through**, enumerate all five explicitly as
required edit sites (same class of gap the state-machine task's own
review caught): `poll_sweep`'s `$persist_cursor` `$entry` (every idle
tick), `cmd.model-sweep-resume`'s in-memory re-arm and its cursor
write-back, `cmd.model-sweep`'s restart-resume re-arm and its initial
cursor write.

**unset rule, stated explicitly** (the existing filter-token convention
doesn't resolve this cleanly on its own): `model-sweep-resume <backend>`
with no `:no_yield:` token given clears a `no_yield` flag already on
the cursor -- resuming without repeating the token means resuming
under the default (yield-aware) behavior. `:no_yield:` must be repeated
on every resume call to stay in effect. this is a DIFFERENT rule than
the existing "no filter token = keep the cursor's filter as-is"
convention (`cmd.model-sweep-resume`'s filter handling) -- deliberately
different, since silently re-arming an uninterruptible run on a plain
resume call is a worse failure mode than silently dropping back to the
safe default.

### 3. `ensure_model_pinned` defers the task, does not pause the sweep

`ensure_model_pinned` fires its own `switch-model` call unconditionally
once no switch is already in flight for that checksum
(`<coding.model_switch_in_flight>->{$checksum}` guard). change: before
firing, check whether a sweep is `running` (or already `yielding`) on
that backend AND is not `:no_yield:`-protected. if so:

- do **NOT** fire `switch-model`.
- do **NOT** set `<coding.model_switch_in_flight>->{$checksum}` --
  that flag suppresses every future attempt for this checksum,
  including the eventual real one; setting it on a deferred path
  would permanently block the drain below.
- record the deferral: `<coding.model_pin_deferred>->{$backend}
  {$checksum} = TRUE` (new, simple, per-backend-per-checksum).
- return the dependency object id exactly as today -- the caller's
  existing re-queue-against-`dep_id` behavior (`coding.task.execute`)
  is unchanged and correct; the task parks in `depending`, same as any
  other unresolved pin.

**this needs no active "go pause the sweep" call at all** -- the
parked task already shows up as an active, non-completed entry in
`<coding.task.queue>` the instant it's queued, which is exactly what
scope #1's idle predicate already checks. the sweep discovers the
collision and yields **on its own**, the same tick it would have
anyway, with zero new coordination code between the two mechanisms.

**the drain** -- the piece that's actually new, and the piece the
review flagged as missing entirely from the first draft, since nothing
else in the tree ever re-fires a pinned-model switch. call a new
`coding.helper.drain_model_pin_deferrals($backend)` (walks
`<coding.model_pin_deferred>->{$backend}`, fires the deferred
`switch-model` call for each entry via the same path
`ensure_model_pinned` itself uses, clears the entry) from THREE sites:

1. scope #1's yield-detection branch, immediately, the same tick it
   sets `yielding` -- the whole point of yielding is to let the parked
   task through, so drain right there rather than waiting for a
   separate signal.
2. `finish_sweep` (natural completion) -- catches the `:no_yield:`
   case, where the sweep never yields by definition, and the deferred
   pin's only chance is the sweep actually finishing.
3. `model-sweep-cancel` -- same reasoning as #2, for the abandoned-run
   case.

### 4. adjacent, load-bearing bug: `queue_paused` can outlive a sweep-candidate crash

found while tracing the drain sites above, and directly undermines this
task's own premise if left alone: `coding.handler.
inference_server_sigchld` sets `<coding.task.queue_paused> = 1` on
every crash (gating ALL task dispatch globally, not just this backend
-- `coding.async.send_request`'s own gate). it's cleared on a
successful `verify_inference_startup` ready confirmation. but
`verify_inference_startup`'s retry-exhaustion path -- which a sweep
candidate hits after exactly ONE attempt now
(`coding.cfg.sweep_crash_restart_max_attempts`, landed same session) --
marks the server `failed` and returns without ever clearing
`queue_paused`. a sweep candidate crashing (routine, expected, per this
whole line of work) can leave real task dispatch globally blocked with
no automatic recovery until some LATER spawn happens to verify ready.

fix: the exhaustion branch in `verify_inference_startup` clears
`<coding.task.queue_paused>` the same way the ready-confirmation branch
does, rather than only ever clearing it on success. this is independent
of scopes #1-#3 and should land regardless of whether the rest of this
task does.

### explicitly out of scope

- the circuit breaker itself -- entirely unchanged, still
  `:force:`-gated, still manual-resume-only. `yielding`/`yield-timeout`
  is a structurally separate pause reason (see scope #1's mutual-
  exclusivity note) and must never be confused with or bypass the
  breaker's own gate.
- the actual cpu-binary segfault root cause -- still separate, still
  open, unaffected by any of this.
- how `jobsite.cfg.assessment_model` itself is chosen -- this task only
  makes the coding zenka side coordinate correctly with however that
  value got set.
- the yield-timeout bound (300s, matching `vision_switch_poll`) is a
  reasonable-by-precedent default, not a rigorously settled number --
  worth a second look if it proves wrong in practice, not a blocker to
  landing with it.

## validation

- `bin/dev/ptd -c` / `bin/format-code -c` on every changed/new file.
- **scope #1**: a sweep candidate about to advance while
  `<coding.task.queue>` has one non-completed task -- confirm no
  switch-model call fires, `model-sweep-status` reports `yielding`,
  cursor file is NOT rewritten that tick [ trace `$persist_cursor` is
  skipped ], `idx` unchanged. confirm it clears back to `running` and
  the next candidate fires the tick after the task completes, no
  operator action. confirm a pause-request arriving mid-yield is
  honored on the next tick, not starved.
- **scope #1, bound**: idle predicate continuously false past 300s --
  confirm transition to a real persisted `paused` with
  `paused_reason = 'yield-timeout'`, timer cancelled, and that resuming
  it without `:force:` is refused by the existing (unmodified) gate.
- **scope #2**: `:no_yield:` sweep run, same active-task scenario as
  above -- confirm the switch-model call fires anyway, `yielding` never
  appears. confirm the flag survives a pause/resume cycle when
  `:no_yield:` is repeated on resume, and is dropped when it isn't.
- **scope #3**: `ensure_model_pinned` fires for a checksum while a
  non-`:no_yield:` sweep is `running` on that backend -- confirm no
  switch-model call fires yet, `<coding.model_switch_in_flight>` is NOT
  set for that checksum, the deferral is recorded, and the task parks
  in `depending` as normal. confirm the SAME tick the sweep detects the
  collision and sets `yielding`, the deferred pin's switch-model call
  fires and the task's dependency eventually resolves. repeat with
  `:no_yield:` set -- confirm the pin stays deferred for the sweep's
  full duration and drains on `finish_sweep`, not before.
- **scope #4**: trace a sweep candidate's crash through
  `verify_inference_startup`'s exhaustion path with
  `sweep_crash_restart_max_attempts=1` -- confirm `queue_paused` is
  cleared on that path, not just on the ready-confirmation path.

## related

- `coding-test-iteration-state-machine.md` (landed `bc81c9d82`) -- the
  sweep state machine this extends; read its state model and the real
  committed `poll_sweep`/`cmd.model-sweep-pause`/`-resume` code before
  starting.
- `coding.handler.vision_switch_poll` / `coding.handler.drain_check` --
  the idle-wait precedent this task extracts into
  `coding.helper.backend_idle` rather than reimplementing.
- `coding.task.ensure_model_pinned` / `coding.callback.
  object_model_checksum_loaded` / `coding.task.execute` -- the
  implicit-switch/dependency-park mechanism scope #3 defers into
  correctly, read all three together, the dependency resolution only
  makes sense as one path across them.
- `coding.handler.verify_inference_startup` -- both the retry-ceiling
  change from earlier this session and scope #4's `queue_paused` fix
  live in this same file.

#,,,.,,.,,.,,,..,,.,,,...,...,,,,,...,,,.,,,,,..,,...,...,.,.,.,.,,,.,...,..,,

#,,..,.,,,,,.,,..,,..,...,,,,,,,.,.,.,,.,,,..,..,,...,...,,..,,,,,,.,,,..,,,.,
#HOES6XBYAZWAQRLLTZDAFOPRCGMJEQ2I5L7G6XBUDFDVKWWQH3WH6W6Z2DZ5T6MJ3ZZOV5OHTUZUM
#\\\|PEMT452YCTAMI36FG57DW52Y57WKCK73FVWNITHDHFXJPZ3NMM3 \ / AMOS7 \ YOURUM ::
#\[7]WCUPWBFGTYYE4TKGRIBRG4N3W2Q2TZPOAQY5MJQXX4AMN5USIUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
