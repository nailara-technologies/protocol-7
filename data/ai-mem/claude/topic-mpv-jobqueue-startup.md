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

#,,,,,,,,,,,,,.,.,...,..,,,,,,..,,..,,,,,,...,..,,...,...,,,,,,,,,,,,,,,.,,,.,
#2S4W6UKULRL3YSRSCM7EZXUJFTJV3I6NU7P3IJ2B5ALN2TWQAGIQIFVBK2E5A4H5IOE44PUF4TNCS
#\\\|AZK3CPHNIJ3ROQYRJP63MKBBM6MEIPMU5YF54GV6N546EQVAFDS \ / AMOS7 \ YOURUM ::
#\[7]5OMVZUBFPVOA6LDCEWEDLBG7TNDA5FFUVSDKZ7R4OCNOOLWANOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
