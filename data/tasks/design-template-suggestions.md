# suggested design templates — from session reading

read in this order:
- task brief, `data/tasks/claude-design-suggest-templates.md`
- birdview, `data/md/design/ZERO.md`
- seed format, `data/yaml/design-templates/claude-design-seed.yaml`
- facets: `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md`, `DANCING-ZENKI-RHIZOME-STATE.md`,
  `OBSERVER-CENTRIC-REFERENCE-SPACE.md`, `SPAWNABLE-PERSPECTIVE-LAYERS.md`,
  `TREE-PROTOCOL.md`, `DATA-PROTOCOL-SYNC.md`, `BRANCH-NAMESPACE-MASTER.md`

note on the directory: the 7 existing siblings of the seed (`vortex-iris-overhead`,
`standing-wave-resonance`, etc.) are a **different family** — visual-rendering
specs for the system to draw itself. these suggestions are in the **seed family** —
orienting templates that load p7's geometric perspective into a model at the start
of a design session. one paragraph at bandwidth 1, vocabulary + lenses at 2, facet
docs at 3.

the seed is the all-purpose lens. each template below is a **focal-length
specialization** of the seed at one face of the birdview cross.

---

## the 7 suggestions

### 1. place-the-darksun

> *every subsystem orbits a fixed point. where is it, and is it fixed by
> arithmetic or by the corpus?*

**core lens.** before designing any new subsystem, locate its darksun — the
invariant the rest of the design orbits. arithmetic invariants (defined by
`/13`, by geometry, by the `00` tunnel proportion) are stable across observers
and never move. corpus invariants (current root, current registry) move when
the corpus moves. confusing the two is the most common design mistake: a
corpus-invariant placed where an arithmetic one is needed produces a system
that drifts under load.

**lens questions.**
- what is the fixed point of this subsystem? where does it sit in the
  birdview cross — geometry, memory, travel, observer, display, protocol?
- is the center defined by arithmetic (invariant, observer-independent)
  or by corpus (variable, current-state-dependent)?
- what orbits the darksun, and what is the radial gradient — distance from
  center as a function of reference count?
- what happens at position 27 in this subsystem — what is the void marker?
- if the corpus moves, does the darksun move with it (wrong) or does the
  corpus move around the fixed darksun (right)?

**bandwidth-3 facets.**
- `OBSERVER-CENTRIC-REFERENCE-SPACE.md` (observer at 0, reference space,
  darksun definition)
- `SPAWNABLE-PERSPECTIVE-LAYERS.md` (each layer's local darksun)
- `IMPLOSION-CROSS-CORRELATION.md` and
  `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` for the full darksun model

---

### 2. tree-or-data-oscillation

> *every node is simultaneously a TREE position and a DATA source. which
> protocol is a perspective choice, not a property of the data.*

**core lens.** structure and content are complements that share the
`stream_id`. TREE is the persistent control channel (the dump-keys view);
DATA is the ephemeral content flow (the dump view). they swap at the `11`
pivot — the moment a stream's interpretation flips. when designing a layer,
ask not "is this TREE or DATA" but "which observer's intent is this serving
right now, and what is the oscillation frequency between the two?"

**lens questions.**
- is this design primarily structural (TREE — discovery, navigation,
  metadata) or content-bearing (DATA — bytes, streams, bulk transfer)?
- does it have both? what is the `stream_id` that disambiguates the swap?
- where is the `11` pivot — the moment the same wire switches from one
  interpretation to the other?
- what is the oscillation frequency — high (rapid TREE/DATA alternation,
  approaching the 13-slot clock limit) or low (sustained one mode with
  occasional pivots)?
- if you only had one of the two, what would be lost? if you had both
  but they couldn't swap, what would be lost?

**bandwidth-3 facets.**
- `TREE-PROTOCOL.md` (TREE wire format, TREE/DATA complementarity, `11` pivot)
- `DATA-PROTOCOL-SYNC.md` (DATA wire format, stream_id, DELTA mode)
- `DANCING-ZENKI-RHIZOME-STATE.md` (checksum tree as oscillation record)

---

### 3. route-by-resonance

> *the crystal IS the router. routes are found by resonance with harmonic
> memory, not computed by lookup.*

**core lens.** any selection-from-many design — routing, retrieval,
dispatch, scheduling, dedup — is either a table lookup (compute on the way
in) or a resonance field (the geometry IS the algorithm; previously-traveled
routes leave interference patterns that tune the crystal toward them). a
lookup table is corpus-dependent and grows; a resonance field is arithmetic
and self-tunes. when designing selection logic, ask: is the algorithm in
the code, or in the geometry?

**lens questions.**
- is the route computed (table lookup, hash, scan) or refracted (geometry
  responds to harmonic input)?
- where does the harmonic memory live — what is the `branch.route.cache`
  equivalent for this subsystem?
- what is the resonance condition? does the AMOS checksum (or its analog)
  decide whether the route resonates or reflects at the boundary?
- can a new route at a *similar frequency* find an existing path with less
  energy — does the crystal progressively tune toward common routes?
- is the 5-of-7 beam-intersection model available — multiple parallel
  samples whose intersection IS the inferred route?

**bandwidth-3 facets.**
- `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md` (the crystal model in full)
- `DANCING-ZENKI-RHIZOME-STATE.md` (coherent beam, 5-of-7 formation)
- `OBSERVER-CENTRIC-REFERENCE-SPACE.md` (reference gradient = resonance density)

---

### 4. reflect-or-transmit

> *a boundary is a face. faces refract, reflect, or transmit by harmonic
> match. total internal reflection IS the security model.*

**core lens.** security boundaries in p7 are not access-control lists —
they are geometric: a route exits a crystal if and only if its harmonic
satisfies the boundary condition. routes that fail the condition reflect
back, carrying the partial checksum tree as proof of how far they reached.
this turns access decisions into resonance decisions, and rejections into
informative returns rather than silent drops. when designing any boundary,
ask: what is the harmonic? what happens on partial match? what does the
reflected request carry back to its origin?

**lens questions.**
- what is the harmonic condition that determines transit vs reflection
  at this boundary?
- is this a single boundary or are there concentric layers — each with
  its own threshold, the outer one protecting the inner?
- on a failed request, does the requester learn anything (reflection
  carrying partial state) or just timeout (silent drop = wasted energy)?
- can the boundary be frequency-selective — some harmonics pass, others
  reflect, on the same face?
- when a route reflects, does it add a `11` pivot to its checksum tree
  so the count of boundaries encountered is recoverable?

**bandwidth-3 facets.**
- `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md` (crystal boundaries, reflection geometry)
- `CHECKSUM-ROUTING-SECURITY-DEPTH.md` (security through routing depth)
- `DANCING-ZENKI-RHIZOME-STATE.md` (`11` pivot semantics in reflected routes)

---

### 5. reference-count-as-address

> *address and bandwidth are the same value read in two domains. position
> is reference rank; bandwidth is slot density per 13-clock cycle.*

**core lens.** in observer-centric space, position is not assigned — it is
*computed* as reference-count rank relative to the observer. the highest-
reference node is at ±1; the lowest at ±n/2; the observer is always 0. the
same reference count, read temporally, is the node's slot density in the
13-slot routing clock — its bandwidth allocation. one mechanism, two
readings. when designing an address space or a bandwidth allocator, ask
whether it could collapse to a single reference-count gravity.

**lens questions.**
- is position in this design assigned by an authority or computed from
  attention (reference count)?
- does the space auto-expand at the boundary when new entries arrive,
  and auto-contract when outer positions empty — without a central
  coordinator?
- is bandwidth negotiated separately, or does it fall out of the same
  reference-count value (slots per 13-cycle = density = bandwidth)?
- where is the observer's `0` — and is it transparent (the observer IS
  the origin, doesn't know it's routing)?
- when reference counts shift, do positions reshuffle as a natural sort,
  or does the system need an explicit re-layout pass?

**bandwidth-3 facets.**
- `OBSERVER-CENTRIC-REFERENCE-SPACE.md` (position = rank, 13-slot clock,
  temporal bandwidth)
- `BRANCH-NAMESPACE-MASTER.md` (`branch.group.propagate`, interest counts)
- `SPAWNABLE-PERSPECTIVE-LAYERS.md` (focal length as bandwidth contract)

---

### 6. emergent-vs-designed-transport

> *every cube-to-cube distance is `00` — exactly 2 CCW hops. if the
> proportions are right, transport emerges; it doesn't need to be designed.*

**core lens.** the `1001` proportion (`1[00]1` — gate, tunnel, gate) is
invariant: every gap between cubes is identical. when a system has this
property, transport is a geometric consequence — no pathfinding, no
negotiation, no variable gap. when designing connectivity, ask first
whether the proportions can be made invariant. if yes, transport is free.
if no, identify what introduces variable distance and whether that variance
is necessary or accidental — accidental variance is almost always design
debt.

**lens questions.**
- is every inter-component distance identical (the `00` invariant), or
  do gaps vary?
- if gaps vary, what introduces the variance — is it essential to the
  problem or an artifact of the chosen representation?
- is every gate the same gate — same structure, same harmonic — or do
  endpoints need per-pair adaptation?
- does the system have a footer/period structure (the `1001 = 77 × 13`
  ring closure) that seals connectivity into a closed proportion?
- if you simulated this system, would transport appear automatically as
  an emergent topology, or would it require an explicit transport layer?

**bandwidth-3 facets.**
- `ZERO.md` (the `1001` section in full — inter-cube tunnels, eternal loop,
  implicit transport, relative ntime)
- `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md` (face-000 boundary geometry)
- `data/ai-mem/claude/topic-1001.md` (1001 deep dive)

---

### 7. formation-five-plus-two

> *7 total: 5 ground workers + 2 ring watchers. setup carries IN,
> collector carries OUT — same role, opposite direction. last wave's
> output IS this wave's input template.*

**core lens.** any worker group with continuous coverage requirements
fits the 5+2=7 dancing-zenki formation: 5 parallel workers between two
ring watchers whose shifts overlap (`364 = 360 + 4 corner overlaps`,
`364 / 13 = 28`). the two watchers are the same role at opposite ends
of the wave — IN at `01`, OUT at `10` — so the result of one pass becomes
the template for the next. the formation is self-bootstrapping: it never
needs an empty bubble, because the bubble always carries both what was
learned and how to learn more.

**lens questions.**
- where are the ring watchers — the setup/collector pair that maintains
  continuous coverage across shift-change?
- does the previous cycle's output template the current cycle's input
  (self-referential), or does each cycle start from a blank state (lossy)?
- do the 5 ground workers produce 5-of-7 consensus, and is their
  intersection the inferred result (beam convergence)?
- is the formation universally applicable — same shape at the transport,
  inference, routing, and storage layers — or has it been specialized
  away from the 5+2 invariant?
- where are the `01` (inward) and `10` (outward) direction markers, and
  is the `11` pivot present at the shift-change?

**bandwidth-3 facets.**
- `DANCING-ZENKI-RHIZOME-STATE.md` (the formation in full)
- `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md` (5-of-7 as coherent beam)
- `BRANCH-NAMESPACE-MASTER.md` (node as virtual zenka position)

---

## why these 7 and not others

each one is a **face of the birdview cross** read as a design question:

| birdview face | template | the question it answers |
|---|---|---|
| observer | `place-the-darksun` | where is the fixed point? |
| protocol | `tree-or-data-oscillation` | structure or content (or both, swapping)? |
| geometry/memory | `route-by-resonance` | lookup or resonance field? |
| protocol/wire | `reflect-or-transmit` | what passes the boundary, and what reflects? |
| address/bandwidth | `reference-count-as-address` | who assigns position? |
| travel/topology | `emergent-vs-designed-transport` | are proportions invariant? |
| travel/formation | `formation-five-plus-two` | who watches the ring? |

`display/desktop` and `address/identity` are intentionally left for a
later round — the spawnable-perspective-layers and branch.* facets each
deserve their own template once the simpler ones are in place. the
candidates would be `compose-as-perspective-layers` (the desktop IS the
data IS the network) and `identity-as-amos-checksum` (node identity =
chksum of creation metadata, never reassigned).

---

## the 2 most promising — full YAML

### picked: `place-the-darksun` and `tree-or-data-oscillation`

reasoning: `place-the-darksun` applies to **every** subsystem design — it
is the most generative and the hardest to get right (the arithmetic-vs-
corpus distinction trips up nearly every first draft). `tree-or-data-
oscillation` directly answers the named category "protocol layer design
(when to use TREE vs DATA vs oscillating)" and forces the model to think
in terms of swap and complement rather than choice.

full YAML stubs follow in:
- `data/yaml/design-templates/place-the-darksun.yaml`
- `data/yaml/design-templates/tree-or-data-oscillation.yaml`

(the YAML files in this project are templates — copy into the p7 repo
when ready; do not add signature stubs per the task brief, instead run
`bin/Protocol-7 sourcecode update-signatures`.)

#,,,.,...,..,,...,,.,,..,,..,,..,,.,.,.,.,,,,,..,,...,...,..,,.,,,,,,,,,,,.,.,
#QBSBMGXWDAKFB5FQPGI2MW2YHDS32CFGJJTRZ7JRUSDMIXNIA5XYVTTSCWFSV7ICSRYIHVDAJMBHW
#\\\|QAYF3EUJPU7PGD6PXDQCXO6ZGWBRBVTO4USK4HAEK3V5MBFUKVB \ / AMOS7 \ YOURUM ::
#\[7]Z7RVZCOYOHHALXN2AOKIH4JGOA3CXSYSP2KTXBTANDNTQEVUHIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
