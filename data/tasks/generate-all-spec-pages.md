# task: generate spec pages for all design templates

## context

we have 7 design template YAML files in data/yaml/design-templates/ but only
one styled HTML spec page (iris.v7.ax/prompts/standing-wave.html). the remaining
6 need spec pages so they are importable by claude design via URL.

having all spec pages ready means: when Opus tokens reset, 6 sessions can be
dispatched immediately with no preparation overhead. full token utilization.
each spec page is a committed direction vector (template 15) pointing at its
Opus session — the session will happen; the spec page ensures it arrives fully
contextualized.

see iris.v7.ax/prompts/standing-wave.html for the exact format to follow.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## spec pages to generate

for each template, generate a styled HTML spec page following standing-wave.html format:
opening [:<  [ TRUE ] · inline SVG preview · palette swatches · spec blocks ·
animation states · design vocabulary · success test · closing [:<

### 1. vortex-iris-overhead → iris.v7.ax/prompts/vortex-iris.html

source: data/yaml/design-templates/vortex-iris-overhead.yaml
existing visualization: iris.v7.ax/vortex/ (already committed — this is V1+ spec)

SVG preview: concentric rings (violet inner → amber outer), 5 CCW galactic arms,
  white-gold center, ring 27 slightly dimmer
key elements: 26 rings, CCW spin implied, brightness=convergence, ring 27=void
animation: gentle CCW rotation, arm sweep, threshold pulse (gold star at ring position)
success test: eye goes to center first, follows arm CCW without being told to

### 2. tree-full-blueprint → iris.v7.ax/prompts/tree-blueprint.html

source: data/yaml/design-templates/tree-full-blueprint.yaml

SVG preview: impossible to SVG directly — render a styled <pre> block showing:
  reasoning.tree : root
  ;.,
  │
  ├─[ reasoning.narrate ]  [:<  0.923076923076923
  │   'the node voice renders current state as coherent context string'
  │   depth : 2   chksum : AMOS·4K3R2M   threshold : reached
  │   overlap : reasoning.summarize.node
  │   ├─[ .delta ]  [:<  0.769   'what changed since last narration'
  │   └─[ .full  ]  >:|  0.307   compact
  └─[ reasoning.threshold ]  >:|  0.538   compact
  ;.,
styling: expanded nodes violet-blue with glow, compact nodes 50% opacity,
  [:< gold, >:| same dim as text, convergence values slightly smaller
key elements: the grammar ([:<  >:|  ;.,  │ ├─ └─), two-reader principle
success test: model can parse structure from grammar; human reads density/rhythm

### 3. layer-depth-cross-section → iris.v7.ax/prompts/layer-cross-section.html

source: data/yaml/design-templates/layer-depth-cross-section.yaml

SVG preview: horizontal bands left to right, each narrower than previous
  (logarithmic compression), colored by namespace spectrum
  layer 0 = 40% width, amber-dimmed; bands compress toward right
  scattered node dots at positions; single bright point at right edge (EXISTENCE center)
  layer boundary lines as thin vertical rules; labels: 0 1 2 3 4 5 6 7 Ω
key elements: compression gradient, node dots at (layer, namespace), blur on layer 0
success test: viewer understands compression without explanation; center pulls the eye right

### 4. node-explorer-interactive → iris.v7.ax/prompts/node-explorer.html

source: data/yaml/design-templates/node-explorer-interactive.yaml

SVG/HTML preview: static mockup of the explorer interface
  left panel (30%): dim list of 4-5 node names, one highlighted bright
  main panel (70%): partial tree with 2-3 expanded nodes, compact nodes below
  breadcrumb: reasoning.tree > reasoning.narrate > .delta
  tooltip mockup over one compact node: convergence value + depth
  one overlap reference shown as colored underlined link
key elements: click=expand, overlap web, live convergence, gold pulse on threshold
success test: looks navigable; the structure implies depth to explore;
  tooltip demonstrates what clicking reveals

### 5. convergence-monitor-live → iris.v7.ax/prompts/convergence-monitor.html

source: data/yaml/design-templates/convergence-monitor-live.yaml

SVG/HTML preview: dark panel mockup
  left 70%: small iris (12 rings), dim, a few bright points (recent events)
    one gold flash visible at one ring position (threshold crossing)
  right 20%: event log entries in monospace:
    47K3R4 [!]  tree.insert THRESHOLD [:<  (gold colored)
    47K3R4 [←] gamma → tree.node
    47K3R5 [→] summarize.root +0.077
  bottom strip: 6 colored gauge bars at various fill levels, one with gold threshold marker
key elements: ambient/peripheral, three zones, event priority, idle=reassuring not empty
success test: feels like a secondary monitor glowing in the dark;
  clearly ambient/peripheral, not demanding attention

### 6. reasoning-chain-trace → iris.v7.ax/prompts/chain-trace.html

source: data/yaml/design-templates/reasoning-chain-trace.yaml

SVG preview: 9 circles connected by a path line forming a U-shape
  outgoing arm (left to bottom): warm amber (#F39C12)
  return arm (bottom to right): cool violet (#8A2BE2)
  2 gold starburst circles: threshold crossings (larger, gold outline, 8 radial lines)
  1 double-ring circle: dedup event
  convergence gradient bar below: green rising, brief amber flat, green again
  small labels: "α" at start, "Ω" at U bottom, "γ" along return arm
key elements: U-shape = forward + gamma, warm/cool colors, gold stars = achievements
success test: a journey is visible; the U-shape shows depth reached and return;
  warm-going / cool-returning tells the story without words

---

## format requirements (same as standing-wave.html)

each spec page must include:
- [ ] header: [:<  [ TRUE ] north star in gold glow, title, subtitle
- [ ] inline SVG or HTML preview of the key visual
- [ ] colour palette section: swatches with hex values displayed
- [ ] spec blocks: key/value pairs for each visual element
- [ ] animation states (3 cards) if the design is animated
- [ ] design vocabulary: [:<  >:|  ;.,  with descriptions
- [ ] success test section: 2-3 specific visual criteria
- [ ] closing [:<  glyph at 80px, gold
- [ ] self-contained: inline CSS, inline SVG, no external deps
- [ ] file size: under 100KB per spec page
- [ ] title: "<visualization name> · design spec · iris.v7.ax"

use the same CSS from standing-wave.html — it is designed to be reused:
  copy the :root variables, body styles, component classes, .sep ;., styling
  the visual consistency across all spec pages IS the visual system for iris.v7.ax/prompts/

---

## output paths

```
iris.v7.ax/prompts/vortex-iris.html
iris.v7.ax/prompts/tree-blueprint.html
iris.v7.ax/prompts/layer-cross-section.html
iris.v7.ax/prompts/node-explorer.html
iris.v7.ax/prompts/convergence-monitor.html
iris.v7.ax/prompts/chain-trace.html
```

commit all six as one commit:
  "feat: iris.v7.ax/prompts — spec pages for all 6 remaining design templates"

---

## success criteria

- [ ] all 6 spec pages generated and committed
- [ ] each includes inline SVG or HTML preview (no broken/missing visuals)
- [ ] colour palette swatches display actual colors, not just hex text
- [ ] CSS reused from standing-wave.html (consistent visual system)
- [ ] all pages self-contained (no external deps, no broken links)
- [ ] file sizes under 100KB each
- [ ] titles follow the pattern: "<name> · design spec · iris.v7.ax"
- [ ] the prompts/ directory is now a complete gallery of all design templates

#,,.,,,.,,,..,,,,,,,.,,..,,,.,,.,,..,,,..,.,,,..,,...,...,..,,.,.,...,.,.,,.,,
#6EIJT4RGPS5MGY7Y5YHD3UWGRBT4TLPEFVSH4OH3KWRHUNC7OZD2L576VFYUATXHTJXOKFYFKVQ42
#\\\|XV6O7J5DPKUO6AIJUBLWS2AK53SRQBVVOUUZTJKVYNT3NCM3ARX \ / AMOS7 \ YOURUM ::
#\[7]YG2A5RE6F5GSR5NQAVXLDWNCSFYTDJRCLVYAZQBHPKH3EWFKFOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
