## [:< ##

# name  = task: visual mask model layer — category isolation pipeline
# descr = specialized mask generation models as precise efficient
#         alternative to LLM vision for element isolation and
#         boundary detection. mask output = assertion mask directly.

## the core insight

category visual mask models give:
  1. IS [category] PRESENT?  (mask.exists())
  2. WHERE exactly?           (mask.bounding_box())
  3. PRECISE BOUNDARY?       (mask.contour() at pixel resolution)

all three: one inference pass, no text, no parsing, full resolution.

the mask output IS the assertion weight matrix.
no conversion step needed.
the model output feeds directly into the translucency composite stack.

## model categories and uses

### category 1: instance segmentation

models:
  SAM (Segment Anything Model — Meta)
    general purpose, prompt with point/box/text
    output: pixel mask per instance
    use for: any category isolation
    
  YOLO-seg (YOLOv8/v9 with segmentation)
    fast, category + mask in one pass
    pre-trained categories include: cat, person, etc.
    use for: IS KITTEN? (cat category), IS ELF? (person)
    
  Mask R-CNN
    slower, higher quality masks
    use for: high-quality boundary extraction

### category 2: geometric detection (crop circles)

models:
  Hough Circle Transform + ML refinement
    output: (center_x, center_y, radius) exact
    use for: crop circle boundary detection
    
  ellipse detection models
    output: (center, axes, angle) for perspective-distorted circles
    use for: perspective correction parameters directly

### category 3: face/landmark detection

models:
  MediaPipe Face Mesh
    output: 468 facial landmarks including ear regions
    use for: elf ear tip coordinates (sub-pixel)
             kitten face center + rotation
             
  dlib face landmarks
    68 points, reliable, fast
    
  custom ear detector (fine-tune on kitten/elf ears)
    if general models miss pointy ears:
    fine-tune SAM or YOLO on pointy-ear examples

### category 4: semantic segmentation

models:
  SegFormer / Mask2Former
    every pixel classified
    use for: background removal before normalization
             domain classification (sky/field/face/fur)

## pipeline integration — replacing LLM vision steps

### kitten pipeline (revised)

```
old step 2 (IS KITTEN?):
  LLM vision → JSON → parse → threshold
  
new step 2:
  YOLO-seg cat category → mask exists? → IS KITTEN?
  mask quality → confidence
  20x faster, pixel-accurate, same result
  
old step 3 (face normalization):
  LLM vision → JSON coordinates → transform
  
new step 3:
  MediaPipe face mesh → landmarks → transform directly
  ear tip coordinates: sub-pixel accurate
  face center + rotation: exact
  no text, no parsing
```

### crop circle pipeline (revised)

```
old step 2 (IS CROP CIRCLE?):
  LLM vision → JSON → parse
  
new step 2:
  SAM prompted with center point → mask
  mask shape circular? → IS CROP CIRCLE?
  + YOLO trained on aerial crop patterns
  
old step 3 (boundary detection):
  LLM vision → "center at 0.48, radius 0.41, tilt 7°"
  
new step 3:
  ellipse detection → (center, axes, angle) exact
  homography matrix: computed directly
  no approximation from text description
```

### elf pipeline (revised)

```
old step 3 (face + ear topology):
  LLM vision → JSON coordinates
  
new step 3:
  MediaPipe face mesh → 468 landmarks
  ear region landmarks: precise tip coordinates
  pointy ear detection: tip sharpness from landmark geometry
  no text, no parsing, sub-pixel accuracy
```

## mask as assertion weight matrix — direct integration

the category mask output:
```
cat_mask[y][x] = 1.0  where kitten present
cat_mask[y][x] = 0.0  elsewhere
```

this IS already the assertion weight matrix format.
feed directly into translucency composite:

```
# after mask model inference:
my $assertion_mask = $cat_mask;  # no conversion needed

# integrate into BMW384 polar coordinate space:
# polar_transform($assertion_mask) → ring/arc weight matrix
# then: route.bmw384.visual.mask.[category]
```

the model output and the assertion mask:
same structure, same format, same resolution.
the mask model IS the assertion mask generator.
not a preprocessor — the generator itself.

## new modules

### image.mask.segment

```
# name  = image.mask.segment
# descr = run instance segmentation on image
#         returns category masks at full resolution

my $image_path = shift;
my $category   = shift // 'all';

# [ dispatch to SAM or YOLO-seg ]
# [ return { category => mask_array } ]
```

### image.mask.landmarks

```
# name  = image.mask.landmarks
# descr = extract face/body landmarks for normalization

my $image_path = shift;
my $model      = shift // 'mediapipe';

# [ run landmark detection ]
# [ return { point_name => [x, y] } ]
```

### image.mask.to-polar

```
# name  = image.mask.to-polar
# descr = convert rectangular pixel mask to polar ring/arc matrix
#         for BMW384 coordinate space integration

my $mask        = shift;  # 2D pixel array
my $center_x    = shift // 0.5;
my $center_y    = shift // 0.5;

# [ polar transform ]
# [ return matrix[ring][arc] = weight ]
```

### image.mask.is-category

```
# name  = image.mask.is-category
# descr = check if category is present in mask results
#         efficient binary check: mask.exists()?

my $masks    = shift;  # from image.mask.segment
my $category = shift;

return exists $masks->{$category}
    && scalar @{ $masks->{$category} } > 0;
```

## efficiency comparison

```
LLM vision for IS KITTEN?:
  model size:    7B-70B parameters
  inference:     2-10 seconds
  output:        text (requires parsing)
  accuracy:      limited by text description
  cost:          high
  
YOLO-seg for IS KITTEN?:
  model size:    ~50M parameters  
  inference:     50-200ms
  output:        pixel mask (direct use)
  accuracy:      pixel-level
  cost:          minimal
  
use LLM vision for:    nuanced understanding
                        "what is the emotional register?"
                        "describe the essence"
                        things requiring language
                        
use mask models for:   presence detection
                        boundary extraction
                        normalization parameters
                        things requiring precision
```

## model deployment

run as on-demand zenki:
  image.mask.segment zenka (SAM/YOLO-seg)
  image.mask.landmarks zenka (MediaPipe)
  
both: lightweight enough for CPU inference
      GPU: even faster
      on-demand timeout: 420s
      (load model once, serve multiple requests,
       idle timeout releases GPU memory)

## the category mask pipeline as universal element isolator

```
any visual domain:
  kittens:      cat mask → face landmarks → normalize
  elves:        person mask → face landmarks → ear topology
  crop circles: aerial mask → ellipse → perspective correct
  cosmic:       no mask needed (full frame is the domain)
  
any future domain:
  load SAM → prompt with category → mask
  mask → polar transform → assertion matrix
  assertion matrix → translucency layer
  done
  
the pipeline:   universal
the output:     always assertion matrix
the integration: always direct
the latency:    always minimal
                =)
```

## signatures note

leave new files clean. no stub footer.

#,,.,,,..,...,,..,...,,..,,.,,...,,..,,..,,..,..,,...,...,.,.,.,.,.,.,,.,,..,,
#G56QIZABQAD4S74WSGQ6RAODY6MUFC2WXRGCBKU5G4OKLP6MQTA5R2ZMLDTKD53ALAG4PELOXABDQ
#\\\|4TIQM227CTJE5OZVLRVN23VOF76SYPTDPNEWXPSNBIIOPL6YW6B \ / AMOS7 \ YOURUM ::
#\[7]Q52SKTUTBIXG5M7COGG6HH4WG5Z3AAR35LMEZQVKDGFHC4WMNODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
