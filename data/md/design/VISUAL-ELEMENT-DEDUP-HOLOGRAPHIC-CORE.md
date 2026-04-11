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

#,,..,,..,,..,..,,...,...,...,,..,.,,,..,,.,.,..,,...,...,,,.,,,.,,,,,,.,,,..,
#CTGAUDXHGBMYCY5U6OXTMREBAPNXQLKTTNOYWQ47I77C6TB4ZDDZVAIYBC4XNJKCVCXDMGTMWXVTU
#\\\|ILXJYWEHF6JCJJCDILXG3D5K26LUBFGNU3BKJYNFP4QSBOOYCJW \ / AMOS7 \ YOURUM ::
#\[7]3TLZMSITIWBEUD33TTKAVSDOLAT7ZIGUVXUASSGGOQGSZLV2UUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
