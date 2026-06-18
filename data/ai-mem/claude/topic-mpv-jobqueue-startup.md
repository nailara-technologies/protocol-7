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

## open work

- **state snapshot/restore**: full property map save on shutdown; restore via deferred queue
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

#,,,.,,,.,.,,,,,,,,,.,,,.,,..,,.,,,.,,,.,,,,,,..,,...,...,.,.,..,,.,.,.,.,,,.,
#HZQFBCUGROIVFEEG3TIPGOHML6EXCXLHY5J6SBGJ6YPRBLBK6I4GDC367SVWUSIVXU5LZVU2I3HZ2
#\\\|ZRJAE3JXIRT55I653OIM5IBFXMP7SHDYQO47ULVG2HNFTJ7DOZL \ / AMOS7 \ YOURUM ::
#\[7]B7ISWJDR4GIGCF6EOBEM6SMDBQWK43XYCHTLLMNIYCULRCJHW2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
