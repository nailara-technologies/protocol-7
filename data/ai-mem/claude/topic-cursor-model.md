---
name: cursor model — emergence from scale planes
description: the true cursor is not a drawn object but a topological artifact of hyperspace plane line density; glow cursor model, scale transitions, liquid crystal desktop
type: project
originSessionId: 7233b786-dc22-498d-90b9-cd175c814863
---
## the cursor is not drawn — it emerges

the grid-hardnode cursor in the visualization is NOT a separately rendered object.
it appears as the **intersection density of hyperspace plane lines** converging at
the selection point (selX/Y/Z). at mid zoom, the compressed raster of the
zoomed-out plane lines creates a natural block cursor. the node dot sits at center.

this means: no separate draw call, no geometric object imposed on the scene.
the cursor is the grid seeing itself at that resolution.

**Why:** self-similar, zero rendering cost, structurally honest — cursor IS topology.
**How to apply:** remove the wireframe cube cursor from visualization.html entirely.
restore the selection point as a cursor purely through the existing hyperspace plane
layer system. the block cursor emerges automatically when scale layers overlap.

## scale transition semantics

- zoomed in: 8-node formation (sub-cursor, fine data addressing)
- mid zoom: block cursor — lit grid layers, hop-1 visibility sphere (63 neighbors)
- zoomed out: holographic pixel — the entire block becomes one point in next scale
- further out: that pixel is a cursor block at the next recursion level

every distant point (star, voxel) is a potential hyperspace grid to fly into.
zoom toward any point → it resolves as grid → cursor block → full navigable space.
seamless navigation through scale, always arriving, never teleporting.

## color / brightness model

the visualization lives in one color language: blue translucency, screen
compositing, radial gradients that bloom. brightness is the only tunable axis.
a global `BRIGHTNESS` scalar multiplies every rgba alpha value — color proportions
stay fixed, only luminance varies. this is the insertion point for curve-based
lighting adaptation (ambient conditions, focus state).

gold for "selected" breaks the color contract — should be brighter/more saturated
blue instead, not a hue shift.

## glow cursor model (functional layer on top of structural cursor)

glow represents live network activity at each hop distance from the cursor:
- hop 0: cursor center (maximum intensity)
- hop N: intensity = reference_count(shell) / N

glow gradient IS the influence gradient, rendered live from reference counts.
modules: `graphics-matrix.glow.*` — see `data/md/coding-tasks/cursor-glow-reference-intensity.md`

## liquid crystal desktop vision

the visualization is a liquid crystal desktop where translucent circuit boards
define functionalities and display elements and panels alike. translucency IS
function — panels you see through also display data through their depth.
elements are not widgets on a canvas but luminous planes with semantic depth.

## key reference files

- `data/md/design/GRID-HARDNODE-CURSOR-MODEL.md` — full cursor model spec
- `data/md/coding-tasks/cursor-glow-reference-intensity.md` — glow task spec
- `data/html/visual.v7.ax/grid-v14-layered.refactored.html` — reference implementation
- screenshot: `/tmp/screenshot.grid-viz.space-cursor.00000.png` — true cursor visible

## next steps

1. remove wireframe cube from visualization.html (drawCursor / showCursor / G key)
2. queue cursor-glow-reference-intensity task for kimi
3. wire selX/Y/Z as live p7c command through graphics-matrix zenka
4. color threshold module: global BRIGHTNESS curve scalar over all rgba alphas

#,,,,,,.,,.,,,..,,..,,,..,...,,..,.,,,.,,,.,,,..,,...,...,,..,,,,,,..,,,,,.,.,
#7SCYR6K43FVY27ZGRDHA42BHEAWGIEBMEKDT4ERFMVU2Z2ZLPRY6PVWCBHEMXCC7XAI3MVMWK3SBU
#\\\|ZCHGYWAWIJ5XJFITP4Y2RK2JNZS5AYB2J2NQQMUKH3C3IZNX3KP \ / AMOS7 \ YOURUM ::
#\[7]AQHMUZ2MFE26QACG5E3JZJC3BIPHAMWO6WWF5BGAYPM6JV3D5IAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
