## [:< ##

# name  = task: cancel in-flight self-test before switch-model kills a server
# descr = coding.handler.spawn_smart's force=1 kill path never checks or
#         clears the self-test guard, leaving a zombie guard state and a
#         probe never notified when a model switch happens mid-self-test.

## context

this is todo `JEG` ("reset self-test if was in progress on model switch"),
originally raised generically, investigated in full 2026-08-27 alongside
the backend-aware timeout scaling work. confirmed NOT fixed by any of
that work -- `coding.cmd.switch-model` and `coding.handler.
switch_model_reply` (the files that actually kill/respawn a backend's
server on a model switch) were not touched by any commit that day. the
downstream work made things that WAIT on the self-test guard more
patient/correct ; nothing makes switch-model proactively clear the guard
before it destroys the server the guard's probe is talking to.

## the actual gap (read directly, full audit, trust this)

`src/coding.cmd.switch-model:70` sets `<coding.switch_model_active> =
TRUE` (a status flag other watchers use to distinguish a deliberate
switch from an unexpected server loss -- unrelated to the self-test
guard) and dispatches to `coding.handler.switch_model_reply` via an
async command reply.

`src/coding.handler.switch_model_reply` (143 lines) calls
`coding.handler.spawn_smart` with `force => 1` for each target backend
-- three call sites: the `auto` branch's gpu attempt (line ~99) and its
cpu fallback (line ~113), and the `both`/single-backend loop (line
~126). **none of them check `<coding.self_test_probe_in_flight>->
{$backend}` or anything else about self-test state.**

`src/coding.handler.spawn_smart:75-120`, the actual kill: when
`force`, it cancels the old server's stdout/stderr watchers, closes its
fds, then unconditionally `kill(0,$old_pid)` / `kill('KILL',$old_pid)`,
waits up to 2s for the process to die, reaps it, and deletes
`<coding.inference_servers>->{$backend}`. **zero awareness of
`self_test_probe_in_flight`, the backend lock
(`coding.async.backend_acquire`/`.backend_release`), or
`self_test_probe_state`.** `spawn_smart` is called ONLY from
`switch_model_reply` (confirmed via `grep -rn
"coding.handler.spawn_smart\]>->" src/coding.*` -- three hits, all in
that one file), so there's no other caller to worry about breaking.

**concrete failure sequence:** a self-test probe is genuinely streaming
on backend X when a switch-model call targets X. `spawn_smart` SIGKILLs
the server mid-stream. the probe's HTTP connection dies, but nothing
tells the probe's own pipeline this happened deliberately -- it's
discovered only indirectly, whenever `coding.handler.http_io`/`coding.
handler.http_timeout` eventually notice the socket is gone, or (worse,
if the socket lingers in a way that doesn't trip immediately)
`poll_probe`'s own watchdog, which after 2026-08-27's liveness-aware
rewrite waits up to the `coding.async.stream_tps`-derived outer cap
before giving up -- now potentially much longer than before that fix
landed. until the guard clears, `poll_switch`'s own post-switch
self-test (the `testing` phase, `coding.self_test.run`) gets rejected
outright with `"self-test already in progress"` (`coding.self_test.
run:77`, the per-backend hash-slot guard check), silently skipping
verification of the just-switched model for however long the stale
guard takes to resolve on its own.

## the fix (established pattern, same shape as items 3/4/5 of the
## backend-aware timeout scaling task -- reuse, don't reinvent)

add a cancellation step to `coding.handler.spawn_smart`'s `if ($force)`
block (`src/coding.handler.spawn_smart:77`), BEFORE the existing kill
logic, gated on `<coding.self_test_probe_in_flight>->{$backend}`:

1. scan `$data{'coding'}{'self_test_probe_state'}` for the entry whose
   `backend` field matches (same scan pattern used in `verify_
   inference_startup`, `poll_switch`, `trigger_backend_self_test` --
   at most one per backend, per the same invariant those already rely
   on).
2. if found and `in_flight` with a real `http_state`: synthesize an
   error through the probe's own pipeline -- same shape `poll_probe`'s
   own `watchdog_abort` path already uses (`$cb->{'on_error'}->(...)`
   if `ref $cb->{'on_error'} eq 'CODE'`, then `coding.async.
   http_cleanup`) -- rather than just deleting state out from under a
   live request.
3. delete the probe state entry, release the backend lock
   (`coding.async.backend_release`), and clear
   `<coding.self_test_probe_in_flight>->{$backend}` explicitly --
   don't rely on the probe's own eventual cleanup path noticing, the
   whole point is this must be immediate and deterministic.
4. if the guard is set but no matching probe state exists (stale
   guard, same case `verify_inference_startup`'s stale-guard branch
   already handles): just clear the flag defensively before
   proceeding -- cheap, safe, and the server's about to be killed
   regardless.
5. log at level 1 : this is a real "self-test was in progress"
   substitution to a real destructive event, worth a step above the
   verbose default the code already uses in nearby lines.

## why here and not in switch_model_reply

`spawn_smart` is the actual moment of destruction (the `kill('KILL',
...)` call) and is the only caller of the kill logic. putting the
cancellation immediately before it, inside the same `if ($force)`
block, means any future second caller of `spawn_smart` with `force=>1`
gets this protection automatically, rather than needing every call
site to remember to check first. `switch_model_reply` itself needs no
changes under this design.

## do NOT touch

- `coding.cmd.switch-model` -- only sets the informational
  `switch_model_active` flag, not part of this fix.
- `coding.routing.select_backend` -- the third, unrelated "auto"
  concept in this codebase (routing an in-flight request to an
  already-ready backend), do not conflate.
- anything from `data/tasks/coding-backend-aware-timeout-scaling.md`'s
  items 0-8 -- all already landed and independently verified, this is
  new, separate work in a file none of those touched.

## validation

- `bin/dev/ptd -c` on the changed file.
- standalone test coverage needed (this module's actual behavior has
  none currently -- one script mentions its name in a comment for
  unrelated context, nothing compiles or exercises it): a probe
  genuinely in-flight and alive on the target backend
  gets cancelled through its own pipeline (on_error fires, http_cleanup
  called) before the kill proceeds ; the guard and backend lock are
  clear immediately after ; a stale guard with no matching probe state
  clears defensively without erroring ; no self-test in flight on the
  backend is a no-op past this new block, unchanged from today.
- live verification only after standalone tests pass, and only by the
  user directly -- start a real self-test on a backend, issue
  switch-model targeting that same backend mid-round, confirm the
  guard clears immediately (not after a long stall/cap wait) and the
  post-switch self-test in `poll_switch`'s `testing` phase runs
  normally rather than hitting "self-test already in progress".

not urgent in the sense of "broken today with no recourse" -- the
liveness-aware downstream work landed 2026-08-27 already means a stale
guard from this path resolves within a bounded (if now larger) time
instead of hanging forever, so this is a real usability/correctness
gap, not a live incident.

#,,,.,,,,,,,.,.,.,,,.,,,,,,.,,,,,,.,,,...,...,..,,...,...,..,,,,.,,,.,...,,..,
#G34XJMSLRFH5UTRWWV6KFZUXYNK3FTS2Y5GGJCOMCU5SNLZB7DPWHFFM4YURF4M34XHKWYI7TABRC
#\\\|WBAGDNOA5L4UVTZLOLA3PPHXSMHLC53DJWSBB3Z6THA4XAUKFE6 \ / AMOS7 \ YOURUM ::
#\[7]FTCTBVOOYJIYSNWVWY7IJUAUCRKR2SITFKCIJPK7EFN7ZSL4O2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
