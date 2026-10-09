---
name: reference-image-surface-rooms-spec
description: where the "screens inside generated images as addressable surfaces" design lives [ keyword 'room', not 'surface' ] + what it does not cover yet
metadata:
  type: reference
---

the design for using screens / monitors inside generated images as addressable surfaces is in
`data/md/design-specs/fractal-data-architecture-holographic-tty.md` -- search **'room'**, not
'surface' \ 'screen' [ a full grep for surface \ homography \ rendered_display missed it, 2026-10-09 ] :

- `:579` recursive display navigation : rooms within rooms, each screen = a portal \ context,
  previous room becomes a screen on the wall [ maps onto cube node \ face navigation `:640` ]
- `:648` layered decomposition : mask -> entities \ displays \ background, inpaint ->
  **blank display templates** [ same lighting, reflections, perspective ] ready for content overlay
- `:772` "needed" list : recomposition engine [ match lighting, perspective, scale ]
- `:859` computer_screen zoom ladder ; `:945` space as the forgiving compositor

related : `rendered_display` category [ conf 0.85, binary mask ] in
`data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` ; mask models in
`data/tasks/visual-mask-model-layer.md` [ screens not yet listed there ] ; povray as conditioning in
`data/md/design/VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES.md`.

written up 2026-10-09 as `data/tasks/image-surface-addressing.md` [ truncated \ occluded
screens are wanted, not filtered -- user ] : the geometry step -- mask -> 4-corner quad -> pose \ scale
-> povray renders real syntax-highlighted code onto a matching rect -> composite -> back in as a
reference image [ the user's planned code-rendering feedback loop ]. first test case : the kitten
background `data/gfx/backgrounds/SDNZSXD2I5BZAMYCNJ5YDSOTW4MHA3TRTOB75KDEGMOOW.png` [ 3 screens ].

#,,..,.,.,,,.,,.,,..,,,,.,,,,,,,,,,..,,,.,.,,,..,,...,...,.,,,.,.,.,,,..,,.,.,
#3VHDD4KPBA4XM4DIICELL65QBH5E6CLNCK57FLS2FRDDSU6NTSIMA7ZWXEA3Q2UUGLYYPBX66ZLBO
#\\\|IUAPPRN6QOZO4YUWK5V2N4IX72RVRMAX34JAUSAYTG2ONUAPYNF \ / AMOS7 \ YOURUM ::
#\[7]KGFZ6AGIY6OF5IWGUSO5ZDXECJPS25YNPEMRFA2O6VWKFRCSWOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
