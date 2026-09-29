# images \ elfdb : feature collection

collection first, design later [ user, 2026-09-29 ] -- the features fall into
several categories ; gather them here as they come up, then plan. context :
`data/tasks/images-elfdb-landscape-survey.md` [ what exists, open questions ].

## direction [ user, 2026-09-29 ]

- the two zenki together control rendering and intermixing pipelines for
  character and scene evolution
- visual feedback pipelines with reference images need many, sometimes
  hundreds of iterations to reach the target quality and style -- but the
  threshold crossing occurs reliably
- the same pipeline concept serves feature extraction and translation over
  the whole image dataset [ 49963 images ]
- goal : a style- and context-aware, self-refining dataset -- without
  degrading entropy through re-feeding [ all steps tested manually by the
  user ; the re-feeding needs to be intelligent ]
- invoke.ai is an interim render engine : it will be replaced by something
  native. until then new ui elements drive it through invoke-web's api
  instead of its own web ui -- the testing ground for the native version

## concept sources [ read before designing ]

- `data/md/design/CONCEPT-HARMONIC-VISUAL-INTELLIGENCE.md` -- the feedback
  loop itself : quality gate [ harmonic assertion + llm calibration ],
  reference pool enrichment, emergent threshold, parallel variant branches,
  ANTI-ENTROPIC RESET SEQUENCES [ = the entropy guard for re-feeding : high-
  delta seeds that still pass the harmonic filter, diversity measured via
  the amos7 iteration count ], self-recreating zenka network, three-state
  calibration [ stimulation \ transition \ background, data/gfx/backgrounds/ ]
- `data/ai-mem/claude/topic-image-archive-system.md` -- tiered, vision-scored
  storage over the invoke corpus
- `data/md/design/IMAGE-ZENKA-NATIVE-ARCHITECTURE.md`,
  `VISUAL-GENERATION-NATIVE-ZENKA.md`, `data/tasks/network-elf-avatar-
  pipeline.md` [ elfdb ] -- see the survey
- [ user is still collecting : more sources to add ]

## topology : color wheel -> 3d spiral [ user, 2026-09-29 ]

- start simple, immediate use : the color of each image's 1x1 version maps
  to an ANGLE on a circle at the top level -- a color wheel made of all the
  colors present in the dataset, resolution increasing outward
- core ring : 1x1 up to 3x3 [ 9 pixels total -- the largest tile of that
  category ] -- up to 9 color values per image, compared directly and sorted
  by distance. images with a similar mean color but a different
  composition separate cleanly
- gray \ desaturated mean colors : likely marginal -- many styles sit
  intentionally deep in the blue and blacklight range as their main color,
  and the 2x2 \ 3x3 layout distance does not depend on one hue anyway
  [ user, 2026-09-29 ]
- for elves : sorted by that, the wheel is really a 3d SPIRAL -- a color
  wheel when looked at along its axis, in depth sequences of styles
  [ face detection, scenes ]. nestable, orthogonal distinctions -- like the
  spatial \ temporal compartmentalization topology. not needed for the
  start, only to be known
- the disk is made of ARCS [ user, 2026-09-29 ] : a color \ style change
  already moves the angle, so a sequence [ same scene type, same character,
  an iteration series ] traces an arc instead of sitting on a point -- color
  drift within a scene type becomes visible as arc length \ direction. face
  detection stays the depth mapping. visual language : the iris
  visualization combined with the color wheel visualization
- existing designs for exactly this :
  - `data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` ~:2078
    "universal angle mapping" -- hue -> azimuth phi [ color wheel ],
    saturation -> polar theta [ gray at the POLE, saturated at the equator :
    grays collect in one place instead of scattering over the angle ],
    value -> radius. orrery model : a color ring and a style ring rotate
    independently, the selected angular band is the working set -- an arc
    is a movement on one ring at a fixed position on the other
  - `data/md/development/VORTEX-LAYER-IRIS-CONNECTION.md` -- the iris is the
    vortex seen from above, rings = spiral arms : the 3d spiral that looks
    like a color wheel along its axis
  - live iris rendering : `httpd.route.handler.iris-svg` [ + iris-* routes ]
- generalization [ user, 2026-09-29 ] : iris + arcs + depth dimension[s] is a
  simple structure that can represent a complex processing queue or an
  accounting system -- "the nature of a computer system in itself". angle =
  what [ color, category, account, task type ], arc = how it runs
  [ sequence, drift, progress ], depth = which stage \ layer. first concrete
  case : the invoke.ai render queue [ pending items as arc stubs at their
  color angle, the running one growing, parked sessions a layer deeper ] ;
  `httpd.route.handler.iris-ledger` already uses the iris as a ledger
- like the darksun sorting structure [ user, 2026-09-29 ] : perfectly
  expandable outward -- each added ring adds "bandwidth" for nesting and
  growing datasets with further categorization, while everything stays
  sorted into REALTIME DEDUPLICATION. references : the darksun is the
  center \ attractor of the same geometry [ `data/md/design/ZERO.md` :
  position 27 = 3^3 ; `VORTEX-LAYER-IRIS-CONNECTION.md` : iris center =
  darksun ], `data/md/development/ROUTE-CALCULATION-METHODS.md` already
  routes in { arc, color } coordinates incl. the ccw implosion spiral to the
  darksun, `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` holds the dedup side
- color modes [ user, 2026-09-29 ] : e.g. alternating blacklight and blue ;
  the elf processing queues get blacklight intermediate style rings outward
- those rings double as [ graphical ] color-agnostic addressing and routing
  infrastructure : position on ring \ arc is an address independent of the
  colors drawn there -- what is built for these first use-cases may become
  an actual part of the network topology [ cf. `topic-addressing-trinity`,
  `topic-orbital-data-space`, `ROUTE-CALCULATION-METHODS.md` ] -- keep the
  addressing layer separate from the image \ color semantics from the start
- existing piece : `graphics.matrix.visual.similarity` already takes 1x1
  pixel arrays [ `color_sample` ] but never derives them from real files --
  compares against fallback gray [ known bug, see
  `vision-generic-web-template-hybrid-doc-browser.md` ; also its
  `resolution` param is dead ]

## elf context : fluorescence [ user, 2026-09-29 ]

- on the blacklight base, where the first fluorescent \ neon color palettes
  come in : the environment and holographic content of the scenes -- and in
  elf context mainly body painting lit up by the blacklight environment
- a DEDICATED processing queue : extracting styles and patterns of
  fluorescent body painting from the elves
- network kittens also carry fluorescence [ in a space overlay context ] --
  not addressed yet

## categories : elves first

- elves, kittens, stargates, deep space and other elements have direct
  parallels -- features adapt simply from one category to the other
- the elf category covers most of the main features for the others : build
  elves first, generalize by adapting, not by designing every category up
  front
- elves are complete [ or completable ] in expansion context : building them
  yields the infrastructure for the remaining categories -- moving to another
  category reuses it instead of adding new infrastructure. so the elf build
  must stay category-generic underneath [ rings, queues, addressing, analysis
  ] and elf-specific only on top [ palettes, body painting, face depth ]

## more categories [ user, 2026-09-29 ]

- planets, suns
- backgrounds and scenes -- shared by all other categories : forests,
  beaches, ocean, clouds .. used for scenes AND for ui elements
- povray for precise [ geometric, reproducible ] scene \ ui element parts :
  the povray zenka exists and works [ first implementation committed, used
  for the audio icon rendering -- not refined yet ] ; many povray
  references in the docs [ see the survey, `data/tasks/povray-zenka-
  implementation.md`, `audio-icon-povray-glass-cylinder-wrap.md` ]

## models : masks, quality, decisions [ user, 2026-09-29 ]

- classifier models generating image masks [ cats, humans, .. ] -- already
  written about [ `data/tasks/visual-mask-model-layer.md`, see the survey ]
- inference based quality assessment, corrections and decisions
- NO vision model running in parallel to invoke.ai : rendering runs are
  sustained for a while with the native \ lightweight detection and
  categorization [ histograms, hashes, 1x1 .. 3x3 colors, cheap classifiers ].
  batches alternate :
    render batch -> quality assessment + inference based corrections \
    decisions [ vision \ mask models, invoke.ai parked or drained ] ->
    next render batch using those decisions
- what the lightweight side should decide on its own, without a vision
  model wherever possible [ user, 2026-09-29 ] :
  - the exact reference image mix, chosen by MOMENTUM toward a target color
    bracket [ the color wheel position of the last renders vs the target
    arc -> pick references that pull in that direction ]
  - over- \ underexposure [ luminance histogram : clipped highs \ lows ]
  - obvious entropy based rendering errors [ noise \ banding \ flat or
    collapsed images : entropy far off the batch's normal range ]
  - LoRA overuse [ e.g. the same traits dominating across a batch, color
    \ structure distance collapsing between renders of different prompts ]
- the balanced feedback state [ user observation, 2026-09-29 ] : when all
  is in balance while the loop feeds on its own output, rendering
  stabilizes and only the QUALITY increases, with occasional new style
  emergence -- both detectable [ stable color \ structure distances + a
  rising quality score = stabilized ; a render far from all references but
  passing the quality gate = style emergence ]
- reference CHANNELS : technically 5 reference image channels. an improved
  render replaces the most similar reference image in its channel -- each
  channel upgrades its quality over time although its images are replaced
  automatically [ a channel = a slot keeping its role \ position, not a
  fixed image ]. emergence is the case where no channel is similar enough
  -> candidate for a new channel \ parallel variant branch
  [ cf. "parallel variant collection" in CONCEPT-HARMONIC-VISUAL-
  INTELLIGENCE.md ]
- THRESHOLD TRANSITIONS [ user observation over ~150 sequential render
  iterations, 2026-09-29 ] : even in the stabilized state there are overall
  thresholds. example : an elf with a natural skin color moving into a
  blacklight environment with body painting keeps the skin color for quite a
  while [ depending on the prompt, without accelerating mix-ins ] -- then a
  threshold is reached, the color drops FAST, the new main tone takes over
  and becomes stable itself. the same in style \ scene transitions and when
  picking up new elements
  - control points : before the threshold mix-ins accelerate or holding back
    keeps the old state ; after it the new state stabilizes and the channel
    replacement resumes
  - detection idea [ to verify on real iteration series ] : tipping points
    often show early signals -- the variance of the tracked value [ e.g. the
    skin region's 1x1 .. 3x3 colors ] rises render to render while its mean
    barely moves. measurable without a vision model
- predictability [ user, 2026-09-29 ] : the templates and context make the
  outcomes usefully predictable and plannable -- at least the outcome
  QUALITY. so these behaviours [ stabilization, quality rise, threshold
  transitions ] can be expected and relied on as the basis of the main
  features, not treated as lucky accidents. planning consequence : quality
  targets and transition points can be scheduled [ e.g. a queue plan with
  the expected plateau length per transition ], and deviations from the
  expectation are themselves a signal
- the user's conclusion : this level of control and depth over hundreds of
  iterations far exceeds what a single model rendering can do -- a true
  expansion of text-to-image rendering, native to the multi-agent framework
- the switching machinery exists in invoke-web [ 2026-09-29 ] : session park
  \ drain, the memory guard [ the other side waits for memory ],
  notify_offline to hand the memory over -- see
  `data/tasks/coding-invoke-awareness.md` for the same pattern with the
  coding zenka

## image analysis

- color histograms, histogram \ palette distance
- image distance detection [ perceptual hashes, structural, embeddings ]
- face detection + face distance [ character identity across iterations ]
- [ list was cut off in the conversation -- more to add ]

## own ui elements driving invoke.ai [ interim ]

- find images [ by color wheel position, similarity, palette, face, date,
  checksum ] and add them as references to a render [ ip adapter \ control
  inputs ] via the api
- assemble and enqueue renders from zenki [ invoke-web queue control :
  interactive mode puts them first ]
- gallery position \ selection kept on our side, per category -- invoke.ai's
  web ui keeps neither [ only layout lands in client_state ; every category
  switch starts at the top and reloads all thumbnails -- a weak point with
  40k+ images, user 2026-09-29 ]. not a blocker : our ui replaces it

## render control [ exists in invoke-web, reuse ]

- queue order [ newest \ oldest \ harmonic ], interactive mode, queue-front,
  parked sessions, drain, memory guard, requeue after missing models
  [ invoke-web, 2026-09-29 ]
- cold resume of parked sessions : build on
  `data/tasks/task-zenka-cold-queue-gpu-cooldown-trigger.md` [ gpu-temp
  cooldown gate, implementation plan already written ]

#,,.,,,,.,.,,,,.,,,.,,.,,,,.,,.,,,.,.,.,.,,..,..,,...,...,...,...,,..,,..,,,.,
#6GKGZFL37R42JIKFJL3MWWO6TUPKCCEJ7HG5AHWCL7DU5VBR4JUELJRZRCB4AHWSHBLS7O3T6LFD2
#\\\|56236WCUN3I56YCPUL47RONM522LXTN4Z4OL3YQI6MTJZ3E36YF \ / AMOS7 \ YOURUM ::
#\[7]TFFBBN3Z46MC5IRKND76L2BMDHGC6CMWGFGA5WZN652QWPKV6CBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
