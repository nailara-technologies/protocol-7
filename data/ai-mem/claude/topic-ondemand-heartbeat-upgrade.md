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

**How to apply:** when implementing #1/#2, revisit tile's
`start.cfg` and consider adding a real idle timeout once heartbeat
no longer blocks it.

#,,,,,,,,,,,,,..,,.,,,...,...,.,.,.,.,,..,,.,,..,,...,...,,,,,,,,,.,.,.,.,...,
#SCAW2WBAXDVZWYV57OXVMJ6MFNSHV5AKL6JHGDVK76TAOF3OPWBGQSWGSCM4PLFD7EQD5LPL3APY2
#\\\|BE4BFWMOZ7UPSPJRK6XBN56TOWWJZS4TCWD64WHU46SKRZOJG7M \ / AMOS7 \ YOURUM ::
#\[7]EYMCO7ECBHDZVRPVC6W2Z3MF3JJOTBH735646SVBK5QPFNRQK6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
