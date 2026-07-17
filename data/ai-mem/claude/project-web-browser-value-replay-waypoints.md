---
name: project-web-browser-value-replay-waypoints
description: "direct value-injection replay + curve-smoothed exact waypoints for web-browser visualizations, follow-up to the landed input capture/replay feature"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

**LANDED 2026-07-17**, all four build steps, kimi K3 (2 dispatch rounds).
Steps 1-3 (write-back hook, curve-smoothed exact arrival, pinned
waypoints): commit f3ff56181. Step 4 (multi-window fan-out via subname
groups): commit 5de162b6e — live-verified with two real concurrent
instances landing exactly at a shared waypoint. Also surfaced and fixed a
real `access.zenki` bug (missing grant + a stray reply-handler entry that
never belonged there). Design doc:
`data/tasks/web-browser-value-replay-waypoints.md`.

Originally spun off 2026-07-16 in the session that finished
[[project-input-capture-replay-website-templates]] (all 6 build-order
steps landed: commits 9c297b9e5, 803384253, d0e823312).

**Why a second replay mode:** `window.debugZoom = zoom;` and siblings in
`visualization.html` are a one-way mirror (closure → window every frame),
confirmed by reading the source directly before proposing this — setting
`window.debugZoom` externally does nothing, the render loop overwrites it
next frame. Input-simulation replay (the landed feature) drives state by
dispatching synthetic DOM events and letting the page's own physics
compute the result — right for bug reproduction, wrong for "just land on
this exact state fast," which matters because inverting exact state from
input is genuinely hard once damping/velocity is involved (`alignRotation()`
drift already ruled out `rotX`/`rotZ` as stable `verify=` targets in the
landed feature).

**Design sketch:** (1) each page opts into a `window.__p7SetState` write-
back hook, symmetric to the existing `__p7ReplayTarget` convention; (2)
curve-smoothed arrival — interpolate via the existing `replay-synth` curve
math generalized to arbitrary named vars, then a final tolerance-checked
hard-set via `wait-state-poll` so smooth doesn't compromise exact; (3)
waypoints = named target state vectors pinned to their frontend via the
same BMW-L13 checksum mechanism recordings already use; (4) multi-window
coordination — a waypoint registry generalizing to name → {per-window
target, shared transition timing}, motivated by the project's move toward
multi-window space-embedded UIs, explicitly flagged as bigger/unsettled,
not designed in detail yet.

**Bigger picture this connects to (not scoped, captured so it isn't
lost):** see [[topic-implicit-perspective-navigation]] — curves/thresholds
as the actual navigation-decision substrate (not a separate decision layer
over smooth motion), explicit vs. implicit (interest-signal-driven
auto-framing) navigation modes over the same mechanism, and the cubic
space as ambient substrate every visualization/window is a view into
(including flat 2D "desktop plate" windows), not one more visualization
among others.

**How to apply:** when asked about waypoints, precise/exact perspective
jumps, multi-window perspective coordination, or "replay the captured
graph directly" for any web-browser visualization, this design doc plus
[[topic-implicit-perspective-navigation]] are the starting point — the
small buildable piece is (1)+(2)+(3) above; don't over-scope into (4) or
the vision-layer material without a dedicated design pass first.

## related

[[project-input-capture-replay-website-templates]] ·
[[topic-implicit-perspective-navigation]]

#,,..,,.,,.,.,.,.,.,.,,,.,.,,,..,,,,,,...,,.,,..,,...,..,,...,.,,,..,,.,.,.,.,
#AGIOYYIIFCVVE4Y27FOIUPTYZLSFMOIQQALIPZZCKXPNOOPIYUPXOELBNTUWOWAEUGD4ZCRBDG3IY
#\\\|3BM6Z3CPOIDSEDQ7SGJ2RGWQRSFE3EIIQY6RZKQTA5GCM6N2TFX \ / AMOS7 \ YOURUM ::
#\[7]4SZFKXTP47XKEWUGRBZ5U4TDTZMWVNFRK76IKYAG5CMZQ35PEECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
