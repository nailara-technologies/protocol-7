# task: context-aware scale navigation

## concept

unify all navigation into one interaction primitive: click (or tap).
the geometry already knows what scale layer the pointer is near.
the click resolver asks "nearest logical scale boundary in this direction?"
and jumps there with zoomTargetZoom — magnetic snapping to coherent scale levels.

mousewheel / pinch-zoom remain as fine-grained override between layers.
dragging becomes context-coupled: which layer the pointer is near determines
what the drag operates on.

this makes the visualization work identically on mouse, touch, and tablet —
one basic interaction mode, geometry does the navigation logic.

## scale layers already defined

gridVisibility ranges in visualization.html define the natural snap targets:

  mainGrid:     rangeStart: -2.5, rangeEnd: 0.7777
  hyper20:      rangeStart:  0.3, rangeEnd:  3.70
  hyper200:     rangeStart:  3.4, rangeEnd:  4.00
  hyper10000:   rangeStart:  4.1, rangeEnd:  5.77
  hyper100000:  rangeStart:    5, rangeEnd:  7.77
  hyper1000000: rangeStart:    7, rangeEnd: 13.5

canonical snap zoom values = midpoint of each rangeStart/rangeEnd.
click resolver finds current manualZoom position in this sequence
and snaps to next layer inward or outward depending on context.

## click behavior (target state)

- **click on orbital node/sphere** → zoom to orbital scale centered on that node
  (already partially implemented via double-click)

- **click on free space, pointer near grid structure** → snap to next coarser
  scale layer (zoom out one step in the gridVisibility sequence)

- **click on free space, pointer far from grid** → snap to next finer scale layer
  (zoom in one step)

- **click while at finest scale (mainGrid)** → no-op or enter sub-cube inspection

- **click while at coarsest scale (hyper1000000)** → no-op or zoom to overview

the direction decision (in vs out) uses proximity to rendered geometry:
if pointer is over/near a visible element → zoom in toward it
if pointer is in empty space → zoom out to next overview layer

## drag behavior (target state)

drag context is determined at drag-start by what the pointer is over:

- **drag over orbital node area** → couple to orbital layer: rotate orbital
  sphere, reposition node relative to self
- **drag over grid structure** → couple to grid layer: translate camera along
  grid plane
- **drag in empty space** → rotate view (current behavior, keep as fallback)

## snap animation

use existing zoomTargetZoom mechanism:
  zoomTargetZoom = snap_zoom_value
  manualZoom += (zoomTargetZoom - manualZoom) * CURVES.ZOOM_KICK  (initial kick)

feels like magnetic gravity toward coherent scale levels.
mousewheel clears zoomTargetZoom immediately (already implemented this session).

## touch / mobile benefit

- one-finger tap = click (full navigation model)
- two-finger pinch = mousewheel fine-tune (already works)
- one-finger drag = context-coupled drag (orbital / grid / rotate)
- no need for double-tap, long-press, or mode buttons
- small screen precision compensated by magnetic snap geometry

## implementation notes

- click resolver: check `manualZoom` against gridVisibility sequence →
  find current layer → determine next layer in context direction
- proximity check: raycast or simple distance to nearest projected grid node
  vs nearest projected orbital node vs empty space threshold
- snap values: precompute as array of midpoints from gridVisibility ranges
- existing zoomTargetZoom/ZOOM_KICK/ZOOM_TARGET_ZOOM curve already handles
  the animation correctly
- clear zoomTargetZoom on mousewheel (already done) preserves fine-tune override

## files

- data/web-root/vhosts/space.v7.ax/visualization.html
  - gridVisibility (already defined, ~line 698)
  - zoomTargetZoom mechanism (lines 746-753, 926-962)
  - canvas click handler (search: canvas.addEventListener.*click)
  - canvas mousedown/drag handler

## signatures note

do NOT add stub signature lines to new or modified files.

## assignee

claude (JS/HTML work) — once grid has more functional distinction between layers,
extend to include grid-layer drag coupling. touch events can be wired in the
same pass as the click resolver.

#,,.,,,,,,..,,,..,,..,...,,,.,.,,,.,,,..,,,,.,..,,...,..,,,..,,.,,,,,,.,.,...,
#LLL6IE2LQVFNVFBL6CWU76BVLY5UZTYVL3HUH4HFVBNTW2RSQBPBGEKWC22FM6PQQIXIOV2PA7UCO
#\\\|DY7WJAPAJXGW4D5A3ZGWJGQSKW3URQ7HGZJ6IEQTE4EZLAJCMJT \ / AMOS7 \ YOURUM ::
#\[7]HOKJ7AKOI2YRS5G43D3BABIXC5NEW2WK7C4Z5YT3Z5YDRZJOUCDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
