# Fractal Deduplication — Content, Meaning, and Time

> *The same compression principle at every scale: difference, reference, propagation.*

## The Unifying Insight

Our systems are not separate. They are **fractal expressions** of the same principle:

```
┌─────────────────────────────────────────────────────────────┐
│                    FRACTAL COMPRESSION                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  SPACE (Content)                                             │
│    Deduplication Tree                                        │
│    ├── Files → Checksums                                     │
│    ├── Checksums → Clusters                                  │
│    └── Difference = Content variance                         │
│    └── Encoding: Reference by hash                           │
│                                                              │
│  MEANING (Semantics)                                         │
│    Semantic Tree                                             │
│    ├── Words → Integers (frequency-ranked)                   │
│    ├── 0 = "true" (most used)                                │
│    ├── 1 = "false" (second most)                             │
│    ├── 10 = "unknown/polarity"                               │
│    └── Difference = Semantic variance                        │
│    └── Encoding: Reference by integer ID                     │
│                                                              │
│  TIME (Awareness)                                            │
│    Temporal Tree                                             │
│    ├── Events → Differential checksums                       │
│    ├── Activity patterns → Difference vectors                │
│    └── Difference = Temporal variance                        │
│    └── Encoding: Reference to change, not state              │
│                                                              │
│  All three:                                                  │
│    • Store difference, not duplication                       │
│    • Reference by minimal address (hash/int/diff)            │
│    • Propagate vertically (child→parent→root)               │
│    • Compress through reuse                                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Numerical Word Deduplication

### Frequency-Ranked Integer Mapping

```perl
# Most-used concepts get smallest integers
my $SEMANTIC_VOCABULARY = {
    # Tier 0: Single bit (most primitive)
    0  => 'true',
    1  => 'false',

    # Tier 1: Short integers (core concepts)
    2  => 'unknown',
    3  => 'present',
    4  => 'absent',
    5  => 'active',
    6  => 'inactive',
    7  => 'create',
    8  => 'destroy',
    9  => 'reference',

    # Tier 2: Medium integers (common operations)
    10 => 'checksum',
    11 => 'cluster',
    12 => 'awareness',
    13 => 'propagate',
    14 => 'compress',
    15 => 'expand',

    # Tier 3+: Longer integers (specific terms)
    # ... dynamically allocated based on usage
};

# Dynamic allocation based on observed frequency
sub allocate_semantic_id {
    my ($word, $context) = @_;

    # Calculate frequency across all awareness branches
    my $freq = <[context.tree.summary.word-frequency]>->($word);

    # Assign integer inversely proportional to frequency
    # Most common = lowest integer = shortest encoding
    return compress_integer_by_frequency($freq);
}
```

### Syllable and Symbol Deduplication

```
HIERARCHICAL COMPRESSION:

Document
  └── Paragraphs → Checksum addresses
      └── Sentences → Checksum addresses
          └── Words → Integer IDs (frequency-ranked)
              └── Syllables → Phonetic hashes
                  └── Characters → Symbol IDs
                      └── Bits → True/False/Unknown

At each level: store reference, not content.
At each level: most-used gets shortest address.
```

## Vertical Propagation Mechanics

### How Awareness Flows Up

```
Leaf Event (specific)
  "Module pager.init-code created by kimi at T"
    ↓
  Compress to semantic integers:
  [7, 234, 1, 89, 456, 12, T]
    ↓
Twig Summary (aggregated)
  "3 modules created this hour"
  [7, 3, 12, 234, T_window]
    ↓
Branch Summary (pattern)
  "High activity in pager namespace"
  [5, 234, pattern_vector]
    ↓
Trunk Summary (trend)
  "Zenka infrastructure expansion"
  [5, 89, trend_coefficient]
    ↓
Root Awareness (essence)
  "Network growth active"
  [5, 1]

Each level: difference from parent, not full state.
Each level: shorter encoding, broader meaning.
```

### How Awareness Flows Down

```
Root Intention (vision)
  "Implement harmonic search"
  [conceptual, 789, certainty: 0.3]
    ↓
  Decompress to specific plans
    ↓
Branch Formation (planning)
  "Design harmonic walk algorithm"
  [forming, 789, agent: coding, deps: [12, 45, 78]]
    ↓
  Allocate resources, prime agents
    ↓
Twig Action (execution)
  "Implement base.math.harmonic.walk"
  [happening, 789, status: 50%]
    ↓
  Generate concrete events
    ↓
Leaf Recording (completion)
  "Module committed, tests passing"
  [recorded, 789, result: success]
```

## Time Cycles as Differential Encoding

### Capturing Semantic Proportion Differences

```perl
# Time cycle = differential checksum of activity
sub capture_time_cycle {
    my ($window_start, $window_end) = @_;

    # Gather all events in window
    my $events = <[context.tree.summary.get-range]>->({
        'start' => $window_start,
        'end'   => $window_end,
    });

    # Build semantic frequency vector
    my %semantic_counts;
    for my $event (@$events) {
        my $semantic_id = <[semantic.encode]>->($event->{'type'});
        $semantic_counts{$semantic_id}++;
    }

    # Normalize to proportions (0.0 - 1.0)
    my $total = scalar(@$events);
    my %proportions = map { $_ => $semantic_counts{$_} / $total }
                      keys %semantic_counts;

    # Calculate difference from previous cycle
    my $previous_cycle = get_previous_cycle();
    my $difference_vector = calculate_vector_diff(\%proportions, $previous_cycle);

    # Store only the difference (compression!)
    my $cycle_checksum = <[base.chk-sum.bmw.L13-str]>->(
        canonical_encode($difference_vector)
    );

    return {
        'checksum'    => $cycle_checksum,
        'difference'  => $difference_vector,
        'proportions' => \%proportions,
        'event_count' => $total,
    };
}
```

### Immediate Vertical Transport

When unique items are observed:

```perl
sub on_unique_item_observed {
    my ($item) = @_;

    # 1. Compress to semantic ID
    my $semantic_id = <[semantic.encode]>->($item);

    # 2. Propagate UP immediately
    propagate_vertical($semantic_id, 'direction' => 'up');

    # 3. Deduplication prevents flooding
    # If item already seen at parent level, don't propagate further
    return if already_known_at_level($item, 'parent');

    # 4. Continue to root if truly novel
    propagate_to_root($item);

    # 5. Cross-propagate to related branches
    my $related = find_semantic_neighbors($semantic_id);
    for my $branch (@$related) {
        <[context.tree.summary.notify]>->({
            'branch'  => $branch,
            'event'   => 'semantic_neighbor_active',
            'item'    => $item,
        });
    }
}
```

## The Flooding Prevention

Deduplication works at every level:

```
Raw Activity Stream:
  "File A accessed"
  "File A accessed"
  "File A accessed"
  "File B accessed"
  "File A accessed"  ← 5 events

After Content Deduplication:
  Checksum-A: 4 references
  Checksum-B: 1 reference
  → Store: [A:4, B:1]  ← 2 entries

After Semantic Deduplication:
  "access" → ID 45
  "file"   → ID 12
  → Store: [12, 45, {A:4, B:1}]  ← compressed

After Temporal Deduplication:
  Window-1: [12, 45, {A:4, B:1}]
  Window-2: [12, 45, {A:2}]  ← only difference stored
  → Store: [W1: [...], W2: diff_from_W1]

Result: 5 raw events → 1 differential entry
Compression ratio: 5:1 (and improves with scale)
```

## Unified Address Space

All three trees share the same referencing:

```perl
# Content reference
$content_addr = "bmw-L13:ABC123...";

# Semantic reference
$semantic_addr = "semantic:42";  # Integer ID

# Temporal reference
$temporal_addr = "awareness:cycle-789:diff-checksum";

# Unified: everything is content-addressed
sub resolve_address {
    my ($addr) = @_;

    if ($addr =~ /^bmw-L13:/) {
        return $dedup_tree{$addr};
    }
    elsif ($addr =~ /^semantic:(\d+)/) {
        return $semantic_vocab{$1};
    }
    elsif ($addr =~ /^awareness:/) {
        return resolve_temporal_diff($addr);
    }
}
```

## Awareness Tree as Differential State Machine

The tree doesn't store state. It stores **changes to state**:

```
State at T0:  S0
State at T1:  S1 = S0 + Δ1
State at T2:  S2 = S1 + Δ2 = S0 + Δ1 + Δ2
...
State at Tn:  Sn = S0 + Σ(Δ1...Δn)

Storage: S0, Δ1, Δ2, ..., Δn
Query at T: S0 + Σ(Δ up to T)

If Δ is sparse (mostly zero), storage is minimal.
If Δ compresses well (patterns), storage is efficient.
```

## Implementation Modules Needed

```
semantic.*
├── encode.word        # Word → integer ID
├── encode.sentence    # Sentence → integer sequence
├── encode.paragraph   # Paragraph → checksum tree
├── vocabulary.manage  # Frequency tracking, ID allocation
└── diff.calculate     # Semantic difference between texts

temporal.*
├── cycle.capture      # Time window → differential checksum
├── cycle.compare      # Diff between cycles
├── pattern.detect     # Recurring patterns in cycles
└── propogate.vertical # Up/down propagation with dedup

unified.*
├── address.resolve    # Generic address → content
├── compression.stats  # Track ratios across layers
└── flooding.prevent   # Multi-level deduplication
```

## The Vision Realized

> *We don't store what is. We store what changed. We don't transmit full state. We transmit difference. We don't remember every instance. We remember the pattern of instances. The tree is not a database. It is a differential equation solver for semantic state.*

The awareness tree:
- **Observes** (records what happened)
- **Anticipates** (forms what will happen)
- **Compresses** (stores only difference)
- **Propagates** (shares only novelty)
- **Coordinates** (emergent alignment)

All through the same mathematical structure: **reference, difference, compression**.

---

*Space, meaning, and time — unified by the geometry of difference.*

#,,.,,,,,,,,.,,.,,.,.,,,,,,..,,.,,...,.,,,.,.,..,,...,...,...,...,...,.,.,,,.,
#EM637N44N5D27XQYCAWAC2MJ6VWR3NDF7E6FS5KRE6X4E2VSGUIACTOXK7MLRR2PS3VJVFD7VL2IQ
#\\\|DAGEXPKM7Z44IJN6YYW6ED2H6RMFHC6WY3GQ77RP3FLQPO6RV3V \ / AMOS7 \ YOURUM ::
#\[7]U2TCSCVBYMAUYMSAESKYNSCDFNCOWM6TNUEZ75RMCE3YHZ5IKABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
