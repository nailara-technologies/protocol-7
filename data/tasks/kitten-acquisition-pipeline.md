## [:< ##

# name  = task: kitten acquisition and harmonic calibration pipeline
# descr = yandex images → IS KITTEN? filter → normalize → group by
#         coat/expression/ear topology → composite eternal sweetie
#         template → deploy as T=5 ground truth calibration layer

## why kittens

kittens are the field's own T=5 ground truth:
- if the harmonic filter works correctly on kittens: it works
- if anything is T=5, a kitten is
- the purring carrier frequency: made visual
- the eternal sweetie template: made computationally concrete
- the remaining animal: the calibration corpus

any assertion mask that suppresses kittens is miscalibrated.
any system that returns T=5 on kittens: correctly grounded.
kittens are not the use case — kittens are the validation.

## pipeline overview

```
yandex images: "kitten" + variants
  → IS KITTEN? filter (young cat, clearly not adult)
  → normalize: face-centered, ear topology preserved
  → group: by coat pattern / expression / ear position
  → composite: canonical sweetie template per group
  → harmonic validation: kittens MUST return T=5
     (if they don't: recalibrate the filter, not the kittens)
  → deploy: purring carrier layer in translucency composite
  → iris overlay: kitten face at center void (position 27)
```

## step 1: acquisition

yandex image search adapter (from crop-circle-acquisition-pipeline.md)
query terms:
  "kitten" / "котёнок" / "Kätzchen" / "chaton"
  "baby cat" / "kittens pile"
  "kitten purring" / "sleeping kitten"
  "kitten ear" / "kitten face close up"
  (close-up face shots: best for ear topology extraction)

store raw: data/gfx/kittens/raw/[hash].jpg

## step 2: IS KITTEN? filter

lm-vision classification prompt:

```
is this image a kitten (young cat, clearly not an adult)?

return JSON:
{
  "is_kitten": true/false,
  "confidence": 0.0-1.0,
  "age_estimate": "newborn/young_kitten/older_kitten/adult",
  "ear_topology": "visible/partially_visible/not_visible",
  "expression": "purring/sleeping/playful/curious/other",
  "coat_pattern": "solid/tabby/calico/tuxedo/other",
  "notes": "brief"
}
```

threshold: confidence > 0.85 AND is_kitten = true
           AND age_estimate != "adult"

strict filtering: adults rejected
(adult cats: different pipeline, different calibration role)
(kittens specifically: the eternal sweetie template)

## step 3: normalize — face-centered, ear topology preserved

### 3a. face detection

lm-vision prompt:
```
locate the kitten face in this image.
return JSON:
{
  "face_center_x": 0-1 normalized,
  "face_center_y": 0-1 normalized,
  "face_radius": 0-1 normalized,
  "left_ear_tip_x": 0-1,
  "left_ear_tip_y": 0-1,
  "right_ear_tip_x": 0-1,
  "right_ear_tip_y": 0-1,
  "ear_angle": degrees between ears (from face center)
}
```

### 3b. normalize

- center on face
- scale so ear tips at ~80% of frame width
- rotate so ear midpoint = top center
  (ears always at top — the universal kitten orientation)
- output: 512×512 face-centered

the pointy ears: preserved precisely
(pointy ears = eternal sweetie template signature
 same template as the elves
 the alignment point between species)

## step 4: group by sweetie archetype

group dimensions:
  coat_pattern:  solid / tabby / calico / tuxedo / other
  expression:    purring / sleeping / playful / curious
  ear_position:  forward / sideways / flat / alert

each combination: a sweetie archetype
each archetype: its own composite

priority archetypes:
  1. purring + alert ears     (the council of 13 overwatch)
  2. sleeping + folded ears   (the temporary home at rest)
  3. curious + forward ears   (the field explorer)
  4. playful + sideways ears  (the dancing zenki)

## step 5: composite eternal sweetie template

per archetype group:
  align all members (face-centered helps enormously)
  mean-pool (soft composite — preserves fur texture)
  enhance: ear edges, eye catchlights, whisker lines

result: [archetype].sweetie.png
  the canonical representation of this archetype
  the eternal template made pixel-concrete

## step 6: harmonic validation — THE CRITICAL STEP

for each composite sweetie template:

apply is_true() to image data segments
IF any kitten composite returns T=FALSE:
  the harmonic filter is miscalibrated
  DO NOT adjust the kitten
  ADJUST THE FILTER

kittens ARE T=5 by definition
the filter exists to find what kittens are
not to judge whether kittens qualify

this step: the ground truth calibration
every other assertion mask is validated against:
"does this mask agree that kittens are T=5?"
yes: the mask is correctly oriented
no: the mask needs tuning

## step 7: deploy as purring carrier layer

the kitten assertion mask sits at a specific layer
in the translucency composite stack:

```
layer 0: base field          (neutral substrate)
layer 1: crop circle mask    (harmonic geometry filter)
layer 2: kitten layer        (T=5 ground truth calibration)
layer 3: popular flavour     (cluster preferences)
layer 4: personal config     (user preferences)
```

the kitten layer:
  raises weight of content that is T=5 adjacent
  (content near kitten archetypes in the field)
  provides the continuous purring carrier
  that keeps the field coherently warm

content that kittens would approve of: surfaces
content that kittens would be indifferent to: normal
content that kittens would hiss at: suppressed

## step 8: iris center void overlay

the iris visualization has a center void at (400,400) r=24
that is position 27 — the darksun.

overlay the primary purring sweetie composite there:
  the canonical purring kitten face
  at the center of the field visualization
  transparent enough to see through
  present enough to orient

the iris: becomes the living system map
with a kitten at the darksun
holding it all together
by being what it is

implementation: extend iris-logo-overlay.md task
  optionally: switch between nailara logo and kitten
  or: composite both (logo over kitten, both translucent)
  the kitten as the ground layer beneath the logo
  the eternal sweetie template beneath the brand

## output structure

```
data/gfx/kittens/
  raw/                    original downloads
  normalized/             face-centered 512×512
    purring/              by expression
    sleeping/
    playful/
    curious/
  composites/             canonical archetype images
    purring-alert.sweetie.png
    sleeping-folded.sweetie.png
    playful-sideways.sweetie.png
    curious-forward.sweetie.png
  masks/                  assertion weight matrices
    [archetype].mask.json

data/tasks/research-findings/kittens/
  acquisition-log.json
  archetypes.json         group registry
  calibration-log.json    which masks returned T=5
```

## new modules

### image.kitten.classify
  lm-vision wrapper for IS KITTEN? with expression + coat

### image.kitten.normalize
  face-center, ear-orient, 512×512

### image.kitten.archetype
  assign to sweetie archetype group

### route.bmw384.visual.mask.kitten
  the purring carrier assertion layer
  input: BMW384 coordinate
  output: warmth weight (how kitten-adjacent is this coordinate)

## validation query for any assertion mask system

```
load: any assertion mask
test: does it return T=5 on kitten composites?
      yes → correctly calibrated, proceed
      no  → miscalibrated, adjust mask not kittens
```

the kitten corpus: the universal calibration set
for any harmonic truth assertion system
at any scale
in any context
from minus to plus infinity

because: the field would be less without them
and the filter that doesn't know this
doesn't know what it's filtering
=)

## signatures note

leave new files clean. no stub footer.

#,,..,...,.,,,,,,,..,,.,.,.,,,,..,,,,,,,,,,,,,..,,...,...,..,,,,,,.,,,..,,.,.,
#GQPRPR7Y6SCIVJZVEULE3I2BSKQV627WURN4BRVS4BSMA7B3OWDIYI5LPVLKPW3YYRC7OHUMOD2LI
#\\\|7XMEQWPEG5HVQ5LQUPHUCZERP2GSWOMPH52UGFEH3FL4XZ7XV4Z \ / AMOS7 \ YOURUM ::
#\[7]DHQGY7PLVWKU65K4PERYS3KWA6ADKU3IY4IZBQWA3CLFZNTFXSBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
