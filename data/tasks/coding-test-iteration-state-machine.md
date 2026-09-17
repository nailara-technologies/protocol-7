## [:< ##

# name  = task: formal state machine + control commands for test iteration
# descr = coding.model-sweep [ already implemented, `8c765db92`/`6ae9cd3ab` --
#         see "already shipped" below ] currently has no pause/cancel, no
#         visible "this is actively crash-looping" status, and no
#         distinction between an infra-level failure and a genuine
#         model-quality failure. this task extends the shipped v1 with an
#         official state machine and command set, ahead of the more
#         complex templated test workflows planned on top of it later.

## already shipped -- read before touching anything below

`src/coding.model_sweep.cmd.model-sweep`,
`src/coding.model_sweep.cmd.model-sweep-status`,
`src/coding.model_sweep.handler.poll_sweep` are real, committed,
registered code (`cfg/zenki/coding/zenka.v7:77`,
`subroutines.load-early`), not a spec waiting to be built --
`coding-model-sweep-iterator.md`'s own task is done. read all three in
full before writing anything here; this task's every code reference
below is to real line numbers in those files as they exist today, not
to the design doc's description of them.

## why now -- live incident, 2026-09-17

1. started `p7c coding.model-sweep cpu` (89 candidates, default
   filter). `coding.model-sweep-status` gave idx/total and nothing else
   -- no way to tell, from that command alone, that every single
   candidate was crashing identically until the operator noticed the
   pattern by hand and started grepping raw logs.
2. tried to pause it once the pattern was suspicious. **there is no
   pause or cancel command.** the only lever tried was restarting the
   whole `coding` zenka (`v7-zenki.zenka.cmd.restart coding`), which
   hung twice (15s and 40s timeouts, no reply) rather than actually
   restarting it -- confirmed via unchanged session uptime in `list
   sessions`. gave up on that path rather than risk a force-kill mid
   in-flight spawn/self-test state. *the restart-hang itself is a
   separate, unscoped infra issue -- see "explicitly out of scope."*
3. the sweep finished on its own: 0/91 cpu candidates functional. all
   89 non-crash-free entries got written to `coding.model_status` as
   plain `inference-failures [switch failed: crashed]` -- structurally
   indistinguishable from a genuinely bad model. root cause (confirmed
   by running `llama-server-cpu` directly, bypassing the zenka
   entirely) was a segfault in the cpu binary itself, unrelated to any
   model file -- `2HZQLFQ:LOYSD4A` is `gpu: functional [3/3]` on the
   identical gguf. *the 89 already-recorded rows are not retro-tagged
   by this task -- see "explicitly out of scope."*
4. separately, a manual `coding.switch-model ... backend=cpu` test
   against a *different*, previously-`functional` model (Qwythos-9B)
   triggered a genuine 30-minute infinite crash-restart loop --
   `coding.handler.inference_server_sigchld`'s intended 5-attempt
   cutoff (`:87-97`) never fired because `coding.spawn_inference_server`
   replaced `<coding.inference_servers>->{$backend}` wholesale on every
   spawn [ including crash-triggered respawns ], silently dropping
   `restart_count` each time. fixed and landed same session (`0bcc68235`)
   -- not part of this task's scope, already done. **but for 30 minutes,
   neither `coding.model-sweep-status` nor `coding.model-status` showed
   any sign this was happening** -- both backends read `idle` the
   entire time, because the crash-restart subsystem is wired
   independently of the sweep/switch bookkeeping those commands read
   from. the only way the operator found it was live log output the
   user happened to be watching.

not every gap above maps to in-scope work here -- item 2's restart
hang and item 3's existing stale rows are named explicitly as
out-of-scope below, not silently dropped.

## scope

### 1. two independent state axes -- do not merge them into one persisted blob

**sweep axis**, per backend, persisted in the *existing*
`state/model_sweep_cursor.yaml` as a new explicit `state:` field
alongside the file's current `filter`/`candidates`/`idx`/`started`:

```
idle              no sweep for this backend
running           poll_sweep actively driving switch-model calls
pause-requested   NEW -- pause command issued, current candidate's
                   cycle still in flight, not yet honored
paused            NEW -- honored: no further candidate started,
                   cursor intact and resumable
```

`completed` is deliberately **not** a persisted/reportable state:
`poll_sweep`'s existing `finish_sweep` already clears the cursor
entirely (`$clear_cursor->()`) and deletes
`<coding.model_sweep_state>->{$backend}`, which makes a finished sweep
read as plain `idle` today (`cmd.model-sweep-status`'s fallthrough at
its final `else` branch) -- keep that. a finished sweep is a one-time
log line (`poll_sweep`'s existing summary), not a state to poll for.

**backend axis** (`crash-looping`): **derived at read time, never
persisted.** source of truth is the existing in-memory
`<coding.inference_servers>->{$backend}` hash --
`status eq 'crashed'` with `restart_count` in `1..5` means
crash-looping; `status eq 'failed'` (set at `sigchld:95` and
`verify_inference_startup:223`) is the already-exhausted terminal
case and reports as that, not as crash-looping. this must never live
in the cursor file: a crash-looping backend with **no sweep running at
all** (the item-4 manual-switch case, which is the entire justification
for this axis existing) would otherwise read as a resumable cursor
entry and get picked up by `cmd.model-sweep`'s existing auto-resume
(`:71-73`) or its in-progress refusal (`:61`) -- both wrong. the
in-memory hash is also the only thing that's actually live: a
persisted copy would be stale the instant the zenka restarts.

**`coding.model-sweep-status` prints both axes on every line, never
collapsed into one token** -- this is what makes paused+crash-looping,
idle+crash-looping, and completed(=idle)+crash-looping representable
instead of undefined:

```
cpu : paused [ circuit-breaker : 3x crash_before_ready exit=139 ] : idx=7/89 filter=default : server=crash-looping [ attempt 3/5 ]
gpu : idle : server=ok
```

### 2. pause / resume / cancel commands

new `.cmd.` files, registered the same way `model-sweep`/
`model-sweep-status` already are (`cfg/zenki/coding/zenka.v7`
`keywords =`, `bin/dev/gen-sub-whitelist coding`).

**`coding.model-sweep-pause <backend>`** -- does NOT stop anything
immediately. sets `<coding.model_sweep_state>->{$backend}
{'pause_requested'} = TRUE` and returns "pause requested -- will halt
after current candidate" (never "paused" while a switch may still be
in flight -- reporting a state that hasn't actually happened is
exactly the misleading-status failure this task exists to fix). the
`poll_sweep` timer keeps running unmodified. the check goes at the top
of the `phase eq qw| idle |` branch (`poll_sweep`, immediately before
`$start_candidate->()` -- the single site that issues a new
switch-model call): if the flag is set there, persist the cursor at
the current `idx` [ not N+1 -- this is BEFORE the next candidate would
start ], set persisted `state: paused`, cancel the timer, log once.
this is the one point-in-time where "no more calls will be issued" is
actually true.

**`coding.model-sweep-resume <backend> [filter] [:force:]`** --
distinct from `cmd.model-sweep`'s existing auto-resume-on-restart path
(`:66-114`, landed `6ae9cd3ab`): that path only fires when
`<coding.model_sweep_state>->{$backend}` is undefined (post-restart,
in-memory state gone). a `paused` sweep still has that in-memory state
defined, so plain `p7c coding.model-sweep cpu` against it hits the
**existing in-progress refusal at `cmd.model-sweep:61`** and reports
"already in progress" -- itself a misleading-status bug of the exact
class this task targets. fix required alongside the new resume
command: that refusal message must distinguish `running` from
`paused` and, when `paused`, point at `model-sweep-resume` instead of
just refusing. resume re-arms the timer from the persisted cursor.
same filter-matching rule `6ae9cd3ab` already established for the
restart case: refuse on a filter mismatch. additionally: **refuse a
resume when the persisted `state` is `paused` with a non-empty
`paused_reason` (a circuit-breaker trip, see #4) unless `:force:` is
given** -- an operator resuming a breaker-paused sweep without
acknowledging why it stopped is exactly how the remaining 86
candidates get burned on the same bad data a second time.

**`coding.model-sweep-cancel <backend>`** -- stops permanently, clears
the cursor (unlike pause), state -> `idle`. does not touch
`coding.model_status` -- already-recorded results stay recorded. **the
in-flight candidate, if any, is not aborted**: `poll_switch` has its
own independent timer and its own `model_status.record` call
(`poll_switch:264-272`), so candidate N's verdict can still land
*after* cancel returns -- cancel means "no further candidates," not
"nothing more will be written." for the same reason, do not clear
`<coding.self_test_switch_in_progress>` from the cancel command itself
-- let the in-flight `poll_switch` cycle clear it the way it normally
does; clearing it early would wrongly un-suppress
`monitor_inference_startup`'s auto-self-test while that cycle is still
resolving.

### 3. crash-class tag on the existing `inference-failures` detail -- two classes, zero new instrumentation

resist a 6th top-level `coding.model_status` state -- the existing
five are load-bearing elsewhere (sweep filter modes, the
`consensus_vote` doc). instead tag the *existing* free-text detail
[ what already produces `[switch failed: crashed]` ] at its one real
write site for a crash verdict, `poll_switch:264-272`:

```
crash_before_ready   process never reached the "ready" transition
                       [ monitor_inference_startup:85, existing
                       ready_logged flag -- already tracked, zero new
                       instrumentation needed ]. today's cpu segfault
                       shape: confirmed via direct binary run producing
                       zero output beyond "system info" before SIGSEGV.
crash_after_ready     was serving [ ready_logged already TRUE ], died
                       mid-request -- the sigchld/restart-loop path,
                       item 4 above
```

deliberately two classes, not three: a genuine three-way split
[ before-any-output / during-load / after-ready ] needs a new
high-water marker in `monitor_inference_startup`'s log-parse path that
does not exist today -- real new work, not "additive detail." the
two-class version is derivable *today* purely from the existing
`ready_logged` boolean and costs nothing to add. it is also everything
the circuit breaker (#4) needs: today's incident signature was zero
output before segfault, unambiguously `crash_before_ready`.

tag format at the write site: append `(crash_class, exit_status)` to
the existing detail string, e.g. `switch failed: crashed
[crash_before_ready exit=139]`. `exit_status` is already captured at
`sigchld:44`.

`verify_inference_startup:198`'s own `model_status.record` call
(`detail => 'restart_count exhausted'`, a *second*, separate crash
write site the original scoping pass missed) gets the same tag: by
definition its exhaustion path never saw a ready transition across any
of the 5 attempts, so it is unconditionally `crash_before_ready`.

### 4. circuit breaker on the sweep -- reads what #3 writes, so #3 lands first

direct consequence of item 3's incident: nothing stopped the sweep
from burning through all 89 candidates once the first few showed the
same signature. `poll_sweep` never reads per-candidate verdicts today
-- it only observes `!defined $switch_state` and advances (its
`waiting`-phase branch). add the read at that exact advance point,
right after `$idx++`/before the next tick: look up
`<coding.model_status>->{$checksum}{$backend}` for the candidate that
just finished, classify via #3's tag, and update an **in-memory,
per-backend, consecutive-match counter** -- not persisted, and reset
to 0 both on any non-matching outcome AND on `model-sweep-resume`
(otherwise a resume after the operator fixes the binary re-trips
instantly on the stale pre-fix count).

signature = the tuple `(crash_class, exit_status)`, not just the class
name -- two different exit codes both tagged `crash_before_ready`
aren't obviously the same underlying problem.

**breaker trips only on `crash_before_ready`, never
`crash_after_ready`, by design**: `resource-insufficient` already
returns early inside `spawn_inference_server` (`:343-348`) before any
process spawns at all, so real transient contention never produces a
SIGCHLD or a crash class in the first place -- it can't false-positive
this breaker. `crash_after_ready` deliberately does NOT trip it: three
consecutive post-ready crashes are plausibly three genuinely,
independently bad models, and auto-halting on that would be a false
positive in exactly the wrong direction (real distinct model failures,
not one shared infra cause).

N=3 consecutive identical-signature `crash_before_ready` verdicts ->
auto-transition to `paused` (never `cancel` -- cancel clears the
cursor and destroys the frozen 89-candidate list, which is the entire
thing worth protecting so the operator can resume after fixing the
actual binary; see #2's `paused_reason` field), with the tuple recorded
as `paused_reason` and surfaced verbatim by `model-sweep-status`
(see the example line in #1).

### explicitly out of scope

- the actual cpu-binary segfault root cause -- separate, still-open
  investigation. `coding-cpu-and-hybrid-offload-path.md` already flags
  recompiling `ik_llama.cpp` as "not off the table" if investigation
  points there; discriminating tests not yet run: `llama-server-cuda-fa
  -ngl 0` on a crashed candidate [ loads -> cpu-build-specific ],
  direct retry with `-tb 8` [ the binary's own startup line logs
  `n_threads_batch=-1`, a live smell for an allocation against a
  sentinel ].
- the `v7-zenki.zenka.cmd.restart` hang from incident item 2 -- a
  different subsystem (zenka lifecycle, not test iteration), worth its
  own investigation, not folded in here.
- retro-tagging the 89 existing cpu rows from today's sweep with a
  crash class -- they predate #3 landing and have no tag to retrofit
  from log data that's already rotated out of the ring buffer. once
  the segfault (or whatever's actually wrong) is fixed, re-run with
  `:re-test-failed:` -- `cmd.model-sweep`'s existing filter already
  includes `inference-failures` (`:137-142` in the design doc's terms),
  so this needs no new code, just a re-run.
- a three-way `crash_before_load`/`crash_during_load`/
  `crash_after_ready` split -- considered and explicitly declined in
  #3 in favor of the two-class version; would need new
  `monitor_inference_startup` instrumentation this task does not add.
- the "more complex test workflow templates" the user flagged as later
  build-out -- this task's job is giving that future work a proper
  state machine and command surface to land on, not designing the
  templates themselves. leave a named extension point [ an optional
  `template` field alongside `filter`/`candidates` in the persisted
  cursor, unused until that work starts ] but do not build template
  selection/execution logic now.
- re-litigating the 5-state `coding.model_status` taxonomy itself --
  #3 is additive detail on the existing `inference-failures` state,
  not a schema change to the table `MODEL-STATUS-TRACKING.md` already
  settled.
- `llm.service.consensus_vote` -- still just a future consumer, not
  touched by this task either.

## validation

- `bin/dev/ptd -c` on every changed/new file.
- **pause**: given a sweep at `idx=3` mid-`waiting` phase, call pause.
  confirm the immediate reply is "pause requested," not "paused."
  confirm no candidate 4 switch-model call is issued. confirm that once
  the in-flight candidate 3 cycle reaches its terminal (`!defined
  $switch_state`) transition, the cursor persists `idx=4` (the
  already-finished candidate 3 correctly advances past, per
  `poll_sweep`'s real terminal-transition semantics -- NOT idx staying
  at 3), `state: paused`, and the timer is cancelled.
- **cancel mid-cycle**: given an in-flight candidate, call cancel.
  confirm the cursor is cleared immediately. confirm the in-flight
  candidate's `poll_switch` cycle still completes and still writes to
  `coding.model_status` afterward. confirm
  `<coding.self_test_switch_in_progress>` ends FALSE (cleared by the
  in-flight cycle itself, not by cancel).
- **circuit breaker**: given a 10-candidate cursor at `idx=3` where
  candidates 1-3 each recorded `inference-failures` with a
  `crash_before_ready exit=139` tag, confirm: the cursor persists
  `state: paused` with `paused_reason` naming that exact tuple, no
  candidate-4 switch-model call is issued, and `model-sweep-status`
  prints the reason verbatim.
- **resume vs. already-in-progress**: given the paused state above,
  confirm `p7c coding.model-sweep cpu` (the plain, existing command)
  replies pointing at `model-sweep-resume`, not "already in progress."
  confirm plain `model-sweep-resume` (no `:force:`) against a
  breaker-`paused_reason` cursor refuses; confirm `:force:` proceeds
  and the in-memory consecutive-crash counter starts back at 0.
- **crash-looping, no sweep running**: given
  `<coding.inference_servers>->{cpu} = { status => 'crashed',
  restart_count => 3 }` and no cursor entry for cpu at all, confirm
  `coding.model-sweep-status` prints `cpu : idle : server=crash-looping
  [ attempt 3/5 ]` -- the exact scenario today's commands got
  completely wrong for 30 minutes.

## related

- `coding-model-sweep-iterator.md` -- already-shipped v1 this task
  extends; read its "the 4 states, filter modes" and "the loop itself"
  sections, and the real committed code in "already shipped" above,
  before starting.
- `data/md/design/MODEL-STATUS-TRACKING.md` -- the 5-state taxonomy
  #3 extends rather than replaces.
- `coding-cpu-and-hybrid-offload-path.md` -- prior CPU-spawn work; the
  still-open segfault root cause lives here, not in this task.

#,,.,,,.,,,,.,.,,,,..,.,.,,,.,,,,,...,.,.,,..,..,,...,...,,.,,,.,,..,,..,,.,,,

#,,..,,..,,.,,,.,,.,.,..,,.,.,,,,,.,.,,,.,,,,,..,,...,...,.,,,...,...,,,.,,.,,
#SWP4T37FBPOM4JQK2XMJX7MW5X7BZHFGRX6XY32V23M53VGD4MDRXGA2PV5N3XCTZ66U2TWO3B6AQ
#\\\|SYX5P6BQVBVPJ64UCUKZQ4EKKFCSC6WJXZI7WF7SOMA7ND6MZEK \ / AMOS7 \ YOURUM ::
#\[7]CH5P476QXEACRM3P4RAELNP6J6ALFKBEGXGQC3Y2DX42FLOYOEAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
