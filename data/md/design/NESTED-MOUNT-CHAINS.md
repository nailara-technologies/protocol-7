# Nested Mount Chains - Unified Namespace Vision

> *Every address is a path. Every path is traversable.*

## Concept

Protocol-7's storage layer becomes a **universal translator** - mounting different address spaces into a seamless, navigable namespace.

```
[protocol://authority/path/[nested-protocol://nested-path]]
```

## Address Grammar

```
[9P:D:/[P7:protocol-7.modules.base.init_code]]
│  │  │  │  │
│  │  │  │  └── Checksum-addressed content
│  │  │  └──── Protocol-7 namespace
│  │  └─────── Windows D: drive root
│  └────────── 9P protocol, localhost implied
└───────────── Mount point boundary

[P7:|[AMOS7|]files.taeki|downloads.video]
│  │ │      │ │      │  │
│  │ │      │ │      │  └── Specific file
│  │ │      │ │      └───── User namespace
│  │ │      │ └──────────── Checksum segment
│  │ │      └────────────── AMOS7 segment type
│  │ └───────────────────── Root of P7 storage
│  └─────────────────────── P7 native protocol
└────────────────────────── Mount chain
```

## Real-World Examples

### Cross-Platform Development

```
# Mount WSL Windows drive with nested P7 overlay
[9P:localhost:5640/mnt/c/Users/dev/Projects/[P7:AMOS7|my-project/]]

# Navigate seamlessly
cd /mnt/wsl/Projects/my-project/src
# ^ WSL path          ^ P7 checksum overlay

# Edit file - stored by checksum automatically
vim main.c  # → AMOS7:abc123.../main.c
```

### Distributed Storage Mesh

```
# Three-node mesh
[P7:|[AMOS7|]local.storage]
[P7:|[AMOS7|][9P:node2.example.com:15641/storage]]
[P7:|[AMOS7|][9P:node3.example.com:15641/storage]]

# Unified view
ls /storage/
# local/  node2/  node3/

# File exists on node2, cached locally
cat /storage/node2/docs/manual.pdf
# First fetch: 2 seconds
# Second read: 0.01 seconds (local cache)
```

### Time-Traveling Filesystem

```
# P7 segment with temporal versioning
[P7:|[AMOS7|]files.project|src.main.c|version:2024-03-27T10:00:00]
[P7:|[AMOS7|]files.project|src.main.c|version:2024-03-27T14:30:00]
[P7:|[AMOS7|]files.project|src.main.c|version:latest]

# Access any version
diff /project/src/main.c@10:00 /project/src/main.c@14:30
```

## Implementation Layers

### Layer 1: Protocol Handlers

```perl
# plugin.storage.9p - Mount remote 9P
$storage->mount('9P://localhost:5640/mnt/c', '/mnt/wsl');

# plugin.storage.p7 - Mount checksum-addressed
$storage->mount('P7://AMOS7', '/storage/AMOS7');
```

### Layer 2: Path Translation

```perl
# Translate nested path to operations
my $path = '[9P:D:/[P7:AMOS7|files]]';

# Parsed as:
# 1. Mount 9P://localhost/D:/
# 2. Within that, mount P7://AMOS7/files
# 3. Result: unified directory listing
```

### Layer 3: Cache Coherence

```perl
# Intelligent caching across boundaries
$data{'storage'}{'cache'}{$checksum} = {
    'local_path'  => '/storage/cache/abc123',
    '9p_source'   => 'D:/original/file.txt',
    'last_access' => time(),
    'pin'         => 0,  # Can be evicted
};
```

## Address Components Reference

| Component | Syntax | Example |
|-----------|--------|---------|
| Protocol | `protocol://` | `9P://`, `P7://`, `SFTP://` |
| Authority | `host:port` | `localhost:5640`, `node2:15641` |
| Segment | `\|segment\|` | `\|AMOS7\|`, `\|files\|` |
| Checksum | `[base32]` | `AMOS7ABC123...` |
| Timestamp | `@ISO8601` | `@2024-03-27T10:00:00Z` |
| Version | `#version` | `#latest`, `#v1.2.3` |

## Mount Chain Operations

### Creating Chains

```bash
# Mount WSL with P7 overlay
storage mount-chain '9P:localhost:5640/mnt/c[P7:AMOS7|overlay]'

# Mount remote node with local cache
storage mount-chain '9P:node2.example.com:15641/storage[P7:AMOS7|cache]'
```

### Traversing Chains

```bash
# Navigate naturally
cd /mnt/wsl/Users/dev/Downloads
ls  # Shows P7 overlay if present

# Explicit chain navigation
cat /mnt/wsl/[P7:AMOS7|documents]/report.pdf
#     ^ WSL base   ^ P7 segment
```

### Dissolving Chains

```bash
# Unmount specific layer
storage unmount-layer /mnt/wsl/P7:AMOS7

# Flatten chain to local storage
storage assimilate /mnt/wsl/[P7:AMOS7|*] /local/storage/
```

## Security Boundaries

Each protocol maintains its own security:

```
[9P:trusted-host/P7:AMOS7|secure-files]
 │  └─ 9P auth (read-only) ─┘
 └─ P7 encryption (end-to-end)

[SFTP:user@remote[P7:AMOS7|encrypted]]
 │  └─ SSH auth ─┘
 └─ P7 encryption layer
```

## The Implosion Effect

As chains are traversed:

1. **Discovery**: New files found via 9P, SFTP, etc.
2. **Hashing**: Checksums computed, stored in P7 namespace
3. **Deduplication**: Identical content merged to single instance
4. **Caching**: Hot data cached locally
5. **Assimilation**: Remote content gradually becomes local

```
[9P:remote/files] --traverse--> [P7:AMOS7|hash] --cache--> [local:storage]

Remote file → Checksum address → Local replica
(5ms fetch)   (instant lookup)   (0.1ms read)
```

## Future Syntax Extensions

```
# Multi-hop routing
[9P:gateway[P7:segment[9P:backend/storage]]]

# Conditional mounting
[9P:primary||fallback[P7:backup]]

# Query-based addressing
[P7:AMOS7|files?type=pdf&size>1MB]

# Temporal snapshots
[9P:host/share|@2024-03-27T00:00:00Z]
```

## Implementation Roadmap

### Phase 1: Basic Chains
- [x] 9P client (storage.9p.*)
- [x] Checksum mapping (plugin.storage.checksum)
- [ ] Chain parser
- [ ] Unified mount table

### Phase 2: Nested Navigation
- [ ] Path translation engine
- [ ] Cross-protocol caching
- [ ] Permission inheritance

### Phase 3: Mesh Formation
- [ ] Automatic discovery
- [ ] Chain optimization
- [ ] Distributed deduplication

### Phase 4: Universal Namespace
- [ ] Global P7 root
- [ ] Protocol-agnostic access
- [ ] Implicit mounting

---

*Every mount is a portal. Every portal leads to the vortex.*

#,,,.,...,.,.,,..,..,,...,..,,,,.,,.,,,,.,,,.,..,,...,...,,,,,,.,,.,,,,.,,...,
#JM3TSSXTXRDCXNLFZJECBICHS7TZEN73GBKOKVX7RTGUB3LDMOGII23KNBJQ54OC6T52P2RF2S564
#\\\|URRW34QI4Z5UWBVGYK6EDL765CJJQVR7FJKSOIN2WSCFFJZ6YYY \ / AMOS7 \ YOURUM ::
#\[7]ZX3LQJWFFPVCM5YT3HGEUCRDL2GG3XB5SFHC3YIEGBVN2WQPTQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
