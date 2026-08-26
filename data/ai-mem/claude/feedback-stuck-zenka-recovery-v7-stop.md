---
name: feedback-stuck-zenka-recovery-v7-stop
description: a zenka blocked inside a synchronous call (e.g. a bad blocking-socket-read implementation) can't be recovered with v7.restart -- the stuck process can't process its own restart command either. Use v7.stop, which sends TERM then KILL. Also set max_concurrency on any on-demand zenka susceptible to this, or a racing v7.start during the hang spawns a second live instance.
metadata:
  type: feedback
  originSessionId: bb701c28-fcf8-43e8-aab4-bbd5dfd0b711
  modified: 2026-08-11
---

Hit live 2026-08-11 building `users.cmd.remote-fetch` (see
[[bug-auth-keypair-client-composition-gotchas]]): an early version did a
blocking socket read that self-deadlocked the whole `users` zenka (single-
threaded event loop, waiting on its own reply via a same-process loopback).

**`v7.restart <zenka>` could not recover it.** Restart is itself a command
routed TO the target zenka's own session — a process stuck inside a
blocking call can't process ANY incoming command, including a request to
restart itself. The restart call just queues/times out silently.

**`v7.stop <zenka>` did.** Per user: it sends TERM first, then KILL — an
OS-level signal path, not an in-band command the stuck process has to
cooperate with. Confirmed working: `p7c v7.stop users` killed the hung PID
cleanly (`<KILL>ed children : <pid>`) and the zenka came back on-demand on
the next call.

**Compounding gotcha:** while the original instance was stuck, a `v7.start`
attempt aimed at "fixing" it instead spawned a SECOND live instance
(`v7.stop` later reported "there were 2 of them running"). The zenka had no
`max_concurrency` set in its `start.cfg` — added `max_concurrency = 1`
afterward (precedent: `cfg/zenki/image2html/start.cfg`,
`cfg/zenki/window-place/start.cfg` already had it).

**How to apply:**
- If a zenka stops responding to ANY command (not just one specific call
  failing) while a background/deferred command is in flight, suspect it's
  blocked synchronously, not crashed — check for a recent blocking I/O call
  (socket read, subprocess wait) added without an event-driven or
  timeout-guarded alternative.
- Recover with `p7c v7.stop <zenka>` (TERM then KILL), not `v7.restart` —
  the latter is a no-op against a genuinely stuck process.
- Before landing any on-demand zenka susceptible to this pattern, set
  `max_concurrency = 1` in its `start.cfg` so a recovery-attempt
  race can't produce duplicate live instances.
- The real fix is architectural, not procedural: hand any post-handshake
  ongoing I/O to the normal event-driven session/command-dispatch
  machinery (`base.session.init` + `base.session.init_state`) instead of
  blocking reads — see [[bug-auth-keypair-client-composition-gotchas]]
  item 8 for the concrete before/after.

[[bug-auth-keypair-client-composition-gotchas]]

#,,..,,,,,,,.,,.,,,..,,.,,,..,..,,,,.,.,.,,..,..,,...,...,..,,,,,,,,.,.,.,,..,
#S6XUN3SM7C2VQX6CJYURNIPOTCE4KGG2X5VD6HDCLUJBPCOPRNC6AYEU2TNEC3DI56TDZLCUYN3Z6
#\\\|GFHKPTRKBEY3FH7UGL3FX67Y7DWYV46CK2EYX2NVEMXNXI46EHF \ / AMOS7 \ YOURUM ::
#\[7]QLNBLIE4XOOMRN6VIJ4EF75WQBUSJFKKB2RXH3JSTX4QLAHSDACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
