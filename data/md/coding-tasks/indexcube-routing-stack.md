
 .:[  @INDEXCUBE : per-zenka routing stack and cube traversal  ]:.

## Core Design

Each zenka has one `@INDEXCUBE` (declared in `bin/Protocol-7` line 14).
It is a **1D array used as a routing stack** — the array index is hop depth,
each element is a P7REF encoding a full 4D cube coordinate:

```perl
our @INDEXCUBE;   ## declared alongside %code %data %keys %colors ##

@INDEXCUBE[0]  = 'MODEL:MBZAAII:ZRCGL5Q'    ## entry point          ##
@INDEXCUBE[1]  = 'CUBE:O6A7F7Q:CQGT4CA'     ## routed through cube  ##
@INDEXCUBE[2]  = 'CODING:XFIU53I:MLH5WYY'   ## current position     ##

push @INDEXCUBE, $p7ref;   ## descend into sub-cube / advance one hop ##
pop  @INDEXCUBE;           ## return to parent / unwind one hop        ##
```

**The cube is the namespace. The array is your traversal through it.**

## P7REF as 4D Coordinate

A P7REF `TYPE:CHKSUM7:ADDR_B32` encodes all four cube dimensions:

```
TYPE      →  tint / category  [ routing, storage, inference, ... ]
CHKSUM7   →  AMOS7 identity   [ 7-char collision-resistant ID    ]
ADDR_B32  →  spatial position  [ base32-encoded cube coordinate   ]
```

No separate coordinate struct needed — P7REFs already carry full 4D
addressing. Existing `decode_harmonized_refstr` parser handles them.

## Stack Properties

### Tamper-Evidence by Construction

Stack order IS the signed traversal proof. Each hop is signed at push time;
you cannot insert a hop into the middle without invalidating all subsequent
signatures. Array index = position in ordered proof chain, not just depth.

### Cross-Zenka Handoff

When a P7REF routes to another zenka, you append their entry point to your
stack — not a copy of their stack, a continuation of yours:

```perl
## local descent ##
push @INDEXCUBE, local_p7ref();

## cross-zenka handoff ##
push @INDEXCUBE, $foreign_zenka_entry_p7ref;
## TYPE field marks the domain transition ##
## full route remains one readable array   ##
```

The TYPE field at each element shows where domain transitions occurred.
Reordering any two hops breaks the signature chain — order is enforced
by the cryptographic structure, not by convention.

### Recursive Extension

When a coordinate needs sub-cube resolution, the P7REF value at that
position points to another zenka's @INDEXCUBE entry — recursive nesting
without changing the base structure. Sparse by default (undef = unvisited),
dense only where actually traversed.

## Stack Operations

```perl
## read current position ##
my $here = $INDEXCUBE[-1];

## read entry point ##
my $origin = $INDEXCUBE[0];

## route depth = tamper-evidence depth ##
my $depth = scalar @INDEXCUBE;

## unwind to previous hop ##
my $prev = pop @INDEXCUBE;

## reset to origin ##
@INDEXCUBE = ( $INDEXCUBE[0] );
```

## Relationship to %colors

`%colors` (also declared in `bin/Protocol-7`) is the tint registry —
named category → tint value. The TYPE field of each P7REF stack entry
looks up in `%colors` to resolve the service category at that hop:

```perl
## tint lookup for current position ##
my $tint = $colors{ $current_type } // 0;
```

Color mixing at a coordinate = multiple TYPE entries with the same
ADDR_B32 but different CHKSUM7 — a coordinate serving multiple categories
has multiple P7REFs in the stack at the same depth, one per active tint.

## Cube Coordinate Conventions

```
ADDR_B32 encodes (X, Y, Z) as three bytes:
  X = axis 0  [ 0..255 ]  spatial
  Y = axis 1  [ 0..255 ]  spatial
  Z = axis 2  [ 0..255 ]  spatial

TYPE selects the tint layer (service category)
Stack index selects the traversal depth (hop count)
```

Scale: the node/container boundary = 1.0. Stack entries below that are
intra-process; entries above are network hops. The scale transition is
marked by TYPE changing from an internal category to a routable zenka name.

## Connection to Existing Infrastructure

- **P7REF format**: `decode_harmonized_refstr` in `base.parser.decode_harmonized_refstr`
  already parses `TYPE:CHKSUM7:ADDR_B32` — no new parser needed
- **AMOS7 checksums**: CHKSUM7 generated via `AMOS7::CHKSUM` — already present
- **Route log**: the `log/` subdirectory in zenka key identity task is the
  on-disk serialization of `@INDEXCUBE` — same structure, different medium
- **multicast sharding**: ADDR_B32 first byte = multicast group discriminator
  — the cube coordinate already encodes group membership
- **discover/nodes zenki**: ADDR_B32 spatial component maps onto the host
  presence table the nodes zenka already maintains

## Implementation Phases

### Phase 1 : Entry Point Initialization

On zenka startup, push the zenka's own P7REF as `@INDEXCUBE[0]`:

```perl
## in zenka init_code, after session acquired ##
push @INDEXCUBE, <[base.p7ref.self]>->();
## base.p7ref.self: constructs TYPE:CHKSUM7:ADDR_B32 from zenka identity ##
```

This gives every zenka a populated `@INDEXCUBE[0]` from birth — the
minimal useful state. All other operations build on this.

### Phase 2 : Push/Pop Routing Primitives

```
base.indexcube.push   ## sign and push a P7REF onto the stack        ##
base.indexcube.pop    ## pop and verify signature of top entry        ##
base.indexcube.here   ## return current position P7REF ($stack[-1])   ##
base.indexcube.depth  ## return tamper-evidence depth (scalar @stack)  ##
base.indexcube.reset  ## unwind to origin (keep [0], discard rest)    ##
```

### Phase 3 : Tint Resolution

```
base.indexcube.tint       ## resolve TYPE of current entry via %colors         ##
base.indexcube.color_mix  ## return all TYPE values at current depth            ##
base.indexcube.neighbors  ## N nearest zenki by ADDR_B32 manhattan distance    ##
base.indexcube.distance   ## spatial distance between two ADDR_B32 coordinates ##
```

### Phase 4 : Serialization / Route Log Sync

Serialize `@INDEXCUBE` to the zenka key identity `log/` subdirectory
on each push — the in-memory stack and the on-disk route log stay in sync.
Deserialization on startup reconstructs stack from existing log entries.

### Phase 5 : Cross-Zenka Handoff Protocol

Standardize the handoff message format: when routing to another zenka,
send your current `@INDEXCUBE` state alongside the command, allowing the
receiving zenka to append your stack to theirs for full route continuity.

## Design Decisions (resolved)

### Signing Granularity — Hybrid

Sign every push individually AND support checkpoint compression:

```
n signed pushes  →  one summary signature (compressed form)
verification accepts either granular or compressed form
```

Storage pressure triggers compression; cryptographic strength is preserved
either way. Granular form is the default; compressed form is an optimization
applied retrospectively, never during active routing.

### ADDR_B32 Assignment — Deterministic from Identity Key

```perl
## no registry, no collision detection needed ##
$addr_b32 = amos7_chksum( $zenka_pubkey )[0..5];   ## first 6 chars of AMOS7 ##
```

The cube coordinate is derived, not assigned. Same pubkey always produces
the same coordinate. Spatial position is cryptographically bound to identity
— you cannot claim a coordinate without the matching key.

This also connects to the zenka key identity infrastructure: the pubkey IS
the task directory name; the ADDR_B32 IS the cube coordinate. Both derived
from the same key material, the cube addressing and the key hierarchy are
the same structure viewed at different layers.

### Color Mixing — Array of P7REFs at One Depth

Multiple tints at the same depth = array of P7REFs at that stack position:

```perl
## single tint (common case) ##
@INDEXCUBE[2] = 'MODEL:MBZAAII:ZRCGL5Q';

## color mixing (multiple categories at same coordinate) ##
@INDEXCUBE[2] = [ 'MODEL:ABC123:XYZ789', 'CODE:DEF456:UVW012' ];
```

No parser changes needed — existing P7REF handling wraps in arrayref check.
`base.indexcube.color_mix` returns the full list; `base.indexcube.tint`
returns the primary (first) TYPE. Color mixing is opt-in at each depth.

### Cube Neighborhood Queries

ADDR_B32 decoded to 3-byte coordinate enables spatial proximity without
network broadcast — compare decoded byte values directly:

```perl
## manhattan distance between two cube coordinates ##
$dist = abs($ax - $bx) + abs($ay - $by) + abs($az - $bz);

## find N nearest zenki from nodes zenka presence table ##
base.indexcube.neighbors( $addr_b32, $n )
```

Useful for locality-aware routing: prefer nearby zenki (same LAN segment
sharing a /16 prefix = same cube plane) before going to distant hops.
Connects to the discover/nodes zenka infrastructure already tracking
host presence — neighborhood queries add a spatial filter to the existing
presence table.

## Dual Reading : Routing Stack AND Compression Index

`@INDEXCUBE` has two consistent readings sharing the same structural property:
**position encodes importance**.

```
routing reading      : position = hop depth, value = cube coordinate
compression reading  : position = frequency rank, value = element reference
```

Both are valid simultaneously. @INDEXCUBE[0] = parent/root/origin in both.

### Inverse-Occurrence Sorted Deduplication Index

Elements sorted by descending usage frequency — the position in the array
IS the compression coefficient:

```
@INDEXCUBE[0]   =  parent reference         [ FALSE=0, the whole/undifferentiated ]
@INDEXCUBE[1]   =  TRUE/FALSE group         [ the fundamental binary distinction   ]
@INDEXCUBE[2]   =  first content element    [ UNKNOWN=2, highest refcount, base32  ]
...
@INDEXCUBE[N]   =  Nth ranked element       [ longer address = rarer               ]
```

The existing base32 charset `[2-9A-Z]` excludes 0 and 1 for exactly this
reason — the content alphabet begins where UNKNOWN begins. Every AMOS7
checksum is already an element reference in this index, starting at position
2 by construction. The three AMOS7 constants mark the three structural layers:

```
FALSE   = 0  →  parent reference     [ root, excluded from base32 ]
UNKNOWN = 2  →  first content slot   [ start of base32 alphabet   ]
TRUE    = 5  →  resolved/confirmed   [ within base32 range        ]
```

UNKNOWN = 2 is the right constant for the first content position: the element
being resolved, the starting point of discrimination before TRUE/FALSE is
determined. The charset boundary was encoding the index structure all along.

Address length = log2(N) bits to encode position N. High-frequency elements
cost fewer bits to reference — implicit Huffman coding without pre-calculation.
The code lengths emerge from live usage rather than a computed tree.

### Natural Element Hierarchy

The frequency sort produces the linguistic hierarchy without explicit
categorization — statistics discover the structure:

```
rank 1..~52       →  single characters    [ alphabet — always most frequent ]
rank ~53..~400    →  common syllables     [ phonetic units emerge naturally  ]
rank ~400..~15k   →  words
rank ~15k+        →  phrases, paragraphs
```

Phonetic syllables appear between characters and words in the frequency
ordering because they ARE statistically between characters and words —
no explicit phonetic analysis required. The index discovers phonology.

### Implicit Compression via Address Length

Referencing an element is stating its rank. Rank 1 costs ~1 bit; rank
65536 costs 16 bits. The address space self-compresses: the most-used
content occupies the shortest addresses, least-used the longest.

This is equivalent to a Huffman code where:
- The code book is the sorted @INDEXCUBE array
- The code lengths emerge from refcount-driven rank, not pre-computation
- The code book updates continuously as usage patterns shift

### Distributed Caching via Refcount Gradient

No explicit cache eviction policy needed — the refcount gradient drives
distribution automatically:

```
high local refcount  →  short address → many nodes cache it
                     →  pulled toward local @INDEXCUBE (stays in memory)

low local refcount   →  longer address → fewer local references
                     →  drifts toward nodes where it IS frequently referenced
                     →  cube coordinate proximity drives the drift direction
```

Elements migrate to the cube region where they're most needed. The tint
layer marks element type (character / syllable / word / phrase = tint value),
so neighborhood queries find semantically similar content at nearby coordinates.

### Connection to Routing Stack

The routing stack traversal and the content index inhabit the same coordinate
space — navigating toward a destination is simultaneously navigating through
the frequency-ranked content space. A packet routed to cube coordinate X
passes through content cached at intermediate coordinates ranked by their
frequency in traffic toward X.

The @INDEXCUBE[0] parent reference unifies both readings: in routing it is
the origin of the traversal; in the compression index it is the root of the
element hierarchy. The same slot, the same value, two coherent purposes.

## Remaining Open Question

- **Stack depth limit**: unbounded is correct for routing but accumulates
  for long-lived zenki. Periodic checkpoint compression (see above) handles
  storage; a maximum uncompressed depth (e.g. 64 hops) before forced
  compression is a reasonable operational bound.

## Minimal Useful Starting Point

The simplest useful implementation: Phase 1 only. Every zenka initializes
`@INDEXCUBE[0]` with its own P7REF on startup. No push/pop yet, no signing.
Just the origin marker. This is already useful for:
- Identifying any zenka's cube coordinate
- Displaying zenka position in `list zenki` output
- Routing decisions based on tint category

Everything else can be layered on top of a populated `@INDEXCUBE[0]`.

#,,,,,,.,,.,,,.,,,.,,,...,.,,,,..,,,,,,,.,,,,,..,,...,...,.,.,,,.,.,,,,,,,,,,,
#KDEE4IYZJGPYURS3MWXGOHPIXV2IZ62WTC6B7HFB762L2WL7NSHESWRFK6UNASLDZAUKP6QJIUIY6
#\\\|KZ6FBN2J6ITAQFRIDQDHXSFFESP6M4LBFFYKANYCI5TKKMSNWMC \ / AMOS7 \ YOURUM ::
#\[7]2PSE4KJQCJA6SR3SRNSJW5UVGRPNJJV7EXSX7J6Q6U3XSRD5H2CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
