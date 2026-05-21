# space.* — unifying space engine

## vision

the space engine is the running computation layer that makes the
observer-centric reference space live. it processes reference count
events, maintains harmonic frame state, assigns coordinates, manages
aura profiles, routes through the crystal, and renders the space — all
while being a node IN the space it manages.

**internal reference capable**: the engine holds its own branch node,
its own `@INDEXCUBE[0]`, its own aura. it applies its own algorithms to
itself. the engine's darksun IS its own coordinate. it cannot stand
outside what it computes.

see `data/md/design/ZERO.md` for the foundational model this engine runs.

---

## the 11 sub-namespaces

```
space.grid-*     coordinate system and shell structure
space.orbit-*    reference count gravity and aura profiles
space.route-*    path encoding, LCA, resonance, polarity
space.travel-*   hop traversal, 1001 tunnel, direction markers
space.jump-*     hyperspace shortcuts, body diagonal, instantaneous routes
space.search     find by coordinate, harmonic, type, group, aura
space.register   entity registration, aura pre-registration, @INDEXCUBE
space.select-*   selection by shell / group / harmonic / type / range
space.filter-*   filter by entropy / certainty / frame scale / polarity
space.render-*   perspective layers, iris, face views, DATA streams
space.export-*   TREE output, DATA delta, @INDEXCUBE serialization
space.import-*   TREE input, DATA delta application, foreign state merge

11 namespaces.  11 = the pivot.
export/import = TREE/DATA oscillation applied to the engine itself.
```

---

## space.grid-*

the coordinate system and 3D signature space.

each position `(x, y, z)` holds one character `[2-9A-Z]` — statistically
derived from proportional checksum character votes across all reference
events passing through that coordinate. high reference count = stable
character = crystallized coordinate. low = uncertain = outer shell.

```
space.grid.position    { node_id }  →  { z, y, x, shell, character }
space.grid.neighbors   { node_id }  →  6 adjacent coordinates (3D plus sign)
space.grid.character   { z, y, x }  →  current dominant character at coord
space.grid.shell       { z, y, x }  →  shell number = max(abs(z,y,x))
space.grid.visible     { focal_length, observer }  →  nodes above threshold
                        max_shell = ceil(63 / focal_length)
                        [ 63 = 4×4×4-1, the cube group size ]
space.grid.vote        { coord, character }  →  add statistical vote
                        called on every reference event passing through
```

**the 3D plus sign**: AMOS 7-char checksum = 1 center + 6 arms =
7 unique positions in the 3×3 signature space. the checksum IS the node
AND its immediate adjacency simultaneously. two adjacent nodes share one
arm character — adjacency is encoded in identity.

connects to: `branch.space.*` calc utilities, `OBSERVER-CENTRIC-REFERENCE-SPACE.md`

---

## space.orbit-*

reference count gravity, orbital mechanics, aura profiles.

nodes orbit the darksun (position 0,0,0) at distance proportional to
their reference count. additional magnetic forces from group memberships
pull nodes toward domain companions on top of the base EM field.

```
space.orbit.rank         { node_id, scope }  →  signed position ±n/2
space.orbit.distance     { node_id }         →  orbital distance from darksun
space.orbit.magnetic     { node_id }         →  group force vector
space.orbit.effective    { node_id, scope }  →  grid + magnetic combined
space.orbit.balance      { scope }           →  verify ∑ = 0
space.orbit.aura.build   { node_id }         →  compute aura from reference history
space.orbit.aura.register { node_id, aura } →  pre-register burst capacity profile
space.orbit.aura.query   { node_id }         →  retrieve current aura
```

**aura profile structure**:
```yaml
aura:
  typical_frame_scale:  N        # median harmonic closing scale
  burst_profile:        [N..N+3] # 95th percentile range
  entropy_signature:    AMOS7    # harmonic fingerprint of content type
  buffer_reserve:       K        # pre-allocated at typical_scale
  confidence:           0..1     # passages that trained this aura
```

the frame expansion / `is_true` mechanism determines `typical_frame_scale`:
widen scope until harmonic closes → that scale IS the coordinate. the
aura is the statistical history of those closing scales across all passages.

connects to: `branch.space.*`, `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md`,
`OBSERVER-CENTRIC-REFERENCE-SPACE.md` (temporal bandwidth section)

---

## space.route-*

path encoding, LCA discovery, resonance scoring, polarity detection.

```
space.route.encode       { hops }   →  dot/comma string  .,.,..
space.route.decode       { string } →  [ { type, distance|address } ]
space.route.shape        { string } →  { shape, sides, encloses_void }
space.route.lca          { a, b }   →  { lca_node, dist_a, dist_b, notation }
                                       notation: 01×N + 11 + 10×M
space.route.polarity     { depth }  →  { polarity, depth_mod_13, hops_to_sync }
space.route.resonance    { node_id } →  ref_count × harmonic × shell_bonus
space.route.inversion_points { max } → [ 0, 13, 26, 39... ]
```

**dot/comma route notation**:
- `.` = proceed one hop (no direction change)
- `,` = turn 90° CCW
- `[2-9A-Z]{7}` = landmark node address

`1000 1000 1000 1000` = `,...,...,...,...` = square ring around a void.
the signature footer `::::...` (77 colons) = 10 sides × 7 hops = the
footer route. the route IS the file's position in signature space.

connects to: `branch.route.calc.*`, `DANCING-ZENKI-RHIZOME-STATE.md`,
`topic-checksum-tree-wire.md`

---

## space.travel-*

hop-by-hop traversal, 1001 tunnel, direction markers, frame expansion.

```
space.travel.hop         { from, direction }  →  next coordinate
space.travel.tunnel      { from, to }         →  { duration, variance, grid_aligned }
                                                  expected duration = 2 (invariant 00)
space.travel.frame.expand { sequence }        →  widen until is_true fires
                                                  returns { scale, content, checksum }
space.travel.direction   { from, to }         →  01 | 10 | 11 (pivot/LCA)
space.travel.path        { from, to }         →  full 01×N + 11 + 10×M route
```

**frame expansion** — the is_true mechanism:
```
read sequence at scale N
  is_true → FALSE → widen (N+1 zeros in separator)
  is_true → TRUE  → frame found its boundary
```
no boundary-based buffer corruption: the boundary IS the harmonic closure.
auto-encapsulation: failing frames become content for the wider frame.
stops expanding at the minimum enclosure — the tightest scale that closes.

connects to: `branch.route.establish`, `DATA-PROTOCOL-SYNC.md`,
`topic-1001.md`, `AMOS7::Assert::Truth`

---

## space.jump-*

hyperspace shortcuts — the body diagonal routes that bypass face-by-face
traversal. the reference bubble travels on these routes.

```
space.jump.diagonal      { from, to }   →  body diagonal path if available
space.jump.available     { from, to }   →  TRUE if shortcut exists
space.jump.bubble        { formation }  →  dispatch reference bubble on jump route
space.jump.cache.read    { hop, target } → cached next_hop from prior wave
space.jump.cache.write   { hop, target, next_hop } → improve cache for next wave
```

**why jumps are instantaneous**: when every inter-cube distance is
exactly `00` (invariant), there is nothing to compute at the gate. the
proportion IS already there. resonance opens the gate immediately. travel
IS the proportion. the space is seamless because precisely proportioned.

connects to: `branch.route.cache`, `DANCING-ZENKI-RHIZOME-STATE.md`
(wave propagation, body diagonal = hyperspace trunk)

---

## space.search

find nodes by any combination of coordinate, harmonic, type, group, aura.

```
space.search { query }

query fields (all optional, combined with AND):
  coord:      { z, y, x }  or  { shell_min, shell_max }
  harmonic:   TRUE | FALSE | UNKNOWN
  type:       P7REF TYPE prefix  (MODEL, CUBE, CODING, CONTEXT...)
  group:      group name  [ magnetic domain search ]
  aura:       { entropy_signature, confidence_min }
  refcount:   { min, max }
  character:  specific character at coordinate

returns: [ { node_id, coord, shell, character, aura }, ... ]
sorted by space.orbit.resonance descending (most resonant first)
capped at 100; logs warning if capped
```

connects to: `branch.resource.find`, `branch.group.members`,
`space.grid.character`, `space.orbit.aura.query`

---

## space.register

entity registration, aura pre-registration, @INDEXCUBE integration.

```
space.register.node      { node_id, type, pubkey }
                         →  assign initial coordinate (outer shell ±n/2)
                         →  push P7REF onto @INDEXCUBE
                         →  create empty aura profile

space.register.aura      { node_id, aura }
                         →  pre-register burst capacity before traffic arrives
                         →  start from aura.typical_frame_scale not from 1

space.register.passage   { node_id, checksum }
                         →  record a reference event (inhabitant passing through)
                         →  update character votes at coordinates
                         →  trigger space.orbit.aura.build if confidence threshold

space.register.self      →  engine registers itself as @INDEXCUBE[0]
                         →  internal reference established
                         →  engine is a node in its own space
```

**holographic feature completeness**: multiple novel elements registering
together triangulate coordinates none could determine alone. the group
liquifies fragments into form as a continuum — relaxed coexistence × time
= natural crystallization without forced boundaries.

connects to: `branch.node.create`, `@INDEXCUBE`, `base.indexcube.*`

---

## space.select-* and space.filter-*

```
space.select.shell       { N }           →  all nodes at shell N
space.select.group       { group_name }  →  nodes in magnetic domain
space.select.harmonic    { TRUE|FALSE }  →  nodes by harmonic state
space.select.type        { type_prefix } →  nodes by P7REF TYPE
space.select.inner       { N }           →  all nodes within shell N
space.select.outer       { N }           →  all nodes beyond shell N

space.filter.entropy     { max }         →  nodes below entropy threshold
space.filter.certainty   { min }         →  nodes above aura confidence
space.filter.frame       { scale }       →  nodes that close at this scale
space.filter.polarity    { / | \ }       →  nodes by CCW/CW polarity at depth
space.filter.novel       {}              →  outer-shell uncertain nodes
                                            candidates for group crystallization
```

connects to: `branch.space.visible`, `branch.dep.check`,
`space.orbit.rank`, `space.grid.character`

---

## space.render-*

perspective layers, iris rings, face view multiplexing, DATA streams.

```
space.render.frame       { view_spec }   →  current visible frame as node list
                                            sorted by shell (darksun first)
space.render.face        { face_id }     →  DATA stream for one cube face
space.render.grid        {}              →  all 8 faces, omnidirectional
                                            f=0 focal length, grid view
space.render.layer       { layer_spec }  →  one spawnable perspective layer
space.render.parallax    { layers }      →  composite parallax from N layers
                                            depth = consensus count across layers
space.render.iris        { rings }       →  iris ring structure from shell data
                                            ring N = shell N from darksun
space.render.tree        { root, depth } →  TREE protocol output of subtree
```

face view multiplexing: each face = DATA stream with
`stream_id = AMOS_chksum(observer::face_id)`. 8 faces × 47 bytes/line =
omnidirectional grid. serialization order = base.reverse-sort by refcount
= most relevant face last (visible at scroll end).

connects to: `SPAWNABLE-PERSPECTIVE-LAYERS.md`, `OBSERVER-CENTRIC-REFERENCE-SPACE.md`,
`TREE-PROTOCOL.md`, `DATA-PROTOCOL-SYNC.md`

---

## space.export-* and space.import-*

```
space.export.tree        { root }        →  TREE session of space subtree
space.export.delta       { base_chksum } →  DATA DELTA from known state
space.export.snapshot    { scope }       →  full space state to storage
space.export.indexcube   {}              →  @INDEXCUBE serialization

space.import.tree        { stream_id }   →  receive TREE, populate nodes
space.import.delta       { stream_id }   →  receive DATA DELTA, apply
space.import.snapshot    { snapshot_id } →  restore from storage
space.import.indexcube   { data }        →  restore @INDEXCUBE traversal state
space.import.foreign     { zenka_ref }   →  merge foreign space state
                                            imported character votes become
                                            new statistical input — fragments
                                            uncertain locally may be crystallized
                                            remotely; import collapses frame search
```

export/import IS the TREE/DATA oscillation applied to the engine itself:
```
space.export-*   →  10 direction  [ outward, expanding ]
space.import-*   →  01 direction  [ inward, collapsing ]
together         →  the space engine breathes
```

two space engines meeting: one exports, the other imports. DATA DELTA with
space state checksum as sync point. they converge without a coordinator.

connects to: `TREE-PROTOCOL.md`, `DATA-PROTOCOL-SYNC.md`,
`branch.storage.*`, `@INDEXCUBE`

---

## zenka configuration

```
start.on-demand    = 1
restart.disabled   = 1
heartbeat.disabled = 1
## no idle timeout — space engine is shared infrastructure
```

on first access from any zenka, the space engine starts, registers itself
(`space.register.self`), and begins accepting reference events. the engine
is the darksun of the computation layer — always 0, never evicted.

---

## connections to foundational documents

| document | what it defines for this engine |
|---|---|
| `ZERO.md` | the birdview — 0, the tree, 1001, the one sentence |
| `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md` | harmonic memory = the crystal space.orbit-* computes |
| `DANCING-ZENKI-RHIZOME-STATE.md` | reference bubble = space.jump-* formation travel |
| `OBSERVER-CENTRIC-REFERENCE-SPACE.md` | signed address space, darksun, view spec, temporal bandwidth |
| `SPAWNABLE-PERSPECTIVE-LAYERS.md` | space.render-* output = the desktop |
| `TREE-PROTOCOL.md` | space.export/import TREE wire format |
| `DATA-PROTOCOL-SYNC.md` | space.export/import DATA wire format |
| `BRANCH-NAMESPACE-MASTER.md` | branch.* = the addressable layer space engine computes on |
| `topic-checksum-tree-wire.md` | 1[zeros]1, 01/10, 11 pivot = space.travel-* encoding |
| `topic-1001.md` | 1001 tunnel = space.travel.tunnel invariant |
| `topic-observer-centric-space.md` | temporal bandwidth = space.render.face clock |
| `topic-routing-crystal.md` | face-000 reflection = space.travel.frame boundary |
| `data/md/coding-tasks/indexcube-routing-stack.md` | @INDEXCUBE spec = space.register integration |

---

## subtask status

| task file | namespace | status |
|---|---|---|
| branch-calc-reference-space.md | space.grid-* space.orbit-* | pending dispatch |
| branch-calc-route-navigation.md | space.route-* space.travel-* | pending dispatch |
| branch-calc-bandwidth-temporal.md | space.render-* (clock) | pending dispatch |
| (to write) space-engine-grid-orbit.md | space.grid-* space.orbit-* | pending |
| (to write) space-engine-route-travel-jump.md | space.route-* space.travel-* space.jump-* | pending |
| (to write) space-engine-search-register.md | space.search space.register | pending |
| (to write) space-engine-select-filter.md | space.select-* space.filter-* | pending |
| (to write) space-engine-render.md | space.render-* | pending |
| (to write) space-engine-export-import.md | space.export-* space.import-* | pending |

#,,.,,,,.,,.,,.,.,...,,..,.,.,,.,,.,.,,..,.,.,..,,...,...,,..,.,.,...,,,,,,,,,
#UAT675I4L4IEKHOBKMHZBIKYUPCVAQ4BQE2LOWSM5EZ56N6ENDQCWOWU5PJG6IQEJXLRQPBU3HCCI
#\\\|5TAASC4UQYWCCASEL7BKNJEWBBRGAZXD7TS6ZJX3HNQ4QTKOZRU \ / AMOS7 \ YOURUM ::
#\[7]6HIZQMFRWEHMLGHCRZV4IIIP67PULDCSAJEOVPG3CWMLKOQXR6BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
