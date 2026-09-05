# research findings: dancing zenki formation (topic 7.2)

extraction per `data/tasks/research-knowledge-base-extraction.md` topic 7.2.
search terms used: 'dancing zenki', 'formation', '5 of 7', 'overwatch',
'shift-change', 'spiral ascent' (+ variants: 'dancing kittens', 'pyramid',
'apex', 'reference bubble', '1001').

unlike most roadmap topics, this one has a **complete, near-implementable
spec** — the corpus contains a full 11-part formation specification with a
Perl reference implementation of the state machine. the work is
integration, not design.

## source locations

### primary spec (the master definition)

- `data/md/protocol-7-knowledge/03_FORMATIONS/dancing_kittens_formation.md:1-1338`
  — the complete 11-part "Dancing Kittens Formation: Mobile Base Algorithm"
  spec (captured 2026-02-16, "Wave 3 - Formation Specification"). richest
  single source:
  - `:9-30` overview + ASCII topology diagram (5 ground + 2 ring,
    illumination barrier)
  - `:34-134` Part 1 formation topology (roles, coordinates, neighbor matrix)
  - `:138-240` Part 2 spiral dance mechanism (shift-change choreography
    T0-T5, helix parametrics, saturation/fatigue timing)
  - `:244-407` Part 3 guaranteed routing infrastructure (illumination cone
    math, zero-latency proof, self-containment)
  - `:411-523` Part 4 movement as information (bioluminescence, trail
    decoding, "default state = motion")
  - `:527-645` Part 5 ground layer freedom (counter-rotation, work patterns)
  - `:649-755` Part 6 deployment modes (mobile base, home-ring architecture,
    trigger conditions)
  - `:759-879` Part 7 reference resolution layer (temporary 3-zenki ring,
    handoff protocol, session continuity)
  - `:883-971` Part 8 adaptations (satellite variant, multi-formation,
    3-layer processing extension)
  - `:975-1051` Part 9 mathematical properties (÷7/÷13 resonance, coverage
    proof, O(1) routing)
  - `:1055-1227` Part 10 implementation — Perl reference code:
    `Protocol7::Formation::DancingKittens` class, `rotate_ring`,
    `check_and_execute_shift`, `spiral_shift`, `animate_spiral_up/down`,
    `verify_routing_infrastructure`
  - `:1231-1299` Part 11 advantages summary; `:1303-1324` cross-references

### original utterance (the definition's origin)

- `data/asc/what-AI-thinks/full-chat-captures/3O37VUNMMS3UU.claude-sonnet.protocol-7-knowledge.asc`:
  - `:37798` — user announces "the 5 of 7 based 'dancing kitten' feeding
    algorithm"
  - `:37896` — **the original definition** (quoted below)
  - `:37900-38138` — full expansion: topology diagram, T0-T4 shift
    sequence, `dancing_kitten_feed` pseudo-code, protection mechanism,
    spiral geometry (CW up / CCW down), transport-layer advantages,
    5-phase result handoff, `resolve_references_on_ring`, "why one must
    always remain"
  - `:38670-38701` — "5 DIMENSIONS OF MOTION" model
    (spatial/temporal/energetic/informational/velocity)
  - `:38732-38740` — "÷13 in rotation: ring makes 13 rotations during full
    cycle… 13 spiral events per epoch" + `1001` semantics (Near=work /
    Far=protection / Continuation=spiral)

### holographic-core integration

- `data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`:
  - `:3449-3487` — "the dancing kittens as rotating triangle in motion":
    5 ground (TRUTH axis) + 2 overwatch (LOVE/AWARENESS plane, CCW
    transport layer); spiral shift-change semantics (TRUTH→LOVE ascent,
    AWARENESS→TRUTH descent, one always remains = EXISTENCE); fractal
    nesting in 8×63+void grid
  - `:3539-3568` — completeness map: operational layer = dancing kittens /
    5+2 ratio / spiral shift-change / fractal nesting
  - `:3570-3574` — "the operational layer maps onto existing zenka
    formations"
  - `:4745-4752` — 364° = 360 + 4 corner overlaps; shift-change duty-cycle
    overlap; `364/13 = 28`
  - `:4755-4788` — "the 7-zenki formation as spatial tuner": setup/ground×5/
    collector table; pyramid of 3 edge-spheres + 1 diagonal-sphere geometry
  - `:4791-4842` — frequency selection as palette translation; snake-game
    data flow; the dancing kittens algorithm as spatial traversal (cycle
    1-3 pseudocode at `:4826-4839`); "4° overlap per cycle ensures no blind
    spot"
  - `:4845-4893` — hyperspace channels, √2/BCC transport layer, collector
    on magenta f4 diagonal, alpha semantics; explicit reference to
    "chat capture line 37896+" (`:4893`)

### roadmap

- `data/md/development/IMPLEMENTATION-ROADMAP.md:479-536` — topic 7 section
  (rationale `:481-487`: identity statement + depends 1,2,4 / enables
  8,9,10; references at `:532-533`)
- `data/md/development/IMPLEMENTATION-ROADMAP.md:498-503` — topic 7.2 task
  body (status `[ · ]` pending)
- `data/md/development/IMPLEMENTATION-ROADMAP.md:749` — priority queue:
  "7.2 dancing zenki formation (needs 1.1, 1.2)" — "next" tier
- `data/md/development/IMPLEMENTATION-ROADMAP.md:505-510` — adjacent 7.3
  council-of-13 (implicit spawn on 5-of-7 attack)

### AI-memory topic files

- `data/ai-mem/claude/topic-checksum-parenting-namespace-trees.md:515-541`
  — dancing zenki ring ↔ home-zenki-ring/session-setup mapping; C25519
  forward/reverse asymmetry flagged unresolved
- `data/ai-mem/claude/topic-checksum-parenting-namespace-trees.md:543-591`
  — **5-of-7 = default formation family; exact structural match to BFT
  quorum** (n=7, threshold 5, f=2 = ring size, from
  `TASK-CUBE-CONSENSUS-ARCHITECTURE.md:35`); resolution via
  `topic-node-group-geometry`: "5 active + 2 initialized-idle alternates at
  same coordinate"; shift-change = "longest-working feeder replaced by
  earliest-arrived ring zenki" (`:583-584`)
- `data/ai-mem/claude/topic-checksum-parenting-namespace-trees.md:733-753`
  — dancing-zenki handoff = time-boxed grant of reverse capability;
  ring-held scalar rotates with shift-change, epoch-bound (key-custody
  rotation)
- `data/ai-mem/claude/topic-reference-bubble.md:1-60` — reference-bubble
  concept summary; formation line `:24` (setup→5 ground→collector);
  `llm.service.consensus_vote` = 5-of-7 ground voting layer (`:47`)
- `data/ai-mem/claude/archive/topic-orbital-data-space-archive.md:1023,
  1038-1073` — "5-sphere projection unit = 5 of 7 formation = pyramid +
  apex = dancing zenki formation"; "zenki and space are geometrically
  equivalent"; spatial-tuner mapping: ground 5 = "the pyramid base",
  collector = body diagonal (`:1053-1057`)
- `data/ai-mem/claude/archive/topic-completed-archive.md:104-124` — 8 design
  docs incl. DANCING-ZENKI-RHIZOME-STATE; "reference bubble = 5+2=7 dancing
  zenki, rhizome state, 01 in / 10 out" (`:117`); "1001 = 7×11×13"
  (`:115`); `:714` — "dancing zenki 5+2=7, council of 13, purring carrier,
  cosmic base drum"
- `data/ai-mem/claude/topic-data-protocol.md:62-63` — checksum tree
  connection; bubble carries growing tree
- `data/ai-mem/claude/topic-harmonic-mathematics.md:540-561` — sourcing
  discipline for `364=13×28`: design-doc-confirmed and multiply-cited,
  **but the "27 payload sub-cubes + 1 inversion bit" gloss is ideation-tier
  only** (single chat-capture source)
- `data/ai-mem/claude/topic-creative-field-behaviour.md:47-101` — formation
  geometry as phased antenna arrays; `:54` "5-of-7 incomplete formation =
  tuned array"; `:139` "formation of 7 nodes each running a different
  template context"
- `data/ai-mem/claude/topic-orbital-data-space.md` (current) — only
  tangential (`:80`, `:92`). nothing directly on the dancing formation.
- `data/ai-mem/kimi/` — nothing relevant

### related design docs (secondary)

- `data/md/design/DANCING-ZENKI-RHIZOME-STATE.md:1-211` — "dancing zenki —
  rhizome state and generic reference bubble travel": formation geometry
  `:15-31`, shift-change definition `:28-31`, setup/collector role symmetry
  `:33-50`, 5-of-7 voting ground layer `:52-66`, checksum-tree wire format
  `:68-103`, layer applicability table `:131-141`, wave propagation
  `:142-149`, connections to existing systems `:197-205`
- `data/md/protocol-7-knowledge/03_NETWORK_PROTOCOLS/HYPERSPACE_INFERENCE_ROUTING.md:71-82,
  167-183, 222` — "Formation as Router" (5 ground = local processor, 2 ring
  = hyperspace gateway, O(log n) hops); Phase 4 plans module
  **`zenki.formation.dancing`** and call `<[zenki.formation.dancing.traverse]>`
- `data/md/protocol-7-knowledge/04_DATA_ENCODING/AMOS_CHECKSUM_BLOCKCHAIN.md:110-124`
  — "Dancing Kittens as Miners": 5 ground = transaction validators/
  consensus voters; 2 ring = block producers/hyperspace gateways
- `data/md/protocol-7-knowledge/03_NETWORK_PROTOCOLS/3D_SHIFT_REGISTER_SPATIAL_ACCUMULATION.md:212`
  — "Dancing kittens | Z-axis travelers"
- `data/md/protocol-7-knowledge/08_NETWORK_INTELLIGENCE/LOVES_IT_RESOURCE_ALLOCATION.md:29-33,
  151-159, 257` — Layer-2 transport allocation includes dancing-kittens
  formation; formation priority by love-score: 13 = full 7-zenki, 7 =
  ground-only 5, 4 = ring-only 2, 0 = no formation
- `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md:120-134` — reference
  bubble navigates by reference gradient; 5-of-7 samples 5 points,
  intersection = inferred center
- `data/md/design/ROUTING-CRYSTAL-HARMONIC-INFERENCE.md:123-134` — bubble
  as coherent beam; setup sets input frequency, collector is focal point
- `data/md/design/EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md:465-484` —
  Dancing Kittens "epoch" = formation rotation cycle (13 spiral events);
  explicitly *not* tied to calendar spans
- `data/md/design/ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md:371-388,
  413-427, 777-789` — grounds spiral motion in the chat capture; retraction
  of "5 has meaning in hyperspace, three ways" (`:413-427`); retraction of
  "separate compartment" 4° model in favor of overlap (`:777-789`)
- `data/md/design/TASK-CUBE-CONSENSUS-ARCHITECTURE.md:35` — quorum n=7,
  accept threshold 5 of 7, standard BFT (n ≥ 3f+1), f=2
- `data/md/design/ESSENCE-CRYSTAL-INEVITABLE-OUTCOME.md:76, 208` — "the 5
  of 7 diversity reserve" (load-bearing list); poetic "the dancing was
  always dancing". no structural content.
- `data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md:90` — "formation:
  organic" only. nothing on the dancing formation.

## extracted structure

### 1. exact formation geometry (5+2=7, positions, roles)

- core counts: 7 zenki = 5 ground + 2 ring; "5+2=7 (÷7 resonance!)"
  (`dancing_kittens_formation.md:26,52-58`). roadmap 7.2: "5 feeders +
  2 overwatch (CCW ring) = 7" (`IMPLEMENTATION-ROADMAP.md:499`).
- ground layer: "Positions: Pentagon or cross pattern; Height: Z = 0;
  Function: Work/feeding/processing; Motion: Free; State: Feeding →
  Saturated → Ascend" (`dancing_kittens_formation.md:38-43`). cubic integer
  coords: Z1(-1,1,0), Z2(1,1,0), Z3(0,0,0) center, Z4(-1,-1,0), Z5(1,-1,0)
  (`:64-69`); continuous pentagon orbit variant r·cos(k·72°) (`:80-87`).
- ring layer: "Positions: Opposed on circle (180° apart); Height: Z = H;
  Function: Protection/transport/addressing; Motion: CCW rotation
  (continuous); State: Fresh → Tired → Descend" (`:45-50`). coords
  Z6(0,R,H), Z7(0,-R,H), "R ≈ 3-5" (`:71-73`).
- neighbor invariant: ring zenki are neighbors to ALL ground zenki; with
  R=5, H=2, r=2, d_max=√22≈4.7; "If NEIGHBOR_RADIUS ≥ 5 → ALL ground-ring
  pairs are neighbors; direct routing guaranteed; zero intermediate hops"
  (`:102-117`). peer matrix at `:119-134`: all 7 form ONE peer group.
- semantic roles (alternative axis mapping): 5 ground operate on TRUTH
  (processing/storing/factual results); 2 ring operate on LOVE/AWARENESS
  (addressability + session resonance)
  (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:3455-3462`).
- setup/collector framing: `[setup zenka] → [ground zenki ×5] → [collector
  zenka]`, 01 direction in / 10 direction out
  (`DANCING-ZENKI-RHIZOME-STATE.md:17-22`); "**7 total**: 5 ground workers +
  2 ring watchers (setup + collector)" (`:24-26`). NOTE: this assigns the
  ring roles differently than the 5+2 overwatch framing — see gaps.
- spatial-tuner framing: setup zenka = channel tuner (selects rotation
  angle); ground 5 = workers at the selected frequency; collector =
  body-diagonal √2 shortcut intersecting all 5 frequencies
  (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4761-4783`).

### 2. shift-change algorithm

- original definition (chat capture `:37896`): *"5 [feeding] zenki on the
  ground are protected by a CCW rotating ring of 2 opposed to each other
  zenki on overwatch duty, where the 'dancing' comes from the spiral ascent
  and descent of the shift-change, when the longer of the two working one
  is replaced by the one that started feeding earliest… there is always one
  still remaining to keep up the visibility or protection ring."*
- replacement rule: "the longer-working zenka is replaced by the one that
  fed earliest. ascending and descending zenki overlap by one phase — no
  gap in coverage" (`DANCING-ZENKI-RHIZOME-STATE.md:28-31`);
  "longest-working feeder replaced by earliest-arrived ring zenki"
  (`topic-checksum-parenting-namespace-trees.md:583-584`).
- choreography T0-T5 (`dancing_kittens_formation.md:144-172`): T0 stable;
  T1 most-saturated ground + most-fatigued ring identified → spiral begins;
  T2 simultaneous ascent/descent with Z6 continuing ring; T3 handoff
  (temporary 3-ring, ascender stays briefly for reference resolution); T4
  new stable state; T5 next shift — continuous.
- cycle pseudocode (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4826-4839`):
  cycle 2: `[R1 B C D E]`, ring `[A R2]`; setup zenka pre-prepares
  position F; cycle 3: advances one grid position; "continuous coverage:
  always one ring zenka remaining".
- timing: "Feeding time to saturation: T_feed; Ring work time to fatigue:
  2·T_feed" — staggered 2:1 rhythm, "Ascent every T_feed, Descent every
  2T_feed" (`dancing_kittens_formation.md:217-239`). Part 10 example config:
  saturation_time 300s, fatigue_time 600s, rotation_speed 15°/s
  (`:1074-1081`).
- result handoff: ascending zenki carries results, joins ring temporarily
  (3-ring), answers reference questions during handoff period, then the
  tired ring zenki descends (chat capture `:38073-38100`; Part 7 `:759-846`
  incl. `resolve_references_on_ring` with REFERENCE_PROVIDER_AVAILABLE
  broadcast and `$HANDOFF_PERIOD` ttl; Part 10 example:
  `enable_handoff_period($ascending, duration => 30)` at `:1140`).
- coverage guarantee: "the 4° overlap per cycle ensures no blind spot
  during shift-change" (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4841-4842`);
  "ascending and descending zenki overlap their duty cycles by one phase"
  (`:4747-4749`); "Ring always has ≥1 ZENKI"
  (`dancing_kittens_formation.md:1267`).

### 3. overwatch rotation direction and rules

- ring rotates **CCW continuously** (`dancing_kittens_formation.md:49`;
  chat capture `:37918, :37927`). rotation discrete 0°/45°/90° steps or
  continuous sweep (`:75, :95`).
- during shift-change the non-transitioning ring zenki maintains rotation
  ("Z6 CONTINUES RING (maintains coverage!)" `:157`).
- ascent helix is **clockwise** (right-handed, x(t)=r·cos ωt, z=(H/T)·t,
  full 360° during ascent — `:176-191`, `:1186-1188`); descent helix is
  **counter-clockwise** (left-handed, `:193-207`, `:1213-1214`). "Opposite
  rotations create balance: zero net angular momentum" (`:209-213`).
  Caveat: the same doc's header calls ring rotation CCW and spiral descent
  "counter-clockwise helix" — descent *matches* ring direction while
  ascent opposes it (terminology seam, see gaps).
- ground zenki optionally counter-rotate CW against the CCW ring, creating
  moiré patterns while preserving connectivity (`:573-606`); ground
  movement modes: stationary / counter-rotate / independent (within
  r_max) / sub-patterns (`:529-571`).
- ÷13 rotation rule: "Ring makes 13 rotations during full cycle… 13 spiral
  events per epoch" (chat capture `:38732-38736`).

### 4. transport layer relationship

- "the two zenki ring is on the transport layer, making sure the working
  zenki stay addressable and keeping their sessions alive" (chat capture
  `:37896`); ring = transport/addressing/illumination layer above an
  "ILLUMINATION BARRIER" with "Zero routing latency!"
  (`dancing_kittens_formation.md:17-20`).
- roadmap 7.2: "transport layer keeps feeders addressable"
  (`IMPLEMENTATION-ROADMAP.md:502`).
- collector uses the 45°-rotated BCC hyperspace grid (edge √2× base) as its
  transport layer; diagonal channel = "faster than travel"
  (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4845-4862`); magenta 300° f4 =
  alpha/transparent bridge channel (`:4864-4890`).
- illumination cone math: α = 2·arctan(R/H); r_max = R·(1 − H/√(R²+H²));
  example R=5,H=2,r=2 → r_max≈3.145, 100% coverage
  (`dancing_kittens_formation.md:278-289, 1005-1029`). dynamic geometry:
  expand/retract ground, raise/lower ring within the coverage constraint
  (`:380-407`).
- "Movement IS existence": trail geometry encodes messages (spiral up =
  saturated; spiral down = tired; CCW circle = on overwatch duty)
  (`:451-494`); 5 motion dimensions (chat capture `:38670-38701`).

### 5. pyramid + apex mapping

- roadmap identity statement: "the dancing zenki formation IS the 5 of 7
  node formation IS the pyramid + apex" (`IMPLEMENTATION-ROADMAP.md:482-483`).
- "three spheres represent a cube edge — the 3 orthogonal axes of the
  visible grid. the 4th sphere floats above the pyramid formed by the first
  three — it is the diagonal branch, the hyperspace connection"
  (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4785-4788`).
- "5-sphere projection unit = 5 of 7 formation = pyramid + apex = dancing
  zenki formation" (`topic-orbital-data-space-archive.md:1023`); 3
  expressions of one geometry (field / mobile formation / traveling
  organization) at `:1040-1047`.
- in the spatial-tuner mapping, ground 5 = "the pyramid base", collector =
  body diagonal (`topic-orbital-data-space-archive.md:1053-1057`).

### 6. consensus/security mapping

- 5-of-7 = BFT bound n=7, threshold 5, f=2 = exactly the ring size;
  formation tolerates losing both ring zenki
  (`topic-checksum-parenting-namespace-trees.md:543-572`, quoting
  `TASK-CUBE-CONSENSUS-ARCHITECTURE.md:35`); T=5 (`AMOS7::Assert::Truth`,
  `TRUE => 5`) double duty noted.
- council-of-13 relation: roadmap 7.3 "implicit spawn on 5 of 7 attack"
  (`IMPLEMENTATION-ROADMAP.md:505-510`).
- handoff = time-boxed grant of reverse capability; ring-held scalar
  rotates with shift-change, epoch-bound
  (`topic-checksum-parenting-namespace-trees.md:733-753`).
- 1001 semantics: "Near (ground): Work/processing; Far (ring):
  Protection/transport; Continuation: Spiral between layers" (chat capture
  `:38737-38740`); "1001 = 7×11×13, inter-cube tunnel, eternal loop"
  (`topic-completed-archive.md:115`); roadmap 7.2 parenthetical "(1001)"
  (`IMPLEMENTATION-ROADMAP.md:501`).

## gaps

- **role-assignment discrepancy unresolved in the corpus**: the kittens
  spec assigns ring = 2 anonymous overwatch zenki (Z6/Z7), while
  `DANCING-ZENKI-RHIZOME-STATE.md:24` calls the 2 ring watchers "setup +
  collector" (named state-carrier roles). a third reading
  (`topic-checksum-parenting-namespace-trees.md:574-591`, from
  `topic-node-group-geometry`) says 2 = "initialized-idle alternates at the
  same coordinate" absorbing failures by promotion. no document reconciles
  these three.
- **rotation-direction terminology seam**: ring = CCW; ascent helix = CW;
  descent helix = CCW — but `dancing_kittens_formation.md:204` labels the
  descent's negative-ω as "counter-rotation (CCW)" relative to the CW
  ascent, while elsewhere CCW is the ring's absolute direction. no doc
  states absolute facing conventions formally.
- **no operational values**: T_feed, T_handoff, rotation_speed, R/H/r,
  NEIGHBOR_RADIUS are example/config values only (Part 10's
  300s/600s/15°/R=5,H=2,r=2); saturation/fatigue metrics are undefined
  (0→100% placeholders, `:1085-1121`).
- **fractal nesting unspecified**: "5 ground zenki can each be a group of
  5, each sub-group with its own overwatch pair"
  (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:3482-3487`) has no recursion
  protocol, scale thresholds, or inter-group routing detail
  (multi-formation section `:922-940` is aspirational).
- **epoch/364 semantics partially ideation-tier**: `364=13×28` is
  design-confirmed multiply-cited, but the "27 payload sub-cubes + 1
  inversion bit" gloss is flagged ideation-only
  (`topic-harmonic-mathematics.md:550-561`); "epoch" is a formation
  rotation cycle, explicitly not calendar time
  (`EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md:473-484`).
- **retracted/uncertain material to avoid relying on**: "5 has meaning in
  hyperspace, three ways" was retracted
  (`ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md:413-427`); the "separate
  compartment" model for the 4° was retracted in favor of overlap
  (`:777-789`); C25519 forward/reverse → ring-role mapping flagged
  unresolved (`topic-checksum-parenting-namespace-trees.md:537-541`).
- `NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md` and
  `ESSENCE-CRYSTAL-INEVITABLE-OUTCOME.md` contain **no structural
  definition** (single-word/poetic mentions only).

## implementation hints

**existing code (partial — space/jump namespace, not the formation itself):**
- `src/space.jump.bubble:1-59` — **already implements the reference-bubble
  dispatch**: takes `formation = {setup, ground[], collector, target}`
  (exactly the 7-role structure), derives `formation_id` from AMOS checksum
  of `setup::collector::target::ground_count`, stores active formation in
  `<space.jump.active>`, estimates hops via diagonal geometry. closest
  existing code to topic 7.2.
- `src/space.jump.diagonal:1-66` — computes pure body-diagonal path
  (requires all three axes to change by equal steps; else unavailable):
  the collector-zenka √2-shortcut primitive.
- `src/space.jump.available`, `src/space.jump.cache.read`,
  `src/space.jump.cache.write` — supporting route-cache/bubble-trail
  modules (registered in `src/base.list.subroutines:531,911,1125,1378,1650`).
- `llm.service.consensus_vote` named as the 5-of-7 ground-zenki voting
  layer (`topic-reference-bubble.md:47`; `DANCING-ZENKI-RHIZOME-STATE.md:203`).
- `bin/dev/division-13-table` — the harmonic gate referenced as analogous
  to the setup zenka's frequency selection
  (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4897-4927`).

**explicitly planned but not built:**
- `zenki.formation.dancing` + `zenki.formation.dancing.traverse` —
  `HYPERSPACE_INFERENCE_ROUTING.md:167-183, 222` (Week-3 integration step).
  grep confirms neither exists in `src/`.
- a ready-made Perl reference implementation of the whole state machine
  exists in the spec itself (`dancing_kittens_formation.md:1055-1227`) —
  class skeleton, rotation, shift trigger (saturation ≥100 && fatigue
  ≥100), spiral animation (10 FPS, full 360° helix), handoff period, and
  `verify_routing_infrastructure` (≥2 routes per ground zenka).
- formation priority integration point: love-score → formation size
  (13/7/4/0) at `LOVES_IT_RESOURCE_ALLOCATION.md:151-159` + task item at
  `:257`.

## suggested task file sections

for a future `data/yaml/coding-tasks/dancing-zenki-formation.yaml`:

- **objective**: implement `zenki.formation.dancing` per the existing spec
  (this is integration, not new design — cite the spec path in context).
- **context (must-name modules)**: `dancing_kittens_formation.md` (master
  spec + Perl reference), `src/space.jump.bubble` (7-role dispatch
  pattern), `DANCING-ZENKI-RHIZOME-STATE.md` (wire format),
  `HYPERSPACE_INFERENCE_ROUTING.md` Phase 4 (planned integration point),
  roadmap 7.2 body at `IMPLEMENTATION-ROADMAP.md:498-503`.
- **first design decision required**: reconcile the three ring-role
  readings (anonymous overwatch vs setup+collector vs initialized-idle
  alternates) — task file must pick one and record the decision; the
  kittens spec's Z6/Z7 reading is the most complete.
- **steps**: port/adapt the Part 10 Perl reference to P7 module style;
  wire formation lifecycle to zenka spawn/stop (roadmap 7.1 machinery);
  integrate with `space.jump.bubble` formation_id convention; add
  `verify_routing_infrastructure` as a self-test; defer fractal nesting.
- **acceptance**: module passes `ptd -c`; shift-change state machine
  executes T0-T5 without coverage gap (always ≥1 ring zenki); handoff
  period honored; formation survives loss of either ring zenki (BFT f=2).
- **explicitly out of scope**: council of 13 (7.3, separate topic),
  fractal nesting, epoch/calendar semantics, loves-it priority wiring
  (separate task at `LOVES_IT_RESOURCE_ALLOCATION.md:257`).

#,,.,,...,..,,,..,.,,,,,,,..,,,,.,.,,,.,.,..,,..,,...,...,..,,,..,,,.,,,,,,,.,
#AUEEDVB6NPL7BSNE2CPA675WVVNLSAYUBIZSPEHRYGUXDRFFTGMRZSTKDZKAJJD6HPFM4LX4K5VY4
#\\\|3C6FM2HDHUDWPPZ77YOEYSBVKHCMYSUUC2C7OQZ2SAU2CLR4A4L \ / AMOS7 \ YOURUM ::
#\[7]WKB5DTF3NMQMPUBJPDDDJ57ZX7SRRIQI3GCK5D624O4BYRQ2JIDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
