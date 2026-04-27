---
name: node-group-geometry
description: exact geometry of the 8-cube node group and its central void — critical for recursive navigation and visualization
type: project
originSessionId: 7e5b15b7-297d-417a-a4f5-5c73d33de2a6
---
## node group geometry

the node group is 8 × (4×4×4) ambient cubes arranged in a 2×2×2 formation.

**each cube:**
- 4×4×4 = 64 subcubes, minus 1 missing innermost corner (pointing toward center) = **63 blue ambient subcubes**
- has a native **1-pixel boundary** on each face

**void derivation (per axis):**
- two adjacent cubes sit 2px apart: 1 boundary (cube A) + 1 boundary (cube B) = **2**
- each cube's missing innermost corner adds 1px inward from each side: **+1 +1**
- total void per axis: **2 + 1 + 1 = 4**

**the void:**
- exactly **4×4×4** — identical in dimension to one of the 8 ambient cubes
- a virtual 9th cube (63 subcubes) would fit **perfectly** into the center
- it is a **ghost cube slot** — structurally identical to its 8 neighbors
- this is what makes recursive navigation natural: double-clicking into the void enters a space of the same geometry

**totals:**
- 8 × 63 = **504 blue ambient subcubes** total in the node group
- bounding box: **8×8×8** subcubes (with 2px inter-cube gaps + void)

**the void as workspace and 6+1 anchor:**
- the void is the **self-address** of the node group — where its inhabiting data lives
- projection space for addressed state, parent state, or combined inference
- structurally identical to the 8 surrounding cubes → no privileged center
- each node group is simultaneously peripheral (in the larger field) and the center of its own space
- recursively equivalent centers: every void is the center of space for its group, and all are equal

**the void as rotation chamber and teleportation platform:**
- 4×4×4 void is large enough for a 63-subcube cube to rotate 90° in place
- makes the void a **relative grid mapping platform** — a separate grid can be rotated at fixed center
- cubes arrive and depart in all 6 face directions, streaming snake-like (carrying directional history)
- void [0] anchors 6 adjacent spaces via its 6 faces [1-6] = **7-based spatial topology**
- each void face is an **event-horizon** into that direction's space, with variable scale differential
- since every node group has a void, and the void is part of the grid:
  → the grid is **self-sensing** — every void is simultaneously rotation chamber, teleport node,
    and omnidirectional eye looking outward in 6 directions onto the field's inhabitants
- this is the geometric derivation of the 6+1 universe logic: 6 faces + 1 center = 7

**Why:** corrected from earlier sessions which stated 20×20×20 / 10×10×10 — those were wrong. The exact numbers are 4×4×4 cubes with 4×4×4 void.

**How to apply:** use these numbers for recursive-scale-navigation task, any visualization geometry, and the "zoom into void = zoom into identical structure" navigation model.

#,,,,,,,,,,,,,...,.,,,.,,,.,.,...,.,.,,,.,.,,,..,,...,...,,,,,.,,,.,,,,,,,,,.,
#Z252ZY2ZWDOHE6UCWHGXX3ERKECVZWDSW3MW4ZMDXZ6LOOFBQS4Y5CLPFZM746N6CBKYIJUKY4FGW
#\\\|OM47AO2JWWZUWQPHVZZRCBTH3TCR7TP35KJQDM7ULSYLFGV65AW \ / AMOS7 \ YOURUM ::
#\[7]T3GPINSNYF5MAVCFZ4SCRNE6UOA3OOMQ75WFZT53UPGP3KGCBOAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
