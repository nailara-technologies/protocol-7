---
name: kimi zenka state machine upgrade
description: COMPLETE — watcher-based state machine implemented, reconnect fix applied
type: project
originSessionId: 327ba945-ac12-456a-985f-690320d1550f
---
## completed (2026-05-14, session 23)

kimi zenka upgraded to `<[event.add_var]>` variable watcher state machine. task
multiplexing foundation laid. full round-trip verified: `p7c kimi.ask-reply` → "Four".

**what was built:**
- `kimi.watcher.ws_status` — Event.pm variable watcher (`repeat=>TRUE, poll=>'w'`) on
  `<kimi.ws.status>`, drives all lifecycle transitions (disconnected/connecting/ready/busy)
- `kimi.handler.dispatch_next_task` — dispatches next pending task when ws is ready
- `kimi.cmd.status` — shows ws status, task queue, active task, pending approvals
- task queue: pending/active/completed/failed arrays with `kimi.task.active_id`

**reconnect stuck bug fixed:**
- root cause: watcher doesn't fire when value written is same as current value
- symptom: `ws.status` already `disconnected`, written again → watcher silent → no retry
- fix: in `kimi.handler.ws_message` and `kimi.handler.session_liveness_timeout`,
  call `<[kimi.connect.schedule_retry]>` directly after writing `disconnected`,
  not relying solely on the watcher

## open items

- `flush_on_acquisition` inline sub extraction (coding zenka extract-inline-subs template)
- redefined warning in `kimi.handler.approval_request:81` — minor cleanup
- task multiplexing: currently max_concurrent=1; design ready for N when needed

#,,,,,,..,..,,.,,,...,,,,,..,,,.,,...,,.,,,.,,..,,...,..,,..,,,,,,,,.,.,.,.,.,
#DE4WNTMCXN5MBHPQHXETHOFT625QL7Z6ZEBB7S5DHW7UTWCEPPK2DDEMFAQKTYTVVRRPSIMSN27GG
#\\\|YL6M7FBIBIRF35CXV5DZDQJRQMBMQSKYMBY2WZQH4DIATBD5M64 \ / AMOS7 \ YOURUM ::
#\[7]CZQXNV5V2XX2DNYFLKBXPGSX62CUT7CNFLCQA7WB4K3NLL3ZUGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
