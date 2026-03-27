# Checksum Cluster Map

> *Efficient checksum-to-group mapping with P7REF expansion*

## Core Concept

A memory-efficient mapping where each checksum (the key) points to an arrayref of related checksums (the group), enabling:

- **Deduplication groups** — similar/similar files by checksum proximity
- **Version chains** — sequential versions of evolving content
- **Spatial clusters** — L13 coordinate neighbors
- **Temporal sequences** — time-ordered checksum relationships
- **Semantic groups** — content-similar checksums

```
checksum-cluster: {
  'bmw-L13:ABC123...' => {
    'members'  => ['bmw-L13:DEF456...', 'bmw-L13:GHI789...', 'p7://checksum-cluster:OVERFLOW'],
    'type'     => 'proximity',
    'metadata' => {...},
    'p7ref'    => 'p7://checksum-cluster:bmw-L13:ABC123...',
  }
}
```

## Architecture

```
$data{'storage'}{'mapping'}{'checksum-cluster'}
├── clusters          # hashref: cluster_id => cluster_data
│   └── <checksum> => {
│       ├── id           # cluster checksum
│       ├── type         # proximity|temporal|semantic|version|harmonic
│       ├── members      # arrayref of checksums (may contain P7REFs)
│       ├── metadata     # arbitrary data
│       ├── p7ref        # canonical P7REF address
│       └── created/updated
│   }
├── index             # reverse: member_checksum => cluster_id
├── by_type           # grouped by type for efficient queries
├── p7ref_cache       # cached P7REF strings
└── config & stats
```

## Memory Efficiency

### Shared Empty Arrayrefs
Empty clusters use a shared singleton arrayref to save memory:
```perl
'_empty_array' => [],  # Shared reference

# In cluster:
'members' => $registry->{'_empty_array'},  # Shared until first member added
```

### Lazy P7REF Resolution
P7REFs in member lists are only resolved when explicitly requested:
```perl
# Unresolved (fast)
'members' => ['checksum1', 'p7://checksum-cluster:overflow1']

# Resolved on demand
<[plugin.storage.checksum.cluster.lookup]>->({
    'resolve_p7ref' => 1,  # Expand all P7REFs to actual checksums
});
```

### Reverse Index
O(1) lookup of which cluster a checksum belongs to:
```perl
$index{'bmw-L13:MEMBER123'} = 'bmw-L13:CLUSTER456';
```

## API Reference

### Create Cluster
```perl
<[plugin.storage.checksum.cluster.create]>->({
    'checksum' => 'bmw-L13:ABC123...',  # Primary checksum (cluster ID)
    'type'     => 'proximity',          # Cluster type
    'members'  => ['bmw-L13:DEF...', 'bmw-L13:GHI...'],
    'metadata' => { 'source' => 'visual-scan' },
});
# Returns: { mode => 'true', data => { cluster_id, p7ref, member_count } }
```

### Add Members
```perl
<[plugin.storage.checksum.cluster.add]>->({
    'cluster_id' => 'bmw-L13:ABC123...',
    'members'    => ['bmw-L13:NEW1...', 'bmw-L13:NEW2...'],
});
# Auto-creates overflow clusters if size exceeds limit
```

### Lookup
```perl
<[plugin.storage.checksum.cluster.lookup]>->({
    'checksum'      => 'bmw-L13:ABC123...',
    'resolve_p7ref' => 1,  # Expand nested cluster references
});
# Returns: { cluster_id, type, members, metadata, p7ref, is_primary }
```

### Traverse Graph
```perl
<[plugin.storage.checksum.cluster.traverse]>->({
    'start'     => 'bmw-L13:ABC123...',
    'max_depth' => 3,
    'type'      => 'proximity',  # Optional filter
    'callback'  => sub { my $node = shift; ... },
});
```

### Query
```perl
<[plugin.storage.checksum.cluster.query]>->({
    'query'    => 'hubs',       # all|orphans|hubs|stats
    'type'     => 'proximity',  # Filter by type
    'min_size' => 5,
    'limit'    => 100,
});
```

## Cluster Types

| Type | Description | Use Case |
|------|-------------|----------|
| `proximity` | Checksum Hamming distance | Similar file detection |
| `temporal` | Time-based relationships | Version history |
| `semantic` | Content similarity | Topic clustering |
| `version` | Explicit versioning | Git-like chains |
| `harmonic` | D13 alignment | Entropy-based grouping |
| `overflow` | Auto-created when full | Size management |

## P7REF Expansion

Clusters can reference other clusters via P7REF for unlimited scaling:

```
Main Cluster (1000 members, full)
  └── members: [chk1, chk2, ..., chk999, p7://checksum-cluster:overflow-1]

Overflow-1 (1000 members, full)
  └── members: [chk1000, ..., chk1999, p7://checksum-cluster:overflow-2]

Overflow-2 (500 members)
  └── members: [chk2000, ..., chk2499]
```

Logical size: 2500 members
Physical clusters: 3
Lookup complexity: O(n) where n = overflow chain depth (usually < 3)

## Command Line Interface

```bash
# Create cluster
checksum-cluster create bmw-L13:abc123 :type: proximity \
    bmw-L13:def456 bmw-L13:ghi789

# Add members
checksum-cluster add bmw-L13:abc123 bmw-L13:jkl012

# Lookup
checksum-cluster lookup bmw-L13:abc123

# Traverse graph
checksum-cluster traverse bmw-L13:abc123 :max-depth: 5

# Query
checksum-cluster query hubs :limit: 10
checksum-cluster query stats

# Create from visual mapping
checksum-cluster from-visual L13 :threshold: 0.1
```

## Integration with Visual Mapping

```perl
# Extract L13 coordinates and create spatial clusters
my $coords = $data{'storage'}{'mapping'}{'visual'}{'coordinates'};

for my $p7ref (keys %$coords) {
    my $c = $coords->{$p7ref};
    my $grid_key = sprintf("L13:%d,%d,%d",
        int($c->{'L13_x'} / 10),
        int($c->{'L13_y'} / 10),
        int($c->{'L13_z'} / 10));

    # Create spatial cluster
    <[plugin.storage.checksum.cluster.add]>->({
        'cluster_id' => $grid_key,
        'members'    => [$checksum],
    });
}
```

## Integration with Pager Zenka

```perl
# Create pager from checksum cluster
my $cluster = <[plugin.storage.checksum.cluster.lookup]>->({
    'checksum' => 'bmw-L13:GROUP123',
});

# Use cluster members as pager source
my $pager_id = <[pager.buffer.virtual]>->({
    'source_type' => 'checksum-list',
    'source_args' => {
        'items' => $cluster->{'members'},  # Arrayref of checksums
    },
});

# Apply harmonic filtering
<[pager.filter.division-13-harmonic]>->({
    'buffer_id' => $pager_id,
    'params'    => { 'seed' => 1, 'mode' => 'entropy' },
});
```

## Performance Characteristics

| Operation | Complexity | Memory |
|-----------|-----------|--------|
| Create | O(1) | O(m) where m = members |
| Lookup (primary) | O(1) | - |
| Lookup (reverse) | O(1) | - |
| Add member | O(1) avg | O(1) |
| Traverse | O(v + e) | O(d) where d = depth |
| Query (by type) | O(t) where t = type count | - |
| P7REF resolve | O(c) where c = chain depth | O(total members) |

## Storage Estimates

Per cluster (empty):
- Hash overhead: ~200 bytes
- Shared empty array: ~24 bytes (shared)

Per member:
- String pointer: 8-16 bytes
- Reverse index entry: ~40 bytes

Example: 1M clusters, avg 10 members each
- Clusters: 1M × 200B = 200 MB
- Members: 10M × 16B = 160 MB
- Reverse index: 10M × 40B = 400 MB
- Total: ~760 MB for 10M relationships

With compression (empty clusters shared, common prefixes):
- Estimated: ~500 MB

---

*Checksums cluster like stars in constellations — individually unique, collectively meaningful.*

#,,,.,,.,,,..,.,,,,,.,..,,.,,,...,..,,.,,,..,,..,,...,...,..,,.,.,,,.,,..,,.,,
#22YY6G2N4SSP7SBZ42LB6TY6MY3IHCDL2XP2Z2DWWJXWDGPKAPXPXXFAUQJDMECJGGTY5KK65NW3S
#\\\|JLHG55FPEHWYR46G3AEIC562XXNS667YFUHDLDRELZ5SSSBH2QH \ / AMOS7 \ YOURUM ::
#\[7]GGUDYPWNFAUOUXZKDJRV2OJP3IJBNG4IGHCPJ6KDPHR2PXO4WOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
