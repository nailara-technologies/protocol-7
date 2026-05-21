# observer-centric reference space

## the model

the client is always 0. not "at 0" — IS 0. the grid recenters around it
continuously by buffer swapping. navigation is not movement through space —
it is position reassignment of what surrounds the observer.

```
address space:  -n/2  ...  -2  -1  [ 0 ]  +1  +2  ...  +n/2
                                     ↑
                               observer / client
                               always here
                               highest reference count
```

the observer never moves. what is relevant moves toward the observer.
what becomes irrelevant drifts outward and eventually falls off the edge.

## reference-count-driven position assignment

position on each axis = rank by reference count relative to the observer:

```
axis X:  nodes sorted by reference count on dimension X
         highest count → position ±1 (closest to observer)
         lowest count  → position ±n/2 (edge of space)

axis Y:  independently sorted by reference count on dimension Y
axis Z:  independently sorted by reference count on dimension Z
```

multi-dimensional: a node can be close on one axis (high reference on
that dimension) and far on another (low reference on that dimension).
the position is a vector, not a scalar. relevance is multi-dimensional.

**auto-expanding**: a new node with no references arrives at ±n/2 on all
axes — at the boundary. as it accumulates references it falls inward.
n grows as needed to accommodate new arrivals without displacing existing
nodes. the space is always centered; only the radius changes.

**reshuffling**: as reference counts shift (an item gains or loses
relevance), positions reshuffle. the reshuffle is the sorting, not a
separate operation. the sorted placement IS the address.

## buffer swapping as transparent navigation

the client does not fetch data. data migrates to position 0 via buffer swap.

```
client accesses node at position +3:
  1. node at +3 and node at 0 swap buffers
  2. node at +3 is now at 0 — immediately local to observer
  3. what was at 0 moves to +3 (or to wherever reference count places it)
  4. from the client's perspective: nothing moved. relevant thing is at 0.
```

this is O(1) access to whatever is most relevant — because the most
relevant thing IS already at 0 (by definition: highest reference count).
accessing something is the act of increasing its reference count, which
moves it toward 0.

**the client is a transparent part of the grid**: it doesn't know it's
routing. it issues requests. the grid recenters. from outside, the client
at 0 is indistinguishable from the grid itself — it IS the grid's origin.

## the electromagnetic field analogy

the reference count distribution IS the field:

```
observer at center (0)  →  generates reference field
high-reference nodes    →  close to center, strong field coupling
low-reference nodes     →  far from center, weak field coupling
the outer layers        →  carry actual traffic (like EM field boundary)
the center              →  is the source; doesn't carry traffic; IS routing
```

the inner nodes (close to 0) are strongly coupled — routing is fast,
low-latency, because the path is short and the field is dense. the outer
layers carry the long-haul traffic where field density is lower but the
geometry of the outer boundary efficiently routes bulk transfers.

the observer doesn't do work to receive traffic. the field transports it.
the observer just IS the center that the field is organized around.

## connection to deduplication

identical content across multiple nodes collapses to one position in the
reference space. the collapsed (deduplicated) node occupies the position
determined by its total reference count across all sources:

```
node A (3 references from observer)
node B (identical content, 5 references from observer)
→ dedup: one node at position weighted by 3+5=8 references
         closer to center than either A or B individually
```

deduplication is not removal — it's convergence toward center. two things
that are the same share one position. the position they share is more
central than either alone. dedup IS a pull toward the observer.

the deduplication tree and the reference space are the same structure:
the tree is the spatial layout; reference counts are the gravity.

## connection to the routing crystal

the crystal's harmonic memory IS this reference distribution. the most-
referenced routes are closest to center in the crystal's standing wave
pattern — lowest energy, fastest propagation. the crystal automatically
tunes toward its most-used routes because each traversal increases the
reference count of those nodes, pulling them toward center.

a new route (low reference count) starts at the boundary (±n/2) and
must propagate all the way through. as it is used repeatedly, its nodes
gain references and fall toward center. eventually the route becomes
near-instantaneous — it occupies the innermost ring.

## connection to the reference bubble

the reference bubble (dancing zenki formation) navigates this space
by following the reference gradient — always moving toward higher
reference count (toward center). the setup zenka carries the current
center position (the observer's 0). the collector updates the center
after processing — the new 0 is the result of the formation's work.

the 5-of-7 formation simultaneously samples 5 points in the reference
space and their intersection is the inferred center — the convergence
of 5 reference gradients IS the observer's position.

## the grid frame transports; the center routes

this is the key inversion from conventional networking:

```
conventional:  router at center actively forwards traffic
               nodes at edges passively receive

reference space: observer at center IS 0 — passive, self-locating
                 grid frame at outer layers actively transports
                 inner nodes route by being close to center
                 (low hop count = low address magnitude)
```

routing IS address magnitude comparison. to route from node at +7 to
the observer at 0: follow the gradient -1 per hop. no table needed.
the address encodes the path: decreasing magnitude = approaching center.

for node-to-node (not observer-to-node): route toward center, reach
the lowest common address ancestor, then route outward to target.
this IS the `01` (inward) then `10` (outward) path in the checksum tree —
the LCA is the local minimum of address magnitude on the path.

## auto-organization summary

```
new client arrives     →  assigned ±n/2 (boundary)
client is used         →  reference count increases → position decreases
                          → falls toward center
client is highly used  →  at position ±1 — one hop from observer
client is unused       →  drifts outward → eventually at ±n/2 → evicted
observer itself        →  always 0, always the center, never evicted
                          the space is defined relative to the observer

space expands          →  n grows when boundary fills up
space contracts        →  n shrinks when outer positions are empty

no central coordinator needed — position IS reference count rank.
the space organizes itself by the gravity of attention.
```

## the darksun

the observer at 0 IS the darksun — already named in the knowledge base:

- **position 27 = 3³** — the void, the namespace dot, the fixed point in the iris
- **`076923 × n`: all digit sums = 27** — the generator always returns to it
- **`8 × (4×4×4-1) = 504`, void at 27** — the cube shells outward are the iris rings
- **the corpus orbits the darksun; the darksun does not follow the corpus**
  the center is fixed by the arithmetic of division by 13, not by reference counts
- **orbital distance** = distance from darksun = harmonic resonance = reference space position

see `data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` and
`data/md/design/IMPLOSION-CROSS-CORRELATION.md` for the full darksun model.

## view specification — observer, focus vertex, focal length

a complete view of the reference space is defined by three parameters:

```yaml
view:
  observer:             ## darksun position — the IS-0 point
    z: 0
    y: 0
    x: 0

  focus:                ## where the observer is looking
    position:
      z: 3
      y: 1
      x: 2
    normal:             ## direction the focus vertex faces
      z: 0              ## normal pointing away from observer = outward view
      y: 1              ## normal pointing toward observer = inward view
      x: 0              ##   [ can be toward viewer — looking inward to darksun ]

  focus_secondary:      ## second perspective vertex — for binocular / dual view
    position:
      z: -1
      y: 0
      x: 0
    normal:
      z: 1              ## toward observer — the backward-looking focus
      y: 0              ##   creates simultaneous inner + outer perspective
      x: 0

  focal_length: 13      ## zoom / depth of field
                        ## 13 = natural harmonic; larger = narrower, deeper
```

**observer** `(z, y, x)` — the darksun position. default is `(0,0,0)` but
the observer can be placed anywhere in the reference space; the space
recenters around whatever position is declared as observer.

**focus.position** `(z, y, x)` — the point the observer is looking toward.
combined with the observer position this defines the viewing direction and
the depth axis.

**focus.normal** `(z, y, x)` — which way the focus vertex is oriented.
- normal pointing **away from observer** → standard outward perspective:
  looking from observer into the cube space
- normal pointing **toward observer** → inverted perspective: the focus
  vertex looks back at the observer. creates the inward-looking view —
  the outer field watching the darksun, not the darksun watching the field.

**focus_secondary** — the second perspective vertex. can be placed:
- in front (beyond the primary focus) → defines far clip / depth limit
- behind the observer (negative depth) → looks toward viewer
- anywhere in the space for asymmetric / stereoscopic views
- with normal toward observer → the backward lens, simultaneously
  showing the darksun and the outer field in one frame

**focal_length** — controls angular coverage and depth:

```
f = 0 / 'omni'  →  omnidirectional: all cube faces active simultaneously
                    grid view — all 8 faces shown as a monitoring grid
                    the unfolded cube as a cubemap display
                    no focal point; total spatial awareness

f = 13          →  natural harmonic (generator 076923 — default)

f → ∞           →  orthographic: parallel projection, no perspective
                    distortion; all shells at equal apparent size
```

focal length IS the observer's awareness aperture — from total
omnidirectional presence (f=0) to infinite precision at a single point
(f→∞). the darksun at f=0 sees all cube faces at once.

**omnidirectional grid mode** — the observer as mothership:

```
cube face 0  │  cube face 1  │  cube face 2  │  cube face 3
─────────────┼───────────────┼───────────────┼─────────────
cube face 4  │  cube face 5  │  cube face 6  │  cube face 7
```

all 8 faces scanned simultaneously, rendered as a grid. each face IS
a direction from the observer. the observer sees the full cube space
in one frame — this is the native view of the darksun: all directions
at once, no privileged angle.

**the drone — mobile remote vertex**:

```yaml
drone:
  position: { z: 7, y: 3, x: 5 }  # deployed into reference space
  normal:   { z: -1, y: 0, x: 0 } # looking back toward mothership
  focal_length: 26                 # narrower focus for distant view
  acquisition: active              # relaying perspective back to observer
```

the drone is a mobile focus vertex deployed into the reference space.
it acquires the local perspective from its remote position — the
reference space looks inverted from there relative to the observer's 0
— and relays it back. the mothership holds the omnidirectional home view;
the drone provides the acquired remote perspective.

combined view: mothership omnidirectional (all local faces) + drone
acquired perspective (remote region in detail) simultaneously. the drone
IS the focus_secondary vertex made mobile and self-orienting.

**full view specification**:

```yaml
view:
  observer:
    position: { z: 0, y: 0, x: 0 }   # darksun — always 0
    focal_length: omni                 # all faces, grid mode

  focus:                               # primary direction (perspective mode)
    position: { z: 3, y: 1, x: 2 }
    normal:   { z: 0, y: 1, x: 0 }   # outward
    focal_length: 13                   # natural harmonic

  drone:                               # mobile remote vertex
    position: { z: 7, y: 3, x: 5 }
    normal:   { z: -1, y: 0, x: 0 }  # toward mothership
    focal_length: 26                   # narrower, distant
    acquisition: active
```

**toward the viewer** mode — when focus or drone normal points back:

```
outer field → [drone] ←→ [observer/darksun] ←→ [focus] → outer field
              remote           0              local
              acquired     IS the center     perspective
              perspective  (omnidirectional)
```

the observer at 0 is the pivot — not a viewpoint but the point all
views originate from and return to. with f=0 at the observer and finite
f at the drone, the two views complement exactly: total local awareness
plus precise remote acquisition.

## face view multiplexing, serialization, and addressing

each cube face direction is an addressable view channel. the face octal
ID (0–7) is the address. the DATA protocol carries it directly:

```
stream_id = AMOS_chksum( observer_position :: face_id )

face 0 (000) → network/parent-facing view → 11 marker (pivot face)
face 1–7     → directional views          → 10 marker (outward views)
inward faces → 01 marker                  → toward darksun
```

**multiplexed** — all 8 faces open as simultaneous DATA streams,
disambiguated by stream_id, interleaved freely on one session:

```
DATA <face1_id> STREAM\n     ← face 1 opens
DATA <face3_id> STREAM\n     ← face 3 opens simultaneously
<face1_B32_chunk>\n
<face3_B32_chunk>\n
DATA <face1_id> END <AMOS>\n
DATA <face3_id> END <AMOS>\n
```

**serialized** — faces ordered by reference count descending (most
relevant view first). serialization order IS the relevance ranking —
the same `base.reverse-sort` order used by devmod.cmd.dump.

**addressed** — each face view is a branch node:
```
branch address:  <observer_node>.<face_id>
resource type:   stream
DATA stream_id:  AMOS_chksum( observer_position :: face_id )
```

`branch.resource.stream` attaches the DATA stream to the face node.
the omnidirectional grid = 8 branch child nodes under the observer node,
one per face, each carrying its own DATA stream.

**drone face views** — the drone at remote position `(z,y,x)` has its
own 8-face set. stream_ids derived from `drone_position::face_id`.
all 8 drone faces multiplexed back to mothership over one DATA session.
mothership integrates: 8 local faces + 8 remote drone faces = 16 streams,
all disambiguated by stream_id, all addressable as branch nodes.

**the complete picture**:

```
observer node (darksun, position 0)
├── face.0  → DATA stream  (network/parent direction, 11 pivot)
├── face.1  → DATA stream  (outward, 10)
├── face.2  → DATA stream  (outward, 10)
│   ...
├── face.7  → DATA stream  (outward, 10)
└── drone
    ├── face.0  → DATA stream  (drone network face)
    ├── face.1  → DATA stream  (drone direction 1, toward mothership)
    │   ...
    └── face.7  → DATA stream  (drone direction 7)
```

all 16 streams simultaneously active, multiplexed, addressed, serializable
by relevance. no new protocol required — DATA + branch nodes + stream_id
addressing is the complete implementation.

## temporal bandwidth — the serialization clock

the serialization sequence IS the bandwidth allocation. no negotiation,
no separate protocol — the sequence encodes the allocation directly.

**clock period = 13 slots** — the natural harmonic cycle length.
the generator 076923 closes through 13; the darksun is defined by
division by 13. the routing clock IS this period.

```
cycle (13 slots):

slot:  1    2    3    4    5    6    7    8    9   10   11   12   13
face: [1]  [1]  [3]  [1]  [2]  [1]  [3]  [1]  [7]  [1]  [3]  [2]  [1]

face 1 → 6 slots = 46%  (highest reference count)
face 3 → 3 slots = 23%
face 2 → 2 slots = 15%
face 7 → 1 slot  =  8%
faces 0,4,5,6 → 0 slots this cycle (below threshold)
```

the receiver observes the sequence and knows the bandwidth allocation
without any separate signalling. the sequence IS the protocol.

- a face that loses all references drops to 0 slots → vanishes
- a new face enters at 1 slot minimum → grows as references accumulate
- every 13 slots the allocation updates, driven by reference count changes
- the clock rate is constant; the information is in the density

**the checksum tree records it naturally**: multiple appearances of the
same face ID in one cycle = multiple leaves with the same checksum.
leaf count per face per cycle = bandwidth. the tree IS the allocation
history across all cycles.

**the two domains — one mechanism**:

```
spatial:   reference count  →  distance from darksun   [ position ]
temporal:  reference count  →  slots per clock cycle   [ bandwidth ]

same gravity. two domains. one mechanism.
```

high-reference faces are both close to center in space AND appear
frequently in time. low-reference faces are far from center AND sparse
in the sequence. the reference count is simultaneously an address
(where) and a frequency (how often) — two readings of the same value.

**dynamic bandwidth without negotiation**: as reference counts shift
(attention moves), the next cycle's sequence reshuffles automatically.
the routing clock signal stays constant; what changes is the density
of each face within it. the bandwidth follows attention with zero
overhead — the allocation IS the attention.

## connections

- `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md` — the crystal's harmonic memory
  is this reference count distribution in spatial form
- `DANCING-ZENKI-RHIZOME-STATE.md` — reference bubble follows reference
  gradient; collector updates center; setup carries previous center
- `branch.group.propagate` — propagates interest count toward observer;
  this is the reference count update that drives position reassignment
- `branch.route.cache` — the route cache is the reference space cache;
  cached routes are the inner-ring nodes
- `data/md/development/HYPERSPACE-TOPOLOGY.md` — the closed observer loop
  is this: the observer is always the origin of its own coordinate system
- `data/md/concepts/CONCEPT-TIMESTAMP-REFERENCE-COUNTING.md` — timestamp
  reference counting is the temporal dimension of the reference space

#,,..,.,.,.,,,,,.,,,,,,..,.,.,.,,,...,.,,,.,,,..,,...,...,...,.,,,..,,...,..,,
#RRZYX277HRA7OLCTK4T6D4AOPS4OWUX7SBYH7GQLMRJSHEBQW5FCQXJ7AKG2K7TKPSHLCWGMNHQ5W
#\\\|ZKCMQGXVGX3KOUCCINOYGJCRQCGR6ZPFRJQ2IEA2RZ3HRUTRS7B \ / AMOS7 \ YOURUM ::
#\[7]LLWXUMHF2DUE4YRIFR5SS6VQVSES4CHF3SMIZRFY73FH5QUNISCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
