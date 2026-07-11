---
name: window-canvas-addressing
description: seed design — window.canvas.* as first-class addressable counterpart to window.profile.*, for screens/displays (physical, virtual, networked) as groupable, uniquely-addressable primitives
metadata:
  node_type: memory
  type: project
  originSessionId: cdc77f2e-a114-4ee9-98d3-e13ad338f3b3
---

## origin

Surfaced 2026-07-11, same session as [[topic-x11-protocol-hardening]]'s
connection pool, while looking at what's next after [[topic-x11-resolution-profiles]]
(Xvfb becoming a general-purpose headless-render backend needing named
per-purpose resolution profiles, not just one fixed appliance-sim size).

## the gap

`modules/window.profile.calculate` computes window geometry as percentages
of a screen, but the screen itself is just raw caller-supplied numbers
(`screen_w`/`screen_h`/`screen_x`/`screen_y`) — nothing treats the canvas
(the display itself, physical or virtual) as a first-class addressable
object. `X-11.servers` (from the multi-server work,
[[topic-x11-multi-server]]) already tracks multiple X displays but doesn't
connect to window-placement percentages at all except via manually-passed
dimensions. A `window.canvas.*` counterpart would make the canvas itself
the addressed/registered thing, with `window.profile.calculate` taking a
canvas reference instead of raw numbers — and giving the resolution-profile
work (per-purpose named Xvfb sizes) a natural home as a property of a
canvas, not a separate parallel mechanism.

## two canvas categories, different identity models

1. **Topology-relative physical canvases** — a monitor's logical address
   is not a stable property of the device alone; it's a function of
   *(device, current group composition)*. The same physical monitor in a
   2-screen setup vs a 3-screen setup on the same host gets a different
   logical slot, because added screen space redistributes where windows
   land across the whole group. Identity needs two parts: a stable
   physical handle (EDID / output name or similar) plus a
   group-topology-scoped logical address that can shift when the group's
   composition changes. The "profile" here is really per-*group-shape*,
   not per-monitor.

2. **Controllable/virtual canvases** — Xvfb/Xephyr, where protocol-7 has
   direct lifecycle authority: create, destroy, presumably power on/off,
   and spin up N parallel instances from the same config on demand. No
   topology-dependency problem, since these don't pre-exist independently
   — they're summoned with their identity already known at creation time.

A single canvas abstraction needs to cleanly support both "found and
topology-addressed" and "created and directly owned" without treating
every canvas as the same kind of object.

## generalizing direction (not yet converged)

User's read: canvas identity will likely bottom out to something
uniquely addressable — like a routable public key — with different
parallel *groupings* of that same underlying thing able to freely coexist
(the same physical monitor can belong to multiple simultaneous logical
groupings depending on which "shape" is currently active). This isn't
canvas-specific — it's read as a universal primitive: the same
unique-address + free-parallel-grouping pattern should apply to channels,
nodes, and groups of nodes generally, not just screens.

This lines up with — but hasn't yet been explicitly reconciled against —
existing addressing vision already in memory:
- [[topic-addressing-trinity]] — named tree / checksum / timestamp as
  three orthogonal identity primitives; a canvas's "routable public key"
  identity would be a fourth axis, or might fold into the checksum axis
- [[topic-checksum-addressing]] — AMOS checksums as universal routing
  primitive already extended to models/tasks/deps/consensus-groups/remote
  nodes; canvases and canvas-groups would be a natural additional entity
  type under the same `TYPE:CHKSUM7:ADDR_B32` scheme
- [[topic-routing-crystal]], [[topic-reference-bubble]] — existing
  node/group topology and routing designs this would need to sit inside
  rather than duplicate
- C25519 keys are already the established security/identity boundary
  elsewhere ([[feedback-source-identity-spoofing]]) — "routable public
  key" as canvas identity may literally mean reusing that same mechanism,
  not inventing a new one

Not yet decided: whether canvas identity is a new primitive or a specific
application of one of the above existing ones. Worth reconciling before
implementation starts, since building a bespoke canvas-addressing scheme
that later needs folding into the checksum/C25519 addressing already used
everywhere else would be wasted work.

## status

Pure design/vision stage, nothing implemented. Natural next step once
this reconciles: a task file similar to
`data/tasks/x11-connection-pool.md`, scoped first to what `X-11.servers`
already tracks (X displays, Xvfb included) rather than the full "any
screen over the network" scope, per the earlier scoping recommendation in
this same conversation.

## related

[[topic-x11-resolution-profiles]] · [[topic-x11-multi-server]] ·
[[topic-x11-protocol-hardening]] · [[topic-addressing-trinity]] ·
[[topic-checksum-addressing]] · [[topic-routing-crystal]] ·
[[topic-reference-bubble]] · [[feedback-source-identity-spoofing]]

#,,,.,.,,,,,.,,.,,,,,,,.,,,.,,,,,,,,,,..,,,..,..,,...,..,,...,.,.,.,,,,,.,,,,,
#TH3MT24336X3VSHBSIQWZJ6EKSUMXPLQU7WRXY2YPUCF4K4K6X2Z6ZAPGL27KQLV35RLRXX72PBYE
#\\\|MLFDZN2FZPWN2CLHFEOIYWS3JGKVQOL63LRH4VBXTNQ3VMAUWV5 \ / AMOS7 \ YOURUM ::
#\[7]ODGF7OIW7B5DH2NVTYREF6DNREA4GPW3YKC675MQQIEGODS6FIAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
