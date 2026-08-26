# Visual Mapping Plugins for Storage Harmonization

> *From checksums to constellations - visual data gravity wells*

## Core Concept

Transform storage references into navigable visual spaces where:
- **Proximity** = similarity (checksum distance, path similarity)
- **Brightness** = reference count (hot data glows)
- **Color** = type (9P=blue, checksum=gold, local=green)
- **Connections** = relationships (same content, shared segments)

## Architecture

```
plugin.storage.visual.*
├── init_code                    # Initialize visual registry
├── extract-floats               # Extract sortable values from refs
├── proximity-calc               # Calculate visual proximity
├── harmonization-filter         # Iterative harmonization workflows
├── branch-score                 # Multi-reference branching scores
├── render-graph                 # Generate graph data for display
└── iteration-controller         # Workflow step controller
```

## Float Value Extraction Layers

### Layer 1: Intrinsic Properties
```perl
# Extract base metrics from any P7REF
my $floats = <[plugin.storage.visual.extract-floats]>->({
    'p7ref' => 'p7://checksum:ABC123',
    'layers' => ['intrinsic'],
});
# Returns: {
#   'checksum_entropy'   => 0.847,      # 0-1, higher = more unique
#   'path_depth'         => 0.3,        # normalized depth in tree
#   'reference_count'    => 5.0,        # how many refs point here
#   'access_frequency'   => 0.92,       # 0-1, recent access weight
#   'byte_size_log'      => 16.5,       # log2 of file size
# }
```

### Layer 2: Temporal Patterns
```perl
my $floats = <[plugin.storage.visual.extract-floats]>->({
    'p7ref' => 'p7://9p:host/path',
    'layers' => ['temporal'],
});
# Returns: {
#   'creation_age_days'  => 45.5,       # days since creation
#   'modification_velocity' => 0.1,     # changes per day
#   'access_decay'       => 0.75,       # 1.0 = accessed now, 0.0 = never
#   'time_of_day_pref'   => 14.5,       # preferred hour (0-24)
# }
```

### Layer 3: Network Position
```perl
my $floats = <[plugin.storage.visual.extract-floats]>->({
    'p7ref' => $p7ref,
    'layers' => ['network'],
});
# Returns: {
#   'hop_count'          => 2.0,        # network distance from local
#   'bandwidth_score'    => 0.95,       # 0-1, available bandwidth
#   'reliability'        => 0.99,       # uptime percentage
#   'mesh_centrality'    => 0.34,       # graph centrality in mesh
# }
```

## Visual Proximity Matching

### Distance Functions
```perl
# Calculate visual distance between two refs
my $proximity = <[plugin.storage.visual.proximity-calc]>->({
    'ref1'   => 'p7://checksum:ABC',
    'ref2'   => 'p7://checksum:DEF',
    'method' => 'harmonized',           # or 'checksum', 'path', 'semantic'
});
# Returns: 0.0-1.0 where 0.0 = identical, 1.0 = completely different
```

### Methods
| Method | Description |
|--------|-------------|
| `checksum` | Hamming distance of checksums |
| `path` | Levenshtein distance of paths |
| `semantic` | Segment overlap similarity |
| `harmonized` | Weighted combination of all |

## Harmonization Filter Workflows

### Workflow Definition
```perl
# Define iterative harmonization workflow
my $workflow = {
    'name'  => 'dedup-hot-files',
    'steps' => [
        {   # Step 1: Group by checksum proximity
            'filter'  => 'proximity-cluster',
            'params'  => { 'threshold' => 0.05, 'method' => 'checksum' },
            'extract' => ['reference_count', 'access_frequency'],
        },
        {   # Step 2: Within clusters, sort by heat
            'filter'  => 'sort',
            'params'  => { 'by' => 'access_frequency', 'desc' => 1 },
        },
        {   # Step 3: Top 10% get local cache priority
            'filter'  => 'threshold',
            'params'  => { 'percentile' => 0.10 },
            'action'  => 'prioritize-local-cache',
        },
    ],
};

my $result = <[plugin.storage.visual.harmonization-filter]>->({
    'refs'     => \@p7refs,
    'workflow' => $workflow,
});
```

### Visual Iteration Steps
Each step produces visual output:
```
Step 1: Scatter plot - checksum similarity space
        Color = reference count
        Size  = file size

Step 2: Sorted heatmap - access frequency gradient
        Brighter = more frequent

Step 3: Highlight overlay - top 10% in gold
        Connections show migration path to local
```

## Multi-Reference Branching

### Branch Score Calculation
```perl
# Score branching potential of a reference
my $score = <[plugin.storage.visual.branch-score]>->({
    'p7ref'      => 'p7://checksum:ABC',
    'branches'   => ['local', '9p:node2', '9p:node3'],
    'criteria'   => {
        'local'      => { weight => 0.5,  max_latency => 0.001 },
        '9p:node2'   => { weight => 0.3,  max_latency => 0.010 },
        '9p:node3'   => { weight => 0.2,  max_latency => 0.050 },
    },
});
# Returns: {
#   'primary_branch'   => 'local',
#   'secondary'        => ['9p:node2'],
#   'score_vector'     => [0.95, 0.72, 0.45],
#   'recommendation'   => 'replicate-to-node2',
# }
```

### Branch Visualization
```
         [p7://checksum:ABC]
              /    |    \
           0.95  0.72  0.45
            /     |      \
      [local] [node2]  [node3]
       GOLD    BLUE    GRAY
       (hot)   (warm)  (cold)
```

## Graph Rendering

### Generate Graph Data
```perl
my $graph = <[plugin.storage.visual.render-graph]>->({
    'refs'       => \@selected_refs,
    'layout'     => 'force-directed',  # or 'hierarchical', 'circular'
    'dimensions' => 3,                  # 2D or 3D
    'edges'      => {
        'same-checksum'   => { 'visible' => 1, 'color' => '#FFD700' },
        'shared-segment'  => { 'visible' => 1, 'color' => '#00AAFF' },
        'proximity>0.8'   => { 'visible' => 0 },
    },
});

# Returns graph format for various renderers:
# - GraphViz DOT
# - D3.js JSON
# - Unity 3D scene
# - ASCII art (for terminal)
```

### Terminal ASCII Preview
```
storage visual render --ascii --limit 50

                    [9P:host1]★
                   /    |     \
                  /     |      \
           [CHK:ABC]  [CHK:DEF] [CHK:GHI]
              ★★★       ★★        ★
             /   \       |
      [local]   [9P:h2] [local]
       GOLD      BLUE   GREEN
```

## Integration with Existing Systems

### @INDEXCUBE Integration
```perl
# L13 checksums become visual coordinates
my $visual_coord = <[plugin.storage.visual.extract-floats]>->({
    'p7ref' => 'p7://checksum:BWML13ABC',
    'layers' => ['L13-coordinate'],
});
# Returns x,y,z in L13 space for 3D visualization

# INDEXCUBE queries become visual selections
my $refs = <[base.indexcube.here]>->($coordinate);
# Render as glowing sphere at that coordinate
```

### P7REF Integration
```perl
# Any P7REF can be visualized
my $viz = <[plugin.storage.visual.extract-floats]>->({
    'p7ref' => 'p7://nested:9p:host[checksum:ABC]|segment',
    'layers' => ['all'],
});
# Produces float vector for positioning in visual space
```

## Command Line Interface

```bash
# Extract float values
storage visual extract p7://checksum:ABC --layers=intrinsic,temporal

# Calculate proximity matrix
storage visual proximity --refs @file_list.txt --output matrix.json

# Run harmonization workflow
storage visual harmonize --workflow dedup-hot --refs @all_refs.txt

# Render graph
storage visual render --refs @cluster.txt --layout 3d --output scene.unity

# Interactive ASCII explorer
storage visual explore --ref p7://checksum:ABC --depth 3
```

## Implementation Plan

### Phase 1: Float Extraction
- `plugin.storage.visual.extract-floats`
- Support intrinsic, temporal, network layers
- P7REF type auto-detection

### Phase 2: Proximity
- `plugin.storage.visual.proximity-calc`
- Multiple distance metrics
- Harmonized scoring

### Phase 3: Workflows
- `plugin.storage.visual.harmonization-filter`
- YAML/JSON workflow definitions
- Step-by-step iteration

### Phase 4: Rendering
- `plugin.storage.visual.render-graph`
- Multiple output formats
- Terminal ASCII preview

### Phase 5: Branching
- `plugin.storage.visual.branch-score`
- Multi-node optimization
- Replication recommendations

## Future: Neural Embeddings

Train models to predict optimal placement:
```perl
my $embedding = <[plugin.storage.visual.neural-embed]>->($p7ref);
# Returns 128-dimensional vector
# Similar refs cluster in embedding space
# Use for intelligent prefetching
```

---

*Visualizing the implosion vortex as a navigable starfield.*

#,,,,,,,.,,,.,,,,,.,.,...,.,.,.,.,.,,,...,...,..,,...,...,,..,,,.,,,.,...,,,,,
#MGQVCH4OVLZNYLVA4XZM2MICA57XEO6MMH6QHAWNM2N4SG36JJ5LDNICSO7J2JFCQEKJSMW2MY3GQ
#\\\|MS7NE4DCA7T4CEYIG6AF6BS6MCCB3H32NCO42V2KNBAZ5FHXSQD \ / AMOS7 \ YOURUM ::
#\[7]SX2N5DHX7EGUOAOHBPZNYVYI6Z5E7YSRJTFR4XC25NS7N62R2OAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
