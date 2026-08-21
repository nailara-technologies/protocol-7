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

**status**: existing zenka — extends, not creates.

**existing infrastructure** (tested, load-bearing):
```
cfg/zenki/graphics-matrix/zenka.v7     — full start file, wired to cube
src/graphics-matrix.init_code             — cache dir, permissions, Graphics::Magick
src/graphics-matrix.cmd.assert-similarity — similarity assertion command
src/graphics-matrix.cmd.filter-c2a        — color-to-alpha filter
src/graphics-matrix.cmd.filter-rep-col    — replace color filter
src/graphics-matrix.filter.*              — alpha, c-to-a, rep-col backends
src/graphics-matrix.guess_bg_color        — background color detection
```

**existing visual pipeline** (untested, freely adjustable):
```
src/graphics.matrix.visual.cubic-sort     — 5-phase: classify → group → cluster → batch → layers
src/graphics.matrix.visual.sphere         — sphere classification 0-6, cubic coord calc
src/graphics.matrix.visual.cubic-layers   — hierarchical sphere layer builder
src/graphics.matrix.visual.build-cubic-grid — cubic grid construction
src/graphics.matrix.visual.classify-all   — image classification pipeline
src/graphics.matrix.visual.find-clusters  — similarity cluster detection
src/graphics.matrix.visual.group-spheres  — sphere grouping
src/graphics.matrix.visual.group-by-color — color-based grouping
src/graphics.matrix.visual.group-by-proximity — spatial proximity grouping
src/graphics.matrix.visual.cluster-center — cluster centroid calculation
src/graphics.matrix.visual.color          — color utilities
src/graphics.matrix.visual.extract-color  — color extraction
src/graphics.matrix.visual.extract-palette — palette extraction
src/graphics.matrix.visual.detect-resolution — resolution detection
src/graphics.matrix.visual.similarity     — similarity scoring
src/graphics.matrix.visual.phash          — perceptual hash
src/graphics.matrix.visual.hamming        — hamming distance
src/graphics.matrix.visual.vision-batches — lm-vision batch preparation
src/graphics.matrix.visual.sphere-stats   — sphere statistics
src/graphics.matrix.visual.generate-batch-id — batch ID generation
```

**existing 3D cursor** (untested, freely adjustable):
```
src/graphics-3d.init_code                 — 8×7×13 voxel space (729=9³), GTK3/Cairo 60fps
src/graphics-3d.render.cursor             — cursor render with translucency curves
src/graphics-3d.calc.cursor-translucency  — 6 curve profiles (sigmoid, sine, gaussian, ...)
src/graphics-3d.handler.cursor_navigate   — 3D navigation with wrap-around
src/graphics-3d.cfg.cursor                — cursor configuration
```

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


### grid-hardnode cursor model

full spec: `design/GRID-HARDNODE-CURSOR-MODEL.md`

the primary navigation primitive for the graphics-matrix zenka. merges distributed
terminal interface, vector wireframe rendering, matrix-space navigation, and
psychedelic harmonic realtime visualization — not by design combination but because
all four independently arrived at the same geometric truth: a cursor is a position
with reach, rendered honestly.

reference implementation already exists:
`data/html/visual.v7.ax/grid-v14-layered.refactored.html`
screenshots: `data/gfx/cubic-space-topology/`


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

## initiative H — checksum-based storage and routing

**goal**: content-addressed storage and checksum routing as the enabling layer for
all reference-based features — cross-mapped curves, influence gradients, style layer
addressing, element deduplication — without redundant complexity.

**core insight**: passing a checksum reference IS transferring data between segmented
storage regions. the checksum IS the address. same content = same checksum = single
storage location. no duplication, no complex routing tables — a reference costs nothing
extra regardless of how many nodes hold it.

**existing design corpus** (ready for implementation):
```
UNIFYING-PRINCIPLE-CHECKSUM-COORDINATES.md   — checksum as coordinate system
CHECKSUM-CLUSTER-MAP.md                      — proximity/temporal/semantic/harmonic clusters
CHECKSUM-ROUTING-SECURITY-DEPTH.md           — routing security model
VISION-TIMESTAMP-CHECKSUM-DUALITY.md         — time + checksum together as address
phase-2-indexer-checksum-filesystem.yaml     — filesystem layout + dedup properties
context-tree-checksum-addressing.md          — context tree wiring
checksum-route-binary-framing*.md            — binary framing + harmonic foundations
topic-checksum-addressing.md (memory)        — universal routing primitive summary
```

**P7REF format**: `TYPE:CHKSUM7:ADDR_B32` — 7-char AMOS checksum as universal coordinate.
every entity (model, element, task, node, style layer, lattice position) is a group of
default size 1. scaling to multi-member groups changes membership, not dispatch logic.

**what it enables without adding complexity**:
- element records in vision pipeline addressed by checksum — B1-B5 store once, reference everywhere
- style fingerprints (104-dim vectors) content-addressed — identical style = same checksum = instant dedup
- cross-mapped curve endpoints are checksum pairs — the curve IS the relationship between two addresses
- reference counts are checksum occurrence counts in the cluster index — already maintained
- influence gradient = weighted sum of reference counts, computable from cluster index alone
- palette lattice positions addressable by checksum — `graphics-matrix.lattice.get CHKSUM7` routes directly
- interchange between zenki: pass checksum, receiver fetches from content store — zero-copy transfer

**relation to G (graphics-matrix zenka)**: the visual navigation surface routes by checksum.
selecting a node in the visual issues a checksum-addressed command. the cross-mapped curves
are rendered from cluster membership — same data structure, different rendering angle.

implementation starts with the phase-2 indexer (checksum filesystem) as storage backend,
then wires cluster types into the vision pipeline namespaces.


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

## initiative P — povray zenka

**status**: existing stub — start file wired, init_code placeholder.

**existing infrastructure**:
```
cfg/zenki/povray/zenka.v7   — full start file (auth, net, unix, zenka loop)
                                     wildcard filter command access
src/povray.init_code           — stub (0;), ready for implementation
```

**goal**: raytracing as a P7 network service. povray scenes templated from live
data, rendered on demand, cached by checksum — the reproducible precision of
raytracing as a composable network primitive.

### what it provides

- **topology visualization**: the 8×63+void grid, sphere layers, cross-mapped
  curves — rendered as precise 3D scenes from actual namespace state.
  the same grid that grid-v14 renders in canvas, povray renders with raytraced
  lighting, shadows, reflections. not a different visualization — the same data,
  different rendering fidelity.

- **ambient cube displays**: dot-matrix style displays built from cube primitives,
  positioned precisely in 3D space. location-aware: a display's position in the
  scene IS its lattice address. the display content is supplied as PNG texture,
  updated live from namespace state.

- **location-precise projections**: projected images placed at exact 3D coordinates
  with the projected image supplied as PNG. precision is inherent — povray scenes
  are mathematically exact, not approximated. projection geometry matches the
  cubic topology natively.

- **scene templates from live data**: povray .pov files generated from namespace
  tree state. the scene description IS the data — camera position = cursor
  position, object placement = cell addresses, material properties = reference
  counts and glow intensity. template → data injection → render → cache.

### distributed rendering

in a broader network context, povray becomes a distributed workload:

- **slice rendering**: a scene can be split into horizontal slices, each rendered
  by a different node. the inverse plus sign's 12 transport channels distribute
  slices to available povray instances across the network. each node renders its
  slice and returns the result. assembly is a simple vertical concatenation.

- **checksum-cached results**: rendered frames are content-addressed. same scene
  state = same checksum = cached result. a frame only re-renders when the
  underlying data changes. for stable topology regions (mature, high-quality
  composites), the rendered view is effectively free — cached indefinitely,
  served at memory speed.

- **raytracing without latency**: the combination of distributed rendering and
  aggressive checksum caching means that in steady state, the raytraced view
  is served from cache almost always. re-rendering happens incrementally —
  only the cells that changed since last frame need new slices. the perceptual
  result: raytraced quality at interactive speed, because most of the image
  is already computed and cached.

### relation to G (graphics-matrix zenka)

povray is a rendering backend for the graphics-matrix zenka, not a replacement.
the graphics-matrix provides the data model (namespace positions, reference
counts, glow intensities); povray provides one rendering path. grid-v14 canvas
is another rendering path. terminal block cursor is a third. all three render
the same data at different fidelities:

```
terminal (2D)  →  block cursor in character matrix    (lowest fidelity, fastest)
canvas (3D)    →  grid-v14 wireframe with glow        (mid fidelity, interactive)
povray (3D)    →  raytraced scene with full lighting  (highest fidelity, cached)
```

the three form a fidelity gradient. the user navigates in canvas (interactive
speed), and the povray view renders in the background for the current viewport.
when the user pauses or selects a region, the cached raytraced view is available
immediately if the data hasn't changed. the transition from wireframe to
raytraced is seamless — same geometry, same positions, different rendering.


---

## visual surface infrastructure — web-browser + X-11 zenki

**status**: production-quality — 170+ modules, deployed and tested.

these are not new initiatives — they are **existing infrastructure** that
enables the rendering pipeline for G, P, and B without additional work.

### web-browser zenka (78 modules)

```
cfg/zenki/web-browser/zenka.v7        — WebKit2/GTK3 kiosk browser
src/web-browser.init_code                — WebKit2 4.0, transparency, GPU awareness
src/web-browser.cmd.load_uri             — load URL from P7 command
src/web-browser.cmd.run_js               — execute JavaScript from P7 command
src/web-browser.cmd.switch               — switch between views
src/web-browser.handler.fade_in_view     — translucent view transitions
src/web-browser.handler.swap_views       — multi-layer view swapping
src/web-browser.handler.auto_scroll      — automatic scrolling with speed control
src/web-browser.cmd.start_slideshow      — kiosk-mode slideshow
src/web-browser.calc_zoom_level          — zoom control
src/web-browser.handler.gpu_load_reply   — GPU load awareness
+ 67 more modules (callbacks, handlers, commands, setup)
```

**what it already does**:
- multi-layered rendering with translucency between foreground/background views
- smooth fade transitions between web pages
- JavaScript execution from P7 commands (run_js → direct parameter control)
- kiosk-mode lockdown (no user interaction unless enabled)
- GPU load monitoring with auto-slowdown
- dark blue background (#000013) — protocol-native

### X-11 zenka (95+ modules)

```
cfg/zenki/X-11/zenka.v7               — full X11 server management
cfg/zenki/X-11-pointer/zenka.v7       — cursor control sub-zenka
src/X-11.init_code                       — X11 connection, display init
src/X-11.cmd.set_opacity                 — per-window opacity control
src/X-11.cmd.set_geometry                — window positioning
src/X-11.cmd.get_screen_size             — display geometry
src/X-11.cmd.raise_window                — window stacking
src/X-11.cmd.hide_window / unhide_window — visibility control
src/X-11.cmd.gpu_load                    — GPU load monitoring
src/X-11.cmd.rotate-screen               — display rotation
src/X-11.set_background_image            — background with checksum cache
src/X-11.handler.global_hotkeys          — hotkey system
src/X-11.cmd.wait_visible                — window visibility detection
+ 80 more modules (DPMS, backgrounds, WM, pointer, display state)
```

### tile zenka (42 modules, formerly 'layout')

```
src/tile.init_code                — tile group config loader, checksum validation
src/tile.cmd.switch-group    — switch between tile configurations
src/tile.cmd.add_overlay          — add translucent overlay layer
src/tile.cmd.remove_overlay       — remove overlay layer
src/tile.cmd.sort_layers          — reorder layer stacking
src/tile.cmd.assign_window        — assign window to tile position
src/tile.cmd.get-layer            — query layer state
src/tile.cmd.get_geometry         — tile geometry calculation
src/tile.process-tile-group       — tile group activation engine
src/tile.merge_multiple           — multi-config merge
src/tile.callback.poll_tile_color — tile activity monitoring
src/tile.gpu_alerts.*             — GPU load alert system
+ 30 more modules (handlers, setup, coordinates, transitions)
```

**what it already does**:
- tile group configurations with named presets and hot-switching
- overlay layers with independent control (add, remove, sort)
- window-to-tile assignment with geometry calculation
- tile activity monitoring (color polling, inactive timeout detection)
- configuration persistence with restore-on-restart (timeout-aware)
- GPU load alerts with auto-speed adjustment
- signal handling for graceful transitions

### compton + openbox (10 modules)

```
src/compton.init_code / compton.startup  — X11 compositor (picom)
src/openbox.init_code / openbox.start_wm — window manager with P7 control
```

together with tile, these provide **full composited desktop control**:
openbox manages windows, compton composites them with transparency and
transitions, tile orchestrates the layout and layer stacking — all
controlled through P7 commands. layers and transitions included.

### the rendering stack (already assembled)

the full stack from bottom to top:

```
X-11 zenka          →  display server (real or xvfb virtual)
openbox             →  window management
compton             →  compositing (transparency, shadows, transitions)
tile         →  layout orchestration (tiles, overlays, layer sorting)
web-browser         →  rendering surface (WebKit2, multi-view, translucency)
grid-v14.html       →  cubic space visualization (canvas, 6 zoom layers)
graphics-matrix     →  data model (namespace → visual state)
```

the result: **a P7-controlled composited desktop that can render existing
visualizations as live visual feedback right now**. every layer is independently
controllable through P7 commands. overlays are composited with translucency.
transitions between configurations are smooth.

```
namespace state → graphics-matrix → grid-v14.html → web-browser → tile
                                                         ↕              ↕
                                            JS execution from      layer control
                                            P7 commands             overlay add/remove
                                            (navigation)            (compositing)
```

### the live data bridge — backend infrastructure

the rendering stack has a frontend (grid-v14 in web-browser). the backend
is equally complete:

**data zenka** (108 modules):
```
src/data.channel.shm.*    — SHM channels (create, read, write, poll)
src/data.cmd.mount-cube   — cube-routed namespace mount
src/data.cmd.mount-visual — visual data mount
src/data.get / data.set   — namespace tree read/write
src/data.get.classify_path — path classification
+ fs mounts, hash paths, permissions, array/hash access
```

**httpd + httpsd** (91 modules):
```
async HTTP/HTTPS serving, file transfer, range requests,
benchmark system, diagnostic tools — all production-deployed
httpsd live on pri.v7.ax with non-blocking SSL accept
```

**web zenka** (25 modules):
```
src/web.cmd.render-template — template rendering
src/web.cmd.process-template-ipc — IPC template processing
src/web.assets.*  — asset registry with status tracking
```

**websocket** (4 modules, fresh):
```
src/websocket.init_code   — client subsystem init
src/websocket.connect     — ws:// connect with HTTP upgrade handshake
src/websocket.handler.read — non-blocking read handler
src/websocket.send        — frame send
```

**the complete loop**:
```
namespace change → data zenka → websocket.send → grid-v14 JS
                                                      ↓
                                             grid renders updated glow
                                                      ↓
                                             user navigates (cursor move)
                                                      ↓
                                             JS → websocket → P7 command
                                                      ↓
                                             graphics-matrix.cursor.move
                                                      ↓
                                             namespace update → data zenka → ...
```

the live data bridge is a websocket connection between existing components.
grid-v14 already renders the cubic space — it just needs to receive namespace
state updates via websocket instead of using static data. the websocket
modules handle the transport. the data zenka provides the state. the httpd
serves the page. the web-browser renders it. the loop closes.

no new infrastructure is needed. the bridge is wiring, not building.

this stack is a **precision-bound compositing surface**: each layer contributes
functionality gained cheaply from the physical rendering. layers can be
overlaid with controlled translucency. the web-browser's multi-view system
already supports this — foreground and background views with independent
opacity, smooth transitions between them.

### space as computation

the reason this rendering stack matters beyond UI: **physical space is the
computation**. instead of logically abstracting and tracking all relationships
in data structures (expensive, complex, unbounded), the system renders them
into spatial form and **measures what it sees**.

```
traditional approach:
    maintain abstract relationship graph  →  expensive
    query graph for patterns              →  complex
    track changes across all edges        →  unbounded

spatial approach:
    render relationships as visual overlay  →  cheap (GPU-native)
    measure the rendered result             →  cheap (pixel comparison)
    the merging logic tells you what you're measuring
    the perspective tells you what you're querying
```

3D space is the meeting place and equal-scale translation canvas. perspectives
and visual overlays are the actual computation tools. CPUs and GPUs handle
rendering and pixel measurement at trivially low cost compared to maintaining
an abstract relationship graph — because the spatial structure does the
bookkeeping for free. the grid is not a visualization of the computation;
the grid IS the computation. rendering it is cheaper than abstracting it.

each rendering layer in the stack (terminal, canvas, povray, web-browser
composite) is a different **measurement instrument**:
- terminal: measures position and presence (binary: cursor here or not)
- canvas: measures density and distance (continuous: glow intensity)
- povray: measures geometry and reflection (precise: raytraced interaction)
- composite overlay: measures relationship (what overlaps when two layers merge)

the logic of how you composed the overlay defines what you're measuring.
this is visual computation: the rendering IS the query, the perspective IS
the filter, and spatial proximity IS relationship detection.


---

## dependency graph (simplified)

```
A3 (db access)
    └─→ D1 (unified discover)
            └─→ D2 (curses UI with invoke models)

A1 (graph validation)
    └─→ B4 (inpainting pipeline)

G (graphics-matrix zenka)  ←→  all visual initiatives (bidirectional)
    │                          EXISTING: start file, init_code, filters,
    │                          visual pipeline (cubic-sort, spheres, clusters),
    │                          3D cursor (8×7×13, translucency, navigation)
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
    ├─→ P (povray zenka)  ←→  G (bidirectional: data model ↔ rendering)
    │       EXISTING: start file, stub init_code
    │       distributed slice rendering, checksum-cached frames
    │
    └─→ palette lattice visualization  →  F intermediate layer targeting

RENDERING STACK (existing, enables G + P + B visuals):
    X-11 zenka (95+ modules)  →  display management, xvfb virtual display
    web-browser zenka (78 modules)  →  WebKit2 rendering surface, multi-layer
    tile (42 modules)  →  composited tiling, overlays, layer sorting
    compton (4 modules)  →  X11 compositor (transparency, shadows, transitions)
    openbox (6 modules)  →  window manager with P7 command control
    grid-v14.html  →  already-functional cubic space visualization
    screenshot zenka  →  frame capture
    = full composited desktop stack, all P7-command-controlled

C (opencv zenka plan)  →  absorbed into G as feature detection phase
H (checksum routing)   →  enables G, P, B1-B5 content addressing

A2 (invoke-install)  ·  independent, any time
D3 (lmstudio inference)  ·  independent, low priority
E1-E3 (bugs)  ·  independent, opportunistic
```

#,,,,,.,,,...,,..,,,,,.,,,,,.,.,.,,,.,,,,,,,,,..,,...,...,..,,,..,,,,,,,.,,,,,
#ZVFWUKFOBAOGS7TUDKAESZXAWOVI543PPSRN3P3GGK5R2TKMVSCMZSSIKROMA4U6MXYFRIJBK22OE
#\\\|URJ3GHLTVZ4AERAGOMLYEVI5U33MA6MODUIM6KUA5UEELPFCKOU \ / AMOS7 \ YOURUM ::
#\[7]FQ5XESVAK67SYBUWYQVJGBXZPGEAFFOBTBC2QNTGTEKOAOCRUGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
