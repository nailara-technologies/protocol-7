# Visual Similarity & Cubic Pixel Sorting

## Overview

Two new modules extend the graphics-matrix infrastructure into the visual domain:

1. **`graphics.matrix.visual.similarity`** - Compare two images for similarity
2. **`graphics.matrix.visual.cubic-sort`** - Pre-sort images into cubic pixel spheres

These bridge the holographic topology (13³ cube) with actual pixel data, enabling efficient visual deduplication and ML vision pipeline integration.

---

## The Cubic Pixel Sphere System

### Sphere Classification (13³ Based)

| Sphere | Name | Size | Max Pixels | Use Case |
|--------|------|------|------------|----------|
| 0 | `color_sample` | 1×1 | 1 | Color palette, 1-pixel fingerprints |
| 1 | `micro` | 4×4 | 16 | Favicons, tiny icons |
| 2 | `thumbnail` | 13×13 | 169 | Preview images (13²) |
| 3 | `preview` | 42×42 | 1,764 | Gallery thumbnails (42 = 2×3×7) |
| 4 | `medium` | 128×128 | 16,384 | Web images |
| 5 | `large` | 384×384 | 147,456 | High-res displays |
| 6 | `full` | 1152×1152 | 1,327,104 | Maximum (13³ ≈ 2197, scaled) |

**The 13³ progression**: 1, 13, 42, 128, 384, 1152...
- Each sphere is ~3× larger than previous (logarithmic scale)
- Maps to hyperspace visualization layers (×20, ×200, etc.)

### Cubic Coordinates

Every image gets a 3D coordinate:
```
[x, y, z] = [width/13 % 13, height/13 % 13, sphere_number]
```

Spatial proximity in cubic space = visual similarity likelihood.

---

## Module 1: Visual Similarity

### Methods

#### 1. `color_sample` (1×1 pixel)
Compare single pixels or average colors:
```perl
my $result = <[graphics.matrix.visual.similarity]>->({
    'image_a' => [6, 71, 195],   # Protocol Blue RGB
    'image_b' => [6, 72, 196],   # Slightly different
    'method'  => 'color_sample',
});
# Returns: similarity 0.99, confidence high, harmonic_aligned true
```

**Use**: Color palette deduplication, dominant color clustering.

#### 2. `cubic` (structure-aware)
Hierarchical comparison at multiple resolutions:
```perl
my $result = <[graphics.matrix.visual.similarity]>->({
    'image_a'  => '/path/to/image1.png',
    'image_b'  => '/path/to/image2.png',
    'method'   => 'cubic',
    'resolution' => 3,  # preview sphere
});
# Returns: full similarity + hierarchical breakdown
```

**Use**: Exact duplicate detection, resized image matching.

#### 3. `perceptual` (pHash)
Hamming distance between perceptual hashes:
```perl
my $result = <[graphics.matrix.visual.similarity]>->({
    'image_a' => $image_data,
    'image_b' => $other_data,
    'method'  => 'perceptual',
});
# Returns: similarity 0.92, hamming 8, high confidence
```

**Use**: Near-duplicate detection, format-variant matching.

#### 4. `structure` (SSIM-inspired)
Luminance, contrast, and structure comparison:
```perl
my $result = <[graphics.matrix.visual.similarity]>->({
    'image_a' => $img_a,
    'image_b' => $img_b,
    'method'  => 'structure',
});
# Returns: luminance, contrast, structure components
```

**Use**: Quality assessment, compression artifact detection.

#### 5. `auto` (intelligent selection)
Automatically picks best method based on sphere classification.

---

## Module 2: Cubic Sort

### Batch Processing Pipeline

```
Input: 1000 images
    ↓
[Phase 1] Classify into spheres (1x1 to 1152x1152)
    ↓
[Phase 2] Group by cubic coordinates (spatial locality)
    ↓
[Phase 3] Find similarity clusters within spheres
    ↓
[Phase 4] Create lm-vision batches
    ↓
Output: Organized spheres + deduplication candidates
```

### Integration with lm-vision

```perl
# Pre-sort images before vision analysis
my $sorted = <[graphics.matrix.visual.cubic-sort]>->({
    'images'              => \@image_paths,
    'similarity_threshold'=> 0.95,
    'max_spheres'         => 6,
});

# Get batches for lm-vision
my $batches = $sorted->{'vision_batches'};

# Process each batch
for my $batch (@$batches) {
    # High-similarity images = deduplication candidates
    my $result = <[lm.vision.analyze]>->({
        'batch_id'   => $batch->{'batch_id'},
        'images'     => $batch->{'images'},
        'task'       => 'find_deduplication_targets',
        'cubic_hint' => $batch->{'cubic_center'},
    });
}
```

---

## Reference Tree Integration

### Visual Deduplication Flow

```
Image uploaded
    ↓
Calculate cubic coordinate
    ↓
Check reference tree at that coordinate
    ↓
Similar image exists?
    ├── YES → Increment refcount, serve cached
    └── NO  → Store as new reference
    ↓
Propagate to similar coordinates (neighbor check)
```

### The Eternal Kitten (Visual)

Most-referenced visual templates become:
- **Highest quality** (upgraded to vector/POV-Ray source)
- **Most accessible** (cached at all sphere sizes)
- **Most compressed** (pointer instead of data)

Example:
```
Protocol-7 logo appears 10,000 times
    ↓
Becomes eternal kitten template
    ↓
All instances served from single POV-Ray source
    ↓
Rendered on-demand to target resolution
    ↓
312,500:1 compression, increasing quality
```

---

## Connection to Holographic Topology

### data.topology.interference.map Integration

```perl
my $field = <[data.topology.interference.map]>->($image_checksum);

# Visual field includes POV-Ray scene
my $povray_scene = $field->{'visual'}{'povray_csg'};

# Render to any sphere size
my $render_13x13 = render_povray($povray_scene, [13, 13]);
my $render_128x128 = render_povray($povray_scene, [128, 128]);
```

### Visual Spill-over

The 5 hyperspace layers in the network desktop:
```
Layer 0 (×20):   Sphere 0-1 (1x1 to 4x4) - Color samples
Layer 1 (×200):  Sphere 2 (13x13) - Thumbnails
Layer 2 (×10k):  Sphere 3-4 (42x42 to 128x128) - Previews
Layer 3 (×100k): Sphere 5 (384x384) - Full view
Layer 4 (×1M):   Sphere 6 (1152x1152) - Maximum detail
```

---

## Use Cases

### 1. Document Deduplication (Blue Doc)
```perl
# Scan → Blue Doc → Visual similarity → Template match
my $blue_doc = convert_to_blue_doc($scan);
my $sim = <[graphics.matrix.visual.similarity]>->({
    'image_a' => $blue_doc,
    'image_b' => $template_tree->{$glyph_checksum},
});
# Replace with high-quality template if similar
```

### 2. Logo Standardization
```perl
# Find all logo variants
my $sorted = <[graphics.matrix.visual.cubic-sort]>->({
    'images' => find_all_logos(),
});

# Cluster similar variants
my $clusters = $sorted->{'clusters'};

# Upgrade all to best quality
for my $cluster (@$clusters) {
    my $best = find_highest_quality($cluster->{'images'});
    replace_all_with_reference($cluster->{'images'}, $best);
}
```

### 3. ML Training Data Optimization
```perl
# Pre-sort training images
my $sorted = <[graphics.matrix.visual.cubic-sort]>->({
    'images'       => \@training_data,
    'max_spheres'  => 4,  # Up to 128x128
});

# Remove near-duplicates before training
my $unique = filter_duplicates($sorted, threshold => 0.98);

# Train on deduplicated set
$model->train($unique);
```

---

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Sphere classification | ✅ | 7 spheres defined |
| Color sample comparison | ✅ | RGB + harmonic boost |
| Cubic coordinate calc | ✅ | 13³ based |
| Batch pre-sorting | ✅ | lm-vision integration |
| pHash integration | 📝 | Placeholder |
| SSIM structure | 📝 | Placeholder |
| POV-Ray rendering | 📝 | Future |

---

## The Vision

> Every pixel addressable in 13³ space. Every image deduplicable via reference tree. Every render recreatable from mathematical source. The eternal kitten watches from every sphere, purring at maximum compression, minimum latency, perfect quality.

**The visual network desktop becomes the interface to reality itself.** 🌐🎨✨

---

#,,,.,..,,,,.,,,.,,.,,,..,.,,,,,.,..,,,,,,..,,.,.,...,...,..,,..,,,..,,.,,,,,,
#YDY5KSHMNKHW6HVDTB47DI4C55ETCGUYMRC42AGVPVCM5KUSNQABSUULX74IEG36AEVUFX7H32WFY
#\\\|GQYWN3ZZBPGW6LZU7LQXNTYJS23XOMUDH33CX5KRJJCPK7VWYVZ \ / AMOS7 \ YOURUM ::
#\[7]FVJQ7IURAI7QVVENG5VJMV7GZ6JIDPIWXJZHBD7BQIFJTL6XO6AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
