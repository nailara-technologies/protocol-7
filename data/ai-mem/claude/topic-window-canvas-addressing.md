---
name: window-canvas-addressing
description: window.canvas.* as first-class addressable counterpart to window.profile.*; canvas + canvas-group identity resolved as a specific application of the existing checksum-addressing scheme (TYPE:CHKSUM7:ADDR_B32), not a new primitive — implementation not started
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

`src/window.profile.calculate` computes window geometry as percentages
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

## identity model (converged 2026-07-11)

Canvas identity is **(b) a specific application of the existing
checksum-addressing scheme** from [[topic-checksum-addressing]] — same
`TYPE:CHKSUM7:ADDR_B32` P7REF format, with canvases and canvas-groups as
two new `TYPE` values (`CANVAS:`, `CGROUP:` or similar). It is NOT a new
addressing primitive, and it is NOT a direct use of C25519 keys.

**Why not a new primitive.** The seed design's "unique-address +
free-parallel-groupings-of-the-same-thing" pattern is not novel here —
it's what checksum-addressing already does everywhere else in the
project. AMOS7 checksums provide context-free content identity; named
tree paths ([[topic-addressing-trinity]]) express *membership* in a
group; the same underlying entity can appear at many tree positions in
many groups simultaneously without its checksum changing. Models,
tasks, dep edges, consensus groups, remote nodes already work this way.
A canvas is just another entity type — introducing a fourth "routable
public key" axis for it alone would duplicate what the checksum axis
already delivers, and would fragment routing so canvas-groups couldn't
share [[topic-checksum-tree-wire]] separators / [[topic-routing-crystal]]
resonance-field geometry with the rest of the network.

**Why not C25519.** [[feedback-source-identity-spoofing]] establishes
C25519 as the *security-boundary* identity for authenticated actors
(zenka, user) — "who can send this message." Canvases are addressable
*objects*, not authenticated senders; they don't sign, don't act, and
don't need to prove they are themselves. Where C25519 does enter is at
the *owner* of a controllable canvas (the X-11 zenka that spawned an
Xvfb, or the user whose physical monitor it is) — the canvas inherits
authority from its owner's key-tree identity, but its own address is
still a checksum, not a pubkey. Reusing C25519 as canvas identity would
either invent an unnecessary key per Xvfb spawn or (worse) treat a
physical monitor's EDID as if it were a security credential — exactly
the "hostname as boundary" mistake that feedback memory warns against.

## two-part identity for topology-relative physical canvases

Concrete scheme, in the primitives from the section above:

- **stable physical handle** = `CANVAS:CHKSUM7(EDID_or_output_identity):ADDR_B32`
  — an AMOS7 checksum computed over the monitor's invariant physical
  descriptors (EDID bytes if available, else `output_name + serial +
  connector` fallback). This is content-identity: the physical device's
  *content* is its own descriptor block, so the same monitor always
  produces the same checksum regardless of which host it's plugged into
  or which group it currently belongs to. Owner's C25519 key-tree
  ([[feedback-source-identity-spoofing]], [[topic-key-tree-ring-routing]])
  scopes *which* physical-canvas-registry this checksum resolves in — so
  two different users can each have a monitor with a colliding EDID
  without cross-talk.
- **group-scoped logical address** = a **named-tree path**
  ([[topic-addressing-trinity]]) inside a canvas-group node, where the
  canvas-group itself is `CGROUP:CHKSUM7(sorted-member-checksums):ADDR_B32`.
  When group composition changes, the group's checksum changes (it's a
  content-checksum over its members, so a different membership = a
  different group entity), and the same physical canvas may sit at a
  different tree-path position inside the new group. The physical
  handle from bullet 1 is unchanged; only the group and the position
  within it change. This is the exact "same underlying thing in multiple
  simultaneous parallel groupings" pattern, expressed with primitives
  that already exist.

Profiles ([[topic-x11-resolution-profiles]]) attach to the
*group + tree-path* pair (the "role a canvas plays in this group-shape"),
not to the physical handle, which is what the seed design's
"profile is per-group-shape, not per-monitor" observation was already
gesturing at.

## virtual / controllable canvases (Xvfb, Xephyr)

Same primitive family, simpler case. Identity checksum is derived at
creation time from the spawn parameters —
`CANVAS:CHKSUM7(mode:WxH:owner_key_id:ntime):ADDR_B32` — using the
timestamp axis of [[topic-addressing-trinity]] to disambiguate multiple
parallel Xvfb instances spawned from the same config. Because these are
created with known identity, there is no topology-dependency: the
canvas-group they belong to is just "the owner's own controllable
canvases," a stable group whose checksum only changes when the owner
adds or drops one of its own instances. Named resolution profiles from
[[topic-x11-resolution-profiles]] become properties of the canvas
entity directly (part of what the checksum is computed over), which is
why the `xvfb:WxH` subname sketch there is already implicitly
content-addressing — the WxH is part of the canvas's identity content.

The identity scheme is the same TYPE/CHKSUM7/ADDR_B32 shape as physical
canvases; the difference is only that virtual canvases skip the
two-part physical-handle + group-scoped-logical-address split, because
their "physical handle" and "group position" are both determined by the
owner at creation and don't drift.

## universal-primitive generalization: scope back

The seed design's read that this pattern generalizes to "channels,
nodes, and groups of nodes generally" is directionally correct but was
mis-framed as needing a *new* primitive. The correct restatement:
channels, nodes, and node-groups **already** use this exact pattern —
checksum identity + named-tree membership + parallel groupings — under
[[topic-checksum-addressing]] and [[topic-reference-bubble]]. Canvases
joining that scheme is the news; the scheme itself is not. So:

- **for now**: implement canvas identity strictly as another `TYPE`
  under the existing P7REF format. No new primitive, no new routing
  layer, no parallel key mechanism.
- **do not** carve out "canvas-group" as a distinct concept from the
  general node-group machinery in [[topic-reference-bubble]] /
  [[topic-node-group-geometry]] — a canvas-group is a node-group whose
  members happen to be canvas-typed nodes.
- future channels / other-object types that need to be first-class
  addressable should be added the same way (new `TYPE` value), not by
  reopening the primitive question.

## status

Identity model decided (2026-07-11) — canvases and canvas-groups are
new `TYPE` values under existing `TYPE:CHKSUM7:ADDR_B32` addressing, no
new primitive. Implementation not started. Natural next step: a task
file similar to `data/tasks/x11-connection-pool.md`, scoped to what
`X-11.servers` already tracks (X displays, Xvfb included) with the
first real use case being the named-resolution-profile need from
[[topic-x11-resolution-profiles]] (profiles attach to canvas checksum
content for virtual canvases, to group+tree-path for physical ones).

## related

[[topic-x11-resolution-profiles]] · [[topic-x11-multi-server]] ·
[[topic-x11-protocol-hardening]] · [[topic-addressing-trinity]] ·
[[topic-checksum-addressing]] · [[topic-routing-crystal]] ·
[[topic-reference-bubble]] · [[feedback-source-identity-spoofing]]

#,,,,,...,.,,,,,,,..,,,,.,,.,,..,,.,.,,,,,,.,,..,,...,...,.,.,,.,,,.,,,..,,,.,
#ZMXSYHS2RZZT6ISIB3SQD4FJVLYETELXLJIFQYKIGM4CF3LAIY7IGOCRFOVXQMXNKACHZEWFUFE76
#\\\|2436TVZFVATDRNHWTXIFDOLQX2FMGUNA3K2K5A5ULTOC2BSKW7M \ / AMOS7 \ YOURUM ::
#\[7]L6LWYTSXMKJU52NEUNB6OZ5PDFKC2B5FHEPWKZ2YIXOJLUBW74AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
