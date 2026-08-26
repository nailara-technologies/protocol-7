# mpv Async Startup + Jobqueue Integration

## context

mpv zenka previously used a synchronous blocking startup: `open_control_socket`
busy-waited for the IPC socket, called `mpv.open_player` before the event loop,
and `mpv.send_command` would `exit(2)` on any undef socket. cross-zenka geometry
placement (window-place, tile) requires user confirmation with unbounded latency,
making the old linear model incorrect.

## what landed

### startup state machine (all-deferred)

`mpv.startup.init` now pushes to `system.callbacks.initialized` in every path —
player is never opened before the event loop. paths:

- **audio mode** → push `mpv.startup.job.fork_player`
- **local profile found** → set geometry, push `mpv.startup.job.fork_player`
- **placement mode** → push `mpv.startup.request_geometry` (sends `v7.notify_online`,
  reply chain: `placement_online` → `coords_reply` → `fork_player`)
- **fallback** → resolve geometry, push `mpv.startup.job.fork_player`

### async socket poll

`mpv.open_control_socket` replaced busy-wait with IO::Async timer (20ms delay,
50ms interval). `mpv.startup.handler.socket_poll` does the connection work and
calls `jobqueue.check_dependencies` when socket is ready.

### jobqueue + dependency integration

`jobqueue` added to `modules.load`. dep type `mpv_flag` registered via
`mpv.callback.object.mpv_flag` (checks named data key path). dep object
`<mpv.dep.socket>` resolves when `<mpv.socket>` is defined.

job chain:
```
fork_player (object_id=0, queued by callbacks.initialized)
  → open_player → open_control_socket (async poll starts)
  → finalize job added (dep: mpv.dep.socket)
  ↓
socket_poll finds socket → sets <mpv.socket> → check_dependencies
  ↓
finalize job runs → observe_properties + get_playlist
```

### send_command no longer hard-exits

`mpv.send_command` undef-socket path: queues command as `mpv.job.deferred_send_command`
job with `mpv.dep.socket` dep instead of `exit(2)`. commands sent before player
is ready (or after binary crash) drain automatically when socket resolves.

## modules created / modified

| module | status |
|--------|--------|
| `mpv.startup.init` | modified — all paths deferred |
| `mpv.startup.job.fork_player` | new — forks + adds finalize job |
| `mpv.startup.job.finalize` | new — observe + get_playlist |
| `mpv.callback.object.mpv_flag` | new — dep type callback |
| `mpv.open_control_socket` | rewritten — async poll |
| `mpv.startup.handler.socket_poll` | new — socket connection + check_dependencies |
| `mpv.startup.open_player` | retired (still present, not called) |
| `mpv.send_command` | modified — no exit(2), deferred queue |
| `mpv.job.deferred_send_command` | new — drains on socket dep |
| `mpv.init_code` | modified — dep setup |
| `mpv.startup.handler.coords_reply` | modified — calls fork_player |
| `mpv.startup.handler.placement_online` | modified — calls fork_player |
| `mpv.startup.request_geometry` | modified — calls fork_player |
| `cfg/zenki/mpv/zenka.v7` | modified — added jobqueue |
| `cfg/zenki/mpv/subroutine.white-list` | modified |

## open next steps

- **mpv state snapshot/restore**: capture full property map on shutdown/checkpoint;
  restore via deferred send_command queue on restart
- **visual parameter curve automation**: extend `base.curve.*` to brightness,
  contrast, gamma, saturation, shader params (same shape as existing volume fade)
- **cross-mapped curve routing**: parameter as function of another parameter or
  external signal (ambient curve, time-of-day, position)
- **player restart job**: re-fork binary on death, restore state from snapshot;
  zenka stays alive throughout
- **active curve state in snapshot**: persist curve phase so restoration resumes
  automation mid-transition rather than snapping to endpoint
- **`:twin:` restart integration**: zero-downtime player config reload using v7
  twin restart when zenka is still processing traffic

#,,.,,.,.,,.,,..,,,..,,,,,...,,.,,.,.,..,,,..,..,,...,...,,..,..,,,,,,.,.,,,.,
#CLTPFDKSI6XDILRCUHZJRVXFB6HXM4EJ6DT55J6OKENA4MKHJYHFCJTOAGLMPFR5VKXN6AB7TIT3Y
#\\\|GMPE5MWSNDB5OYH5I6BDYADMOLWNLBFATOUQXETISK3IVJTGBP2 \ / AMOS7 \ YOURUM ::
#\[7]AHAXIFLLNO3JBRXUDUL77GZMRTNCYQEWRLYB5FS657IEPHO4GABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
