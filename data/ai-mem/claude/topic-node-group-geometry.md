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

**the void as workspace:**
- the void is the **self-address** of the node group — where its inhabiting data lives
- projection space for addressed state, parent state, or combined inference
- structurally identical to the 8 surrounding cubes → no privileged center
- each node group is simultaneously peripheral (in the larger field) and the center of its own space
- recursively equivalent centers: every void is the center of space for its group, and all are equal

**Why:** corrected from earlier sessions which stated 20×20×20 / 10×10×10 — those were wrong. The exact numbers are 4×4×4 cubes with 4×4×4 void.

**How to apply:** use these numbers for recursive-scale-navigation task, any visualization geometry, and the "zoom into void = zoom into identical structure" navigation model.

#,,.,,,,,,,..,,.,,,.,,..,,.,,,.,,,...,,.,,,..,..,,...,..,,,,,,,,,,.,,,.,.,..,,
#T5FXCRLM6KR4TXGEHTTPJV2JZVAMVXPMG6LIEI7HAVJKSD2NNCY525UZXXGEUMIUCXK5WOSIVETLS
#\\\|IZZ65RW5BRL6PK6WPT3KWENSH7T6W5K6BZIT5RP7V2TJR24O3ND \ / AMOS7 \ YOURUM ::
#\[7]UUQUR356VR5JIDJPBO7SC36B7R5EPY4U5B3FCEJWUK3Z4JWD4MBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
