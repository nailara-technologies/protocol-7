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
as `dependencies` in `cfg/zenki/tile/start.cfg`. openbox is
**redundant when a window manager / compositor like Weston (WSLg) is already
running**, and the dependency was what broke clean restart.

**Fix (taeki, verified):** `dependencies = cube X-11 openbox set-up`
→ `dependencies = cube X-11 # openbox set-up`. X-11 stays the configured
dependency; its upgraded functions now cover what openbox provided, so tile
no longer needs openbox at all under Weston.

**Verified:** full backend restart with no X-11 running → `v7-zenki.start
protocol-7-menu` starts all dependencies and displays the menu; `v7-zenki.restart
X-11` restarts the menu zenka too and it reopens immediately.

**Why:** the earlier handoff theory ("tile on-demand with no keepalive → dies
on idle → cascade hang; make it always-on") was wrong about the cause.

**How to apply:** supersedes the "TILE FLAPPING / TILE HANG / make tile
always-on" notes in [[topic-async-window-startup-transition]]. Don't add
openbox as a zenka dependency when a compositor/WM is already running. If a
window zenka won't restart cleanly, suspect a redundant WM dependency before
suspecting on-demand/keepalive. Related: [[feedback-wslg-deiconify-limitation]].

#,,..,,,.,,,.,.,.,,,,,,,.,.,.,,..,,,,,,..,,,.,..,,...,...,.,,,.,.,..,,..,,,,.,
#SG6AQJSSUZB6COQ2NPBTMOKC6E26CDMX44TDEC5AG64RMRI6RAB2Y6QINBIFLLXDGU32DEFQZBJGI
#\\\|F5GIA6C3BCBTNG54G4AZSSNMKVSLW5LM3O6J7SYRLCDRKNXQO3D \ / AMOS7 \ YOURUM ::
#\[7]A3WAXGBAJP5YWTYVQ3L2VT23F43NEMT7QXIRI4X5CRJFNXUDIWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
