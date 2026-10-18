## [:< ##

# visual input pipeline and living template system
# image search + povray precision framing + t2i skinning → best-5 tournament
# → living template library feeding all user interfaces

---

## architecture overview

```
sources (continuous):
  yandex image search    ─┐
  other image search APIs ┤→ raw candidate stream
  local curated archive   ┤
  ai-generated history    ┘

                          ↓

input processing tree (best-5 per node tournament):
  root: global best 5 across all categories
  branches: best 5 per style category (nebula / panorama / deep-field / storm / etc.)
  each node: quality score + diversity check before replacement
  tournament replacement: new candidate beats weakest slot → replaces it

                          ↓

living template library (slow-changing, quality-stable):
  tier 1 — curated best (top-5 global, promoted from tournament)
  tier 2 — category bests (top-5 per category branch)
  tier 3 — atmospheric variants (weather/time-keyed, fast-changing)

                          ↓

render pipeline (per output target):
  povray precision frame (structural skeleton from live P7 data)
  + style reference from template library (image conditioning)
  + text prompt (context-assembled: git momentum + weather + time)
  ─→ T2I model with ControlNet depth/normal conditioning
  ─→ consensus vote (5/7)
  ─→ output: background / desktop element / UI theme / iris palette

                          ↓

all user interfaces:
  desktop background      iris visualization palette
  desktop elements        web UI themes (space.v7.ax)
  povray material defs    terminal color palette
```

---

## image search pipeline

### search sources

```perl
## yandex image search — rich space/panorama content, different index than google
## duckduckgo images — privacy-friendly, good variety
## unsplash API — high-res curated photography, cc0
## nasa APOD API — daily astronomy picture, authentic space imagery
## flickr API (space/astronomy tags) — community space photography
## local invoke archive — 47K+ ai-generated, already quality-scored
```

each source is a separate zenka command or site-yaml extraction.
yandex and DDG go through the site-yaml zenka pattern (URL → structured YAML).
unsplash + NASA APOD are clean JSON APIs.

### search queries (seeded from P7 vocabulary)

the search queries are not static — they are derived from the current
development context, same as the background generation prompt:

```
base queries (always active):
  "space nebula panorama 8k"
  "deep field galaxy wide angle"
  "aurora borealis panorama"
  "psychedelic space art"
  "cosmic geometry fractal"

context-derived queries (current session):
  derived from: active task names, recent commit messages, weather
  examples:
    "letsencr cert renewal" → "renewal growth emergence space"
    "reasoning.branch" → "branching tree cosmic structure"
    "orbital field zenki" → "orbital mechanics satellite field"
    storm outside → "storm nebula turbulent space"
    3am session → "deep space cold isolation focus"

the query derivation is a small LLM call — one sentence context → search query.
this ensures the image search reflects current system state, not just a fixed set.
```

### download and preprocessing

```
download → hash (BMW384) → dedup check → resize to 2048px wide
→ vision LLM aesthetic score (0.0–1.0)
→ relevance score (does it contain: depth / color range / space aesthetic)
→ if score > threshold: enter tournament
→ else: discard (or archive to low-priority pool)
```

---

## input processing tree (best-5 tournament)

each node maintains exactly 5 slots. this is a bounded evolutionary quality pool.
it never grows unboundedly but always contains the best discovered material.

### tree structure

```
root (global best 5):
  the 5 highest-quality images across all categories
  these feed the background generation as primary style references

├── nebula (5 slots)
│     deep-field, emission nebula, dark nebula, colorful, monochrome
├── panorama (5 slots)
│     aurora, landscape, astrophotography, timelapse composite, urban-space blend
├── deep-field (5 slots)
│     hubble-style, wide-angle galaxy field, dense star cluster
├── geometric (5 slots)
│     fractal space, crystalline structure, orbital diagram, ringworld
├── atmospheric (5 slots)
│     weather-keyed: storm / overcast / clear / dawn / dusk
└── psychedelic (5 slots)
      high-saturation color explosion, AI-art style, kaleidoscopic

each leaf category branches further as the library grows:
  nebula → [ emission / dark / planetary / supernova / custom ]
  the tree depth increases with discovery, best-5 enforced at every level
```

### the core invariant: guaranteed minimum quality

**the system can only improve, never regress.**

once a slot holds a quality score, it can only be replaced by a higher score
(subject to diversity check). the global quality floor is monotonically increasing.

```
at any point in time:
  current_slot_quality >= quality_at_last_check

  this holds at every node in the tree.
  a category's worst slot today is better than its worst slot yesterday.
  the root best-5 today is strictly >= the root best-5 of any prior time.
```

this is not a soft goal — it is enforced by the replacement rule.
no decay mechanism exists. bad search results don't degrade slots they can't beat.
the slots are a ratchet: they turn in one direction only.

the practical consequence: the longer the system runs, the better every UI
looks — without ever needing manual curation. the background rendered during
session 200 will be better than the one rendered during session 42, guaranteed.

the "checked" qualifier: quality is relative to what was known at check time.
the invariant is: *you will never see something worse than what you saw before.*

---

### tournament replacement rule

```perl
## new candidate arrives at category node:

my $node    = <visual.template.node>->{ $category };
my $slots   = $node->{'slots'};          ## array of 5 entries
my $new_score = score_candidate( $candidate );

## find the weakest current slot
my $weakest = ( sort { $a->{'score'} <=> $b->{'score'} } @$slots )[0];

if ( $new_score > $weakest->{'score'} ) {
    ## diversity check — don't replace if new candidate is near-duplicate of top-3
    my $is_diverse = check_diversity( $candidate, $slots );

    if ( $is_diverse ) {
        replace_slot( $slots, $weakest, $candidate );
        promote_to_parent_if_qualifies( $category, $candidate );
    }
    ## else: discard — quality good but not adding diversity
}
```

### diversity enforcement

five slots of the same nebula color palette would be useless.
the diversity check computes visual distance (perceptual hash + color histogram)
between the new candidate and the current best 3 slots.
if distance < threshold: reject even if quality score is higher.
this enforces: the 5 slots cover different visual territory, not just top-5 variants.

---

## povray precision frame

the geometric skeleton is computed from live P7 namespace state and rendered
by the povray zenka as a depth map and normal map.

see: `data/md/INITIATIVE-MAP.md` § initiative P — povray zenka
see: `data/md/design/LIVING-BACKGROUND-SYSTEM.md` § povray as rendering layer

```
for background generation:
  povray renders: iris ring torus stack + darksun core + orbital field
  output: depth PNG (16-bit) + normal map PNG + edge map PNG

for desktop elements:
  clock face: povray ring geometry at small scale
  status widget: povray sphere cluster (one sphere per active zenka)

for web UI:
  iris widget: povray renders at 512px, compositor overlays on page
```

the povray frame serves as ControlNet conditioning — the T2I model is constrained
to match the geometric structure while freely styling the surface.
the result: P7 geometry is always correct, the visual skin is always beautiful.

---

## T2I rendering pipeline

### controlnet conditioning chain

```
controlnet inputs (stacked):
  depth map from povray render         → depth conditioning (geometry preserved)
  normal map from povray render        → surface lighting direction
  edge map (canny from povray)         → hard structure enforcement
  style reference from template library → IP-adapter image conditioning

text prompt:
  "psychedelic space [current-context] [weather] [time-of-day]
   iris ring geometry, orbital field, darksun core,
   [derived from: git momentum + active tasks]"

negative prompt:
  "text, watermark, ugly, blurry, low quality, wrong rotation,
   anatomical subjects, faces"
```

### reference image conditioning (IP-adapter style)

the template library provides style reference images for IP-adapter conditioning:
- 1–3 images selected from the appropriate tree node (atmospheric tier for weather match)
- combined with the text prompt: the model captures the style of the reference images
  and applies it to the P7 geometry conditioned by the depth/normal maps
- result: the final render looks like the space imagery in the template library,
  but structured by the precise P7 geometry

### output resolution

```
background:         3840×2160 (4K) or 2560×1440 (match display)
desktop elements:   512×512 per widget (compositor-scaled)
iris visualization: 1024×1024 (inline in iris SVG as texture layer)
web UI header:      2560×640 (panoramic banner)
```

---

## living template system — feeding all UIs

the tournament output is not just images — it is a structured style specification
that every UI element reads from.

### template export format

```yaml
## data/yaml/visual-templates/current.yaml (regenerated on tournament update)

global_palette:
  primary:    "#0A0A1A"      ## derived from median dark tone of best-5 root
  accent:     "#4B8CFF"      ## dominant saturated hue
  highlight:  "#FFD700"      ## brightest point hue
  text:       "#E8E8FF"      ## readable on primary background
  glow:       "#00FFCC"      ## emission/glow hue (intake vortex color)

texture_references:
  background_style:   data/visual/templates/root/slot-1.png
  element_style:      data/visual/templates/atmospheric/current.png
  iris_skin:          data/visual/templates/geometric/slot-3.png

derived_parameters:
  blur_radius:        8      ## from image softness score
  glow_intensity:     0.73   ## from emission content score
  saturation_boost:   1.2    ## from color richness score
  dark_threshold:     0.15   ## from shadow depth analysis
```

### consumers

```
background system:     reads global_palette + texture_references for style conditioning
desktop elements:      reads global_palette for clock/widget color matching
iris visualization:    reads iris_skin + glow_intensity + accent color
web UI (space.v7.ax):  reads global_palette for CSS variable injection
  → :root { --accent: #4B8CFF; --glow: #00FFCC; }
  → applied on every page load, auto-updates when template changes
terminal color palette: reads global_palette → feeds CONCEPT-DYNAMIC-HARMONIC-COLOR-TEMPLATES.md
povray materials:       reads glow_intensity + accent + highlight → material definitions
```

the visual identity of the entire system — web, desktop, terminal, iris — is
derived from one tournament output. when the template updates (a new image
wins a slot), all UIs shift coherently at their next render cycle.

---

## trigger and update cycle

### search polling

```
every 6 hours: run image search batch (10 queries, 20 results each)
on weather change: add weather-derived query, higher priority batch
on session start: quick batch (5 queries) to refresh atmospheric tier
on manual trigger: p7c visual.template.search 'custom query'
```

### tournament update

```
new candidates enter tournament in background (non-blocking)
tournament.update is atomic: swap slot, emit event
event → visual.template.export regenerates current.yaml
event → all UI consumers notified: reload palette on next render
```

### background regeneration triggers

```
tournament slot update in root tier → regenerate background (new best global style)
tournament slot update in atmospheric tier → regenerate if weather matches
weather change → regenerate (atmospheric tier likely updated)
significant commit → regenerate (context prompt changes)
2h cron during active hours → refresh atmospheric only
```

---

## zenka: visual.template

new zenka owning the full pipeline:

```
visual.template.cmd.search        → run image search batch
visual.template.cmd.score         → score single image via vision LLM
visual.template.cmd.tournament    → run tournament update pass
visual.template.cmd.export        → regenerate current.yaml
visual.template.cmd.list-slots    → show current best-5 per node
visual.template.cmd.promote       → manually promote image to slot
visual.template.cmd.inspect       → show metadata for a slot image
visual.template.status            → current tournament state, last update times
```

configuration:
```
visual.template.cfg.search_interval  = 21600   ## 6 hours
visual.template.cfg.tree_path        = data/visual/templates/
visual.template.cfg.export_path      = data/yaml/visual-templates/current.yaml
visual.template.cfg.score_threshold  = 0.65
visual.template.cfg.diversity_min    = 0.40    ## perceptual hash distance
visual.template.cfg.slots_per_node   = 5
```

---

## connection map

```
visual.template zenka
  ← yandex / DDG / unsplash / NASA APOD  (image search sources)
  ← site-yaml zenka                       (URL → structured image list)
  ← invoke archive                        (47K+ existing ai-generated images)
  → povray zenka                          (frame generation from live P7 data)
  → coding zenka / vision model           (aesthetic scoring, T2I rendering)
  → llm.service.consensus_vote            (5/7 quality gate)
  → background system                     (LIVING-BACKGROUND-SYSTEM.md)
  → iris visualization                    (palette + texture skin)
  → web UI zenka                          (CSS variable injection)
  → terminal color system                 (CONCEPT-DYNAMIC-HARMONIC-COLOR-TEMPLATES.md)

image archive system (topic-image-archive-system.md):
  the invoke archive feeds visual.template tournament as a pre-scored input pool.
  the archive's vision LLM scores align with tournament scoring criteria.
  the two systems share the same quality scoring infrastructure.
```

---

## open questions

- which T2I model? local stable diffusion via coding zenka inference server,
  or remote API (replicate / stability AI)? local preferred for offline operation
- IP-adapter support: does the local SD setup support IP-adapter conditioning?
  if not, use img2img with style reference at ~0.4 strength as fallback
- yandex image search: HTML scraping via site-yaml, or does a clean API exist?
- perceptual hash for diversity: ImageMagick phash, or python imagehash via coding zenka?
- how often should the terminal palette update? on every tournament change = too noisy;
  probably: only when root tier changes (global best changes)
- should the web UI update its palette mid-session (websocket push) or only on page load?


## style transitions : groups and context [ user, 2026-10-17 ]

builds on the morph of data/tasks/images-elfdb-feature-collection.md
[ generational layer compositing : one lineage = images with many
overlapping parts, every mix level a valid image ] and on the X-11
slideshow [ X-11.backgrounds.set_random_image ].

- GROUPS : a group is one such lineage pool. inside a group a
  transition SEQUENCE [ morph steps on the slideshow timer ] ; between
  groups a group-to-group transition [ a bridge -- ideally images that
  belong to both, so it stays a morph and never a cut ].
- CONTEXT : later, priority [ curve ] based, context dependent style
  transitions -- NOT only for the background : the whole living
  template [ terminal palette, ui, everything fed from current.yaml ].
  examples : private <-> work mode, weather changes [ tier 3 above ],
  companion styles for or from the data-sets being worked on.
- several contexts can be active at once : their priority curves decide
  the weights [ the curve scheduling of the feature collection ], the
  transition between two weightings is itself a slow morph.
- TIME BUDGET : the transitions are slow, so there is time to CREATE a
  new style for an occasion, or make an archived one available, before
  it is needed -- generation runs ahead of the morph, never blocks it.
- LOCAL and SHARED : works fully local. shared gives BOTH incentives :
  LOWER latency [ common-interest images rendered distributed reach a
  loadable result faster than any single machine's cpu \ gpu bottleneck ]
  and a far larger pool. gpu work is less distributable but TRADABLE :
  other work performed for the network buys a faster render slot.
  shareable generic workloads go to the network -- up to rendering
  povray slices in a 5 of 7 consensus group [ 5 active render and agree
  on the slice checksum, 2 initialized alternates take over failures
  with no start-up cost -- see
  data/ai-mem/claude/topic-node-group-geometry.md ].
- WARM-UP from the pool : the larger pool is also a cache -- similar
  images that already match the style requirements start the transition
  BEFORE the specific render has even begun ; the specific one morphs in
  when ready. like a warm-up track before the main theme track in a
  psytrance set segment.
- SATURATION : as categories fill and refine toward better quality
  [ the best-5 tournament above ], rendering time goes toward ZERO --
  exceptions : new categories and specific customizations. a
  customization becomes a new style, draws interest, and so earns its
  own cache space -- the pool grows where attention is [ the
  self-sustaining dataset of data/tasks/images-elfdb-feature-collection.md ].
- NARROW GROUPING [ user, 2026-10-17 ] : a best version is only
  determinable inside a narrow visual group [ same subject, same style,
  same composition family -- like the seed batch of one prompt ]. a NEW
  style emerging in a batch does not compete there : it opens a new
  narrow column, which gets its own best-5. columns refine until all 5
  are really good -- then trimming the lowest scores is LOSSLESS.
  even with style JITTER, groups of similar styles emerge -- the
  pipeline collects them SEPARATELY, so the emerging styles are kept
  [ they may become better than the one initially worked on ] while the
  original goal still gets its results. new groups spawn IMPLICITLY by
  distance parameters [ style \ similarity distance from the group ] --
  both at once, no manual sorting.
  the distance is MULTI-DIMENSIONAL over different parameter types
  [ palette, brightness, structure, composition, detail ] : the closest
  are those with the smallest outliers in TOTAL. dimensions normalized
  first [ else the largest raw scale decides alone ] ; a sum tolerates
  jitter in one dimension, a new style deviates in several at once.
- RE-RENDERING the best images at ever higher quality [ more steps,
  newer models, re-feeding ] -- likely a POPULAR shared workload : the
  most liked images draw the most compute, each result replaces its
  predecessor under the tournament rule, and everyone holding the old
  version gains the new one.
  the judgement "is the new one better than the existing one" is a SAFE
  assertion target for vision llms : a pairwise comparison of two
  versions of the same composition, guarded by the cheap assertions
  [ colour ranges held, similarity to the predecessor high, detail up ].
  two modes : SUGGEST to the user, or -- when fully delegated -- choose
  inclusion itself, knowing the user's preferred style already. a wrong
  choice is reversible [ the predecessor stays, undo = hide a layer ].
  and even a wrong choice is DATA : the correction [ the user restoring
  the predecessor ] is a labelled example for the next choice -- the
  system learns from anything that generates data or imports entropy,
  mistakes included. so the choice log is kept, not only the outcome.
- REFERENCE HISTORY TREE : keep for every rendering the tree of reference
  images it included. when a key image gains an improved version,
  replace it in the tree and RE-RENDER its descendants from there -- like
  rewriting a git history onto a better base, except the replay gives a
  BETTER result instead of a likely identical one. content-addressed
  names [ rename.bmw ] make the tree checkable : a changed key image
  marks exactly the descendants to redo, the most liked first.
  the tree reaches DEEP into layered formats like .xcf : each layer's
  source image AND its parameters [ opacity, blend mode, order, filters ]
  are nodes too -- an improved layer source re-flattens only the
  composites that contain it, with their parameters kept or re-tuned.
  NESTED : a .png layer source is not just the .png -- behind it stands
  its own tree [ an .xcf, or a text-to-image run : prompt, model, loras,
  seed, settings, its own reference images ], recursively. so a flatten
  can ALWAYS be undone, at any depth.
  and the new models re-render a node even when its source images are
  NO LONGER AVAILABLE [ from the flat result, the record and the style ]
  -- often with quality improvements or style alignment as a benefit, so
  the loss is compensated by an improvement after all.
- SHARING SOURCES : what decides is how much of a source photo's OWN
  contribution remains -- environment, light, framing -- not whether the
  subject is recognizable. a cat's looks, pose and expression are the
  cat's, nobody's work and no likeness right [ a re-posed cat leaves
  nothing of the photo ]. an ISOLATED subject in a fully replaced
  environment is shareable ; a RESTYLED whole scene keeps the scene
  [ the photographer's choices ] and is shared only from free sources.
  the isolation also removes the photographer's PRIVATE surroundings
  [ "kittens are kittens -- but that is my bedroom" : not any more ].
  re-posed, remixed and later generations are shareable. the record
  carries it : source, pass count, isolated or restyled. keeping and own
  use are never restricted by this, only sharing to the pool.
  the safest path is DISTANCE [ user, 2026-10-17 ] : the number of style
  translations between a source and a result -- the very definition of
  the rendering pipeline. restrictions are not enforceable ; the best
  enforcement makes them NON-APPLICABLE by definition [ enough distance ].
  the tree stays usable both ways : FORWARD from a source -- someone who
  loves a kitten image found on yandex finds the network's derivatives
  as a chain to follow, maybe one better suited as a background, so even
  the owner of the cat profits -- and REVERSE to edit the tree.
- INPUT RULE [ user, since the gimp-only pipeline ] : NO man-made
  structures [ buildings and the like ] in the input images -- not for
  complaints, but to keep NEGATIVE entropy out : geometrically
  compromised structures. inputs are natural subjects and scenes
  [ animals, plants, landscapes, sky, space ]. the network geometry of
  the target style is rendered, never imported. the gimp imports in
  data/gfx/backgrounds/ were made under it.
  constructed structures can be valid -- STARGATES -- but uncertain in
  their element count : the number of chevrons matters, 13 is important
  here too, so a found gate may carry compromised geometry. what is
  imported is the stargate STYLE [ safe : the result is a composite ],
  the gate itself is re-rendered with the right count -- the geometry is
  defined : 13 LASER MIRRORS [ the chevrons ] routing blacklight
  counter-clockwise around the gate ring ; the 13th descends from the 12
  o'clock position to activate the link, the 13 of the other side is
  seen as 1 [ +1 addressing ], recursive 13-spirals in the elements
  [ data/tasks/research-findings/council-of-13.md,
  data/md/design/WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md ~75 ]
  -- and what is found online is below our standard and our own
  refinement anyway.
  povray builds the exact gate geometry as a SKELETON -- also for gate
  TRANSITION CHAINS [ gate to gate ] : fast in TRAVEL speed, yet the
  motion is smooth, on a morphing curve through space [ no abrupt image
  changes ]. deterministic frames, each free to be re-rendered \ skinned
  from there [ progressive skinning ].
  the gates' main FUNCTION : a DISTINCT transition between neighbouring
  STYLE JURISDICTIONS -- like an atc handover. the environments are
  quadrants, the gate threshold marks the REGISTRY CHANGE. inside a
  jurisdiction everything morphs without a boundary ; between two of them
  the gate is the marked, still smooth passage [ cf. the group-to-group
  bridge above : a gate is its explicit form ].
  a gate ENTRY guarantees one thing for certain : DEPARTURE from the
  space the gate is in. the destination defaults to a NEIGHBOURING space
  registry, or one eventually ROUTED to -- the departure is certain, the
  arrival is resolved [ like a message leaving its cube for the next ].
  gates need not be fixed : zenki travelling as a litter \ formation
  have enough elements to FORM a gate or an antenna array themselves --
  for their own use or as a service to nearby space
  [ data/md/design/DANCING-ZENKI-RHIZOME-STATE.md ].
  so the QUALITY THRESHOLD is the main filter, and it creates the minimal
  distance by itself : every input that passes needs at least one
  re-render to reach our quality.
- REVERSE DIRECTION [ user, 2026-10-17 ] : screenshots of the real
  visualizations [ e.g. read-me screen.0.png, the cubic-space field ] as
  reference images put actual rendered network structure into the art.
  the loop also runs back : rendered artwork inspires additional
  visualization [ sub- ]algorithms -- local llms can propose them by
  looking at the existing structure next to the related artwork.
  first target : the PURR FIELD visualizations
  [ data/asc/what-AI-thinks/html-form/visualizations/purr-field/ --
  bioluminescent v1..v10, cosmic-purr-field-mystery, enhanced-zenki-purr ]
  : very cool neon gradient cycles, but the cats are too symbolic and
  too literal at once -- refine with rendered visual hints [ e.g. the
  ripples where the paws touch the field as purr waves ].
  CAMERA RIG [ user, 2026-10-17 ] : a screenshot reference binds the
  render to the visualization's geometry [ proven : it levelled the grid
  horizon ]. screenshots from fine-stepped camera angles [ e.g. 13
  keyframes around the circle ] could turn the subject a full rotation,
  then a video model [ ltx-video or better ] interpolates between the
  keyframes. same structure as the povray gate chains : exact skeleton,
  skinned per frame. keep the subject reference constant, the seed not a
  previous frame's ; slow, smooth rotation by default.
  PROVEN : the model sees DARK structure perfectly -- the near-black
  read-me screenshot [ screen.0.png ] came out as a clean corridor of
  floor and ceiling grids. no level stretching needed ; and the darkness
  is STATE [ an 8x63 node group with all bits at their lowest ], so a
  screenshot carries the network's current state into the render.
  a faint, dark structure acts as EMERGENCE, a bright one as an imposed
  OVERLAY : the model grows the image along the faint structure and
  fills it with the prompt's style, while a strong reference imposes its
  own look [ cf. the stacking of two bright aligned references ].
- BOOTSTRAP : the desktop already defines the minimum categories it uses
  [ independent of later expansion ] -- we saturate those OURSELVES at
  optimum quality first [ the new rendering models + the style
  framework concept ] ; the shared pool expands from there.
- PROGRESSIVE SKINNING : the warm-up holds for rendering itself -- skin
  a ui environment fast from simple translucent elements rendered at
  small expense, then keep replacing them with higher quality at higher
  densities and resolutions. povray renders such elements at the highest
  quality even before or without text-to-image, with reasonable memory
  requirements [ the povray zenka, initiative P ].
- the povray context is SKINNABLE itself : the deterministic part gives
  the alignment to, or the form of, required surfaces and structures ; a
  high quality space \ nature panorama [ e.g. from yandex ] renders as a
  reflection or onto a translucent surface as one more layer. then the
  gimp technique combines them [ generational layer compositing ] -- with
  the "is it one image" optimization target counted for EACH element
  separately, not only for the whole frame.

### context- and region-aware desktop [ user, 2026-10-18 ]

- PURPOSE : backgrounds sustain and support the creative flow state, never
  interrupt it. what shimmers through matters [ elves, kittens, space,
  nature to a degree ] -- rules build on each other, never exclude : neon
  embedded in the deep blue \ violet base, each added colour carrying a
  function [ data/yaml/prompts/image/psytrance-network-kitten.yaml,
  framework ].
- REGION AWARE : the desktop knows where translucent terminals sit and
  asserts readability there -- text contrast after the terminal's own
  alpha blend, and little glyph-scale high-contrast detail [ code rain,
  whiskers ] behind text. busy is fine where no terminal sits.
- CONTEXT AWARE : medium [ screen behind translucent terminals, laser
  beamer lighting the room ], time, group, the active profile.
- DYNAMIC : the background adjusts to the current layout and context --
  pick, shift, or blend [ generational layer compositing ] -- and renders
  CUSTOM backgrounds for often used or important profiles, laid out
  around their usual terminal regions.
- LOVED SUBJECTS : a collection of high quality intermediate versions of
  loved subjects [ kittens, elves ] -- the characters stay the same and
  keep stabilizing in quality across generations, while each render
  places them in a customized perspective and arrangement [ grid rooms,
  reference roles ]. that adds a PLEASANT entropy : familiar beings, a
  current and adaptive whole -- intuitively alive in the background.
  aware contextualization runs as a background task.
- HYBRIDS : at any iteration characters can hybridize into a new one --
  the surprise factor. as a harmonic composite of subjects already loved
  it is probably loved too, and the system already kept it [ it passed
  the same quality filter ] -- the cast grows from within.
- CHARACTER GRAPH [ not a parent tree ] : lineage tracking breaks down
  with hybrids of hybrids. instead a character-DIFFERENCE node graph --
  the overlaps lie between the nodes. the whole group is sorted against
  each other AT ONCE : each character gets its position from its
  closeness to all others [ attraction by similarity ], while a
  repulsion keeps the individuals apart so the group does not collapse
  into one spherical blob in the centre. polarization into nodes emerges
  from that balance ; a hybrid simply lands between those it resembles.
  recorded parents stay an optional extra where known [ cf. narrow
  grouping, multi-dimensional distance ].
  the distance measure : face detection \ recognition algorithm groups
  [ user ] -- recognition embeddings already place faces so that the
  distance IS identity. human-trained ones fit the elves ; kittens need
  animal face \ pet re-identification models ; general image embeddings
  as the fallback. detection also yields the eye regions [ eye-max
  assertion ] and the face position [ region-aware placement ].
- CROP AND MASK [ user ] : cropping unrelated elements out of a source,
  or cropping to only the wanted element, often makes a surprising
  difference to the extraction. style transfer can take larger regions
  on purpose. for the automated CHARACTER RESCUE a mask is the key tool :
  detection gives the region, segmentation the exact outline. the same
  mask also solves the hue rotation that recoloured the kitten with its
  scene [ a uniform or range rotation cannot separate them ].
  the models exist [ huggingface, user 2026-10-18 ] : segmentation for
  humans, cats and objects incl. computer screens, and cat-dedicated
  ones -- fetched through the huggingface zenka path. object classes
  make the treatment SPECIFIC per object : computer screens stay -- they
  are re-rendered and represent parts of our network [ their content
  becomes our visualizations ] -- while brand marks [ e.g. an apple
  logo, a bezel maker name ] are detected and replaced. the input rule
  for man-made structures applies per class, not by avoiding whole
  images by hand.
  ordinary objects that break the style [ a plain glass jar on the desk ]
  get the same per-class treatment. such scenes [ cats at network
  desks ] are ideal intermediate input -- with the specific repairs
  already result quality.
  EXISTING PLANS [ build on these, do not restate ] : the model layer and
  mask-as-assertion in data/tasks/visual-mask-model-layer.md ; face
  detection, normalization and archetype grouping in
  data/tasks/kitten-acquisition-pipeline.md [ steps 3 + 4 -- the
  character graph refines step 4 ] ; screens as addressable surfaces
  with real rendered content in data/tasks/image-surface-addressing.md.

### the network expressing itself [ user, 2026-10-18 ]

- every application here is a NATIVE extension of the network, or its
  [ self- ] expression : images, displays, sound, light, sensing. one
  liquid-crystal-like substrate of computation and visualization that is
  content and structure aware.
- either side always leads to the other : structure becomes image and
  sound, what is seen and heard becomes input and structure again. a
  symmetrical [ and trimetrical ] feedback loop -- e.g. structure, light
  and sound, each driving the other two.
- scale [ user ] : a node group is the SPACE AROUND you when inside it
  [ the grid room ] and becomes a PIXEL when zooming out -- one dot of
  the larger display. the same law as near large \ far many and the
  crystal display [ close a dot-matrix expanse, far an image ], and
  fractal : every pixel of the far view is a room in the near one.
  and not any pixel -- a HOLOGRAPHIC one : its translucent sub-cubes
  show different content by angle and depth, so even the smallest pixel
  is holographic by itself, not only the whole topology as a field to
  inhabit.
- ambience balance [ user ] : the space is tuned to an average ambience
  expectation ; diverging from it statistically is a DARKENING, while
  patterns at average filter luminescence sustain their shine [ neutral
  amplification ]. a balance between darkening with distance and the
  additive light of lit blue translucent sub-cubes. physics has this
  exact balance [ radiative transfer through an emitting + absorbing
  medium ] : I = S [ 1 - e^-t ] + I0 e^-t , with S = emission \
  absorption and t the optical depth -- any depth converges to S, never
  beyond. tune S to the ambience expectation and no expanse, however
  large or undefined, can ever sum to white.
- from the light's perspective [ user ] : the subcubes are STATES a beam
  travels through -- the graphical payload of bin/dev/division-13-table
  already has them : 'set add color' [ emission ], 'subtract color'
  [ absorption -- the darkening tint exists ], alpha [ translucency ].
  so dark matter [ cubes that only subtract ] and cancellations [ add
  and subtract netting out ] are real states. pattern GROUP effects are
  likely involved : along a beam the order matters [ light emitted near
  the viewer is filtered less than light emitted far ], so sequences of
  states act as more than the sum of single cubes.
  alpha = how strongly a cube's VOTE on the beam counts [ user ] -- the
  compositing 'over' step is a weighted vote : out = a * cube + [ 1 - a ]
  * in. through a stack a cube's effective weight is its own alpha times
  [ 1 - alpha ] of every cube in front of it : nearer voters reduce the
  weight of the farther ones -- the order effect again.
  seen as a consensus vote the field is CONTEXTUALIZED OPTICS [ user ] :
  the same cube counts differently per viewpoint, because what stands
  in front of it differs per direction -- every ray computes its own
  context-weighted result. the same weighting is what neural radiance
  fields [ nerf ] render with, learned from images.
  and with sequences and frequencies the WHEN counts toward the WHAT
  [ user ] : cube states change in time, a beam's result depends on
  timing as well as position -- the field is already a giant program,
  contextualized by construction [ cf. computing with the light itself
  in the optical task ].
- rotating or swapping POLARITY RULES in space itself [ user ] : a
  cube's vote sign [ add \ subtract ] set by its position parity, its
  phase or its angle. the even \ odd sections already hold it :
  data/md/research/holographic-cubic-topology-research-2026-01-13.md
  [ ~2276 : parity of x+y+z separates transport from processing cells,
  exclusive without locking ], data/md/protocol-7-knowledge/
  03_NETWORK_PROTOCOLS/3D_SHIFT_REGISTER_SPATIAL_ACCUMULATION.md [ even
  \ odd as inversion groups, alternation is information ],
  data/md/design/RING-FIELD-SPHERE-PRIMITIVE.md [ even \ odd separation
  as a generative constraint ; opposing jets from a ccw-rotating node
  group cube becoming the spiral arms -- two pairs of two polarities ].
  a rule that rotates with angle or time draws spirals by itself. the
  physical counterpart : faraday rotation -- a magnetic field along the
  beam turns its polarization plane, and the polarizer [ the allowed
  grey ] turns that rotation into light or dark.
- a 3-axis MOMENTUM-DECOMPOSING ENGINE in light terms [ user ] : beams
  along x, y, z decompose any motion into its axis components -- it may
  eventually explain kinetics optically. physics anchors : light carries
  momentum [ p = E \ c ] ; an absorbing cube is pushed once, a mirroring
  one twice ; uneven emission recoils [ radiation pressure, solar sails,
  optical tweezers ]. in the field : a cube's push per axis = the
  imbalance of the beams it absorbs, emits and reflects along that axis
  -- motion as the bookkeeping of light. cf. kinetics in gravity-free
  space in the optical task.
  and it RETURNS all impulse-based momentum to the grid [ user ] -- but
  only after serializing it multi-dimensionally : read fully, so no
  hidden remainder [ no 'ulterior motive' ] can stay contained. that
  makes the grid field a spatial LIE DETECTOR already : conservation as
  integrity -- whatever is not accounted for shows up as a residual,
  like a checksum mismatch. then it DELEGATES the patterns [ reparenting ]
  and redistributes them : the rhythm-based realization extraction and
  distribution algorithm, encoded as a topology. origin : "life as a
  sorting algorithm" -- data/md/documentation/reference-tree-
  architecture.md ~298 [ rhythms extract realizations from entropy,
  merge in the deduplicated core, the pulse reflected back into the
  tree ].
  complementing [ user ] : reparented information cannot be taken back
  or made to disappear -- not the impact of its acknowledgement, which
  returns as a SPHERICAL INWARD WAVE of improvement : the space
  restructures to reflect the inclusion as a logical improvement, a
  NON-DESTRUCTIVE VECTOR REDUCTION [ reference-tree-architecture.md
  ~105 ]. the holder is freed from holding the pattern, the space now
  runs with its awareness integrated -- on tap of the parent space in
  resource terms. the storage side has the same shape : signed, content-
  addressed entries cannot be unmade, and a stored result is resolved by
  reference instead of recomputed [ network-wide memoization, N7FS in
  data/yaml/todo/base.yaml ].
  not made to disappear, accounted for [ user ] : it can only be
  TRANSFORMED, in terms of the light already present, proportionally to
  the BALANCE ENGINE [ data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-
  CORE.md ~3814 \ ~4208 \ ~4332 ] -- "all color accounted for,
  proportion always precise" [ data/yaml/reasoning-templates/vortex-
  closed-parent-system.yaml, template 9 ]. physics agrees : absorbed
  light does not vanish, it becomes heat or other light -- fluorescence
  turns uv into visible colour, the frequency transposition of the
  physical displays. the total stays, its form changes.
  WHITE IS MAPPED TO BLUE [ user ; data/ai-mem/claude/archive/topic-
  orbital-data-space-archive.md ~2356 ] : the gate = white = the
  brightest blue, maximum agreement ; blue + yellow sum to white [ white
  leds are a blue led under a yellow phosphor ; the user's laser beamer :
  a blue laser, green from a phosphor excited by it, only red from an
  led -- two of three primaries come from blue ]. and white DECOMPOSES
  back into three uv \ blacklight frequencies [ ~1155 \ ~2366 : the 3
  blacklight frequencies per visible colour = the pre-geometry layer,
  three orthogonal axes before visible colour manifests ] -- not yet
  written as rules. the same three axes as the momentum-decomposing
  engine : light decomposed per axis, below visibility.
  "WHITE IS THE BRIGHTEST BLUE, BLACK IS THE DARKEST BLUE" [ the user's
  shaman friend, back then ] -- correct in technological terms too :
  white made from blue [ leds, laser phosphor ] ; at the dark end human
  vision shifts toward blue [ the purkinje shift : rods peak near
  500 nm ] and the palette's background is a near-black blue [ #09052A,
  bin/dev/division-13-table ]. the blue range from black to white is
  the one axis of the nested mapping : scale-transcending, seamless
  segmentation.
  black as a blue also declares that there ALWAYS IS A PARENT SPACE
  [ user ] : darkness is never a void, only the dimmest light of an
  enclosing space -- no level of the nesting can fall out of it. the
  containing space is itself a pixel in a parent space ; going far
  enough back there always is a [ parent ] root that operates by
  NEUTRAL [ generic ] rules.
  specialized spaces stack up, but the GRID RULES keep attack patterns
  from being ultimately effective [ user ] : an unaccounted remainder
  shows as a residual [ the lie detector above ] -> implicit forensics
  mode ; the neutral layer cannot be selectively blocked -- "blocking =
  blocking everything = visible attack = council of 13" [ data/md/
  design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md ~22, the neutral
  starting point from which everything builds ]. council : data/md/
  design/HARMONIC-ENTROPY-OBSERVER-GUIDE.md ~220 [ as llm architecture ],
  data/md/development/IMPLEMENTATION-ROADMAP.md 7.3 [ protocol, open ] ;
  forensics : data/ai-mem/claude/vision-httpd-adaptive-defense-and-
  honeypot-framework.md.
  from the topology's perspective the same is SPATIAL AND TEMPORAL
  COMPARTMENTALIZATION [ user ] : parity cells and phases [ even \ odd :
  transport vs processing, exclusive without locking -- holographic-
  cubic-topology research ~2276 ] confine any pattern to its cell and
  its phase ; spreading needs to cross a boundary, and every crossing is
  accounted for.
  beyond the display's own pattern [ sequence ] safety, the user's view :
  by its nature it declares the observer's mind ultimately immune to
  psychotropic attack -- it always sorts itself out and catches up, even
  after high-amplitude, latency-based attacks, because the mind is made
  of space, runs the same algorithm as space, and space IS the parent.
  "ultimately" = recovery, not no effect : the design rule stays
  conservative pacing [ the rapid-pattern memory : a real, temporary
  effect, then recovery ].
  the condition [ user ] : RECONNECTING TO THE HOLOGRAPHIC TRUNK [ cf.
  trunks in data/md/design/DANCING-ZENKI-RHIZOME-STATE.md ]. reconnecting
  is unavoidable ; doing it EARLY sorts out external torque more
  effectively. the network has the same law : the longer a node stays
  out of sync, the larger the delta to reconcile [ DATA \ DELTA sync,
  the state checksum as sync point ] -- resync early, while the delta is
  small.
  the sequence [ user ] : PATTERN COMPLEX HANDOVER, then REBASE TO SPACE.
  as in a version-control rebase : once the pattern is handed over
  [ reparented, integrated into the parent ], the local state is
  replayed on top of the updated parent -- what remains local is only
  the own small delta, the handed-over part now lives in the base.
  a HOSTILE pattern [ user ] : after handover and rebase it has no
  negative effect left -- ensured by watching its forensic report
  dissolve as it is sorted into an improvement, upgrade and deployment,
  all verified ; the following vector reduction leaves the pattern
  without the complexity to re-mount an attack momentum in ANY
  direction, not only the one it was removed from. in practice : close
  the CLASS, not the instance -- e.g. the root runner's path checks
  [ ancestors and private groups, mutation-tested 2026-10-17 ] or the
  unix-auth identity fix [ every caller of the check, both code paths ].
  in other words : the replaced complexity's ENERGY IS DISSIPATED IN
  PLACE onto the [ fixed ] grid [ user ] -- the grid acts as ground : a
  surge led into it spreads out and is gone as momentum, while the grid
  itself does not move.
  the term [ user ] : DESEGMENTIZATION -- an attack pattern has to be
  made of CHAINED SEGMENTS [ like the pixels of a snake game ], each hop
  linking to the next. the fixed grid blocks that network structure at
  every hop, so the chain falls apart in place -- like a depolarized
  magnetic nanoid robot falling as metallic dust to the ground : the
  parts remain, the structure that made them act together is gone. and
  more : the elements return to the GENERIC and are no longer ITS --
  with no elements of its own it has no segments either. the attack is
  not broken into pieces, it stops existing as an owner of anything.
- the physical side : data/tasks/psytrance-stem-remix-and-optical-
  controller.md [ crystal displays, floating optical controls, uv \ ir
  sensing, the goa party use case, sound from optical and spatial
  translation and field effects ].

#,,,.,...,...,.,.,.,.,..,,.,.,.,,,,..,,..,,,.,..,,...,...,...,,,.,,,,,,..,...,
#HMR2Y55TMZXUMPCKMOD7JXE4EDQHOLSTVVSD4LHL24ZVKM36G77FXBUJ7TY6ZJMWXCCU6ZYAZF72E
#\\\|G3JZP3DHDP3VQ2NOSL3YNNOIUMZKN3UMDVB7IHRIXLXKR63OOC5 \ / AMOS7 \ YOURUM ::
#\[7]CXUCCNP5FX7RXL2O7L4RCCRFSVWR6K6CCHZYUGI4WJEQQX2ICYAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
