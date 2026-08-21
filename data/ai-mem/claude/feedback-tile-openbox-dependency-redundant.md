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

#,,.,,.,,,.,.,..,,,,,,,,.,...,...,.,,,.,,,..,,..,,...,..,,.,,,,.,,,.,,,,.,,,.,
#4YGVU6ZWEE2N5R33PCBQXPYUBRLV3QFU6FUE3FRWVELA5MSTSY3A4PUWMACDL3DXM5A7L5DGPG7VQ
#\\\|3M4WQDYTRWHCAANRAHUQCF6FE3DHAWHORIBA2OBOI2TBGUUQXRY \ / AMOS7 \ YOURUM ::
#\[7]HCHU4MPOJ3K45GQ3IC47HGJSTOIG53J2QGQ7CAH2L3ILK7XPH4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
