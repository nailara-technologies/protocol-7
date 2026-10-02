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

#,,.,,...,...,.,.,,..,,.,,,.,,.,.,,,.,.,,,..,,..,,...,...,..,,,,.,,,.,,.,,,..,
#UKDI74PZ2CEKMBLOBNBQZ334SPZJFKWQAMXSIQM73EJXNYG7JAMTWLHTZCC2J3KN6YRQEJDASOLXK
#\\\|HDQZDKGRTZCXIAAUVEFGKOFFQB52FCTRV6QMZ2CT6LCNDELISJT \ / AMOS7 \ YOURUM ::
#\[7]YHLAZMB7Z2O5Z3A6XVZODOZO4C7VNEXTTVNJHWTGHIYEWRN6NMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
