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

## audience rating [ user, 2026-09-29 ]

- a sophisticated distinction whether an image is safe for all audiences
  or not ; both are kept and treated SEPARATELY [ storage, queues, anything
  shown or exported ]
- transitions from one into the other are allowed internally, planned for
  and used a lot -- the rating is a property of each render, not of a
  whole iteration series
- tested by the user : the rendering queues alone, given enough iterations,
  can reliably ensure a category -- e.g. a portrait extraction queue that
  extracts elf characters from the entire dataset in really high quality,
  safe for all audiences
- so the rating must be checked per render and at every export \ display
  boundary, never inherited from a queue's intent alone [ a queue aiming at
  "safe" still needs the per-image check before anything leaves it ]

## drift detection \ recycling tags [ user, 2026-09-29 ]

- within the non-safe section further distinctions tag generations with a
  RECYCLING requirement : anatomical errors, age drift, bias not intended by
  the scene description or explicitly defined differently
- drift sources can be indirect : e.g. a kitten in a reference image makes
  the elf adopt slight feline features and get YOUNGER with each iteration,
  with no obvious source at first -- the source is the kitten. so the
  reference mix is a drift source to check, not only the prompt
- HARD RULE : a render with age drift in the non-safe section is never kept
  in recognizable form -- not even encrypted in the black box : it is shrunk
  to <= 3x3 IMMEDIATELY [ color values only ] or deleted, before any other
  step, and never enters a reference channel or any further processing
  [ the drift would carry into the next iteration ]. the age check is part
  of the per-image export \ display check, not only of the queue logic
- preemptive stabilization [ user-tested ] : queues aware of possible drifts
  counteract them up front -- phrases like "optimum age", "perfect anatomy"
  and further distinctions that make the elves more of a shamanic, spiritual
  expression than just a female humanoid with pointy ears. such additions
  strongly reduce anatomy errors and especially drifting or mismatching
  facial expressions -- a really functional stabilizing strategy
- DEFAULT PROMPT ATTRIBUTES [ user, 2026-09-29 ] : "optimum age" and
  "perfect anatomy" [ among other possible attributes ] belong in ALL
  rendering prompts involving elves -- for the quality level they give
  alone. build them into the elf prompt template as fixed parts, not as
  per-queue options that can be forgotten
- DESIGN PRINCIPLE [ user, 2026-09-29 ] : the default attributes control the
  overall drift and counteract biases of certain rendering sections or input
  [ obviously broken or unsafe input included ]. mix strategy +
  deduplication over the many renders stabilize the categories -- so for
  desirability you evaluate and fine-tune the CATEGORIES and their templates,
  and can ignore the input state : what can not be integrated only ends up
  as randomizing start entropy
  - limit 1 : "ignore the input" covers desirability \ quality, NOT the
    per-image output checks [ rating, exclusion parameters, age drift ] --
    those stay, they are what guarantees broken \ unsafe input never
    surfaces in the result
  - what "ignore the input" means [ user clarification ] : the queue is
    robust enough that even RANDOM internet images, given a long enough
    run, only produce results within the exact thresholds of all main
    categories they are fed into
  - the input is still filtered : by desirability selection from a larger
    batch [ e.g. an image search for elves -- the quality spread alone means
    only the best images, already close to the category, are chosen ], plus
    explicit exclusion \ downvoting criteria. do not rely on broad search
    terms alone
  - scoring with a STRICT cut-off is exclusion, not its absence : only the
    top results within a margin pass, so even a slight downvote drops whole
    categories of elements [ example : "mobile phones excluded" -- rendering
    them out once they emerge costs too many heavy inference iterations ]
  - safety = matching ALL shared requirements together ; that also catches
    outliers, legality included. NO single gate is generically safe : tested
    by the user -- vision models rated obviously unsafe images "safe for all
    audiences" out of admiration for their aesthetics, and only admitted
    after ~5 rounds of direct chat that a character was naked. a rule nailed
    onto one gate alone is loud, not safe -- defense in depth : selection
    margin + all category requirements + exclusion criteria + per-image
    output checks, none of them trusted alone
- detection without a vision model where possible : face distance to the
  character's anchor [ see face-anchored cells ] drifting in one direction
  over iterations flags identity \ age drift early ; reference images whose
  category differs from the scene [ e.g. a kitten reference in an elf queue ]
  flag a likely drift source before rendering

## recycling = shrinking, the self-sustaining dataset [ user, 2026-09-29 ]

- recycling works in BOTH directions :
  - upward = extraction [ in the character sense ], two modes : face
    extraction, and the optimum age upgrade -- in whichever scene context.
    the results all match the threshold bracket, or the queue is not done
    rendering yet. it renders to REPLACE the poor input imagery state
    without losing its integratable entropy
  - downward : the superseded images are kicked out into a recycling queue
    system that scavenges them for anything still usable -- isolating
    elements and feeding them into other queues. none of the actual pixels
    within the not accepted range survive
  - the downward path can only run automatically once the system can rely
    on having extracted all desirable elements for upgrading the categories
    it already has
  - EXCEPTION : age drift in the non-safe section is not scavenged either --
    the hard rule under drift detection applies [ immediately <= 3x3 or
    deleted, no isolation, no feeding into other queues ]
- tests show this is reachable by the number of translation steps alone,
  without necessarily a vision capable llm ; the safe for all audiences part
  also has more lightweight classifiers available. vision models still
  greatly enhance the system
- every raised [ improved ] image gets its lower quality predecessors dropped
- dropped is not deleted : predecessors shrink back into the 3x3, 2x2, 1x1
  sizes, with process steps in between -- e.g. element separation, mask
  based foreground removal and inpainting to complete a background, and
  other generic or more contextualized queues \ steps
- goal : a fully self-sustaining dataset that neither explodes in size nor
  loses context or data, kept in a desirable range from any perspective
- why it works : the desired minimum quality technically needs many
  iterations ; by then, with correctly defined queues, the result set has
  grown out of any fluctuation and out of its source state

## non-safe section : nested encrypted black box [ user, 2026-09-29 ]

- encrypted by default ; nested [ black boxes inside black boxes ] ; not
  transferable through the regular character sharing logic
- users never have to look at degenerated anatomy or anything matching an
  exclusion parameter for the result set -- those stay inside the box
- [ see the hard rule under drift detection : age drift is not kept inside
  the box either ]

## open data ingestion [ later, user, 2026-09-29 ]

- ingestion from image search engines -- not immediately : only once the
  queues themselves are reliably safe and stable
- ingested images pass the same per-image rating \ exclusion \ drift checks
  as renders before they enter any queue or reference channel ; source \
  licence metadata kept with them [ open question : which sources and
  licences are acceptable ]
- the user notes a philosophical side to character extraction and to
  recycling itself [ not yet written down ]

## characters : face-anchored cells [ user, 2026-09-29 ]

- face detection + face distance sorting "branch" the main characters : the
  renders belonging to one character form a CELL
- the extracted faces themselves are simple graphical anchors for matching
  and grouping all [ sub- ] styles and scenes of that character
- ties into the topology : a character cell is an arc bundle \ depth branch
  on the wheel ; the face is its anchor, the color angle its position

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

## scheduling by curves [ user, 2026-09-29 ]

- why the strict cut-off : available rendering time is a SCARCE resource.
  first the high quality categories must be saturated, then more high
  quality category items should keep appearing -- the fastest, least
  effort way is to let the queue system process and schedule them by all
  the parameters it has
- those parameters are curves, mapped onto \ compared with each other :
  curves and thresholds
- graph the parameters over queue runs ; visualize them and EDIT them
  visually : levels, thresholds, amplification, dampening, range brackets
- the curves are settings control AND a direct part of the state machine
  itself [ editing a curve changes the scheduler's behaviour, not a copy ]
- existing ground : `base.curve.compose` [ named in
  `vision-consensus-vote-as-curve-decision.md` as the continuous
  replacement for discrete winner decisions ],
  `topic-implicit-perspective-navigation` [ "curves \ thresholds ARE the
  nav decision" ], web-browser `graph-params` [ caught a real bug visually,
  `vision-environmental-param-graphing-correlation-convergence.md` ]

## render control [ exists in invoke-web, reuse ]

- queue order [ newest \ oldest \ harmonic ], interactive mode, queue-front,
  parked sessions, drain, memory guard, requeue after missing models
  [ invoke-web, 2026-09-29 ]
- cold resume of parked sessions : build on
  `data/tasks/task-zenka-cold-queue-gpu-cooldown-trigger.md` [ gpu-temp
  cooldown gate, implementation plan already written ]

#,,,.,.,,,.,,,.,.,.,.,,,.,.,.,,,.,,.,,,..,.,,,..,,...,...,..,,,,.,..,,,.,,.,.,
#ZDUT5ELNPPVZ77SN2C2USQJFUPDKQR5SGKSEWAR4ZDTCYNXEM73LZXSPJYJ6AYXTBLQISNYAD57T6
#\\\|M2VGMFAUKMBJ2UBVDSSNUGDZ2NOJD37CDQL7YWOTG2KSS2XKQVM \ / AMOS7 \ YOURUM ::
#\[7]N6J6VURJEILXCSN33BRPUMQ5KWM7G66YHC4TSAZBEZ4SJXAIXSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
