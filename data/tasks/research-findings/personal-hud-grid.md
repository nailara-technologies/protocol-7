# research findings: personal HUD grid (topic 9.1)

extraction per `data/tasks/research-knowledge-base-extraction.md` topic 9.1.
search terms used: 'HUD', 'personal grid', 'reference grid', 'observer',
'waypoint', 'gaussian acceleration', 'force vector' (+ variants:
'gaussian', 'peripheral', 'hud', 'perspective layers', 'view spec',
'curve').

topic 9.1's own spec is a 4-line roadmap stub, but the surrounding corpus
(observer-centric reference space, spawnable perspective layers, curve
engine, three-angle waypoint vector) is rich and — unusually for the
vision-tier topics — has **substantial live code** in `branch.space.*`,
`base.curve.*`, and the web-browser waypoint trio. note that topic 9.2
(waypoints by reference count) is tightly coupled to 9.1 and is covered
here as well, since the task's extract list (waypoint crystallization,
gaussian approach curve) is 9.2 material.

## source locations

### roadmap (the spec itself)

- `data/md/development/IMPLEMENTATION-ROADMAP.md:595-645` — entire section
  9 "user experience — holographic panel" (header `:595`, sub-topic block
  `:605-645`); section framing `:595-604`: "the panel IS the field's
  self-model made interactive. zenka and user see the same panel — same
  grammar"; depends on 4, 7, 8; enables 11.
- `data/md/development/IMPLEMENTATION-ROADMAP.md:608-613` — **9.1 personal
  HUD grid**: "intermediate reference grid / cross-references all open
  layers / travels with observer through field / angular, scale, offset
  relationships maintained / [ task: pending ]".
- `data/md/development/IMPLEMENTATION-ROADMAP.md:615-619` — **9.2 waypoints
  by reference count**: "virtual desktops in 3D space / layout remembered,
  approach vector cached / gaussian acceleration profile between frequent
  targets / [ task: pending ]".
- `data/md/development/IMPLEMENTATION-ROADMAP.md:519-523` — **7.5
  "45-degree parent grid alignment" reuses the same phrase "intermediate
  reference grid"**: "fills child grid gaps (FCC packing) / local switching
  hub: up/lateral/reflect" — the only other roadmap occurrence of the term;
  references at `:532-533`.
- `data/md/development/IMPLEMENTATION-ROADMAP.md:512-517` — 7.4 temporary
  home instantiation ("any coordinate can become home / crystallizes,
  fulfills, dissolves / higher bandwidth link to semantic parent /
  on-demand zenka as implementation") — closest existing definition of
  "waypoint crystallization".

### observer-centric reference space (the observer model)

- `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md:1-18` — core model:
  "client IS 0 — not 'at 0'. grid recenters around it via buffer swapping.
  navigation = position reassignment, not movement"; address space
  -n/2…+n/2; "position = reference count rank on each axis independently".
- `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md:46-65` — buffer
  swapping as transparent navigation.
- `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md:187-256` — **view
  specification**: `view: {observer, focus.position, focus.normal,
  focus_secondary, focal_length}`; focal_length semantics: `0/'omni'` =
  all 8 cube faces as grid, `13` = natural harmonic (generator 076923),
  `→ ∞` = orthographic.
- `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md:262-327` —
  omnidirectional grid mode (observer as mothership, 8-face monitoring
  grid), drone = mobile remote focus vertex relaying remote perspective
  back; "the observer at 0 is the pivot — not a viewpoint but the point
  all views originate from and return to".
- `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md:329-395` — face view
  multiplexing/addressing (face octal = addressable view channel).
- `data/ai-mem/claude/topic-observer-centric-space.md:15-28` — condensed
  model incl. "new arrivals start at ±n/2 (boundary), fall inward as used;
  n auto-expands outward".
- `data/ai-mem/claude/topic-observer-centric-space.md:59-95` — condensed
  view spec YAML + temporal bandwidth (spatial: ref count → distance;
  temporal: ref count → slots per 13-slot clock).
- `data/ai-mem/claude/topic-observer-centric-space.md:97-103` — connections
  to existing systems: `branch.group.propagate` (interest count drives
  position reassignment), `branch.route.cache`, reference bubble, "observer
  always origin of own coordinates".

### perspective layers (the "open layers" 9.1 cross-references)

- `data/md/design/SPAWNABLE-PERSPECTIVE-LAYERS.md:14-19` — "desktop =
  Σ(active perspective layers) composited by parallax; layout = reference
  space positions + view spec parameters; depth = consensus count across
  layers".
- `data/md/design/SPAWNABLE-PERSPECTIVE-LAYERS.md:21-56` — **layer stack
  definition**: each layer = spawned on-demand zenka + view spec resource
  on branch node; structurally identical, differentiated only by geometric
  offset / orientation / focal_length / scope; layer 0 personal darksun
  (offset=0), layer 1 local neighborhood, layer 2 network reference center
  (recursive), layer 3 task context, layer N recursive; "parallax between
  layers = UI depth cue. consensus across layers = darksun".
- `data/md/design/SPAWNABLE-PERSPECTIVE-LAYERS.md:58-95` —
  summarization/bandwidth: high-ref → large/bright/close; "focal length =
  tunable bandwidth"; visible frame = inner shells only.
- `data/md/design/SPAWNABLE-PERSPECTIVE-LAYERS.md:97-133` — nested
  resolution = derivation route; all UI changes = view spec parameter
  changes only ("zoom in = increasing focal length … context switch =
  changing which layer is the primary observer").
- `data/md/design/SPAWNABLE-PERSPECTIVE-LAYERS.md:155-168` — implementation
  anchors list (branch.node.*, branch.resource.*, branch.group.propagate,
  branch.dep.graph, 13-slot clock, iris ring structure, living background
  system).
- `data/ai-mem/claude/topic-perspective-layers.md:20-52` — condensed layer
  model.

### waypoint / curve mechanics

- `data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4083-4206` —
  **Three-Angle Waypoint Vector**: `waypoint = {θ₁ azimuthal, θ₂ polar, θ₃
  roll/spin}`; equivalence `group waypoint (θ₁,θ₂,θ₃) ≡ orrery ring state
  (angle_ring, style_ring, quality_ring)`; coordinate transforms θ₁=c_type×
  360°/13, θ₂=c_angle×360°/13, θ₃=σ_quality×360°/6; θ₃ stability thresholds
  (<30° stable, 30-120° dynamic, >120° split); waypoint_history +
  PREDICT_CLUSTER extrapolation algorithm (`:4171-4199`).
- `data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4719-4740` —
  "0° reference grid" as base frequency in the 5-of-7 corner-circle
  geometry.
- `data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4939-4952` —
  "entropy groups … migrate via three-angle waypoint vectors along the
  harmonic gradient … The three-angle waypoint vector is sufficient to
  describe any group's state and trajectory".
- `data/ai-mem/claude/topic-orbital-data-space.md:42-53` — **curve engine**:
  "Camera flight, zenka travel, animated parameters all use same curve
  structure"; "curve has sub-curves at waypoints; galactic→individual scale
  = one continuous recursing curve"; layer mask = universal rendering
  interface.
- `data/ai-mem/claude/topic-orbital-data-space.md:64-72` — "Personal
  squelch = contextualized view threshold"; "Observer context as
  consensus: multiple observers zooming same region increases template
  weights".
- `data/ai-mem/claude/archive/topic-orbital-data-space-archive.md:134-149`
  — curve archive detail: control points = waypoints/orbital positions;
  "zenka travel path → same curve: source orbit → waypoints → target
  orbit"; zooming into a waypoint reveals it's itself a curve.
- `data/ai-mem/claude/topic-implicit-perspective-navigation.md:28-60` —
  explicit vs implicit navigation: (1) explicit = set target state (named
  waypoint) and curve-interpolate; (2) implicit = adjust interest signals,
  "perspective/camera position then calculates itself" (auto-fit);
  (3) magnetic nudging between close-scoring clusters.
- `data/ai-mem/claude/topic-implicit-perspective-navigation.md:88-102` —
  "session-bound overlay, kept orthogonal" (personal layer additive on
  shared space); status: "Pure design/vision, nothing implemented".
- `data/ai-mem/claude/vision-orbital-hop-sequence-hyperspace-flight-animation.md:16-41`
  — cubic grid self-tiling: "EVERY frame is compatible with EVERY other
  frame"; mismatched scale reads as intentional translucent overlay.
- same file `:59-74` — hyperspace transit (discrete per-hop frames) vs
  orbital/local arrival (fluid continuous render) ↔ explicit/implicit split.

### HUD precedent (design)

- `data/md/design/CLAUDE-DESIGN-BRIEFS.md:1-43` — Brief 1 "Space Engine
  Grid UI": full HUD readout spec — 100px margins for HUD (`:7`), margin
  HUD content "focal length, max shell, observer coordinates, dot/comma
  route legend" (`:30`), font "11px for HUD" (`:42`), observer fixed at
  (0,0,0), `max_shell = ceil(63 / focal_length)` (`:11`), 13-step iris ring
  halo.

### gaussian / acceleration primitives

- `data/md/design/MEMORY-TREE-SYSTEM.md:96,124,205-221,551` —
  `gaussian_pulse` curve type (peak at input ~0.5), implemented via
  `<[base.curve.eval]>`, used for CRITICAL rank falloff.
- `src/base.calc_gauss:1-10` — gaussian PDF implemented:
  `exp(-0.5*((x-m)/s)²)/sqrt(τs²)`.
- `src/base.curve.eval:19-23` — `gaussian_pulse`: `x=(t-0.5)*4; bell=
  base.calc_gauss(x); val=bell*sqrt(τ)` (normalized to 1.0 at peak); other
  types sine/exponential/quantized/heartbeat/linear/ease-*/hold/sigmoid.
- `data/ai-mem/kimi/MEMORY-active.md:187` — additive glow via
  gaussian-copy paste-add (audio lattice rendering precedent).

### secondary .asc capture (search-only, as instructed)

- `data/asc/what-AI-thinks/full-chat-captures/3O37VUNMMS3UU.claude-sonnet.protocol-7-knowledge.asc:29706-29715`
  — HUD display spec fragment (top-right; zoom distance, view angle, lens,
  cursor coords; real-time, fades after 2s); smooth transitions
  `:29717-29732` (ease-in-out distance, slerp rotation, projection morph).
- same file `:26413-26416` — "ZENKI navigation instructions … Meaning:
  Spatial waypoints".
- same file `:39934-40533` — waypoint-mathematics discussion (trail drawn
  from position-history waypoints, one step ahead; dense vs sparse
  sampling; `curve->add_waypoint`) — zenki-trail rendering, tangential to
  9.2 but confirms waypoint+curve idiom.
- same file: ~100 "observer" hits, overwhelmingly philosophical
  (witness/neutral-observer metaphysics, `:14914-29524`) — **no definition
  of a HUD-grid observer layer**.

### negative results (explicitly searched, nothing relevant)

- `data/md/design/ESSENCE-CRYSTAL-INEVITABLE-OUTCOME.md` — no matches for
  HUD/waypoint/observer/gaussian/peripheral/reference grid.
- `data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md` — no matches.
- `data/ai-mem/claude/topic-field-coherence-synthesis.md` (whole file,
  28 lines) and `data/md/development/FIELD-COHERENCE-SYNTHESIS.md:95` —
  one tangential "aligned observer" line only.
- `data/ai-mem/claude/topic-creative-field-behaviour.md` — grep on all
  search terms: **no matches**.
- `data/md/design/FOUR-VISUAL-DOMAINS.md`, `data/md/design/GRID-HARDNODE-CURSOR-MODEL.md`
  — no HUD/waypoint/observer/peripheral matches.
- `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md` — no
  hud/waypoint/gaussian/peripheral matches (observer model only).

## extracted structure

### 1. intermediate reference grid definition

the term appears exactly twice. roadmap 9.1 (`:608-612`): the personal HUD
grid IS an "intermediate reference grid" that "cross-references all open
layers", "travels with observer through field", maintaining "angular,
scale, offset relationships". roadmap 7.5 (`:519-522`) uses the identical
term for the 45°-rotated parent grid that "fills child grid gaps (FCC
packing)" and acts as "local switching hub: up/lateral/reflect" — an
interstitial grid one scale level up that bridges child grids.

the compositional meaning comes from `SPAWNABLE-PERSPECTIVE-LAYERS.md:14-19`:
the personal desktop is the sum of active perspective layers composited by
parallax, where each layer is a complete observer-centric reference space
(`:21-43`) differing only in geometric offset, orientation, focal length,
scope. the HUD grid is therefore best understood as the per-observer
intermediate frame that holds the angular/scale/offset relationships
between these layers constant while the observer (darksun at 0) moves —
the pivot all views "originate from and return to"
(`OBSERVER-CENTRIC-REFERENCE-SPACE.md:324-327`).

### 2. layer cross-reference mechanics

`SPAWNABLE-PERSPECTIVE-LAYERS.md:97-114`: "layer N resolves within context
of layer N-1 → … → layer 0 → branch.node.path … the layer stack IS the
derivation path. implicit, auto-computed, no explicit spec." cross-layer
identity anchors: "parallax between layers = UI depth cue. consensus
across layers = darksun" (`:31`); "depth = consensus count across layers =
harmonic truth" (`:17`). change operations are pure view-spec parameter
changes (`:116-133`). shared space stays common; a session contributes an
additive orthogonal overlay (`topic-implicit-perspective-navigation.md:88-94`).
multi-observer consensus weights: "multiple observers zooming same region
increases template weights" (`topic-orbital-data-space.md:71`).

### 3. waypoint crystallization logic

no document defines this phrase directly; the composite is:

(a) roadmap 9.2 (`:615-619`) — waypoints ranked by reference count,
behaving as "virtual desktops in 3D space", "layout remembered, approach
vector cached";

(b) roadmap 7.4 (`:512-517`) — "any coordinate can become home;
crystallizes, fulfills, dissolves; higher bandwidth link to semantic
parent; on-demand zenka as implementation" — the crystallize/dissolve
lifecycle of a temporary home coordinate;

(c) `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4083-4116` — a waypoint is
fully described by the three-angle vector (θ₁,θ₂,θ₃), equivalent to an
orrery ring state, with θ₃ (quality variance) predicting stability/split
(`:4143-4150`);

(d) waypoint history + trajectory extrapolation for prediction
(`:4163-4199`);

(e) `HARMONIC-ENTROPY-OBSERVER-GUIDE.md:32` — "positions that stop
blinking: crystallizing toward T=5" (crystallization = settling into
stable 846153/T=5 phase).

### 4. gaussian approach curve details

roadmap 9.2 (`:618`) specifies only "gaussian acceleration profile between
frequent targets" — no further parameters anywhere. available primitive:
`base.curve.eval` type `gaussian_pulse` (`src/base.curve.eval:19-23`,
x=(t−0.5)×4, normalized peak at t=0.5) built on `base.calc_gauss` (μ=0,
σ=1). `MEMORY-TREE-SYSTEM.md:205-221` documents gaussian_pulse as "humped
… peak at input ~0.5, near-0 at both ends". design intent for motion
feel: `topic-implicit-perspective-navigation.md:15-26` — "curves/thresholds
ARE the decision"; curve-constant shape decides perceived overshoot;
explicit mode = "curve-smoothed exact arrival" at pinned waypoints.

NOTE: gaussian_pulse as implemented is a hump (velocity-ish), not an
S-curve (position-ish); an acceleration profile would likely compose
gaussian_pulse with the existing sigmoid/ease curves via
`base.curve.compose` (`topic-base-curve-system.md:38-52`).

### 5. related navigation/frame-compat guarantees

`vision-orbital-hop-sequence-hyperspace-flight-animation.md:16-41` — cubic
grid self-tiling guarantees any frame compatible with any other; scale
mismatch resolves as translucent overlay. two-mode travel: discrete
hyperspace hops vs fluid orbital arrival (`:59-65`).

## gaps

- **no document defines the personal HUD grid as a concrete component.**
  only the 4-line roadmap stub (9.1) + the margin-HUD visual precedent in
  `CLAUDE-DESIGN-BRIEFS.md:7,30,42`. no data structures, no command
  surface, no rendering target.
- **"travels with observer through field" is unmechanized** — nothing
  specifies how the grid frame updates during navigation (re-derivation
  cadence, transition curves, what happens to pinned relationships
  mid-flight).
- **"cross-references all open layers" has no defined cross-reference
  format** — no schema for how a HUD grid entry points into multiple
  perspective layers simultaneously (only the layer-resolution chain
  `SPAWNABLE-PERSPECTIVE-LAYERS.md:97-114` and parallax compositing exist).
- **angular/scale/offset relationship invariants are stated but not
  formalized** — no math pinning how offset/rotation/scale of the
  intermediate grid relate child↔parent layers (7.5's FCC-packing parent
  grid is named but not derived).
- **gaussian acceleration profile**: no σ, no duration, no per-waypoint
  caching format ("approach vector cached" is named in 9.2 with no
  container definition). existing `gaussian_pulse` is a [0,1] hump, not an
  acceleration curve — mapping is undefined.
- **waypoint crystallization logic is undefined as such** — must be
  synthesized from 7.4 lifecycle + 9.2 reference-count ranking +
  three-angle waypoint vector; no unified definition exists.
- **HUD grid vs margin HUD**: `CLAUDE-DESIGN-BRIEFS.md` defines readout
  elements only; nothing connects them to the 9.1 "grid" concept.
- primary docs #5 (`ESSENCE-CRYSTAL-INEVITABLE-OUTCOME.md`), #6
  (`NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md`), #4
  (`topic-creative-field-behaviour.md`), and #3
  (`topic-field-coherence-synthesis.md`) contain **zero** relevant
  definitions for 9.1.

## implementation hints

**implemented and directly reusable:**

- `src/branch.space.visible:1-111` — the view-spec engine:
  `{focal_length, observer_node, scope}` → visible nodes sorted by shell,
  darksun first; `max_shell = int(63/focal_length)`; omni mode; interleaved
  ±rank position assignment; persists `branch.space.positions`.
- `src/branch.space.magnetic_force:1-72` — **force vector implementation**:
  `force = (other_position − this_position)/distance²` summed over group
  companions; returns `magnetic_vector {z,y,x}`, magnitude, dominant_group.
- `src/branch.space.effective_position:1-78` — grid rank + magnetic delta →
  effective position, clipped to ±n/2 ("effective = grid + magnetic").
- `src/branch.space.balance:1-101`, `src/branch.space.rank`,
  `src/branch.space.shell`, `src/branch.space.util.*` (position_for,
  ref_count, collect_subtree, build_visible_result) — full
  `branch.space.*` family already live.
- `src/base.calc_gauss` + `src/base.curve.{eval,register,cancel,compose,
  tick,init,eval.position}` — complete curve/gaussian primitive layer
  (consumed by `window.place.damp.tick`, `mpv.handler.audio_fade`,
  `memory.tree.score.rank_falloff`, `route.bmw384.route.as-curve`,
  `route.bmw384.visual.flying-elements`).
- `src/web-browser.cmd.waypoint-set`, `src/web-browser.cmd.goto-waypoint`,
  `src/web-browser.cmd.goto-waypoint-group` — **the only landed waypoint
  system**: named `{vars, chk, url}`-pinned waypoints, curve-smoothed exact
  arrival, page-pin verification, subname-group fan-out (see
  `data/ai-mem/kimi/topic-web-browser-state-play-waypoints.md`,
  `data/ai-mem/claude/project-web-browser-value-replay-waypoints.md:40-42`
  "waypoint registry generalizing to name → {per-window …}"); loaded per
  `cfg/zenki/web-browser/subroutines.load-early:464,493,616`.
- `src/window.place.handler.draw:13`, `src/window.place.handler.poll_pointer:39`,
  `src/select.region.handler.draw:13` — existing on-screen HUD readout
  pattern (cairo, follows live surface).
- `src/graphics-matrix.cursor.{init,position,move,set,checksum}`,
  `src/graphics-3d.calc.cursor-translucency` — navigable 3D cursor/viewpoint.
- `route.bmw384.visual.wheel.gauss` — gaussian-glow ring rendering
  precedent; `audio.render_standing_wave.v1-v4` — gaussian-copy additive
  compositing precedent.
- layer/zenka infrastructure named by `SPAWNABLE-PERSPECTIVE-LAYERS.md:155-168`:
  `branch.node.*`, `branch.resource.*` (view spec as resource),
  `branch.group.propagate`, `branch.dep.graph`, `base.reverse-sort`.

**no HUD-grid/observer-grid specific code exists** — grep over `src/`,
`cfg/`, `bin/` for `hud|waypoint` finds only: (a) the web-browser waypoint
trio above, (b) window-place/select-region HUD readouts, (c)
`ticker.open_window:217` (notify-mode HUD), (d) checksum false-positives
(base32 "HUD" substrings; `bin/dev/dep-graph`, `bin/dev/len` matches are
signature artifacts, not code). no `hud`-namespaced module, no
personal-grid component, no gaussian acceleration driver anywhere in the
tree. status across all sources: roadmap 9.1 is `[ task: pending ]`;
`topic-implicit-perspective-navigation.md:98` records "Pure design/vision,
nothing implemented."

## suggested task file sections

for a future `data/yaml/coding-tasks/personal-hud-grid.yaml` (a scoped,
code-backed first increment is feasible unlike topics 7.3/10):

- **objective (suggested first increment)**: a session-bound personal grid
  overlay built on the live `branch.space.*` + `base.curve.*` primitives —
  per-observer intermediate frame holding angular/scale/offset
  relationships of open layers, with a named-waypoint registry
  generalizing the web-browser waypoint trio.
- **context (must-name modules)**: `src/branch.space.visible` (view-spec
  engine), `src/branch.space.magnetic_force` / `effective_position` (force
  vectors), `src/base.curve.*` (gaussian/ease/compose), web-browser
  waypoint trio (registry pattern), `OBSERVER-CENTRIC-REFERENCE-SPACE.md`
  (observer-at-0 model + view spec), `SPAWNABLE-PERSPECTIVE-LAYERS.md`
  (layer stack), `CLAUDE-DESIGN-BRIEFS.md` Brief 1 (HUD readout
  precedent), roadmap 9.1/9.2 bodies.
- **design decisions to record in the task file**:
  - cross-reference record format (how a HUD grid entry points at N
    layers) — no existing schema; propose minimal `{layer_ref, offset,
    angle, scale}` per entry.
  - grid frame update during navigation (hook `branch.group.propagate`
    reassignment events?).
  - gaussian acceleration composition (gaussian_pulse × sigmoid via
    `base.curve.compose`) + per-waypoint approach-vector cache format.
  - rendering target: cairo margin-HUD pattern (`window.place.handler.draw`)
    as phase 1; space.v7.ax WebGL layer mask as phase 2.
- **acceptance**: module passes `ptd -c`; waypoint registry round-trip
  (set/goto/crystallize by ref-count threshold); grid relationships
  survive simulated observer jumps (buffer-swap navigation); gaussian
  approach curve lands exactly on pinned waypoint.
- **explicitly out of scope**: 9.3 sampler panel, 9.4 live synthesis
  parameters, 9.6 variable-c layers; multi-observer consensus weights;
  hyperspace hop animation.

#,,,.,..,,,..,..,,...,.,,,..,,,,,,,,,,.,.,.,.,..,,...,...,..,,,.,,.,.,,..,.,,,
#7ZFSPA7JE44YTB7W7FPFB7OQ4PKQSLCZGNQHGWLRZHR5IC6J547VKATYUA5J2GS3JODSF6JFN5GBW
#\\\|QN3HA3RGX33IXFLBLFGLDPQY674UBXSAK4K6TNC6F7RSU7MU5UK \ / AMOS7 \ YOURUM ::
#\[7]UNR5DLACWIQIO6YDZDSCDEKDNNNIHVQBEQHAKIL7BK5U562UCSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
