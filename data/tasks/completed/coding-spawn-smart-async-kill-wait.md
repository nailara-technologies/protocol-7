## [:< ##

# name  = task: make spawn_smart fully async -- no more blocking kill-wait
# descr = remove the blocking busy-wait spawn_smart uses to wait for an old
#         inference server to die before switching models, replacing it
#         with the zenka's own existing SIGCHLD-driven reaping, and make
#         the whole function callback-driven (on_done) rather than
#         half-async

## why now

confirmed live 2026-09-17/18: `coding.handler.spawn_smart`'s forced-kill
branch (fires on every model switch during the sweep, `force => 1`) blocks
the ENTIRE coding zenka event loop while waiting for the old server's pid
to die:

```perl
## coding.handler.spawn_smart, current lines ~136-145 ##
my $wait_count = 0;
while ( kill( 0, $old_pid ) && $wait_count < 20 ) {
    select( undef, undef, undef, 0.1 );
    <[base.waitpid]>->($old_pid);    ## Reap if zombie [WNOHANG] ##
    $wait_count++;
}
## brief additional wait for gpu driver to release vram ##
select( undef, undef, undef, 0.3 ) if $backend eq 'gpu';
```

`select(undef,undef,undef,N)` is a real blocking sleep of the whole
single-threaded process -- up to 20*0.1s + 0.3s = 2.3s of total event-loop
freeze per forced respawn. The user confirmed this directly: `coding.heart`
(the heartbeat ping) visibly waited for this exact loop to finish. Every
model-sweep candidate switch goes through this path with `force=1`, and a
crash-restart storm (several forced respawns back to back) stacks these
blocks toward v7-zenki's heartbeat timeout -- the most concrete, directly-
observed mechanism behind repeated `coding` heartbeat kills this session
(separately mitigated by raising `heartbeat.timeout` 47->77, see
`cfg/zenki/coding/start.cfg`, but that's a symptom-side margin increase,
not a fix for this root cause).

## existing infra to reuse -- read all three before writing anything

1. **`coding.handler.inference_server_sigchld`** already reaps children
   fully non-blockingly (`waitpid(-1, WNOHANG)` loop, real SIGCHLD
   handler, zero polling) and already has the EXACT guard-flag shape this
   task needs: `<coding.draining>` (line ~58) and
   `<coding.lora_training_in_progress>` (line ~74) both make a deliberate
   kill of the tracked server look identical to a crash from this
   handler's point of view, and both just `next` (skip crash-restart,
   don't touch `restart_count`/backoff) when set. This task adds a THIRD
   flag of the same shape -- but unlike those two, which just skip and
   stop, this one also needs to fire a continuation (spawn the new
   server) once the old pid is confirmed reaped.
2. **`plugin.usage.kimi.refresh_token`** shows this codebase's own
   `on_done` callback convention (`{'on_done' => {'handler' => '...',
   'params' => {...}}}`, called via
   `<[protocol-7.command.send.local]>`-style or a direct handler
   dispatch once an async step completes) -- mirror that shape, don't
   invent a new one.
3. **`coding.handler.spawn_smart_path_reply`** is spawn_smart's OWN
   existing async-completion precedent for the "need to resolve amos_id
   to a path" branch (when `spawn_smart` returns `TRUE` early and the
   real spawn happens later, in this reply handler). This confirms
   `spawn_smart`'s callers already tolerate "returns now, really
   finishes later" for one branch -- this task generalizes that to ALL
   branches via one consistent `on_done` callback, including this file.

## the real wrinkle -- read before touching `switch_model_reply`

`coding.handler.switch_model_reply`'s `auto` branch (lines ~96-120)
depends SYNCHRONOUSLY on `spawn_smart`'s gpu return value to decide
whether to fall back to cpu:

```perl
my $gpu_ok = <[coding.handler.spawn_smart]>->({ backend => 'gpu', ... });
unless ($gpu_ok) {
    ## try cpu instead ##
    <[coding.handler.spawn_smart]>->({ backend => 'cpu', ... });
}
```

The "does it fit" decision genuinely can't be known until the old
process is confirmed dead (killing it frees the VRAM/RAM the fit-check
reads) -- so once the kill-wait is async, this boolean can no longer be
read synchronously. Per explicit user decision: **make `spawn_smart`
async everywhere, not just for this one call site** -- give it an
`on_done` callback parameter, and move the `unless ($gpu_ok) { try cpu
}` fallback logic INSIDE that callback. Do not leave spawn_smart
half-sync/half-async; that was explicitly rejected as not making sense.

## scope

1. **`coding.handler.spawn_smart`**: accept a new `on_done` param
   (coderef or the `{'handler'=>..,'params'=>..}` shape, match whichever
   the codebase's `on_done` convention actually uses -- confirm from
   `plugin.usage.kimi.refresh_token`, don't guess). Remove the blocking
   `while(...){ select(...) }` loop and the unconditional GPU
   `select(...,0.3)` entirely. In their place:
   - before sending the kill: set
     `<coding.switching_backend>->{$backend} = TRUE` (new flag, same
     shape as `<coding.draining>`/`<coding.lora_training_in_progress>`)
     and stash everything needed to finish the spawn afterward (model
     path, mmproj path, binary, port, amos_id, and the caller's
     `on_done`) in a new `<coding.pending_switch>->{$backend}` hashref.
   - send `kill('KILL', $old_pid)` as today, then return (nothing left
     to do synchronously on this path).
   - the actual memory-check + `coding.spawn_inference_server` call that
     currently follows the blocking wait becomes a new small helper
     (e.g. `coding.helper.complete_pending_switch` or similar -- name it
     clearly) that reads `<coding.pending_switch>->{$backend}`, does the
     fit-check + spawn, calls the stashed `on_done` with the real
     TRUE/FALSE result, and deletes the pending-switch entry.
   - for a backend with no old process to kill (nothing running yet),
     skip straight to calling that same helper immediately -- no
     regression for the cold-start case.
2. **`coding.handler.inference_server_sigchld`**: add a branch alongside
   the existing `<coding.draining>`/`<coding.lora_training_in_progress>`
   checks (same `if`/`next` shape) that: checks
   `<coding.switching_backend>->{$backend}` for the matched backend, and
   if set, clears the flag and calls the new completion helper from
   step 1 instead of just `next`-ing past crash-restart. Real crashes
   (flag unset) go through the existing crash-restart path completely
   unchanged.
3. **defensive fallback timer**: also arm a bounded timer (mirror the
   existing 2.3s total budget -- e.g. `event.add_timer` with
   `after => 3`) right when `<coding.pending_switch>->{$backend}` is
   set, that fires the same completion helper if it hasn't already run
   by then (covers the theoretical case of a missed/coalesced SIGCHLD --
   the existing sigchld handler already drains ALL exited children per
   signal so this should be rare, but the current code already budgets
   for "old process took too long" and callers shouldn't silently hang
   forever if it never fires). Cancel this timer from inside the
   completion helper if it already ran via the sigchld path, and vice
   versa -- guard against running the completion helper twice for the
   same pending-switch entry (e.g. a boolean/deleted-key check, since
   the hashref itself is deleted once consumed).
4. **`coding.handler.switch_model_reply`**: convert both call sites
   (`auto` branch lines ~96-120, and the `both`/single-backend loop
   lines ~121-133) to pass `on_done` instead of reading a return value.
   Move the `unless ($gpu_ok) { try cpu }` fallback logic into gpu's
   `on_done` callback.
5. **`coding.handler.spawn_smart_path_reply`**: this is already the
   completion point for the "resolve path async" branch -- make it also
   call the caller's `on_done` (threaded through from the original
   `spawn_smart` call) instead of being a dead end, so it's consistent
   with the other completion paths.

## explicitly out of scope

- `coding.spawn_inference_server` itself (the actual binary-spawning
  logic, partial-offload math, context sizing) -- untouched, already
  correct.
- `coding.helper.check_resource_fit` / `coding.helper.calculate_safe_context`
  -- untouched.
- the model-sweep pause/resume/cooldown machinery, the
  `v7-zenki.instance_count`/`restart_pending` fix, the heartbeat.timeout
  config changes, the `ptrace`/backtrace question -- all separate,
  already handled or explicitly deferred this session, don't
  re-investigate.
- the model sweep is PAUSED (both backends) for the duration of this
  task specifically so live-testing isn't fighting background sweep
  activity -- don't resume it as part of this task; that's a manual step
  afterward.

## verification

`bin/format-code -c` on every touched/new file. Live-test with the sweep
still paused: manually trigger a model switch with `force=1` on gpu
(e.g. via whatever `switch-model`-style command routes to
`switch_model_reply`) while something else is watching `coding.heart`
response latency, confirm it no longer blocks for ~2s. Trigger the
auto-fallback path deliberately (a gpu switch that won't fit) and
confirm it still correctly falls back to cpu via the callback. Trigger a
REAL crash (not a deliberate switch) and confirm the existing
crash-restart backoff/circuit-breaker behavior is completely unchanged --
this is the part most likely to regress silently if the new
`switching_backend` guard leaks true for longer than it should. Leave
the tree uncommitted, report back with what changed and exactly how each
path was verified.

## status [ 2026-09-18 ] — DONE, live-verified, signed + staged

kimi (k2.8) landed cleanly, needed one `kimi_continue` to finish after
hitting a 100-step budget mid-test-2 (test 1 was already fully passed by
then). All three live tests passed, independently re-verified this
session (not just trusting kimi's report): read the actual diffs for the
two highest-risk files (`inference_server_sigchld`'s new branch is purely
additive, `next`s before the untouched restart_count/backoff block;
`complete_pending_switch` clears `<coding.switching_backend>`
unconditionally on both the sigchld and fallback-timer paths, closing the
exact "stuck flag disables future crash-restart" risk), and ran
`bin/format-code -c` myself across all 9 touched/new files.

- **test 1** (deliberate gpu switch, force=1): `coding.heart` stayed at
  ~0.0018s (baseline 0.0011s) vs the old ~2.3s block. Log: kill ->
  `inference_server_sigchld` recognizes the deliberate-switch flag ->
  `complete_pending_switch` -> new server ready. No fallback-timer line
  (SIGCHLD path won).
- **test 2** (auto-fallback, 16.69GB model doesn't fit either backend):
  gpu insufficient -> `switch_model_auto_gpu_done` -> tries cpu ->
  cpu also insufficient -> clean end state, no stuck flags on either
  backend.
- **test 3** (the critical one, real `kill -9` outside spawn_smart):
  crash-restart path fires completely unchanged -- `gpu server crashed
  [exit=9]` -> `scheduling gpu restart in 5s (attempt 1/5)` -> restarted
  successfully. No "deliberate model switch" log line appeared; the guard
  flag was confirmed unset throughout. Repeated with a second kill,
  identical path both times.

Files: `coding.handler.spawn_smart` (rewritten, fully async via `on_done`),
new `coding.helper.complete_pending_switch` + `coding.handler.
pending_switch_timeout` + `coding.handler.switch_model_auto_gpu_done` +
`coding.handler.switch_model_spawn_done`, `coding.handler.
inference_server_sigchld` (additive branch only), `coding.handler.
switch_model_reply` (on_done call sites), `coding.handler.
spawn_smart_path_reply` (threads on_done through), `coding.init_code`
(new global init), module-registration files.

#,,.,,,,,,,..,.,,,,..,,.,,...,...,,,.,,,.,,.,,..,,...,...,,.,,,.,,..,,,,,,,,.,
#F52J5T4QUNHGEO7NEWZS3RHMDLTPWRRJQRJ6IMFNA34NOB7YV5FHSYCSBRWAF4AA5LWS2NYWNWUZ4
#\\\|G5DGL7SRR4OXZW5C276YFT4OWIAIV7OVAWMZCL2PH7J7BMVYYPD \ / AMOS7 \ YOURUM ::
#\[7]AECEL7ATX3S7IH7Y47UIQR4N77IDUTMBXMU2QGWHPJDTVAPY36AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
