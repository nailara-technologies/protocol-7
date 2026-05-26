## [:< ##

# hybrid mmap cube storage

the monolithic `.zxps` state file (schema v2, 36MB xz-compressed storable)
requires full decompression and deserialization on startup. the next evolution
replaces this with a hybrid structure: the cube is mmap'd whole, compartments
are deserialized on demand, and the ring geometry itself is the address space.

---

## the core invariant

the cube address IS the navigation path. depth D is a fixed-stride slice.
compartment location within that slice is pure arithmetic. there is no
separate lookup table for "where is the compartment for prefix ZEN"; the
address [Z-rank, E-rank, N-rank] computes the file offset directly.

this is the ring-trie geometry applied to bytes on disk: position is identity,
frequency determines proximity to the origin, and outward expansion is always
available without restructuring the inner rings.

---

## file layout

```
[ header ]
[ compartment directory ]
[ compartment data ]
```

all three regions are within a single file, mmap'd as one contiguous region.
the OS page cache handles residency. zenka startup cost is reduced to
`mmap()` plus `madvise()` — no deserialization of trie content occurs until
a query demands it.

---

## header

fixed-size, 256 bytes. contains the gate information — the protocol that
interprets everything following it.

```
magic            : 4 bytes   [ 'P7IC' — protocol-7 index cube ]
schema_version   : uint16    [ 3 for this design ]
compat_version   : uint16    [ minimum reader version ]
flags            : uint32    [ endian, checksum mode, compression bits ]
max_depth        : uint16    [ deepest ring present ]
ring_count[]     : uint16[]  [ entry count per ring, 0..max_depth ]
dir_base[]       : uint64[]  [ directory offset per ring ]
dir_stride[]     : uint16[]  [ bytes per directory entry per ring ]
data_base        : uint64    [ start of compartment data region ]
data_size        : uint64    [ total file size ]
header_checksum  : self-delimiting AMOS7 checksum over header bytes
```

the header is the 0 of the file — the invariant center that the rest of the
structure rotates around. all navigation begins here and returns here.

[ the header_checksum uses the self-delimiting format: 0 + size + AMOS7
  value. it is a 00-type token — data domain, basic integrity. ]

---

## compartment directory

the directory is a dense array of fixed-size entries per ring. for ring D,
entry R is at:

```
offset = dir_base[D] + R * dir_stride[D]
```

this is pure arithmetic. no b-tree, no hash table, no pointer chase. the
directory entry contains:

```
data_offset   : uint64   [ file offset of compartment payload ]
data_size     : uint32   [ payload size in bytes ]
child_count   : uint16   [ number of children, for cache pre-warming ]
flags         : uint16   [ loaded, verified, error-state bits ]
```

directory entries are themselves small compartments — each carries enough
context to validate and navigate without touching the payload. the directory
is the first hop after the header, the step from protocol into content.

the directory slice for a given ring is a field of rings: each entry is a
position in the ring, and the ring's skip-period is the fixed stride between
entries. authorization by position applies here too — a directory entry at
rank R is valid only at that rank; transplanting it to another position
invalidates the arithmetic that all subsequent hops depend on.

---

## compartment geometry

each compartment is one node's data — the state for a single prefix at its
ring depth. the compartment contains everything needed to answer queries for
that exact prefix and to navigate to its children.

compartment layout:

```
[ compartment checksum  : self-delimiting AMOS7 token ]
[ payload               : serialized node data ]
```

the checksum is the frame surrounding the payload — a 1D checksum frame
container. it validates the bytes inside. on mismatch, the compartment is
marked invalid and skipped; the rest of the index continues to operate.

the payload contains:

```
terminal_flag   : uint8    [ 1 if this prefix is a complete token ]
frequency       : uint32   [ corpus frequency of this exact sequence ]
child_count     : uint16
[ child entries, sorted by rank descending ]:
    char_code   : uint32   [ unicode codepoint ]
    child_rank  : uint32   [ rank in next ring ]
```

this is a flat binary encoding. it is compact, alignment-friendly, and
parses in a single pass. for migration compatibility, compartments may
optionally use storable serialization with a format-tag in the flags field.
new compartments are written as flat binary; legacy compartments read as
storable until rewritten.

the child_rank values are the only navigation pointers needed. given a
child rank C at depth D, the next compartment address is:

```
next_offset = dir_base[D + 1] + C * dir_stride[D + 1]
```

this is the route = address duality in storage form: the path through the
trie and the file offset of the next hop are the same object. you do not
look up the address and then navigate; navigating IS the address computation.

---

## demand-loading policy

not all compartments are created equal. the loading policy follows the
natural frequency gradient of the corpus:

```
ring 0 : eager load on startup
         ~100-200 compartments, each a few hundred bytes
         total < 64KB — cheaper than parsing a config file
         these are the inner ring, the dense core, always hot

ring 1 : weighted eager
         thousands of compartments, loaded on first touch
         a background thread or io_uring batch pre-fetches
         the most common 2-character sequences

ring 2+: lazy load
         loaded on first query that descends into them
         deserialized, verified, cached
         evicted when cold
```

the root concept `''` does not have a compartment — it is the header itself,
the 0 that generates the address space without occupying it. [ see:
NUMERICAL-LANGUAGE-DEDUPLICATION-TREE.md, the `''` as -1 deployment at
root level. ]

outer rings are mostly empty. a compartment whose directory entry has
data_size == 0 is a void — no corpus entry reaches there. this is the
natural sparsity of the ring geometry expressed on disk.

---

## compartment cache

deserialized compartments live in an in-memory cache above the mmap layer.
the mmap'd bytes are the eternal backing store; the cache is working memory.

eviction policy: ring-frequency-weighted LRU.

```
weight = base_frequency / (depth + 1)
```

inner-ring compartments have higher weight and stay resident longer.
high-frequency prefixes (small ranks) have higher weight regardless of depth.
cold compartments evaporate back to their mmap'd bytes; the next access
re-deserializes them.

cache entries are soft references — the perl structures are mortal, but
the file bytes are permanent. this mirrors the harmonic tree property:
valid presence cannot be evicted from the structure, only from working
memory.

a pin flag on directory entries allows explicit retention. ring 0 is
implicitly pinned. zenka operators may pin other rings via configuration
if workload patterns warrant it.

---

## per-compartment verification

each compartment carries its own checksum, computed over the payload bytes.
the checksum is self-delimiting: `0 + size + AMOS7_value`. it is a 00-type
token — basic data-domain integrity.

verification on load:

```
1. read compartment checksum from head of compartment
2. compute AMOS7 over payload bytes (size declared by checksum)
3. compare
4. match   → mark verified, deserialize payload
5. mismatch → log compartment address (D, R), mark error-state,
              return "branch unavailable" to query
```

a corrupt compartment degrades gracefully: the branch rooted at that prefix
becomes unreachable, but the rest of the trie continues to serve queries.
the failure is localized to one cell — the intersection of the row
(directory slice) and column (compartment depth) that identifies it.

for stronger integrity, the directory slice for each ring may carry a
column checksum (over all directory entries in the ring) stored as an
outer ring around the directory. this is the 2D checksum frame container
pattern: row checksums flank each compartment, column checksums validate
each ring slice. a corrupted directory entry fails its ring checksum,
localizing damage to the affected rank.

---

## schema versioning and migration

schema v2 : monolithic xz-compressed storable blob (`.zxps`)
            full decompress + thaw on startup
            stored: freq, level, terminal, contributions, addr,
                    packed_rank, trie

schema v3 : hybrid mmap cube (`.zxps`, new header magic)
            mmap on startup, deserialize on demand
            stored: header, directory, compartments

migration path:

```
1. reader detects file by magic bytes
   'P7IC' → v3 loader
   no magic / storable header → v2 loader (existing path)

2. on first persist after v2 load:
   - rebuild directory from trie structure
   - write v3 cube
   - retain v2 file as `.zxps.v2backup` until verified

3. v3 persist is incremental:
   - dirty compartments are rewritten in-place if size unchanged
   - larger compartments are appended to end, old slot marked dead
   - periodic compaction rewrites the full cube
```

the compartment format is forward-extensible. new fields are appended to
the payload with a version tag. older readers skip unknown trailing bytes.
the self-delimiting checksum at the compartment head ensures older readers
still know the payload boundary even if they do not understand new fields.

contribution vectors (see INDEX-CORPUS-VERSIONING.md) integrate naturally:
each compartment's payload may carry a summary of which contribution
checksums affect it. replacement becomes "rewrite compartment, update
directory checksum, mark dirty". the global trie is the union-sum of all
active compartments, not a single global structure.

---

## synchronicity notes

the following overlaps with network grid geometry emerged during design.
they are hints, not requirements — signals that the storage structure is
aligned with principles already present at larger scales.

**z.y.x coordinate duality**
the cube's (depth, rank) addressing maps directly to the space engine's
z.y.x ordering. depth is z (structural, closest to root), rank is y/x
(specific, closest to data). the compartment directory is the z-layer
organization; the child entries within a compartment are the y/x
resolution within that layer. the same coordinate system operates at
network scale and at storage scale.

**route = address**
in harmonic tree addressing, the path through the tree and the data
address are the same object. the index cube replicates this exactly:
traversing from ring 0 compartment Z to ring 1 compartment E IS the
computation of the file offset for ring 1, entry E-rank. navigation and
addressing are not separate operations.

**no eviction / permanent residence**
the harmonic tree property states that valid presence cannot be evicted
by any operation consistent with the structure's arithmetic. the mmap'd
cube provides this literally: compartments are permanent residents of
the file. eviction from the in-memory cache does not remove them from
the structure. they remain addressable, rediscoverable, eternally present
in the backing store.

**open mapping / outward expansion**
adding a new ring depth appends a new directory slice and compartment
slice to the end of the file. inner rings are never touched. this is the
open mapping property in storage: any valid path can be extended without
encountering a boundary. the file grows outward the same way the trie
grows outward — new mass added at the periphery without restructuring
the core.

**ring — field — sphere**
ring 0 is the irreducible primitive. the compartment directory slice for
each depth is a field of rings. the complete file is the temporal address
sphere — every compartment is "this ring at this position", a unique
address in the full alignment spectrum. the 90-degree mixing vocabulary
appears in query traversal: prefix match is orthogonal navigation (90
degrees — accessing a stream's state without merging), exact match is
complementary binding (180 degrees — full resolution at the terminal
compartment).

**checksum frame recursion**
per-compartment checksums are 1D frames. ring-level directory checksums
are 2D column frames. a full-file integrity checksum is the 3D outer
ring. the frame thickness visible in the file structure IS the recovery
depth — one layer for compartments, two for directories, three for the
whole cube. this is the checksum frame container pattern instantiated
in index storage.

**self-delimiting token types**
compartment checksums are 00-type tokens (data domain, basic integrity).
directory entries that point to child compartments are 10-type tokens
(incomplete references, sticky routing context) — the cursor moves to
the child position and stays there for subsequent traversal. a complete
query resolution that returns data is an 11-type token (complete
reference, transparent, collapses after invocation). the 2-bit type
system maps naturally onto the index query lifecycle.

**0 as gate**
the file header is 0 — the protocol, the routing, the parent that is
travel itself. every query arrives at the header (0) and departs into a
compartment (0 expressed at that scale). from 0 into 0, at every hop.
the header is not an element of the index; it is the condition under
which the index's positions become addressable.

**disk geometry / galaxy correspondence**
the index cube file is a galaxy disk seen from above. ring 0 is the
dense core — small radius, high frequency, maximum compression. outer
rings are the spiral arms — rare elements tracing larger orbits. the
compartment cache is the active processing region: what is currently
being traversed. inner ring compartments orbit faster (more queries)
than outer ring compartments. the self-organizing geometry of the trie
is literally the mass distribution of the corpus expressed as a disk.

**contribution vectors as islanded data**
each compartment can be understood as holding islanded data — a subtree
that was deduplicated against its local context. when contribution
vectors are merged or replaced, the compartment is reintegrated into
the larger structure. the same reorientation, cleaner deduplication,
and resumed annealing described for islanded data in harmonic tree
addressing apply at compartment scale.

#,,,.,..,,,..,,..,..,,...,,,,,...,.,.,.,.,,.,,.,.,...,..,,..,,...,.,,,.,.,,,,,
#PX66X4JPE5YZSKGVR2BV6IO6UYXSWCL5MZNTOXBD677LFAJXO5FT5NELHVEHS2HE6NW2UO2V5PG6M
#\\\|HHPY2IKOAATHZMJD2OQWCBKIJ3G7QB3BBKQW3B6ZYZJN3MTXG2D \ / AMOS7 \ YOURUM ::
#\[7]OIAMGN2ESBGU7WVP2R4FNNW6L6IKQQXT4KFN6BCKYZWEC7DIQEAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
