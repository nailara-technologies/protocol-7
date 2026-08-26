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

#,,.,,,,,,,..,...,,..,...,,,,,,.,,...,,,.,,.,,..,,...,..,,.,.,.,,,.,,,,.,,,..,
#2KYYJS2RKP3U56QMSSCK7IEML56YL3MLVOWBYQIAP235WQLLCVRHAFW6HZPRCFRWL5245P6YVVAMU
#\\\|BRGYXEHLCVANZLH5RVIZ2HK2O6XNWUL7TKVQQ5ZAKHHOMXWAOVJ \ / AMOS7 \ YOURUM ::
#\[7]NKVSH33ROQODVBIB6YU44OZX6DXKU3WEC7XBJPMWO2HKAODPAECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
