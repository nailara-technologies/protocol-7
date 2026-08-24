---
name: ondemand-heartbeat-upgrade
description: "future v7 upgrade to let on-demand zenki keep heartbeat enabled without heartbeats resetting the idle timeout, plus pre-exit termination notification"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

Currently on-demand zenki (`calc`, `image2html`, etc.) conventionally set
`restart.disabled = 1` and `heartbeat.disabled = 1` alongside
`start.on-demand = 1` + `[base.zenki.set_ondemand_timeout:N]` — so v7
neither monitors nor restarts them, and they self-terminate after idle.

**2026-06-15 — tile zenka set up as a test case:** `tile` (renamed from
`tile-groups`, see [[zenka-naming-cleanup]]) was configured as
`start.on-demand = 1` with `dependencies = cube X-11 openbox set-up` and
heartbeat/restart left at default (enabled), and *no* idle-timeout call.
Rationale: tile holds live window-group/layout state used by many
always-on desktop zenki — losing heartbeat protection (crash detection +
restart) wasn't worth the idle-timeout savings, and a non-zero idle
timeout would currently be pointless anyway since the on-demand timeout
logic treats heartbeat requests like regular requests (i.e. as long as
v7 heartbeats it, it never goes idle).

**Two follow-up upgrades identified (not yet implemented):**
1. Add a "exclude heartbeat requests from resetting the on-demand idle
   timer" mode, so on-demand zenki *can* have a real idle timeout even
   with heartbeat enabled.
2. Add a pre-exit termination notification from a self-terminating
   on-demand zenka to v7, which immediately disables auto-restart +
   heartbeat for that instance *before* the zenka exits — avoiding a
   false "unresponsive" detection race. Once implemented, this would let
   *all* on-demand zenki safely run with heartbeat enabled by default
   (protected against unplanned unresponsiveness, while planned
   idle/manual shutdown still works cleanly).

**2026-08-24 — LANDED, both #1 and #2.** Implemented as: (1) `heart` is
excluded from resetting `<base.ondemand.last_activity>`
(`base.handler.command`), and `base.event.callback.io-idle-restart` arms
the idle timer with the *remaining* time since last real activity instead
of the full window every time — unconditional/automatic, no opt-in flag.
(2) `v7.idle-term` (new `src/v7.zenka.cmd.idle-term`, cloned from
`v7.zenka.cmd.restart_own-zenka`'s cube_sid→instance resolution) — an
idling zenka asks v7 to terminate it via `v7.zenka.instance.stop`, which
sets `<zenka.instance.shutdown>` *before* killing the process so
`v7.handler.zenka_status`'s override forces `shutdown` status regardless
of what was computed, meaning no restart-on-idle-exit — race-proof by
construction, no separate "unregister"/pre-stop-window step needed. v7
replies `'deferred'` and deliberately never completes it on the accept
path (the caller's about to die anyway) and explicitly deletes its own
`<base.cmd_reply>` entry, since nothing else does — see
[[p7-local-command-route-and-deferred-reply-mechanics]] for why that's
safe and what it isn't the same as. Full design writeup + verification:
`data/tasks/completed/v7-ondemand-heartbeat-idle-term.md`, commit
`0f1ba4446`. Design doc `data/md/design/ZENKA-LIFECYCLE-ONDEMAND-HEARTBEAT.md`
updated with a status note; its "configurable timeout modes" / wake
permissions / priority / WoL sections remain open, unimplemented.

**Still open:** `tile`'s `start.cfg` has *not* been updated to add a real
idle timeout — heartbeat no longer blocks it from having one, but nobody's
asked for that yet. Revisit if/when tile's idle-shutdown becomes desired.

#,,.,,...,.,.,,.,,,..,.,.,,,.,,,.,.,.,...,.,,,..,,...,...,..,,...,,,.,.,,,,.,,
#Y6K2XTTNH6DG6KNLJT4C7WELZKXN5EB7WXEQTRAFKQJZ6J5T64GLDPGXSWGE43QLLLHSPMT35RSXC
#\\\|TM3CEG3JGHYYFSB33NHY3YDD6B6YXRS4XKZBUXMRGQSSSKVUTED \ / AMOS7 \ YOURUM ::
#\[7]OSXPS3LU5WYJXEBXGU53JMG65RORSV7RQILMEZYJ2KHL7ZHGJ4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
