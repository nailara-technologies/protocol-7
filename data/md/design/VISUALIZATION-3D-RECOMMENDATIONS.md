# 3d visualization : recommendations for the layered grid as a checked readout [ 2026-11-17 ]

recommendations only. nothing here is built, no code was changed.

read for this pass, and nothing else :

- `data/web-root/vhosts/visual.v7.ax/grid-v14-layered.refactored.html` [ 1430 lines, 56716 bytes ]
- `src/discover.orbital.*`, `src/discover.cmd.*orbital*`, and of the web side only
  `plugin.web.space.orbital.subscribe_discover`, `.handler.discover_strm_open`,
  `.to_cells` and the head of `.json`
- `TRANSPORT-DESIGN.md` section 3.5, `RESOURCE-ACCOUNTING-UNIFIED.md` section 21,
  `SUBSTRATE-SYNTHESIS.md` [ the lines on views, layers, readouts ; contradiction 13 ]

not read, so not claimed : the other `plugin.web.space.*` modules, the graphics-matrix
zenka, how the web zenka pushes to a browser [ poll \ stream ], the transport sections on
holds and gates beyond what 3.5 quotes, the ledger sections 15 to 20, whether a js
runtime for headless checks is installed.

## 1. what is there [ checked ]

**the page.**

- one self-contained file, canvas 2d, no library, no build step
- **it has no data input at all** : no fetch, no stream, no file. everything drawn is
  generated from constants and the camera. it is a geometry study, not yet a readout
- a data-driven **layer registry** [ `layers`, 8 entries ] with a zoom range per layer
  [ `vis.rangeStart \ rangeEnd \ fade`, `calcRangeAlpha` ], computed once per frame, and
  an early bail-out for invisible layers. this is the best part of the file
- five "hyper" grids at the scales 20, 200, 10 000, 100 000, 1 000 000 [ "20x20x20 base
  unit" ]. `generateHyperGrid` emits lines along X and along Z only ; **no Y lines**
- the main grid : formations of 8 cubes with a cut-out corner and sub-cubes, 343
  formations at `RENDER_RANGE = 3`, regenerated around the camera every frame
- selection is an unbounded integer coordinate, the camera follows lazily
  [ `CAM_FOLLOW_SPEED` ], an edge indicator shows a selection outside the drawn range
- pools for hyper lines and formations, a projection cache per frame
- `draw()` still allocates per frame [ `allSubcubes`, `allEdges`, `.map`, objects per
  edge ], sorts both lists every frame, builds one `hsla(..)` string and one path per
  edge, and `animate()` redraws on every animation frame even when nothing moved
- auto-rotate adds `0.13` per frame, not per second : the speed follows the display
  refresh rate [ 60 Hz and 144 Hz differ by a factor of 2.4 ]. there is no speed control
- colours are already dark violet \ blue [ lightness 2 to 13 % ], background `#000007`.
  the colours are spread over the css, the layer table and literals inside `draw()`
- `grid-v14-layered.optimized.html` is **byte-identical** to the refactored file [ `cmp` ]

**the backend.**

- `discover.orbital.store_remote` keeps `<discover.orbital.known>`, keyed by
  `chk-sum.bmw.L13-str( pkey )` : hostname, pkey, p7ref, timestamp
- `discover.cmd.list-orbital subscribe` opens a STRM push channel : the current snapshot
  first, then one line per mutation. the line is plain text :
  `hostname pkey7 p7ref age`. gated by `discover.cfg.orbital_push_enabled`
- `plugin.web.space.orbital.subscribe_discover` subscribes with a retry backoff, the
  handler merges the lines into `<web.space.orbital.cache>`
- from the cache two things leave : `plugin.web.space.orbital.json` [ a json structure
  for the existing visualization ] and `plugin.web.space.orbital.to_cells`, which places
  nodes as graphics-matrix cells from **rounded orbital angles** [ theta \ phi \ psi ]
- `discover.orbital.share_grid_fragment` is zenka to zenka [ `nodes.orbital-grid-fragment`,
  lines `hostname p7ref` ] : it never reaches a browser
- `discover.cmd.inject-orbital` injects a test node. a ready test hook
- `base.indexcube.push \ pop \ here \ depth \ reset` exist ; `decoder.cmd.show-indexcube`
  too

**what does not fit yet.**

| the page | the designs |
|---|---|
| scales of 20 and powers of 10 | one scale = one octet triple, 256 per axis [ transport 3.5 ] |
| one flat coordinate per axis | a stack of places : `push` descends, `pop` returns |
| a place is drawn everywhere | a cube is sparse : a step arrives only at an occupied coordinate or a face |
| positions from rounded angles [ `to_cells` ] | `ADDR_B32` is three octets `X Y Z`, from the identity key |
| draws its own generated truth | "the view reads the series the tests assert on and computes nothing of its own" [ ledger 21 ] |
| no clock | the frame of the series is the only time |

## 2. the one rule : a view is a checked readout

from synthesis contradiction 13 and ledger section 21 : a view is a cache like every
other derived state, the journal stays the truth, and a picture that looks wrong is a
failed property or a missing one. as rules for the code :

1. **every number on screen is a field of a row of the feed.** the view scales, places
   and colours ; it adds, divides and predicts nothing. no fill level computed from
   two other values in the browser : the row carries it
2. **no interpolation of values between frames.** a form may fade from one frame to the
   next [ a fade is not a value ], a number shown is always a row's number
3. **the verdicts come from the tests.** the feed carries the property results
   [ section 4, `prop` rows ]. the view marks the frame a property failed in ; it does
   not judge
4. **one parser, one dump.** the view can write back what it holds as text. the dump of
   a loaded series equals the rows of the file : this is the acceptance check that
   makes "readout" testable and not a promise
5. **the view shows no more than its holder knows.** a trunk shows a constant stream
   and nothing of what crosses [ transport 3.5, section 7 ] ; the stack of a move never
   travels in the unit, so the view of a holder shows its one entry, not the path
6. **the same file, three sources.** a scratch series from the simulation, a replay of
   a real journal, the live state. only the head differs [ `source` ]

## 3. what the layers show

a **layer** is one kind of row drawn one way. a **perspective** is a named set : layers
on \ off, a scale, a camera, a speed. the registry of the page already is the first
half ; the second is a small p7 config text [ section 4.4 ].

### 3.1 the lattice [ @INDEXCUBE ]

- **re-base the scales to 256.** the five hyper layers become "scale n" layers : one
  grid per depth of the stack, the zoom range per layer stays as the mechanism. zooming
  out through a face of the cube is `pop`, zooming into a place is `push`
- **the coordinate is a stack of octet triples, never one number.** 256^7 is past the
  whole-number range of a js double : a flattened coordinate breaks at depth 7. the
  camera holds `( stack, offset inside the cube )` and draws relative to the cube it is
  in. this also matches the design : "plain whole numbers with a bound, no modulo"
- **draw the sparse cube as it is.** occupied places as glyphs, the six faces
  [ octet 0 \ 255 of an axis ] as planes, the rest as the router's volume : one faint
  tint for "held by the holder of the parent place". no 256^3 grid lines : a grid of
  tick marks at 16 or 32, off below a zoom threshold
- **the cut-out formation is the glyph of an occupied place** at near zoom [ kept ], a
  point with a label ring further out
- **the edge is visible.** a face is drawn differently from an inner plane : a step
  symbol is refused there [ `return`, reason `edge` ], only a lane digit crosses
- **marks 1 .. 6** : one hue per axis inside the violet \ blue \ cyan band, the sign by
  line form [ full \ dashed ], not by brightness. axis = `( mark - 1 ) >> 1`, as the
  design numbers it : the legend shows mark, axis and octet in one row
- **mark 7 and `f4`** : alpha only, no colour of its own, along the body diagonal. the
  design says it "renders as alpha, not as a colour" : the view follows that literally
- **`f1` .. `f3`** have no transport meaning [ 3.5 ]. no layer is invented for them
- `to_cells` places by rounded angles. the lattice layer places by the `ADDR` octets
  only. two derivations of one position would be two truths [ question 6 ]

### 3.2 holds, lanes, gates, trunks

| thing | drawn as | from the row |
|---|---|---|
| hold, open [ `depart` ] | a thin segment from holder to next holder, with a remaining-frames arc at the holder | state, deadline frame |
| hold, closed [ `arrive` ] | the segment turns solid once, then fades over the fade time | state |
| hold, closed [ `return` ] | the segment recedes back to the holder, the reason as a short label | state, reason |
| a chain of holds | the segments in order ; closing runs visibly in reverse [ this is `pop` ] | prev \ next hold id |
| a run through empty coordinates | **one** segment of the router, not one per coordinate [ 3.5 ] | one hold row |
| lane | a band on the face it crosses, width = capacity, filled part = in use | fill, cap |
| gate pair | two glyphs on the two faces of one crossing ; open \ closed by form | state |
| a carry up the stack | the crossing is drawn at the layer where it settles [ the nearest shared layer ], not at each scale on the way | settle depth |
| trunk | a steady dashed line at a fixed rate, alpha only | present \ absent, nothing else |
| refused at the anchor | a mark at the top face, no segment : the sender got no `depart` | reason |

beside the 3d picture, a **stack panel** : the entries of the selected move or of the
zenka's own `@INDEXCUBE` as a ladder, entry 0 the anchor at the bottom, `here` on top.
it is a list, it costs nothing to draw, and it is the part a test can read most easily.

as built an `@INDEXCUBE` entry is not a signature [ 3.5 ] : the panel shows `valid` as
what `pop` reports, labelled "checksum only" until the signed form exists. a view that
showed a lock symbol here would claim more than the code proves.

### 3.3 pools filling and overflowing

- **first the flat picture.** section 21 names it : time as the horizontal axis, "the
  curves that balance each other are the picture". a strip of curves per pool [ fill
  level, held, reserved, given out, leftover ] against the frame, in true proportions,
  one shared vertical unit. this is stage 1, before anything is 3d : it is cheap, it is
  the picture the owner asked for, and it proves the feed
- **then the same rows in space.** a pool is a column at its place : height of the
  vessel = capacity, level = fill, bands inside for held and reserved. true
  proportions : a pool ten times larger is ten times taller, or the scale is written
  on it. no logarithm without a label
- **overflow is a flow to the accounting parent** [ or the root pool ] : a slow, steady
  line upward along the tree, its width the amount of that frame. "remainders to
  parent" is so visible as what it is. a leftover of zero draws nothing, as it writes
  no record
- **over capacity** : a steady outline in the one warning hue. never a blink, never a
  pulse [ section 6 ]
- **the properties are drawn where they fail** : a marker on the frame axis and on the
  pool, with the property number [ 1 .. 9 ]. passing properties are a quiet row of
  ticks
- **the two ends** : the first frame [ empty ] and the saturated frame are reachable by
  one key each. a clean design "looks good starting at zero and saturated" : those two
  frames are the first thing to look at

### 3.4 realtime network state

the same layers, `source = live` in the head. section 21 puts it outside the ledger
design : "a readout of real journals in place of scratch ones". so :

- no second view. a perspective `network` = lattice + places + trunks + pool levels, at
  the scale of the anchor
- the two views of the synthesis as two perspectives over the same nodes : the
  **identity tree** [ timeless ] and the **occupancy view** [ dated, who holds now ]
- live rows are coalesced by the backend to at most one frame per second by default.
  the view never polls faster than the frame rate it is told
- as background \ dashboard workload : the page takes `?perspective=<name>&ui=0` and
  draws without panels. nothing else is needed for that use

## 4. the data contract

one text form for everything the view reads. no json : the existing
`plugin.web.space.orbital.json` stays as it is for its present consumer and is not
extended [ question 7 ].

### 4.1 shape

a head in p7 config style [ `=` and `:` equivalent ], one empty line, then rows. a row
is one fact : a kind word, then fields separated by single spaces. this is the form
`list-orbital subscribe` already pushes [ `hostname pkey7 p7ref age` ], with the kind
word added in front. the series of ledger section 21 is "a plain column file with a p7
config style head" : **the view reads that file itself**, it gets no export of its own.
the only request to the 1b task is that each row starts with its kind word and each
frame with a `frame` row, so one parser serves all sources.

    format        = p7-view 1
    source        = sim                 [ sim \ replay \ live ]
    scenario      = ramp
    seed          = 13
    frames        = 420
    frame.rate    = 1                   [ frames per second at speed 1, live only ]
    unit.amount   = drop
    cols.pool     = id parent cap fill held reserved given leftover horizon price
    cols.sum      = entered held given leftover
    cols.prop     = number result
    cols.place    = id depth path kind label
    cols.hold     = id holder next state deadline prev reason
    cols.lane     = id place mark cap fill
    cols.gate     = id place axis side state peer
    cols.trunk    = id place-a place-b
    body.bmw      = <BMW checksum of everything after the empty line>

    frame 0
    place a7 1 12.200.31 zenka cube
    pool root - 1000 0 0 0 0 0 0 0
    sum 0 0 0 0
    prop 1 true
    frame 1
    pool root - 1000 40 40 0 0 0 0 0
    sum 40 40 0 0

### 4.2 rules

- **the head names the columns.** the parser reads `cols.<kind>` and never assumes an
  order. a new column is added at the end, an unknown kind is skipped and counted
- **frame 0 is whole, later frames carry only rows that changed.** a row replaces the
  row with the same kind and id. `gone <kind> <id>` removes one. a live stream that
  dropped anything sends `frame <n> whole` and starts again : no repair logic in the view
- **whole numbers in the unit of the head.** no floats, no percent : the ledger counts
  drops, the view divides only to place a pixel
- **`path`** is the stack from the anchor down, one triple per scale :
  `12.200.31/0.255.7`. decimal octets, so the row is readable by hand and the view
  decodes no base32. the P7REF stays the id where one is wanted
- **`-`** for an empty field, never an empty string between two spaces
- **truth values** as the words `true` \ `false` \ `unknown`, as the reply modes do
- **checksums** : BMW over the body in the head, AMOS for a 7 character label. no sha
  anywhere, also not `crypto.subtle` in the browser. the backend and a command line
  check verify `body.bmw` ; the view shows the value and does not port a checksum to js
  in the first stages [ question 9 ]
- **labels, not hostnames.** the present orbital line carries the hostname, and
  `visual.v7.ax` is a public vhost. the `place` row carries a label [ `pkey7` or the
  AMOS label of the alias ] ; a hostname only on an authenticated perspective
  [ question 5 ]
- **bounded.** the head of a live feed states `rows.max` per frame. above it the
  backend sends aggregates one scale up [ `cube <path> places holds fill cap` ] : the
  level of detail is chosen where the data is, the view computes no sums

### 4.3 where the rows come from

| rows | source of truth | reaches the view by |
|---|---|---|
| `pool` `sum` `prop` | the simulation of ledger 21, written with the ledger's own modules and read back by replay | a file, fetched once as text |
| `place` | `<discover.orbital.known>` [ and `base.indexcube.here` for the own stack ] | the existing subscribe pattern of `discover.cmd.list-orbital` |
| `hold` `lane` `gate` `trunk` | the transport walker [ its acceptance check 10 ] first, live holders later | a file first, a stream later |

for the live part, follow the pattern that exists and works : a command with a
`subscribe` argument, a STRM handle list, the snapshot pushed at once, dead handles
dropped on a failed push. one such command per source zenka, the web zenka relays the
lines unchanged. a new command needs its three lists [ the zenka's own `zenka.v7` list,
the sub whitelist, the cube access grant ]. `discover.cmd.inject-orbital` stays as the
test hook : an injected node must appear as a `place` row and in the dump.

how the web zenka hands a stream to a browser was not read. until that is known, plan
with the plainest form : the browser asks `since <frame>` once per frame interval and
gets the rows as text [ question 8 ].

### 4.4 perspectives

a second small text, same style, kept beside the page or served by the web zenka :

    perspective   = ledger
    layers        = series pools overflow props
    scale         = 0
    camera        = 15 15 0
    speed         = 1
    ui            = 1

## 5. the current code : keep, refactor, remove

**keep.**

- the layer registry and its zoom-range visibility : every new layer is one more entry
- `updateProjectionCache` \ `project`, the hyper line pool, the formation pool
- the integer selection with the lazy camera, and the edge indicator
- the panels and the key set [ I, L, B, F, C, R, arrows, page up \ down ]
- the cut-out cube templates, as the glyph of an occupied place
- one file that opens without a build step and without a network library

**refactor.**

- **time, not frames** : every motion multiplies by `dt x speed`. rotation in degrees
  per second
- **draw on demand** : a `dirty` flag set by camera, input, a new frame of the feed or
  a running fade. an idle page draws nothing
- **one palette table** [ hue, lightness, alpha per role ] with one `brightness`
  factor over all lightness values. no colour literal left inside `draw()`
- **one draw function per layer** in the registry [ `layer.draw( ctx, state )` ] in
  place of the `type` string branches at the end of `draw()`
- **no allocation in the frame** : typed arrays for projected points and segments,
  segments bucketed by style and stroked as one path per bucket, the depth sort only
  for filled faces and only after the camera moved
- **the scales** : constants `SCALE_20` .. `SCALE_1000000` and their ranges become one
  rule, 256 per depth, with the stack coordinate of section 3.1
- **Y lines in `generateHyperGrid`** : today a grid has two of its three line
  directions. either add the third or state in a comment why it is left out
- **listeners in place of inline `onclick`**, and `prefers-reduced-motion` read at start
- split into the page and two scripts [ `p7-view-feed.js` : parser, state, dump ;
  `p7-view-layers.js` : the draw functions ], plain script tags. the parser must run
  without a canvas, or it cannot be checked alone
- comments to project style on the way : lowercase, `[ word ]`

**remove.**

- `grid-v14-layered.optimized.html` : a byte-identical copy [ after a look at what
  `index.html` links to ; the owner deletes, not a tool ]
- the `×100k` and `×1M` layers and `MIN_ZOOM = 0.00000000007` once the stack
  coordinate is in : depth replaces the extreme zoom
- the per-frame regeneration of all 343 formations when the layer shows places from
  the feed : only occupied places are built
- nothing of the backend. `to_cells` and `orbital.json` serve the existing
  graphics-matrix path and stay untouched by this plan

## 6. calm by default : theme, speed, brightness

the owner's sensitivity to bright screens and fast patterns is a hard constraint of the
view, not a preference setting. so the calm state is what the page does with no
argument and no stored setting, and everything faster is a deliberate step.

- **theme** : dark violet \ blue, background near black as today. one warning hue
  [ a muted amber or magenta at low lightness ], used for "over capacity" and "failed
  property" only. print stays light [ a print stylesheet ]
- **brightness** : one factor, default at or below today's values, keys `-` \ `+`, a
  hard upper bound on lightness that no layer can pass. no white, no full-saturation
  fill over an area
- **speed** : one factor for everything that moves [ feed playback, rotation, fades,
  flows ]. default : rotation off, one frame of the series per 2 seconds, fades of
  800 ms. keys `[` halve, `]` double, `0` pause, `.` one frame forward, `,` one back.
  the factor is shown in the info panel
- **a ceiling** : above 2 x the page asks nothing and refuses nothing, it shows a
  plain note beside the factor [ warn, do not restrict ]. but two limits hold at every
  speed, because they are what protects : no element changes its lightness faster
  than once per 400 ms, and above a set playback rate frames are **skipped, not shown
  faster** [ the picture steps, it does not flicker ]
- **no strobing forms at all** : no blink, no pulse, no cycling palette, no moving
  dash pattern over a large area. state is carried by form and position ; a change is
  one slow fade. the trunk's dashes move at one fixed slow rate, or stand still below
  speed 1
- **`prefers-reduced-motion`** : start paused, fades off
- the setting is kept per browser [ local storage ], and a query argument overrides it
  for a background use

## 7. performance

- **budget** : at most 4000 stroked segments and 500 filled faces per drawn frame, a
  draw under 8 ms on the owner's machine, and **zero draws when idle**. a frame cap of
  30 per second by default : the calm speed needs no more, and it halves the load
- **canvas 2d stays** for the stages below. the costs today are allocation, sorting
  and one path per edge, not the api. webgl only if the budget fails after the
  refactor, and then for the line layers alone [ question 3 ]
- **style buckets** : alpha quantised to 8 or 16 steps per layer, one path per bucket.
  this removes most `strokeStyle` changes and all per-edge strings
- **sparse by construction** : the lattice draws occupied places, faces and ticks. the
  cost follows the number of rows, never 256^3
- **level of detail from the feed** : aggregates per cube one scale up [ section 4.2 ],
  chosen by the backend against `rows.max`
- **the feed** : frame 0 whole, deltas after, coalesced to the frame rate. a series
  file of 420 frames and a few dozen pools is some hundred kilobytes of text : fetched
  once, parsed once, held as typed columns
- **backend cost** : the readout is a subscriber like any other. no zenka computes
  anything for the view that it does not already hold ; a zenka with no subscriber does
  no work for it
- the info panel keeps FPS and element count, and adds rows per frame and draw time :
  the numbers the acceptance checks read

## 8. stages, each sized for one kimi run

every task prompt says : BMW \ AMOS only, no sha, no json for the new form ; lowercase
comments, `[ word ]` ; touch no file the task does not name ; `bin/format-code -c` for
any `src/*` file. no stage changes `to_cells`, `orbital.json` or a ledger file.

**stage 0 : the shell, no new picture.** a new file `grid-v15.html` beside v14 [ v14
stays as the reference ]. palette table, brightness, speed, `dt`, draw on demand,
listeners, reduced motion, the third line direction or its comment.

- with rotation off and no input, the draw counter stays at 0 over 10 seconds
- rotation at speed 1 turns the same angle per second at 30 and at 60 frames per second
- `[` `]` `0` `-` `+` work and the values show in the panel ; a reload keeps them
- no colour literal outside the palette table [ grep ]
- at default brightness no drawn lightness is above the v14 values
- the v14 file is unchanged [ `cmp` against git ]

**stage 1 : the feed and the flat series.** `p7-view-feed.js` [ parser, state, dump ]
and a `series` layer : curves per pool against the frame, playback, the two end keys.
input : the 1b series file if it exists by then, else a hand-written fixture of three
pools and 20 frames in the form of section 4.1.

- the dump of the loaded file equals its rows, byte for byte, for the fixture and for
  a real series
- the parser runs without a canvas [ the same check from a command line, if a js
  runtime is there ; else from a test page that prints `equal` \ `differs at row n` ]
- a column moved in `cols.pool` gives the same picture ; an unknown kind is skipped
  and counted in the panel
- a `prop .. false` row shows its marker at its frame, and nowhere else
- no number is on screen that is not a field of a row [ review of the layer code : no
  arithmetic on two fields ]
- playback at speed 1 is one frame per 2 seconds ; `.` and `,` step exactly one frame

**stage 2 : pools in space.** columns at places, bands, the overflow flow to the
accounting parent, the over-capacity outline.

- scenario overfill : every frame with a `remainder` to a parent shows one flow on that
  edge, and no flow in a frame without one
- heights are in true proportion : two pools with `cap` 100 and 1000 measure 1 : 10
  in the dump of drawn heights
- the first and the saturated frame are one key each
- no element changes lightness faster than once per 400 ms at any speed

**stage 3 : the lattice.** stack coordinate, 256 per scale, sparse cube, faces, places
from `place` rows, the stack panel. input : a fixture, then `inject-orbital`.

- a place with path `0.255.7` stands on the +Y face and is drawn as a face place
- a camera at depth 8 moves one coordinate without jitter [ the stack coordinate holds ]
- zooming out through the cube shows the parent scale with this cube as one place
- an injected orbital node appears as one `place` row in the dump
- no grid of 256^3 is ever built : segments per frame stay under the budget at every
  zoom

**stage 4 : holds, lanes, gates, trunks.** from a trace file written by the transport
walker, in the same form.

- a run through empty coordinates is one segment
- a chain closes in reverse order on screen, as in the trace
- a step at an edge shows `return`, reason `edge`, and no segment beyond the face
- a carry is drawn at its settle depth only
- a trunk looks the same with and without traffic in the trace

**stage 5 : live.** a `subscribe` readout command per source zenka after the
`list-orbital` pattern, the web relay, perspectives, `?perspective=..&ui=0`.

- the command lists are complete : `<zenka>.commands` shows the command, the far cube
  log shows no refusal
- snapshot first : a fresh subscriber has the whole state within one frame interval
- a killed subscriber is dropped from the handle list on the next push
- the public perspective carries no hostname [ grep on the relayed lines ]
- the same page shows `source = sim` and `source = live` with no code path of its own
  for either

**stage 6 : measure, then decide.** the budget of section 7 against real row counts,
the background use, webgl only on a failed budget.

## 9. owner questions, each with a recommendation

1. **re-base the grid from 20 \ powers of 10 to 256 per scale ?** yes : the lattice
   that exists is `@INDEXCUBE`, and a second scale system in the view would be a
   second truth. the 20-grid can stay as an optional layer, off by default.
2. **a new file `grid-v15.html`, or change v14 in place ?** a new file : v14 stays as
   the visual reference for the checks of stage 0.
3. **canvas 2d or webgl ?** 2d until the measured budget fails. no library either way.
4. **flat series first, 3d pools second ?** yes : section 21 asks for curves over
   time, and that picture proves the feed with the least code.
5. **hostnames on the public vhost ?** no : labels only, hostnames on an
   authenticated perspective.
6. **which position rule : `ADDR` octets or the rounded angles of `to_cells` ?** the
   octets for the lattice layer ; leave `to_cells` alone until graphics-matrix is
   looked at on its own.
7. **move `orbital.json` to the text form now ?** no : leave it, do not extend it, move
   its consumer after stage 5 if the owner wants one form.
8. **how does a live feed reach the browser ?** not read in this pass. start with one
   plain text request per frame interval [ `since <frame>` ], change to a push when
   the web zenka's way is known.
9. **verify `body.bmw` in the browser ?** not at first : the backend and a command
   line check verify, the view shows the value. a js BMW port is its own small task
   if a browser-side check is wanted. never sha as a stand-in.
10. **interpolate between frames ?** no values. a fade of the form only.
11. **default speed ?** rotation off, one frame per 2 seconds, fades of 800 ms.
12. **a hard speed limit ?** no refusal, a note above 2 x ; but frames are skipped
    and not shown faster, and the 400 ms lightness rule holds at every speed.
13. **what does a trunk show ?** presence only, at constant alpha. amounts appear at
    the pools of its two ends, never on the line.
14. **the stack panel while entries are unsigned ?** show `valid` as "checksum only"
    until the signed entry of 3.5 exists.
15. **layers for `f1` .. `f3` ?** none : the design gives them no transport meaning.
16. **the identical `optimized.html` ?** delete it, by the owner, after a look at the
    links of `index.html`.
17. **where does a scratch series live ?** outside the repo tree, served read-only ;
    only the small fixture of stage 1 is tracked.

## 10. not claimed

- nothing was run in a browser. the statements about the page are from reading it
- the frame rate dependence of the rotation is read from `rotY += 0.13` per animation
  frame ; the unit [ degrees ] is assumed from the start values
- the budget numbers of section 7 are targets to measure against, not measurements
- the series form of section 4.1 is a proposal to the ledger 1b task, which owns that
  file. if 1b has fixed another column form, the view follows it and only asks for
  the kind word and the `frame` row
- the `hold` \ `lane` \ `gate` columns are drawn from section 3.5 alone. transport
  sections 4 to 6 may name fields this pass did not see
- whether discover's known list carries enough to give every place its stack path
  [ and not only its own cube's octets ] was not checked

#,,..,,.,,,..,,,.,,..,,..,.,,,.,.,,.,,,,,,,.,,..,,...,...,.,.,.,.,,.,,,.,,,,,,
#C6Z27YC66V6I7XBFCU4Z4MYRDLYLLGIXYDRYEU7AWFRCEYHXEBZ6SJJF6NIG4USVERQAW7VEPTN5M
#\\\|X5AWF2MRNAEA3RPNDFHJ7KV2AHWHFO7SRVULT7XE4ATFSQ3VPML \ / AMOS7 \ YOURUM ::
#\[7]2SMQB6NFYJMPJ2JIA2UFBTVX7NDMWYFF25FG7R44LF5NCJRCF6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
