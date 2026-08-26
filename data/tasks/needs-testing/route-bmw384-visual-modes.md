## [:< ##

# name  = task: implement BMW384 iris visualization modes
# descr = extend route.bmw384.visual.wheel with arc-width, density, gaussian
#         highlight, namespace overlay, and metric-driven proportional modes

## background

the current iris renders uniform rings and equal arc segments. this task adds
visualization modes that reveal the actual data distribution — arc widths
proportional to node counts, ring thickness by density, gaussian glow around
selected arcs, and namespace overlay rendering.

all modes share the same coordinate → SVG pipeline. they are controlled by
<route.bmw384.cfg.visual_mode> and additional per-mode config params.

## read first

- src/route.bmw384.visual.wheel  — current implementation
- src/route.bmw384.cmd.visual-wheel  — command handler

## mode 1: arc-width distribution [ visual_mode = 'arc-width' ]

instead of 26 equal arc segments, each arc's angular width is proportional
to its node count. arc H (170 nodes) gets the most degrees, sparse arcs
get fewer. total still sums to 360°.

implementation:
  1. compute node count per arc: @arc_counts[0..25]
  2. total = sum of all counts
  3. arc_deg[i] = ( arc_counts[i] / total ) * 360
  4. arc_start_deg[i] = sum of arc_deg[0..i-1]
  5. draw spokes at arc boundaries, labels centered in each arc
  6. node angular position within its arc: same fractional offset as before
     but scaled to the arc's actual angular width

add: <route.bmw384.cfg.arc_min_deg> = 2  [ minimum degrees per arc, prevents
invisible arcs — redistribute excess proportionally ]

## mode 2: density rings [ visual_mode = 'density' ]

ring thickness proportional to node density at that coordinate depth.
instead of uniform ring_radius_step, each ring's thickness is:
  ring_thickness[i] = base_thickness * ( nodes_in_ring[i] / max_nodes_per_ring )

for the signature-indexed disc, all rings have the same nodes (same 3873 plotted
per ring) — so density mode is more useful when rings represent different datasets
or namespaces. implement as: ring thickness = node count at that color band.

divide color space into $rings equal bands; count nodes per band;
render each band as a filled annulus of proportional thickness.

## mode 3: gaussian arc highlight [ visual_mode = 'gauss' ]

select one or more arc labels (e.g. 'D' or 'D,H,X') and render a gaussian
glow spreading from those arcs across the wheel. nodes near the selected arc
are brighter/larger, nodes far away fade.

params:
  <route.bmw384.cfg.gauss_arcs>   = 'D'      [ comma-separated arc labels ]
  <route.bmw384.cfg.gauss_sigma>  = 3         [ sigma in arc units, default 3 ]
  <route.bmw384.cfg.gauss_boost>  = 2.0       [ max brightness multiplier ]

for each node: compute arc distance to nearest selected arc (min circular
distance in arc units 0..13). gaussian weight = exp( -dist² / (2*sigma²) ).
node opacity = base_opacity * ( 1 + (gauss_boost-1) * weight )
node radius  = base_r * ( 1 + 0.5 * weight )

## mode 4: namespace overlay [ visual_mode = 'overlay' ]

render multiple namespace filters as separate translucent layers, each a
different base hue tint, stacked on the same wheel.

params:
  <route.bmw384.cfg.overlay_namespaces> = 'base,kimi,jobsite,route'

for each namespace prefix:
  - filter nodes whose name starts with that prefix
  - assign a fixed hue shift per namespace (evenly spaced: 0°, 90°, 180°, 270°)
  - render as a separate pass with opacity 0.4
  - label each namespace in a legend at the bottom of the SVG

the interference pattern between namespace distributions becomes visible as
color mixing where multiple namespaces share coordinate regions.

## mode 5: metric rings [ visual_mode = 'metric' ]

ring thickness and color driven by a computed metric rather than ring index.
each ring represents a different metric dimension of the same nodes:

  ring 0: color = content BMW384 (from signature footer)
  ring 1: color = name BMW384 (from dot-path string)
  ring 2: color = parent namespace BMW384 (strip last .element)
  ring 3: color = grandparent namespace BMW384

nodes where content and name coordinates agree (same arc) glow brighter.
nodes where they diverge are dimmer. this makes naming coherence visible.

compute name_coord via <[base.chk-sum.bmw384.coordinate]>->( $name )
compare arc with stored arc from index.

## mode 6: heatmap [ visual_mode = 'heatmap' ]

no individual node dots — instead render each arc×ring cell as a filled
rectangle whose color encodes node density:
  - black = 0 nodes
  - cool blue = 1-5 nodes
  - green = 6-15 nodes
  - yellow = 16-30 nodes
  - red = 30+ nodes

produces a clean density heatmap of the field topology without visual clutter.
useful for seeing structural patterns at a glance.

## cmd.visual-wheel changes

extend argument parsing:
  p7c index.visual-wheel file 26 arc-width
  p7c index.visual-wheel file 13 gauss D,H
  p7c index.visual-wheel html 1 overlay base,kimi,jobsite
  p7c index.visual-wheel file 26 heatmap

parse: mode name after ring count, additional mode params after mode name.
set <route.bmw384.cfg.visual_mode> and mode-specific params before render call.

## new module to create

### src/route.bmw384.visual.wheel-mode

dispatcher: reads <route.bmw384.cfg.visual_mode> and calls the appropriate
render variant. default ('ring') calls the existing wheel module unchanged.

  my $mode = <route.bmw384.cfg.visual_mode> // 'ring';
  if    ( $mode eq 'arc-width' ) { return <[route.bmw384.visual.wheel.arc-width]> }
  elsif ( $mode eq 'density'   ) { return <[route.bmw384.visual.wheel.density]>   }
  elsif ( $mode eq 'gauss'     ) { return <[route.bmw384.visual.wheel.gauss]>     }
  elsif ( $mode eq 'overlay'   ) { return <[route.bmw384.visual.wheel.overlay]>   }
  elsif ( $mode eq 'metric'    ) { return <[route.bmw384.visual.wheel.metric]>    }
  elsif ( $mode eq 'heatmap'   ) { return <[route.bmw384.visual.wheel.heatmap]>   }
  else                           { return <[route.bmw384.visual.wheel]>            }

each mode is its own module, sharing the same header (params, index read,
PI, segment_deg, segment_width) via copy — do not try to share a common
header module, just duplicate the 15-line setup in each.

## priority

implement in this order (simplest first):
1. gauss  — single-pass modification of existing wheel, easiest
2. heatmap — no per-node rendering, clean new approach
3. arc-width — requires arc boundary recalculation
4. overlay — multiple render passes
5. metric — requires coordinate recomputation per node
6. density — useful mainly with multiple datasets

## notes on signatures

- new files: leave clean, no stub footer
- existing modules: signing system re-signs on commit

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas in zenka modules

#,,,.,,..,,.,,,,.,..,,...,,,.,,..,...,.,,,...,..,,...,..,,,.,,.,,,,.,,,.,,.,.,
#HIB6CYAESUPQPQETYH4XW3F3TE4PLTUNP5TNAMQRTTDIW6WN3QCV63Y3BRDONHFQC6IDQKOYWSTUO
#\\\|SHLN2KCEMUXK2KBOGDM5JX2UQHFOK7HFP5WLR4543SO6WTTSPRP \ / AMOS7 \ YOURUM ::
#\[7]CDCTGQ6LKNVFEIWW5NWXICKMEXF4NVQEML23ULEX5SL57ZQINUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
