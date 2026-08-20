# coding.vision-model `:switch:` — deferred idle-gated vision-model switch request

## status (2026-07-23) — DONE, landed `95a2031fc`

landed as `coding: add vision-model :switch: for idle-gated model switching`.
`src/coding.cmd.vision-model` branches on `:switch:`, parses optional
checksum/timeout, short-circuits when already vision; new
`src/coding.handler.vision_switch_poll` implements the two-phase
(waiting_idle/switching) timer state machine; both whitelisted in
`cfg/zenki/coding/subroutine.white-list`. confirmed live
(2026-07-23): `coding.commands vision` lists `vision-model [:switch:
[<id>] [<timeout>]]`, `coding.vision-model` (no-arg report) returns the
loaded model checksum; `coding.vision-model :switch:` (no checksum, a
vision model already loaded) hit the already-vision short-circuit path
exactly as spec'd — replied the same model id immediately, no deferred
switch/wait. round-1 report path and round-2 :switch: short-circuit both
confirmed live. the switching/waiting_idle phases (actually loading a
*different* model) were exercised in an earlier session per the owner,
not re-verified in this pass.

## status (2026-07-19) — PLANNED, ready for implementation

round 2 of the `coding.vision-model` feature. round 1 (`src/coding.cmd.vision-model`,
commit `bc3824421`) added a no-arg report of whether the currently-loaded gpu model has
vision (mmproj). round 2 adds a `:switch:` action parameter that asks the coding zenka to
*make* a vision-capable model the loaded one, waiting for the current task queue to go idle
first so no in-flight inference is interrupted, and replying deferred once the switch lands.

consumer: `lm-vision` (already granted `coding.vision-model` in cube's `access.zenki`, and it
is enabled in coding's own `access.cmd.usr.cube`). also usable interactively via nshell/p7c.

---

## parameter grammar

extend `src/coding.cmd.vision-model` to parse `$call->{'args'}`:

```
coding.vision-model                          -> round-1 behaviour, unchanged (report only)
coding.vision-model :switch:                 -> switch to auto-selected vision model, default timeout
coding.vision-model :switch: <checksum>      -> switch to a specific model checksum
coding.vision-model :switch: <timeout>       -> auto-select, caller-supplied wait bound (seconds)
coding.vision-model :switch: <checksum> <timeout>   -> both, order-independent
```

- `:switch:` is a colon-wrapped out-of-band directive, matching the `:start:` / `:xxx:`
  convention already in `base.strm.subscribe*` and `lm-vision.init_code`. CONFIRMED as the
  naming (unambiguously names the requested action; preferred over `:request:`).
- the two optional tokens are disambiguated by shape, so order does not matter:
  - checksum  = `m{^[A-Z2-7]{7}:[A-Z2-7]{7}$}i`  (contains a colon — same regex as `coding.cmd.switch-model`)
  - timeout   = `m{^\d+$}`  (bare integer seconds)
- any arg string that starts with something other than `:switch:` and is non-empty ->
  usage/error reply (`mode => size`), do not silently fall through to the report path.

### model selection (OPEN — owner to confirm the source)

when no checksum is supplied, the command auto-selects a vision-capable model *locally*
(no extra async round-trip): scan `<coding.model_metadata>` and pick the first entry whose
key is not itself an mmproj file and which is vision-capable. the codebase already ships a
predicate for this — `models.parser.str.is_vision` (coding subroutine.white-list line 649) —
prefer reusing it over re-deriving "has mmproj". if a configured default vision model exists
(e.g. an `lm-vision` / coding config key), prefer that as the auto-select source.

**judgment call for the owner:** auto-select source — configured-default vs registry-scan.
Recommendation: registry-scan via `is_vision`, with an explicit checksum from the caller
(`lm-vision` has `fetch_model_config` and can pass one) always taking precedence. If neither
a checksum nor any vision-capable registry entry is found, reply `FALSE no-vision-model`
immediately (not deferred).

### short-circuit: already vision

if a vision model is already loaded and ready (round-1 predicate: gpu status `ready` AND
non-empty mmproj) AND either no checksum was supplied, or the supplied checksum already
matches the loaded `<inference.model.amos_id>` — reply `TRUE <model-id>` **immediately**
(non-deferred, `mode => true`). no switch, no idle wait. this is the common lm-vision case.

---

## idle detection

**finding (state plainly to owner):** there is no idle *event* to subscribe to in this
codebase. the existing idle signal is the `coding.handler.drain_check` predicate, and it is
consumed by *polling* on a timer (drain sets up a 1.0s-interval timer that re-checks until
the predicate holds). so the idiomatic, robust choice is to reuse that same predicate via a
pending-scoped, self-cancelling poll timer — this satisfies "do not reimplement queue-depth
tracking" (the predicate is reused verbatim) even though the mechanism polls. a hand-rolled
event-driven hook off task-completion would miss the case where the backend lock releases
*after* the final completion event, which is exactly why drain_check ANDs both conditions.

**idle predicate (mirror `coding.handler.drain_check` exactly):**

```
idle  ==  active_tasks == 0   AND   no backend lock held
```

- active tasks: iterate `<coding.task.queue>` values, count entries whose
  `execution.status` is neither `completed` nor `failed`. (equivalently
  `coding.task.queue_stats` -> queued+running+paused+depending; but drain_check reads the
  raw queue, so mirror that for behavioural parity.)
- backend lock: `<coding.state.backend>->{gpu}{lock}` / `->{cpu}{lock}` both undef.
  these are set by `coding.async.backend_acquire` and cleared by
  `coding.async.backend_release` around each in-flight inference request.

do **not** count the switch request itself, and do **not** count `completed`/`failed`
tombstones as active.

---

## state machine (new handler, modelled on `coding.self_test.handler.poll_switch`)

new module `src/coding.handler.vision_switch_poll` — a timer-driven machine, but simpler
than poll_switch: **no restore phase, no tier-2 judgment** (owner explicit: no
auto-revert-after-request, no priority preemption — future scope).

per-request state under `$data{coding}{vision_switch_state}{<switch_id>}`:

```
reply_id        deferred reply target (from $call->{reply_id})
target_checksum resolved model to switch to
timeout         wait-for-idle bound in seconds (caller value or default)
started         <[base.time]>->(3) at request time (drives idle-wait timeout)
phase           'waiting_idle' | 'switching'
prior_pid       gpu pid captured just before switch-model is issued
replied         guard so the deferred reply fires exactly once
```

timer: `<[event.add_timer]>` with `after`/`interval` ~1.0s, `handler =>
coding.handler.vision_switch_poll`, `data => { switch_id => ... }` (read via `$event->w->data`,
same pattern as poll_switch / monitor_inference_startup).

### phase `waiting_idle`

1. `elapsed = now - started`. if `elapsed > timeout` -> reply `FALSE timeout`, cancel the
   *queued* switch (nothing has been killed yet — interrupt nothing), finish. this is the
   caller's wait bound and a distinct failure mode.
2. else evaluate the idle predicate above. if not idle -> return (timer continues), log at
   low verbosity every ~5s.
3. if idle -> capture `prior_pid` from `coding.cmd.inference-status` gpu pid, issue the switch
   by reusing the existing flow verbatim:
   `<[coding.cmd.switch-model]>->({ args => $target_checksum })`
   (this is exactly how poll_switch triggers its restore — reuses `switch_model_reply` ->
   `spawn_smart`, inheriting today's mmproj_path propagation fix, no duplication).
   set `phase = switching`, reset `started = now`.

### phase `switching`

readiness is governed by the switch's **own** bound now, not the caller's wait timeout:
`max_wait = <coding.cfg.switch_model_max_wait> // 300` (same key poll_switch uses).

read `coding.cmd.inference-status`; let `ready = gpu.status eq 'ready'`,
`pid = gpu.pid`, `pid_changed = pid && pid != prior_pid`.

- **success** = `ready && pid_changed`. (CARRY-OVER from poll_switch's hard-won lesson: do
  NOT gate on model_id match — `<inference.model.amos_id>` is one global shared across
  gpu/cpu and is set by switch_model_reply before the respawn actually completes, so it can
  read "correct" while the OLD process still serves. pid change is the load-bearing signal.)
  -> reply `TRUE <model-id>` (model-id from gpu `model` / `<inference.model.amos_id>`), finish.
- **crashed** = `gpu.status eq 'crashed'` -> reply `FALSE crashed`, finish.
- **timed out** = `elapsed > max_wait` -> reply `FALSE switch-timeout`, finish. (distinct
  label from the idle-wait `timeout` so the caller can tell the two phases apart.)
- else -> return, timer continues.

on every finish: cancel the timer, delete the state entry, fire the deferred reply exactly
once (guarded by `replied`).

---

## reply contract (deferred id lifecycle)

- on `:switch:` accepted (not short-circuited), capture `my $reply_id = $call->{reply_id}`,
  register state + start the poll timer, and return `{ mode => deferred }` (matches
  `coding.cmd.inference-status`'s deferred pattern).
- later fulfilment: `<[base.callback.cmd_reply]>->( $reply_id, { mode => ..., data => ... } )`.
- reply payloads (`mode` per the `.cmd.` reply contract, `data` a STRING):
  - success:        `{ mode => true,  data => '<model-id>' }`
  - idle-wait over: `{ mode => false, data => 'timeout' }`
  - switch crashed: `{ mode => false, data => 'crashed' }`
  - switch too slow:`{ mode => false, data => 'switch-timeout' }`
  - no vision model available: `{ mode => false, data => 'no-vision-model' }` (fired
    immediately, non-deferred, if resolution fails before any timer is armed)
- the deferred reply MUST fire exactly once — guard the idle-timeout-vs-switch-success race
  with the `replied` flag; once fired, all further timer ticks are no-ops that only cancel.

---

## timeout semantics (owner's explicit open question — resolved by phase split)

the two phases have opposite abort-safety, so the single caller-supplied timeout is applied
to the **wait-for-idle phase only**:

- **wait-for-idle** is unbounded and externally dependent (someone else's queue) and safely
  cancellable — nothing has been touched yet. the caller's timeout bounds THIS. on expiry:
  `FALSE timeout`, drop the queued switch, interrupt nothing.
- **switch/respawn** is abort-*unsafe* (a kill+respawn is already in motion). it is governed
  by the switch's own readiness bound (`switch_model_max_wait`, 300s) and reports its true
  outcome (`TRUE <id>` / `FALSE crashed` / `FALSE switch-timeout`).

this answers the owner's question directly: the caller timeout is *both* a distinct failure
mode *and* just-a-wait-bound — but on different phases. default when omitted: cap the idle
wait (recommend `concurrent.drain_timeout`'s 300s, or a dedicated
`coding.cfg.vision_switch_idle_timeout`) rather than waiting forever on a busy queue.

---

## access control

**no new grant entries required** (deviation from the task's step-3 assumption — call this
out to the owner). `:switch:` is a *parameter* of the already-granted `coding.vision-model`
command, not a new command; cube grants are per-command-name, not per-arg. round 1 already
added `coding.vision-model` to cube's `access.zenki` (lm-vision, line 255) and to coding's
`access.cmd.usr.cube` (line 54). those cover the `:switch:` path unchanged.

**whitelist (required):** add every new module file name to
`cfg/zenki/coding/subroutine.white-list` (round-1 reference: `coding.cmd.vision-model`
at line 447). new file: `coding.handler.vision_switch_poll` (plus any helper module split out).

---

## files

- `src/coding.cmd.vision-model` — CHANGED: branch on `:switch:`, parse optional
  checksum/timeout, resolve target, short-circuit already-vision, arm the poll timer, return
  `{ mode => deferred }`. round-1 report path preserved for the no-arg / non-`:switch:` case.
- `src/coding.handler.vision_switch_poll` — NEW: the two-phase timer state machine above.
- `cfg/zenki/coding/subroutine.white-list` — add new module name(s).
- (optional) `cfg/zenki/coding/start` — add `coding.cfg.vision_switch_idle_timeout`
  default if a dedicated key is preferred over reusing `concurrent.drain_timeout`.

**signatures:** new/changed module files MUST be left UNSIGNED. the owner signs interactively
(`bin/Protocol-7 sourcecode update-signatures <paths>`). do NOT self-sign, do NOT commit/push.

---

## explicitly OUT OF SCOPE (owner was explicit)

- auto-revert-after-request ("temporarily switch for one request then switch back") — future.
- priority-queue preemption of in-flight inference — future; this feature only ever waits for
  natural idle, never interrupts.
- no polling reimplementation of queue-depth tracking — the drain_check predicate is reused.

---

## open questions for the owner

1. **auto-select source** (top question): registry-scan via `models.parser.str.is_vision`
   vs a configured default vision-model key. Plan recommends registry-scan, explicit caller
   checksum always wins.
2. **timeout default + config key**: reuse `concurrent.drain_timeout` (300s) as the idle-wait
   cap, or add a dedicated `coding.cfg.vision_switch_idle_timeout`? Plan leans dedicated key
   for clarity.
3. confirm the **no-new-access-grant** framing (parameter of an already-granted command).

#,,,.,,,.,,,.,.,.,...,,,,,,..,,..,..,,...,,..,..,,...,...,,,.,,,.,,..,,.,,...,
#O7QYYKFFNRNSCOO6SU3IVOFN7E3UWV5MULYOQVQL5TKYRFV5YL4J7C75LNJJ7OFI7CGI7MFEUE3CK
#\\\|GIZSJEKSWIRBEHLSSU2H7VGAP5HNHUL3FNT3KCNMIGPRK3LDIXX \ / AMOS7 \ YOURUM ::
#\[7]UHQO7NLEV3H33VG5JQQCFDYNK34DDQIHXKWCI4GCYXMS3BEBPCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
