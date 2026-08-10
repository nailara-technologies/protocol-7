---
name: feedback-verify-instance-callbacks-initialized-deadlock
description: "system.callbacks.initialized is only drained by v7's verify-instance handshake, which itself depends on an early get_session_id call — deferring get_session_id past any callback pushed onto that array deadlocks startup"
metadata:
  type: feedback
---

Never defer `[base.get_session_id]` (or `base.async.get_session_id`) past whatever
a zenka pushes onto `<system.callbacks.initialized>` in its own `*_init`/start
sequence.

**Why:** `<system.callbacks.initialized>` (pushed to by many zenki's init code —
`coding.init_code`, `index.init_code`, `tile.init_code`, `ticker.init_code`,
`web-browser.init_code`, `mpv.startup.init`, and others) is drained by exactly one
place: `base.cmd.verify-instance`, a command **only v7 sends**, as part of v7's own
startup handshake for that instance. v7 can't send it until it learns the instance
exists, which happens via `base.session.send_init_reports` (armed as a timer in
`base.net.connect`) delivering a pending report to v7 — and `send_init_reports`
refuses to send *anything* until `<system.zenka.initialized>` (a **different**, local
flag) is true. That flag is only set inside `base.get_session_id` /
`base.handler.whoami_reply`, once the `whoami` round-trip to cube completes.

So the real dependency chain is:

```
get_session_id → <system.zenka.initialized>=TRUE → send_init_reports fires
  → v7 learns about the instance → v7 sends verify-instance
  → base.cmd.verify-instance drains <system.callbacks.initialized>
  → whatever real startup work (fork_player, open_window, ...) was deferred there runs
```

If any callback pushed onto `<system.callbacks.initialized>` is itself a
precondition for `get_session_id` running (e.g. "call it once the socket this
callback opens is ready"), the chain is circular and nothing ever moves — the
instance sits in v7's `starting` status forever, `send_init_reports` logs
"delaying sending init reports [ zenka is not initialized yet ]" on a growing
backoff, and v7's `verify_instance` timeout (`v7.timeout.verify_instance`, default
13s) fires and restarts the instance — forever, since the same deadlock recurs
every restart.

**How to apply:** when a zenka's start file calls `get_session_id`, keep it before
any step whose completion the zenka's own deferred (`system.callbacks.initialized`)
work depends on — normally that means keeping it early/unconditional, exactly where
it already is in most start files. It is safe to call it again later (e.g. once a
resource the zenka manages, like an IPC socket, is truly ready) purely for
documentation/clarity — `base.handler.whoami_reply`'s "already have a cube sid,
refused to request another" guard makes the second call a harmless no-op, but it's
also pure log noise once you know it can never do anything: prefer not adding it
unless there's a real reason to re-request post-ready.

Diagnosis path when this happens: check whether `verify-instance`'s own log line
(`instance verification [KEY:...]`) ever appears in the zenka's own buffer
(`p7c <zenka>.show-buffer "zenka <N>"`) — if it never does, this deadlock (or a
variant of it) is the cause, not whatever the deferred callback itself does.
Confirmed live 2026-08-10 in [[topic-mpv-jobqueue-startup]] — `mpv.open_player`'s
own "starting mpv player.," log line never appeared either, proving the fork itself
never ran, before any code inside the deferred callback could be blamed.

Distinct from, and not to be confused with, cube's *routing* gate
(`$data{'session'}{$sid}{'initialized'}`, flipped by `cube.cmd.set-initialized`,
which v7 also calls as a side effect of the same verify-instance success). That
flag controls whether cube relays fresh commands to the session at all — it is not
what causes this deadlock, and delaying `get_session_id` does not delay it either
(v7 flips it as soon as verify-instance succeeds, essentially concurrently with
whatever fork/startup work that same event releases — see
[[topic-mpv-jobqueue-startup]] for why that specific gap can't be closed by
session-id timing).

[[topic-mpv-jobqueue-startup]]

#,,,.,,,,,...,,,,,...,..,,.,,,,.,,,..,...,,..,..,,...,...,...,...,.,.,.,,,..,,
#MJRJWD7HEZON5GCLKNDJPK2HMZTOROUB6CDT2EXEGGYSR3YUYJBDN2HE4T2MTH26CCJP3THWG43TC
#\\\|7UJ323Z3VDIQKMZD7J5H2APSBRK3OCMU7KILEKMY4KFVLBTY2AI \ / AMOS7 \ YOURUM ::
#\[7]ARYF6ZPXJWFRIA7EIJA6JIFEHVUOFFXHD4F3MTA7P5U7NMM53SCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
