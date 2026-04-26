## [:< ##

# name  = [ kimi-task ] grid-v13-orbital-visualization
# descr = merge grid-v13 cubic grid with live orbital node rendering —
#         CCW orbital trails, resonance tentacles, template-driven layer activation

## objective

create a new HTML visualization file that merges:
1. grid-v13-final-baseline.html — the production cubic grid with 6 zoom-resolved
   layers and calcRangeAlpha fading
2. zenki-cosmic-suns.html — stellar rendering with trail system, glow, particles
3. live data from /orbital.json and /templates.json endpoints

the result goes to data/web-root/space.v7.ax/visualization.html and becomes
the main interactive visualization for space.v7.ax.

## source files to read first

- data/asc/what-AI-thinks/html-form/visualizations/cubic-space/production/grid-v13-final-baseline.html
  (1161 lines — the base grid, keep ALL existing grid rendering intact)
- data/asc/what-AI-thinks/html-form/visualizations/zenki-cosmos/zenki-cosmic-suns.html
  (has trail system, glow, starfield, fluorescent particles — lift these)
- data/asc/what-AI-thinks/html-form/visualizations/zenki-cosmos/zenki-unified-cosmos-v2.html
  (has particle dynamics, unified field rendering — reference for arc rendering)

## what to add to the grid

### 1. live data fetch loop
- fetch /orbital.json every 13 seconds (matches server-side update interval)
- fetch /templates.json every 7 seconds (faster for responsive layer switching)
- store in JS objects: orbitalData, templateData
- graceful fallback: if fetch fails, use last known data (don't break the grid)

### 2. orbital node rendering layer
activated when templateData.active_layers includes 'orbital-self' or 'orbital-known'
with weight > 0.1:

**self node** (our own orbital position):
- rendered as a bright blue sphere at the position derived from our P7REF
- theta/phi/psi/omega from orbitalData.self map to 3D coordinates:
  x = sin(phi) * cos(theta) * scale
  y = cos(phi) * scale
  z = sin(phi) * sin(theta) * scale
  (scale proportional to current zoom level)
- pulsing glow effect, blue/white color

**known nodes** (orbitalData.known array):
- same coordinate derivation from their p7ref ADDR_B32
- color by status:
  connected (in orbitalData.connections) → cyan glow
  discovered only → fluorescent green/yellow
  known but aged (age > 60s) → dim blue

### 3. CCW orbital trail system
the key new visual — translucent arcs showing orbital motion direction:

- each node maintains a position history buffer (configurable, default 13 entries)
- positions stored with timestamps
- rendered as arc: most recent = full opacity, oldest = near-transparent
- opacity formula: opacity = base_opacity * (1 - index/trail_length)^decay_power
- trail rendered CCW (matching the orbital model's CCW rotation)
- trail_length: configurable 3-42 entries (default 13 — harmonic depth)
- trail_decay: configurable 0.5-3.0 (default 1.5 — exponential falloff)
- overlap_range: how many seconds of history to show (default 42s)
- the arc direction makes orbital motion readable in a single frame
  (temporal branch compression — N frames of motion in 1 frame as opacity gradient)

### 4. resonance tentacles (connection layer)
activated when 'orbital-connections' layer weight > 0.1:

- for each entry in orbitalData.connections with status 'connected':
  draw a line from self position to the connected node's position
- encrypted connections: bright cyan line, animated dash pattern flowing toward target
- unencrypted: dimmer white line, static
- line opacity proportional to connection age (newer = brighter)
- subtle glow along the line (lift from zenki-cosmic-suns trail glow system)

### 5. template-driven layer visibility
read templateData.active_layers array:
- each layer has a weight 0.0-1.0
- use weight directly as the global alpha multiplier for that layer
- smooth transitions: lerp current weight toward target weight each frame
  (prevents jarring switches when template resolver updates)
- layers:
  'cubic-grid' weight → grid line opacity (always > 0, minimum 0.3)
  'orbital-galaxy' weight → starfield + arc trail opacity
  'orbital-self' weight → self node opacity
  'orbital-connections' weight → tentacle opacity
  'orbital-known' weight → known node opacity
  'completion-wave' weight → (reserved, skip for now)
  'nameserv-remote' weight → remote DNS nodes (dim, far from center)

### 6. zoom-context reporting
when user changes zoom level, POST to /context with:
  { zoom: currentZoom, intent: derived_intent }
derived_intent:
  zoom decreasing → 'explore'
  zoom stable (< 5% change) → 'navigate'
  zoom increasing → 'focus'
debounce: only post after 500ms of stable zoom (don't spam on scroll)

### 7. UI controls to add
add to the existing controls panel:
- Trail length slider: 3-42 (default 13)
- Trail decay slider: 0.5-3.0 (default 1.5)
- Overlap range: 13s / 42s / 133s
- Toggle: show orbital nodes (on by default)
- Toggle: show tentacles (on by default)
- Toggle: show trails (on by default)

## output file

data/web-root/space.v7.ax/visualization.html

this is a pure HTML/JS file — no P7 module conventions apply.
write clean modern JavaScript, no jQuery, use fetch() API.
the grid rendering code from grid-v13 must be preserved exactly.
add the orbital layer on top of it, not replacing any existing code.

## important rendering notes

- orbital nodes render AFTER the grid lines in each frame (nodes on top of grid)
- trails render BEFORE nodes (trails behind nodes)
- tentacles render BETWEEN trails and nodes
- use the existing project() function from grid-v13 for all 3D→2D projection
- orbital positions should be scaled to fit within the current grid's coordinate space
  (use the same coordinate system as the grid — not a separate space)
- at mainGrid zoom: nodes appear as small bright dots within the grid cells
- at hyper20+ zoom: nodes spread out, trails become visible arcs, galaxy emerges

## deliverables

1. data/web-root/space.v7.ax/visualization.html
   (complete merged visualization, self-contained, no external dependencies)
