---
name: session-69
description: "session-69: :twin: zero-downtime restart — full implementation for web, httpd, coding zenki"
metadata: 
  node_type: memory
  type: project
  originSessionId: a11c6251-11c5-4768-866e-4edabf9840e5
---

## session-69 summary (2026-06-01)

### what was built: v7.restart :twin: — zero-downtime concurrent restart

`v7.restart :twin: <zenka>` starts a replacement alongside the running instance,
drains old one gracefully, suppresses restart, leaves exactly one instance running.

**key commits (branch: base):**
- `5b46da166` — twin restart fixes (double-instance, ambiguity, notify_online)
- `a6786a81b` — drain fix, ghost cleanup, restart suppression
- `04e3b6014` — cube backchannel + web.cmd.drain + restore on failure
- `4ea13894f` — namespace swap fix + drain command routing
- `c75fcfe58` — coding :twin: drain + spawn resilience

### architecture decisions

**concurrency fix**: `zenka.cmd.start` with `concurrent-handover` BEFORE
`zenka.instance.track_handover` — doing track_handover first pushed count to 2,
blocking the expansion slot check (needs count == max_concurrency exactly).

**drain routing**: `protocol-7.command.send.local` with `root_sid.cube_sid.drain`
pattern (from heartbeat module) — route-send was not delivering in v7 context.
access.zenki: `drain` added to `access.cmd.usr.*` (general) so cube can forward it.

**cube backchannel**: `cube.cmd.unset-initialized` pauses command delivery to old
zenka after drain is sent (send drain FIRST while initialized, THEN unset).

**restart suppression**: in `v7.handler.zenka_status`, capture `being_replaced_by`
before `handover_cleanup`, check if new instance is online → suppress restart of old.
Restore `cube.set-initialized` on old if new twin fails startup.

**namespace swap**: `v7.zenka.*` subroutine names unavailable after `base.swap_subs`
runs — use `zenka.instance.track_handover` / `zenka.instance.handover_cleanup`.

### coding zenka :twin: specifics

**await_resources mode**: if GPU port 8000 occupied at init, skip spawn timer,
start 3s polling timer. polls sibling pid files (`state/inference.gpu.*.pid`
excluding own `$$`), checks `/proc/$old_pid` for process existence.
`async_spawn_inference_servers` returns FALSE silently when `<coding.awaiting_resources>`
set — prevents model_path_reply + deferred timer from spawning during handover.

**drain**: `coding.cmd.drain` sets `<coding.draining>`, `drain_check` waits for
both task queue empty AND no active `coding.state.backend` lock (in-flight inference).
`inference_crash_restart` + `inference_server_sigchld` both skip when draining.

**drain_timeout**: 300s in `cfg/zenki/coding/start` — allows long
inference rounds to complete before force-kill.

**instance-scoped pid files**: `state/inference.gpu.$$.pid` — prevents spawn_inference_server
orphan scan from killing sibling instance's live GPU server.

#,,..,.,.,,.,,.,,,,..,.,.,,,,,,..,,,,,..,,,..,..,,...,...,.,,,.,,,,,,,,..,,,.,
#AW4VMOFJX4WUC6G4WQNFLM2QEGG4QXMZFXEOQC3JS7URX2GIKM3IIAMPGFRTPGWKKW43Y5S35IGHO
#\\\|GNUMEK6IZ6GFUY35V2J6SXLE73F44TM4FLIX6YAYGMKE7BF2PUN \ / AMOS7 \ YOURUM ::
#\[7]GFU7VXYXJTSHIFYDO7IB55EXAAFXJYJOG2UBLWJADPXED76HGICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
