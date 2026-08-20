# Window canvas addressing: reconcile identity model against existing addressing vision

## what this is

A research/synthesis task, not an implementation task. No code should be
written or modified. The deliverable is a design decision, written up as
a memory update, that a later implementation task will build on.

## context, read first

`data/ai-mem/claude/topic-window-canvas-addressing.md` — the seed design.
Read it fully first; it frames the problem precisely and lists the open
question this task exists to answer. Short version: protocol-7 needs a
`window.canvas.*` counterpart to the existing `modules/window.profile.*`
family, treating screens/displays (physical and virtual — Xvfb, Xephyr,
eventually networked/remote) as first-class addressable objects instead
of raw caller-supplied pixel dimensions. Two canvas categories were
identified with different identity needs: topology-relative physical
canvases (a monitor's logical address depends on the current screen-group
composition, not just the device) vs. directly-owned controllable/virtual
canvases (Xvfb/Xephyr — created, destroyed, duplicated on demand).

The open question: canvas identity was speculated to bottom out to
something uniquely addressable (a routable public key), with free
parallel groupings of the same underlying thing coexisting — and that
this isn't canvas-specific, it's a candidate universal primitive that
should also apply to channels, nodes, and groups of nodes generally.
**This was not reconciled against protocol-7's existing addressing
vision before being written down — that reconciliation is this task.**

## what to read

Read all of these before forming a conclusion — the point is to check
whether the seed design's intuition is actually novel or whether it's a
specific case of something already designed elsewhere in this project's
several years of accumulated architecture work:

- `data/ai-mem/claude/topic-addressing-trinity.md` — three orthogonal
  identity primitives already established: named tree (`a.b.c`),
  checksums (AMOS7/BMW, content-identity), timestamps (temporal
  identity). Does "routable public key" fit as a fourth axis, or is it
  actually redundant with (or a specific encoding of) one of these three?
- `data/ai-mem/claude/topic-checksum-addressing.md` — AMOS checksums
  already used as a universal routing primitive across models, tasks,
  dependency edges, consensus groups, and remote nodes, with a
  `TYPE:CHKSUM7:ADDR_B32` coordinate format. If canvases/canvas-groups
  are just another `TYPE` under this existing scheme, the "new universal
  primitive" framing in the seed design may be unnecessary — check
  concretely whether canvas/group identity maps cleanly onto this format
  or whether something about the topology-relative case (identity that
  legitimately *changes* when group composition changes) breaks an
  assumption this scheme relies on.
- `data/ai-mem/claude/topic-routing-crystal.md`, `data/ai-mem/claude/topic-checksum-tree-wire.md`,
  `data/ai-mem/claude/topic-tree-protocol.md` — existing routing/wire
  design this would need to sit inside, not duplicate.
- `data/ai-mem/claude/topic-reference-bubble.md` and its design doc
  `data/md/design/DANCING-ZENKI-RHIZOME-STATE.md` — existing
  node/group/traveling-state design. Pay particular attention to whether
  this already has a notion of "the same underlying thing participating
  in multiple simultaneous groupings" — that's the exact shape of the
  topology-relative canvas problem (one physical monitor, multiple
  possible group-shapes) and may already be solved here in a more general
  form.
- `data/ai-mem/claude/feedback-source-identity-spoofing.md` — C25519 keys
  are already the established security/identity boundary elsewhere in
  this project ("hostname strings aren't a security boundary, C25519
  is"). If "routable public key" is meant literally, check whether this
  means reusing the *exact same* C25519 key mechanism used for zenka/user
  identity elsewhere, not inventing a parallel key system for canvases.
- `data/ai-mem/claude/topic-node-group-geometry.md`,
  `data/ai-mem/claude/topic-addressing-trinity.md`'s referenced
  8×63-cube geometry — check if the "group" concept in the canvas seed
  design (parallel groupings of the same device) has a spatial/geometric
  analog already defined here, since this project's addressing schemes
  tend to be geometrically grounded, not abstract.
- `data/ai-mem/claude/topic-x11-multi-server.md` — the actual current
  implementation state of `X-11.servers`, the multi-display registry the
  canvas work would sit on top of. Ground the design decision in what
  this registry actually tracks today, not just the aspirational version.
- `data/ai-mem/claude/topic-x11-resolution-profiles.md` — the concrete
  near-term trigger for this whole line of work (Xvfb needing per-purpose
  named resolution profiles). Whatever identity model you converge on
  needs to obviously accommodate this as the first real use case.

## what to produce

A written reconciliation, NOT code. Specifically:

1. **A clear answer** to: is canvas/group identity (a) a genuinely new
   addressing primitive, (b) a specific application of the existing
   checksum-addressing scheme, (c) a specific application of C25519 keys
   as already used for zenka/user identity, or (d) some combination —
   and why. Don't hedge with "could be any of these" — pick one, with
   the reasoning that ruled out the others.
2. **A concrete answer** to the topology-relative identity problem
   specifically: if a canvas's logical address can legitimately change
   when the screen-group's composition changes, what's the actual
   two-part identity scheme (stable physical handle + group-scoped
   logical address) look like in terms of the primitives from (1) — e.g.
   is the stable handle a checksum of something, a C25519 pubkey, a tree
   path, or a new kind of thing?
3. **How virtual/controllable canvases (Xvfb/Xephyr) differ**, if at all,
   in the identity scheme from (1)+(2) — they don't have the
   topology-dependency problem since they're created with known identity,
   but should still use the same addressing primitive family for
   consistency.
4. Whether the "universal primitive, applies to channels/nodes/node-groups
   too" generalization from the seed design holds up under (1)-(3), is
   too broad and should be scoped back down to just canvases for now, or
   needs modification.

## output

Write the reconciliation as an update to
`data/ai-mem/claude/topic-window-canvas-addressing.md` — replace the
"generalizing direction (not yet converged)" section with the converged
answer, keep everything else in the file intact, update the `## status`
section to reflect that the identity model is now decided (even though
implementation still isn't started), and update the frontmatter
`description` line accordingly. Do not create a new file for this — edit
the existing one in place.

Do not write any code, do not touch `modules/`, do not touch
`cfg/`, do not run any signing/staging/commit commands. This
task's only output is the memory file edit above.

#,,..,.,,,,.,,..,,.,,,,,.,.,.,.,.,.,.,..,,,..,..,,...,..,,.,,,,.,,,.,,...,.,,,
#N5DLDKQCMMXCESOMTP2SFCSWSFA32JGIZZRCAF5GTEQH76E36UIOXVK7TKB2GJXO2KMMPKWE3HQHS
#\\\|ZBBC7ID2AN4LV3LF6APTXIQ25ISYMZEZL4TLSUPY3NCVNPQCP7G \ / AMOS7 \ YOURUM ::
#\[7]WXTGSPYJV5QVI6WEOWSB3XCCFVZPSL7K46P4LZRTL6DM4ZDJ6EDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
