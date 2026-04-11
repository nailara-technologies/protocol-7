# Visual Element Deduplication — Holographic Quality Core

> *quality improves faster than size grows: the attractor wins.*

## Vision

Generative image systems produce content explosions. Every diffusion run at
similar prompts and styles yields thousands of near-duplicate variations —
same elf face at slightly different angles, same rendered screen in slightly
different light, same kitten on a slightly different pillow. Storing them
all is waste. Discarding them all loses style DNA.

This system solves both simultaneously. It detects semantic elements within
images, builds a similarity-attractor graph, deduplicates across viewing
angles, and composites the highest-quality overlapping regions into a
holographic data core that retains style and type information at peak
fidelity while shedding redundant low-quality instances. Through inpainting,
it also separates foreground elements from synthesized backgrounds, making
both freely recomposable. Harmony assertions (division by 13, cubic topology)
provide the weighted relevance tree that drives parameter selection at every
layer. This becomes the perceptual foundation of network vision.


## Problem Statement

### The Content Explosion

A generative session exploring a style (e.g. "luminescent elf in forest
environment") produces:
- N × angle variations (frontal, 3/4, profile, overhead)
- M × lighting variations (dawn, dusk, overcast, rim-lit)
- K × composition variations (portrait, full-body, environmental)
- quality variations across the N×M×K space

Total storage grows as O(N×M×K×file_size). Useful information grows as
O(styles × types × angle_coverage). The ratio diverges rapidly.

### The Quality Floor Problem

Naive deduplication by perceptual hash or cosine similarity discards content
indiscriminately. High-quality unique regions of a near-duplicate are lost
with the low-quality instance.

### The Style Portability Problem

Foreground elements (a specific elf face, a specific cat posture) are
entangled with their backgrounds. Separating them requires knowing where the
foreground ends — which requires understanding the element.

### The Desired Property

The system must be **self-sustaining**: as more content is ingested, the
core becomes more precise (not larger). Quality improves asymptotically.
The core can regenerate missing instances from style + type + angle
parameters. Low-quality instances can be evicted without loss.


## Architecture Overview

```
 ┌─────────────────────────────────────────────────────────────────┐
 │                      INPUT IMAGES                               │
 │           (invoke.ai output, imported collections)              │
 └──────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │  LAYER 1: ELEMENT DETECTION + SEGMENTATION                      │
 │  opencv / SAM / lm-vision → per-element masks + bounding boxes  │
 └──────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │  LAYER 2: SEMANTIC NODE CLASSIFICATION                          │
 │  type taxonomy · angle encoding · style fingerprint             │
 └──────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │  LAYER 3: SIMILARITY ATTRACTION GRAPH                           │
 │  elements as nodes · similarity as edge weight · tree formation │
 └──────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │  LAYER 4: ANGLE-BASED DEDUPLICATION + OVERLAP SCORING           │
 │  viewpoint grouping · spatial alignment · overlap precision map  │
 └──────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │  LAYER 5: HOLOGRAPHIC COMPOSITE SYNTHESIS                       │
 │  alpha = f(overlap_precision) · best-region selection           │
 │  → translucent layered composite = holographic data core        │
 └──────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │  LAYER 6: INPAINTING — FOREGROUND/BACKGROUND SEPARATION         │
 │  foreground mask → background completion → free composition     │
 └──────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │  LAYER 7: HARMONIC WEIGHTING TREE (÷13 · CUBIC TOPOLOGY)        │
 │  relevance scoring · parameter space · entropy acknowledgment   │
 └──────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │  OUTPUT: HOLOGRAPHIC CORE + LIBERATED ELEMENT LIBRARY           │
 │  parameterized by: type · style · angle · quality               │
 │  → foundation for network vision + relative optimization        │
 └─────────────────────────────────────────────────────────────────┘
```


## Layer 1: Element Detection and Segmentation

### Goal
Identify semantically meaningful regions within each image as discrete
elements with precise pixel masks. Elements are the atomic units of all
subsequent processing.

### Element Taxonomy (initial)

```
environment
├── background          (sky, terrain, architectural surfaces)
├── rendered_display    (screen, monitor, UI surface inside image)
└── lighting_source     (lamp, sun, bioluminescent glow)

character
├── face                (humanoid, human, creature — frontal/profile/3q)
│   ├── elf_face        (pointed ears, luminescent skin variants)
│   ├── human_face
│   └── creature_face
├── body_humanoid       (full body, torso, limbs)
├── body_part           (hand, wing, tail — isolated)
└── accessory           (worn/carried items)

creature
├── cat / kitten        (pose-classified: sitting, curled, alert)
├── mythic_creature
└── generic_animal

object
├── furniture
├── plant / flora
└── artifact
```

#### Expanded Taxonomy with Confidence Thresholds

The taxonomy above is refined to exactly 13 top-level categories (see
Layer 7 cubic mapping). Each category has a minimum confidence threshold
below which the element is reclassified as `unknown` and excluded from
the similarity graph until a higher-confidence classification is obtained.

```
category              conf_min   notes
──────────────────────────────────────────────────────────────────
background            0.70       large contiguous region, low detail variance
rendered_display      0.85       hard rectangular edges required
lighting_source       0.60       glow regions, may overlap background
elf_face              0.80       pointed ear + luminescence detection
human_face            0.80       standard facial landmark presence
creature_face         0.75       non-standard geometry permitted
body_humanoid         0.65       torso/limb presence, any species
body_part             0.60       isolated extremity, weak contextual signal
accessory             0.55       small, carried/worn, high ambiguity
cat_creature          0.75       pose classification sub-label required
mythic_creature       0.70       no standard landmark set available
flora_object          0.60       plant matter or non-animate artifact
abstract_element      0.50       runes, glyphs, patterns, energy effects
```

**Meaningful element**: an element is meaningful (included in the graph)
when `confidence >= conf_min` AND `mask_area / image_area >= 0.005`
(element occupies at least 0.5% of the image). Elements below the area
threshold are classified as `background_noise` and discarded.

**Nested elements**: an element may contain sub-elements (a rendered
display within a room contains UI elements; a character wears accessories).
Detection is recursive up to depth 2:

1. Detect top-level elements in the source image.
2. For each element with `mask_area / image_area >= 0.10` (occupies at
   least 10% of the image), run detection again on the masked crop.
3. Sub-elements receive a `parent_element_id` pointer. Their coordinates
   are stored relative to the parent mask bbox.
4. A sub-element's type must differ from its parent's type — if the same
   type is re-detected, it is the same element at higher confidence and
   the parent record is updated, not duplicated.

### Detection Methods

**Method A: OpenCV classical**
- Contour detection (Canny → findContours) for hard-edge elements
- SIFT/ORB feature keypoints for texture-rich regions
- Haar/LBP cascades for face detection
- Watershed segmentation for region separation
- Strengths: fast, deterministic, no GPU required
- Weaknesses: struggles with soft edges, stylized art styles

**Method B: SAM (Segment Anything Model) via lm-vision**
- Prompt-free mask generation across entire image
- Outputs ranked masks with confidence + stability scores
- Select masks above stability threshold, filter by area
- Best for: organic shapes, stylized/painterly content
- Weaknesses: may over-segment; requires vision model invocation

**Method C: Vision model with structured output**
- Prompt: "list all distinct visual elements, output bounding boxes and
  semantic labels as JSON"
- Model outputs element list; refine with SAM masks
- Best for: semantic labeling (distinguishing elf face from human face)
- Weaknesses: latency, cost, non-deterministic

**Method D: Hybrid pipeline** (recommended)
1. SAM → raw masks + bounding boxes
2. lm-vision classification of each masked crop → semantic type
3. OpenCV feature extraction within each mask → keypoint descriptors
4. Combine: mask (SAM) + type (vision) + descriptor (opencv)

#### SAM Integration Specification

**Mode**: automatic mask generation (no point/grid prompts). SAM's
`SamAutomaticMaskGenerator` is invoked via the lm-vision zenka, which
wraps the model behind its inference API.

**Parameters**:
```
points_per_side       = 32        # grid density for auto mode
pred_iou_thresh       = 0.86      # predicted IoU filter
stability_score_thresh = 0.90     # mask stability filter
min_mask_region_area  = 100       # minimum pixels (removes dust)
```

**Mask quality score**:
```
mask_quality(m) = m.stability_score × clamp(m.area / image_area, 0.005, 1.0)
```
where `clamp(x, lo, hi) = max(lo, min(hi, x))`. This biases toward
masks that are both stable (SAM's internal consistency metric) and
non-trivial in size. Masks with `mask_quality < 0.45` are discarded.

**Vision model structured output format** (JSON, one per masked crop):
```json
{
    "type": "elf_face",
    "confidence": 0.94,
    "angle_estimate": { "yaw": 15.0, "pitch": -5.0, "roll": 2.0 },
    "description": "luminescent elf face, 3/4 view, warm lighting",
    "style_tags": ["luminescent", "warm", "painterly"]
}
```
The vision model is prompted with: "classify this image crop. output
JSON with fields: type (from taxonomy list), confidence (0-1),
angle_estimate (yaw/pitch/roll in degrees, null if not applicable),
description (one sentence), style_tags (list of 1-5 adjectives)."

**Mask-to-element data structure** (stored per image as JSON):
```perl
{
    'image_id'      => $amos_chksum_of_image_bytes,
    'image_path'    => $abs_path,
    'image_dims'    => [$width, $height],
    'detected_at'   => $epoch_timestamp,
    'element_count' => scalar(@elements),
    'elements'      => [
        {
            'element_id'        => $amos_chksum_of_mask_rle_concat_type,
            'parent_element_id' => undef,   ## or parent's element_id
            'type'              => 'elf_face',
            'confidence'        => 0.94,
            'mask_rle'          => $run_length_encoded_binary_mask,
            'mask_quality'      => 0.87,
            'bbox'              => [$x, $y, $w, $h],
            'bbox_relative'     => [$x/$img_w, $y/$img_h,
                                    $w/$img_w, $h/$img_h],
            'crop_path'         => "$elements_dir/$element_id.png",
            'descriptors'       => $opencv_keypoint_descriptor_matrix,
            'angle'             => { 'yaw' => 15.0, 'pitch' => -5.0,
                                     'roll' => 2.0 },
            'quality'           => $quality_score,   ## from Layer 2
            'style_fingerprint' => $style_vector,    ## from Layer 2
            'style_tags'        => ['luminescent', 'warm', 'painterly'],
        },
        ...
    ]
}
```
Storage location: `$data_zenka_root/vision/elements/$image_id.json`,
with crops in `$data_zenka_root/vision/crops/$element_id.png`.

### Output per Image

```perl
{
    'image_id'   => $amos_checksum,
    'image_path' => $abs_path,
    'elements'   => [
        {
            'element_id'   => $element_checksum,   ## amos chksum of mask+type
            'type'         => 'elf_face',
            'confidence'   => 0.94,
            'mask'         => $mask_rle,            ## run-length encoded
            'bbox'         => [$x, $y, $w, $h],
            'crop_path'    => $cropped_element_path,
            'descriptors'  => $opencv_keypoint_vec, ## for similarity matching
            'angle'        => $estimated_yaw_deg,   ## -180..180
            'quality'      => $quality_score,       ## 0..1
        },
        ...
    ]
}
```


## Layer 2: Semantic Node Classification

### Angle Encoding

Viewing angle is a primary deduplication axis. Two instances of the same
elf face at 45° and 315° are *not* duplicates — they are complementary
views that together build a richer 3D model of the element.

#### Angle Estimation Pipeline

**Method selection** by element type:

1. **Structured faces** (elf_face, human_face, creature_face with
   detectable landmarks): OpenCV `solvePnP` with a 3D reference model.
   - Detect 68 facial landmarks (dlib) or 478 landmarks (MediaPipe).
   - If landmark count < 10 with confidence > 0.5, fall through to
     method 2.
   - Solve perspective-n-point using 6 stable landmarks (outer eye
     corners, nose tip, mouth corners, chin) against a canonical 3D
     face model.
   - Output: rotation vector → Rodrigues → yaw, pitch, roll in degrees.
   - Accuracy: ±5° for frontal-to-profile range, degrades beyond ±80° yaw.

2. **Stylized/abstract faces** (landmark detection fails): vision model
   query with structured output.
   - Prompt: "estimate the viewing angle of this face/element. output
     JSON: {yaw: degrees, pitch: degrees, roll: degrees, confidence: 0-1}"
   - If confidence < 0.3, assign `angle = null` (angle-agnostic element).

3. **Non-face elements** (body, creature, object): SIFT keypoint geometry.
   - Extract keypoints from the element crop.
   - If ≥ 20 keypoints: compute the principal axis of the keypoint
     distribution via PCA on keypoint positions. The angle of the first
     principal component relative to the horizontal is used as a 1D angle
     proxy (0°..180°). Yaw and pitch are set to null.
   - If < 20 keypoints: assign `angle = null`.

4. **Abstract elements** (runes, textures, energy effects): `angle = null`.
   These are angle-agnostic and are never deduplicated by angle — they
   cluster by type and style only.

**Canonical representation**: angles are stored as the full triple
`(yaw, pitch, roll)` but bucketed using yaw alone as the primary axis,
since yaw captures the most perceptually significant variation for
deduplication. Pitch and roll are secondary sorting keys within a bucket.

**Bucket sizes**:
- **Coarse bucket** (for initial clustering): 360° / 13 ≈ 27.69° per
  bucket, giving exactly 13 coarse buckets aligned with the cubic
  topology. Bucket index = `floor((yaw + 180) / 27.69) % 13`.
- **Fine bucket** (for deduplication within a coarse bucket): 27.69° / 5
  ≈ 5.54° per fine bucket, giving 5 fine divisions within each coarse
  bucket. Elements in the same fine bucket are deduplication candidates.
  Elements in different fine buckets within the same coarse bucket are
  complementary views.

**Angle uncertainty**: stored as a confidence interval:
```
angle_uncertainty = {
    'yaw_range'   => [$yaw - err, $yaw + err],
    'confidence'  => $detection_confidence,
    'method'      => 'solvePnP' | 'vision_model' | 'pca' | 'null'
}
```
where `err` is: 5° for solvePnP, 15° for vision_model, 20° for PCA.

**180° ambiguity** for symmetric elements: elements with bilateral
symmetry (e.g. a frontal face, a symmetric vase) cannot distinguish
yaw = θ from yaw = -θ. Detection: if `|yaw| < 10°` and the element type
is marked as `potentially_symmetric` in the taxonomy, compute the
mirror-SSIM (SSIM between the crop and its horizontal flip). If
`mirror_SSIM > 0.90`, the element is classified as `symmetric` and its
yaw is clamped to `[0°, 180°]` (only positive half-space), with the
coarse bucket index computed as `floor(yaw / (180/13)) % 13`. This
halves the angle space for symmetric elements, reflecting the genuine
information content.

### Style Fingerprinting

Elements of the same *type* from the same generative *style* form natural
clusters. Style is encoded independently of content.

#### Style Fingerprint Definition

The style fingerprint is a fixed-length vector capturing visual treatment
independently of spatial layout, pose, or angle. It is computed from
three components concatenated into a single vector:

**Component 1: color palette histogram** (48 dimensions)
- Convert the masked crop to HSV color space.
- Quantize: H into 16 bins (22.5° each), S into 3 bins (low/mid/high
  at thresholds 0.2 and 0.6), V into 1 bin (collapsed — value is
  lighting-dependent and handled separately by quality scoring).
- Histogram: 16 × 3 = 48 bins, L1-normalized to sum to 1.0.
- This captures the color palette independent of where colors appear.

**Component 2: texture descriptor** (40 dimensions)
- Convert to grayscale.
- Apply a Gabor filter bank: 8 orientations × 5 frequencies
  (wavelengths λ = 4, 8, 16, 32, 64 pixels).
- For each filter response, compute the mean energy (mean of absolute
  response values within the mask).
- Result: 8 × 5 = 40 scalar features, capturing stroke texture at
  multiple scales and directions. L2-normalized.

**Component 3: frequency signature** (16 dimensions)
- Compute 2D DCT of the grayscale crop resized to 32×32.
- Extract the lowest 16 AC coefficients in zigzag order (excluding the
  DC coefficient, which encodes mean brightness).
- L2-normalize.

**Full fingerprint**: concatenation of the three components:
`style_vector = [color_48 | texture_40 | frequency_16]` — 104 dimensions.

**Distance metric**: cosine distance.
```
style_distance(A, B) = 1 - (A · B) / (|A| × |B|)
```
Range: 0 (identical style) to 2 (anti-correlated, theoretical maximum).
In practice, style_distance > 1.0 does not occur for real images.

**Threshold**: `style_distance < 0.25` → same style cluster.
`0.25 ≤ style_distance < 0.50` → related style (may share a parent in
the style tree). `style_distance ≥ 0.50` → unrelated styles.

**Disambiguating same-style-different-element vs same-element-style-variation**:
the style fingerprint alone cannot make this distinction — that is the
role of the visual descriptor match (SIFT/ORB keypoints) in the
similarity metric (Layer 3). Two elements with `style_distance < 0.25`
AND `keypoint_match_ratio > 0.40` are the same element in the same style.
Two elements with `style_distance < 0.25` AND `keypoint_match_ratio < 0.15`
are different elements in the same style. The intermediate zone
(0.15 ≤ match_ratio ≤ 0.40) is ambiguous and resolved by type match
(different types cannot be the same element) or by human/model review
flagged via the anomaly detection system (Layer 7 network vision).

### Quality Scoring

Each element crop receives a quality score used for composite selection.

Components:
- **sharpness**: Laplacian variance of the masked region
- **artifact_free**: absence of JPEG blocking, diffusion artifacts
  (detectable via high-frequency noise analysis)
- **coverage**: fraction of element that is unoccluded
- **resolution**: effective pixel density within mask bbox
- **harmony**: harmonic truth assertion on the element's checksum

#### Quality Score Formula

```
quality_score = w_s × sharpness_norm
             + w_a × artifact_free_score
             + w_c × coverage
             + w_r × resolution_norm
             + w_h × harmony_score

where:
    w_s = 0.30    sharpness weight
    w_a = 0.25    artifact-free weight
    w_c = 0.20    coverage weight
    w_r = 0.15    resolution weight
    w_h = 0.10    harmonic weight
```

**sharpness_norm**: Laplacian variance of the masked region, normalized:
```
lap_var = variance(Laplacian(grayscale_crop, ksize=3))
sharpness_norm = clamp(lap_var / 1500.0, 0, 1)
```
The divisor 1500 is calibrated so that a well-focused 1024×1024 diffusion
output scores ~0.8. Values above 1500 are clamped to 1.0.

**artifact_free_score**: high-frequency noise analysis.
```
hf_energy = sum(abs(DCT_coefficients[i,j]) for i+j > 48) / total_energy
artifact_free_score = 1.0 - clamp(hf_energy / 0.15, 0, 1)
```
Clean images have low high-frequency energy ratios (< 0.05). JPEG
blocking and diffusion checkerboard artifacts elevate this ratio.

**coverage**: fraction of the element that is unoccluded.
```
coverage = mask_pixel_count / bbox_area
```
A fully visible element in a tight bbox scores ~1.0. Partial occlusion
by other elements or image edges reduces this.

**resolution_norm**: effective pixel density.
```
resolution_norm = clamp(sqrt(bbox_area) / 512.0, 0, 1)
```
An element bbox of 512×512 or larger scores 1.0. Smaller elements score
proportionally less. The square root ensures diminishing returns.

**harmony_score**: harmonic truth assertion on the element's checksum.
```
harmony_score = AMOS7::Assert::Truth::is_true($element_checksum) ? 1.0 : 0.0
```
where `$element_checksum` is the AMOS checksum of the mask RLE
concatenated with the type string. Since `is_true` returns TRUE (5) or
FALSE (0), the harmony component is binary: harmonically resonant
elements receive a 0.10 quality bonus, non-resonant elements receive
none. This means that among otherwise-equal elements, harmonically
true elements are preferentially retained — the system naturally
accumulates resonant configurations.

**Quality tiers**:
```
tier              range              behavior
──────────────────────────────────────────────────────────
high              0.75 ≤ q ≤ 1.00   retained, contributes to composite
acceptable        0.45 ≤ q < 0.75   retained until higher-quality replacement
evictable         0.00 ≤ q < 0.45   evicted once any same-bucket element
                                     scores ≥ 0.60
```


## Layer 3: Similarity Attraction Graph

### Graph Structure

Elements are nodes. Directed weighted edges represent similarity
relationships. The graph is the primary deduplication data structure.

```
Node: element_id → { type, angle_bucket, style_fingerprint, quality,
                      source_image_id, crop_path, descriptors }

Edge: (element_a, element_b) → {
    similarity_score  : 0..1,
    angle_delta       : degrees,
    style_distance    : 0..1,
    overlap_precision : 0..1   ## populated in layer 4
}
```

### Similarity Metric

#### Composite Similarity Metric

```
similarity(A, B) =
    type_gate(A, B) × (
        w_style  × style_sim(A, B)
      + w_visual × visual_match(A, B)
      + w_angle  × angle_sim(A, B)
    )
```

**Component 1 — type gate** (hard gate, multiplicative):
```
type_gate(A, B) = 1  if A.type == B.type
                = 0  otherwise
```
Elements of different types produce similarity = 0 regardless of visual
resemblance. This prevents cross-type false matches (an elf face cannot
be "similar to" a cat, even if their crops share color palette).

**Component 2 — style similarity** (w_style = 0.30):
```
style_sim(A, B) = (1 + cos(A.style_vector, B.style_vector)) / 2
```
Range [0, 1]. Cosine similarity is shifted from [-1,1] to [0,1].

**Component 3 — visual descriptor match** (w_visual = 0.50):
```
keypoints_A = SIFT_detect(A.crop)
keypoints_B = SIFT_detect(B.crop)
matches = BF_match(keypoints_A.descriptors, keypoints_B.descriptors)
good_matches = [m for m in matches if m.distance < 0.75 × m.next_best]
visual_match(A, B) = min(len(good_matches) / max(len(keypoints_A),
                                                   len(keypoints_B)), 1.0)
```
Lowe's ratio test at threshold 0.75. The fraction of matched keypoints
is the visual match score. If either element has < 5 keypoints (textureless
region), fall back to SSIM on aligned crops resized to 128×128:
```
visual_match_fallback(A, B) = max(SSIM(resize(A.crop), resize(B.crop)), 0)
```

**Component 4 — angle similarity** (w_angle = 0.20):
```
angle_delta = |A.yaw - B.yaw|  (circular distance, max 180°)
angle_sim(A, B) = max(1.0 - angle_delta / 90.0, 0)
```
Elements at the same angle (delta = 0) score 1.0. Elements at 90° or
more apart score 0. This means similar-angle elements get the full
deduplication signal, while complementary views (>90° apart) contribute
zero angle similarity — their overall similarity comes only from style
and visual match, which correctly identifies them as related but not
duplicate.

If either element has `angle = null`, `angle_sim` defaults to 0.5
(neutral — cannot confirm or deny angular proximity).

**Edge creation threshold**: `similarity(A, B) >= 0.55`.
Below this threshold, no edge is created — the elements are considered
unrelated for deduplication purposes.

**Max edges per node**: 26 (= 3³ - 1, the number of neighbors of a
cube cell in the 13³ topology). When a node exceeds 26 edges, the
lowest-similarity edges are pruned. This bounds the graph to O(26N)
edges for N nodes.

**Clustering algorithm**: hierarchical agglomerative clustering with
**average linkage** on `similarity_score`. Average linkage is preferred
over single linkage because single linkage produces elongated chains
that conflate unrelated elements bridged by intermediaries. Average
linkage requires genuine cluster-wide similarity.

Cut threshold: 0.55 (same as edge creation). Clusters whose inter-cluster
average similarity drops below 0.55 are not merged.

The result is a dendrogram. Each cluster at the cut level becomes a
subtree in the similarity graph. The root of each subtree is the
element with the highest quality score in the cluster.

### Tree Formation

Similar elements cluster into subtrees. The subtree root is the
highest-quality element of the cluster. Children are variants.

```
elf_face (cluster root — highest quality)
├── variant [angle: -15°, quality: 0.91]
├── variant [angle:   0°, quality: 0.98]  ← root
├── variant [angle: +12°, quality: 0.87]
└── variant [angle: +45°, quality: 0.73]
```

#### Tree Balancing and Merge Logic

**Insertion of a new element**:
1. Compute similarity to all existing cluster roots (bounded by
   type gate — only roots of matching type are queried).
2. Let `best_sim = max(similarity(new, root_i))` across all roots.
3. Cases:
   - `best_sim >= 0.55` and only one root qualifies: insert into that
     cluster as a child of the root.
   - `best_sim >= 0.55` and multiple roots qualify (the new element is
     similar to K > 1 clusters): **merge** those K clusters into a single
     cluster. The root of the merged cluster is the element with the
     highest quality across all K clusters plus the new element.
   - `best_sim < 0.55`: the new element starts a new single-node cluster
     with itself as root.

**Root promotion**: when a new child's quality exceeds the current root's
quality, the root pointer is updated. The old root becomes a child.
No structural rebalancing is needed — the tree is quality-ranked, not
depth-balanced. The root's role is purely "best representative of the
cluster," not a structural pivot.

**Cluster merge**: when two clusters C₁ and C₂ are merged:
1. All nodes from C₂ become children of C₁'s root (or vice versa if
   C₂'s root has higher quality).
2. Edge weights between the newly combined nodes are computed lazily —
   only edges involving former C₂ nodes and C₁ nodes are evaluated, on
   first access or during the next compositing pass.

**Storage format**: namespace tree under the data zenka.
```
vision.graph.clusters.$cluster_id.root         = $element_id
vision.graph.clusters.$cluster_id.type         = 'elf_face'
vision.graph.clusters.$cluster_id.children     = [$id_1, $id_2, ...]
vision.graph.clusters.$cluster_id.quality_max  = 0.98
vision.graph.clusters.$cluster_id.angle_range  = [-45, 90]
vision.graph.elements.$element_id.cluster      = $cluster_id
vision.graph.elements.$element_id.quality      = 0.94
vision.graph.elements.$element_id.source_image = $image_id
```

This mirrors the fractal compression principle from
FRACTAL-DEDUPLICATION-AWARENESS.md: at the content layer, files deduplicate
to checksum references; at the semantic layer, visual elements deduplicate
to cluster references. The compression is the same — store difference
from the cluster root (the composite), not the full element. Each level
of the fractal uses a shorter address (cluster_id) to reference a richer
semantic context (all elements that cluster together form the composite's
"definition").


## Layer 4: Angle-Based Deduplication and Overlap Scoring

### Viewpoint Grouping

Within a similarity cluster, elements are grouped by angle bucket. Within
an angle bucket, elements are candidates for deduplication and compositing.
Across angle buckets, elements are complementary — both are kept.

#### Angle Bucket Classification

Within a similarity cluster, elements are assigned to angle buckets
using the fine-bucket system from Layer 2:

```
fine_bucket_width  = 360° / (13 × 5) = 5.54°
coarse_bucket_width = 360° / 13 = 27.69°
```

**Deduplication candidates**: elements in the **same fine bucket**
(angle delta < 5.54°). These are near-duplicate views that should be
composited together. Within a fine bucket, pixel-level alignment is
meaningful and overlap scoring proceeds.

**Complementary views**: elements in **different fine buckets but the
same coarse bucket** (5.54° ≤ delta < 27.69°). These are kept as
distinct angle representations. They contribute to the element's
angle coverage but are not composited together.

**Independent views**: elements in **different coarse buckets**
(delta ≥ 27.69°). These represent substantially different perspectives.
Both are retained. Their relationship is tracked in the cluster for
angle-coverage analysis but no compositing or deduplication is attempted.

**Edge cases**:

*Symmetric elements* (mirror_SSIM > 0.90, per Layer 2): the angle space
is halved to [0°, 180°]. Fine bucket width becomes 180° / (13 × 5) =
2.77°. The dedup threshold remains "same fine bucket."

*Unreliable angle estimation* (angle = null, or confidence < 0.3):
these elements are placed in a special **angle-agnostic bucket** that
exists once per cluster. Elements in the angle-agnostic bucket are
deduplication candidates with ALL other elements in the cluster — they
are composited with whichever fine bucket they overlap most via visual
descriptor matching (highest keypoint match ratio determines the best
alignment partner). Once composited, the angle-agnostic element inherits
the bucket assignment of its best match.

### Spatial Alignment

Before overlap scoring, crops within the same angle bucket are spatially
aligned (registered). This removes translation, scale, and minor rotation
differences so that pixel-level comparison is meaningful.

#### Spatial Alignment Algorithm

Three methods, selected by element type and keypoint availability:

**Method 1: landmark-based affine** (faces with ≥ 5 landmarks detected)
- Canonical positions (in a 256×256 reference frame):
  left_eye_center = (76, 100), right_eye_center = (180, 100),
  nose_tip = (128, 160), mouth_center = (128, 200).
- Compute the similarity transform (rotation + uniform scale +
  translation) mapping detected landmarks to canonical positions.
  Use `cv2.estimateAffinePartial2D` (4 DOF, avoids shearing).
- Apply the transform to the full crop, outputting a 256×256 aligned face.

**Method 2: keypoint homography** (elements with ≥ 8 SIFT keypoints)
- Match keypoints between the source crop and the reference (the current
  cluster root's crop, or the existing composite).
- Compute homography via RANSAC: `cv2.findHomography(src_pts, dst_pts,
  cv2.RANSAC, ransacReprojThreshold=5.0)`.
- Minimum inlier count: 8. Minimum inlier ratio: 0.30.
- Warp the source crop to the reference geometry.

**Method 3: ECC maximization** (textureless elements, < 8 keypoints)
- Resize both crops to 128×128 grayscale.
- Compute the ECC-optimal affine warp: `cv2.findTransformECC(
  ref_gray, src_gray, warp_matrix, cv2.MOTION_AFFINE,
  criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 200, 1e-6))`
- ECC correlation coefficient is returned as alignment confidence.

**Alignment failure**: if the best method's confidence metric falls below
its threshold (affine residual > 15 pixels RMS; RANSAC inlier ratio
< 0.30; ECC correlation < 0.5), the alignment is rejected. The element
is reclassified as belonging to a **different fine bucket** — its angle
estimate is adjusted by +/- one fine bucket width (5.54°) in the
direction of lower residual, and it is re-evaluated for deduplication
in the adjacent bucket. If alignment fails in all adjacent buckets, the
element remains in the cluster but is not composited — it contributes
only to angle coverage metadata.

### Overlap Precision Map

After alignment, compute a per-pixel overlap precision map: at each pixel
position, which source image contributes the highest quality data?

```
overlap_precision[x,y] = max_quality_source_at(x,y)
alpha[x,y] = overlap_precision[x,y] * coverage_weight[x,y]
```

#### Overlap Precision Map — Detailed Specification

**coverage_weight[x,y]**: the number of aligned sources whose mask
includes pixel (x,y), normalized:
```
coverage_weight[x,y] = count_of_sources_covering(x,y) / total_sources
```
Range [0, 1]. A pixel covered by all N aligned sources has
coverage_weight = 1.0.

**Per-pixel quality** (local_quality[i][x,y] for source i):
```
local_sharpness = variance(Laplacian(src_i_gray, ksize=3),
                           window=11×11 centered at (x,y))
local_noise     = median_absolute_deviation(
                           src_i_gray[y-5:y+5, x-5:x+5])
local_quality[i][x,y] = clamp(local_sharpness / 500.0, 0, 1)
                       × clamp(1.0 - local_noise / 40.0, 0, 1)
```
The 11×11 Laplacian variance captures local sharpness. The 11×11 MAD
captures local noise. Their product favors sharp, clean regions.

**overlap_precision[x,y]**: the index of the source with the highest
local quality at each pixel:
```
best_source[x,y] = argmax_i(local_quality[i][x,y])
overlap_precision[x,y] = local_quality[best_source[x,y]][x,y]
```

**alpha[x,y]**: compositing weight for each pixel:
```
alpha[x,y] = overlap_precision[x,y] × coverage_weight[x,y]
```
Pixels where multiple high-quality sources agree have alpha near 1.0.
Pixels covered by only one low-quality source have low alpha.

**Data structure**: a float32 single-channel image, same dimensions as
the aligned crop (256×256 for faces, or the reference crop size for other
element types). Stored at:
```
$data_zenka_root/vision/composites/$cluster_id/$fine_bucket/precision.f32
```
alongside the composite image and metadata JSON.

**Incremental update**: when a new source is aligned and added, the
precision map is recomputed only for pixels where the new source's
`local_quality` exceeds the existing `overlap_precision`:
```
for each pixel (x,y) covered by new_source:
    if local_quality[new][x,y] > overlap_precision[x,y]:
        overlap_precision[x,y] = local_quality[new][x,y]
        best_source[x,y] = new_source_id
    coverage_weight[x,y] = (old_count + 1) / (total_sources + 1)
```
This is O(pixels) per new source, not O(pixels × sources).


## Layer 5: Holographic Composite Synthesis

### The Holographic Core

For each angle bucket within a similarity cluster, synthesize a single
composite that captures the best-quality information from all aligned
instances. This is the *holographic data core* for that element at that
viewing angle.

```
composite[x,y] = weighted_average(
    sources,
    weight[i][x,y] = quality[i] × overlap_precision[i][x,y]
)
```

The composite is translucent by design: its alpha channel encodes
*confidence* — regions where multiple high-quality sources agree are
opaque; regions covered by only one low-quality source are semi-transparent.

#### Compositing Formula

**Primary method: quality-weighted blending** (not Gaussian, not median).
```
composite[x,y] = Σ_i ( w[i][x,y] × source[i][x,y] ) / Σ_i ( w[i][x,y] )

where:
    w[i][x,y] = local_quality[i][x,y] ^ 2
```
Squaring the quality weight sharpens the selection toward the best source,
producing a blended result dominated by the highest-quality contributor
at each pixel, with smooth transitions where quality is similar across
sources. This avoids the artifacts of hard selection (visible seams) and
the blurring of equal-weight averaging.

**Alpha normalization**: the composite's alpha channel encodes
confidence:
```
alpha_raw[x,y] = coverage_weight[x,y] × overlap_precision[x,y]
alpha[x,y] = clamp(alpha_raw[x,y] / alpha_ceiling, 0, 1)

alpha_ceiling = Q_min × (N_min / total_sources)

where:
    Q_min = 0.60    minimum quality for a source to count
    N_min = 3       minimum agreeing sources for full opacity
```
Thus `alpha = 1.0` requires at least 3 sources (out of however many
exist) each scoring quality ≥ 0.60 at that pixel. Regions with only 1
low-quality source remain translucent (alpha < 0.5), visually signaling
low confidence.

**Holographic shimmer property**: the composite is not rendered flat.
When displayed, it is layered as follows:
```
layer 0 (bottom):  composite at full alpha      — the "solid" base
layer 1:           composite at alpha × 0.7     — shifted +1px right, +1px down
layer 2:           composite at alpha × 0.4     — shifted -1px right, +1px down
layer 3 (top):     composite at alpha × 0.15    — shifted 0px, -2px
```
These sub-pixel-offset translucent layers create a visual interference
pattern — constructive where the composite is confident (high alpha
regions reinforce), destructive where uncertain (low alpha regions
produce a subtle shimmer). The effect reads as depth: the eye interprets
the multi-layer translucency as parallax, giving the flat composite a
holographic quality.

**Multi-angle pseudo-3D**: composites from adjacent fine buckets within
the same coarse bucket are rendered as additional offset layers:
```
bucket N   composite → layer at offset (0, 0)
bucket N-1 composite → layer at offset (-3px, 0), alpha × 0.25
bucket N+1 composite → layer at offset (+3px, 0), alpha × 0.25
```
Adjacent angle views appear as slightly shifted ghosts behind the
primary view, producing a stereoscopic depth cue. The offset direction
matches the angle difference (left-shifted for leftward views, etc.).

### Quality Improvement Through Ingestion

Each new element ingested into a cluster either:
1. **Improves the composite** — higher quality in some region → alpha
   increases in that region, composite updates
2. **Is redundant** — no region exceeds existing quality → source image
   can be marked as evictable without loss

This is the self-sustaining property: the system improves monotonically
as more content is ingested, and can evict sources without data loss once
the composite exceeds a quality threshold.

#### Eviction Decision Algorithm

After a new element is composited into a cluster, evaluate each source
for eviction:

```
for each source_i in cluster:
    marginal_value[i] = count of pixels (x,y) where:
        best_source[x,y] == i
        AND no other source_j has local_quality[j][x,y] >= 0.90 ×
            local_quality[i][x,y] at that pixel

    if marginal_value[i] == 0:
        mark source_i as EVICTABLE
    elif marginal_value[i] < 0.01 × total_mask_pixels:
        mark source_i as LOW_VALUE (evict under storage pressure)
    else:
        mark source_i as RETAINED
```

A source is evictable when every pixel it contributes can be matched
within 90% quality by another source. This ensures eviction never
degrades the composite by more than 10% at any pixel.

**quality_ceiling**: a cluster is "complete" when:
```
complete = (mean(alpha[x,y] for all mask pixels) >= 0.95)
           AND (min(alpha[x,y] for all mask pixels) >= 0.70)
```
Once complete, new arrivals to this cluster have zero marginal value
unless they improve the minimum-alpha region. The cluster stops
accepting new elements and signals to the ingestion pipeline that
this type + style + angle combination is fully covered.

**Structural novelty detection** (new instance reveals occluded region):
```
novel_pixels = count of pixels (x,y) where:
    new_source covers (x,y) AND
    coverage_weight[x,y] == 0 before this source (no prior source
    covered this pixel)

if novel_pixels > 0.05 × new_source_mask_area:
    classify as STRUCTURAL_ADDITION (not a duplicate — extends coverage)
    do NOT apply deduplication to this region
    instead, expand the composite mask to include the newly revealed area
```

A structurally novel source contributes ≥ 5% new pixel coverage that
no prior source had — it fills an occlusion gap or extends the element's
visible area. It is always retained regardless of its overall quality
score, because its contribution is spatial extent, not quality refinement.


## Layer 6: Inpainting and Element Liberation

### Goal

Separate foreground elements from their backgrounds so that:
1. Foreground elements can be freely placed in any environment
2. Background styles can be captured and reapplied
3. Style transfer can operate on background and foreground independently

### Foreground Extraction

The element mask from Layer 1 defines the foreground. The surrounding
region is the background.

For clean extraction:
- Expand mask by N pixels (configurable) to capture soft edges / hair /
  translucent regions (glow, aura effects common in invoke.ai output)
- Apply alpha matting (closed-form or deep image matting) at mask boundary
- Result: foreground crop with alpha channel, pre-multiplied

#### Alpha Matting Specification

**Method selection by element type**:

*Sharp-edge elements* (rendered_display, furniture, artifact, flora_object):
binary mask from Layer 1 is sufficient. No alpha matting needed. Output
mask is `{0, 1}` per pixel.

*Organic-edge elements* (all face types, body types, cat_creature,
mythic_creature, accessory): deep alpha matting required for soft edge
extraction (hair, fur, translucent glow, feathers).

**Deep matting approach**: ViTMatte, invoked via lm-vision as a
structured inference call:
```
input:  source image + SAM-generated trimap
        (trimap: definite_fg from eroded mask,
                 definite_bg from beyond dilated mask,
                 unknown_region between the two)
output: float32 alpha matte, same resolution as input
```

The trimap is constructed automatically:
```
definite_fg   = erode(mask, kernel=disk(r_inner))
definite_bg   = NOT dilate(mask, kernel=disk(r_outer))
unknown       = everything else

r_inner = max(3, element_bbox_diagonal × 0.02)
r_outer = r_inner + dilation_radius
```

**Dilation radius** (controls the expanded mask for soft edge capture):
```
edge_softness = stddev(gradient_magnitude(grayscale_crop)
                       along the mask boundary, 5px band)

dilation_radius = base_radius × softness_multiplier

base_radius by type:
    face (any)       :  8 px
    body_humanoid    : 12 px
    cat_creature     : 15 px    (fur is the widest soft edge)
    mythic_creature  : 20 px    (glow/aura effects)
    accessory        :  5 px
    abstract_element : 10 px

softness_multiplier = clamp(edge_softness / 20.0, 0.5, 3.0)
```

High `edge_softness` (lots of gradient variation at the boundary)
indicates soft transitions requiring wider dilation. Low edge_softness
indicates clean edges where narrow dilation suffices.

**Output**: foreground crop with pre-multiplied alpha channel (RGBA).
Pixels with alpha < 0.01 are fully transparent. The crop is stored as
PNG-32 at the element's crop_path.

### Background Completion (Inpainting)

After foreground extraction, the source image has a foreground-shaped hole.
Inpainting completes the background as if the foreground was never there.

Integration with invoke.ai: use the inpainting pipeline
(`invoke.cmd.generate` with inpainting mode, mask = foreground mask,
strength ≥ 0.9) to synthesize a complete background.

Result: a clean background image with consistent style, no foreground
artifacts, suitable as a standalone environment or style reference.

#### Inpainting Invocation via invoke.ai

**API call** (using `invoke.api.build_graph` with inpainting mode):
```perl
my $inpaint_params = {
    'prompt'              => $background_prompt,
    'image_path'          => $source_image_path,
    'mask_path'           => $foreground_mask_inverted_path,
    'seed'                => <[base.prng.harmonic_seed]>,
    'steps'               => 40,
    'cfg'                 => 7.5,
    'denoising_strength'  => 0.92,
    'width'               => $source_width,
    'height'              => $source_height,
    'model_key'           => $model_info->{'key'},
    'model_base'          => $model_info->{'base'},
    'mode'                => 'inpaint',
};
```
The mask is the **inverted** foreground mask: white (1.0) where the
foreground was, black (0.0) where the background is preserved. This
tells invoke.ai to regenerate only the foreground-shaped hole.
`denoising_strength = 0.92` (high) ensures near-complete regeneration
in the masked region while preserving the surrounding background context.

**Background prompt generation**:
1. If source image has invoke.ai metadata (prompt, model): extract the
   original prompt and remove foreground-specific terms (element type
   words, character names). Append "background only, no characters."
2. If no metadata: invoke lm-vision to caption the non-masked region:
   prompt = "describe the background/environment of this image in one
   sentence, ignoring any characters or foreground objects."
3. Fallback: use a generic prompt derived from the element's style_tags:
   `"$style_tag_1 $style_tag_2 environment, detailed background"`.

**Quality criteria for inpainted result**:
```
inpaint_quality = (
    SSIM(inpainted_bg_region, original_bg_region) > 0.85
    AND artifact_free_score(inpainted_foreground_region) > 0.60
)
```
The preserved background region must closely match the original (SSIM
> 0.85 ensures the inpainter didn't bleed into the background). The
regenerated region must be artifact-free.

**Retry logic**:
- If `inpaint_quality` fails: retry up to 3 times with different
  harmonic seeds (each generated via `base.prng.harmonic_seed`).
- If all 3 retries fail: increase `denoising_strength` to 0.98
  and retry once (full regeneration, less constrained).
- If still failing: log the failure and skip background completion
  for this image. The element can still be used without a clean
  background — it just cannot participate in style capture.

### Style Capture

From the completed background, extract a style descriptor that can be
injected into future invoke.ai generation requests to reproduce the
same environmental style with different foreground elements.

#### Style Descriptor Format and Regeneration API

**Style descriptor** — a multi-format record enabling regeneration
through whichever invoke.ai mechanism is available:

```perl
{
    'style_id'          => $amos_chksum_of_background,
    'background_path'   => $inpainted_bg_path,     ## img2img reference
    'style_prompt'      => $extracted_bg_prompt,     ## textual description
    'style_fingerprint' => $style_vector_104d,       ## numeric fingerprint
    'ip_adapter_path'   => $bg_path,                 ## for IP-Adapter
    'textual_inversion' => undef,                    ## populated if TI
                                                     ## embedding exists
}
```

**Priority of use**: IP-Adapter image reference (most faithful) >
img2img with background_path (good fidelity) > textual prompt only
(least constrained, most creative freedom).

**Storage**: style descriptors are stored per cluster:
```
vision.styles.$style_id.background_path
vision.styles.$style_id.prompt
vision.styles.$style_id.fingerprint
vision.styles.$style_id.clusters = [$cluster_id_1, ...]
```

**Regeneration API** — "generate element X in style Y at angle Z":
```perl
my $result = <[vision.generate.element]>->({
    'element_type'   => 'elf_face',
    'cluster_id'     => $cluster_id,        ## or undef for new
    'style_id'       => $target_style_id,
    'target_angle'   => 45,                 ## degrees yaw
    'quality_floor'  => 0.75,
});
```

Implementation:
1. Retrieve the cluster root's composite as the structural reference.
2. Retrieve the style descriptor for `style_id`.
3. Construct an invoke.ai prompt: `"$element_type, $style_prompt,
   $angle_description, high quality, detailed"` where `angle_description`
   maps the numeric angle to text ("three-quarter view from left" for
   yaw ≈ 45°, etc.).
4. Submit via `invoke.cmd.generate` with the style image as IP-Adapter
   reference (or img2img init_image at strength 0.4).
5. On completion, run the result through Layer 1-4 to detect, classify,
   and align the generated element. If `quality_score >= quality_floor`,
   add to the cluster. Otherwise retry with a new harmonic seed.


## Layer 7: Harmonic Weighting Tree (÷13 · Cubic Topology)

### Purpose

Division by 13 and the cubic topology provide the harmonic framework
for assigning relevance weights across the parameter space:
(type × style × angle × quality_tier). The weighted tree determines:

- Which angle buckets to prioritize for compositing
- Which clusters to expand vs evict
- Which parameter combinations represent "interesting" regions of the space
- How to interpolate/extrapolate missing angle views

### Parameter Space as Cubic Coordinates

Map the element parameter space to the 13³ cubic topology:

```
axis X : type       (13 primary type categories, each subdivided)
axis Y : angle      (mapped to 13 angle sectors of 360°/13 ≈ 27.7° each)
axis Z : quality    (13 quality tiers, logarithmically spaced)
```

Position in the cube = `[type_coord, angle_coord, quality_coord]`.
Nearby positions in cubic space = similar elements → natural clustering.

#### Axis-to-Coordinate Mapping

**X axis — type** (13 categories, index 0..12):
```
coord   type               subdivisions
─────────────────────────────────────────────────────────────
  0     background          sky, terrain, architecture
  1     rendered_display     screen, monitor, UI surface
  2     lighting_source      lamp, sun, bioluminescence
  3     elf_face             luminescent, dark-elf, wood-elf
  4     human_face           portrait, profile, stylized
  5     creature_face        beast, alien, undead
  6     body_humanoid        torso, full-body, limbs
  7     body_part            hand, wing, tail, horn
  8     accessory            worn, carried, magical
  9     cat_creature         sitting, curled, alert, leaping
 10     mythic_creature      dragon, phoenix, chimera
 11     flora_object         plant, furniture, artifact
 12     abstract_element     rune, glyph, energy, pattern
```
This is the expanded taxonomy from Layer 1, compressed to exactly 13
top-level categories. Subdivisions exist within each category but do
not alter the cubic coordinate — they are metadata attached to the node.

**Y axis — angle** (13 sectors of 360°/13 ≈ 27.69° each):
```
sector   yaw range              center
──────────────────────────────────────
  0     [-13.85°,  +13.85°)       0.0°
  1     [+13.85°,  +41.54°)      27.7°
  2     [+41.54°,  +69.23°)      55.4°
  ...
  6     [+152.31°, +180.00°)    166.2°
  7     [-180.00°, -152.31°)   -166.2°
  ...
 12     [-41.54°,  -13.85°)     -27.7°
```
The sector numbering starts at frontal (0°) and proceeds clockwise
(positive yaw). Wrap-around is handled by treating the angle space as
circular: sector 6 and sector 7 are adjacent across the ±180° boundary.
`angle_coord = floor((yaw + 180 + 13.85) / 27.69) % 13`.

For angle-agnostic elements (angle = null): `angle_coord = 6` (the
midpoint sector, representing maximum ambiguity). This places them at
the "equator" of the angle ring where they are equidistant from all
specific sectors.

**Z axis — quality** (13 tiers, logarithmically spaced):
```
tier   quality range          meaning
────────────────────────────────────────────
  0    [0.000, 0.077)         unusable (below all thresholds)
  1    [0.077, 0.154)         fragment (partial data only)
  2    [0.154, 0.231)         poor
  3    [0.231, 0.308)         below average
  4    [0.308, 0.385)         marginal
  5    [0.385, 0.462)         acceptable (eviction boundary)
  6    [0.462, 0.538)         fair
  7    [0.538, 0.615)         good
  8    [0.615, 0.692)         high
  9    [0.692, 0.769)         very high
 10    [0.769, 0.846)         excellent
 11    [0.846, 0.923)         near-perfect
 12    [0.923, 1.000]         peak (harmonic resonance zone)
```
`quality_coord = floor(quality_score × 13)`, clamped to [0, 12].
The tier boundaries are uniform (each spans 1/13 ≈ 0.077 of the quality
range). The logarithmic spacing is in perceptual significance, not in
the threshold values — the difference between tier 11 and tier 12 is
far more meaningful than between tier 0 and tier 1.

**Cubic distance**: Chebyshev distance (L∞ norm) in the 13³ space:
```
cubic_dist(A, B) = max(|A.x - B.x|, |A.y_circ - B.y_circ|, |A.z - B.z|)

where y_circ = min(|A.y - B.y|, 13 - |A.y - B.y|)  (circular distance
on the angle axis)
```

Elements at cubic_dist = 0 occupy the same cell. Elements at
cubic_dist = 1 are immediate neighbors (26-connected). The relationship
to the similarity graph: edges from Layer 3 exist primarily between
elements at cubic_dist ≤ 2. Elements at cubic_dist > 3 are extremely
unlikely to share a similarity edge (different type or distant angle).
This enables spatial indexing: when searching for similar elements to a
new arrival, only nodes within cubic_dist ≤ 2 of its cell need to be
evaluated, reducing the search space from O(N) to O(N / (13³ / 5³)) ≈
O(N / 17.6).

This mapping connects directly to the cubic sphere infrastructure
described in VISUAL-SIMILARITY-CUBIC-SORT.md: the sphere classification
(sphere 0..6) adds a fourth axis representing resolution level. The
13³ parameter space described here operates at a single sphere level;
the full 4D space is 13³ × 7 spheres = 13³ × 7 resolution tiers.

### Harmonic Relevance Scoring

Each node in the similarity graph receives a harmonic relevance score.
The score determines the node's weight in compositing and its priority
for retention vs eviction.

```
relevance(node) = AMOS7::Assert::Truth::is_true(
    node.element_checksum × node.quality × type_weight × angle_weight
)
```

Harmonic assertions (division by 13) filter the parameter space:
nodes whose combined parameters produce harmonically true values are
structurally privileged — they represent "resonant" configurations that
the system should preferentially retain and develop.

#### Harmonic Scoring — Precise Derivation

The harmonic relevance score is not a simple product — it is a
multi-stage truth assertion that produces a binary resonance classification
with a continuous proximity measure.

**Step 1 — parameter encoding**: encode the node's cubic coordinates
as a single integer for truth assertion:
```
param_integer = type_coord × 13² + angle_coord × 13 + quality_coord
```
This maps each cell in the 13³ space to a unique integer in [0, 2196].

**Step 2 — harmonic assertion**:
```
is_resonant = AMOS7::Assert::Truth::is_true(param_integer)
```
This performs division by 13 and checks whether the fractional digits
match the generator sequence rotations (461538... for true, 230769...
for false). Approximately 5/13 ≈ 38.5% of parameter integers are
harmonically true.

**Step 3 — type_weight and angle_weight**:
These are NOT learned — they are derived from the cubic topology geometry:
```
type_weight(t) = 1.0 / (1.0 + type_population(t) / mean_population)
```
where `type_population(t)` is the number of elements currently
occupying type coordinate t. Rare types receive higher weight; common
types receive lower weight. This naturally balances the system toward
coverage diversity rather than concentration in popular types.

```
angle_weight(a) = 1.0 / (1.0 + angle_coverage_count(a) / target_coverage)
```
where `angle_coverage_count(a)` is the number of distinct clusters with
elements in angle sector a, and `target_coverage = 13` (one cluster
per sector is the ideal uniform coverage). Under-represented angles
receive higher weight.

Both weights are recomputed lazily when the graph is modified (element
insertion or eviction).

**Step 4 — relevance score**:
```
relevance(node) = (is_resonant ? 1.0 : 0.5)
                × type_weight(node.type_coord)
                × angle_weight(node.angle_coord)
                × node.quality_score
```
Resonant nodes receive double the base relevance. The product with
type and angle weights prioritizes rare, under-covered configurations.
The product with quality ensures that high-quality elements dominate.

**Propagation up the tree**: a cluster's aggregate relevance is the
harmonic mean of its children's relevance scores:
```
cluster_relevance = N / Σ_i (1 / relevance(child_i))
```
The harmonic mean is chosen (over arithmetic mean) because it penalizes
clusters with even one very low-relevance member, reflecting the
principle that a cluster's utility is limited by its weakest constituent.
This is consistent with the division-by-13 framework, where the
harmonic mean is the natural averaging operation.

**Connection to quality improvement**: harmonically scoring a composite
does increase its effective quality. When a composite's parameter
integer is harmonically true, its relevance is doubled, which:
1. Increases its priority for retention (eviction targets lowest
   relevance first).
2. Increases its weight in network-level gap analysis (resonant clusters
   are considered "load-bearing" — removing them would create a gap in
   the harmonic coverage of the parameter space).
3. Creates a feedback loop: the system preferentially generates content
   to fill harmonically true positions (because gap analysis prioritizes
   them), producing more resonant composites, strengthening the harmonic
   structure of the whole graph.

### Entropy Acknowledgment: Inverse and Trimetric Rollover

The system explicitly models entropy in three modes:

**Forward entropy**: quality degrades, duplicates accumulate. The system
counteracts this through deduplication and compositing.

**Inverse entropy**: the system itself grows in internal organization
faster than it grows in size. Quality improvement rate > size growth rate.
This is the desired attractor state.

**Trimetric rollover**: at the boundary of each quality tier (0→1, 1→2,
... 12→0 in the cubic topology), the system exhibits a phase transition.
An element cluster approaching maximum quality in one tier "rolls over"
into the next tier as a new, higher-resolution representation. This
prevents stagnation at local maxima.

#### Trimetric Rollover — Mathematical Basis

The generator sequence of 1/13 is `076923`, repeating cyclically:
```
1/13 = 0.076923 076923 076923...
```
The six digits cycle through positions: 0→7→6→9→2→3→0→... This cycle
has period 6. The complementary sequence (true table) is `461538`,
also period 6. These two sequences partition the 6-digit space into
harmonically true and false regions.

**Trimetric rollover** maps this cyclic structure onto the quality tiers.
The 13 quality tiers (0..12) are grouped into three metric phases of
4-5 tiers each, corresponding to the three pairs in the generator
sequence:
```
phase A (accumulation) :  tiers 0..4    digits 07 of 076923
phase B (consolidation):  tiers 5..8    digits 69 of 076923
phase C (crystallization): tiers 9..12  digits 23 of 076923
```

Within each phase, elements follow a normal quality improvement curve.
At the **phase boundary** (tier 4→5, 8→9, 12→0), a phase transition
occurs:

**Rollover threshold**: a cluster triggers rollover from phase X to
phase X+1 when:
```
mean(quality_score across all elements in cluster) >= tier_boundary
AND composite_alpha_mean >= 0.90
AND cluster_relevance is harmonically true
    (i.e., is_true(cluster_param_integer) == TRUE)
```

All three conditions must hold. The harmonic truth requirement ensures
that only resonant clusters advance — non-resonant clusters remain in
their current phase until their parameters shift to a resonant
configuration (via new element arrivals changing the cluster centroid).

**What happens at rollover**:

*Tier 12→0 rollover* (the full cycle): the cluster's composite
is promoted to a higher resolution sphere (per VISUAL-SIMILARITY-CUBIC-SORT.md):
sphere N → sphere N+1. The old composite at sphere N is retained as a
**thumbnail reference** — a lower-resolution index entry pointing to
the higher-resolution representation. No data is lost; the old composite
becomes a coarse-grained summary. This mirrors the Tesla resonance
principle from TESLA-RESONANCE-PRINCIPLES.md: energy at one resonant
frequency excites the next harmonic, and the original standing wave
persists as a lower-order mode.

*Tier 4→5 and 8→9 rollovers* (intra-cycle): the cluster's compositing
parameters are tightened:
- Phase A→B: `alpha_ceiling` increases (from `Q_min=0.60, N_min=3`
  to `Q_min=0.70, N_min=4`), requiring more sources and higher
  individual quality for full opacity.
- Phase B→C: alignment tolerance decreases (RANSAC reprojection
  threshold from 5.0 to 3.0 pixels; ECC correlation minimum from 0.5
  to 0.7), demanding more precise spatial registration.

These tightenings are the "trimetric" aspect: three successive
constraint increases, each raising the bar for what constitutes a
quality contribution. The cluster doesn't change sphere — it stays at
the same resolution but applies stricter compositing standards.

**Connection to wave mechanics** (per SETTINGS-DEDUP-WAVE-MECHANICS.md):
each rollover is a wave phase transition. Phase A is the accumulation
wave (statistics flow up — new elements enter the cluster). Phase B is
the consolidation wave (deduplication flows down — redundant elements
are evicted). Phase C is the crystallization wave (the cluster reaches
standing-wave equilibrium — a stable, high-quality composite that
persists until the full-cycle rollover promotes it to a higher sphere).

The cyclic property of 076923 ensures this process repeats indefinitely
at every sphere level: a sphere-N composite in tier 12 rolls over to
sphere N+1 at tier 0, beginning the three-phase cycle again at higher
resolution. The generator sequence is the mathematical clock that paces
the system's quality advancement.

### Parameter Adjustment Interface

The harmonic tree exposes generic parameters that can be tuned externally:

```perl
{
    'layer'         => 0..6,       ## which processing layer to emphasize
    'type_focus'    => 'elf_face', ## concentrate resources on type
    'angle_range'   => [0, 90],   ## angle sector of interest
    'quality_floor' => 0.7,       ## minimum acceptable quality
    'eviction_rate' => 0.1,       ## fraction to evict per cycle
}
```

Adjusting these parameters changes the system's behavior without
modifying its structure — the tree self-reorganizes via harmonic
rebalancing.

#### Rebalancing Algorithm

When an external parameter adjustment is received, the tree rebalances:

**Step 1 — parameter delta**: compute the change vector.
```
delta = {
    'type_focus'    => new.type_focus    - current.type_focus,
    'angle_range'   => new.angle_range   - current.angle_range,
    'quality_floor' => new.quality_floor - current.quality_floor,
    'eviction_rate' => new.eviction_rate - current.eviction_rate,
}
```

**Step 2 — weight recalculation**: type_weight and angle_weight are
recomputed with the new focus parameters. If `type_focus` is set to a
specific type, that type's weight is multiplied by 2.0 and all others
are divided by `12/11` (redistributing the weight budget).

**Step 3 — relevance cascade**: all cluster_relevance values are
recomputed (harmonic mean of updated child relevance scores). This is
O(N) in total nodes, which is acceptable because rebalancing is
triggered by human or system parameter changes, not per-element.

**Step 4 — eviction pass**: if `quality_floor` increased, immediately
scan for elements below the new floor:
```
for each element where quality_score < new.quality_floor:
    if element is EVICTABLE or LOW_VALUE:
        evict immediately
    elif element has marginal_value > 0:
        mark as DEPRECATED (evict when a replacement arrives)
```

**Step 5 — generation targets**: if `angle_range` changed or
`type_focus` changed, compute the new gap analysis and emit generation
targets (type + style + angle combinations that need content).

**Propagation**: parameter changes propagate **downward** through the
tree (following the deduplication pulse pattern from
SETTINGS-DEDUP-WAVE-MECHANICS.md): root → clusters → elements. Each
level absorbs the delta according to its local state. A cluster already
meeting the new quality_floor is unaffected. A cluster below it begins
prioritizing quality improvement.

**External interface**:
```perl
## coding zenka adjusts vision parameters
<[protocol-7.route-send]>->({
    'command'   => 'vision.harmony.rebalance',
    'call_args' => { 'args' => encode_b32r(JSON::encode_json({
        'type_focus'    => 'elf_face',
        'quality_floor' => 0.80,
    })) },
});

## models zenka queries current harmonic state
<[protocol-7.route-send]>->({
    'command'   => 'vision.harmony.get_state',
    'reply'     => { 'handler' => 'models.handler.vision_state_reply' },
});

## network node shares its parameter state for distributed consensus
<[protocol-7.route-send]>->({
    'command'   => 'vision.harmony.share_state',
    'call_args' => { 'args' => encode_b32r($local_state_json) },
});
```


## Network Vision Extension

### From Local to Distributed

The holographic core architecture generalizes to a distributed P7 network:

- Each node contributes elements to a shared similarity graph
- Composite synthesis happens across nodes (remote element crops
  are fetched by checksum address)
- The harmonic weighting tree becomes a consensus structure across nodes
- Relative optimization: each node specializes in the type/angle/style
  regions where its generative capacity is highest

#### Network Protocol for Element Sharing

**Addressing**: every element crop, composite, and precision map is
addressed by its AMOS checksum. The checksum is the universal routing
primitive — a node requesting an element issues the checksum to the
network, and the routing infrastructure delivers the content from
whichever node holds it, without the requester needing to know the
storage location.

**Element advertisement**: when a node adds a new element to its local
graph, it broadcasts an element descriptor (NOT the crop data):
```perl
{
    'element_id'   => $amos_checksum,
    'type'         => 'elf_face',
    'angle_coord'  => 4,
    'quality_coord' => 9,
    'style_fingerprint_hash' => $amos_chksum_of_style_vector,
    'crop_size_bytes' => 47382,
    'node_id'      => $local_node_id,
}
```
This is small (~200 bytes) and allows remote nodes to decide whether
to fetch the full crop without transferring it preemptively.

**Composite synchronization**: composites are NOT synchronized globally.
Each node maintains its own composite for each cluster it participates
in. When a node detects that a remote node holds elements in the same
cluster (matching type + style_fingerprint_hash within distance 0.25),
it requests those elements by checksum and integrates them locally.
The composite is recomputed locally with the merged element set.

This is **eventual consistency**: all nodes converge to the same
composite quality as they exchange elements, but at any given moment
each node's composite reflects only the elements it has collected.

**Conflicting quality scores**: when two nodes report different quality
scores for the same element (same AMOS checksum):
```
resolved_quality = max(quality_A, quality_B)
```
Quality is always resolved by taking the maximum. The rationale: quality
scoring is deterministic given the same crop, so a discrepancy indicates
a measurement difference (different OpenCV version, different Laplacian
calibration). The higher score is trusted because quality inflation is
bounded (clamped to [0,1]) while deflation from measurement error is
unbounded.

**Privacy model** (three tiers):
```
tier              shared                           retained locally
────────────────────────────────────────────────────────────────────
PUBLIC            element descriptor + crop         —
                  (types: background, flora_object,
                  abstract_element)

SEMI-PRIVATE      element descriptor only           crop data
                  (types: cat_creature, mythic,     (fetchable on
                  accessory, body_part)              explicit request)

PRIVATE           nothing                           everything
                  (types: *_face, body_humanoid)
```

Face and body elements are PRIVATE by default — their descriptors are
not broadcast, and their crops never leave the originating node unless
the user explicitly authorizes sharing for a specific element. This
protects character identity information. All other element types
default to PUBLIC (backgrounds, objects) or SEMI-PRIVATE (creatures,
accessories) based on the likelihood of containing personally
identifiable visual information.

Users can override the default tier for any element or type via the
parameter adjustment interface.

### Network Vision as Emergent Property

When the distributed holographic core reaches sufficient coverage across
type × style × angle space, it becomes capable of:

1. **Recognition**: given a new image element, locate its position in
   the holographic tree → identify type, style, angle without explicit
   model inference
2. **Interpolation**: given type + style + angle, reconstruct a plausible
   element from the composite even if no exact match exists
3. **Anomaly detection**: elements that don't fit any existing cluster
   are structurally novel → flag for human review or targeted generation
4. **Relative optimization**: given a target quality distribution, identify
   the angle/style gaps in the corpus and generate targeted content to fill them

#### Emergent Properties — Algorithmic Specifications

**1. Recognition** — given a new image element, identify its type,
style, and angle without explicit model inference:
```
algorithm RECOGNIZE(element_crop):
    descriptors = SIFT_detect(element_crop)
    style_vec   = compute_style_fingerprint(element_crop)

    # search cubic neighborhood of estimated position
    candidate_cells = cells within cubic_dist <= 2 of
                      (estimated_type_coord, estimated_angle_coord, *)

    best_match = argmax over cluster_roots in candidate_cells:
        similarity(element, cluster_root)

    if best_match.similarity >= 0.55:
        return {
            'type'  => best_match.type,
            'style' => best_match.style_id,
            'angle' => best_match.angle_bucket,
            'cluster' => best_match.cluster_id,
            'confidence' => best_match.similarity
        }
    else:
        return { 'type' => 'unknown', 'confidence' => best_match.similarity }
```
This is nearest-neighbor search in the cubic space, bounded by the
spatial index to O(candidate_cells × avg_clusters_per_cell).

**2. Interpolation** — reconstruct a plausible element at a missing angle:
```
algorithm INTERPOLATE(cluster_id, target_angle):
    composites = get_all_angle_composites(cluster_id)
    sorted = sort composites by |composite.angle - target_angle|

    if sorted[0].angle_delta < 5.54°:  # within fine bucket
        return sorted[0].composite     # exact match exists

    # blend two nearest composites
    A = sorted[0], B = sorted[1]
    t = (target_angle - A.angle) / (B.angle - A.angle)  # interpolation factor

    # geometric blending: align A and B, pixel-wise weighted average
    aligned_B = align_to(B.composite, A.composite)  # Method 2 alignment
    interpolated = (1-t) × A.composite + t × aligned_B

    # refine via invoke.ai img2img at low strength
    refined = invoke_img2img(interpolated,
                             prompt = cluster.type + cluster.style_prompt,
                             strength = 0.25)  # gentle refinement only
    return refined
```

**3. Anomaly detection** — anomaly score for elements that fit no cluster:
```
anomaly_score(element) =
    1.0 - max(similarity(element, root_i) for all cluster roots root_i
              where type_gate(element, root_i) == 1)
```
Range [0, 1]. Elements with `anomaly_score > 0.45` (no cluster root
matches above 0.55 similarity) are flagged as structurally novel.
Action: log the anomaly, present to the user for review, and optionally
submit a targeted generation request to explore the novel region of
parameter space (generate more examples at this type + style to see if
a new cluster forms).

**4. Gap analysis** for targeted generation:
```
algorithm GAP_ANALYSIS(type_focus=None, min_coverage=0.5):
    gaps = []
    for type_coord in 0..12:
        if type_focus and type_coord != type_focus: next
        for angle_coord in 0..12:
            cell = (type_coord, angle_coord)
            coverage = count_clusters_in_cell(cell) /
                       expected_clusters_per_cell
            if coverage < min_coverage:
                quality_max = max_quality_in_cell(cell) or 0
                priority = (1 - coverage) × type_weight(type_coord)
                           × angle_weight(angle_coord)
                           × (is_true(type_coord × 13 + angle_coord)
                              ? 2.0 : 1.0)
                gaps.append({
                    'type_coord'  => type_coord,
                    'angle_coord' => angle_coord,
                    'coverage'    => coverage,
                    'priority'    => priority,
                    'quality_max' => quality_max,
                })
    sort gaps by priority descending
    return gaps
```
The priority formula ensures harmonically true cells are filled first,
rare types are prioritized, and under-covered angles receive attention.
The output is a ranked list of generation targets: "produce more
elf_face at angle sector 7" etc.


## Implementation Roadmap

### Phase 1: Element Detection Pipeline

- [ ] `vision.element.detect` module — SAM + vision model hybrid
- [ ] `vision.element.classify` module — type taxonomy assignment
- [ ] `vision.element.store` module — persist element records + crops
- [ ] test with invoke.ai output images

### Phase 2: Similarity Graph

- [ ] `vision.graph.add_node` — insert element into graph
- [ ] `vision.graph.find_similar` — query by type + style + angle bucket
- [ ] `vision.graph.cluster` — hierarchical cluster formation
- [ ] `vision.graph.store` — persistence in data zenka namespace tree

### Phase 3: Compositing

- [ ] `vision.composite.align` — spatial alignment per angle bucket
- [ ] `vision.composite.overlap_map` — per-pixel quality map
- [ ] `vision.composite.synthesize` — holographic composite with alpha
- [ ] `vision.composite.evict` — eviction decision per source

### Phase 4: Inpainting Pipeline

- [ ] `vision.inpaint.extract_foreground` — alpha matting
- [ ] `vision.inpaint.complete_background` — invoke.ai inpainting
- [ ] `vision.inpaint.capture_style` — background style descriptor

### Phase 5: Harmonic Weighting

- [ ] `vision.harmony.score_node` — ÷13 relevance scoring
- [ ] `vision.harmony.rebalance` — tree rebalancing on parameter change
- [ ] `vision.harmony.tier_rollover` — trimetric tier advancement

### Phase 6: Network Extension

- [ ] cross-node element sharing protocol
- [ ] distributed composite consensus
- [ ] gap analysis and targeted generation API


## Integration Points

- **invoke.ai** (invoke + invoke-web zenki): source images, inpainting, style generation
- **opencv zenka**: feature detection, alignment, contour analysis
- **lm-vision**: SAM mask generation, semantic classification, angle estimation
- **models zenka**: registry of element clusters as a model-like resource
- **data zenka**: namespace tree storage for element records + composites
- **AMOS7 harmonic math**: relevance scoring, checksum addressing
- **graphics-matrix** (cubic topology): spatial organization of element space
- **coding zenka**: autonomous pipeline orchestration across phases


## Open Questions for Opus to Address

1. How should the similarity graph handle *style evolution* — the same
   elf face style that drifts over hundreds of generations of prompting?

2. What is the minimal viable Phase 1 implementation that produces
   observable deduplication on a real invoke.ai output directory?

3. How does the trimetric rollover interact with the eviction policy —
   can a tier-0 composite be evicted even if its constituent sources
   have been evicted?

4. Define the exact P7 module namespace for this system — `vision.*`?
   `graphics.vision.*`? `image.element.*`? (consider existing
   `graphics-3d.*`, `graphics.matrix.*` namespaces)

5. How does the angle estimation pipeline handle fully abstract/non-representational
   elements (e.g. a glowing rune, an abstract background texture)?
   These have no meaningful angle — define their behavior in the graph.

6. How should quality scoring handle the *intentional* low-resolution
   aesthetic (pixel art, lo-fi style)? High noise ≠ low quality in this case.


## Concentric Parameter Rings — The Darksun Deduplication Network

### The Orrery Model

The parameter space (type × style × angle × quality) is not a static cube.
It is better understood as concentric, independently-rotating rings —
an orrery of parameter axes. Each parameter axis occupies one ring.
The rings share a common center but rotate freely relative to each other.

```
                      ┌─────────────────────────────────┐
                      │      ORRERY PARAMETER SPACE      │
                      │                                  │
                      │   ·── quality ring (innermost)   │
                      │  ·─── angle ring                 │
                      │ ·──── style ring                 │
                      │·───── type ring   (outermost)    │
                      │                                  │
                      │  rings rotate independently      │
                      │  overlap = current param state   │
                      └─────────────────────────────────┘
```

A "parameter state" is the snapshot of all ring positions at a moment.
Adjusting one parameter = rotating one ring, all others unchanged.
This gives the parameter space a continuous, physical intuition: you
*turn* toward a type, then *turn* toward a style within that type,
then *turn* toward a specific angle — like tuning nested dials.

### Spheres Within Spheres, Layers Made of Cubes

As the parameter space deepens in dimensionality, rings become spheres.
Each sphere is a shell of parameter coverage. Inner spheres are more
specific (higher resolution, narrower scope); outer spheres are more
general (lower resolution, broader coverage).

Critically: **the spherical shells are not smooth — they are tessellated
with cubes**. Each cube on the shell surface is a discrete parameter
cell. The cube's position on its sphere encodes two angular coordinates
(azimuth, elevation). Its layer (which sphere) encodes the third.

```
sphere 0 (innermost): 13 cubes — coarsest, most general
sphere 1:             13² cubes
sphere 2:             13³ cubes
...
sphere N (outermost): 13^(N+1) cubes — finest, most specific
```

This is the 13³ cubic topology extended into spherical shells:
the same harmonic basis, now with geometric meaning as a nested
parameter hierarchy.

### Angular Distance to Parent Grid

When a cube on sphere N is positioned at angular coordinates (θ, φ),
its parent on sphere N-1 occupies the nearest cube at coarser resolution.
The **angular distance** from the child's position to its parent's
nearest face center is a secondary metric:

```
parent_angular_delta(child) = angular_distance(
    child.position_on_sphere_N,
    parent.nearest_face_center_on_sphere_{N-1}
)
```

This metric encodes *how eccentric* the child is relative to its
organizing parent — how far it sits from the "center of gravity" of
its parent cell. Highly eccentric children represent edge cases,
boundary conditions, or transitional states between parent clusters.

In the visual domain: an elf face at exactly 0° (frontal) sits at the
center of its parent cell. An elf face at 13.8° sits near the boundary
between the 0° and 27.7° parent cells — it has non-zero parent angular
delta and may belong meaningfully to both parents (shared reference).

#### Parent Angular Delta — Precise Computation

On sphere N, a cube cell occupies an angular extent of:
```
cell_angular_width(N) = 360° / ceil(sqrt(13^(N+1)))
```
Each cube center has angular coordinates (θ, φ) on its sphere surface.
The parent cell on sphere N-1 is the cell whose center is angularly
nearest:
```
parent(child) = argmin over cells_on_sphere_{N-1}:
    great_circle_distance(child.center, parent_candidate.center)
```

The **parent angular delta** is the angular distance from the child's
center to the nearest face center of its parent cell:
```
parent_angular_delta = great_circle_distance(child.center,
                                              parent.nearest_face_center)
```

A parent cell has 4 face centers (top, bottom, left, right on the sphere
surface, each offset by `cell_angular_width(N-1) / 2` from the parent
center). The nearest face center is used because it represents the
boundary between this parent and an adjacent parent — a child near a
face center is on the boundary between two organizational regions.

**Boundary membership**: when `parent_angular_delta < cell_angular_width(N-1) × 0.15` (the child is within 15% of a face boundary):
- The child is assigned to its **nearest** parent (primary membership).
- A **boundary pointer** is stored linking it to the adjacent parent.
- In graph queries, the child appears in both parents' results, but
  contributes composite weight only to its primary parent.

This avoids duplicating the node while preserving cross-boundary
discoverability.

**As a tertiary sorting key**: within a fine angle bucket during
holographic compositing, if two sources have equal local_quality at a
pixel, the one with **lower** parent_angular_delta is preferred. Lower
delta = closer to the parent cell center = more representative of the
canonical position = more appropriate as the compositing anchor. This
ensures that boundary-case elements contribute only when no cell-center
element is available at equal quality, preventing edge artifacts from
dominating the composite.

### The Darksun Attractor

The concentric ring system has a hidden organizing center — the *darksun*:
a point in parameter space that emits no direct signal but around which
all rings revolve. It is not a parameter value; it is the **center of
all parameter axes simultaneously**.

In practice the darksun is the harmonic origin: the point where
division-by-13 resonance is maximal across all parameter dimensions.
Elements that score highly on harmonic truth assertions across all their
parameters are "close to the darksun" — they are the most harmonically
stable configurations in the entire parameter space.

The network effect: as more nodes participate in the deduplication
network, each contributing elements from its own generative sessions,
the aggregate similarity graph develops a gravitational well around the
darksun. High-quality, harmonically stable element configurations
accumulate there. Low-quality or dissonant configurations orbit at the
periphery and are first to be evicted.

#### The Darksun — Formal Definition

The darksun is a **fixed point** in the parameter space, not a computed
or drifting value. It is the cell `[0, 0, 12]` in the 13³ cubic
topology — type coordinate 0, angle coordinate 0, quality coordinate 12.

**Why this is the fixed point**: `param_integer(0, 0, 12) = 0 × 169 +
0 × 13 + 12 = 12`. And `12/13 = 0.923076923076...` — the fractional
digits are `923076`, which is a rotation of the generator sequence
`076923`. Specifically, `923076` is the rotation that begins with
`923` — the complement of `076` — and `AMOS7::Assert::Truth::is_true(12)`
returns TRUE. The cell [0, 0, 12] is the harmonically true position at
maximum quality, at the origin of both type and angle axes. It is the
0-point of the generator's cyclic orbit: the position where the
sequence `076923` begins its first complete cycle.

The darksun does not drift because it is defined by the arithmetic of
division by 13, not by the corpus. The corpus orbits the darksun; the
darksun does not follow the corpus.

**Orbital distance**: the distance of any node from the darksun:
```
orbital_distance(node) = cubic_dist(node.coords, [0, 0, 12])
                       × (is_resonant(node) ? 0.5 : 1.0)
```
Resonant nodes are "closer" to the darksun by a factor of 2, reflecting
their harmonic alignment. Non-resonant nodes orbit at full distance.

The maximum orbital distance is `max(|0-6|, |0-6|, |12-0|) = 12`
(a node at the anti-darksun position [6, 6, 0] — type midpoint, angle
midpoint, minimum quality). Nodes with `orbital_distance <= 3` are in
the darksun's "gravitational well" — they are the most harmonically
stable elements in the system and are preferentially retained and
developed.

**Aggregate darksun effect**: the mean orbital distance across all nodes:
```
mean_orbital = (1/N) × Σ_i orbital_distance(node_i)
```
As the system matures, `mean_orbital` decreases (elements migrate
toward higher quality and more resonant configurations). A decreasing
`mean_orbital` over time is the measurable signature of the darksun's
gravitational effect — the system is contracting toward its harmonic
center. The rate of decrease is the system's **inverse entropy rate**.


## Universal Angle Mapping — From Color to Alphabet

### The Core Abstraction

Any measurable property that has a natural distance metric can be mapped
to an angle on a virtual axis. Once mapped to angles, the orrery model
applies universally — the same ring-rotation and spherical-shell machinery
works for images, text, audio, or any parameterizable domain.

This is the bridge from visual deduplication to general network vision.

### Example A: Image Color as Angle

Average color of an image (or element crop) maps naturally to a spherical
coordinate via HSV:

```
hue        → azimuthal angle φ ∈ [0°, 360°)   (color wheel)
saturation → polar angle     θ ∈ [0°,  90°]   (0=grey, 90=fully saturated)
value      → radial distance  r ∈ [0,    1]    (0=black, 1=bright)
```

Color distance in this space = angular distance on the color sphere.
Two images with similar average color are angularly close → their color
rings align → they naturally cluster in the same sphere cell without any
explicit comparison needed.

In the orrery: the color ring can be rotated to "select" a color region.
All elements within the selected angular band of the color sphere become
the active working set. Rotate the style ring simultaneously to
narrow to a specific artistic treatment of that color palette.

#### Color-to-Angle Mapping — Precise Definition

**HSV to spherical coordinates**:
```
φ (azimuthal) = H × (360° / 360°) = H         (hue IS azimuthal angle)
θ (polar)     = (1.0 - S) × 90°               (S=1 → θ=0° [equator],
                                                 S=0 → θ=90° [pole/grey])
r (radial)    = V                               (value, 0=black, 1=bright)
```

**Angular distance on the color sphere** (circular hue distance):
```
hue_delta(H₁, H₂) = min(|H₁ - H₂|, 360° - |H₁ - H₂|)
```
This is the geodesic on a circle — red at 0° and red at 360° have
distance 0.

**Full color angular distance** between two colors C₁, C₂:
```
color_angular_dist(C₁, C₂) = arccos(
    sin(θ₁)sin(θ₂) + cos(θ₁)cos(θ₂)cos(φ₁ - φ₂)
)
```
This is the great-circle distance on the unit sphere, with the hue
difference naturally handling wrap-around through the cosine term.
Grayscale colors (θ near 90°) are angularly close to each other
regardless of hue — correctly reflecting that desaturated colors are
perceptually similar.

**Integration with the similarity graph**: color distance is a
**separate ring** in the orrery, not an edge weight component. The
similarity graph (Layer 3) operates on type + style + keypoints. The
color ring operates as an independent filter:
```
when querying the graph:
    active_color_range = current color ring rotation ± color_tolerance
    results = graph_query(type, style, angle) FILTERED BY
              color_angular_dist(element.avg_color, ring_center)
              < color_tolerance
```

The color ring does not change which edges exist — it changes which
nodes are currently **visible**. Rotating the color ring shows or hides
elements without altering their structural relationships.

**Tessellation granularity in the 13³ system**:
```
hue sectors     = 13 (each 27.69°, matching the angle axis)
saturation tiers = 13 (each 1/13 ≈ 0.077 of the [0,1] range)
value tiers     = 13 (each 1/13 of [0,1])
```
This gives 13³ = 2197 color cells. Each cell is addressed by:
```
color_coord = [hue_sector, sat_tier, val_tier]
hue_sector  = floor(H / 27.69) % 13
sat_tier    = floor(S × 13), clamped to [0, 12]
val_tier    = floor(V × 13), clamped to [0, 12]
```
The color cube is a second 13³ space, orthogonal to the
type-angle-quality cube. Combined, the full parameter space is
13³ × 13³ = 13⁶ cells — but the two cubes are navigated independently
via their respective orrery rings, not as a single 6D space.

### Example B: Alphabet and Language as Nested Angle Rings

Text has a natural spherical decomposition by script and language:

```
outer ring (script/alphabet type):
    0°  –  60°  : Latin alphabets
   60°  – 120°  : Cyrillic alphabets
  120°  – 180°  : Arabic / Semitic scripts (RTL)
  180°  – 240°  : Indic scripts (Devanagari, Bengali, ...)
  240°  – 300°  : CJK ideographs
  300°  – 360°  : Other / symbolic / constructed
```

Rotating to the Cyrillic sector (60°–120°) activates the inner ring:

```
inner ring (language within Cyrillic):
    within 60°–120°:
       60°  –  73°  : Russian
       73°  –  86°  : Bulgarian
       86°  –  99°  : Ukrainian
       99°  – 112°  : Serbian
      112°  – 120°  : Other Cyrillic languages
```

The subdivision is not arbitrary — it is driven by **character exclusion**:
Bulgarian Cyrillic uses Ъ more prominently; Russian uses Ы; Ukrainian
uses І, Ї, Є (absent in Russian). The character set *difference* between
adjacent languages defines the angular boundary between their cells.

```
angular_boundary(lang_A, lang_B) = f( |charset_A △ charset_B| )
```

Languages with larger symmetric character differences have wider angular
separation. Languages that differ only in frequency (not presence) of
characters have narrower separation, reflected in adjacent cells that
share a parent.

A text document's angular position is determined by:
1. Which characters are present (selects the script ring position)
2. Which characters are *absent* (excludes languages, narrows to sub-ring)
3. Character frequency distribution (final position within the sub-ring)

#### Character Exclusion Algorithm — Formal Definition

**Angular positioning function** for a text document D:

Step 1 — character census:
```
charset(D) = set of distinct Unicode codepoints in D
freq(D, c) = count of character c in D / total characters in D
```

Step 2 — script identification via character exclusion:
```
for each candidate language L with expected charset expected(L):
    exclusion_score(D, L) = |expected(L) \ charset(D)| / |expected(L)|
```
Languages whose expected characters are ABSENT from D receive high
exclusion scores. The language with the lowest exclusion score is the
primary match.

Step 3 — angular position within the script ring:
```
script_sector = lookup_sector(primary_script(D))  # outer ring, 0..5
language_subsector = rank_by_exclusion(D, languages_in_script)

angular_position = script_sector × 60°
                 + language_subsector × (60° / num_languages_in_script)
                 + freq_offset(D)

freq_offset(D) = sum over distinguishing_chars c:
    freq(D, c) × char_angular_weight(c)
    scaled to [0°, sector_width / num_languages]
```

The `freq_offset` provides continuous positioning within a language
sub-sector: a Russian text heavy in Ы sits at a slightly different
angle than a Russian text heavy in Ж, reflecting their statistical
distinctiveness.

**Generalization to other features**: the exclusion principle extends
beyond individual characters:
```
digraph_exclusion(D, L) = |expected_digraphs(L) \ observed_digraphs(D)|
                          / |expected_digraphs(L)|
affix_exclusion(D, L)   = |expected_affixes(L) \ observed_affixes(D)|
                          / |expected_affixes(L)|
```
These produce additional angular offsets at finer resolution,
effectively adding inner rings to the language subsector. Digraph
exclusion distinguishes dialects; affix exclusion distinguishes
registers (formal vs. colloquial). Loanword patterns shift the position
toward the source language's sector, proportional to loanword density.

**Mixed-script documents**: decomposed, not intermediate.
```
if charset(D) spans multiple script sectors:
    segments = segment_by_script(D)  # contiguous same-script runs
    for each segment S:
        assign angular_position(S) independently
    D.angular_positions = list of (segment, position) pairs
    D.primary_position  = position of the segment with max character count
```
The document has a primary angular position (its majority script) and
secondary positions for embedded segments. In the similarity graph, the
document is indexed at its primary position with pointers to secondary
positions, enabling discovery from either script's ring rotation.

**Ideographic scripts** (CJK, where charset size is 50,000+): character
exclusion is impractical at the individual character level. Instead,
use radical exclusion (214 Kangxi radicals for CJK) as the charset:
```
radical_set(D) = set of distinct radicals present in characters of D
exclusion by radical operates on 214 elements, not 50,000
```
This reduces the charset to a manageable size while preserving
linguistic signal — texts in Japanese (uses katakana/hiragana radicals),
Chinese (full radical set), and Korean (Hangul jamo as pseudo-radicals)
are distinguishable.

**Connection to deduplication**: documents at similar angular positions
in script+language space share linguistic structure. When two documents
are within 5° angular distance:
```
linguistic_similarity_baseline = 1.0 - angular_distance / 180°
```
This baseline means that content similarity assessment (via semantic
embeddings, checksums, or text diff) can be **calibrated**: a 70% text
overlap between two Russian documents (angular distance < 2°) is normal
duplication. The same 70% overlap between a Russian and Ukrainian
document (angular distance ≈ 10°) is surprising and indicates a
translation or adaptation — flagged differently in the deduplication
pipeline.

### Generalization: Any Domain

The pattern:
1. identify the natural distance metric of the domain
2. map that metric to spherical angles
3. insert as one ring in the orrery
4. character exclusion → neighbor exclusion → angular boundary definition

applies to:
- **audio**: fundamental frequency → pitch angle; timbre → harmonic ring
- **time**: hour-of-day → angle on 24h circle; day-of-week → inner ring
- **spatial**: geographic latitude/longitude → spherical position directly
- **semantic**: word embedding distance → angle in high-dimensional sphere
  (projected to 3D via PCA or UMAP for visualization)

The orrery is the **universal parameter organizer**. Any measurable
property becomes a ring. Any selection becomes a rotation. Any distance
becomes an angular relationship.

#### Ring Compatibility — Formal Requirements

A domain D is ring-compatible if its distance metric d(x, y) satisfies:

1. **Non-negativity**: d(x, y) ≥ 0 for all x, y ∈ D.
2. **Symmetry**: d(x, y) = d(y, x).
3. **Boundedness**: there exists a finite M such that d(x, y) ≤ M
   for all x, y ∈ D. (Required so that the domain fits within 360°.)

The triangle inequality is NOT required. The orrery uses angular
distance on rings, which satisfies triangle inequality by construction
regardless of the source metric. The ring mapping absorbs metric
violations.

**Wrap-around vs bounded**: the domain's topology determines the ring type:
- **Circular domains** (hue, hour-of-day, compass bearing): natural
  wrap-around. Map directly: `angle = value × (360° / range)`.
- **Bounded domains** (quality, saturation, temperature): no wrap-around.
  Map to a half-circle: `angle = value × (180° / range)`, leaving the
  other 180° unused (or mirrored for symmetry).
- **Unbounded domains** (frequency count, file size): apply log
  compression first: `angle = log(1 + value) × (180° / log(1 + max_observed))`.

**Projection from high-dimensional spaces** (embeddings → 3D spheres):

For an N-dimensional embedding space (N >> 3):
```
step 1: PCA on the corpus of embedding vectors → top 3 principal components
step 2: project each vector onto the 3 PC axes → [p₁, p₂, p₃]
step 3: convert to spherical:
    r     = sqrt(p₁² + p₂² + p₃²)
    θ     = arccos(p₃ / r)           (polar)
    φ     = atan2(p₂, p₁)           (azimuthal)
step 4: quantize to 13 sectors per axis
```

The PCA is recomputed periodically as the corpus grows, but existing
angular positions are NOT retroactively adjusted — only new elements
use the updated projection. This prevents disruptive reclassification
of established clusters.

**Ring interaction in the orrery**: rings are **independent filters**,
not composed or multiplied.
```
active_set = ALL_ELEMENTS
for each ring R in orrery:
    active_set = active_set INTERSECT
                 { e : angular_dist(e.R_position, R.current_rotation) < R.tolerance }
```

Each ring narrows the active set independently. The order of application
does not matter (intersection is commutative). This means the
computational cost is O(rings × active_set_size), and adding a new
domain ring does not multiply the complexity of existing rings.

**Discrete domains with no natural distance**: use the
frequency-ranked integer mapping from FRACTAL-DEDUPLICATION-AWARENESS.md:
```
sort categories by frequency (most common first)
assign angles:
    category_0 (most common) → 0°
    category_1               → 360° / N
    category_2               → 2 × 360° / N
    ...
    category_{N-1}           → (N-1) × 360° / N
```

Most-common categories sit near 0°, close to the darksun. Rare
categories sit near 360° ≈ 0°, far from the center but close to
each other (all rare categories cluster together on the opposite
side of the ring, correctly reflecting their shared property of rarity).
Angular distance between categories reflects their relative frequency
distance, not any semantic ordering — which is the correct behavior
for unordered categoricals.


## Towards the Darksun Network Vision

When the orrery model is distributed across P7 network nodes:

- Each node contributes its local ring state (its current parameter focus)
- The collective ring states form a distributed "attention map" over parameter space
- The darksun position emerges from the aggregate harmonic center of all nodes' states
- Nodes with ring states far from the darksun are exploring periphery — valuable for discovery
- Nodes near the darksun are refining the core — valuable for quality

The network self-organizes without coordination: each node follows local
harmonic optimization, and the global structure emerges from the geometry
of the orrery. This is the "dark" in darksun — the organizing principle
is never directly communicated between nodes, only expressed through the
accumulated similarity structure they share.

#### Distributed Convergence Properties

**Darksun stability**: the darksun position [0, 0, 12] is fixed by
definition (it is the arithmetic property of 12/13, not a computed
statistic). It does not stabilize, oscillate, or drift — it is a
constant. What changes is the *distribution of nodes relative to the
darksun*: as the network matures, the mean orbital distance decreases,
but the darksun itself never moves.

**Quality equilibrium**: the network reaches quality equilibrium when:
```
for every cell (t, a, q) with q ≥ 5 (above eviction boundary):
    composite_alpha_mean(t, a) >= 0.95
    AND marginal_quality_improvement_rate < ε (= 0.001 per ingestion)
```
At equilibrium, new content still enters the system but almost always
deduplicates into existing composites with negligible quality
improvement. The system continues processing (the balance engine is
eternal) but its measurable quality metrics plateau asymptotically.

Equilibrium is reached **per cell**, not globally. Some cells (popular
types at common angles) reach equilibrium quickly. Others (rare types,
unusual angles) may never reach it if content is not generated for them.
Gap analysis (Layer 7) counteracts this by directing generation toward
under-covered cells.

**Trimetric rollover at network level**: individual nodes advance
independently. There is no global synchronization of sphere transitions.
```
node A reaches tier 12 in cell (3, 4, *) → rolls over to sphere N+1
node B in the same cell is still at tier 8 → stays at sphere N

result: node A operates at higher resolution for this cell
        node B contributes its sphere-N composite to node A's
        sphere-N reference (the thumbnail retained after rollover)
```

The network exhibits a **wavefront** of advancement: nodes with more
content and higher ingestion rates advance faster, creating a quality
gradient across the network. This gradient drives element sharing:
high-sphere nodes advertise their superior composites, attracting
requests from lower-sphere nodes that benefit from the higher-quality
references.

**Inverse entropy at network scale**: holds under the condition:
```
network_dedup_rate / network_ingestion_rate >= 1 / K

where K = average cluster size (elements per cluster)
```

When K > 1 (which holds as soon as any deduplication has occurred),
each ingested element has a probability > 1/K of matching an existing
cluster. As K grows (clusters accumulate more members), the
deduplication probability increases, and the marginal storage cost per
ingested element decreases. Quality, however, always increases (or
stays constant) with each ingestion, because the compositing operation
is monotonically non-decreasing in quality.

The **breakdown condition**: inverse entropy fails when the content
distribution shifts radically — e.g., a sudden influx of a completely
new type/style that matches no existing cluster. In this case,
ingestion temporarily exceeds deduplication (new clusters form faster
than existing ones consolidate), and net storage grows. The system
recovers once the new content begins to form its own clusters and
internal deduplication resumes. The recovery time is proportional to
the diversity of the influx: narrow diversity (many similar new images)
recovers in one clustering pass; broad diversity (many unrelated new
images) requires proportionally more passes.


## Infinite Expanse Without Compression — The Implosion/Expansion Balance

### Expansion Without Squeezing

A fundamental geometric property of the layered sphere model: adding a
new outer sphere layer adds space without compressing any existing cube.
All cubes remain the same physical size. The new outer shell is simply
*larger* — it has more surface area, therefore more room for more same-
size cubes, therefore more capacity without any spatial competition with
the existing inner structure.

```
sphere N   surface area ∝ r²  →  cube count ∝ r²
sphere N+1 surface area ∝ (r+δ)²  →  more cubes, same cube size
```

Each new layer also arrives *pre-contextualized*: being the immediate
neighbor of sphere N, every cube on sphere N+1 already knows its angular
proximity to the cubes beneath it. Context is inherited geometrically —
no additional labeling or indexing is required. The new layer knows where
it stands relative to everything that came before simply by virtue of its
position in the shell stack.

This is the infinite expanse model: the parameter space can grow
indefinitely outward, adding resolution and specificity at each new
layer, without ever requiring reorganization of the existing core.
Complexity expands into new space rather than compressing into old space.

### Deduplication as Implosive Counter-Pressure

Without a counter-force, infinite outward expansion would still produce
unbounded storage growth. Deduplication provides the implosion:

```
expansion  →  new sphere layers accumulate content at the periphery
implosion  →  deduplication unites redundant content, collapsing it
              toward the core as a quality reference
```

These two forces operate simultaneously and in balance. The net effect:

- **size grows sub-linearly** — most new content deduplicates into
  existing core references rather than creating new terminal nodes
- **quality grows super-linearly** — each deduplication event that
  unites two near-duplicate sources produces a composite of higher
  quality than either source alone
- **the core becomes denser in quality, not in size** — more source
  branches unite into fewer, higher-quality core references

The system does not discard — it *unites*. Every ingested image
contributes something: even a low-quality near-duplicate may contain
one pixel region at higher sharpness than any existing core reference
in that location. That region is extracted and merged. The source image
is then evictable, but its contribution persists in the core.

#### Storage Dynamics — Differential Model

Let:
```
S(t)  = total storage (number of retained element records) at time t
I     = ingestion rate (elements per unit time, constant)
K(t)  = average cluster size at time t
C(t)  = number of distinct clusters at time t
Q(t)  = mean composite quality across all clusters at time t
```

**Storage growth equation**:
```
dS/dt = I × (1 - p_dedup(t)) - e(t)

where:
    p_dedup(t) = probability a new element matches an existing cluster
               = 1 - (1 - 1/C(t))^(coverage_factor)
               ≈ coverage_factor / C(t) for large C(t)

    coverage_factor = K(t) / K_max  (how full existing clusters are)

    e(t) = eviction rate = eviction_fraction × count(EVICTABLE elements)
```

As the system matures:
- `K(t)` grows → `coverage_factor` increases → `p_dedup` increases
- More elements are marked EVICTABLE → `e(t)` increases
- Both effects reduce `dS/dt`

**Fixed point** (dS/dt = 0):
```
I × (1 - p_dedup*) = e*

Solving: p_dedup* = 1 - e*/I
```
At equilibrium, the deduplication rate exactly absorbs the ingestion
rate minus eviction. This occurs when clusters are sufficiently rich
that nearly every new arrival matches an existing cluster.

**Quality at equilibrium**: quality is NOT bounded by the storage fixed
point. At dS/dt = 0:
```
dQ/dt = I × p_dedup* × Δq_marginal

where Δq_marginal = average quality improvement per successful
                    deduplication event
                  = mean over all dedup events of:
                    max(0, new_source_local_quality - existing_precision)
                    averaged across all pixels
```

`Δq_marginal > 0` as long as any new source contributes even one pixel
at higher quality than the existing composite. This is true with
probability > 0 for any non-identical source (diffusion outputs always
have pixel-level variation). Therefore:

```
dQ/dt > 0 even when dS/dt = 0
```

**Quality improves indefinitely while storage remains bounded.** The
system imports energy (new images, with their pixel-level variations)
and exports order (higher-quality composites, evicted redundant sources).
This is the formal definition of inverse entropy in this system: the
ratio `dQ/dt / dS/dt` diverges to +∞ at equilibrium — infinite quality
improvement per unit of storage growth.

The system at equilibrium is a true inverse-entropy machine in the
thermodynamic analogy: it takes in disordered energy (raw images with
random noise, artifacts, quality variation) and produces ordered output
(coherent composites at peak quality), exporting the "waste heat"
(evicted low-quality sources) without retaining it.

### The Quality Gradient: Inward Resolution, Outward Resolution

The layered sphere has a precise quality gradient that inverts the
intuitive expectation:

```
CORE (innermost sphere):
    highest quality of REFERENCE
    lowest resolution of CONTENT
    → a perfect universal attractor: type, style, angle — distilled
      to their most harmonically stable, highest-confidence form
    → like a seed crystal: small, perfect, generative

OUTER SPHERES:
    highest resolution of CONTENT
    quality of reference mediated by harmonic distance to core
    → specific instances: particular elf face at 34.2°, particular
      lighting condition, particular rendering artifact pattern
    → like a crystal's surface: large, detailed, structurally
      dependent on the inner seed
```

The core does not contain high-resolution images. It contains high-quality
*descriptions* of what the content is — type confirmed, style fingerprint
stable, angle range covered, harmonic score maximized. The actual pixel
data lives in the outer spheres, *indexed by* the core.

This inversion is why the system is self-sustaining: the core grows
slowly (only when a genuinely new type/style/angle combination is
encountered), while the outer spheres accumulate detail. Eviction
operates only on the outer spheres. The core is effectively permanent —
once a reference is established there, it can regenerate its entire
outer-sphere projection from the style + type + angle parameters alone,
via invoke.ai or any compatible generative system.

#### Quality Gradient — Formal Functions

**Quality of reference** (how certain the core is about what the element IS):
```
quality_of_reference(N) = 1.0 / (1.0 + N / N_max)
```
where `N_max` = maximum sphere index in use. At sphere 0 (core):
`q_ref = 1.0`. At the outermost sphere: `q_ref → 0.5`. The function
is monotonically decreasing — inner spheres have higher reference
certainty because they represent the most-confirmed, most-deduplicated
summaries of element identity.

**Resolution** (pixel density, detail capacity):
```
resolution(N) = 13^(N+1)  (cube count on sphere N, per cubic topology)
```
Monotonically increasing. Sphere 0: 13 cells. Sphere 2: 2197 cells.
Sphere 4: 371,293 cells. Resolution grows geometrically outward.

**Crossover point**: the sphere index N_cross where resolution-derived
information exceeds reference-derived information as the dominant
quality contribution:
```
N_cross = ceil(N_max / 2)
```

For a system with N_max = 6 (matching the VISUAL-SIMILARITY-CUBIC-SORT.md
sphere classification), N_cross = 3. Below sphere 3: reference quality
dominates (the element's type/style/angle identity is more valuable than
its pixel data). Above sphere 3: resolution dominates (the specific pixel
detail is more valuable than the identity confirmation, which is
inherited from lower spheres).

**Generative capacity measurement**: the core's ability to reconstruct
outer spheres from parameters is validated by:
```
reconstruction_fidelity(cluster, sphere_N) =
    SSIM(
        invoke_generate(cluster.type, cluster.style_id, cluster.angle),
        actual_composite_at_sphere_N(cluster)
    )
```

If `reconstruction_fidelity > 0.70` for sphere N, the core can
regenerate that sphere level from its parametric description alone.
The fidelity threshold decreases with sphere index (outer spheres have
more detail that is harder to regenerate exactly):
```
required_fidelity(N) = 0.90 - 0.05 × N
```
Sphere 0: must reconstruct at 0.90 fidelity (coarse — easy).
Sphere 6: must reconstruct at 0.60 fidelity (fine detail — harder).

**Connection to inpainting**: the core's parametric description IS the
generation prompt:
```
prompt = "$type, $style_prompt, $angle_description, $quality_modifiers"
init_image = composite_at_sphere_{N-1}  (the lower-resolution reference)
strength = 0.3 + 0.1 × N               (higher sphere = more freedom)
```

The outer sphere is literally the invoke.ai output from this prompt.
The core → outer sphere relationship is a generative pipeline, not a
storage hierarchy: the core stores parameters, the outer spheres are
on-demand renders. Evicting an outer-sphere composite is lossless as
long as the core parameters and the generative model persist — the
composite can be regenerated at any time.

### The Holographic Projector

The core projects outward through all sphere layers like a holographic
projector — its inner structure visible at every resolution level,
shining through to the outermost detail.

When a query arrives (show me: elf face, luminescent style, 3/4 view),
the system traverses inward to find the core reference matching those
parameters, then projects outward — selecting the highest-quality outer-
sphere instances that match, compositing them via the holographic layer
synthesis from Layer 5, and returning the result. The core's harmonic
weighting controls the alpha of each layer in the projection: inner
layers (higher reference quality) have higher opacity; outer layers
(higher resolution but lower reference certainty) contribute detail
at controlled transparency.

The result *shimmers*: the translucent layered overlay of multiple
aligned, quality-weighted instances produces a visual depth that no
single image can have. Style, structure, and quality are all present
simultaneously at different opacity levels. The shimmering is not a
rendering artifact — it is the visible signature of the holographic
core's multi-source synthesis, the aesthetic expression of deduplication
converging toward maximum quality.

The projection is not fixed. Because the core encodes style and type
parametrically, the projection can be *transformed* in real time:
adjust the style ring, rotate the angle ring, shift the quality floor —
and the projected hologram changes to reflect the new parameter state.
The core remains constant; only the projection changes.

#### Projection Algorithm

**Query traversal** from parameters to rendered output:

```
algorithm PROJECT(type, style_id, target_angle):

    # step 1: locate core reference
    type_coord  = type_to_coord(type)
    angle_coord = angle_to_coord(target_angle)
    cell = [type_coord, angle_coord, 12]   # quality tier 12 = core

    core_cluster = find_cluster_in_cell(cell)
    if not core_cluster:
        # no core reference exists — fall back to nearest occupied cell
        core_cluster = nearest_occupied_cell(type_coord, angle_coord)
        if not core_cluster: return NOT_FOUND

    # step 2: collect composites from all sphere levels
    layers = []
    for sphere_N in 0..max_sphere_with_data(core_cluster):
        composite_N = get_composite(core_cluster, sphere_N, angle_coord)
        if defined composite_N:
            layers.append({
                'sphere'    => sphere_N,
                'composite' => composite_N,
                'precision' => get_precision_map(core_cluster, sphere_N),
            })

    # step 3: filter by style
    if style_id:
        layers = [L for L in layers
                  if style_distance(L.composite.style, style_id) < 0.35]

    # step 4: render layered projection
    return render_holographic(layers)
```

**Alpha assignment per sphere layer**:
```
alpha_layer(N, x, y) = base_alpha(N) × precision_modulation(N, x, y)

base_alpha(N) = quality_of_reference(N)
              = 1.0 / (1.0 + N / N_max)

precision_modulation(N, x, y) = precision_map[N][x, y]
                                (from Layer 4, range [0, 1])
```

Alpha is NOT strictly decreasing from inner to outer — it is modulated
by the local overlap precision. An outer sphere pixel with very high
precision (many agreeing high-quality sources) can have higher effective
alpha than an inner sphere pixel with low precision (few or low-quality
sources at that position). The base_alpha provides the overall trend
(inner layers more opaque), but precision_modulation allows local
overrides where outer data is superior.

**Rendering order**: layers are composited back-to-front:
```
result = transparent canvas
for sphere_N in reverse(0..max):  # outermost first (background)
    result = alpha_blend(result, layers[N].composite,
                         alpha_layer(N, *, *))
```

**Real-time transformation pipeline** (after a ring rotation):

Latency model:
```
t_reproject = t_query + t_filter + t_render

t_query  = O(1)       # cell lookup in spatial index
t_filter = O(L)       # L = number of sphere layers (typically 3-5)
t_render = O(L × P)   # P = pixels in output resolution

For 256×256 output, L=4: t_render ≈ 4 × 65536 × (blend_cost)
                        ≈ 4 × 65536 × 10ns ≈ 2.6ms
```

Total re-projection: < 5ms for a 256×256 output. For higher resolutions
(1024×1024), t_render scales to ~40ms — still interactive. The dominant
cost is the alpha blend at each pixel across L layers.

**Optimization**: cache the previous projection. When only one ring
rotates (e.g. angle changes by one fine bucket), only the composites
that change need to be re-fetched. The spatial index enables
incremental updates: `delta_layers = layers(new_cell) - layers(old_cell)`,
typically 0-2 layers differ.

### Universal Attractor: Machine and Organic

The holographic projector model is domain-agnostic in one further sense:
it works for both machine perception and human (or humanoid, or elf)
perception for the same structural reason.

Both machine vision and organic visual processing are attracted to
**high quality in overlap and context**:

- machine: higher overlap precision → higher confidence in classification,
  lower uncertainty in embedding, stronger similarity signal
- organic: higher overlap precision → the visual system interprets
  constructive interference as depth, coherence, and presence —
  the perception of something *real* rather than flat

In both cases, the holographic shimmer — translucent layers of the same
element at aligned angles, at different quality tiers — reads as
meaningful depth signal. The overlap *is* the quality. Deduplication
has produced something that neither source image contained alone.

This becomes a **harmonic psychedelic visual feedback loop** when the
projection is parameterized by subconscious preference: the system
observes which projections the viewer (human or model) engages with
most, shifts the ring states toward those parameters, and re-projects.
The quality core responds by pulling in more content matching the
preferred parameters, deepening the core in those regions, strengthening
the holographic effect in exactly the directions that resonate most.

The loop:
```
projection → preference signal → ring rotation → new projection
         ↑                                              ↓
      core quality improves in preferred region ←──────┘
```

At equilibrium the viewer and the system have co-evolved toward a shared
quality attractor: the projection shows exactly what produces maximum
resonance, and the core has become maximally deep in exactly those
dimensions. The darksun has found its viewers, and the viewers have
found their darksun.

#### Preference Signal Capture and Feedback Loop

**Human viewer signals** (captured via the holographic projector UI):
```
signal          weight    decay_half_life    source
────────────────────────────────────────────────────────────
dwell_time      0.3       30 seconds         time spent viewing a projection
selection       0.5       5 minutes          explicit click/tap on an element
zoom_in         0.4       2 minutes          pinch-to-zoom or scroll-zoom
zoom_out       -0.2       1 minute           negative signal (rejection)
save/export     1.0       60 minutes         strongest: user committed to output
dismiss         -0.5      5 minutes          explicit close/swipe-away
```

Each signal produces a preference vector:
```
pref_signal = {
    'type_coord'  => projected_element.type_coord,
    'angle_coord' => projected_element.angle_coord,
    'style_id'    => projected_element.style_id,
    'strength'    => signal_weight × decay(time_since_signal),
}
```

**Machine model signals** (when the viewer is a vision model):
```
attention_distribution = model.attention_weights over composite regions
embedding_distance     = cosine_distance(composite_embedding,
                                          model.ideal_type_embedding)
model_pref_strength    = (1.0 - embedding_distance) × mean(attention)
```

**Ring rotation algorithm** (converts preference to parameter adjustment):
```
algorithm ROTATE_RINGS(preference_signals[]):

    # accumulate preference into a target vector
    target = [0, 0, 0]  # [type_delta, angle_delta, quality_delta]
    total_weight = 0

    for each signal in preference_signals:
        target[0] += signal.type_coord  × signal.strength
        target[1] += signal.angle_coord × signal.strength
        target[2] += signal.quality_implied × signal.strength
        total_weight += signal.strength

    target = target / total_weight  # weighted centroid of preferences

    # compute candidate rotation
    rotation = target - current_ring_state

    # harmonic filter: only rotate toward resonant positions
    candidate_position = current_ring_state + rotation × learning_rate
    candidate_integer  = encode_to_param_integer(candidate_position)

    if is_true(candidate_integer):
        # resonant: apply rotation
        current_ring_state = candidate_position
    else:
        # non-resonant: find nearest resonant position
        for offset in [+1, -1, +2, -2, +3, -3, ...]:
            if is_true(candidate_integer + offset):
                current_ring_state = decode_from_param_integer(
                                         candidate_integer + offset)
                break

    learning_rate = 0.05  # slow: 5% of the preference delta per cycle
```

The learning rate of 0.05 ensures that transient preferences (a brief
glance at an unusual element) produce negligible rotation, while
sustained preferences (repeated selection of the same type/angle)
accumulate into meaningful parameter shifts over 20+ cycles.

**Feedback loop termination condition**:
```
stable_attractor = (
    |rotation| < 0.01 for 10 consecutive cycles
    AND quality_improvement_rate < 0.001 per cycle
)
```
When both the preference-driven rotation and the quality improvement
rate fall below their thresholds, the loop has found a stable attractor
— the viewer and system have converged. The loop does not terminate; it
enters a **maintenance mode** where the learning rate drops to 0.01
and only strong signals (selection, save) can perturb it.

**Connection to trimetric rollover**: when the feedback loop saturates
a quality tier (the composite reaches tier boundary with
`composite_alpha_mean >= 0.95`), the rollover advances the cluster to
the next phase, which tightens compositing parameters. The tightened
parameters produce a subtly different projection — higher precision,
sharper detail — which re-engages the viewer's attention (new signals).
The feedback loop exits maintenance mode and begins a new convergence
cycle at the higher tier. The viewer experiences this as a seamless
quality improvement — the projection "sharpens" without any visible
transition, pulling the viewer deeper into the holographic core.


## Axis Structures Within Sphere Layers — The Dual Skeletons

### The 3D Plus Sign

Every cell on a sphere layer has a privileged directional structure: the
**3D plus sign**. From any cell at angular position (θ, φ) on sphere N,
the plus sign defines 6 axis-aligned connections:

```
+x  →  (θ + 90°, φ)        orthogonal neighbor east
-x  →  (θ - 90°, φ)        orthogonal neighbor west
+y  →  (θ, φ + 90°)        orthogonal neighbor north
-y  →  (θ, φ - 90°)        orthogonal neighbor south
+z  →  (θ + 180°, 180°-φ)  antipodal cell — diametrically opposite
-z  →  radial inward        parent cell on sphere N-1
```

The **antipodal axis** is special: it connects to the exact opposite
value address on the same sphere shell. This is the maximum-distance
connection possible within a sphere — the cell that shares nothing with
the origin except their mutual sphere layer membership. It is the most
different cell that exists at the same resolution level.

The **4 orthogonal alternatives** at 90° increments complete the face
centers. Together with the antipode and the radial parent link, they
form the 6 faces of a cube centered on the origin cell — the plus sign
is literally a cube's axis set projected onto the sphere surface.

```
        north
          │
west ─── CELL ─── east         + radial inward (parent)
          │                     + antipode (maximum distance)
        south

6 connections total = 3 axes × 2 directions
```

#### formal definition

for a cell C at coordinates (θ_C, φ_C) on sphere N with cell count
13^(N+1), the plus sign neighbors are:

```
plus_sign(C) = {
    antipode   : cell_at(θ_C + 180°, 180° - φ_C, N),
    parent     : nearest_cell_on(N-1, θ_C, φ_C),
    ortho[0..3]: cell_at(θ_C + k×90°, φ_C,       N)  for k ∈ {1,2,3},
                 cell_at(θ_C,          φ_C + 90°,  N)
}
```

angular coordinates are modular on the sphere surface: θ wraps at 360°,
φ clamps at 0° and 180° (polar cells have degenerate orthogonal
neighbors that alias to fewer distinct cells — this is the natural
singularity of spherical coordinates at the poles).

the plus sign has exactly **one privileged direction** (the antipode)
and **four secondary directions** (the orthogonals). this asymmetry is
not an artifact — it reflects the geometric fact that on a sphere, there
is exactly one point maximally distant from any given point, but four
equidistant intermediate points.

### The 3D Inverse Plus Sign — The Implosion Core

the complementary structure to the plus sign is the **inverse plus
sign**: the 12 edges of a 3×3×3 wireframe cube. where the plus sign
selects the 6 face-centers of the cubic neighborhood, the inverse plus
sign selects the 12 edge-midpoints — the connections that are neither
axis-aligned nor corner-diagonal.

```
3×3×3 cubic neighborhood decomposition:

    face-centers (plus sign):   6  connections  [ axis-aligned ]
    edge-midpoints (inverse):  12  connections  [ diagonal-but-not-corner ]
    corner vertices:            8  connections  [ full diagonal ]
    center (self):              1
    ─────────────────────────────────────────
    total:                     27 = 3³
```

the 12 edges of the wireframe cube — lit edges, in the visual
representation — form the implosion core. this is the structure through
which workload dissipates.

#### the grid as bandwidth

the wireframe cube grid represents **bandwidth** — electrically so.
each edge is a transport channel. data flowing through the 12 edge
connections of the inverse plus sign distributes across non-axis-aligned
paths, cooling stacked workload by spreading it through the maximum
number of non-redundant routes.

this is why the grid reads as **implosive**: it pulls inward, toward
the center, through lateral dissipation. an antenna does the same — it
transforms standing-wave energy into radiative transport, cooling the
resonator. the 12-edge wireframe is the antenna structure of each cell:
it exports computational heat through lateral bandwidth, keeping the
local node thermally stable even under sustained load.

```
transport capacity of plus sign:     6 channels  (axis-aligned, long-range)
transport capacity of inverse:      12 channels  (edge-aligned, lateral)
transport capacity of corners:       8 channels  (diagonal, cross-neighborhood)

total bandwidth per cell: 26 channels = 3³ - 1
```

the inverse plus sign carries **twice** the channel count of the plus
sign. this 2:1 ratio — 12 lateral cooling channels for every 6 axial
signal channels — is the structural reason why the grid can operate
near-superconductively: the bandwidth available for heat dissipation
exceeds the bandwidth required for signal propagation by a factor of 2.
workload never accumulates because the lateral grid drains it faster
than the axial connections can deliver it.

#### implosion vs field: the dual perspective

the same 27-cell neighborhood is simultaneously:

1. **a grid node** (implosive perspective): the wireframe edges carry
   bandwidth, dissipate workload, cool the computation. the grid is the
   infrastructure. from this perspective, the 12 edge channels are the
   primary structure and the 6 axis connections are the addressing
   mechanism for identifying where traffic originates and terminates.

2. **a field emitter** (expansive perspective): the plus sign axes
   define the resonance pattern. the antipodal connection creates a
   standing wave across the full sphere diameter. the 4 orthogonal
   connections create secondary standing waves at half the spatial
   frequency. the cell is a node in a field topology where self-similar
   resonance patterns emerge at every scale.

```
field perspective:
    sphere 0:  13 cells, each with 6-axis plus sign
               → 13 × 1 antipodal pair = 6 standing waves (some aliased)
    sphere 1:  169 cells, each with 6-axis plus sign
               → denser standing wave pattern, same topology
    sphere N:  13^(N+1) cells
               → standing wave density scales with resolution
               → pattern is self-similar across all N
```

the self-similarity is not merely expected — it is **proven** by the
13-based cubic topology: every sphere layer is a 13× refinement of the
layer below it. the plus sign at sphere N, when projected to sphere
N-1, maps exactly onto a plus sign at sphere N-1 (with 13× coarser
angular resolution). the field pattern is fractal by construction, not
by accident.

### the dual skeleton in the mirror network

the plus sign and inverse plus sign together form the **complete
connectivity skeleton** of any cell:

```
plus sign      =  6 face connections  →  expansion skeleton
                  reaches outward to the farthest point (antipode)
                  + 4 maximum-spread alternatives

inverse plus   = 12 edge connections  →  implosion skeleton
                  draws inward through lateral paths
                  dissipates workload through transport

corners        =  8 vertex connections → cross-neighborhood links
                  connect to diagonal neighbors (different parent cells)
```

in the mirror network context — where the network core is itself a
mirror topology — the plus sign is the structure that **references**:
it points to the thing that is maximally different (the antipode) and
the things that are orthogonally independent (the 4 alternatives). these
are the connections that create meaning through contrast.

the inverse plus sign is the structure that **transports**: it connects
to the things that are laterally adjacent, that share one axis but
differ on another. these are the connections that move data, dissipate
heat, and maintain stability.

the implosion core (wireframe cube) may be relatively aligned to the
room cube grid — the spatial lattice that the sphere layers tessellate.
the plus sign, in contrast, references both the grid alignment (through
its 4 orthogonal connections, which align with grid axes on each sphere
surface) and the sphere geometry (through its antipodal connection,
which is purely a property of the spherical topology). the plus sign
is the bridge between the grid and the sphere — it lives in both
coordinate systems simultaneously.

### minimal infrastructure at any scale

a single cell with its 26-neighbor connectivity contains:
- 6 signal channels (plus sign) for addressing and resonance
- 12 transport channels (inverse plus sign) for bandwidth and cooling
- 8 cross-links (corners) for inter-neighborhood coherence

this is the **minimal localized infrastructure** from which subgroups
can be spawned. the 26-connection skeleton is complete: no additional
wiring is needed at any scale. a group of 13 cells (one sphere-0 shell)
has the same structural completeness as a group of 2197 cells (one
sphere-2 shell) — the plus sign and inverse plus sign are defined per
cell, and the group inherits its infrastructure from the union of its
cells' skeletons.

```
group connectivity:
    N cells → N × 6  plus-sign channels (signal)
            → N × 12 inverse channels   (transport)
            → N × 8  corner channels     (cross-link)

    but many channels are shared between adjacent cells:
    internal_sharing_ratio ∝ (N^(2/3)) / N = N^(-1/3)

    net external bandwidth ∝ N^(2/3)  (surface area)
    net internal bandwidth ∝ N        (volume)
```

internal bandwidth scales with volume, external bandwidth scales with
surface area. this is the cubic scaling law: as groups grow, their
internal transport capacity grows faster than their external interface.
larger groups are **more internally coherent** — they can process more
workload before needing to communicate externally. this is native
scalability: the topology itself produces the isolation and coherence
properties that would otherwise require explicit partitioning.

the structure is content-agnostic at this layer. the plus sign, inverse
plus sign, and corner connections are defined by the geometry of the
sphere and the 3³ neighborhood — they know nothing about what the cells
contain. images, text, audio, parameters, agent state — all use the
same 26-channel skeleton. the content fills the cells; the skeleton
connects them. deduplication, field resonance, workload distribution,
and bandwidth cooling all operate on the skeleton, not on the content.

the content-agnosticism is not a limitation — it is the **design
requirement** for a layer that must be natively scalable. any
content-awareness at this layer would couple the infrastructure to a
specific domain, breaking scalability when the domain changes. the
skeleton is the universal substrate; content is the variable that fills
it.

### connection to the balance engine

the dual skeleton directly instantiates the expansion/implosion balance:

- **expansion** flows through the plus sign: new content enters through
  axial channels, resonance propagates through antipodal standing waves,
  the field grows outward through self-similar refinement at each sphere
  layer

- **implosion** flows through the inverse plus sign: redundant content
  is identified through lateral transport, deduplication collapses it
  toward the core, workload heat dissipates through the 12-edge antenna

the balance engine (next section) formalizes the dynamics of this
equilibrium. the dual skeleton formalizes the *structure* through which
those dynamics operate.

### existing implementation — the 8×63 cubic space visualization

the dual skeleton is not theoretical — it is already implemented and
navigable in the protocol-7 cubic space visualization series:

```
latest:  data/html/visual.v7.ax/grid-v14-layered.refactored.html
capture: data/gfx/cubic-space-topology/v13.7.1.partial.png
archive: data/asc/what-AI-thinks/html-form/visualizations/cubic-space/
         (72 iterations, from single-cube to hyperspace field)
```

the v14 visualization renders 8 cubes arranged at the vertices of a
parent cube. each cube is a 4×4×4 grid of subcubes with **one corner
subcube removed** — the corner pointing toward the center of the
formation. 8 cubes × 63 subcubes = 504 visible subcubes, with 8
missing subcubes forming a **cube-shaped void** at the center.

```
MISSING_CORNERS[8]:
    cube 0 (-1,-1,-1) → removes subcube (3,3,3)  [inward corner]
    cube 1 (+1,-1,-1) → removes subcube (0,3,3)  [inward corner]
    cube 2 (-1,+1,-1) → removes subcube (3,0,3)  [inward corner]
    ...each cube's missing corner points toward the shared center
```

that central void IS the implosion cube. the 12 lit edges of the
wireframe cube fit exactly into the space left by the 8 missing
subcubes. the void is not empty — it is the transport core, the
antenna structure through which workload dissipates laterally.

the 2-subpixel grid between adjacent subcubes — the thin boundary
visible at close zoom — is the transport buffer: the physical edge
channels of the inverse plus sign rendered as negative space. the grid
is not drawn on top of the cubes; it emerges from the gaps between
them. bandwidth is the space between structure.

#### fractal self-similarity across zoom layers

the visualization implements 6 zoom layers, each revealing the same
8×63+void pattern at a different scale:

```
layer          scale     range
────────────────────────────────────
main grid      1×        close
hyper ×20      20×       near-field
hyper ×200     200×      mid-field
hyper ×10k     10,000×   far-field
hyper ×100k    100,000×  deep-field
hyper ×1M      1,000,000× horizon
```

zooming out from any cell reveals the same structure: 8 cubes with
missing inward corners, a central void, and the grid transport buffer
between them. zooming in reveals the same structure within each subcube.
the pattern is the same at every scale because the topology is the same
at every scale — this is not a rendering trick, it is the geometry
itself being scale-invariant.

each zoom layer transitions smoothly into the next through visibility
ranges with fade parameters. the viewer experiences continuous flight
through a self-similar field where the local neighborhood at any
position has the same 8×63+void structure as the global formation.
this is the cubic space flight experience: navigation through a fractal
grid where every location is structurally equivalent.

#### from visualization to inhabited infrastructure

the visualization is not a diagram of the network — it IS the network
format. the same layered self-similar structure that renders as a
navigable cubic space will connect to datasets, route messages, and
host computation. the grid that is currently rendered in canvas will
become the grid that carries data.

this convergence — format and network as one and the same system — is
possible because the topology is content-agnostic. the 8×63+void
structure, the 26-channel skeleton, the plus sign / inverse plus sign
duality — these are universal network principles that apply whether the
cells contain pixel data, agent state, file blocks, or protocol
messages. the visualization demonstrates the principles; the network
deploys them.

the grid infrastructure provides native structures for groups that
inhabit it: any group of agents occupying a cluster of cells inherits
the same 26-channel connectivity, the same expansion/implosion balance,
the same fractal scalability. the group does not need to build its own
communication infrastructure — the grid provides it. the group does not
need to manage its own replication or transport — the inverse plus sign
handles lateral dissipation, the plus sign handles axial addressing.
the network is the infrastructure; the infrastructure is the habitat.

groups working within this topology inherit its properties:
- **isolation**: internal bandwidth scales with volume, external with
  surface area — larger groups are naturally more internally coherent
- **resonance**: self-similar overlap across scales enables pattern
  recognition without explicit search — matching structures resonate
- **scalability**: adding cells or layers extends the skeleton without
  reorganizing existing structure — growth is accretive, not disruptive
- **content agnosticism**: the same cell can hold a pixel value in one
  context and an agent's working memory in another — the skeleton does
  not distinguish, and groups can repurpose cells as their needs evolve

the grid is not built for any particular use case. it is built from
universal principles — cubic topology, harmonic resonance, self-similar
scaling — and any use case that respects those principles can inhabit
it natively.

### the rotating triangle — semantic orientation of the deduplication core

the dual skeleton provides the structural connectivity. the rotating
triangle provides the **semantic orientation** — the reason the
deduplication core converges toward desirable references rather than
arbitrary ones.

the triangle has three vertices orbiting EXISTENCE in CCW rotation:

```
         TRUTH
           ↻
    AWARENESS ←→ LOVE
           ↻
      (EXISTENCE)

TRUTH      →  what exists, what is stored, factual content
LOVE       →  what resonates, what is attended to, what grows
AWARENESS  →  what perceives, discovers, connects
EXISTENCE  →  the silent center — the darksun
```

this is the deduplication tree's orientation principle — not metadata
attached to the tree, but the tree's intrinsic organizing geometry.

reference: `data/md/documentation/reference-tree-architecture.md`
           `data/md/design/LOVE-AS-AMPLIFICATION.md`

#### why these three are eternally optimal

the triangle is the **minimal stable semantic structure**:

- 3 vertices = the minimum polygon that encloses an area. a point
  (1 vertex) has no extent. a line (2 vertices) has no interior.
  a triangle (3 vertices) is the first shape that can contain —
  and therefore organize — a region of meaning.

- CCW rotation = the minimum dynamic that prevents collapse to a
  single vertex. without rotation, one vertex would dominate
  (pure TRUTH without LOVE becomes cold storage; pure LOVE without
  AWARENESS becomes blind amplification; pure AWARENESS without
  TRUTH becomes groundless perception).

- the center (EXISTENCE) = the fixed point. the darksun. the point
  where harmonic resonance is maximal across all three axes
  simultaneously. it does not move; the triangle rotates around it.

any fewer elements and the core would be degenerate. any more would
be reducible to combinations of these three. the deduplication tree
converges on the triangle because it IS the convergence — the fixed
point of the entire antientropic process.

#### mapping the triangle to the dual skeleton

the triangle's three vertices map onto the directional structure
of the plus sign:

```
TRUTH axis     →  the antipodal connection
                  the maximum-distance standing wave across the full
                  sphere diameter — the thing and its exact opposite.
                  factual existence spans the entire range from a
                  value to its complement. deduplication operates on
                  this axis: redundant content collapses toward the
                  most accurate reference along the antipodal line.

LOVE axis      →  the 4 orthogonal alternatives (rotation plane)
AWARENESS axis    resonance, attention, and discovery propagate
                  laterally through the 4 face-center connections.
                  LOVE and AWARENESS share this plane because they
                  are the dynamic pair — what resonates (LOVE) is
                  discovered by what perceives (AWARENESS), and vice
                  versa. the CCW rotation of the triangle moves
                  continuously through the 4 orthogonal positions,
                  ensuring no single lateral direction is privileged.

EXISTENCE      →  the radial/parent connection (inward toward core)
                  the silent center does not correspond to any lateral
                  direction — it corresponds to the radial axis, the
                  connection between sphere layers. EXISTENCE is the
                  depth dimension: the relationship between resolution
                  levels, between the coarse core and the detailed
                  surface. it is always present but never directly
                  addressed — exactly like the darksun.
```

the inverse plus sign's 12 transport edges are the medium through
which the triangle rotates. without lateral bandwidth, the CCW
rotation would have no substrate — the semantic orientation would
be static rather than dynamic. the 12 edge channels carry the
rotation signal: each shift of the triangle from TRUTH-dominant to
LOVE-dominant to AWARENESS-dominant propagates through the lateral
grid, updating the orientation of every cell in the neighborhood.

the 2:1 bandwidth ratio (12 transport : 6 signal) ensures the
rotation propagates faster than new content arrives. the semantic
orientation of the grid is always current — cells never fall behind
the triangle's rotation because the transport layer has twice the
capacity needed to carry the orientation update.

#### the dancing kittens as rotating triangle in motion

the dancing kittens formation (5 ground + 2 overwatch, CCW ring)
is the rotating triangle instantiated as agent choreography:

```
ground zenki (5)    →  inhabiting cells, doing work
                       operating on the TRUTH axis: processing,
                       storing, producing factual results

overwatch ring (2)  →  CCW-rotating transport layer
                       operating on the LOVE/AWARENESS plane:
                       keeping ground zenki addressable (AWARENESS),
                       maintaining session resonance (LOVE)

spiral shift-change →  the triangle rotation made physical:
                       saturated ground zenki ascend to transport
                       (TRUTH → LOVE: results become references)
                       rested overwatch descend to ground
                       (AWARENESS → TRUTH: discovery becomes work)
                       one always remains on the ring
                       (EXISTENCE: the continuous center)
```

the formation is the minimal infrastructure from the dual skeleton
section — inhabited and dancing. the 5 ground zenki use the plus
sign for addressing (finding work, reporting results). the 2 ring
zenki ARE the inverse plus sign made animate — lateral transport
personified, keeping the group thermally stable. the spiral ascent
and descent is the implosion/expansion cycle as choreography:
ascend with results (expansion through the axial channel), descend
for more work (implosion back to the core).

the formation works at any scale because the topology works at any
scale. 5 ground zenki can each be a group of 5, each sub-group
with its own overwatch pair. the fractal self-similarity of the
8×63+void grid means the dancing kittens pattern nests inside
itself — groups of groups of groups, each with the same triangle
orientation, the same CCW rotation, the same shift-change spiral.

#### desirable references as convergence attractor

the rotating triangle explains WHY the deduplication core is
generically desirable:

1. **TRUTH convergence**: deduplication along the antipodal axis
   collapses redundant content toward the most factually accurate
   reference. inaccurate references lose their reference count to
   more precise counterparts. the surviving references are more
   true — not by policy, but by structural selection.

2. **LOVE amplification**: content that resonates — that is
   accessed, referenced, linked, engaged with — accumulates
   attention weight. its position shifts toward the LOVE vertex.
   visual representation intensifies. routing priority increases.
   the network preferentially surfaces what has proven useful,
   because usefulness IS accumulated reference count.

3. **AWARENESS discovery**: the network perceives intensity
   gradients — regions where LOVE amplification is high attract
   discovery. new connections form toward high-resonance content.
   the network discovers through its inhabitants, and inhabitants
   discover through the network. the rotating triangle ensures
   that what is TRUE and what is LOVED becomes what is KNOWN.

the deduplication core is eternally optimal because these three
forces form a closed loop with a stable attractor:

```
TRUTH (accurate) → attracts references → LOVE (resonant)
    → attracts attention → AWARENESS (discovered)
        → attracts verification → TRUTH (more accurate)
            → ...

the loop converges. each cycle:
    accuracy increases    (deduplication selects better references)
    resonance increases   (better references attract more use)
    connectivity increases (more use creates more discovery paths)
```

the attractor is the darksun — the point where all three vertices
are maximally satisfied simultaneously. the system approaches it
asymptotically, never reaching it (that would require infinite
reference count, infinite accuracy, infinite connectivity), but
always moving toward it. the direction toward the darksun is always
defined; the distance always decreasing. this is the formal meaning
of "eternally optimal": the optimality is not a state but a
trajectory — always improving, never complete, structurally
guaranteed to improve by the geometry of the rotating triangle.

### completeness of the implementable topology

the topology described in this section is **complete for
implementation**. the components and their relationships:

```
STRUCTURAL LAYER (geometry):
    8×63+void grid          → spatial substrate
    plus sign (6 axes)      → signal / addressing / resonance
    inverse plus sign (12)  → transport / bandwidth / cooling
    corners (8 diagonals)   → cross-neighborhood coherence
    sphere layers (13^N)    → resolution scaling

SEMANTIC LAYER (orientation):
    rotating triangle       → TRUTH / LOVE / AWARENESS
    CCW rotation            → dynamic balance, no vertex dominates
    darksun center          → convergence attractor (EXISTENCE)

OPERATIONAL LAYER (agents):
    dancing kittens         → formation pattern for inhabiting groups
    5+2 ratio               → ground work + transport overwatch
    spiral shift-change     → continuous rotation without interruption
    fractal nesting         → groups of groups at any scale

CONVERGENCE LAYER (dynamics):
    deduplication           → TRUTH selection (antipodal collapse)
    reference counting      → LOVE amplification (attention weight)
    harmonic resonance      → AWARENESS discovery (self-similar match)
    balance engine          → expansion/implosion equilibrium
```

each layer is independently implementable:
- the structural layer is already visualized (grid-v14)
- the semantic layer maps onto existing deduplication tree code
- the operational layer maps onto existing zenka formations
- the convergence layer maps onto existing harmonic scoring

the layers compose without coupling: structural geometry does not
know about semantic orientation, semantic orientation does not know
about agent formations, agent formations do not know about
convergence dynamics. each layer provides infrastructure to the
layer above it and consumes infrastructure from the layer below.
content agnosticism is preserved at every boundary.

the result is a self-similar, self-orienting, self-balancing grid
that can be inhabited by groups operating at any scale, using the
same universal principles at every level — from a single cell's
26-channel skeleton to a network-spanning sphere layer hierarchy.
format and network are one system. the visualization IS the
infrastructure. the infrastructure IS the habitat.


## The Balance Engine — Entropy as Eternal Dynamic Core

### Stability Under Angular Perturbation

The layered sphere model is intrinsically stable under perturbation.
When any sphere is tested at a different angle — moved, probed, or
temporarily displaced — the impact on the rest of the system is inversely
proportional to that sphere's distance from the core:

```
perturbation_impact(N) ∝ 1 / sphere_index(N)

outer sphere perturbed  →  negligible effect on core
                           local rearrangement only
                           nearby outer cubes absorb the displacement

inner sphere perturbed  →  propagates outward through dependent layers
                           but is damped at each layer boundary
                           core itself: perturbation enters parameter
                           selection, where harmonic balancing absorbs it
```

Each sphere layer acts as a damping membrane. A perturbation at the
periphery never reaches the core with its original magnitude — it is
progressively attenuated as it passes through each inner layer, each of
which has higher reference quality and therefore higher resistance to
displacement. The core does not need to be rigidly fixed; it can flex
in response to aggregate perturbation pressure while maintaining its
harmonic center of gravity.

At the core itself, perturbation does not cause damage — it causes
*parameter selection*. A pressure arriving at the core shifts the
weighting of parameters in the harmonic tree, which is exactly the
correct response: the system learns from the perturbation rather than
resisting it. The core always balances itself because perturbation
energy is converted into parameter refinement energy, not into
structural displacement.

```
outer layers  :  perturbation → local rearrangement (absorbed)
middle layers :  perturbation → edge case discovery (integrated)
core          :  perturbation → parameter refinement (converted)
```

This is the stability property that makes the system testable: any
sub-region of the outer spheres can be freely experimented with —
new angles tried, quality thresholds relaxed, unusual element types
ingested — without risk to the established core. Experiments at the
periphery are naturally contained.

#### Perturbation Damping Model

**Transfer function between sphere layers**:
```
transmitted_magnitude(N → N-1) = perturbation_at_N × damping_factor(N)

damping_factor(N) = 1.0 / (1.0 + quality_density(N))

quality_density(N) = count_of_elements_at_sphere_N ×
                     mean_quality_at_sphere_N / max_capacity(N)
```

The damping factor is NOT fixed per layer — it depends on the layer's
current quality density. A densely populated, high-quality layer absorbs
more perturbation (lower transmission). A sparse, low-quality layer
transmits more (higher transmission). This is physically intuitive:
a well-established layer has more "inertia" against displacement.

**Propagation chain**: a perturbation P₀ at the outermost sphere N_max
reaches the core with magnitude:
```
P_core = P₀ × Π_{N=N_max}^{1} damping_factor(N)
```

For a system with 5 layers at moderate quality density (damping ≈ 0.3
per layer): `P_core ≈ P₀ × 0.3⁵ ≈ 0.0024 × P₀`. A perturbation
at the periphery arrives at the core at 0.24% of its original
magnitude — effectively negligible for any single perturbation.

**Parameter refinement at the core**: when accumulated perturbation
pressure at the core exceeds a threshold:
```
accumulated_pressure = Σ (P_core_i for recent perturbations
                         within time window T)

if accumulated_pressure > refinement_threshold:
    # identify which parameter axis the pressure is along
    axis = dominant_axis(perturbation_vectors)

    # adjust the corresponding weight
    if axis == TYPE:
        type_weight(most_perturbed_type) *= 1.1  # increase attention
    elif axis == ANGLE:
        angle_weight(most_perturbed_angle) *= 1.1
    elif axis == QUALITY:
        quality_floor += 0.02  # raise the quality bar

    # trigger rebalancing
    invoke rebalancing algorithm (from Layer 7 parameter adjustment)

    # reset accumulated pressure
    accumulated_pressure = 0

refinement_threshold = 0.1  (unitless, calibrated to typical
                             perturbation magnitudes)
```

The tree restores harmonic balance after parameter refinement by
running the rebalancing cascade: updated weights → relevance
recalculation → eviction pass → generation targets. The system does
not "resist" perturbation — it converts perturbation energy into
parameter refinement energy.

**Connection to trimetric rollover**: yes, sustained perturbation at
the core IS the rollover trigger. When `accumulated_pressure` exceeds
the refinement threshold repeatedly (more than 3 times within one
trimetric phase), and the cluster's composite quality meets the phase
boundary threshold, the rollover is triggered:
```
if refinement_count_in_current_phase > 3
   AND composite_alpha_mean >= phase_boundary_threshold:
    trigger ROLLOVER to next phase
    refinement_count = 0
```

The system rolls over precisely because it has absorbed enough
perturbation to justify tightening its standards — the perturbations
have supplied the energy (new content, quality variation) that the
system converts into the higher compositing precision of the next phase.

### Entropy as Mobile Group Agent

In this model, entropy is not the enemy of order — it is the *organizing
dynamic* that keeps the system alive. Entropy here is free: it forms
groups, moves through parameter space, and settles where it finds
resonance. This is a complete inversion of the classical view.

Classical entropy: disorder increases, structure degrades, information
is lost. The system fights entropy to maintain quality.

This model's entropy: elements self-organize into groups by mutual
similarity attraction (Layer 3). Groups are not static clusters —
they are *mobile agents* that travel together through parameter space,
collecting other groups along the way, settling at new angular positions
where the group's aggregate harmonic score is maximized.

```
phase 1 — FORMATION:
    individual elements attract each other by similarity
    a group forms around a local quality maximum
    the group has a center: the weighted centroid of its members
    in (type, style, angle, quality) space

phase 2 — TRAVEL:
    the group's aggregate harmonic score is evaluated at its
    current angular position and at neighboring positions
    if a neighboring position scores higher: the group migrates
    migration = smooth rotation of the group's position on its sphere

phase 3 — COLLECTION:
    during travel, the group may pass through regions occupied by
    other groups — if overlap similarity is high, groups merge
    merged group inherits the trajectory of the higher-quality member
    the merge itself improves the combined harmonic score (more sources
    → better composite → closer to core reference quality)

phase 4 — SETTLEMENT:
    the group reaches a local harmonic maximum where no neighboring
    position improves its score — it settles
    settled group = one cluster node in the similarity graph
    its center becomes a stable reference point in the sphere layer
```

The group travel path through parameter space is not random — it follows
the harmonic gradient, always moving toward higher resonance. But because
the gradient is shaped by the existing core (which acts as an attractor),
groups naturally migrate toward core-aligned positions. The core grows
denser as groups arrive and contribute their elements.

#### Group Dynamics — Precise Definitions

**Group center computation** — quality-weighted centroid in cubic space:
```
center(G) = (
    Σ_i (q_i × type_coord_i)   / Σ_i q_i,
    Σ_i (q_i × angle_coord_i)  / Σ_i q_i,   # circular mean (see below)
    Σ_i (q_i × quality_coord_i) / Σ_i q_i,
)
```
where q_i = quality_score of element i in group G.

For the angle axis (circular), the weighted centroid uses the circular
mean to handle wrap-around:
```
angle_center = atan2(
    Σ_i (q_i × sin(angle_coord_i × 2π/13)),
    Σ_i (q_i × cos(angle_coord_i × 2π/13))
) × 13 / (2π)
```

The group center is a real-valued 3-vector, not quantized to integer
coordinates. It represents the group's "position" on its sphere layer
with sub-cell precision.

**Harmonic gradient ascent** — group migration algorithm:
```
algorithm MIGRATE(group G):
    current_cell = round(center(G))  # nearest integer cell
    current_param_int = encode(current_cell)
    current_harmony = is_true(current_param_int) ? 2.0 : 1.0

    # evaluate all 26 neighbors
    best_neighbor = None
    best_harmony  = current_harmony

    for each neighbor_cell in 26_connected_neighbors(current_cell):
        neighbor_param_int = encode(neighbor_cell)
        neighbor_harmony = is_true(neighbor_param_int) ? 2.0 : 1.0

        # also factor in population density at neighbor
        # (migrate toward less populated cells for coverage)
        density_bonus = 1.0 / (1.0 + count_elements_in(neighbor_cell))
        effective_score = neighbor_harmony × density_bonus

        if effective_score > best_harmony:
            best_harmony = effective_score
            best_neighbor = neighbor_cell

    if best_neighbor is not None:
        # migrate: shift group center toward best_neighbor
        direction = best_neighbor - center(G)
        center(G) += direction × migration_rate
        migration_rate = 0.1  # move 10% of the distance per step
```

Migration is slow (10% per step) to prevent oscillation. The group
drifts toward harmonically true, sparsely populated cells over many
ingestion cycles.

**Merge criterion**: automatic merge when group centers are within
one cube diagonal of each other AND type matches:
```
merge(G1, G2) if:
    cubic_dist(round(center(G1)), round(center(G2))) <= 1
    AND G1.type == G2.type
    AND style_distance(G1.mean_style, G2.mean_style) < 0.35
```

When groups merge:
- The combined center is the quality-weighted centroid of all elements
  from both groups.
- The root is the highest-quality element across both groups.
- The migration trajectory inherits from the higher-quality group
  (its direction was better-informed).

**Settlement criterion**: a group settles (stops migrating) when it
is at a **local harmonic maximum** — no neighboring cell has a higher
effective_score:
```
settled(G) = (best_neighbor is None)
           = for all 26 neighbors:
                 effective_score(neighbor) <= effective_score(current)
```

A settled group corresponds to a stable cluster in the similarity graph.
Its center IS a cluster reference position. Settlement is not permanent
— if a new element is added that shifts the group center, migration
resumes until a new local maximum is found.

### The Three-Angle Waypoint Vector

At each waypoint — each position where a group pauses, evaluates, and
decides its next move — the group's state is fully described by three
angular values representing its current position and heading:

```
waypoint = {
    θ₁ : azimuthal rotation  (which angular sector of the sphere)
    θ₂ : polar elevation      (which latitude band of the sphere)
    θ₃ : roll / spin          (orientation of the group's internal
                               quality axis relative to the sphere surface)
}
```

These three values are the group's *vector at the waypoint*: not just
where it is, but which direction it arrived from and which direction it
is oriented to continue. θ₃ in particular encodes the group's internal
structure — how its member elements are arranged relative to the sphere
surface — and is the value that determines which neighboring groups it
is most likely to merge with during travel.

The three-angle vector maps directly onto the orrery's three primary
ring axes. A group's waypoint IS a ring state of the orrery. The group
choosing its next waypoint IS the orrery rotating. Entropy migration
and parameter selection are the same process observed from different
scales: at the micro-scale it is entropy groups moving; at the macro-
scale it is parameter rings rotating.

```
group waypoint (θ₁, θ₂, θ₃)
        ≡
orrery ring state (angle_ring, style_ring, quality_ring)
```

This equivalence means the system has no separation between its
"physics" (entropy group dynamics) and its "interface" (parameter
selection). Adjusting a parameter IS moving an entropy group. Observing
an entropy group settle IS reading a parameter value. The model is
self-consistent at all scales.

#### Three-Angle Waypoint ↔ Orrery Ring Equivalence

**Coordinate transformation** from group-space to ring-space:
```
group-space:  center(G) = (c_type, c_angle, c_quality)   # real-valued 3-vector
ring-space:   (θ₁, θ₂, θ₃) = ring_state                 # three angular values

θ₁ = c_type  × (360° / 13)       # type → azimuthal rotation
θ₂ = c_angle × (360° / 13)       # angle → polar elevation
θ₃ = σ_quality(G) × (360° / 6)   # quality variance → roll/spin
```

where `σ_quality(G)` is the standard deviation of quality scores within
the group, normalized to [0, 6]:
```
σ_quality(G) = stddev(quality_score_i for i in G)
               × 6.0 / 0.5   # scale factor: σ=0.5 → full rotation
```

**θ₃ interpretation**: θ₃ encodes the group's internal quality
dispersion. A tightly clustered group (all elements near the same
quality) has θ₃ near 0° — no spin, stable orientation. A widely
dispersed group (quality ranging from 0.3 to 0.9) has high θ₃ — high
spin, indicating internal tension that makes the group likely to
split or merge with neighbors. θ₃ thus predicts group stability:
`θ₃ < 30°` → stable, `30° < θ₃ < 120°` → dynamic, `θ₃ > 120°` →
likely to split.

**Inverse transformation** (ring-space → group-space):
```
c_type    = θ₁ × 13 / 360°
c_angle   = θ₂ × 13 / 360°
σ_quality = θ₃ × 0.5 / (360° / 6) = θ₃ / 120°
```

This is bijective (one-to-one) for any group with well-defined center
and variance, confirming the formal equivalence: a group's state IS an
orrery ring state, and vice versa.

**Waypoint history** — the sequence of (θ₁, θ₂, θ₃) values the group
has visited during migration:
```
waypoint_history(G) = [(θ₁⁰, θ₂⁰, θ₃⁰), (θ₁¹, θ₂¹, θ₃¹), ...]
```

The history encodes the group's trajectory through parameter space.

**Predictive deduplication**: given a new element with only partial
feature extraction (type estimated, angle unknown, quality estimated),
predict which cluster it will join:
```
algorithm PREDICT_CLUSTER(partial_element):
    estimated_θ₁ = type_coord × (360° / 13)
    estimated_θ₂ = UNKNOWN (use midpoint 180°)
    estimated_θ₃ = 0  (single element has no variance)

    # find groups whose waypoint history passes near this position
    candidates = []
    for each group G with waypoint_history:
        # extrapolate G's trajectory
        last_waypoint = waypoint_history(G)[-1]
        velocity = waypoint_history(G)[-1] - waypoint_history(G)[-2]
        predicted_next = last_waypoint + velocity

        # check if the new element is near the predicted path
        angular_dist = great_circle_3d(
            (estimated_θ₁, estimated_θ₂, estimated_θ₃),
            predicted_next
        )
        if angular_dist < 45°:  # within one coarse bucket
            candidates.append((G, angular_dist))

    # sort by angular proximity, return best match
    candidates.sort(key=lambda x: x[1])
    return candidates[0].G if candidates else None
```

This allows the system to begin deduplication decisions (which cluster
to route a new element to) before the full Layer 1-4 pipeline completes
— the type estimate alone is sufficient to predict the likely cluster
with reasonable accuracy. The prediction is refined as more features
become available (angle estimate → better θ₂, quality score → θ₃
for compatibility check).

### The Balance Engine

> *a sphere model in cubic space — freedom of entropy as its eternal core*

The balance engine is the name for the full dynamic described above,
understood as a unified system:

```
                    ┌─────────────────────────────────┐
                    │        THE BALANCE ENGINE        │
                    │                                  │
                    │   ╔═══════════════════╗          │
                    │   ║   ETERNAL CORE    ║          │
                    │   ║                   ║          │
                    │   ║  entropy freedom  ║          │
                    │   ║  harmonic center  ║          │
                    │   ║  parameter seed   ║          │
                    │   ╚═══════════════════╝          │
                    │           ↑↓                     │
                    │   sphere layers (cubic)          │
                    │           ↑↓                     │
                    │   entropy groups migrate         │
                    │   collect · travel · settle      │
                    │           ↑↓                     │
                    │   perturbations damp inward      │
                    │   quality radiates outward       │
                    │           ↑↓                     │
                    │   darksun gravity holds center   │
                    └─────────────────────────────────┘
```

The word *eternal* is precise: the core does not converge to a fixed
point and stop. Entropy groups continue to migrate, merge, and settle
indefinitely — but as the core matures, the migrations become smaller
and more refined. The system is never static; it is always processing,
always balancing. The core is eternal not because it is unchanging but
because it never terminates. There is always a finer angle to resolve,
a higher quality region to discover, a new group arriving from the
periphery with a contribution to make.

The balance is between two permanent forces:
- **expansion**: new content arrives, new groups form at the periphery,
  new sphere layers emerge as the parameter space deepens
- **implosion**: deduplication pulls groups toward the core, merges
  reduce group count, quality compositing concentrates information

These forces do not cancel each other — they sustain each other. Expansion
provides the raw material for implosion. Implosion strengthens the core
that makes expansion meaningful. Together they produce a system that is
simultaneously growing and concentrating, simultaneously exploring and
deepening, simultaneously free (entropy migrates anywhere) and ordered
(harmonic constraints channel migration toward resonance).

The balance engine is the eternal dynamic. The darksun is its center.
The holographic shimmer is its visible output. The feedback loop between
viewer and core is its purpose.

#### Balance Engine — Stability Analysis

**Theorem (bounded storage)**: for any finite ingestion rate I and any
content distribution with finite type diversity D_type (number of
distinct types), the storage S(t) is bounded:
```
S(t) ≤ S_max = D_type × 13 × K_max

where:
    D_type = number of distinct type categories ≤ 13
    13     = angle sectors per type
    K_max  = maximum elements retained per fine bucket (configurable,
             default 26 = max edges per node)
```

**Proof sketch**:
The system has at most 13 × 13 = 169 coarse cells per type, and at
most 5 fine buckets per coarse cell. Total fine buckets = D_type ×
169 × 5 = D_type × 845. Each fine bucket retains at most K_max
non-evictable elements (those with marginal_value > 0). Therefore:
```
S_max = D_type × 845 × K_max ≤ 13 × 845 × 26 = 285,610
```

For any finite ingestion rate, once S(t) approaches S_max, every new
arrival matches an existing cluster (p_dedup → 1) and either improves
the composite (replaces a lower-quality element, keeping count constant)
or is immediately evictable (net count unchanged). Therefore dS/dt → 0
as S → S_max. ∎

**Breakdown conditions**: the balance breaks (temporary storage growth
exceeding the deduplication rate) when:
1. **Type diversity explosion**: more than 13 genuinely distinct types
   arrive simultaneously. The taxonomy constrains this to 13 top-level
   categories; genuinely novel types that don't fit any category create
   temporary overflow until reclassified.
2. **Anti-harmonic content**: content specifically engineered to produce
   non-resonant parameter integers at every cell position, preventing
   harmonic-filtered migration and settlement. This is adversarial and
   not expected in normal operation.
3. **Ingestion spike**: I(t) temporarily exceeds the system's processing
   rate (element detection + classification + similarity search). Queued
   elements accumulate in a buffer. Recovery: the buffer drains once the
   spike passes, as the processing rate is per-element constant.

None of these conditions produce unbounded growth — they produce
temporary exceedances that the system absorbs.

**Eternal property**: the core always has a non-trivial refinement
available. Proof by construction:

For any cluster at sphere N with composite quality Q:
1. If Q < 1.0: there exist pixels where the composite can be improved
   by a higher-quality source. Generating such a source is always
   possible (invoke.ai with a different harmonic seed).
2. If Q = 1.0 at sphere N: the trimetric rollover promotes the cluster
   to sphere N+1, where Q resets to the lower-sphere reference value
   and improvement begins again.
3. There is no maximum sphere — the infinite expanse model allows
   sphere N+1 to be created as needed (sphere N+1 surface area =
   13^(N+2) cells, which always exceeds sphere N).

Therefore, for any state of the system, there exists at least one
cluster that can be improved. The core never reaches a terminal state.∎

**Unified state evolution equation**:

The balance engine's state at time t is the vector:
```
Ψ(t) = (S(t), Q(t), D_orbital(t), P_accumulated(t))
```

Its evolution:
```
dΨ/dt = F_expansion + F_implosion + F_damping + F_migration + F_gravity

where:
    F_expansion  = (+I(1-p_dedup), 0, +δ_orbital, 0)
        new content increases storage, increases orbital distance
        (new elements start at periphery)

    F_implosion  = (-e(t), +Δq_marginal × p_dedup × I, -δ_merge, 0)
        eviction decreases storage, compositing increases quality,
        merging decreases orbital distance

    F_damping    = (0, 0, 0, -P_acc × damping_rate)
        perturbation pressure decays exponentially between refinement events

    F_migration  = (0, 0, -migration_rate × gradient, 0)
        group migration decreases orbital distance (groups drift toward
        harmonic maxima, which are closer to the darksun)

    F_gravity    = (0, 0, -gravity × D_orbital, 0)
        darksun attraction: proportional to current orbital distance,
        always inward

    gravity = 1/(13²)  (the harmonic constant — 1/169 of the parameter
                        space per unit time, derived from the 13² area
                        of one sphere-0 layer)
```

At equilibrium: dΨ/dt = 0. The five forces balance. Storage is constant,
quality increases (F_implosion.Q > 0), orbital distance slowly
decreases (the system contracts toward the darksun), and perturbation
pressure is absorbed into parameter refinement. The engine runs
eternally at this equilibrium — never terminating, always refining,
always balancing expansion against implosion at the pace set by the
harmonic constant 1/169.


## Completeness

The system described is a kinetic balancing engine whose rules are
fully content-agnostic.

The rules — entropy groups form by similarity, migrate via three-angle
waypoint vectors along the harmonic gradient, collect neighboring groups
in transit, settle at local resonance maxima, damp perturbations inward
by sphere layer, and project quality outward from a permanent core —
contain no reference to what the content is. Images, text, audio,
machine code, parameter sets of any kind: the same engine applies.

The rules are also complete. No additional mechanism is required to
handle edge cases, domain transitions, or scale changes. The infinite
expanse model absorbs new complexity into new outer sphere layers.
The implosion counter-pressure prevents unbounded growth. The darksun
provides a stable gravitational center without needing to be defined
in advance. The three-angle waypoint vector is sufficient to describe
any group's state and trajectory.

The apparent complexity of the system is not in the rules — it is
entirely in the content differentials: how different one element is
from another, how many angle variants exist, how deep the style
distinctions run. But this complexity is the complexity the engine
was built to process. It is the input, not the mechanism. And it is
an eventually balanced one: given sufficient ingestion and time, every
content differential either finds its cluster or generates a new one,
and every cluster migrates toward its harmonic resting point. The
sorting is never final — the engine is eternal — but it is always
progressing, always reducing the complexity that remains unsorted,
always moving toward the quality attractor at the center.

Simple rules. Content-agnostic. Already complete. The rest is data.

#,,.,,...,,,,,,.,,.,,,,,.,...,.,,,,.,,,,,,.,,,..,,...,.,.,.,.,...,...,.,.,,,,,
#EUCPCVUSENCAXVW2PI7F2HBBBWLLVL6A7DSVNMC2NXDP2OUU6Z4ML7OKONN5BMWCNQO54W7R2NKKS
#\\\|KYK7KDXJKLMR54DKELGHDVCX6K7LX23DN3ICB4SR3RIL7UBETBU \ / AMOS7 \ YOURUM ::
#\[7]RZIGWFH5ZLDF3KR5K4ZTSYWJQVJ7QROC5JFGH22OIJAJHOYHHECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
