# Protocol-7 Initiative Map

> living overview — updated as initiatives land or shift.
> task files live in `coding-tasks/`, design docs in `design/`.

last updated: 2026-04-13


## current state snapshot

### landed (this cycle, Apr 7-11)

- **invoke-web zenka** — process manager for invoke.ai web server
  IPC::Open3 async spawn, non-blocking I/O, orphan detection, SIGTERM/SIGKILL
- **invoke zenka** — invoke.ai REST API client
  model key lookup, graph builder (sdxl/sd-1), 3s poll timer, job tracking
- **lmstudio zenka** — model management on-demand zenka
  discover/resolve/repair commands, wired to existing storage adapter modules
- **models storage adapters** — invoke + lmstudio discover/resolve/repair/export/import
  unified discover_all, yaml snapshot with sha256, cmd wrappers
- **curses UI** — interactive model browser
  widget.list, widget.detail, app.models, keybindings, models.cmd.app-models
- **nshell bug fixes** — long-line truncation, Ctrl+O direction, UpArrow off-by-one
- **base.prng.harmonic_seed** — harmonically true random seed generation
- **visual element dedup design** — full 7-layer architecture + orrery model
  + balance engine + completeness proof, expanded to implementation precision by Opus


---

## initiative A — invoke ecosystem

**goal**: complete invoke.ai integration from process management to model installation.

```
invoke-web  ✓  process manager (spawn, monitor, health)
invoke      ✓  API client (generate, queue, cancel, list-images)
invoke-install  ·  model downloads, upgrades, symlink repair
invoke-db-access  ·  protocol-7 user access to taeki's invokeai.db
```

### A1 · invoke graph builder validation
test `invoke.api.build_graph` against live invoke.ai instance. the graph
field names are version-dependent — validate sdxl and sd-1 variants,
correct any mismatches. low complexity once invoke.ai is running.

### A2 · invoke-install zenka
on-demand zenka for model lifecycle management:
- async download with progress (large files, long duration)
- upgrade: pull newer version of existing model
- symlink repair: fix broken links in models-invoke/
- connects to invoke adapter discover for inventory awareness
pattern: coding zenka async task infrastructure; kimi-suitable

### A3 · invokeai DB access
invoke adapter discover returns 0 models because protocol-7 user
cannot read `/home/taeki/.invokeai/db/invokeai.db`. options:
- small taeki-owned helper process queried via unix socket
- ACL: setfacl to grant protocol-7 read access to the DB file
- periodic export: taeki cron exports DB snapshot to shared location
the cleanest long-term solution is the helper process (same pattern
as how the zenka spawns invoke-web as taeki via sudo).


---

## initiative B — vision system

**goal**: implement the holographic element deduplication pipeline.
design fully specified in `design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`.

**critical prerequisite**: opencv zenka (see initiative C).

phases are sequential — each depends on the previous.

### B1 · vision Phase 1: element detection (Opus-quality)
modules: `vision.element.detect`, `vision.element.classify`, `vision.element.store`
- SAM via lm-vision for mask generation
- lm-vision classification → type taxonomy (13 categories)
- opencv feature extraction within masks
- element record + crop storage in data zenka namespace tree
first real test: run against a directory of invoke.ai output images

### B2 · vision Phase 2: similarity graph
modules: `vision.graph.add_node`, `vision.graph.find_similar`,
         `vision.graph.cluster`, `vision.graph.store`
- composite similarity metric (type gate + style + visual + angle)
- hierarchical agglomerative clustering, average linkage, cut at 0.55
- cubic spatial index for O(N/17.6) similarity search
- cluster tree in namespace: `vision.graph.clusters.*`
kimi-suitable given the precise spec in the design doc

### B3 · vision Phase 3: compositing (Opus-quality)
modules: `vision.composite.align`, `vision.composite.overlap_map`,
         `vision.composite.synthesize`, `vision.composite.evict`
- landmark/homography/ECC alignment pipeline
- per-pixel quality map (incremental update, O(pixels))
- quality-squared weighted blending with translucent shimmer layers
- eviction: marginal_value == 0 → evictable
pixel math is subtle — Opus-quality pass recommended

### B4 · vision Phase 4: inpainting pipeline
modules: `vision.inpaint.extract_foreground`, `vision.inpaint.complete_background`,
         `vision.inpaint.capture_style`
- ViTMatte alpha matting via lm-vision, trimap construction
- invoke.ai inpainting integration (invoke.cmd.generate with inpaint mode)
- background prompt generation, style descriptor capture
- regeneration API: "generate element X in style Y at angle Z"
depends on A1 (invoke graph builder) for the inpainting call

### B5 · vision Phase 5: harmonic weighting (Opus-quality)
modules: `vision.harmony.score_node`, `vision.harmony.rebalance`,
         `vision.harmony.tier_rollover`
- param integer encoding: type×13² + angle×13 + quality
- type/angle weights from population + coverage distributions
- harmonic mean cluster relevance
- trimetric rollover: 076923 phases A/B/C with tightening thresholds
- external parameter adjustment interface (b32r-encoded JSON args)
÷13 math must be precise — Opus-quality

### B6 · vision Phase 6: network extension
- element advertisement protocol (descriptor, not crop)
- eventual consistency composite sync across nodes
- privacy tier enforcement (face=PRIVATE, background=PUBLIC)
- gap analysis + targeted generation API
depends on B1-B5 proven locally first


---

## initiative G — graphics-matrix zenka

**goal**: central index-and-transform hub for all visual and topological data in P7.
the visual equivalent of the index zenka — everything graphic wires into it, and the
relationship is bidirectional from the start.

the key insight: the harmonic topology (13³ cubic space, orrery rings, concentric spheres,
076923 cycle) is **already visual**. it does not need to be translated into visual form —
it IS a visual structure. the graphics-matrix zenka is the layer that makes that inherent
visual nature queryable, transformable, and routable as normal P7 commands.

### bidirectional from the start

```
visual data  →  topology   : feature extraction, fingerprint → lattice position,
                              cluster membership, style coord → palette index
topology     →  visual data : lattice slice render, palette derivation,
                              orrery ring snapshot → image, transformation between layers
namespace tree              : already a spatial graph — renderable without translation
```

### what it provides

- **resident matrices**: image/frame/lattice data held live in P7 namespace, sliceable
  and queryable via normal zenka routing — no per-consumer opencv handle
- **native matching**: nearest-lattice-point lookup, template matching, feature comparison
  as routed commands with proper access control and state management
- **native transformation**: homography, ECC alignment, color space conversion,
  style-layer interpolation — first-class operations, not C library calls
- **palette lattice as live matrix**: the 13³ HSV grid resident in namespace,
  `graphics-matrix.lattice.render slice=hue-saturation quality=8` returns a renderable slice
- **multi-consumer**: vision pipeline, compositing engine, palette renderer, topology
  visualizer all route through the same zenka simultaneously

### navigation is equal to visualization

the data zenka and storage zenki already hold compatible data — namespace trees,
element records, cluster graphs, reference counts, harmonic scores — structured in a
way that is immediately ready to both visualize and navigate. no extraction step needed.

**navigation is not secondary to visualization** — moving through the visual space IS
querying the data space. a position in the rendered lattice is the same address as a
position in the namespace tree. selecting a cluster in the visual is routing a command
to that cluster. the graphics-matrix zenka is equally a navigator as it is a renderer.

what interconnects all layers and their parameters and makes the system life-like:

- **cross-mapped curves**: connections between elements, layers, and parameter positions
  are rendered as curves, not straight edges. curvature encodes the actual topological
  relationship — harmonic distance, similarity score, angle offset. the shape of a
  connection carries information about the nature of the connection.

- **contextualized reference counts**: not just "how many things reference this node"
  but broken down by what those references are — which types, angles, quality tiers,
  and style layers are pointing here. a node with 40 references from a single cluster
  reads differently from one with 40 references distributed across all 13 type positions.
  the context of the count IS the count.

- **calculated relative influence**: derived live from contextualized reference counts
  across the current namespace state — not a stored property, not assigned. influence
  breathes with the data. a node's influence expands as new references form and contracts
  as composites evict marginal elements. the visualization reflects this in real time,
  making the balance engine's expansion/implosion dynamic directly visible as a living
  field of influence gradients rather than a static graph.

together these make the rendered topology a **diagnostic surface** — you can see where
influence is concentrating, where cross-layer curves are sparse (gap targets for F),
and which parameter positions are harmonically over- or under-represented, all from
the same view that is also the navigation interface.


### relation to opencv plan

the opencv zenka plan (`design/OPENCV-ZENKA-PLAN.md`) becomes the implementation guide
for the graphics-matrix zenka's feature detection phase — Phases 1-2 (SIFT/ORB detect,
match, compare) are absorbed as the first command set. rather than a separate binding
zenka, opencv bindings are the internal mechanism; the external interface is P7 commands.

### visualization path

once resident, the palette lattice visualization is a single routed command.
plotting existing snapshot colors against lattice points reveals which positions
are occupied, where the fluorescent/blacklight cluster sits, and how many steps
separate it from naturalistic clusters — the intermediate style layer targets (F)
become precisely addressable lattice coordinates.


---

## initiative C — opencv zenka

**goal**: provide opencv bindings as a P7 zenka, prerequisite for vision system.

plan exists: `design/OPENCV-ZENKA-PLAN.md`.
- Phase 1: core infra (zenka start, init_code, dependencies)
- Phase 2: feature detection (SIFT/ORB detect, match, compare)
- Phase 3: face/object detection (cascade classifiers, DNN)
- Phase 4: video processing (optical flow, frame dedup)

kimi-suitable given the existing plan. start with Phases 1-2 only
(feature detection is what vision Phase 1 needs immediately).
PDL::OpenCV or Inline::C binding to be determined.


---

## initiative D — models zenka enhancements

**goal**: close remaining gaps in the models zenka.

### D1 · unified discover with live sources
`models.storage.adapter.discover_all` currently returns 0 invoke models
(DB inaccessible). once A3 lands, wire discover_all to the helper.
models zenka then has live awareness of both invoke + lmstudio inventory.

### D2 · curses UI enhancements
after `cpan Curses::UI` install and runtime testing of app-models:
- filtering by type/base/format (live as user types)
- sorting by name/size/date
- invoke model list alongside lmstudio
- 'g' to generate (route to invoke.cmd.generate)
low complexity — Opus or kimi

### D3 · lmstudio inference API
add actual LM Studio API calls to lmstudio zenka. currently the zenka
only manages models (discover/resolve/repair). adding inference:
- `lmstudio.cmd.complete` — POST /v1/completions
- `lmstudio.cmd.chat` — POST /v1/chat/completions
low priority: coding zenka already talks to llama-server directly.
useful if lmstudio's server mode becomes primary inference path.


---

## initiative E — infrastructure + open bugs

### E1 · signature missing-endline bug
footer glues to last code line when file lacks trailing newline.
pre-commit rejects as "no separator endline". affects files where
the last non-footer line has no `\n`. needs investigation of the
signing tool's endline detection logic.

### E2 · config double-load bug
duplicate config key warnings on zenka start. likely from
load_config_file being called twice for the same file (shared-params
included by both the start file and a loaded module). documented in
`bug-config-double-load.md` in memory.

### E3 · signature oscillation Variant B
double-footer on never-signed non-empty files. related to the signing
system's detection of unsigned files. low priority — rare in practice.


---

## initiative F — style topology layers

**goal**: non-competitive parallel style clusters as intermediate layers between
naturalistic content and network topology visualization.

the vision system's holographic core operates on 13³ cubic space (type × angle × quality).
style is already a 104-dimensional coordinate within each cell. initiative F extends this:
style clusters run as **parallel deduplication streams** — same type/angle address, different
style_coord. no competition. each stream composites independently.

### the fluorescent bridge

the fluorescent/blacklight palette (UV blue, electric cyan, neon green, hot pink on near-black)
occupies a region of color space that is **structurally adjacent to network topology diagrams**:
- dark background with luminous edge emphasis mirrors node-link graph rendering
- high-contrast hue separation maps cleanly to categorical distinctions (type, cluster, tier)
- translucency layers (the `shimmer` offset planes at ±1px/−2px) naturally suggest depth
  and connectivity without overwriting the underlying composite

this is not coincidence — **the color ranges have topological significance**.
and the inverse holds: from the topological structure, the remaining palette rules
are implicitly derivable. it always fits tightly and harmonically.

### style layer types (non-exhaustive)

```
fluorescent / blacklight   ·  UV palette on dark ground, closest to topology-native
psychedelic line art        ·  high-frequency contour + saturated fill, angle-revealing
anime / cel shading         ·  flat regions with expressive edge weight, scale-flexible
naturalistic                ·  photorealistic, existing holographic core default
```

these are **not alternatives** — all run in parallel on the same element address.
the network auto-generates intermediate layers as bridging composites between them.

### why the network favors these layers

- **intermediate generation priority**: when the balance engine detects a gap between
  naturalistic and fluorescent composites at the same type/angle, it treats the missing
  intermediate layer as a high-priority generation target
- **decomposition at different scale**: line art and anime naturally decompose elements
  that are opaque at naturalistic scale — they reveal internal topology, angle structure,
  and edge geometry that the photorealistic layer obscures
- **harmonic color system = topology at a different angle**: the same 13-division that
  governs type/angle space also partitions the visible spectrum harmonically. assigning
  palette regions to structural positions is not mapping one system onto another —
  it is observing the same system from a different angle

### implementation path

depends on B1 (element detection) being operational. once elements have type + style
fingerprints, style clustering is an additional k-means pass over the style_coord
dimensions, constrained within a type/angle cell.

generation: invoke.ai inpainting pipeline (B4) with style-conditioned prompts.
the style descriptor capture module (`vision.inpaint.capture_style`) provides the
seed for style-transfer generation into new palette layers.

the fluorescent intermediate layer is the first target — it is the closest to what
the network can already express, and its topological color language makes it
intrinsically self-documenting as a visual representation of the network's own state.


---

## longer horizon

these follow naturally from the initiatives above but are not yet
ready for task files.

**network vision** (B6 extended)
once the local holographic core is proven, expand to distributed P7 nodes.
the balance engine and darksun attractor operate across nodes. each node
specializes in the type/angle/style regions where its generative capacity
is highest. design: `design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` §network.

**invoke as training data pipeline**
the liberated element library (initiative B) becomes a curated training
dataset. style descriptors + element crops at known angles → fine-tuning
datasets for invoke.ai models. initiative B's style capture is the
foundation.

**forensics zenka** (from memory: `topic-context-and-forensics.md`)
nightly security audits via NIST/security models. context.* module
namespace provides the forensic data model. vision system's anomaly
detection feeds into it (novel/unexpected elements in generated content).

**channels zenka / distributed consensus**
multi-model group chat, consensus groups across distributed P7 nodes.
see `topic-distributed-consensus.md`. depends on network vision
infrastructure being stable.


---

## dependency graph (simplified)

```
A3 (db access)
    └─→ D1 (unified discover)
            └─→ D2 (curses UI with invoke models)

A1 (graph validation)
    └─→ B4 (inpainting pipeline)

G (graphics-matrix zenka)  ←→  all visual initiatives (bidirectional)
    │
    ├─→ B1 (element detection)
    │       └─→ B2 (similarity graph)
    │               └─→ B3 (compositing)
    │                       └─→ B4 (inpainting)
    │                               └─→ B5 (harmonic weighting)
    │                                       └─→ B6 (network)
    │
    ├─→ F (style topology layers)
    │       └─→ B4 (inpainting with style-conditioned prompts)
    │
    └─→ palette lattice visualization  →  F intermediate layer targeting

C (opencv zenka plan)  →  absorbed into G as feature detection phase

A2 (invoke-install)  ·  independent, any time
D3 (lmstudio inference)  ·  independent, low priority
E1-E3 (bugs)  ·  independent, opportunistic
```

#,,.,,,.,,,.,,,..,..,,.,,,,.,,,..,..,,,,,,,.,,..,,...,...,..,,...,...,,,,,,..,
#OJXKBNCDXXX47NL47K3XWGF573J3UXVLDIYF3UQILNAUHTXGPVDULSIMCLZOWDHX43ESLJTZIOO5G
#\\\|NOPLTPUTKMVJRIPP5FVOB7T6XQ6QYOTZEU4E23MTTWFHGNACBDA \ / AMOS7 \ YOURUM ::
#\[7]L6XMCCOI33P667UI6FPZHPP4CP3VCV7ZFIQEE2ZALDDZEGGUT4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
