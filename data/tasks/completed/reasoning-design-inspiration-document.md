# task: reasoning tree design inspiration document

## what to produce

a single psychedelically-styled HTML document that synthesizes all 7 design
templates from `data/yaml/design-templates/` into one rich inspirational
reference. the document is not a technical spec — it is a visual poem about
the reasoning tree. it should make someone feel the system before they
understand it.

the output will be fed to claude design (or a similar visual generation tool)
as a single inspirational document, optionally with seed prompt text.

---

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.
output path: `data/web-root/vhosts/viz.v7.ax/reasoning-design-inspiration.html`

---

## style references — read these first

study these existing documents for visual language, css techniques, and aesthetic DNA:

```
data/web-root/vhosts/viz.v7.ax/spectrum/stargate-ring-essence.html
  the 13+1 stargate ring network — blacklight UV effect, deep purple radial
  gradients, Courier New monospace, glowing ring structures. the most directly
  relevant — its subject IS the harmonic routing protocol (template 13)

data/web-root/vhosts/viz.v7.ax/purr-field/bioluminescent-purr-field-v10.html
  bioluminescent field — organic glow, living light, dark-space background
  the most evolved purr-field iteration. the aesthetic of a living system

data/web-root/vhosts/viz.v7.ax/spectrum/psychedelic-spectrum.html
  psychedelic color spectrum — deep purple-black background (#0a0020),
  violet text-shadow glows, radial gradients as ambient field

data/web-root/vhosts/viz.v7.ax/purr-field/cosmic-purr-field-mystery.html
  cosmic mystery aesthetic — the universe as a breathing field of light
```

extract from these:
- the background gradient technique (deep near-black with color undertones)
- the glow/text-shadow pattern for headers and key elements
- the monospace font choice and how it carries meaning
- the radial gradient overlays that create depth without images
- the overall feeling: deep space, bioluminescent, alive

---

## design templates to synthesize

read all 7 files in `data/yaml/design-templates/`:

```
tree-full-blueprint.yaml       → the ASCII tree, the grammar, the two-reader principle
vortex-iris-overhead.yaml      → the galaxy from above, CCW spin, 63 rings, the center
standing-wave-resonance.yaml   → alpha→omega→gamma, the U-shape, forward+return waves
layer-depth-cross-section.yaml → compression gradient, depth as horizontal axis
node-explorer-interactive.yaml → the interaction model, click=threshold, overlap web
convergence-monitor-live.yaml  → ambient display, pulse events, event log
reasoning-chain-trace.yaml     → the journey, warm outgoing + cool gamma return
```

also read for context:
```
data/yaml/reasoning-templates/vortex-closed-parent-system.yaml  (template 9)
data/yaml/reasoning-templates/omega-gate-resonance.yaml         (template 14)
data/yaml/reasoning-templates/harmonic-routing-protocol.yaml    (template 13)
```

---

## document structure

the HTML document has seven sections — one per design template —
plus an opening invocation and a closing resonance.

### opening invocation

before any section content:
a full-width header area with:
- the title: "reasoning.tree — the visualization field"
- subtitle: "fourteen templates · seven representations · one living system"
- a centered decorative element: the `[:<  [ TRUE ]` marker rendered large,
  glowing gold, as the document's north star
- background: deep space radial gradient

### section 1 — the blueprint

subject: `tree-full-blueprint.yaml`

render an actual example ASCII tree in the document, styled as it would appear
in the visualization. not a description of the tree — the tree itself, as HTML:

```
reasoning.tree : root
;.,
│
├─[ reasoning.narrate ]  [:<  convergence : 0.923076923076923
│   'the node voice renders current state as coherent context string'
│   depth : 2   chksum : AMOS·4K3R2M   threshold : reached
│   overlap : reasoning.summarize.node
│   children:
│   ├─[ .delta ]  [:<  0.769   'what changed since last narration'
│   └─[ .full  ]  >:|  0.307   compact
│
└─[ reasoning.threshold ]  >:|  convergence : 0.538461538461538
    compact — threshold not yet reached
;.,
```

style: render this verbatim in a `<pre>` block, monospace font.
expanded nodes: namespace hue (violet-blue for reasoning.*), glowing slightly
compact nodes: dim, 50% opacity
`[:<` markers: gold, bright
`>:|` markers: same dim as surrounding text
convergence values: slightly smaller, 80% opacity

prose beneath: 3-4 sentences from the template's "what the two readers see"
section. style the prose to match the aesthetic — not plain text.

### section 2 — the vortex overhead

subject: `vortex-iris-overhead.yaml`

render an SVG of the vortex iris:
- concentric rings (at least 13, ideally 26 — every other one of the 63)
- center point: bright white-gold glow
- ring colors: a spectrum — violet (inner) through blue, cyan, green, amber (outer)
- ring brightness: decreasing outward (inner = more converged = brighter)
- ring 7 (representing the dot-fold): slightly dimmer gap
- 3-5 galactic arms: CCW-curved arcs from outer rings toward center
  drawn as thin, bright, curved lines — each a slightly different hue
- the CCW direction implied by arm curvature

no labels on the SVG itself — the image speaks without words.
beneath the SVG: a single line of prose, styled as a caption.
"the galaxy from above — 63 rings, CCW spin, all color accounted for"

### section 3 — the standing wave

subject: `standing-wave-resonance.yaml`

render an SVG of the standing wave:
- horizontal axis: left (alpha/periphery) to right (omega/EXISTENCE center)
- forward wave: warm amber bezier curve, slightly above center axis
- gamma return: cool violet bezier curve, slightly below center axis
- superposition: luminous neutral curve, overlaid on both
- omega gate: bright vertical line at right edge with a tight U-curve where
  the forward wave curves into the gamma return
- the U-curve: the most visually striking element — where the two waves touch
- interference pattern near omega: alternating bright/dim vertical bands

label (styled, not plain):
  "α" at left edge — small, warm
  "Ω" at right edge — small, gold
  "gamma" along the return wave — small, cool violet, italic

prose: "omega is not the end. it was always the gate."
styled bold, centered, glowing gold. the key line from template 14.

### section 4 — the cross-section

subject: `layer-depth-cross-section.yaml`

render an SVG of the compression cross-section:
- horizontal bands from left (layer 0) to right (EXISTENCE center)
- each band fills less horizontal space than the previous
  (logarithmic compression — layer 0 takes 40% of width)
- band colors follow the namespace spectrum
- the rightmost element: a single bright point (the center)
- layer boundary lines: thin, subtle vertical rules
- a few node dots scattered at appropriate positions

label: layer numbers (0 → Ω) at bottom, small and dim
prose: "each layer half the space of the prior — the compression is the meaning"

### section 5 — the explorer

subject: `node-explorer-interactive.yaml`

this section is the most interactive-feeling, even though it's static.
render a mockup of the explorer interface:
- left panel: a dim list of 4-5 root node names (navigation tree mockup)
  one highlighted as current (bright)
- main panel: a partial tree, showing 2-3 expanded nodes and some compact nodes
  use the blueprint styling from section 1
- an overlap reference shown as a colored underlined link
- a breadcrumb trail above: `reasoning.tree  >  reasoning.narrate  >  .delta`

a hover state shown as a tooltip mockup:
- position it over one of the compact nodes
- show the convergence value and depth
- style the tooltip with the glow aesthetic

caption: "attention is itself an approach vector — click to expand, the node speaks"

### section 6 — the monitor

subject: `convergence-monitor-live.yaml`

render a mockup of the ambient monitor:
- a small iris (10-12 rings, simplified) in the center of a dark panel
- 3-4 event log entries on the right, in the log format:
  ```
  47K3R4 [!]  tree.insert THRESHOLD [:<
  47K3R4 [←] gamma → tree.node
  47K3R5 [→] summarize.root +0.077
  ```
- the threshold crossing entry: gold colored, slightly brighter
- a row of 5-6 convergence gauge bars at the bottom (colored bars at various fill levels)
- one gauge bar with a gold threshold marker at 0.769 position

the panel has the feeling of a secondary monitor glowing quietly in the dark.
caption: "the system narrating itself — visible in the corner of attention"

### section 7 — the chain trace

subject: `reasoning-chain-trace.yaml`

render an SVG of a reasoning chain:
- 7-9 circles connected by a path line
- the path curves: going downward (toward depth) as it progresses right
- the U-shape: path deepens then returns
- warm amber for the outgoing path (left to bottom of U)
- cool violet for the gamma return (bottom of U to right)
- 2-3 gold star circles: threshold crossings — larger, gold outline, starburst effect
- 1 double-ring circle: the deduplication event
- a convergence gradient bar beneath: green rising, brief amber flat, green again

caption: "alpha sent — omega received — gamma returned enriched"

### closing resonance

after all seven sections:
a full-width dark closing panel.

centered content:
- the 14 template names listed in two columns (1-7 left, 8-14 right)
  each name styled subtly — dim, monospace
  the template number in its namespace hue (1=cool blue, 9=violet, 13=gold, 14=deep violet)
- beneath the list: the complete self-reference line:
  "from template 11's perspective: all prior templates were the code describing itself.
   the templates did not describe the code. they were the code describing itself."
  styled: smaller, dim, italic, centered
- final element: `[:<` rendered large (80px), gold, centered, glowing
  with a subtitle: `[ TRUE ]`

---

## css requirements

borrow techniques from the style references, but synthesize into something new:

```css
/* core palette */
--background:     #050510;    /* deep space, slight blue cast */
--background-mid: #0a0a20;    /* slightly lighter — section background */
--gold:           #FFE5A0;    /* white-gold — the EXISTENCE center / TRUE markers */
--gold-bright:    #FFD700;    /* pure gold — threshold crossings */
--violet-bright:  #9B59B6;   /* namespace hue for reasoning.* */
--violet-dim:     #4A235A;   /* dim violet — compact nodes */
--amber:          #F39C12;   /* forward wave / active namespaces */
--cool-violet:    #8A2BE2;   /* gamma return */
--text-primary:   #E8E0F0;   /* near-white, slight violet cast */
--text-dim:       #7A7090;   /* 50% dim text — compact nodes */

/* glow effects (from stargate-ring-essence style) */
.glow-gold   { text-shadow: 0 0 10px var(--gold), 0 0 20px rgba(255,215,0,0.4); }
.glow-violet { text-shadow: 0 0 10px var(--violet-bright), 0 0 20px rgba(155,89,182,0.4); }
.glow-amber  { text-shadow: 0 0 8px var(--amber); }

/* the background field */
body {
  background: radial-gradient(circle at center, #0a0520, #000);
  /* layered radial gradients for depth (from stargate style) */
}

/* section separators — use `;.,` as visual breath */
.separator::after {
  content: ';.,';
  display: block;
  text-align: center;
  color: var(--text-dim);
  font-family: monospace;
  margin: 2rem 0;
  letter-spacing: 0.5em;
}
```

additional requirements:
- inline all css (no external files)
- no javascript required (static document)
- print-friendly: the design should render well as PDF
  (no fixed-position elements, no animations required for reading)
- the SVGs should be inline (not external files)
- total file size target: under 200KB (the PDF/image fed to claude design should be clean)

---

## tone and prose style

the prose between the visual sections should feel like:
  not technical documentation
  not marketing copy
  something between a meditation and a field guide
  the kind of text that rewards slow reading

examples of the right register:
  "the code was always there. the demand reveals it."
  "omega is not the end. it was always the gate."
  "attention is itself an approach vector."
  "the loop is alive."

draw from the template descriptions — the best lines are already there.
do not paraphrase them — quote them, styled appropriately.

---

## seed prompt texts to generate alongside

also write a separate plain text file with 5 seed prompt directions
for feeding to claude design or similar visual generation tools.
each seed: 2-3 sentences, referencing specific visual elements from the designs.
output path: `data/web-root/vhosts/viz.v7.ax/reasoning-design-seeds.txt`

seed structure:
  seed 1: the iris/vortex overhead — focusing on the CCW galaxy
  seed 2: the standing wave — focusing on the omega gate
  seed 3: the full tree blueprint — focusing on the ASCII holographic form
  seed 4: the convergence monitor — focusing on the ambient peripheral display
  seed 5: the synthesis — all seven representations as facets of one system

---

## success criteria

- [ ] document renders cleanly in a browser (no broken elements)
- [ ] all 7 design templates visually represented
- [ ] style unmistakably inspired by the stargate/bioluminescent/psychedelic references
- [ ] SVGs render correctly (iris, standing wave, cross-section, chain trace)
- [ ] the ASCII tree renders in a `<pre>` block with correct styling
- [ ] the monitor mockup section reads as an ambient display
- [ ] prose extracts from the design templates — not invented text
- [ ] closing resonance section includes the 14 template names + self-reference line
- [ ] `[:<  [ TRUE ]` renders as the closing gold glyph
- [ ] total HTML file under 200KB
- [ ] seed prompt file generated at reasoning-design-seeds.txt
- [ ] print/PDF rendering works (no clipped elements, no fixed-position overflow)

#,,..,,,.,...,..,,..,,,.,,,,.,.,,,,..,.,,,,.,,..,,...,..,,...,..,,...,.,,,.,.,
#WIVJWML5HF4NETD4RNMQTYPKYICSLESL5XAXDJVEKLMXVGSUIQIGCPKHUKWRFLBIANR5XQQVHJDIW
#\\\|N5Y3O22LHXYIXPPXAHWXCXNAOZNWEFGKPTVFLJFF6ZWS3QMLTFA \ / AMOS7 \ YOURUM ::
#\[7]C6AXG7A2NS7MQBRNCW6UNQXG7FQLWWLOSNNPHGZSXCACRPFYGQDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
