---
name: topic-mpv-jobqueue-startup
description: "mpv async startup state machine + jobqueue integration; deferred socket, send_command queuing, dep chain"
metadata: 
  node_type: memory
  type: project
  originSessionId: eec99c76-3a6c-4a57-abb3-72c98c78bcdd
---

## what landed (2026-06-18)

full async startup state machine for mpv zenka using jobqueue + dependency system:

- `mpv.startup.init` defers ALL paths via `system.callbacks.initialized` — no player open before event loop
- `mpv.open_control_socket` → async 50ms poll timer (was busy-wait blocking event loop)
- `mpv.startup.handler.socket_poll` → opens socket, calls `check_dependencies`
- `mpv.dep.socket` dep object (type `mpv_flag`) resolves when `<mpv.socket>` defined
- `mpv.startup.job.fork_player` → forks binary + queues `finalize` job with socket dep
- `mpv.startup.job.finalize` → observe_properties + get_playlist (runs when socket dep resolves)
- `mpv.send_command` → no longer `exit(2)` on undef socket; queues `mpv.job.deferred_send_command` with socket dep
- `jobqueue` added to mpv `modules.load`
- doc: `data/md/documentation/MPV-ASYNC-STARTUP-JOBQUEUE.md`

## window placement (2026-06-18)

full startup geometry flow landed:
- `mpv.startup.init` checks local profile first → fast path skips window-place
- placement mode: requests window-place.coords after cube connects; caches result locally
- `mpv.cmd.clear-profile` — clears both local + window-place saved profiles (fire-and-forget route-send)
- `mpv.cmd.reposition` — clears profiles, triggers placement UI, applies via reply handler
- `mpv.handler.reposition_reply` — parses x/y/w/h, saves profile, calls X-11.set_geometry
- `window-place.cmd.clear-profile` + `window.profile.delete` helper
- `window.place.cmd.coords` — configurable `window.place.initial_geometry.<caller>` escape hatch

**Weston/XWayland ignores `--geometry` position offset** (size is honored, position is not):
- GTK windows under XWayland position correctly; pure X11 clients (mpv x11egl) do not
- fix: after IPC socket ready (`socket_poll`), request `X-11.wait_visible`, then `X-11.set_geometry`
- `mpv.startup.handler.socket_poll` now does this when `fade_in` is disabled
- `mpv.handler.window_id_reply` — new handler; stores `<x11.id>` + calls `cube.X-11.set_geometry`
- note: `mpv.await_window_presence` is commented out in `mpv.open_player`; `x11.id` was never set before

## mpv window positioning bug RESOLVED (2026-06-19)

Symptom: mpv's window landed at the wrong/random position despite the
2026-06-18 `X-11.wait_visible` → `cube.X-11.set_geometry` fix landing —
size was honored, position wasn't. Live log showed a `Bad Window` X11
protocol error on `ConfigureWindow` (id `25165827`), forcing an X11
reconnect (the recently-added [[topic-x11-multi-server]] reconnect logic
absorbed what used to be a hard crash/restart — confirmed working as
designed).

Root cause (confirmed by user, recalled from ~11 years ago): under
Weston/WSLg, a freshly-created X11 window can exist as a resource but not
yet be "actualized"/mapped until something forces a WM refresh — `X-11.
get_window_ids` already calls `<[X-11.WM.update]>` before reading
`_NET_CLIENT_LIST` for exactly this reason, but `X-11.cmd.set_geometry`
called `ConfigureWindow` directly with no `WM.update` before *or* after.
Two distinct failures from one missing call:
- before: window not yet realized → `ConfigureWindow` throws `BadWindow`.
- after: even when `ConfigureWindow` succeeds, the new geometry doesn't
  visually take effect without a follow-up `WM.update` to push it through
  to the compositor.

Fix (landed, commit `26eea1eda`): `modules/X-11.cmd.set_geometry` now calls
`<[X-11.WM.update]>` both immediately before and immediately after
`ConfigureWindow`. User-confirmed live: mpv window now appears mapped,
correctly positioned, on the correct screen, matching the
`window-place`-selected coordinates exactly.

Note: `window.place` itself never touched mpv's actual window — it only
repositions its own decoy GTK HUD overlay and saves the resulting
coordinates to a profile (`window.profile.save`), which mpv reads back as
`<mpv.geometry>` on next startup. The `X-11.wait_visible` →
`set_geometry` chain is the only thing that ever touches mpv's real
window.

## socket-wait polling replaced with inotify + batched send_command buffer (2026-08-10, `4526a0360`)

The 50ms `mpv.open_control_socket` poll timer (`mpv.startup.handler.socket_poll`,
this doc's original "async 50ms poll timer" line above) was a polling-timer
anti-pattern per [[feedback-watcher-state-machines]]. Replaced with an
inotify `IN_CREATE` watch on `/run/.7` (`base.inotify.install_io_watcher`,
same pattern as `amos-term.plugin-install_watcher`) — fires only when the
socket file actually appears, plus a single one-shot 4.2s deadline timer as
the only remaining fallback (not a repeating poll). The per-tick `waitpid`
crash check inside the old poll handler is gone too — redundant with
`mpv.handler.stdout`/`.stderr`, which already catch the player dying via
EOF (event-driven, was already there). Handler renamed
`mpv.startup.handler.socket_poll` → `.socket_ready` (fires on the inotify
event or an immediate `-e` check for the fork/watch-install race); new
`mpv.startup.handler.socket_timeout` handles the deadline-only case.

Separately, `mpv.send_command`'s deferred-command mechanism ("queues
`mpv.job.deferred_send_command` with socket dep", described below) was the
actual root cause of a long-reported "redundant queue entries" symptom:
every command called before the socket was ready spun up a *full jobqueue
job* (job id, priority slot, dependency-tracking entry) just to hold a
string. Replaced with a plain ordered array (`<mpv.pending_commands>`) that
`mpv.startup.handler.socket_ready` replays as one batch, in call order,
right after the socket's io handler is registered. `mpv.job.
deferred_send_command` is now dead and deleted. `jobqueue` stays loaded —
`mpv.dep.socket` and the `finalize` job (observe_properties/get_playlist,
gated on the socket dependency) are untouched and still legitimate uses of
it.

Mid-fix, deferring `[base.get_session_id]` (in `configuration/zenki/mpv/
start`) until `socket_ready` looked like the correct move — it seemed to
be what unlocks cube's routing-ready flag too early — but caused a real
startup deadlock instead. See [[feedback-verify-instance-callbacks-initialized-deadlock]]
for why that specific move is a trap for *any* zenka using the
`system.callbacks.initialized` pattern, not just mpv. `get_session_id`
stays early in the start file; the "not ready — buffering" burst you'll
still see in logs at startup is expected/routine now (logged at level 2),
not a bug — cube's per-session `initialized` flag and the player's actual
IPC-socket readiness are just two different clocks that can't be fully
unified without mpv self-managing `cube.set-initialized`/`unset-initialized`
around its own fork→socket-ready window (discussed, not implemented —
closes the window, doesn't eliminate it, given as an option to the user
and declined for this pass).

A second, related v7-handshake gotcha surfaced and got fully fixed in a
follow-up pass, live-verified on the `site-yaml` zenka (which silences
console by design, `system.zenka.verbosity.console = 0`): v7's entire
verify-instance handshake is driven by scraping two specific console log
lines (`cube session id received [...]` and `instance verification
[KEY:...]`), not by any reply or by `send_init_reports` — a silenced
console verbosity drops either line entirely and produces the identical
hang/restart-loop symptom even though the zenka itself runs fine. Initial
fix only patched the KEY line in `base.cmd.verify-instance`; the real
blocker turned out to be earlier, in `base.get_session_id`/
`base.handler.whoami_reply`'s "cube session id received" line, which is
what triggers v7 to send verify-instance in the first place. New shared
helper `base.log.forced_console` fixes all three call sites. See
[[feedback-verify-instance-callbacks-initialized-deadlock]] for the full
mechanism and the `and`/`or`-precedence bug caught writing the helper.

## open work

- ~~**state snapshot/restore**~~ **DONE** (`218cc382b`, 2026-07-31) —
  see [[topic-mpv-persistence]] layers 1-2; restore ended up synchronous
  from `mpv.startup.job.finalize`, not via the deferred queue as
  originally planned here
- **visual curve automation**: brightness/contrast/gamma/saturation via `base.curve.*` (same as volume)
- **cross-mapped curves**: parameter driven by another param or external signal
- **player restart job**: re-fork on binary death, zenka stays alive, restore from snapshot
- **active curve state in snapshot**: resume automation mid-transition on restore
- **`:twin:` restart**: zero-downtime reload via v7 twin parameter
- **async X-11 monitor registry**: replace all xrandr/synchronous monitor queries; user flagged as "next on the list"

## architecture notes

the deferred send_command queue is the state buffer for restart scenarios:
commands sent before player ready (startup) or after binary crash both queue
safely and drain when socket resolves. the zenka surviving binary death is the
unlock for self-healing and restart-with-restore patterns.

**Why:** exit(2) was from kiosk mode — crash+restart was the recovery strategy.
now zenka stays alive to manage state, fallback chains, and LLM-assisted repair.

**How to apply:** any mpv command that fires during startup is safe; any recovery
logic that needs the player socket uses mpv.dep.socket as its dependency.

[[topic-self-improving-system]]
[[topic-mpv-persistence]]

#,,,.,,,,,,,,,.,.,,,.,.,,,..,,,,,,,,.,.,,,,,.,..,,...,...,..,,.,,,.,.,,..,,,,,
#BWLXY4DIRSSAIODO4OSX23JTJYGDZUPMDHVSB6OOFGGUBWEOUQLFBXL2BG4Q4IH4QGP4XAWRLUT26
#\\\|WAWXD4O4WOGN4PEHYJ5HHGV32CTRPE4FGKICQK4VQJ6DOJKL3Z7 \ / AMOS7 \ YOURUM ::
#\[7]Q3GYW5YK2JFFVPZNFLCIQUJ66MNUAFBY3SIQ36Q2UNFLXXIWMACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
