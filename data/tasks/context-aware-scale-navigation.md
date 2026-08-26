# task: context-aware scale navigation

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

the click-snaps-to-scale-layer model here is the **graphical
counterpart** of the console fold/unfold primitive from
`data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`. zoom-out folds a
sub-tree into its parent scale's representation; zoom-in unfolds it.
the three-layer abstraction model (space / proximity grouping /
frame-code) at the bottom of this file is the same recursion the
philosophy describes as "branch node = complete tree" — every scale
contains the same kinds of elements.

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

## three-layer abstraction model

interaction depth mirrors abstraction depth — click speed and target encode
which layer you want to work at, no mode buttons needed:

  space / content    — base reality, what things are, data values
  proximity grouping — first abstraction, spatial relationship, the grid
  frame / code       — second abstraction, explicit structure, connections

### click semantics across layers

- single click in space/content → interact with content directly (move, select)
- single click on frame edge    → select that frame, enter frame-interaction mode
- double click on frame         → switch to frame-structure mode: connections,
                                   dependencies, what the frame is bound to
- single click into content area inside frame → offer content selection first
- fast second click or double   → exit frame mode, back to space interaction

content is part of space. frame is abstraction from it. you never choose a mode
from a menu — click target + click speed encode the abstraction level.

### mapping to P7 topology

- space/content       → data values in the namespace tree, zenka state
- proximity grouping  → zenka neighborhoods, orbital shells, grid layers
- frame/code          → module definitions, zenka start files, the code
                        that shapes behavior

double-clicking into a zenka's orbital shell inspects its code/connections.
single-clicking back out returns to the data space it operates on.
a module IS a callable region of the namespace — the frame around behavior.

### touch equivalents

- tap            = single click
- double-tap     = double click (enter frame-structure mode)
- tap-hold       = reserved for context menu / long-press actions
- drag from frame edge = move/resize frame structure

## assignee

claude (JS/HTML work) — once grid has more functional distinction between layers,
extend to include grid-layer drag coupling. touch events can be wired in the
same pass as the click resolver.

#,,..,..,,,..,,.,,.,,,,,.,,,.,..,,,.,,,,,,.,.,..,,...,...,..,,.,.,..,,.,,,.,.,
#ZNYJLSVMI4CIJAOFPRDBZZFVGZBLZXXLGJSONAEJGDV44DZYTWWBSPJRU6HS62XD5FZCOC6TT34HS
#\\\|FLCNHTBXBYEWF4WNE45I3T3EMVALYRH3XNVFOAK7PS4ROSOP7GX \ / AMOS7 \ YOURUM ::
#\[7]O7NOS6X7N73FHCPCP6X4QFEQDU5GKW6N3VWMMHRMFNVCRHLXWUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
