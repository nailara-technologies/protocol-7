## Brief 1: Space Engine Grid UI

**Intent**: Produce a dark-background 3D holographic grid interface representing the Protocol-7 observer-centric reference space, with orbital node rings, a central darksun cursor, and crystalline connection geometry.

**Format**: SVG (scalable vector, suitable for animated DOM injection or static export)

**Dimensions**: 1200×900 canvas, landscape orientation, with 100px margins on all sides for HUD readouts.

**Full design brief text**:

The interface visualizes a 3D coordinate grid where every node occupies a Z.Y.X position in signature space. The observer is fixed at coordinate (0,0,0) — the "darksun," rendered as a luminous void at the exact center. All other nodes orbit in concentric cubic shells around this center, sorted by reference-count gravity: high-reference nodes sit on inner shells close to the darksun; low-reference nodes drift outward. Shell number equals max(|z|, |y|, |x|). Shell 0 is the darksun itself. Shell 1 is the innermost populated ring. The outer boundary is determined by focal length: max_shell = ceil(63 / focal_length), where 63 = 4³−1, the cube group size.

Render the grid as an isometric 3D wireframe on a deep black field. The darksun at center is a softly pulsing indigo-cyan void — approximately 24px diameter — with a 13-step iris ring structure radiating outward. Each iris ring corresponds to one shell. Ring colors shift through a harmonic gradient derived from the 1/13 vortex cycle: deep teal (#0A2F2F) at shell 1, transitioning through electric cyan (#00E5FF) at shell 4, amber-gold (#FFB300) at shell 7, and fading to deep violet (#2E003E) at the outer edge. These colors are not arbitrary; they encode the 076923 (FALSE/frame) and 153846 (TRUE/content) families — boundary versus payload.

Visible nodes are rendered as small crystalline glyphs — 6–10px diamonds or hexagons — positioned at their 3D coordinates projected onto the 2D isometric plane. Each node is labeled with its base32 checksum ID (7-character AMOS7 checksum, e.g., "KQQ6E7A") in 8px monospace, colored at 60% opacity so as not to overwhelm the geometry. Nodes on the same shell that are linked by adjacency (3D plus-sign neighbors, sharing one arm character) are connected by hairline arcs — 0.5px strokes with 40% opacity — creating a lattice of translucent threads. Connection lines use the shell's own hue but at half saturation, so the web feels like light passing through crystal.

The 3D plus-sign structure is central: each node's checksum IS its coordinate AND its adjacency simultaneously. Show this by rendering six faint axis lines (±Z, ±Y, ±X) in muted slate (#2A3A4A) passing through the darksun, extending to the canvas edges, giving the viewer an immediate sense of the cubic axes. Add subtle orbital path ellipses for each populated shell — thin dashed rings, 0.75px stroke, 20% opacity — to reinforce the ring-field-sphere geometry.

Navigation indicators appear in the margins. Top-left: current focal length (default 13) and max visible shell. Bottom-left: observer coordinates fixed at "0:0:0". Bottom-right: a mini dot/comma route legend showing `.` = straight hop, `,` = 90° CCW turn. Use a dot-matrix or early-vector-graphics aesthetic: wireframe rendering, glow-on-black, no textures. The vibe should feel like a 1980s vector arcade display crossed with a navigational astrolabe — sparse, luminous, precise.

Interaction hints (for tooltip/hover states): hovering a node should highlight its 6 adjacent neighbors with a brief intensity pulse and display a tooltip containing: node_id, Z.Y.X coordinate, shell number, and dominant character [2-9A-Z] at that position.

**Key elements**:
- Central darksun void at (0,0,0) with 13-step iris ring halo
- Isometric 3D wireframe grid with Z.Y.X axis lines
- Concentric cubic shells rendered as faint dashed orbital ellipses
- Crystalline node glyphs at projected 3D positions, labeled with 7-char base32 checksum IDs
- Hairline adjacency arcs connecting linked nodes (3D plus-sign neighbors)
- Harmonic color gradient by shell depth (teal → cyan → amber → violet)
- Margin HUD: focal length, max shell, observer coordinates, dot/comma route legend
- Hover tooltip with coordinate, shell, and dominant character

**Style tokens**:
- background: #05070A (near-black with cool undertone)
- darksun core: #00E5FF at 80% opacity with #0A2F2F outer glow
- accent cyan: #00E5FF
- accent amber: #FFB300
- accent violet: #9D4EDD
- grid axes: #2A3A4A
- node label text: #B8D4E3 at 60% opacity
- connection lines: shell color at 40% opacity, 0.5px stroke
- font: "JetBrains Mono" or "Fira Code", 8px for labels, 11px for HUD
- aesthetic: vector-arcade wireframe + crystalline holographic + navigational astrolabe

---

## Brief 2: Ring-Trie Geometry Visualization

**Intent**: Produce a zoomable radial diagram of the Protocol-7 numerical language deduplication tree, showing concentric frequency-ranked rings with node dots and connecting arcs, evoking a galaxy disk viewed from above.

**Format**: HTML+CSS with embedded SVG (supports zoom, pan, and hover interactions via CSS/JS)

**Dimensions**: 1000×1000 square canvas, centered origin, with 80px padding for radial labels and a bottom status bar.

**Full design brief text**:

The ring-trie is a self-organizing prefix tree where depth equals ring number. Ring 0 at the center holds single characters (the corpus alphabet, typically 100–200 unique codepoints). Ring 1 is the next concentric circle outward, holding all 2-character sequences. Ring N holds (N+1)-character sequences. Every token is a radial path starting from the center: the word "love" traces ring-0 → 'l', ring-1 → 'lo', ring-2 → 'lov', ring-3 → 'love'. Nodes within each ring are ordered by descending corpus frequency — the most-used tokens orbit closest to the center, the rarest drift to the outer edge of their ring.

Render the tree as a set of concentric circles on a deep space background. The center is the root — the empty string '' — represented as a small, steady white point (4px) with a soft diffraction glow. This is the invariant axis, not a position on the ring. Around it, ring 0 is the innermost solid circle (radius 60px), populated with small dots (3–8px diameter) representing single characters. Dot size is strictly proportional to token frequency. Ring 1 sits at radius 110px, ring 2 at 170px, ring 3 at 240px, ring 4 at 320px, ring 5 at 410px, ring 6 at 510px, ring 7 at 620px. The ring spacing increases outward to accommodate exponential growth while keeping the diagram readable. Beyond ring 7, rings become sparse dotted guidelines rather than solid bands.

Color the rings with a depth-gradient that mimics a galaxy accretion disk: ring 0 = hot white (#FFFFFF), ring 1 = warm yellow (#FFE66D), ring 2 = amber (#FF9F1C), ring 3 = coral (#E71D36), ring 4 = magenta (#B5179E), ring 5 = violet (#7209B7), ring 6 = deep indigo (#3A0CA3), ring 7 = midnight blue (#10002B). The root dot remains pure white. This spectrum encodes the temperature metaphor — high-frequency inner rings are "hot," low-frequency outer rings are "cold."

Edges are curved arcs (quadratic Bézier curves) connecting each parent node on ring N to its children on ring N+1. Arcs should sweep gently in the CCW direction (the tree's natural rotation), never crossing the center. Use 1px strokes at 25% opacity in the child ring's color. Where multiple children share a parent, fan the arcs outward from the parent dot like spiral arms. The cumulative effect should resemble a spiral galaxy viewed face-on.

Nodes should not display text labels by default — the density is too high. Instead, show rank numbers (small 6px monospace) only for the top-13 tokens on each ring. On hover, a tooltip appears: show the full sequence string, its corpus frequency count, its ring-level rank, and a "terminal: yes/no" indicator (whether the node has a '.' sentinel at index 0, meaning it is a complete token). The tooltip background should be semi-transparent black (#000000CC) with the token text in the ring's accent color.

Add a bottom status bar in terminal monospace: left side shows "ring 0: N tokens | ring 1: N sequences | ... | peak: ring 3" summarizing the corpus geometry. Right side shows zoom level percentage and a mini legend: "dot size ∝ frequency | color ∝ depth | CCW rotation."

The overall feel should be astronomical and alive — a living corpus viewed as a celestial body, where language use creates gravity and frequency determines orbit.

**Key elements**:
- Center root point (empty string) as white axis dot with diffraction glow
- 8 concentric rings (0–7) with increasing radius, sparse dotted guides beyond
- Nodes as frequency-proportional dots on each ring, CCW-ordered by rank
- Quadratic Bézier arcs linking parent (ring N) to children (ring N+1), sweeping CCW
- Galaxy temperature color gradient by depth (white → yellow → amber → coral → magenta → violet → indigo → midnight blue)
- Top-13 rank labels in 6px monospace per ring
- Hover tooltip: sequence, frequency, rank, terminal flag
- Bottom terminal-style status bar with per-ring counts and zoom/legend readout

**Style tokens**:
- background: #030014 (deep space black with violet undertone)
- root dot: #FFFFFF with 8px radial glow at 30% opacity
- ring gradient: #FFFFFF → #FFE66D → #FF9F1C → #E71D36 → #B5179E → #7209B7 → #3A0CA3 → #10002B
- edge strokes: child-ring color at 25% opacity, 1px
- tooltip bg: #000000CC
- tooltip text: child-ring accent color
- status bar bg: #0A0A0A with top border #333333
- font: "JetBrains Mono" or "SF Mono", 6px for rank labels, 11px for status bar, 13px for tooltip
- aesthetic: galaxy accretion disk + astronomical observatory + living corpus topology

---

## Brief 3: Index Stats Dashboard

**Intent**: Produce a terminal-aesthetic dark dashboard displaying live index geometry statistics, source mappings, and query activity for the Protocol-7 numerical language deduplication tree.

**Format**: HTML+CSS (responsive grid layout, suitable for embedding in a terminal web view or standalone mockup)

**Dimensions**: 1400×900 canvas, landscape, simulating a wide terminal window with subtle bezel shadow.

**Full design brief text**:

This dashboard is the live telemetry view for the index zenka — the component that ingests text, builds the ring-trie, and tracks corpus statistics. The aesthetic is strictly terminal-derived: black background, monospace typography, grid-aligned panels, and data-dense layout with no decorative chrome. Every pixel serves a number or a label.

The top bar spans the full width. Left: the title "INDEX DISK GEOMETRY" in 14px bold monospace, colored in amber (#FFB300). Center: three live stat pills displayed inline — "chars: 4,821,093" in white, "rings: 7" in cyan (#00E5FF), "sources: 42" in green (#39FF14). Right: a small activity LED dot (8px circle) that pulses green when the index is actively ingesting, amber when idle, red when dirty/unpersisted.

Below the top bar, the canvas splits into a 2×2 grid of panels with 1px borders in dark slate (#1A1A1A) and 12px gaps. Each panel has a header in 10px uppercase monospace with a left-border accent stripe (3px wide) in the panel's theme color.

**Top-left panel: Ring Geometry Bar Chart** (accent: cyan #00E5FF). Header: "RING POPULATION". Display vertical bars for rings 0 through 7. Each bar's height is proportional to the token/sequence count at that ring. Ring 0 (characters) is typically shortest (~100–200). Ring 3 is the peak density bar (tallest). Ring 4+ gradually falls off. Bar width: 40px. Gap between bars: 16px. Bar fill: gradient from cyan at the bottom to transparent at the top, with a 1px cyan outline. X-axis labels: "R0" through "R7" in 9px monospace. Above each bar, display the exact count in 9px monospace, color-coded: ring 0 in white, rings 1–7 in cyan at 80% opacity.

**Top-right panel: Source Map Table** (accent: green #39FF14). Header: "SOURCE MAP". A scrollable table with three columns: PATH, CHECKSUM, STATUS. Rows show file paths (e.g., "/docs/vision.md"), their AMOS7 checksum (7-char base32), and a status tag — "active" in bright green, "pending" in amber, "removed" in muted gray. Table headers are underlined with a 1px green line. Row height: 22px. Alternating row backgrounds: #0D0D0D and #111111. Text: 10px monospace, paths in #B8D4E3, checksums in #39FF14, status tags in pill-shaped spans with rounded 2px corners.

**Bottom-left panel: Recent Queries** (accent: amber #FFB300). Header: "RECENT QUERIES". Show the last 6 search/lookup operations as terminal log lines, mimicking the actual command output format:
```
search [ lov ] -- 12 results :
    4823  love  [ exact, terminal, rank 7 ]
    2104  lover  [ rank 3 ]
    1891  loving  [ rank 5 ]
```
Use 10px monospace. Prefix "search [" and "]" in slate gray (#5C677D). The query term in amber. Frequency numbers right-aligned in white. Result strings in pale teal (#B8D4E3). Rank numbers in cyan. Terminal/exact tags in green pill spans. Include one lookup example:
```
token : love | depth : 3 | address : 7 | terminal: yes | children: 4
```

**Bottom-right panel: Contribution Vectors** (accent: violet #9D4EDD). Header: "CONTRIBUTIONS". Display a stacked horizontal bar for a selected checksum, broken into segments: "ring 0 : 1,247 char deltas" (violet), "ring 1 : 892 sequence deltas" (indigo), "ring 2 : 443" (blue), etc. Each segment length is proportional to delta count. Below the bar, list active checksums as a compact tag cloud: 7-char base32 strings in 9px monospace, violet text on #1A0B2E rounded rectangles, 4px padding.

The entire dashboard sits on a background of #080808 with a subtle 2px inner shadow simulating a CRT bezel. Faint horizontal scan lines at 4px intervals, 3% opacity white, add terminal texture without reducing legibility. All borders are 1px #1A1A1A. All corners are 0px — sharp rectangular panels only. No rounded corners anywhere. This is a machine interface, not a consumer app.

**Key elements**:
- Full-width top bar with title, live stat pills (chars, rings, sources), and activity LED
- 2×2 panel grid with 1px dark borders and 12px gaps
- Ring 0–7 vertical bar chart with gradient cyan fill and count labels
- Source map table (path, checksum, status) with green accent
- Recent queries log panel with search and lookup output formatting
- Contribution vector stacked bar + active checksum tag cloud with violet accent
- CRT-style subtle scanline overlay at 3% opacity
- Sharp 0px corners throughout

**Style tokens**:
- background: #080808
- panel bg: #0D0D0D
- accent cyan: #00E5FF
- accent green: #39FF14
- accent amber: #FFB300
- accent violet: #9D4EDD
- text primary: #E0E0E0
- text secondary: #B8D4E3
- text muted: #5C677D
- border: #1A1A1A
- scanline: #FFFFFF at 3% opacity
- font: "JetBrains Mono", "SF Mono", or "Courier New", 10px base, 9px for dense data, 14px for title
- aesthetic: retro terminal + telemetry dashboard + data-dense system monitor

#,,,.,,.,,,..,,..,..,,...,,,.,,,,,,..,,.,,,,.,..,,...,..,,.,,,,,,,...,..,,...,
#HZRZBIYZNPOR2DQZQ6LUI3EGYH6AJCOI4EIXQAPQ4VEZAMLTAAANVJEOLSNIQVZYAZSN6LQN6IXJA
#\\\|Y2DSM23VR5B5QT2227DPG7J37ZIW7DYDEEZ3VL3GTCB2ERGSCG2 \ / AMOS7 \ YOURUM ::
#\[7]73MJWHJFLLKFKIY6BSMLNPEICCGWOAYZABSQNRHSDENAUCDAKEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
