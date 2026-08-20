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
- `cfg/zenki/data/start` - basic zenka config
- `src/data.init_code` - File::ExtAttr autoload
- `src/data.cmd.mount-cube` - stub (not implemented)
- `src/data.cmd.attach-fs-mount` - stub (not implemented)

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

### Existing Infrastructure (Leverage, Don't Duplicate)

#### Indexer Zenka
- `index.init_code` - Wordlist infrastructure (Digest::BMW, Linux::Inotify2)
- `index.cmd.add-path` - Path monitoring for indexing
- `index.callback.wordlist-import` - Content analysis
- `index.jobs` - Background indexing jobs

#### Storage Zenka
- `storage.amos_chksum.open_socket` - **Use for ELF checksums**
- `storage.protocol.SFTP` - Remote storage protocol
- `storage.map-dirs.*` - Directory tree mapping framework
- `storage.unix.handler.amos-chksum` - Unix socket checksum service

#### Filesystem (fs) Zenka
- `fs.cmd.mount` - System mount operations
- `fs.cmd.unmount` - Cleanup operations
- `fs.is_mounted` - Mount status checking
- `fs.init_code` - Filesystem state management

### Checksum System (Use Existing)
- **`amos-chksum`** - ELF checksum for spatial positioning
- **`bmw`** - BMW checksum for content validation
- **`base32`/`base58`** - Encodings from AMOS7
- **C25519** - Key-linked ownership

### Reference Encoding (`base.p7refs.*`)

**Network-safe reference handling** - for sharing refs across nodes:

```perl
## Generate P7REF for network sharing
my ($p7ref, $chksum) = <[base.p7refs.gen_template_chksum]>
    ->('HASH', $b32_addr, $node_name);
## Returns: HASH:<chksum>:<b32_addr>

## Anonymized mode (for untrusted peers)
my $anon_ref = <[base.p7refs.gen_template_chksum]>
    ->('HASH', $b32_addr, undef, 'exclude_types');
## Returns: <chksum>:<b32_addr> (no type prefix)
```

**Applications**:
- **Network mounts**: Exchange P7REFs instead of raw memory addresses
- **Cubic replication**: Consistent ref IDs across 27-node neighborhood
- **Child/parent IPC**: Reference tokens for async communication
- **Cache keys**: Checksum-based invalidation

**Benefits**:
- Single optimization hub for reference encoding
- Half-anonymized (checksum validates without full exposure)
- Node-aware distributed references

### Cubic Topology
- `cfg/zenki/cube/` - Cubic space infrastructure
- `protocol7-math-topology-reference.yaml` - 13³ calculations
- `cfg/zenki/cube/pm-dep/AMOS7__CHKSUM` - ELF library

### Data Zenka's Role

**Data zenka is the coordinator**, not the implementer:
- Uses `storage.amos_chksum` for checksums (not reimplementing)
- Uses `fs.cmd.mount` for FUSE setup (not new mount logic)
- Uses `index.*` for search/wordlists (existing indexing)
- Provides **new**: Cubic space mapping, CODE ref evaluation, async child/parent pattern

**Checksum Algorithms (Reuse)**:
```perl
## ELF for spatial positioning via storage zenka socket
my $usock = <storage.unix_socket.amos-chksum>;
print {$usock} "  $data\n";  # 2-space indent protocol
my $elf = <$usock>;           # Returns ELF checksum
my ($x, $y, $z) = elf_to_cubic($elf);  # 13³ coordinates

## BMW for content validation
my $bmw = bmw_256($content);

## Base32/Base58 for display/encoding
my $b32 = encode_b32r($checksum);
my $b58 = encode_b58s($key_id);

## C25519 for ownership/encryption
my $pubkey = $keys{'C25519'}{$key_id}{'public'};
```

**Existing Encodings** (from `AMOS7::Protocol::P7`):
- BASE32 - Checksum display, key identifiers
- BASE58 - C25519 keys (like Bitcoin)
- BASE64 - Binary data transport
- HEX - Raw checksum bytes

**Mode Selection** (ELF truth assertion modes):
```perl
## Via storage socket protocol
print {$usock} ": 7 13 :\n";  # Select modes 7 and 13
print {$usock} "  $data\n";   # Get checksum in selected modes
```

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

#,,,,,,..,..,,...,..,,,,.,.,.,,..,...,..,,.,,,.,.,...,...,.,,,..,,.,.,..,,..,,
#GF2XIXEJCXIZVQFO7JSLBJZUYBQNB2PXVROWCVF2SGL46PIDOB7N3S73J5TY2NNWQVA3VMQILHRLC
#\\\|EQ5JJTE3JISEB3JQZUU637W3BZI64SALLHZ2YUUEEYVUNN24E3W \ / AMOS7 \ YOURUM ::
#\[7]WXGBRWHCQYQDFFY7YT4PQAZN3NEZVKHHGRYTC5DPJFEZVYIV3YAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

---

## Appendix: Streaming Checksum Modes for Large Files

### Problem: Unknown Full Checksum

When receiving large streams (network uploads, live recordings), the final checksum isn't known until the stream ends. Traditional approaches either:
- Buffer entirely in memory (resource intensive)
- Write to temp file, checksum at end (latency)
- Use placeholder names, rename at end (complexity)

### Solution: Incremental Block Addressing

**BMW checksum continuation** allows resuming from intermediate state:

```perl
## BMW supports incremental hashing
my $bmw_state = BMW->new;

while (my $chunk = read_stream()) {
    $bmw_state->add($chunk);

    ## Current checksum represents all data so far
    my $current_checksum = $bmw_state->hexdigest;

    ## Write 63K block with current cumulative checksum
    write_block($chunk, $current_checksum);

    ## Rename file to reflect current state
    rename_file($path, $current_checksum, $total_bytes);
}
```

### Block Structure

**63K Base Blocks** (configurable):

```
┌─────────────────────────────────────────────────────────┐
│  63KB Block Format                                      │
├─────────────────────────────────────────────────────────┤
│  Header (256 bytes):                                    │
│    - Block magic (4 bytes): 0x424D57 (BMW)              │
│    - Block type (1 byte): SINGLE | SPLIT | OVERLAP      │
│    - Sequence number (8 bytes)                          │
│    - Cumulative checksum (32 bytes)                     │
│    - Block size (4 bytes): actual data in block         │
│    - Flags (4 bytes): CONTINUES | TERMINAL | CHECKPOINT │
│                                                         │
│  Data (65024 bytes max):                                │
│    - Raw file data                                      │
│    - Or multiple file fragments with inline headers     │
│                                                         │
│  Footer (256 bytes):                                    │
│    - Block checksum (32 bytes)                          │
│    - Padding/reserved                                   │
└─────────────────────────────────────────────────────────┘
```

### Write Modes

#### Mode 1: Single-Contained Single-Segment
```
Block N: [File A: bytes 0-63999]     ← complete file fits
Block N+1: [File B: bytes 0-63999]   ← next file
```
Simplest mode - one file per block, no fragmentation.

#### Mode 2: Split-Contained
```
Block N: [File A: bytes 0-63999]
Block N+1: [File A: bytes 64000-127999]  ← continuation
Block N+2: [File B: bytes 0-63999]       ← new file starts
```
Large files span multiple blocks. Each block has cumulative checksum.

#### Mode 3: Split-Overlap
```
Block N: [File A: end-1KB][File B: start-62KB]
Block N+1: [File B: continuation]
```
File boundaries overlap within block - useful for small files, ensures atomicity.

### Hierarchical Aggregation

**63K → 63M → 63G blocks**:

```
Level 0 (63K):  Raw data blocks
Level 1 (63M):  1024 x 63K block checksums
Level 2 (63G):  1024 x 63M block checksums
```

Merkle-tree-like structure allows:
- Verifying any 63K segment without full file checksum
- Resuming interrupted transfers at 63K boundaries
- Parallel verification

### Filename Convention

**Atomic rename pattern**:
```
Writing:   .tmp.<partial_checksum>.<offset>
Complete:  <final_checksum>-<total_bytes>.data
Append:    <prev_checksum>-<prev_bytes>.data → <new_checksum>-<new_bytes>.data
```

Example:
```
Uploading 500MB file...
.tmp.a3f7b2.0              (first 63K)
a3f7b2-65536.data          (renamed after checksum)
a3f7b2d9-131072.data       (after second block)
...
final9a2e-524288000.data   (complete)
```

### Cross-Node Continuation

**Resuming on different node**:
```
Node A wrote: checksum X at offset Y
Node B receives: checksum X, offset Y, state Z
Node B: Continue BMW from state Z, verify X matches
Node B: Append new data, new checksum X'
```

BMW state is ~32 bytes - can be passed between nodes.

### Implementation Sketch

```perl
package AMOS7::Data::StreamWriter;

sub write_chunk {
    my ($self, $data_chunk) = @_;

    ## Add to BMW checksum
    $self->{'bmw_state'}->add($data_chunk);
    my $current_checksum = $self->{'bmw_state'}->hexdigest;

    ## Accumulate to 63K
    $self->{'buffer'} .= $data_chunk;

    ## Flush when buffer full
    if (length($self->{'buffer'}) >= 63*1024) {
        my $block = substr($self->{'buffer'}, 0, 63*1024);
        $self->{'buffer'} = substr($self->{'buffer'}, 63*1024);

        ## Write with current cumulative checksum
        $self->write_block($block, {
            'checksum' => $current_checksum,
            'offset'   => $self->{'total_written'},
            'flags'    => $self->{'is_complete'} ? 'TERMINAL' : 'CONTINUES',
        });

        ## Atomic rename to reflect state
        $self->rename_current_file($current_checksum, $self->{'total_written'});
    }

    $self->{'total_written'} += length($data_chunk);
    return $current_checksum;
}
```

### Benefits

1. **Always-consistent naming**: Filename reflects actual content
2. **Resumable transfers**: Continue from any 63K boundary
3. **Incremental verification**: Verify as you write, not at end
4. **Cross-node append**: BMW state portability
5. **No temp files**: Content-addressed from first byte
6. **Parallel writes**: Different 63M blocks in parallel

### Relation to Cubic Space

63K/63M block boundaries align with cubic topology:
- 63K blocks → individual cubic nodes
- 63M superblocks → 27-node neighborhoods
- Spatial position determines replica placement

#,,,.,.,,,.,.,,..,.,,,..,,,.,,,,.,...,...,,..,.,.,...,...,...,..,,..,,.,,,,..,
#7NUFN2TPSGNSBSCTMUUJCLYGLCT66MJAZUW5VSAN3QXN743QHVPPYZUUEZQUJ7BMOP373I7OE6QJE
#\\\|WG5YPAVMDD56IAGFMSKZ4RJ5TQFYQHNY4WBSZLQDWRS7B2A7NQN \ / AMOS7 \ YOURUM ::
#\[7]5DQBF4Y5RSQM77YGOIR3FPIN3YCAQ6WL4EQ6D2ETTCRCMQDZ5ABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

### 63K Convergence: Storage = Network

The 63K block size unifies storage and network layers:

```
┌─────────────────────────────────────────────────────────┐
│  STORAGE LAYER          │  NETWORK LAYER                 │
│  ─────────────          │  ─────────────                 │
│  63K content blocks     │  63K packets                   │
│  BMW checksum addressed │  Cubic topology routed         │
│  Merkle tree verified   │  Buffer-swapped at nodes       │
│                         │  Re-encrypted per hop          │
└─────────────────────────┴────────────────────────────────┘
                           │
                           ▼
              ┌──────────────────────┐
              │  ZERO-COPY TRANSFER  │
              │  Block on disk =     │
              │  Packet in flight    │
              └──────────────────────┘
```

**Buffer Swap Operations**:
- Storage layer writes 63K block → references buffer
- Network layer sends buffer → zero copy
- Router receives → swaps to local buffer pool
- Re-encrypts → forwards to next cubic hop

**Traffic Analysis Resistance**:
```
Standardized 63K size + entropy padding
    ↓
All packets identical size
    ↓
Cannot distinguish file types by size
    ↓
Re-encryption at each hop
    ↓
Cannot track flows by pattern
    ↓
Cubic routing in 3D space
    ↓
No source/destination correlation
```

**Context-Aware Optimization**:
- Hot paths: Keep buffers in 27-node neighborhood
- Cold data: Background migration, erasure coding
- Streaming: Direct block-to-packet mapping
- Batch: Aggregate 63K→63M superblocks

**Efficiency Benefits**:
- No size conversion overhead
- Memory-mapped buffers work for both storage and network
- CPU cache-friendly (63K fits in L2)
- DMA-friendly for hardware acceleration

This is **Layer 3D** - not just routing, but spatial positioning of data in truth-space, where storage and transmission become the same operation.

#,,,,,.,.,,,,,.,.,,..,,..,,,,,.,.,..,,.,.,,..,.,.,...,...,...,,,,,,,,,,.,,...,
#FK2KMKELQOP5FCLCEH4IKIFJFV5FYSRPG5VFPUT24JDQJ6WBNPHS6PF2QF6IP4N2ZZD2TO6L5XT4Y
#\\\|FPTWDEFFKO3QBA3ZJRF46ISKJ42BSMXYWTHFLVIPX5QJINHV6KX \ / AMOS7 \ YOURUM ::
#\[7]FGSPCCFE7TCFNSF4EHBSQHLRWU4JGZYX4TOLRSWGUVTC42WJSIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
