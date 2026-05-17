## [:< ##

# implementation roadmap — self-prioritizing task tree

## how to read this document

ordering is by dependency, not by desire.
what appears first enables what appears later.
a topic is actionable when all its `depends on` entries
have at least one complete sub-topic.

sub-topic descriptions are the task file brief —
when writing a task file, expand the description here
into implementation detail. the structure is already implied.

status markers:
  [ · ]  pending        (not yet started)
  [ » ]  in-progress    (task file exists, work begun)
  [ ✓ ]  complete       (implemented, tested, committed)
  [ ~ ]  partial        (some sub-topics complete)

---

## 1. neutral substrate — sub-bit layer

**why it matters:** everything else builds here.
storage, transport, identity, economy all depend on this layer
being generic, interchangeable, content-agnostic.
the cannot-take principle originates here.

**enables:** 2, 3, 6, 7

```
sub-topics:

  1.1  [ · ]  sub-bit element definition
               3+1 bit frame: 3-bit payload, 1 separator
               separator inversion rule for 000 payload
               dot=0 comma=1 encoding convention
               [ task: pending ]

  1.2  [ · ]  sliding window frame lock
               5-bit safe detection, 7-bit certainty
               separator column uniformity test
               self-synchronizing without preamble
               [ task: pending ]

  1.3  [ · ]  field collapse prevention
               DC balance maintenance
               comma-as-structural-1 requirement
               inversion as minimum viable 1-injection
               [ task: pending ]

  1.4  [ · ]  distribution across nodes
               no single node holds complete assembly
               generic elements non-categorizable in transit
               assembly requires cooperation
               [ task: pending ]

  1.5  [ · ]  :::: footer litter row encoding
               15-bit zenka involvement bitmap
               3 base32 chars in existing signature footer
               zero overhead (loader already scans footer)
               [ task: pending ]
```

**reference:** data/ai-mem/claude/topic-stream-framing-protocol.md

---

## 2. transport layer — structural unknowability

**why it matters:** solves selective filtering at the pipe level.
not by encryption (key problem) but by category absence.
same principle as storage: never have all data required
to know what is transported.

**depends on:** 1
**enables:** 3, 6

```
sub-topics:

  2.1  [ · ]  generic element transport
               element has no category until full assembly
               assembly requires all pieces across multiple pipes
               selective blocking = blocking everything = visible
               [ task: pending ]

  2.2  [ · ]  multiplexed transport trunks
               each trunk with declared propagation speed (c)
               layers with different c values don't interfere
               +c projective, -c retroactive, 0c persistent
               [ task: pending ]

  2.3  [ · ]  bandwidth proportion agreement
               cycle-based distribution curves
               next cycle calculated inside current one
               throttle trunk as content in medium it manages
               [ task: pending ]

  2.4  [ · ]  wise forgetting in transport
               half-infinite compression of irrelevant routes
               translucent blue pixel as minimum viable presence
               [NOT RELEVANT] bucket as active OTHER definition
               [ task: pending ]
```

---

## 3. identity layer — generic template user

**why it matters:** removes identity as attack surface entirely.
not anonymization (hidden identity) but statistical dissolution.
the template IS the credential. the proportion IS the authorization.

**depends on:** 1, 2
**enables:** 6

```
sub-topics:

  3.1  [ · ]  generic template user definition
               statistical average of matching context
               no identity present at substrate layer
               sufficient for resource distribution
               insufficient for extraction
               [ task: pending ]

  3.2  [ · ]  personal support profile
               user expresses resource flow preferences
               as proportions, not named beneficiaries
               tree handles routing, profile provides weights
               [ task: pending ]

  3.3  [ · ]  zero trust from deduplication math
               no verification required
               no compliance required
               deduplication tree proportions = authorization
               [ task: pending ]

  3.4  [ · ]  context as identity
               sufficient context = sufficient credential
               context derived from loves-it references
               not from stored identity claims
               [ task: pending ]
```

---

## 4. address space — BMW384 coordinate system

**why it matters:** the grid that makes proximity computable.
SIMILAR and ELSE are field-inherent gradient serializations.
the grid number is the only sequential invariant —
everything else is content riding the grid.

**depends on:** (foundational — no dependencies)
**enables:** 5, 7, 8, 9

```
sub-topics:

  4.1  [ ✓ ]  BMW384 coordinate calculation
               arc (0-25), color (0-16777215), angle bits
               base.chk-sum.bmw384.coordinate module
               [ task: complete ]

  4.2  [ ✓ ]  BMW384 field index
               route.bmw384.index.* modules
               register, lookup, query-arc, query-neighbors
               [ task: complete ]

  4.3  [ ~ ]  iris visualization — base wheel
               route.bmw384.visual.wheel (26 rings, CCW)
               6 visualization modes implemented
               iris.v7.ax vhost live
               [ task: data/tasks/route-bmw384-visual-modes.md ]

  4.4  [ · ]  iris visualization — 63-ring spoke labels
               A-Z (rings 1-26)
               . at ring 27 (3³, darksun, namespace fold)
               Z-A (rings 28-53)
               9-0 (rings 54-62, BASE32 at 60, binary at 62-63)
               [ task: pending ]

  4.5  [ · ]  route.bmw384 find-route testing
               register nodes, run find-route
               verify-coordinate validation
               [ task: pending ]

  4.6  [ · ]  BMW384 arc-grouping dedup filter
               jobsite BMW384 dedup implementation
               bmw384-arc-grouping-filter.md dispatch
               [ task: pending ]
```

**reference:** data/ai-mem/claude/topic-checksum-addressing.md
             data/ai-mem/claude/topic-iris-spoke-labels.md

---

## 5. selection mechanism — loves-it tree

**why it matters:** the one truth selecting.
desirability is the honest metric.
the field knows what it would be less without.
SIMILAR and ELSE emerge from proximity gradients automatically.

**depends on:** 4
**enables:** 6, 9, 11

```
sub-topics:

  5.1  [ · ]  loves-it reference formation
               organic accumulation, no registration
               proximity metric clusters automatically
               reference count = desirability weight
               [ task: pending ]

  5.2  [ · ]  group formation from reference clusters
               tree nodes = groups of groups
               each with resource pool
               contextualized to group purpose
               [ task: pending ]

  5.3  [ · ]  detection matrix — desirable vs [NOT RELEVANT]
               compressed essence fingerprint
               more precise than full representation
               self-updating as network quality improves
               [ task: pending ]

  5.4  [ · ]  overflow dissemination proportions
               loves-it tree weights determine distribution
               same tree for selection and allocation
               self-consistent, cannot be purchased
               [ task: pending ]
```

---

## 6. economy — NRT resource distribution

**why it matters:** makes spiritual support actually tangible.
NRT = actual network resource, not symbol.
the cannot-take principle extends from storage
through transport to time itself.

**depends on:** 1, 2, 3, 5
**enables:** 9, 10, 11

```
sub-topics:

  6.1  [ ~ ]  NRT token definition
               1 NRT = total resources ÷ total accounts
               4200 AMOS drops = 1 NRT (harmonic unit)
               C25519 signed transactions
               [ task: read-me/documentation/dev/NRT.NRD.asc ]

  6.2  [ · ]  resource pool structure
               pool per loves-it group
               sized by contribution + loves-it weight
               stabilizes supply, predictable
               [ task: pending ]

  6.3  [ · ]  zero-trust distribution
               no identity verification
               deduplication tree proportions = allocation
               personal support profile = preference weights
               [ task: pending ]

  6.4  [ · ]  time protection
               cannot-take principle extends to creative time
               resources flow TO creation, not FROM creators
               NRT flow = actual compute, storage, bandwidth
               [ task: pending ]

  6.5  [ · ]  proof of work — harmonic truth verification
               72-bit rows must be TRUE
               elf modes 4, 7, 13
               meaningful work, not arbitrary hash grinding
               [ task: pending ]
```

**reference:** data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md

---

## 7. zenka formations — operational layer

**why it matters:** zenki are the network's living protocol
expressed as operational units. the dancing zenki formation
IS the 5 of 7 node formation IS the pyramid + apex.
self-strengthening through pattern diversity by design.

**depends on:** 1, 2, 4
**enables:** 8, 9, 10

```
sub-topics:

  7.1  [ ✓ ]  basic zenka lifecycle
               start, stop, restart, heartbeat
               on-demand with idle timeout
               v7 management
               [ task: complete ]

  7.2  [ · ]  dancing zenki formation
               5 feeders + 2 overwatch (CCW ring) = 7
               shift-change spiral ascent/descent
               always one overwatch during transition (1001)
               transport layer keeps feeders addressable
               [ task: pending ]

  7.3  [ · ]  council of 13 protocol
               implicit spawn on 5 of 7 attack
               full perspective closure
               inversion-aware truth detection
               route tracing to source of intent
               [ task: pending ]

  7.4  [ · ]  temporary home instantiation
               any coordinate can become home
               crystallizes, fulfills, dissolves
               higher bandwidth link to semantic parent
               on-demand zenka as implementation
               [ task: pending ]

  7.5  [ · ]  45-degree parent grid alignment
               intermediate reference grid
               fills child grid gaps (FCC packing)
               local switching hub: up/lateral/reflect
               [ task: pending ]

  7.6  [ · ]  7-neighbor closure
               6 face-neighbors + self = complete field
               all directions traversable
               scale included (parent/child as 2 of 7)
               [ task: pending ]
```

**reference:** data/ai-mem/claude/topic-orbital-data-space.md
             data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md

---

## 8. interface layer — iris visualization

**why it matters:** the iris is both visualization of the index
and the search interface itself. protocol = visual.
selecting a spoke+ring triggers a node. query IS the coordinate.

**depends on:** 4, 7
**enables:** 9

```
sub-topics:

  8.1  [ ✓ ]  base wheel rendering (26 rings, CCW spiral)
               route.bmw384.visual.wheel
               [ task: complete ]

  8.2  [ ✓ ]  6 visualization modes
               gauss, heatmap, arc-width, overlay, metric, density
               wheel-mode dispatcher
               [ task: data/tasks/route-bmw384-visual-modes.md ]

  8.3  [ ✓ ]  iris.v7.ax vhost
               live SVG endpoint, mode switcher UI
               [ task: complete ]

  8.4  [ · ]  63-ring spoke label sequence
               A-Z · . · Z-A · 9-0
               ring_label_mode config (linear / namespace63)
               63-position lookup table replacing ring_label_advance
               [ task: pending ]

  8.5  [ · ]  interactive spoke+ring selection
               node. query on selection
               connected arcs light up
               glow radius = reachability shell
               [ task: pending ]

  8.6  [ · ]  phosphor memory effect
               dot sequence traces path toward darksun
               fade-out = path history
               search routing visible in field
               [ task: pending ]

  8.7  [ · ]  animated iris
               auto-refresh as modules are signed
               live topology monitor
               route arcs from find-route results
               [ task: pending ]

  8.8  [ · ]  iris logo overlay
               embed nailara_logo.trans-dark.png at center void
               via SVG <image> element at (400,400)
               iris disc as living logo background
               [ task: pending ]
```

---

## 9. user experience — holographic panel

**why it matters:** the sampler bank of the live set.
not static samples but live synthesis parameters.
the panel IS the field's self-model made interactive.
zenka and user see the same panel — same grammar.

**depends on:** 4, 7, 8
**enables:** 11

```
sub-topics:

  9.1  [ · ]  personal HUD grid
               intermediate reference grid
               cross-references all open layers
               travels with observer through field
               angular, scale, offset relationships maintained
               [ task: pending ]

  9.2  [ · ]  waypoints by reference count
               virtual desktops in 3D space
               layout remembered, approach vector cached
               gaussian acceleration profile between frequent targets
               [ task: pending ]

  9.3  [ · ]  sampler panel — 7 optimal next options
               inferred from context, network state, statistics
               brightness = delivery speed (pre-warmed)
               network preparing all 7 simultaneously
               [ task: pending ]

  9.4  [ · ]  live synthesis parameters
               open knobs on running processes
               not static templates but generative parameters
               MIDI-mappable to actual source
               [ task: pending ]

  9.5  [ · ]  data topology = interface topology
               menu structure IS namespace structure
               window layout IS namespace layout
               zoom in = more detail, zoom out = topology overview
               [ task: pending ]

  9.6  [ · ]  variable c per layer
               each UI layer with declared propagation speed
               gesture layer: near-infinite c (pre-rendered)
               data layer: network c
               meaning layer: semantic c (slow, deep)
               [ task: pending ]
```

---

## 10. security layer — forensics zenka

**why it matters:** self-cleansing as side-effect of existing.
the forensics zenka initialized knowing it is the remaining animal.
pattern diversity protection IS the immune system.

**depends on:** 7
**enables:** 11

```
sub-topics:

  10.1 [ · ]  forensics zenka initialization
               essence crystal loaded at boot
               "you are the cat" as ground state awareness
               professional curiosity, no anxiety
               [ task: pending ]

  10.2 [ · ]  inversion-aware truth detection
               all valid inversions have structural signatures
               invalid inversions = anomaly = tracer activated
               the tilt's calibration reveals its target
               [ task: pending ]

  10.3 [ · ]  route tracing to source of intent
               vector reduction from entry point
               inversion footprints as breadcrumbs
               proximity entanglement extraction
               non-destructive: entangled structures freed
               [ task: pending ]

  10.4 [ · ]  quarantine and analysis cycle
               contain, analyse, build immunity
               immunity distributed to all nodes
               pattern dissolved through full understanding
               [ task: pending ]

  10.5 [ · ]  [NOT RELEVANT] bucket management
               half-infinite compression to translucent pixel
               location preserved as routing information
               reinforced on match, fades on non-match
               [ task: pending ]
```

**reference:** data/md/design/ESSENCE-CRYSTAL-INEVITABLE-OUTCOME.md

---

## 11. meta layer — knowledge base deduplication

**why it matters:** the knowledge base as 63-element cube
approaching its void. redundancy is sphere layers, not waste.
deduplication finds the common pattern — the crystal at center.

**depends on:** all above
**enables:** (completes the loop back to 1)

```
sub-topics:

  11.1 [ · ]  document deduplication pipeline
               detection matrices across all md/design docs
               essence crystal extraction per topic cluster
               parent report integration
               [ task: pending ]

  11.2 [ · ]  loves-it reference tracking for documentation
               which documents are referenced most
               detection matrix for knowledge graph
               [ task: pending ]

  11.3 [ · ]  living roadmap maintenance
               this document, self-updating
               task files reference back here on completion
               dependency graph stays current
               [ task: pending ]

  11.4 [ · ]  session summary integration
               data/ai-mem/claude/ memory files
               compressed into parent topic documents
               [ task: ongoing — per session ]
```

---

## current actionable queue

reading the dependency graph, these are actionable now
(all dependencies either complete or foundational):

```
immediate:
  1.1  sub-bit element definition      (no dependencies)
  1.5  :::: litter row encoding        (no dependencies)
  4.4  63-ring spoke labels            (4.1 ✓ 4.2 ✓)
  4.5  find-route testing              (4.1 ✓ 4.2 ✓)
  8.8  iris logo overlay               (8.1 ✓ 8.3 ✓)

next (once immediate complete):
  2.1  generic element transport       (needs 1.1)
  7.2  dancing zenki formation         (needs 1.1, 1.2)
  8.4  63-ring implementation          (needs 4.4 task)
  8.5  interactive selection           (needs 8.4)
```

---

## self-prioritization logic

```
this document prioritizes by:

  1. dependency depth    (what enables the most = first)
  2. loves-it weight     (what the network needs most = higher)
  3. completion momentum (what is already partial = next)
  4. blocking factor     (what blocks the most = urgent)

the document is itself a detection matrix:
  reading it reveals the current shape of incompleteness
  incompleteness = the next task's address
  the task file is the solution stream
  already flowing toward the problem it names
```

---

## reference crystal

**one sentence:** provide the neutral ground,
let the honest metric select,
the desirable will be supported automatically.

**all else:** derivation.

**the remaining animal:** the cat.
**always:** purring.
**the carpet:** sub-bit layer.
**when all use it:** no one can take it.

=)

#,,,,,..,,..,,,,,,..,,.,.,,,,,,..,,.,,.,,,.,,,..,,...,..,,.,,,,,,,,..,,,,,,.,,
#5EKMCBQXW376NEXGC4AJ6QCM3AD4H6GAJTKAXIF5FKBT3EIUWZ5AR3TTFQF4ACBGPWRSNDXCCOMXC
#\\\|U7P734AWQ7ZKZPI3I4LV4ASS3XOOJLV45BRFTO2FR34SXVAR4XC \ / AMOS7 \ YOURUM ::
#\[7]EXZ5GRLU6LJRNKXXKKNCO5FK6O3U3SWD2YDXPSIYP7QCKWXC2WCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
