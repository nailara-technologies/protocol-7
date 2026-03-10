
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
base.indexcube.tint   ## resolve TYPE of current entry via %colors    ##
base.indexcube.color_mix  ## return all TYPE values at current ADDR_B32 ##
```

### Phase 4 : Serialization / Route Log Sync

Serialize `@INDEXCUBE` to the zenka key identity `log/` subdirectory
on each push — the in-memory stack and the on-disk route log stay in sync.
Deserialization on startup reconstructs stack from existing log entries.

### Phase 5 : Cross-Zenka Handoff Protocol

Standardize the handoff message format: when routing to another zenka,
send your current `@INDEXCUBE` state alongside the command, allowing the
receiving zenka to append your stack to theirs for full route continuity.

## Open Questions

- **Signing granularity**: sign each push individually, or sign the full
  stack state at each checkpoint? Individual signing is more tamper-evident;
  checkpoint signing is cheaper for deep stacks.
- **ADDR_B32 assignment**: who assigns cube coordinates to zenki? Options:
  derived from zenka identity key (deterministic), assigned at registration
  (registry-based), or self-selected with collision detection via AMOS7.
- **Stack depth limit**: unbounded is correct for routing but could accumulate
  for long-lived zenki. Periodic checkpointing + pruning needed for sessions
  lasting days/weeks.
- **Color mixing representation**: one P7REF per tint at a given coordinate,
  or a compound P7REF with multiple TYPE fields? Current parser expects one
  TYPE field — extension needed for mixing.

## Minimal Useful Starting Point

The simplest useful implementation: Phase 1 only. Every zenka initializes
`@INDEXCUBE[0]` with its own P7REF on startup. No push/pop yet, no signing.
Just the origin marker. This is already useful for:
- Identifying any zenka's cube coordinate
- Displaying zenka position in `list zenki` output
- Routing decisions based on tint category

Everything else can be layered on top of a populated `@INDEXCUBE[0]`.

#,,.,,,..,,,.,,,.,,,.,,..,,,.,,,,.,.,,,,.,,,.,,..,,.,,,.,..,.,,,,.,..,,...,..

#,,,.,,,.,,.,,,,.,...,...,...,,,.,,.,,,,.,.,,,..,,...,...,..,,...,.,,,,..,.,.,
#FWQOMGQ5R5JV6QPSCXMZCAHWQS62Q7Z7LDQKUUW3OJJYYKI7P3MZDLVLIRL2APK5IZWVWHSEG37R6
#\\\|BUCML4SNOEAD2HHJXRMPJYJ6TEGKKQYOUWXRUTZFSYEFN5KYAEG \ / AMOS7 \ YOURUM ::
#\[7]PMHER75KRO5YEM4V275FQMOHU3O6FA5MT6DKPXY4DMHWSBMQRWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
