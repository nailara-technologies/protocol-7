---
name: p7-local-command-route-and-deferred-reply-mechanics
description: "when base.route.add is/isn't involved in a command exchange, what 'deferred' actually does at the wire level for a locally-dispatched .cmd. module, and how session-close cleanup (cancel_route) resolves in-flight routes on both sides"
metadata:
  type: reference
  originSessionId: 5ac91c78-9af6-4d29-bfc3-06bee0e50cd4
---

Established while building `v7.idle-term` (see
[[ondemand-heartbeat-upgrade]]) — cost several rounds of wrong guesses
before reading the actual call sites. Verify against these files, don't
re-derive from memory of this note alone if the code has moved.

**`base.route.add` has two distinct callers, and receiving a routed
command as a LOCAL `.cmd.` dispatch never touches it at all.**
1. `base.handler.command.route_to_target` — cube-side forwarding, when a
   command's target isn't the receiving zenka itself. `source.sid` =
   sender's session, `target.sid` = the zenka it's relaying to. Lives
   entirely in the router's (usually cube's) own `%data`.
2. `base.protocol-7.command.send.local:82` — any zenka's own outbound
   send with a registered `reply => {handler=>...}`. Self-referential:
   `source.sid == target.sid ==` the sender's own upstream session (e.g.
   v7's link to cube). This is how v7 tracks its own outbound `heart`
   probes to correlate the eventual reply with
   `v7.handler.heartbeat_timer_response`.
3. A zenka *receiving* a routed command and dispatching it as a local
   `.cmd.` module (`$data{'base'}{'cmd'}{$cmd}` → `$code{...}->($call_args)`
   in `base.handler.command`) uses neither — it's tracked purely via
   `$call_args->{'reply_id'}` / `<base.cmd_reply>`, a hash local to that
   one process, unrelated to `%data{'route'}`.

**`mode => 'deferred'` from a local `.cmd.` handler sends *nothing* over
the wire right now** — not even `WAIT` (`base.handler.command:750-760`:
logs, resumes the input watcher, returns). `WAIT` is one of the modes a
deferred command can *complete with later* via `base.callback.cmd_reply`,
not something `deferred` emits on its own. Critically,
`<base.cmd_reply>->{$reply_id}` is only deleted on the *non*-deferred
path (line 761) — `deferred` means "I'll reply later," and if you never
do, that entry sits there forever unless you delete it yourself. This is
different from [[cross-zenka-deferred-reply]]'s pitfall (route-send's
ephemeral per-call session closing before a later reply can land) — a
local `.cmd.` dispatch's session (the persistent zenka↔cube link) never
closes on its own, so `deferred`-and-never-complete is *safe* to use
deliberately as "I will never reply" as long as you clean up
`<base.cmd_reply>` yourself, e.g. before returning from the handler.

**`base.session.cancel_route` (fired by `base.session.check.close` on
session teardown) sweeps routes unconditionally, regardless of whether
the closing session was source or target, and regardless of reply-pending
state** — no wait-counter check. For a route where the closing session
was the *target*, it also synthesizes `"($cmd_id)FALSE command route
collapsed\n"` directly into the *source* session's own output buffer,
which flows back through that source's normal `process_reply` path as if
a genuine FALSE reply arrived. This is why a zenka dying mid-heartbeat
(with v7's own outbound-probe route entry still open) doesn't leak
anything on v7's side, and doesn't need special-casing — it resolves
through `v7.handler.heartbeat_timer_response` exactly like an ordinary
crash always has, whether or not `v7.idle-term` is involved.

**`v7.zenka.instance.stop` is race-proof against a concurrent heartbeat
failure flipping status to `error`** — it sets
`<zenka.instance.shutdown>->{$instance_id}` as its first action and
synchronously cancels the instance's `Event::timer` objects (including
`heartbeat-timeout`) via `v7.cancel_instance_timers`, before the process
is even killed. `v7.handler.zenka_status` has an unconditional override
near its end: if `<zenka.instance.shutdown>` exists for the instance, the
status is forced to `shutdown` regardless of what was computed, and
`v7.init_restart_timer` never fires.

**`v7.zenka.cmd.pause-instance` is not a heartbeat-detection test tool** —
it explicitly calls `v7.stop_heartbeat_timer` as part of pausing (storing
`paused_status_timer` for `resume-instance` to re-enable), specifically
so a deliberate admin freeze doesn't trigger a spurious restart. To
actually simulate a genuinely unresponsive zenka (for testing heartbeat
detection), load `devmod` in `modules.load` (`zenka.v7`), grant its
`access.cmd.usr.cube` list access to `sleep`, and call
`<zenka>.sleep <seconds>` — `devmod.cmd.sleep` really blocks the event
loop synchronously. `mod-test` (`cfg/zenki/mod-test/`) is the designated
throwaway zenka for this kind of live experiment — both its `start.cfg`
and `zenka.v7` already carry commented-out devmod scaffolding meant to be
toggled on temporarily.

## connections

- [[ondemand-heartbeat-upgrade]] — the feature this was established for
- [[cross-zenka-deferred-reply]] — the *other* deferred-reply failure
  mode (route-send's ephemeral session), don't conflate the two
- [[p7-route-send-wire-protocol]] — sibling reference on route-send's
  wire shapes (`call_args` only transmits `args`, reply `cmd` values,
  SIZE/STRM producer-side modes)

#,,.,,...,.,,,,,,,,..,.,,,,..,...,.,.,...,,,,,..,,...,...,..,,,.,,,..,..,,,,,,
#ONQMVVAST5S7BQ35QBAL5F777BXO65X5WVJWASFMY4UFHP3YVTMFYJ3LITMQJDVAGKTCAUTWKOP4K
#\\\|R4UHTMHWEZU2WLY42SLM33M3ZLWTHW5TRZIGVXVOU62R44DSNLI \ / AMOS7 \ YOURUM ::
#\[7]5AIDYAWYLETJOKEZQAAZHTZCGSF57YJFSVE7FP7TILW6KP4WLABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
