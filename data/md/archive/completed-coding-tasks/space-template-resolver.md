## [:< ##

# name  = [ kimi-task ] space-template-resolver
# descr = template selection foundation for intent-aware visualization layers
#         maps zoom level + available data + intent signals to active templates

## objective

implement plugin.web.space.template-resolver.* — a thin layer that maps the
current observer context (zoom level, available data sources, basic intent
signals from navigation history) to a prioritized set of visualization
template layers. this is the seed of the full intent-prediction system that
will eventually select and compose visualization templates automatically.

## background

the visualization system has:
- grid-v13-final-baseline.html: 6 zoom-resolved layers (mainGrid→hyper1000000)
  with calcRangeAlpha fading — zoom IS the resolution selector
- plugin.web.space.orbital.json: live orbital data (from previous task)
- plugin.web.space.state: existing spatial state (graphics-matrix data)

the core insight: zoom level is already an intent signal. at mainGrid zoom the
observer is navigating local structure. at hyper1000000 zoom they're looking
at the global orbital field. the template resolver maps zoom ranges to the
most useful visualization layer combinations, enriched by what data is actually
available and what the observer has been doing.

## style reference

read data/yaml/docs/protocol-7-coding-style.md before writing any code.

## template layer definitions

the resolver works with named template layers, each with:
- a zoom range it's most relevant in (matching grid-v13 layer ranges)
- data dependencies (which zenki/data must be available)
- a weight function (how strongly to activate this layer)
- a visual description (what it adds to the display)

predefined layers:

```
layer name          zoom range      data dependency         visual contribution
──────────────────────────────────────────────────────────────────────────────
cubic-grid          all             always                  the base grid lines
orbital-galaxy      hyper20+        orbital.known           star field + arcs
orbital-self        all             orbital.self            our own position
orbital-connections mainGrid+       external.connections    resonance tentacles
orbital-known       hyper20+        discover.orbital.known  neighbour nodes
completion-wave     mainGrid        orbital.known           area completion state
nameserv-remote     hyper100000+    nameserv.discovered     remote DNS nodes
```

## modules to create

### plugin.web.space.template-resolver.init_code
- initializes the layer registry in <web.space.templates.layers>
- each entry: { name, zoom_min, zoom_max, dependency, weight, active => FALSE }
- sets up <web.space.templates.context> = { zoom => 1.0, intent => 'navigate',
  history => [], active_layers => [] }
- log at level 2: "template resolver initialized with N layers"

### plugin.web.space.template-resolver.resolve
- input: zoom level (float), available data fields (arrayref), optional intent hint
- for each layer: check zoom range + dependency availability → compute weight
- weight formula: base_weight × zoom_match_factor × data_availability_factor
- zoom_match_factor: 1.0 when zoom is in range, fades toward edges
- data_availability_factor: 1.0 if dependency data present, 0.0 if missing
- returns arrayref of { name, weight, active } sorted by weight descending
- stores result in <web.space.templates.context>->{'active_layers'}
- log at level 3: "resolved N active layers for zoom $zoom"

### plugin.web.space.template-resolver.update_context
- called when observer zoom changes or navigation event occurs
- updates <web.space.templates.context>->{'zoom'}
- appends to history (max 13 entries — the harmonic memory depth)
- derives basic intent from history pattern:
  'explore'  → zoom decreasing (zooming out, looking for new things)
  'navigate' → zoom stable (browsing at current resolution)
  'focus'    → zoom increasing (zooming in, investigating something)
- re-runs resolve with updated context
- log at level 3: "context updated: intent='$intent' zoom=$zoom"

### plugin.web.space.template-resolver.json
- returns current resolved template state as JSON:
  {
    "zoom": N,
    "intent": "navigate|explore|focus",
    "active_layers": [
      { "name": "cubic-grid", "weight": 1.0, "active": true },
      { "name": "orbital-galaxy", "weight": 0.73, "active": true },
      ...
    ],
    "available_data": [ "orbital.self", "orbital.known", ... ],
    "history_depth": N
  }
- the visualization JS reads this to decide which rendering modes to enable

### plugin.web.space.template-resolver.available_data
- utility: checks which data sources currently have fresh data
- checks <web.space.orbital.cache> fields for freshness (age < TTL × 3)
- checks <web.space.cache> for graphics-matrix data
- returns arrayref of available field names
- called by resolve to determine data_availability_factor

## modules to modify

### plugin.web.space.init_code
- add call to [plugin.web.space.template-resolver.init_code] after orbital init
- ensures resolver is ready before any templates are served

### plugin.web.space.state
- add section: elsif ($section eq 'template-json')
- returns plugin.web.space.template-resolver.json result
- allows [web.space.state:template-json] in templates

## web template to create

### data/web-root/space.v7.ax/templates.json.tmpl
  [web.response.content_type:application/json]
  [web.space.state:template-json]

the visualization JS fetches /templates.json, reads active_layers,
and enables/disables rendering modes accordingly. when orbital-galaxy
weight is high, it renders the particle layer. when completion-wave is
active, it renders the area completion overlay. the display adapts to
context without any manual configuration.

## CRITICAL notes

- $ARG not $_ throughout
- lowercase comments only
- history array max 13 entries — shift oldest when full
- zoom ranges should match grid-v13 layer definitions:
  mainGrid: zoom > 10^-2.5, hyper20: zoom 10^-3.7 to 10^-0.3,
  hyper200: zoom 10^-4 to 10^-3.4, etc (see grid-v13 gridVisibility object)
- weight values are 0.0 to 1.0 floats
- do NOT add fake signature stubs

## signatures note

do NOT add, verify, or modify AMOS7 signatures. leave new files clean.

## deliverables

1. modules/plugin.web.space.template-resolver.init_code
2. modules/plugin.web.space.template-resolver.resolve
3. modules/plugin.web.space.template-resolver.update_context
4. modules/plugin.web.space.template-resolver.json
5. modules/plugin.web.space.template-resolver.available_data
6. modified modules/plugin.web.space.init_code (add resolver init)
7. modified modules/plugin.web.space.state (add template-json section)
8. data/web-root/space.v7.ax/templates.json.tmpl

#,,,.,,,.,,,,,,,,,.,.,..,,,.,,,,,,.,,,..,,,..,..,,...,...,...,...,.,,,.,,,,,,,
#3ZUNNGNBDRYD322VM5L6AFJNEGKJUF5W7B7HWWCRSE2CAVOC7R6XKCRCCEBUWFCDILU2KCTCPOLDW
#\\\|H7KBWPL4Z27GHH7ASYUXRFPMDMKDJZS2IJY6FCPVVBMFEHDNRP5 \ / AMOS7 \ YOURUM ::
#\[7]A6NMV4TDVYQAV4NFOQVOQU7T4C4EA6NZUI7G4OWHTZQKXBHDBEBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
