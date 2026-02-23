# Data Zenka Architecture

## Vision

**"Network data is zenka data. Zenka data is network data."**

A seamless data fabric bridging:
- Indexer zenka (file indexing, wordlists, inotify monitoring)
- Data checksums (ELF, BMW, C25519 key-linked)
- Cubic space network mappings (13³ topology)
- Native filesystem access (FUSE mounts)

## Current State

Stub exists:
- `configuration/zenki/data/start` - basic zenka config
- `modules/data.init_code` - File::ExtAttr autoload
- `modules/data.cmd.mount-cube` - stub (not implemented)
- `modules/data.cmd.attach-fs-mount` - stub (not implemented)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA ZENKA FABRIC                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   NETWORK    │◄──►│  CUBIC SPACE │◄──►│  FILESYSTEM  │      │
│  │   LAYER      │    │   MAPPING    │    │   LAYER      │      │
│  │              │    │   (13³)      │    │   (FUSE)     │      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                   │                    │              │
│         └───────────────────┼────────────────────┘              │
│                             │                                   │
│                    ┌────────▼────────┐                         │
│                    │   DATA ZENKA    │                         │
│                    │   CORE          │                         │
│                    │                 │                         │
│                    │  • Checksum     │                         │
│                    │  • Topology     │                         │
│                    │  • Permissions  │                         │
│                    │  • Replication  │                         │
│                    └────────┬────────┘                         │
│                             │                                   │
│                    ┌────────▼────────┐                         │
│                    │ INDEXER ZENKA   │                         │
│                    │                 │                         │
│                    │  • Wordlists    │                         │
│                    │  • Inotify      │                         │
│                    │  • Search       │                         │
│                    └─────────────────┘                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Core Concepts

### 1. Cubic Space Addressing (13³)

Data locations mapped to 13×13×13 cubic topology:
- **2197 total nodes** (13³)
- **27-node neighborhood** per data block (3³)
- **ELF checksum** determines spatial position
- **BMW checksum** determines depth/validation

```
Data ID → ELF checksum → (x, y, z) in 13³ space
                        → 27-node neighborhood
                        → Replica placement
```

### 2. Network-Filesystem Unification

**Mount modes**:

| Mode | Direction | Use Case |
|------|-----------|----------|
| `attach-fs-mount` | FS → Zenka | Expose existing directory to network |
| `mount-cube` | Zenka → FS | Mount cubic namespace as local directory |
| `bind-network` | Network ↔ Zenka | Link remote cubic space to local |

### 3. Automatic Checksum Linking

All data carries:
- **ELF checksum** (truth assertion / spatial position)
- **BMW checksum** (content validation)
- **C25519 key** (ownership / encryption)

```perl
## Data block structure
{
    'content'      => $binary_data,
    'elf_checksum' => $spatial_coords,  # 13³ position
    'bmw_checksum' => $content_hash,    # integrity
    'key_id'       => $c25519_key,      # ownership
    'topology'     => $neighborhood_27, # related blocks
    'replicas'     => [@mirror_nodes],  # redundancy
}
```

### 4. FUSE Integration - Nested Hash Mapping

Native filesystem access via FUSE with **nested hash traversal**:

**Namespace Convention**: `<zenka>.<feature>.<state>.<branches>`

```
Zenka data hash:          FUSE mount:
user.taeki.files          /mnt/data/
├── uploads               ├── user/
│   └── documents         │   └── taeki/
│       └── scans         │       └── files/
│           └── doc1.pdf  │           └── uploads/
└── downloads             │               └── documents/
    └── archives          │                   └── scans/
                          │                       └── doc1.pdf
                          └── downloads/
                              └── archives/
```

**Key Features**:
- Internal `.` becomes `/` on filesystem
- **Type-based mapping**: HASH→dir, ARRAY→listing, SCALAR→file
- Uses existing hash resolver routines from `devmod.cmd.{dump,get,set}`
- Any nested data structure mountable at any depth
- Extended attributes store ELF/BMW checksums
- Inotify triggers automatic re-indexing

**Directory Listing Format (ARRAY)**:
```perl
## Array of hash entries = directory contents
[
    { 'name' => 'file1', 'content' => \$data1, 'mtime' => ... },
    { 'name' => 'file2', 'content' => \$data2, 'mtime' => ... },
]
## FUSE readdir returns: file1, file2
```

**Example Mount Commands**:
```bash
# Mount entire user namespace
p7.data mount user /mnt/users

# Mount specific user's files
p7.data mount user.taeki.files /mnt/taeki-files

# Mount just uploads
p7.data mount user.taeki.files.uploads /mnt/uploads
```

## Namespace Conventions

### Clean Zenka.Feature.State Structure

All data follows: `<zenka>.<feature>.<state>.<branches...>`

```perl
## Examples:
user.taeki.files.uploads.documents.scans
  │    │     │      │        │       └── leaf data
  │    │     │      │       └── sub-category
  │    │     │     └── action/type
  │    │    └── feature module
  │   └── user identifier
  └── zenka namespace

network.hosts.remote.192.168.1.1.status
index.wordlists.english.common
protocol-7.modules.base.registry
```

### Hash Resolution

Uses existing resolver from `devmod.cmd.*`:

```perl
my $data_ref = <[devmod.cmd.get]>->('user.taeki.files.uploads');
## Returns nested hash ref at that path

## Traversal uses existing convenience routines:
my $value = resolve_hash_path(\%data, 'user.taeki.files');
```

### Data Hash Structure - Type-Based Mapping

Reference types determine filesystem behavior:

| Perl Type | Filesystem | Purpose |
|-----------|------------|---------|
| **HASH ref** | Directory | Nested namespace (traversable) |
| **ARRAY ref** | Directory listing | Ordered list of entries |
| **SCALAR ref** | File | Actual data content or data pointer |
| **CODE ref** | Dynamic filter/proxy | Returns any reference type on access |

```perl
$data{'user'}{'taeki'}{'files'} = {
    ## HASH ref → Directory: uploads/
    'uploads' => {
        ## HASH ref → Directory: documents/
        'documents' => {
            ## HASH ref → Directory: scans/
            'scans' => [
                ## ARRAY ref → Directory listing
                {  ## Each entry is HASH → appears as file
                    'name'         => 'doc1.pdf',
                    'content'      => \$binary_data,  ## SCALAR ref → File content
                    'elf_checksum' => '...',
                    'bmw_checksum' => '...',
                    'key_id'       => 'taeki.base',
                    'topology'     => [x, y, z],
                    'mtime'        => timestamp,
                },
                {
                    'name'    => 'doc2.pdf',
                    'content' => \$binary_data2,
                    ...
                }
            ]
        }
    },
    ## SCALAR ref → File: readme.txt
    'readme.txt' => \$readme_content,
};
```

**Filesystem View**:
```
/mnt/user.taeki.files/
├── uploads/              [HASH]
│   └── documents/        [HASH]
│       └── scans/        [ARRAY → directory listing]
│           ├── doc1.pdf  [SCALAR ref content]
│           └── doc2.pdf  [SCALAR ref content]
├── readme.txt            [SCALAR ref content]
├── recent/               [CODE ref → returns ARRAY]
│   └── (dynamic)         [filtered by mtime > 24h]
└── large-video.mkv       [TIED SCALAR → memory mapped]
```

**Dynamic Behavior**:
- `recent/` → CODE executes on `ls`, returns filtered ARRAY
- `large-video.mkv` → TIED var fetches from disk on first `read()`
- All appear as normal files/directories to user

**Benefits**:
- Type-native traversal (no special markers needed)
- ARRAY listings allow custom ordering (by date, name, checksum)
- SCALAR refs for content enable memory-mapped files, symlinks, or lazy loading
- Mixed structures: directory can contain both subdirs (HASH) and files (SCALAR)

### 5. CODE References - Dynamic Filters

**CODE refs** act as **lazy evaluators** and **transformers**:

```perl
$data{'user'}{'taeki'}{'files'}{'dynamic'} = sub {
    my ($context) = @_;  # Access context (read, write, stat)

    # Can return any reference type:
    return \$generated_content;           # SCALAR - generated file
    return [ @filtered_entries ];        # ARRAY  - filtered listing
    return { %computed_structure };      # HASH   - computed directory
};
```

**Use Cases**:
- **Lazy loading**: Content generated on first access
- **Dynamic filtering**: Directory listing filtered by permissions/time
- **Search results**: CODE ref returns matching entries as ARRAY
- **Transformations**: On-the-fly format conversion (JSON→YAML)
- **Authentication gates**: CODE checks keys before returning content

```perl
## Dynamic search directory
'downloads' => sub {
    my $query = shift;  # FUSE context carries query params
    my @matches = grep { $_->{'name'} =~ /$query/ } @all_files;
    return \@matches;  # ARRAY ref = directory listing
}
```

### 6. Tied Variables - External Storage

Using Perl's `tie` mechanism for external backends:

```perl
## Tie to memory-mapped file
tie my $content, 'AMOS7::Data::MMap', '/path/to/large/file';
$data{'user'}{'taeki'}{'files'}{'video.mkv'} = \$content;

## Tie to database (lazy fetch)
tie my $db_record, 'AMOS7::Data::DB', { key => 'record-42' };
$data{'db'}{'records'}{'item-42'} = \$db_record;

## Tie to network resource (cached)
tie my $remote, 'AMOS7::Data::Remote', 'https://example.com/data.bin';
$data{'remote'}{'example'}{'data.bin'} = \$remote;
```

**TIE Integration**:
- FETCH → FUSE read()
- STORE → FUSE write()
- Access triggers automatic sync
- Local cache with remote backing

## Implementation Path

### Phase 1: Core Data Structures

1. **Data block registry**
   - ELF-to-cubic mapping
   - Neighborhood tracking
   - Checksum validation

2. **Indexer integration**
   - Wordlist generation from content
   - Inotify watch on data changes
   - Search indexing

3. **Basic mount commands**
   - `data.cmd.mount-cube` (zenka → FS)
   - `data.cmd.attach-fs-mount` (FS → zenka)

### Phase 2: Network Layer

1. **Cubic space protocol**
   - Node discovery via 13³ topology
   - Replica synchronization
   - Conflict resolution (truth assertion)

2. **Data replication**
   - 27-node neighborhood redundancy
   - Automatic failover
   - Consistency verification

### Phase 3: FUSE Filesystem

1. **FUSE driver**
   - Directory mapping from cubic space
   - Extended attribute storage
   - Inotify bridge to indexer

2. **Permission bridge**
   - Zenka auth → POSIX permissions
   - C25519 key ownership
   - Group-based access

## Commands to Implement

### `data.cmd.attach-fs-mount <path> <data-src>`
Attach existing filesystem path to zenka data fabric.

```perl
my ($mount_path, $data_source) = @args;

# 1. Validate path exists
# 2. Calculate ELF/BMW checksums
# 3. Map to cubic space
# 4. Register with indexer
# 5. Start inotify watch
# 6. Return handle
```

### `data.cmd.mount-hash <hash-path> <local-path>`
Mount nested data hash as local filesystem using type-based mapping.

```perl
my ($hash_path, $local_path) = @args;

# 1. Validate hash path exists in %data
# 2. Resolve nested hash ref via devmod resolver
# 3. Create FUSE mount
# 4. Traverse structure:
#    - HASH ref   → directory (recurse into keys)
#    - ARRAY ref  → directory listing (entries = files)
#    - SCALAR ref → file content
#    - CODE ref   → execute, return result type, cache if needed
#    - TIED var   → use tied interface for external storage
# 5. Return mount handle

## Example:
## mount-hash user.taeki.files /mnt/files
## HASH{'user'}{'taeki'}{'files'} = {
##   'docs'   => HASH { ... },        # → /mnt/files/docs/
##   'list'   => ARRAY [ ... ],       # → /mnt/files/list/
##   'note'   => SCALAR \$content,    # → /mnt/files/note
##   'recent' => CODE { ... },        # → /mnt/files/recent/ [dynamic]
##   'large'  => TIED SCALAR,         # → /mnt/files/large [mmap]
## }
```

### `data.cmd.mount-cube <cubic-coords> <local-path>`
Mount cubic space coordinates as local directory (topology view).

```perl
my ($cube_coords, $local_path) = @args;

# 1. Validate cubic coordinates (0-12 range)
# 2. Find all data blocks in 27-node neighborhood
# 3. Create FUSE mount
# 4. Map neighborhood to subdirectories
# 5. Return mount handle

## Example:
## mount-cube 7-7-7 /mnt/cube-777
## → /mnt/cube-777/neighbors/.../data
```

### `data.cmd.detach-cube <handle>`
Unmount and cleanup.

### `data.cmd.find-by-checksum <checksum>`
Locate data block by ELF or BMW checksum.

### `data.cmd.replicate <cube-coords> <target-nodes>`
Explicit replication control.

## Integration Points

### Indexer Zenka
- `index.init_code` - Shared wordlist infrastructure
- `index.jobs` - Indexing jobs for new data
- `list.index-jobs` - Monitor indexing progress

### Checksum System
- `AMOS7::CHKSUM::ELF` - Spatial positioning
- `AMOS7::CHKSUM::BMW` - Content validation
- `AMOS7::Protocol::P7` - Data serialization

### Cubic Topology
- `configuration/zenki/cube/` - Existing cubic space infrastructure
- Neighborhood_27 calculations from `protocol7-math-topology-reference.yaml`

## Security Model

1. **Ownership**: C25519 keys linked to data blocks
2. **Validation**: BMW checksums prevent tampering
3. **Truth**: ELF checksums enforce spatial consistency
4. **Access**: Extended attributes carry permission metadata

## Future Extensions

- **Encrypted volumes**: Data encrypted at rest with C25519
- **Versioning**: Historical snapshots via checksum chains
- **Cross-cube migration**: Move data between 13³ spaces
- **Graph queries**: Topology-aware data relationships

---

## Async Architecture Considerations

### The FUSE Blocking Problem

FUSE operations are **synchronous from the kernel's perspective** - `read()` must return data immediately. But Protocol-7 data sources are **async/deferred** (network fetches, remote cubic lookups).

### Solution: Child Zenka Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA ZENKA (Parent)                       │
│                     [Network Facing]                         │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Protocol-7   │◄──►│   Network    │◄──►│   Cache      │  │
│  │   Handler    │    │   Interface  │    │   Manager    │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                    │          │
│         └───────────────────┼────────────────────┘          │
│                             │                               │
│                    ┌────────▼────────┐                      │
│                    │  Child Spawner  │                      │
│                    │  (FUSE mounts)  │                      │
│                    └────────┬────────┘                      │
│                             │                               │
└─────────────────────────────┼───────────────────────────────┘
                              │ IPC (shared cache/protocol)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               DATA ZENKA CHILD (FUSE Handler)                │
│                     [Filesystem Facing]                      │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  FUSE        │◄──►│   Local      │◄──►│   Request    │  │
│  │  Interface   │    │   Cache      │    │   Queue      │  │
│  └──────────────┘    └──────┬───────┘    └──────┬───────┘  │
│                             │                    │          │
│                             └────────────────────┘          │
│                             (serves from cache,             │
│                              requests from parent)          │
└─────────────────────────────────────────────────────────────┘
```

### Operation Flow

**1. FUSE `read()` Request Arrives**:
```
Child (FUSE Handler):
  1. Check local cache
  2. Cache hit → return immediately
  3. Cache miss → queue request to parent, return EAGAIN or block
```

**2. Parent Handles Network Fetch**:
```
Parent (Network Facing):
  1. Receive request from child via IPC
  2. Issue deferred Protocol-7 request
  3. Wait for network response (non-blocking)
  4. Populate shared cache
  5. Notify child: "data ready"
```

**3. Child Completes FUSE Call**:
```
Child:
  1. Receive "data ready" signal
  2. Read from now-populated cache
  3. Return to FUSE/kernel
```

### Implementation Strategies

**Option A: Shared Memory + Signals**
```perl
## Parent and child share mmap'd cache
## Parent signals child when data arrives
## Child uses signalfd or poll for async notification
```

**Option B: Unix Domain Sockets**
```perl
## Child sends request via socket
## Parent responds when data ready
## Child uses non-blocking recv or io_uring
```

**Option C: Protocol-7 Native (Deferred Replies)**
```perl
## Child sends request with callback ID
## Parent issues deferred network call
## When reply arrives, parent sends to child via internal protocol
## Child matches callback ID, serves FUSE request
```

### Trade-offs

| Approach | Latency | Complexity | Cache Coherence |
|----------|---------|------------|-----------------|
| Shared Memory + Signals | Low | Medium | Manual sync |
| Unix Sockets | Medium | Low | Message-based |
| Protocol-7 Native | Medium | High | Built-in |

### Recommended: Hybrid Approach

**Hot paths** (frequently accessed): Shared memory cache in child
**Cold paths** (on-demand fetch): Protocol-7 deferred via parent

This keeps the child responsive for cached data while leveraging parent's network stack for remote fetches.

### Cache Prepopulation

Parent can proactively push data to child cache:
- Based on ELF topology (27-node neighborhood)
- Based on access patterns
- Based on pre-declared mount requirements

```perl
## Parent: "User mounted user.taeki.files, I'll prefetch neighborhood"
$parent->push_to_child_cache($neighborhood_27_data);
```

## Notes

The data zenka is the **materialization layer** - where abstract cubic topology becomes tangible storage, where network packets become files, where checksums become coordinates.

It bridges the mathematical purity of 13³ space with the messy reality of filesystems and networks.

**Key Insight**: The sync/async boundary is the child/parent split. Child speaks sync (FUSE), parent speaks async (Protocol-7). The cache is the translation layer.

"Data is not stored. Data is *positioned* in truth-space."

#,,..,,,,,.,.,.,,,,..,.,,,...,,..,,..,.,,,...,.,.,...,...,,,.,,.,,.,.,..,,.,,,
#7BI2GVTYRBSFI65KWHGLKVGOIKKK52OVZZ67O6YDPVDCX6DAFPZZOU5XGGCZLOUU2L5FTZZICSYHS
#\\\|FMMZ6SFSVKEFHUV62STCKHYAPNP3XOPVBW2NPZ6YZAG5HFSDOQQ \ / AMOS7 \ YOURUM ::
#\[7]AYW6BEYK4E4DVFXC5C5HNBBQ46KLBI5JUX64ZNWNWG7GAW5E5KDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
