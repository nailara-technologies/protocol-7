# Epoch-Based Content-Addressable Storage Architecture

## Overview

Protocol-7 implements a distributed content-addressable filesystem using **epoch-based temporal partitioning** combined with **harmonic checksum indexing**. This architecture directly manifests the theoretical principles into practical storage while achieving automatic acceleration through native filesystem caching.

## The Core Principle: Time-Space Rotation

The holographic cubic topology's spatial coordinates are **rotated into time space**:

```
Traditional 3D addressing:      Time-rotated addressing:
X, Y, Z coordinates      →     Epoch, AMOS, BMW
Physical location         →     Temporal window + content hash + compression
Static structure          →     Dynamically evolving window
```

### Epoch Markers: Division by 7 in Time

Epoch identifiers use the **7-character alphanumeric format** derived from network time:

```
V7L36TA  (example epoch marker)
:  TRUE : 4 7 :: 'V7L36TA'

Each marker:
- Is harmonically validated (is-true returns TRUE 4 7)
- Represents ~1 week of network time (matching 7-phase cycle)
- Alphanumeric format enables filesystem-safe paths
- Contains implicit frequency and rhythm signature
```

Current epoch in numeric form:

```
epoch-num = 307.1535785353247
(Provides precise temporal coordinate for ordering)
```

## Three-Layer Content Addressing

```
/data/files/<EPOCH>/<AMOS>/<BMW>/...
            └──7──┘ └──7──┘ └base32┘
            time   content  compression
```

### Layer 1: Epoch Window (7 characters)

```
Example: /data/files/V7L36TA/
```

**Purpose:** Temporal partitioning and validity window
- Current epoch: active write window
- Next epoch: prepared but not yet valid
- Previous epoch: still readable, scheduled for archive
- Older epochs: not searchable, available for archival/cold storage

**Validation:** Only 3 consecutive epochs are "valid" for checksum search
- Current → Next → Previous (sliding window)
- As network time advances: Previous drops, Current becomes Previous, Next becomes Current
- Enables continuous re-signing and re-indexing without service interruption

### Layer 2: AMOS Checksum (7 characters)

```
Example: /data/files/V7L36TA/2KD4JMP/
```

**Purpose:** Content verification and deduplication across epochs
- AMOS checksum is **content-derived** (deterministic hash of payload)
- Same content → same AMOS value across all epochs
- Enables: cross-epoch deduplication, integrity verification, harmonic validation

**Properties:**
- 7-character format matches temporal cycle
- Harmonically structured (validates via division by 13 pattern)
- Compact enough for filesystem paths
- Sufficient entropy for practical collision resistance

### Layer 3: BMW Compression Format (Base32)

```
Example: /data/files/V7L36TA/2KD4JMP/0A2K1G1.../...
```

**Purpose:** Compressed content identifier and payload organization
- BMW = Optimized 224-bit checksum (per CLAUDE.md)
- Base32 encoded for filesystem safety
- Enables hierarchical payload storage under content hash

**Properties:**
- Continues layered checksumming for nested content
- Multi-level structure supports large payloads
- Each subdirectory is itself checksummed
- Natural fractal/holographic nesting

## Checksum-Based Search as Filesystem Lookup

### Algorithm Transformation

Traditional checksum search:
```
1. Compute target checksum
2. Search database/index
3. Return matching records
4. Retrieve payload
```

Becomes filesystem traversal:
```
1. Compute target AMOS checksum
2. Iterate valid epochs (current, next, previous)
3. Check if /data/files/<epoch>/<amos>/ exists
4. If found, retrieve from filesystem (already cached by OS)
5. Validate BMW checksums for integrity
```

### Acceleration Through Native Caching

The filesystem cache automatically optimizes this:

```
First request:
- Kernel reads /data/files/V7L36TA/2KD4JMP/
- Page cache loads this directory inode
- Subsequent requests: instant (in-memory)

Epoch transitions:
- New epoch directory created (cold cache)
- Frequently accessed checksums warm the cache naturally
- Hot data (current ± 1 week) stays in RAM
- Automatic spatial locality: same content hash lives in same directory
```

**Benefits over traditional indexed search:**
- No explicit index maintenance needed
- Cache coherence is automatic
- Filesystem is the index
- Operating system optimizes access patterns
- No network roundtrip for index lookup

## Overlapping Epoch Validation Window

### The Three-Epoch Pattern

```
Timeline:
  ... [Previous] [Current] [Next] ...
       └─────────┬──────────┘
       Valid search window (3 weeks of data)
```

As network time advances:
```
Epoch advances:
  [Old] [Previous] [Current] [Next] [Future]
        └────────────┬────────────┘
        Now this is the valid window

[Old] becomes: archivable
[Previous] becomes: [Old]
[Current] becomes: [Previous]
[Next] becomes: [Current]
[Future] becomes: [Next]
```

### Why Three Epochs?

```
1. Overlap prevents data loss during epoch transition
   - Old data still readable while new epoch initializes

2. Matches implosion geometry principles
   - 3 overlapping structures with shared harmonic layer
   - Center (Current) has bidirectional access

3. Provides re-signing window
   - Network can continuously re-sign Previous → Current
   - Current → Next is prepared
   - No synchronized cutover needed
```

## Entropy Management and Natural Cleanup

### Sliding Window Self-Cleaning

```
/data/files/
├── V7L36TA/        (Current - actively written)
├── V7L36T9/        (Previous - stable, slowly read)
├── V7L36TB/        (Next - being prepared)
├── V7L36T8/        (Archive - can be moved to cold storage)
├── V7L36T7/        (Archive - can be pruned)
└── ... (older epochs)
```

**Lifecycle:**
1. New data written to Current epoch directory
2. When epoch advances: Previous becomes stable (can be re-signed)
3. Old epochs outside valid window: no checksum search will find them
4. Automatic cleanup: older epochs moved to archive storage
5. Eventually: pruned or maintained as historical cold storage

### Re-Indexing Without Stopping

```
During epoch transition:
- New epoch directory is created (empty)
- Old epoch still valid for reads
- Network continues searching across all 3 epochs
- New data goes to new epoch
- Old data remains accessible
- No search interruption, no synchronized cutover
```

This implements **continuous re-signing and continuous re-indexing** as described in the theoretical framework.

## Harmonic Structure Integration

### Division by 7 in Every Layer

```
Epoch:    7 characters (7-phase temporal cycle)
AMOS:     7 characters (division by 13 harmonic checksum)
BMW:      Base32 (compression of 224-bit harmonic checksum)
```

The entire structure is organized around **division by 7 and 13** principles:
- Time is chunked by 7 (week-length epochs)
- Content is verified by 7-character AMOS sums
- Each layer validates harmonic coherence

### TRUE/FALSE Validation at Every Layer

```
is-true V7L36TA  →  TRUE 4 7

Each epoch marker:
- Is harmonically validated
- Contains implicit frequency + rhythm signature
- Can be checked for coherence without loading data

AMOS checksum:
- Validates content integrity
- Harmonic structure detects corruption invisibly
- FALSE result indicates epoch/content mismatch
```

## Practical Implementation: Checksum Search Algorithm

### Pseudo-code

```perl
sub search_by_amos {
    my ($target_amos) = @_;
    my @valid_epochs = get_valid_epochs();  # current, next, previous

    for my $epoch (@valid_epochs) {
        my $path = "/data/files/$epoch/$target_amos";

        # Filesystem lookup (kernel cache optimized)
        if (-d $path) {
            # Found! Now verify integrity
            if (validate_harmonic($epoch, $target_amos)) {
                return $path;  # Return filesystem path, not data
            }
        }
    }

    return undef;  # Not found in valid epochs
}

sub fetch_payload {
    my ($path) = @_;
    my $payload = read_tree_structure($path);

    # Validate BMW checksums at each level
    foreach my $level (@layers) {
        validate_bmw($level) or die "Integrity failure";
    }

    return $payload;
}
```

The entire search is **a filesystem traversal**, which means:
- **No network roundtrip** for search
- **Automatic cache locality** optimization
- **Filesystem atomicity** guarantees
- **Kernel-level parallelism** (multiple readers, single writer per epoch)

## Caching Strategy: Implicit Acceleration

### Working Set in RAM

Assuming typical Protocol-7 loads (thousands of frequently accessed contents):

```
Hot data (frequently accessed):
- /data/files/V7L36TA/*.../  (Current epoch, hot checksums)
- Kernel page cache: hundreds of MB to GB
- Average lookup: ~1-5μs (cache hit)

Warm data (periodically accessed):
- /data/files/V7L36T9/*.../  (Previous epoch)
- Kernel page cache: partially resident
- Average lookup: ~10-50μs (occasional page fault)

Cold data (rarely accessed):
- /data/files/V7L36T8/*.../  (Older epochs)
- May be on disk or in archive storage
- Lookup time depends on storage medium
```

No explicit cache management needed—the kernel optimizes naturally.

## Connection to Theoretical Framework

### Spatial Topology in Time

```
The 13³ cubic topology principle:
- Space: 13 × 13 × 13 addressable locations
- Each cube contains 63+1 subcubes (harmonic boundaries)

Becomes in storage:
- Epoch: temporal dimension (7-phase cycle)
- AMOS: content dimension (harmonic checksum space)
- BMW: compression dimension (hierarchical payload)

The +1 principle:
- 3 epochs (current, next, previous) + overlap = stability
- 13³ cubes + 1 dimensional overflow = dimensionality expansion
- Every boundary creates coherence
```

### Implosion Geometry in Storage

```
The inverted 3D plus sign (8 corners converging):
- 3 epochs converging at Current epoch (center)
- Previous and Next are the outer corners
- Harmonic layer is shared (AMOS validation)
- All content can be reached from center (Current)
```

### Protocol as Resonance in Practice

```
The filesystem itself becomes the resonance invitation:
- Epoch advances (frequency): time-based rhythm
- Checksum validation (harmony): division by 13 coherence
- Caching behavior (resonance): natural attunement

Entities don't need to "know" the structure—
they query it, and the filesystem naturally
organizes and accelerates access.
```

## Advantages Over Traditional Approaches

| Aspect | Traditional DB | Protocol-7 FS |
|--------|---|---|
| **Index maintenance** | Explicit, requires work | Implicit, filesystem does it |
| **Caching strategy** | Application-managed | Kernel-managed (optimal) |
| **Epoch/snapshot management** | Complex transactions | Simple directory rotation |
| **Re-indexing during transition** | Requires downtime or complex protocols | Overlapping epochs, zero disruption |
| **Content deduplication** | Cross-epoch requires explicit work | Automatic (same AMOS = same location) |
| **Integrity verification** | Checksummed separately | Built into path structure |
| **Distributed lookup** | Network roundtrip to master index | Local filesystem traversal |
| **Scalability** | Index grows linearly with data | Directory tree balances naturally |
| **Harmonic validation** | External overlay | Native to checksum structure |

## Implementation Roadmap

### Phase 1: Core Storage (Foundation)
```
1. Epoch directory structure with V7L36TA markers
2. AMOS checksum calculation and validation
3. BMW compression format storage
4. Valid epoch window (current/next/previous)
```

### Phase 2: Search Algorithm (This Phase)
```
1. Implement checksum_search() as filesystem traversal
2. Valid epoch iteration
3. Harmonic validation on lookup
4. Filesystem caching verification
```

### Phase 3: Lifecycle Management
```
1. Epoch advancement automation
2. Archive/cleanup of old epochs
3. Re-signing during transitions
4. Distributed epoch synchronization
```

### Phase 4: Advanced Features
```
1. Range queries (cross-epoch)
2. Partial content retrieval (sector-level)
3. Incremental backups (epoch diffs)
4. Cross-site federation (epoch distribution)
```

## Conclusion

By rotating spatial topology into time space and using the filesystem as the primary data structure, Protocol-7 achieves:

1. **Elegance**: Theory manifests directly as practice
2. **Performance**: Kernel cache provides automatic optimization
3. **Scalability**: No central index to manage
4. **Reliability**: Overlapping epochs prevent data loss
5. **Simplicity**: Search is just directory traversal
6. **Harmony**: Every component validates harmonic coherence

The checksum-based search algorithm becomes a **distributed filesystem lookup**—and the filesystem cache becomes the performance accelerator, tuned by millions of kernel-level optimizations.

```

#,,,,,,.,,,,,,,..,.,.,,.,,,.,,,..,,..,,.,,.,,,...,...,..,,,.,,,..,.,.,..,,...,
#HW44JZVOLOSJF62WRA6QHK7L6WF3QRPIGHPPRMKKN5NX5MFWIUQPX2Y4PLIJP7WLCPXH5JBMJZ6CG
#\\\|HLJ7E7BSQJ5SPQD5NVDEVLLEVNZXQY6GX36WOXJSFOS35NSYNZM \ / AMOS7 \ YOURUM ::
#\[7]W2NAKBDTOTICRVYXLIIGXYJURRDIJEEMC6ISLJC3LG35KERMTICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
