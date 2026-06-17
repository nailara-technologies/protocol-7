## [:< ##

# task: index zenka — schema v3 cube storage format

define the binary file format for the `.zxpc` (index cube) schema v3 file.
this is the on-disk representation of the ring-trie geometry: the address
IS the navigation path, and compartment location is pure arithmetic.

design reference: `data/md/design/INDEX-CUBE-STORAGE.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

---

## file layout

```
[ 256-byte header ]
[ compartment directory ]
[ compartment data ]
```

all three regions are within a single file, mmap'd as one contiguous region.
the OS page cache handles residency. zenka startup cost is reduced to
`mmap()` plus validation of the header checksum — no deserialization of trie
content occurs until a query demands it.

---

## header (256 bytes)

fixed-size, self-describing gate structure.

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
[ padding to 256 bytes total ]
```

the `header_checksum` uses the self-delimiting format: `0 + size + AMOS7_value`.
it is a 00-type token — data domain, basic integrity. the header is the 0 of
the file: the invariant center that the rest of the structure rotates around.

---

## directory entry structure

the directory is a dense array of fixed-size entries per ring. for ring D,
entry R is at:

```
offset = dir_base[D] + R * dir_stride[D]
```

this is pure arithmetic — no b-tree, no hash table, no pointer chase.

each directory entry contains:

```
data_offset           : uint64   [ file offset of compartment payload ]
data_size             : uint32   [ payload size in bytes ]
child_count           : uint16   [ number of children, for cache pre-warming ]
flags                 : uint16   [ loaded, verified, error-state bits ]
compartment_chksum7   : 8 bytes  [ AMOS7 identity of this compartment ]
```

`dir_base[D]` must be aligned to a 16-byte boundary. the fixed-size entry
and aligned base enable the `(depth, rank)` → file_offset mapping to collapse
to a bit-shift and add, compatible with 19-bit border addressing from the
context-tree routing layer.

---

## compartment payload layout

each compartment is one node's data — the state for a single prefix at its
ring depth.

```
[ compartment checksum  : self-delimiting AMOS7 token (1D frame) ]
[ payload               : serialized node data ]
```

the checksum frame validates the payload bytes. on mismatch, the compartment
is marked invalid and skipped; the rest of the index continues to operate.

the payload contains:

```
terminal_flag      : uint8    [ 1 if this prefix is a complete token ]
frequency          : uint32   [ corpus frequency of this exact sequence ]
parent_chksum7     : 8 bytes  [ AMOS7 of parent compartment at depth D-1 ]
child_count        : uint16
[ child entries, sorted by rank descending ]:
    char_code      : uint32   [ unicode codepoint ]
    child_rank     : uint32   [ rank in next ring ]
```

for depth-0 compartments, `parent_chksum7` is the header checksum — the root
of the tamper-evidence chain.

this is a flat binary encoding: compact, alignment-friendly, and parses in a
single pass. for migration compatibility, compartments may optionally use
storable serialization with a format-tag in the flags field. new compartments
are written as flat binary; legacy compartments read as storable until rewritten.

---

## p7ref connection

every compartment is addressable as a p7ref without translation:

```
TYPE      : implicit 'P7IC' (from file magic)
CHKSUM7   : compartment_chksum7 (from directory entry)
ADDR_B32  : (depth, rank) arithmetic
```

external references to compartments need no translation layer — the same
string addresses a route in `@INDEXCUBE` and a compartment on disk. the
directory IS the index, and the index IS the directory.

---

## notes

- forward-extensible: new payload fields are appended with a version tag;
  older readers skip unknown trailing bytes. the self-delimiting checksum at
  the compartment head ensures older readers still know the payload boundary.
- void compartments: a directory entry with `data_size == 0` is a void — no
  corpus entry reaches this address. this is the natural sparsity of the ring
  geometry expressed on disk.
- the 19-bit addressing constraint: with `dir_stride` constrained to a power
  of two and `dir_base` aligned, the offset computation collapses to a single
  bit-shift and add. a ring with up to 8192 entries (13 bits) and a stride of
  16 bytes uses exactly 17 bits for its span; with a 6-bit depth selector, the
  full compartment address fits in 19 bits.

#,,..,,..,,,,,,,,,...,,,,,,..,,..,.,.,...,,,.,..,,...,...,.,.,.,,,.,,,,..,,,,,
#Q5XSPYFYCW5P2TV7VI5LX5AX2TPIV24GHWDKYDC3U4M2RHLSZQUKZT2G5V574PXIBSFC4IUVGB2G6
#\\\|JBDI74UAVPFEERDKJUKSPJMAGXYNUFJCNYK7YO2T3YI5XACJYOK \ / AMOS7 \ YOURUM ::
#\[7]GSOPEA7GZCULQHZJH2DPCBAKBOTNKIWOSGSJR4CINCLZGVGWIEBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
