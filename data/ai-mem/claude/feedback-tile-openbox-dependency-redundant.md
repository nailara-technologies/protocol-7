---
name: feedback-tile-openbox-dependency-redundant
description: "tile's restart/hang problem was the openbox dependency, not on-demand config; openbox redundant under Weston"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 143295dd-3613-490e-8329-cda25b2cd167
---

The tile zenka's "flapping / hangs / won't restart cleanly" problem
(2026-06-24) was NOT the on-demand configuration and did NOT need
"make tile always-on". Root cause: tile listed **openbox** (and **set-up**)
as `dependencies` in `configuration/zenki/tile/zenka-startup.v7`. openbox is
**redundant when a window manager / compositor like Weston (WSLg) is already
running**, and the dependency was what broke clean restart.

**Fix (taeki, verified):** `dependencies = cube X-11 openbox set-up`
→ `dependencies = cube X-11 # openbox set-up`. X-11 stays the configured
dependency; its upgraded functions now cover what openbox provided, so tile
no longer needs openbox at all under Weston.

**Verified:** full backend restart with no X-11 running → `v7.start
protocol-7-menu` starts all dependencies and displays the menu; `v7.restart
X-11` restarts the menu zenka too and it reopens immediately.

**Why:** the earlier handoff theory ("tile on-demand with no keepalive → dies
on idle → cascade hang; make it always-on") was wrong about the cause.

**How to apply:** supersedes the "TILE FLAPPING / TILE HANG / make tile
always-on" notes in [[topic-async-window-startup-transition]]. Don't add
openbox as a zenka dependency when a compositor/WM is already running. If a
window zenka won't restart cleanly, suspect a redundant WM dependency before
suspecting on-demand/keepalive. Related: [[feedback-wslg-deiconify-limitation]].

#,,,.,.,.,,.,,,.,,.,.,,.,,.,,,,.,,.,.,,,,,,.,,..,,...,..,,...,,,.,,..,,,,,,,,,
#5O3XHEOYWJQT32T4VQNBMUC5INIZ6DFO5GIPHVTLV7N5VJSVO7LTBTWIPRBJ2UBPHNE6DLBM55XM4
#\\\|ONPYGOCFHPBPOKCHEGFAD2IOVVEE2ZF6L6M4ZOIMGARSO3FCQXD \ / AMOS7 \ YOURUM ::
#\[7]EA5JECTZLD6DMX3RAD6XOFZ55IIXCM2EQD2GSWDDN426QITZMMAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
