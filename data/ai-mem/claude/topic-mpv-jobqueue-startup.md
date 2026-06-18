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

## open work

- **state snapshot/restore**: full property map save on shutdown; restore via deferred queue
- **visual curve automation**: brightness/contrast/gamma/saturation via `base.curve.*` (same as volume)
- **cross-mapped curves**: parameter driven by another param or external signal
- **player restart job**: re-fork on binary death, zenka stays alive, restore from snapshot
- **active curve state in snapshot**: resume automation mid-transition on restore
- **`:twin:` restart**: zero-downtime reload via v7 twin parameter

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

#,,,.,,,,,.,,,,,,,,.,,..,,,,,,,,,,,..,,,.,.,.,..,,...,...,.,.,..,,.,.,,,.,..,,
#KFOMFDHQRLE47JJ6LCF5V3P6QRRRSJMT5JZ2YZWJ5D34TCIURYPLGQ35QHCYBEYG47J3VTS55IBKM
#\\\|U3WKOTXW7O3LOMK3WZCTUTDMPYK2PCU6CEAKO5W7EH53OV42FOQ \ / AMOS7 \ YOURUM ::
#\[7]O24XJRTJYKQKK37RT5R5IBTHVONLQNHBBPTQ37UWU2VC2WNBH6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
