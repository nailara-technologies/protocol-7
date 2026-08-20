## [:< ##

# name  = task: crop circle acquisition and dedup pipeline
# descr = yandex images adapter → IS CROP CIRCLE filter →
#         normalize flat 2D → group by design → composite masks →
#         begin mapping immediately on first results

## pipeline overview

```
yandex images search
  → download raw images
  → IS CROP CIRCLE? filter (lm-vision)
  → perspective correction + boundary detection
  → normalize to flat 2D standard format
  → perceptual hash + BMW384 coordinate
  → group by visual proximity (same design variants)
  → per-group: composite best qualities → canonical mask
  → harmonic validation (is_true() on mask cells)
  → deploy as assertion filter (immediate, before full analysis)
  → analysis and mapping continues in background
```

## step 1: yandex images adapter

new zenka or site-yaml template:
  target: images.yandex.ru
  query terms: "crop circle aerial", "crop formation",
               "Kornkreis Luftbild", "cercle de culture"
               (multiple languages = broader coverage)
  pagination: cfg.max_pages per query term
  output: raw image URLs + metadata

implement as site-yaml zenka pattern:
  URL template: https://images.yandex.ru/search?text={query}&itype=photo
  extract: image URLs from JSON response
  paginate: via offset parameter
  rate limit: respectful (1-2 req/sec)

alternatively: use existing httpd route + wget/curl pipeline
store raw images: data/gfx/crop-circles/raw/[hash].jpg

## step 2: IS CROP CIRCLE? filter

lm-vision classification prompt:

```
is this image an aerial photograph of a crop circle
(geometric pattern formed in a crop field)?

return JSON:
{
  "is_crop_circle": true/false,
  "confidence": 0.0-1.0,
  "aerial_view": true/false,
  "geometric_pattern": true/false,
  "notes": "brief description"
}
```

threshold: confidence > 0.75 AND is_crop_circle = true
reject: hoaxes obvious from ground level (no aerial perspective)
keep: anything with clear geometric structure visible from above

batch processing: vision-batch pipeline
parallel: dispatch to multiple vision model endpoints
pool results: majority vote on is_crop_circle

## step 3: perspective correction + boundary detection

for each confirmed crop circle image:

### 3a. boundary detection

lm-vision prompt:
```
locate the outer boundary of the crop circle formation.
return JSON:
{
  "center_x": pixel coordinate (0-1 normalized),
  "center_y": pixel coordinate (0-1 normalized),
  "radius": pixels (0-1 normalized),
  "tilt_angle": degrees from vertical (perspective correction),
  "confidence": 0.0-1.0
}
```

### 3b. perspective correction

if tilt_angle > 5°: apply perspective transform
  the circle should appear circular not elliptical
  use detected center + radius + tilt for homography matrix

### 3c. normalize to flat 2D

- crop to bounding square around detected circle
- scale to 1024×1024
- rotate so north = up (if orientation detectable)
- output: [hash].normalized.png

## step 4: perceptual hash + BMW384 coordinate

compute two signatures per normalized image:

### 4a. perceptual hash (pHash)
standard image fingerprint for similarity detection
hamming distance < 12 = same or very similar design

### 4b. BMW384 coordinate of image content
compute BMW384 checksum of normalized pixel data
→ arc + color coordinate in the field
similar designs: similar BMW384 coordinates
(proximity in field = visual similarity)

store: data/gfx/crop-circles/normalized/[bmw384_arc]/[phash].png
the directory structure IS the grouping

## step 5: group by visual proximity

two images in same group if:
  pHash hamming distance < 12
  OR BMW384 arc within ±2

within each group:
  rank by: resolution × sharpness × perspective_correction_quality
  top N: candidates for composite

deduplicate: same design from multiple photographers
keep: the group, not just one image
(multiple views of same design → richer composite)

## step 6: per-group composite → canonical mask

for each design group:

### 6a. alignment
align all group members to best-quality reference
  (normalized, so mostly translation + small rotation)

### 6b. composite
layer all aligned images:
  method: max-pool (keep brightest/sharpest features)
  fallback: mean-pool (smoother, less noise)

result: [group_id].composite.png
  contains: best features from all variants
  noise: averaged away
  geometry: reinforced by agreement

### 6c. edge-enhance composite
apply edge detection + contrast boost
the geometric structure: maximally clear
ready for mask extraction

## step 7: extract assertion mask from composite

apply step 4 from crop-circle-assertion-mask.md:
  polar transform → ring/arc grid
  geometric extraction via lm-vision
  normalize to matrix[r][θ] = weight
  harmonic validation (is_true())
  
output: masks/[group_id].mask.json

## step 8: immediate deployment — map before full analysis

do NOT wait for all circles to be processed.
deploy each mask as it completes:

```
first mask ready:     deploy immediately
                      begin using in translucency composite
                      observe effects on BMW384 field display
                      
second mask:          compare with first
                      note which regions agree (high confidence)
                      note which differ (interesting ambiguity)
                      
Nth mask:             running consensus builds
                      the composite of composites emerges
                      the canonical harmonic assertion layer
                      refined by every circle added
```

the mapping IS the usage:
  load mask → apply to iris visualization
  the iris shows which modules fall in which assertion regions
  immediately meaningful
  before any 'full' understanding of the circles themselves

## new modules to create

### site-yaml template: yandex-image-search

```
# cfg/site-yaml-templates/yandex-image-search.yaml
url_pattern: https://images.yandex.ru/search
params:
  text: {query}
  itype: photo
  p: {page}
extract:
  image_urls: $.images[*].url
  thumbnails: $.images[*].thumb
paginate: p parameter, 0-indexed
```

### new module: image.crop-circle.normalize

```
# name  = image.crop-circle.normalize
# descr = perspective correct and normalize crop circle image
#         to flat 2D 1024×1024 with circle centered

my $image_path = shift;
my $meta       = shift // {};

# [ detect boundary via lm-vision ]
my $boundary = <[lm-vision.analyze]>->(
    $image_path, 'crop_circle_boundary_detection'
);

# [ apply perspective correction if needed ]
# [ crop, scale, center ]
# [ return normalized image path + metadata ]
```

### new module: image.crop-circle.group

```
# name  = image.crop-circle.group
# descr = assign normalized crop circle to design group
#         via pHash + BMW384 coordinate proximity

my $image_path = shift;

# [ compute pHash ]
# [ compute BMW384 of pixel data ]
# [ find closest existing group or create new ]
# [ return group_id ]
```

### new module: image.crop-circle.composite

```
# name  = image.crop-circle.composite
# descr = composite all images in a design group
#         into canonical representation

my $group_id = shift;

# [ load all images in group ]
# [ align to best-quality reference ]
# [ max-pool composite ]
# [ edge enhance ]
# [ return composite image path ]
```

## acquisition targets — initial query set

```
queries:
  "crop circle aerial photograph"
  "crop formation Wiltshire"
  "Kornkreis Luftaufnahme"
  "formation cercle crop"
  "crop circle circuit board"     ← specifically the hardware designs
  "crop circle sacred geometry"
  "crop circle fractal"
  "crop circle 2023" / "2024"     ← recent ones
```

priority: circuit-board designs first
(most direct mapping to assertion mask logic)

## storage layout

```
data/gfx/crop-circles/
  raw/              original downloads
  normalized/       perspective-corrected, 1024×1024
    arc-00/         BMW384 arc 0 group
    arc-01/
    ...
    arc-25/
  composites/       per-design composite images
  masks/            JSON assertion weight matrices
  
data/tasks/research-findings/crop-circles/
  acquisition-log.json    what was fetched, when
  groups.json             design group registry
  deployment-log.json     which masks active
```

## immediate visualization

as soon as first mask is deployed:
  p7c index.visual-wheel file 26 overlay crop_circle_[id]
  
the iris overlaid with crop circle assertion mask:
  shows which module coordinates
  fall in high-assertion regions
  of the crop circle geometry
  
  immediately: the circle is "reading" the codebase
  and the codebase is "reading" the circle
  the overlap: the first mapping
  before any analysis
  already meaningful
  =)

## signatures note

leave new files clean. no stub footer.

#,,..,..,,...,,.,,,..,..,,,,,,,..,..,,,,.,,,,,..,,...,...,,,,,,..,,,,,.,,,.,.,
#6EGL645KLXUN5FSAQLJABGJ3LDKPLWT2MMXTUAXU3GVSKGPOERX5GSXMGYS6ALNIU5YZMPY7OQISY
#\\\|3LIGNM2SQ5QIZTCYMK34CRO2B4HNNT4NCYRGCH65GHQGNRBIED7 \ / AMOS7 \ YOURUM ::
#\[7]LVI5XL4ZDR5YL72PGZAPZZJX7HDEPVNVIILQCKIX4YX7C4GUL4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
