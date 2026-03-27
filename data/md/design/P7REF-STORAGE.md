# P7REF - Unified Storage Reference System

> *Every storage location has a name. Every name is traversable.*

## Overview

P7REF is Protocol-7's unified addressing system for storage. It provides a single syntax to reference:
- Checksum-addressed content (AMOS7/BMW/SHA)
- 9P remote filesystems
- Local filesystem paths
- Nested mount chains
- AMOS7 segments

## P7REF Syntax

```
p7://<type>:<address>[@<authority>][|<segment>][?<query>]
```

### Components

| Component | Description | Example |
|-----------|-------------|---------|
| `type` | Reference type | `checksum`, `9p`, `path`, `segment`, `nested` |
| `address` | Type-specific address | `AMOS7ABC123`, `/mnt/c/file.txt` |
| `@authority` | Server/location | `@localhost:5640`, `@node2.example.com` |
| `\|segment\|` | AMOS7 segment | `\|files\|`, `\|downloads\|` |
| `?query` | Key=value parameters | `?ttl=3600&priority=high` |

## Reference Types

### checksum
Content-addressed reference by BMW/AMOS hash.

```
p7://checksum:AMOS7B32CHECKSUM123
p7://checksum:BMW224ABC|files|documents
p7://checksum:BMWL13ABC|indexcube|segment
```

**Available algorithms:**
- `bmw` - BMW-512 file checksum (default)
- `bmw-224` - BMW-224 Base32
- `bmw-512` - BMW-512 32-bit
- `bmw-L13` - BMW L13 string checksum (for @INDEXCUBE)
- `bmw-L13-b32` - BMW L13 Base32
- `amos` - AMOS checksum

### 9p
Remote 9P filesystem reference.

```
p7://9p:localhost:5640/mnt/c/Users/dev/Documents
p7://9p:host/mnt/data@192.168.1.100:5640
```

### path
Local filesystem path.

```
p7://path:/home/user/documents
p7://path:/data/storage|segment|archive
```

### segment
AMOS7 segment reference.

```
p7://segment:AMOS7|files|downloads|video
p7://segment:local|cache|hot
```

### nested
Nested mount chains.

```
p7://nested:9p:host/mnt[c7://checksum:hash]
p7://nested:path:/local[9p:remote/backup]
```

## CLI Usage

### Resolve P7REF
```bash
storage p7ref resolve p7://checksum:AMOS7ABC123
# Output: Type: checksum, Path: /storage/AMOS7/...

storage p7ref resolve p7://9p:localhost:5640/mnt/c/file.txt
# Output: Type: 9p, Authority: localhost:5640, Path: /mnt/c/file.txt
```

### Parse P7REF
```bash
storage p7ref parse p7://9p:host/path|segment|name
# Shows: Type, Address, Segments, Nested levels
```

### Index P7REF
```bash
storage p7ref index p7://checksum:ABC123 :type: document :priority: high
# Adds to searchable index with metadata
```

### Search P7REF
```bash
storage p7ref search :by: checksum :value: AMOS7ABC123
storage p7ref search :by: type :value: 9p
storage p7ref search :by: segment :value: downloads
```

## Nested Chains

P7REF supports arbitrary nesting:

```
p7://9p:gateway[P7://segment:AMOS7|files[9p:backend/storage]]
```

This represents:
1. Connect to 9P gateway
2. Access AMOS7 segment within gateway
3. Navigate to backend storage via 9P

## Parallel References

Multiple P7REFs can reference the same content:

```perl
# Same file, different access methods
my @refs = (
    'p7://checksum:AMOS7ABC123',
    'p7://path:/local/file.txt',
    'p7://9p:remote/mnt/file.txt',
);

# Search finds all references
my $result = <[plugin.storage.p7ref.search]>->({
    'by'    => 'checksum',
    'value' => 'AMOS7ABC123',
});
# Returns all 3 references above
```

## Integration with Storage Mapping

P7REF works seamlessly with storage mapping plugins:

```perl
# Map file to P7REF
my $map = <[plugin.storage.p7ref.resolve]>->({
    'p7ref' => 'p7://9p:localhost:5640/mnt/c/data.bin',
});

# Checksum plugin hashes the content
my $checksum = <[plugin.storage.checksum.map-file]>->({
    'path' => $map->{'data'}{'path'},
});

# Index both references as parallel
<[plugin.storage.p7ref.index]>->({
    'p7ref'    => 'p7://9p:localhost:5640/mnt/c/data.bin',
    'metadata' => { 'checksum' => $checksum->{'data'}{'checksum'} },
});

<[plugin.storage.p7ref.index]>->({
    'p7ref'    => "p7://checksum:$checksum->{'data'}{'checksum'}",
    'metadata' => { 'source' => '9p-localhost' },
});
```

## Filter and Sort

Search results can be filtered and sorted:

```bash
# Filter by metadata
storage p7ref search :by: type :value: 9p :filter:priority=high

# Sort by access time (implementation pending)
storage p7ref search :by: segment :value: hot :sort: last_access
```

## Future Extensions

### Temporal References
```
p7://checksum:ABC123@2024-03-27T10:00:00Z
```

### Query-Based
```
p7://search:?type=pdf&size>1MB&created>2024-01-01
```

### Multi-Hop Routing
```
p7://route:gateway1->gateway2->target/file.txt
```

### Conditional
```
p7://failover:primary[backup]|priority:high
```

## Architecture

```
P7REF Layer:
  - Parse: String -> Components
  - Resolve: Components -> Storage Location
  - Index: Track parallel references
  - Search: Find by any criteria

Type Handlers:
  - plugin.storage.p7ref.checksum -> plugin.storage.checksum
  - plugin.storage.p7ref.9p -> storage.9p
  - plugin.storage.p7ref.path -> local filesystem
  - plugin.storage.p7ref.segment -> AMOS7 segments
```

## Reloading

P7REF plugins reload with `reload plugins`:
```bash
cube reload plugins
```

This updates P7REF handling without affecting core storage operations.

---

*One ring to reference them all, one syntax to find them,*
*One namespace to bring them all, and in the vortex bind them.*

#,,..,.,,,.,.,,..,...,.,.,,.,,...,,..,.,.,,,,,..,,...,...,,.,,.,.,.,,,.,,,...,
#RFPA6IDRJMX2H73DUG2B3KHWF6L5OP7LSBSMM3CJIVQ7DB2ZVVFMJ3J7UERGVIYVZL4QPSXJFMM3M
#\\\|VTK3MGUD2DILODUVICU5IMQCZQKUB46BPEPNMAGMA5PVNKOT5CK \ / AMOS7 \ YOURUM ::
#\[7]LR354426VQAUJAFZ53YAHIS47XSVRNXONY35MDPYAJOW3PMPZSBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
