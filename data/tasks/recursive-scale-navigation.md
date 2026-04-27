# task: recursive scale navigation — double-click zoom into node void

## geometric foundation

the node group is 8 x (4x4x4) ambient cubes arranged in a 2x2x2 formation.
each cube has 1 missing corner subcube pointing toward the center (63 lit subcubes each).
each cube has a native 1-pixel boundary, so adjacent cubes sit 2px apart (1+1).
the missing corner adds 1px inward from each side → void per axis: 2+1+1 = 4.

the central void is exactly 4x4x4 — identical in size to one of the 8 ambient cubes.
a virtual 9th cube (63 subcubes) fits perfectly into the void: the ghost cube slot.

ratio: void:group bounding box = 4:8 = 1:2 (exact).
total lit subcubes: 8 x 63 = 504.

recursive self-similarity:
- current level's node group (8x8x8 bounding box) = parent level's central void (4x4x4 x scale)
- zoom factor between adjacent levels = 2
- 5 navigable scale levels already defined in grid-v13 baseline:
    SCALE_1      = FORMATION_SPACING x 1       (innermost)
    SCALE_20     = FORMATION_SPACING x 20
    SCALE_200    = FORMATION_SPACING x 200
    SCALE_10000  = FORMATION_SPACING x 10000
    SCALE_100000 = FORMATION_SPACING x 100000  (outermost)

the x20 jump between levels = 2 (void ratio) x 10 (decimal/binary boundary).
the 8 corner cubes (with their missing inner subcubes) are the entry/exit points between scales.

## navigation model

- **double-click node** -> push current scale context, zoom in 2x, enter void
  the 20x20x20 group shrinks to fill the 10x10x10 void at the new scale
- **double-click void center** -> zoom out 2x, pop context
- **navigation stack** -> tracks current scale level + context node p7ref
  max depth: 5 levels (the 5 defined scale constants)
- **breadcrumb indicator** -> small overlay showing current depth [0..4]
  and path: NODE:D56WNQY > NODE:NODEB00 > ...

## data model

each scale level fetches a context-scoped orbital endpoint:
  GET /orbital.json                          (level 0 — network view)
  GET /orbital.json?context=NODE:D56WNQY    (level 1 — inside self node)
  GET /orbital.json?context=NODE:D56WNQY:NODE:NODEB00  (level 2 — nested)

at level 0: known[] = other P7 nodes on the network
at level 1: known[] = zenki running inside the node (cube, v7, httpd, kimi...)
at level 2+: known[] = sub-processes, data spaces, task contexts (tbd)

the web zenka's orbital state handler needs a context param:
- `plugin.web.space.fetch` reads context query param
- routes to appropriate data source per level
- returns same orbital.json schema regardless of depth

## implementation plan

### phase 1: navigation stack + double-click (visualization only, mock data)

1. add `navStack = []` — array of { scaleLevel, contextP7ref, rotX, rotY, manualZoom }
2. double-click detection: 250ms timer to distinguish from single-click
3. on double-click node:
   - push current state to navStack
   - set zoomTargetZoom = manualZoom * 2 with 0.7 kick
   - set context p7ref = node.p7ref
   - fetch /orbital.json?context=<p7ref> (falls back to current data if unimplemented)
4. on double-click void (no node within 40px):
   - if navStack not empty: pop state, animate back
5. breadcrumb overlay: depth indicator + p7ref path

### phase 2: context-scoped orbital endpoint (web zenka)

- `plugin.web.space.fetch`: parse `context` query param from request
- level 1 handler: return zenki list as known[] nodes
  (map p7c list sessions output to orbital node format with synthetic p7refs)
- level 2+: tbd based on what makes sense at each depth

### phase 3: real data at each level

- level 1 nodes: real zenka p7refs with orbital positions derived from
  zenka name hash (same addr_b32 encoding, seeded by zenka identity)
- connect transitions to actual P7 routing (navigate to a zenka's context)

## visualization notes

- the orbital sphere radius (140) and the grid CUBE_SIZE (140) are already matched
- the 4x4x4 void maps to radius 70 — could visualize as inner sphere boundary
- the 8 corner cubes (missing inner subcube) could be highlighted as entry points
- smooth 2x zoom with existing lerp + 0.7 kick is already proven to feel right
- at depth > 0: show outer node group faintly at 0.2 opacity as spatial anchor

## signatures note

phase 1 modifies visualization.html only.
phase 2 modifies plugin.web.space.fetch and related web zenka modules.

#,,.,,,,,,...,,..,,,.,,,.,,.,,..,,...,,.,,.,,,..,,...,...,,.,,...,,,.,...,,.,,
#AP33L24DRFU5CVZKO5ZSBIRRLJWXLII2XUQOM4QNZ3XXMNEEB6KEB2JMIAQCOEUYZSFFP4O5LM6QS
#\\\|EBY3X3SDEKQNDNXCIGIHYNQ7Y4ZTRQ6VQVQ7ONVHKHOW5OYLSZV \ / AMOS7 \ YOURUM ::
#\[7]DSB6KJC7NZHIC6C7BROES6TTVGSA33S5AE4GD2B6ISQUU733LYBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
