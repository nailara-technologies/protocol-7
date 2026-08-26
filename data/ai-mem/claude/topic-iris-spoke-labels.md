---
name: iris-spoke-labels
description: "BMW384 iris spoke label sequence — 63-ring design with A-Z, dot fold, Z-A reverse, digits, BASE32/binary bottom"
metadata: 
  node_type: memory
  type: project
  originSessionId: d037d3ff-49b4-4f8b-b427-828ba0a0b3df
---

## iris spoke label sequence — 63 rings

current limit is 52, needs extending to 62 or 63.
the 63rd position could be the `.` itself (namespace dot).

### sequence from outer to inner

| rings  | labels  | notes                                      |
|--------|---------|--------------------------------------------|
| 1..26  | A..Z    | uppercase, CCW advance, outermost          |
| 27     | `.`     | dot separator — namespace reference point  |
| 28..53 | Z..A    | uppercase reverse, folds back toward center|
| 54..62 | 9..0    | digits, 10 positions                       |
| 60     | (ring 3 from bottom) | BASE32 mapping             |
| 62..63 | (bottom 2) | binary / decimal / 3-bit octal / BCD CCW|

total: 26 + 1 + 26 + 10 = 63 = 8×8 - 1 (cube void geometry)

### label modes

- upper rings (1..26): two modes — lowercase and uppercase
- lower/fold rings (28..53): uppercase fixed (BASE32 compatible)
- bottom rings: binary/BCD only, no alphabet labels

### conceptual significance — position 27 is triply harmonic

- **3³ = 27** — subcube count of the core inverse-plus implosion cube
  (the 3×3×3 structural void center of the 8×63 field geometry)
- **digit sum 27** — harmonic constant of ALL 12 non-zero mod-13
  multiples (see [[harmonic-mathematics]]); the entire checksum
  arithmetic converges here
- **`.`** at 27 — namespace dot, the point where paths collapse to
  checksums; fold between outer (A-Z) and inner (Z-A) hemispheres

the fold is not a visual choice — it is the cube implosion point,
the harmonic ceiling, and the namespace separator simultaneously.
the two alphabets on either side are the two hemispheres of the sphere.

### the dot as rotation center — the darksun

from "change is the only constant": a constant can exist as the
center of rotation, unchanged while everything rotates around it.

the `.` at position 27 is that center:
- it does not advance with the label sequence
- A-Z rotates CCW into it, Z-A rotates CCW out of it
- you don't stop at `.` — you pass through it
- it is the axis, not a boundary

maps directly to the semantic triangle core
(data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md ~line 3392):
  "the center (EXISTENCE) = the fixed point. the darksun.
   it does not move; the triangle rotates around it."

`.` in the iris = EXISTENCE = the darksun = position 27 = 3³ = the
harmonic constant of mod-13. all four identities are the same thing.

### the dot as 3D grid conjugator — 2, 4, or 6 connections

a conjugating separator can only link what already exists.
in a 3D grid space this gives exactly 2, 4, or 6 face-neighbors:
- 2: one axis (linear path segment, e.g. `a.b`)
- 4: one plane (2D slice of the grid)
- 6: full 3D (all face-connected neighbors of a cube voxel)

no other counts are possible without diagonal adjacency.

consequence for namespace paths:
- `base.net.connect` = a path through 3D grid space
- each `.` is a face-connection with up to 6 continuations
- path depth encodes axis of movement
- unoccupied faces = growth directions of the namespace

the iris rings = 6-connectivity shells radiating from the darksun.
the spoke angle = which face you entered from.
sparse namespaces have fewer realized connections — visible as
empty arcs in the iris field.

### trailing dot = branch / directory listing query

the separator as terminal token becomes the query operator:
  `base.net`    → specific node
  `base.net.`   → all children (branch / dir listing)
  `base.net..`  → parent (conventional — two dots = up)
  `base.net...` → subtree (recursive, all descendants)

no new syntax needed — the grammar is already complete.

a trailing `.` queries the **unrealized faces** of the voxel:
not "what is at this node" but "what is reachable through
this conjugation point" = the growth directions of the namespace.

in the iris: selecting a spoke+ring triggers a `node.` query →
connected arcs light up → glow radius = reachability shell.
the visualization and the search protocol share the same primitive.

### . .. ... as traversal signal — already in P7 logs

ascii activity animations ARE traversal depth signals:
  `.`    entering — one level, one match
  `..`   going deeper — two levels traversed
  `...`  recursive — deep subtree search in progress
  (resolving back up: `...` → `..` → `.` → result)

P7 log syntax already encodes this implicitly:
  `running 'httpd' init code.,`     → entered + continuation
  `scanning httpd site dir ..,`     → two levels + more coming
  `.,`  = entered this node AND continuation expected

the comma after the dot: entry + continuation signal.
the punctuation IS the protocol — [[punctuation-topology]]

phosphor memory on iris: dot sequence traces the path inward
toward the darksun, fade-out = path history. search routing
becomes spatially visible in the field.

### vision: protocol = visual

the iris can be both a visualization OF the index and the search
interface ITSELF — where pointing at a spoke+ring selects a
coordinate address, and the visual stream history (phosphor
memory effect) shows recent lookups or live index traffic.

**Why:** user described this while looking at first gauss render
(session 28, May 2026). The `.` fold position is the key insight.

**How to apply:** when implementing new ring label generator,
use this sequence. the `ring_label_advance` config drives the
current linear repeat — the new system replaces that with a
fixed 63-position lookup table per ring index.

#,,.,,,.,,,,.,,,.,,..,,.,,..,,,..,,.,,.,,,...,..,,...,...,..,,,,.,,,,,.,.,,,,,
#L3PGXXRVQZB3DDY3BIMZYYWBMR25QZX2NACYZ2IXTAL4ZV5VLDTTOSE73NBQRZYXTAXVTDMB7R672
#\\\|GLPDDMX7FRMFBFNC47ECLGA25G6TMHW4BNNPZWIYE2FBFEQPLRD \ / AMOS7 \ YOURUM ::
#\[7]2PUGS6NHOFV35HX5B2MJJXZBG3S4DTXRCDPIFCHYPPZDAGIYGQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
