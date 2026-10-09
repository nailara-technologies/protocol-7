# image surfaces : addressable screens inside generated images

brief [ 2026-10-09 ]. the geometry step between a detected screen and real
content on it. concept is in
`data/md/design-specs/fractal-data-architecture-holographic-tty.md` [ `:579`
rooms within rooms, `:648` blank display templates, `:772` recomposition
engine "match lighting, perspective, scale" -- listed as needed ]. this task
is that recomposition engine, for flat displays first.

## the loop [ user ]

```
generation [ qwen 2.2 t2i, reference-guided ]
    ↓  hints : syntax-highlight palettes, glyph density, glow
render real code sections that also look good graphically
    ↓
povray renders them onto rects matching each screen's perspective + scale
    ↓
composite into the image  ->  new reference image
    ↓
next generation run  [ feedback ]
```

the generated "code" is gibberish but carries style ; the rendered code is
real but needs the style. each round moves both toward each other.

## pipeline

1. **detect** -- display mask [ `rendered_display`, conf 0.85, binary mask,
   see `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` ; model layer in
   `data/tasks/visual-mask-model-layer.md` ]. entity masks too [ cat, elf ]
   -- needed for occlusion in step 5.
2. **fit the quad** -- 4 corners per display. fit lines to the mask's
   straight edges, corners = line intersections [ robust against glow \
   bezel noise, unlike taking mask extreme points ].
3. **pose + scale** -- homography image-quad <-> unit rect. for povray : a
   camera \ plane placement reproducing that homography [ focal length
   shared by all displays of one image -- solve once, constrains the rest ].
   aspect ratio of the real panel comes out of the solve, not the bbox.
4. **render** -- `povray.cmd.render <template> <context>` with a new
   display-surface template : textured rect [ the code render ] + emissive
   finish matching the screen glow. context = pose, size, palette.
5. **composite** -- clipped by the visible display mask, entity masks stay
   on top [ the screen goes *behind* the cat ]. glow \ reflection taken from
   the blank display template [ inpainted, `:686` ].
6. **back in** -- composite saved as a reference image, linked to its source.

## special cases [ kept, not filtered out ]

- **truncated by the frame** -- a display running past the image edge is
  still wanted [ user ]. corners outside the image are fine : the line fit
  from the visible edges extrapolates them, the full rect is rendered and
  the image border clips it. needs >= 2 visible edges + the vanishing
  direction of a third ; mark the surface `truncated` with which sides.
- **occluded** -- part of the screen behind an entity. same treatment :
  full rect rendered, entity mask cuts it. visible fraction stored.
- **non-flat** [ curved panels, holographic \ circular displays ] -- later.
  flat rects first.

## surface address

one record per surface, so later code [ rooms, portals, content routing ]
can name it :

```yaml
surface:
  image:     <checksum name of the png>     # e.g. SDNZSX..MOOW
  index:     0..n                           # left to right
  corners:   [[x,y] x4]                     # may lie outside the image
  truncated: [ right ]                      # sides cut by the frame, or none
  visible:   0.0..1.0                       # after frame + occlusion
  pose:      { homography, focal }          # solved, shared focal
  aspect:    w/h of the real panel
  content:   <what is rendered there now>
```

the rooms spec makes each surface a portal ; this record is what the click
resolves to.

## first test case

`data/gfx/backgrounds/EFKDIR72PN2FMO4WTUBLGWYJUHVX2UACHMES47ZJZR4IO.png`
[ network kitten, 1408x640 ] -- several flat screens at different angles,
one truncated at the frame. covers detect, quad fit, shared focal,
truncation and occlusion [ the cat in front ] in one image. the elf images
[ DRJG.., Z5GQ.. ] have code *walls* rather than screens : a second case
[ large planar text surfaces, no bezel ].

## pieces

- exists : povray zenka [ render, template.resolve ], invoke \ invokeai
  zenki for generation.
- new : display mask + quad fit [ opencv, on-demand like the mask models ],
  pose solve, povray display-surface template, code -> texture renderer
  [ highlighted source as an image, palette from the generation ], compositor,
  surface records.

#,,,.,,..,..,,,..,.,,,,,,,,,,,.,,,,,.,,,.,.,,,..,,...,...,.,.,,,.,.,,,,,.,...,
#W7MO2WXKOBBP56YWVSFR4OWNT4G2ADQY6DA56UL32N7AWGHV3GEZD52BM6HU5WRQCIDOWUALJ34KC
#\\\|22JHDU4ADAD6PU35KGEGGRKYEA5JEPTA77IVJM5DRCAVEH3YAXW \ / AMOS7 \ YOURUM ::
#\[7]2ODTTXXU65MCLWFJCCCSGVE2FACTAVCTPWHUFR5SEUFUSODUXGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
