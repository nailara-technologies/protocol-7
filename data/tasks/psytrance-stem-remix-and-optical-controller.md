# psytrance library : stem decomposition, dynamic remix, optical controllers

brief [ 2026-10-02 ]. on the list for ~20 years ; the tools now exist.
software first, hardware later.

## goal [ user ]

take a psytrance library apart into basslines and other elements and remix
it completely dynamically ; similarity sorting prepares fast switching
between members of the same or a compatible category. combined with
touchscreen interfaces and later midi-style hardware.

## phase 1 : decomposition and analysis

- **stems** : demucs [ open source, meta ; drums \ bass \ vocals \ other ]
  on the gpu. full-library runs are long full-load jobs -> after the fan
  repair or with a lowered power limit
  [ `data/ai-mem/claude/project-host-pc-warranty-until-2027-02.md` ]
- **analysis** : essentia or librosa -> tempo, beat grid, key, phrase
  boundaries [ psytrance : 4/4, ~138-148 bpm, 16 \ 32-bar phrases ]
- **storage** : stems as content-addressed segments [ checksum per stem,
  dedup across the library ] ; metadata per stem : bpm, key, phrase map,
  source track

## phase 2 : similarity

- audio embeddings per stem [ clap, openl3 or similar ] -> vectors
- similarity tree [ reference-tree style ] : same category = same stem
  type + close embedding ; compatible = tempo within stretch range + key
  compatible [ camelot wheel neighbors ]
- precompute nearest compatible neighbors so switching is instant

## phase 3 : live remix engine

- shared beat grid as the clock [ network clock analogy ]
- swaps only on phrase boundaries [ the "when" is predictable, the "what"
  open ]
- constant-power crossfades [ cos \ sin, cos² + sin² = 1 ] ; make-before-
  break handover between stems
- key matching \ time stretching where needed

## phase 4 : interfaces

- touchscreen first [ dark violet \ blue ui, calm defaults ]
- later hardware : magnetically balanced, hovering, translucent controls ;
  blacklight via fiber optics, fluorescent acrylic or resin, polarization
  and blue tint filters ; light translated into sensor values with no
  visible wires, and able to read the mixed result back
  - relevant physics : **photoelasticity** -- transparent plastics under
    polarized light show stress as color fringes ; a camera \ photodiodes
    behind crossed polarizers can read force and deformation optically
  - levitation position : hall sensors or optical tracking of the
    floating element

## later : physical crystal displays [ user, 2026-10-18 ]

the same base technology for the translucent crystal display surfaces
[ data/yaml/prompts/image/psytrance-network-kitten.yaml, layers.no_grey ] :
FREQUENCY TRANSPOSITION of uv light supplied through fiber optics.
- uv leds, fiber optics, neon fluorescent translucent foil ; external
  blue-grey and blue tinted foil layers -- the grey likely at least one
  polarization filter [ the darkening grey tint of the colour rules : a
  filter that only attenuates, with a blue bias, never grey light ]
- fluorescent ACRYLIC plates too [ cheap on ebay, comfortable sizes ].
  laser cutting by colour : a co2 laser [ 10.6 um ] is absorbed by the
  acrylic itself and cuts every colour ; a blue diode laser [ ~450 nm ]
  passes through clear, blue and violet plates and fails on exactly the
  colours wanted here. check the material is acrylic [ PMMA ] -- never
  laser-cut PVC [ chlorine gas ] ; polycarbonate cuts badly and burns
- inspiration [ user ] : the rectangular amiga power and disk leds -- an
  evenly lit flat face instead of a point. edge-lit fluorescent acrylic
  segments as their next generation : status lights that follow the
  no-point-source rule by construction
- reflection by shape [ user ] : square \ rectangular media reflect
  internally differently from round ones, and that matters in our
  topology. a square light pipe mirrors its source into a regular GRID
  of virtual images [ kaleidoscope ; why square and hexagonal mixing rods
  homogenize light and round ones do not ] -- the cubic lattice appears
  inside the material by itself. returns with the povray track [ photons,
  interior reflection ]
- holographic [ user ] : interlaced layers coexist in one medium, each
  seen from its own angle -- all it needs to always work is observer
  movement, likely with a tracked viewpoint. known relatives : lenticular
  and parallax-barrier displays, light-field displays, head-tracked
  "window" rendering. the rendered side has it too : a tracked viewpoint
  drives the camera rig [ reference roles ] and the crystal display reads
  differently from each side
- focal length as a tuning dial [ user ] : layers at different depths,
  the focus selects one -- a spatial channel, tuned in context like a
  radio station. angle picks the view, focus picks the depth. known
  relatives : refocusable light fields [ light-field cameras ], multi-
  layer and volumetric displays with real focus cues
- ONE device group [ user ] : the same plates are display, sensor and
  control surface at once, with a magnetic component -- e.g. magnetically
  balanced floating midi faders, fully translucent, read optically [ the
  controller hardware above : levitation, photoelasticity, readback ]
- readout without cameras [ user ] : cheap raspberry pi \ arduino colour
  sensors return the light's colour as a value [ e.g. TCS34725 rgb +
  clear, AS7341 with 11 spectral channels, i2c ] ; filter foil or plates
  in front set the range mapping as desired ; a fiber optic cable can
  carry the light to the sensor, so the sensing point needs no
  electronics. one sensor per channel, far cheaper than cameras
- uv and ir sensing [ user, 2026-10-18 ] : uv ccd cells are cheap too ;
  with ir in combination -- uv + ir cameras and calculated interference
  to visualize human auras, e.g. at a psytrance party. what each band
  measures : near-ir [ ~700-1000 nm, plain ccd \ cmos without the ir
  filter ] sees skin and fabric differently ; THERMAL ir [ 8-14 um, a
  microbolometer, cheap arrays like the MLX90640 32x24 ] sees body heat
  and the warm air rising around moving people -- a real field around
  each dancer ; uv sees fluorescence [ blacklight-lit clothing, skin ].
  the combination renders a live field per person. the data side has
  auras already : space.orbit.aura.build [ data/md/design/
  SPACE-ENGINE-MASTER.md, aura profiles from reference history ]
- variants : liquid resin and fluorescent ink, 3d printed structures ;
  tools needed : a laser cutter, a 3d printer
- when the funds allow ; the rendered versions come first

## later : the goa party use case [ user, 2026-10-18 ]

the system at a party : not only remixing but CREATING the sound [ the
user has ideas how ] -- full rhythm awareness, harmonizing algorithms in
context, the full psychedelic spectrum. audio systems then need capable
graphics cards -- because of OPTICAL AND SPATIAL TRANSLATION [ user ] :
the sound is light and optics in between, generated through spatial
fields ; magnetism likely plays a role, and even kinetics in
gravity-free space [ simulated motion as a sound source ], and field
effects in general [ interference, resonance, propagation ]. a musician can still lead [ user ] -- like FLY-BY-WIRE :
the musician steers intent, the system manages the realtime complexity
underneath [ rhythm, harmonizing, the stems and layers in context ] and
keeps it within what works. the genre this opens [ user ] : DEEP
[ HOLOGRAPHIC ] FRACTAL TRANCE -- goa-trance invented within goa-trance,
each layer a full piece of the style that can be opened further ; depth
through layering and slow change, not speed. the visuals : large hologram-like displays that adjust
to what THEY see [ the uv \ ir sensing above : the dancers' fields feed
back into sound and light ].

primitive display build [ user ] :
- two mosquito nets holding fluorescent grains, glued together with
  resin ; light supplied through fiber optics [ uv, as above ]
- each display is INITIALIZED by a mapping : cameras correlate every
  light strand and level with its target area and colour effect, which
  yields a translation matrix that maps the output onto the resolution
  the display really has [ irregular grain positions included ]
- known technique to build on : camera-based pixel mapping of irregular
  led installations and projector-camera calibration [ light one channel
  at a time or in coded patterns, find where it lands ] -- coded
  patterns [ binary \ gray code ] need log2 N frames instead of N
- re-initialize when the net is moved or a fiber shifts ; the cameras
  can also check the mapping live

## later : computing with the light itself [ user, 2026-10-02 ]

uv source + fiber optics + fluorescent color thresholds can also
CALCULATE : intensities and colors as values, fiber couplers as sums,
filters as weights, fluorescence thresholds as the nonlinear step -- the
formula hardwired in geometry and materials, finetuned by hand.
- prior art : photonic \ optical neural networks ; diffractive optical
  networks [ ozcan lab, ucla, 2018 : 3d-printed passive layers that
  classify at the speed of light ]
- known limits : a few bits of precision [ noise ], drift with
  temperature, fluorescent dyes bleach under uv over time -> needs
  recalibration and a reference channel, like the formation-as-reference
  principle

## rights

splitting and remixing one's own library for personal use is fine ;
publishing remixes of other artists' tracks needs their permission.

#,,..,.,,,,.,,.,,,,..,,,,,...,..,,...,.,.,,,.,..,,...,...,,,.,,.,,.,.,,..,,,,,
#3XP72KIFFY6DSGHP5SNU57RIOZXQEO3BNFP722ZX2QHOBNTI5Z57QMVKHNKF4NL5O7NBFQCTJOBPE
#\\\|TH2XZQJPEBTH6W5PIPZYSG6N2NL4UVM3NDTJPVNPV254G3MQXWQ \ / AMOS7 \ YOURUM ::
#\[7]HJZMVEOT5BMQZP7J7Y3DOZ66U23FVIVEK2C3VS7DJT7Y23KCCICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
