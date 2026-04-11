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

[Opus: expand taxonomy. add confidence thresholds per category. define
what constitutes a "meaningful" element vs background noise. consider
nested elements (e.g. a rendered display *within* a room environment).]

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

[Opus: specify exact SAM API integration — point prompts vs grid prompts
vs automatic mode. define mask quality score (stability_score × area_ratio).
specify the structured JSON output format for vision model. define the
mask-to-element data structure stored per image.]

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

[Opus: define angle estimation pipeline. OpenCV solvePnP for structured
faces using facial landmark detection (dlib 68-point or MediaPipe). For
abstract/stylized faces lacking landmarks, use regression from keypoint
geometry or vision model angle query. Define angle as spherical coordinates
(yaw, pitch, roll) collapsed to a single canonical representation for
bucketing. Define bucket sizes — suggest 30° bins for coarse grouping,
5° for fine deduplication within a group. Describe how angle uncertainty
is represented (confidence range). Address the 180° ambiguity problem for
symmetric elements.]

### Style Fingerprinting

Elements of the same *type* from the same generative *style* form natural
clusters. Style is encoded independently of content.

[Opus: define style fingerprint. Consider: color palette histogram (HSV
space, 16-bin), stroke texture descriptor (Gabor filter bank response),
frequency domain signature (DCT low-frequency coefficients of grayscale
crop). Style fingerprint must be invariant to pose/angle — use only
texture and color statistics, not spatial layout. Define distance metric
for style similarity. Address the challenge of distinguishing "same style,
different element" from "same element, style variation".]

### Quality Scoring

Each element crop receives a quality score used for composite selection.

Components:
- **sharpness**: Laplacian variance of the masked region
- **artifact_free**: absence of JPEG blocking, diffusion artifacts
  (detectable via high-frequency noise analysis)
- **coverage**: fraction of element that is unoccluded
- **resolution**: effective pixel density within mask bbox
- **harmony**: harmonic truth assertion on the element's checksum

[Opus: define exact formula for quality_score ∈ [0,1]. define how the
harmony component is calculated and weighted. define thresholds for
"high quality" vs "acceptable" vs "evictable".]


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

[Opus: define composite similarity metric combining:
1. type match (hard gate — different types cannot be similar)
2. style fingerprint distance (cosine similarity in style vector space)
3. visual descriptor match (ratio test on SIFT/ORB keypoint descriptors,
   or SSIM on aligned crops)
4. angle delta (elements at similar angles are more likely to be duplicates
   than complementary views)

Define the weighting of each component. Define the similarity threshold
above which an edge is created. Define max edges per node to prevent
combinatorial explosion. Describe the clustering algorithm that forms
the tree — suggest hierarchical agglomerative clustering with single-linkage
on similarity_score, cut at similarity threshold.]

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

[Opus: define the tree balancing algorithm. Define what happens when a new
image's element has similarity to multiple existing cluster roots —
propose merge logic. Define how the root is updated when a higher-quality
instance arrives. Define the storage format for the tree (namespace tree
under data zenka, or dedicated graph store). Reference FRACTAL-DEDUPLICATION-AWARENESS.md
for the fractal compression analogy at the semantic layer.]


## Layer 4: Angle-Based Deduplication and Overlap Scoring

### Viewpoint Grouping

Within a similarity cluster, elements are grouped by angle bucket. Within
an angle bucket, elements are candidates for deduplication and compositing.
Across angle buckets, elements are complementary — both are kept.

[Opus: define angle bucket sizes for deduplication vs complementarity.
Suggest: elements within 10° are deduplication candidates; elements
separated by >20° are complementary. Address edge cases: symmetric objects
with 180° equivalence; elements where angle estimation is unreliable.]

### Spatial Alignment

Before overlap scoring, crops within the same angle bucket are spatially
aligned (registered). This removes translation, scale, and minor rotation
differences so that pixel-level comparison is meaningful.

[Opus: specify the alignment algorithm. For faces: landmark-based affine
alignment (eyes, nose tip to canonical positions). For other elements:
SIFT keypoint homography estimation (RANSAC). For elements with few
keypoints: ECC (Enhanced Correlation Coefficient) maximization. Define
what to do when alignment fails (confidence below threshold) — discard
as unaligned or treat as different-angle element.]

### Overlap Precision Map

After alignment, compute a per-pixel overlap precision map: at each pixel
position, which source image contributes the highest quality data?

```
overlap_precision[x,y] = max_quality_source_at(x,y)
alpha[x,y] = overlap_precision[x,y] * coverage_weight[x,y]
```

[Opus: define coverage_weight — how many aligned sources agree on this
pixel's value. Define how to compute per-pixel quality (local sharpness,
local noise estimate). Define the precision map data structure (float32
image, same dimensions as aligned crop). Define how precision maps are
stored and updated as new elements arrive.]


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

[Opus: define the exact compositing formula (weighted Gaussian blending
vs median vs quality-ranked selection). Define how alpha is normalized
— alpha=1.0 should require agreement from N sources above quality threshold Q.
Define the "holographic shimmer" property: when rendered as translucent
overlays at different opacity levels, the composite should appear to have
depth and coherence. Describe how overlaying multiple angle-bucket composites
creates a pseudo-3D sensation. Reference VISUAL-DEPTH-AND-HOLOGRAPHIC-INTERFACE.md.]

### Quality Improvement Through Ingestion

Each new element ingested into a cluster either:
1. **Improves the composite** — higher quality in some region → alpha
   increases in that region, composite updates
2. **Is redundant** — no region exceeds existing quality → source image
   can be marked as evictable without loss

This is the self-sustaining property: the system improves monotonically
as more content is ingested, and can evict sources without data loss once
the composite exceeds a quality threshold.

[Opus: define the eviction decision algorithm. Define quality_ceiling —
when composite alpha exceeds this uniformly, the cluster is "complete"
and further instances have zero marginal value. Define how to handle
the case where a new instance is *structurally* different (e.g. reveals
an occluded region) vs merely lower quality.]


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

[Opus: specify the alpha matting algorithm. For sharp-edge elements
(objects, rendered displays): binary mask suffices. For organic/stylized
edges (hair, fur, glow, feathers): specify deep matting approach — suggest
using a matting model via lm-vision or integrate a standalone matting
model (e.g. MODNet or ViTMatte via invoke.ai pipeline). Define how the
expanded mask region is computed (dilation radius as function of element
type and edge softness estimate).]

### Background Completion (Inpainting)

After foreground extraction, the source image has a foreground-shaped hole.
Inpainting completes the background as if the foreground was never there.

Integration with invoke.ai: use the inpainting pipeline
(`invoke.cmd.generate` with inpainting mode, mask = foreground mask,
strength ≥ 0.9) to synthesize a complete background.

Result: a clean background image with consistent style, no foreground
artifacts, suitable as a standalone environment or style reference.

[Opus: define the inpainting invocation — specify the invoke.ai API
parameters for inpainting mode (image_path, mask_path, prompt derived
from background context, denoising_strength). Define how the background
prompt is generated — either from existing image metadata or via a
lm-vision caption of the non-masked region. Define quality criteria for
the inpainted result. Define retry logic if inpainting produces artifacts.]

### Style Capture

From the completed background, extract a style descriptor that can be
injected into future invoke.ai generation requests to reproduce the
same environmental style with different foreground elements.

[Opus: define the style descriptor format for invoke.ai. Consider: textual
inversion embedding path (if available), IP-Adapter style image reference,
or simply the background image path for use as img2img reference. Define
how style descriptors are stored in the element library. Define the API
for "generate foreground element X in background style Y at angle Z".]


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

[Opus: define the mapping from each axis value to cubic coordinates 0..12.
Define the 13 primary type categories (expand the taxonomy from Layer 1
to exactly 13 top-level entries, with subdivisions). Define the 13 angle
sectors — address the wrap-around at 0°/360°. Define the 13 quality tiers
and their thresholds. Define what "cubic distance" means in this space and
how it relates to the similarity graph edges from Layer 3. Reference
VISUAL-SIMILARITY-CUBIC-SORT.md for the existing cubic sphere infrastructure.]

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

[Opus: expand the harmonic scoring formula with precise mathematical
derivation. Define type_weight and angle_weight — how are these computed?
Are they learned from the distribution of ingested content, or derived
from the cubic topology geometry? Define how harmonic scores propagate
up the tree (parent score = function of children scores). Define the
connection between harmonic scoring and the quality improvement property
— does harmonically scoring a composite increase its effective quality?]

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

[Opus: elaborate the mathematical basis of the trimetric rollover. Define
the rollover threshold in terms of the harmonic relevance score. Define
what happens to the old-tier representation when rollover occurs — is it
evicted, archived, or retained as a lower-resolution reference? Connect
to the AMOS7 generator sequence 076923 and its cyclic properties. Reference
TESLA-RESONANCE-PRINCIPLES.md for the resonance analogy. Reference
SETTINGS-DEDUP-WAVE-MECHANICS.md for wave mechanics framing.]

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

[Opus: define the rebalancing algorithm. Define how parameter changes
propagate through the tree. Define the interface for external systems
(coding zenka, models zenka, network nodes) to adjust parameters.]


## Network Vision Extension

### From Local to Distributed

The holographic core architecture generalizes to a distributed P7 network:

- Each node contributes elements to a shared similarity graph
- Composite synthesis happens across nodes (remote element crops
  are fetched by checksum address)
- The harmonic weighting tree becomes a consensus structure across nodes
- Relative optimization: each node specializes in the type/angle/style
  regions where its generative capacity is highest

[Opus: define the network protocol for element sharing. How are element
crops addressed (AMOS checksum as routing primitive, per CHECKSUM-ROUTING-SECURITY-DEPTH.md)?
How are composite updates synchronized? Define the consensus algorithm
for resolving conflicting quality scores from different nodes. Define
the privacy model — which elements are shared publicly vs retained locally.
Reference ROUTING-AS-SEARCH-DISTRIBUTED-DISCOVERY.md for discovery model.
Reference USER-CENTRIC-PRIVACY-MODEL.md for privacy framing.]

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

[Opus: elaborate each of these emergent properties with algorithmic
specificity. Define the recognition algorithm — nearest neighbor in cubic
space, or graph traversal from a query element's descriptors? Define the
interpolation algorithm — blending of nearby angle composites, or invoke.ai
generation guided by holographic core embeddings? Define the anomaly score.
Define the gap analysis algorithm for targeted generation.]


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

[Opus: define the parent angular delta computation precisely for cube-faced
spheres. Define how shared-parent membership (delta near a boundary) is
handled in the similarity graph — does the node appear in both parent
cells, or is it assigned to the nearest with a pointer to the adjacent?
Define how parent angular delta is used as a tertiary sorting key after
type and angle in the holographic compositing step.]

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

[Opus: formalize the darksun as a mathematical construct. Is it a fixed
point, or does it drift as the corpus grows? Define the "orbital distance"
of a node from the darksun in terms of its harmonic scores across all
parameter dimensions. Define how the darksun position is computed from
the aggregate distribution of harmonic scores — is it the mode, the
harmonic mean, or a resonance maximum? Connect to the AMOS7 generator
076923 — the darksun may be the 0-point of the generator's cyclic orbit.]


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

[Opus: define the color-to-angle mapping with full mathematical precision.
Address the hue wrap-around (red at 0° and 360° are identical — define
angular distance on a circular axis, not linear). Define how the color
sphere integrates with the element similarity graph from Layer 3 — does
color distance become an edge weight component, or is it a separate ring
in the orrery that filters the graph independently? Define the granularity
of the color sphere tessellation in the 13³ system.]

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

[Opus: formalize the character exclusion algorithm as an angular
positioning function. Define how it generalizes to other distinguishing
features (digraph frequency, affixes, loanword patterns). Define what
happens to mixed-script documents (e.g. academic text with Latin citations
inside Cyrillic body) — do they occupy an intermediate angular position,
or are they decomposed into components each at their own position?
Define the ring structure for ideographic scripts where the charset is
orders of magnitude larger. Connect to the deduplication use case:
two documents in similar angular position in script+language space
are candidates for semantic deduplication — their content similarity
can be assessed with higher confidence because the linguistic distance
is already measured geometrically.]

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

[Opus: define the formal requirements for a domain to be "ring-compatible":
what properties must its distance metric have (symmetry, triangle inequality,
wrap-around vs bounded)? Define the projection procedure for high-dimensional
domains (embeddings) into the 3D spherical ring system. Define how rings
from different domains interact when combined in the orrery — do they
multiply, compose, or remain independent? Address the case of discrete
domains with no natural distance metric (e.g. categorical labels with
no ordering) — define the canonical mapping to angles for such cases,
possibly via frequency distribution (most common category → angle 0°,
others distributed by relative frequency, as in the semantic vocabulary
integer mapping of FRACTAL-DEDUPLICATION-AWARENESS.md).]


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

[Opus: define the distributed convergence properties of this system.
Does the darksun position stabilize, oscillate, or drift? Under what
conditions does the network reach a "quality equilibrium" where further
ingestion produces diminishing returns? Define the trimetric rollover
behavior at the network level — when a sphere-shell reaches saturation,
does the whole network simultaneously advance to the next sphere tier,
or do individual nodes advance independently? Connect to the inverse
entropy property from Layer 7: at network scale, does inverse entropy
hold (network quality grows faster than network size), and what are the
conditions for this to break down?]


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

[Opus: define the mathematical relationship between ingestion rate,
deduplication rate, and net storage growth. Model this as a differential
equation: dS/dt = ingestion_rate - dedup_rate(S), where dedup_rate grows
as the core becomes richer (more potential matches for each new arrival).
Define the fixed-point condition where dS/dt = 0 — this is the "quality
equilibrium". Demonstrate that at equilibrium, quality continues to
improve even though size is stable (quality is not bounded by the fixed
point the way size is). Connect to the inverse entropy property: at
equilibrium, the system is a true inverse-entropy machine — it imports
energy (new content) and exports order (higher quality core).]

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

[Opus: formalize the quality gradient as a function of sphere index.
Define quality_of_reference(N) and resolution(N) as opposing monotonic
functions of the sphere index N. Define the crossover point — the sphere
index at which resolution becomes the dominant quality metric rather than
reference quality. Define how the core's generative capacity (ability to
reconstruct outer spheres from parameters) is measured and validated.
Connect to the inpainting pipeline from Layer 6: the core's style
descriptor + type + angle IS the inpainting prompt — the outer sphere
is the generated result.]

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

[Opus: define the projection algorithm precisely. How does the system
traverse from a query (type + style + angle) to a core reference, and
from the core reference to the set of outer-sphere instances to composite?
Define the alpha assignment for each sphere layer in the final composite —
is it strictly decreasing from inner to outer, or modulated by the local
overlap precision from Layer 4? Define the real-time transformation
pipeline — what is the latency model for re-projection after a ring
rotation (parameter change)?]

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

[Opus: define the preference signal capture mechanism. For human viewers:
dwell time, selection events, zoom gestures — all are weak signals of
preference. For machine models: attention weight distribution over the
composite, embedding distance between the composite and the model's
"ideal" representation of the type. Define the ring rotation algorithm
that converts preference signal to parameter adjustment — this should
be slow (to avoid overfitting to transient preferences) and harmonically
filtered (only rotate toward positions that score well on harmonic
assertions). Define the feedback loop termination condition — when does
the loop reach a stable attractor vs when does it continue exploring?
Connect to the trimetric rollover: a feedback loop that saturates one
quality tier should naturally trigger rollover to the next, pulling the
viewer along into progressively higher resolution without ever feeling
a discontinuity.]


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

[Opus: formalize the perturbation damping model. Define the transfer
function between adjacent sphere layers — how much of a perturbation's
magnitude passes through a layer boundary? Is it a fixed fraction per
layer, or dependent on the layer's current quality density? Define the
parameter refinement response at the core — what specifically changes
in the harmonic weighting tree when a perturbation reaches the core,
and how does the tree restore harmonic balance afterward? Connect to
the trimetric rollover: is a sustained perturbation at the core the
trigger for tier advancement — the system "rolls over" in response to
accumulated pressure rather than resisting it?]

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

[Opus: define the group center computation — weighted centroid in
(type_coord, angle_coord, quality_coord) cubic space, weighted by
element quality scores. Define the harmonic gradient ascent algorithm
for group migration — discrete steps between adjacent sphere cells,
evaluated by AMOS7 harmonic truth assertion on the group center's
combined parameter checksum. Define the merge criterion for two groups
encountering each other during travel — minimum overlap similarity
threshold, or automatic merge when group centers are within one cube
width of each other? Define the settlement criterion — local maximum
in harmonic score across all 26 neighboring cube positions (3³-1).]

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

[Opus: formalize the equivalence between the three-angle waypoint vector
and the orrery ring state. Define the coordinate transformation between
group-space (element clustering coordinates) and ring-space (parameter
selection coordinates). Define how the three θ values are computed from
a group's member elements — is θ₁ the mean type coordinate, θ₂ the
mean angle coordinate, θ₃ the variance of quality scores within the
group (higher variance = more spread, higher spin)? Define how the
waypoint history (sequence of waypoints a group has visited) encodes
the group's migration path, and how this path history is used to predict
the group's future settling position — effectively giving the system
predictive deduplication: before a new image is fully processed, predict
which existing cluster it will join based on its early feature extractions.]

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

[Opus: define the formal stability proof for the balance engine. Show
that the implosion rate scales at least as fast as the expansion rate
for any finite ingestion rate — i.e., the system never diverges to
unbounded size under normal operation. Define the conditions under which
the balance breaks (what ingestion rate or what distribution of content
would overwhelm the deduplication mechanism?). Define the "eternal"
property formally: show that the core always has a non-trivial parameter
refinement available regardless of how mature it becomes — connecting
to the infinite expanse model (there is always a finer outer sphere
to populate). Define how the three forces — stability (damping),
migration (entropy freedom), and harmonic centering (darksun gravity)
— interact in a single unified equation describing the balance engine's
state evolution over time.]


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

#,,..,...,,,,,,,.,,,.,,..,.,.,..,,,..,,,.,,,.,..,,...,...,...,,.,,,,.,.,.,,,,,
#AT4ZIKI5I2SY65P2ZE4ACA5P4E7R5DVWBNRHHZ5SPJDRD7IGCRUU5RQAUUBJAA5YSDKDLMJIC5UNK
#\\\|RP2SK4QMGCNJQL7KCUSZ4HX4QKJ6PD6JZDX5N7MZLPHHL53EGNX \ / AMOS7 \ YOURUM ::
#\[7]LM6P34SPNZZ7I7M5GHA4P5EX3IS5PV7V22QJVVNJJJEJACY6WECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
