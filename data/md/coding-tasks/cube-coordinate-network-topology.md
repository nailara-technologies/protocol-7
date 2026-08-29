
 .:[  cube coordinate network topology and virtual address routing  ]:.

## Bijective Identity — Coordinate, Color, Integer

A 24-bit integer, an RGB color value, and a cube coordinate are the **same bit
pattern** with three different labels. No translation or encoding step exists —
only reinterpretation of identical bits:

```
0xRRGGBB   =  (R, G, B) cube coord  =  24-bit integer   [ same bits ]
0xRRGGBBAA =  (R, G, B, A) 4D coord =  32-bit integer   [ same bits ]
```

This is a recursive / reverse mapping depending on perspective:
- navigating the cube inward  →  you are reading a coordinate
- observing the same value as color  →  you are reading a pixel
- routing on a network  →  you are reading an address
- indexing a data structure  →  you are reading an integer key

The perspective determines the label; the bits are unchanged across all readings.

### Zero as Parent — Hierarchy Encoded in Value

The zero value is structurally the enclosing container:

```
0x000000   →  the whole cube  [ all addresses, no discrimination ]
0xFF0000   →  one point on axis X=255, Y=0, Z=0
0xFF0000.. →  any prefix with trailing zeros = a sub-cube at that resolution
```

No separate metadata describes the hierarchy — it is encoded in the value itself.
A prefix IS a sub-cube; a full value IS a point; zero IS the parent. The
containment structure falls directly out of the bit arithmetic.

### Hyperspace by Byte Concatenation

Each 8-bit chunk is one fully independent dimension. Stacking dimensions =
concatenating bytes:

```
 8 bits  →  1D line       [ 256 positions ]
16 bits  →  2D plane      [ 256^2 positions ]
24 bits  →  3D cube       [ 256^3 positions ]  ← RGB, 10.A.B.C
32 bits  →  4D hypercube  [ 256^4 positions ]  ← RGBA, (X,Y,Z,tint)
64 bits  →  8D hyperspace [ 256^8 positions ]
```

Each appended byte adds one full dimension of 256 positions. The structure is
self-similar at every scale: an 8-bit value navigates one axis of the cube the
same way a 24-bit value navigates all three — the operations are identical, the
scope differs only in dimensionality.

An 8-bit value can also address a **single bit position** within the cube: its
8 bits independently select one of 256 slots on one axis, each bit addressable
separately within that slot. These are already hyperspace mappings — the cube
is the 3D cross-section of a structure that extends naturally in both directions,
inward to single bits and outward to arbitrary dimension counts.

## Quadrant Mapping — Lower Resolution onto Higher Resolution

Mapping a lower-resolution cube value onto a higher-resolution cube is **quadrant
mapping** — the lower-res coordinate selects a region (quadrant, octant, sub-cube)
within the higher-res space:

```
1 bit   →  halves the cube     [ 2 regions ]
2 bits  →  quadrants           [ 4 regions ]
3 bits  →  octants             [ 8 regions ]
n bits  →  2^n sub-cubes       [ each a full cube at reduced scale ]
```

A low-resolution cube coordinate IS a quadrant selector in the full-resolution
cube. Zooming in replaces the quadrant label with a finer coordinate; zooming out
collapses a sub-cube back to its quadrant label. The scale invariance discussed
earlier is exactly this quadrant relationship applied recursively.

### Base32 — The 5-Bit Bridge

Base32 is 5-bit encoded: each character represents exactly 5 bits, from a
32-symbol alphabet (2^5 = 32). This makes it a natural bridge between human-
readable symbols and binary cube coordinates:

```
1 base32 char  =  5 bits   →  32 positions  ( half an axis )
2 base32 chars =  10 bits  →  1024 positions ( one full byte + 2 bits overhead )
```

Two base32 characters contain one full 8-bit value — the minimal base32 unit
that fully covers one cube axis (0–255). The 2 spare bits are the rounding
overhead from 5→8 bit boundary crossing, but the coverage is exact: any byte
value fits within 2 base32 chars. This is precisely the multicast group
discriminator sizing from earlier: 2 base32 chars = 1 byte = one cube axis.

The natural alignment point where base32 and binary fully synchronise is their
LCM:

```
LCM(5, 8) = 40 bits  =  8 base32 chars  =  5 bytes
```

40-bit blocks are the atomic unit where no padding is needed — 8 base32
characters encode exactly 5 bytes with zero waste. AMOS7 checksums already
operate in this space, which is why base32 AMOS7 values compose cleanly with
byte-aligned cube coordinates.

### Decimal Re-entry

The 5-bit / 8-bit boundary touches decimal with a holographic reading:

```
2^10  =  1024  =  1000 + 24
                    │       └── the 3D cube  ( 3 × 8 bits )
                    └────────── the decimal container  ( 10^3 )
```

1024 is not "1000 with a rounding error of 24" — it is **1000 carrying a color
of 24**. The decimal value and the cube dimension coexist in the same number
simultaneously, each a valid and complete reading. The 24-bit cube is embedded
in the decimal thousand as its tint, and the thousand is the human-scale
container for the cube. One number, two coherent interpretations, neither
approximate — holographic and clean.

### 1000 as Octal-Style Container

1000 itself reads as an existing protocol primitive — a 3-digit payload with a
1-digit container header, directly compatible with the octal header system:

```
1 | 000
│    └── 3-digit payload  ( 000 = zero payload )
└─────── container / overflow marker / delimiter
```

- **overflow detection**: the leading `1` signals that the 3-digit field has
  saturated or carries a flag — exactly the overflow bit in the octal header
- **first-bit inversion for zero payload**: `1|000` is the special case where
  the delimiter appears in the zero-payload position, matching the existing
  octal header convention that places a delimiter at `000` to distinguish it
  from absence of data
- **3-bit payload → 3 decimal digits**: the `000` maps to the 3-bit payload
  space; values 001–999 are direct payload; 000 with the leading 1 is the
  delimited zero case

The 24-bit color is stripped first — it carries the category or calculation
result — leaving the 1000 container to be parsed through the octal header
logic already present in the system. The full 1024 value then decomposes as:

```
1024  =  [ 24-bit cube color | 1000 container ]
          category / result     existing header primitive
```

No new protocol machinery needed — the cube color prefix and the octal
container format were already converging toward the same bit layout. 1024
is where they meet, and the meeting point was already defined.

## Core Observation

The 255×255×255 addressing cube keeps emerging independently across unrelated
subsystems — holographic packet headers, multicast namespace sharding, harmonic
topology, and now network address range mapping. This convergence is not
coincidental: one byte per axis is the minimal coordinate that fits a 3D spatial
identity into standard network primitives without overhead.

```
axis_A = 0x00 .. 0xFF   ## 1 byte
axis_B = 0x00 .. 0xFF   ## 1 byte
axis_C = 0x00 .. 0xFF   ## 1 byte
→ 16,777,216 unique points in 3D space, each addressable by 3 bytes
```

## IPv4 Private Range as Native Cube

The 10.x.x.x private range maps onto the cube with zero translation:

```
10 . A . B . C
     │   │   └── cube axis Z  (0–255)
     │   └────── cube axis Y  (0–255)
     └────────── cube axis X  (0–255)
```

- `10.0.0.0/8`    → full cube  [ galaxy ]
- `10.N.0.0/16`   → disc at X=N  [ galactic plane / spiral arm ]
- `10.N.M.0/24`   → line at X=N, Y=M  [ filament ]
- `10.N.M.P`      → single point  [ star / host ]

The galaxy-disc analogy is apt: a /16 at fixed X is a 256×256 plane — a spiral
disc when the point density follows the CCW routing matrix distribution.

## Holographic Packet Header Reading Modes

The same 3-byte field in a packet header is simultaneously valid as:

```
mode 0 [ cube coordinate ]  : spatial routing address
mode 1 [ IP octets ]        : 10.A.B.C network address
mode 2 [ multicast group ]  : 2-char base32 group + 1-byte sub-shard
mode 3 [ session fragment ] : partial session key for multiplexing
mode 4 [ CCW matrix index ] : row/col/depth in harmonic routing table
```

The reader selects the interpretation based on context — the bits are identical,
the reading mode is the only variable. This is the holographic property: one
encoding, multiple coherent decodings.

## Virtual Address Translator / Load Balancer

### Concept

Localhost-only services (TCP, Unix sockets) are assigned virtual 10.x.x.x
addresses. A translator layer maps these to Protocol-7 network coordinates and
routes them over the public mesh:

```
local service  →  virtual 10.A.B.C:PORT
                           │
                    cube coordinate (A,B,C)
                           │
                    P7 routing + spatial load balancing
                           │
                  any host in the cube at or near (A,B,C)
```

### Listen Socket Mapping

Backend opens a listen socket on a virtual address in the 10.x.x.x range.
The port number provides an additional degree of freedom:

```
port → session ID after connection
     → sub-coordinate within the cube point (fine-grain multiplexing)
     → service type discriminator (well-known port conventions extended)
```

After the listen socket is registered, incoming Protocol-7 packets addressed to
that cube coordinate are translated to localhost TCP connections — the backend
sees standard POSIX socket semantics, the network sees spatial routing.

### Source Address as Spatial Identity

Source addresses are not opaque — they ARE cube coordinates:

```
packet from 10.2.17.43  →  origin at (2, 17, 43) in cube space
packet to   10.5.30.11  →  destination at (5, 30, 11)
```

The translator computes the shortest path through the cube (Manhattan distance
or CCW geodesic), selects the nearest available host, and forwards — no separate
routing table needed. The address IS the routing decision.

### Load Balancing

Multiple backends registered at nearby cube coordinates share load by proximity:

```
request to (5, 30, 11)
  → (5, 30, 11) available?  → route there
  → else (5, 30, 12)?       → route there  [ adjacent Z ]
  → else (5, 29, 11)?       → route there  [ adjacent Y ]
  → ...
```

Geographic affinity: hosts physically colocated on a LAN can share a /24
(same X.Y prefix), making cube-proximity a proxy for network proximity.

### Flexible Translation Layer

The translator is not a single point of failure — it is a function, computable
by any zenka with the address mapping table:

```
translate(src_ip, dst_ip, port) → P7_route_params
```

Any zenka on the path can perform or verify translation. The cube coordinate
in the header carries enough information for any intermediate hop to recalculate
the correct forward path independently.

## Port as Fourth Dimension

Port number extends the 3D cube into a 4D addressing space for session
multiplexing:

```
(A, B, C, port) → unique session endpoint
```

Well-known port conventions can map service families to cube sub-regions:
- port 80/443 range → HTTP service layer at that coordinate
- port 4200 range   → Protocol-7 native services
- high ports        → ephemeral session handles

The virtual port space is private to the translator — external observers see
only cube coordinates and P7 session IDs.

## Connection to Existing Infrastructure

- **discover zenka**: already does multicast presence announcement; cube
  coordinate of a host = its address in the 10.x.x.x range it occupies
- **nodes zenka**: tracks announced hosts; gains cube coordinate column
  alongside existing host presence data — proximity queries become range queries
- **CCW routing matrix**: the 255×255×255 cube is the 3D extension of the CCW
  matrix already in the harmonic topology session; routing decisions ARE matrix
  multiplications
- **multicast namespace sharding**: 2-char base32 group (1 byte) = one cube axis;
  sharding group = disc in the cube at that axis value
- **data zenka FUSE mount**: filesystem paths under the FUSE mount can encode
  cube coordinates as path segments, making the 3D address space navigable as
  a directory tree
- **P7 binary**: `p7 <cube-addr>.<command>` becomes a valid invocation pattern
  once the translator layer maps cube addresses to routable zenka endpoints

## Prior Exploration

Earlier address-range / port-mapping experiments (pre-Protocol-7) established:

- Virtual address ranges assignable per service family without DHCP
- Port-to-session mapping after listen socket open — backend agnostic
- Localhost TCP tunneled over public mesh with source address preservation
- Translation as a pure function, distributable, no central state required

These experiments now have a formal geometric home: the cube. The topology was
always implicit in the address arithmetic; the cube makes it explicit and
unifies it with the routing, multicast, and holographic packet header work.

## The Fourth Dimension : Tint / Ambience Color

The 255×255×255 cube has a natural fourth dimension: the **tint** (or ambience
color) of each bit sub-cube position. Where the three spatial axes encode
location, the tint encodes category — what kind of content or service occupies
that coordinate.

```
(X, Y, Z, tint)  →  fully qualified cube address
```

### Tint as Address Prefix

Network prefixes are already tint values in disguise:

```
10.A.B.C    →  (A, B, C) at tint 'private-rfc1918-a'
172.16.A.B  →  (A, B, *)  at tint 'private-rfc1918-b'
192.168.A.B →  (A, B, *)  at tint 'private-rfc1918-c'
fc00::...   →  (...)       at tint 'private-rfc4193'
```

The prefix IS the tint — different address families and ranges are different
color families in the same spatial cube, occupying the same coordinate axes
without collision because the tint discriminates them.

### Color Mixing — Multiple Categories at One Coordinate

When multiple tint values are present at the same (X, Y, Z) coordinate, the
colors mix. Color mixing does not mean conflict — it means multiple bit
categories are simultaneously valid at that location:

```
(5, 30, 11) with tint {routing, storage, rfc1918-a}
  → routable as a network node
  → addressable as a storage location
  → reachable as a private IP endpoint
  → all simultaneously, same coordinate
```

A coordinate with a single tint is unambiguous. A coordinate with mixed tints
is a superposition — the reader selects the relevant tint layer for its purpose,
just as the holographic packet header reading modes select interpretation from
identical bits. Same coordinate, multiple coherent readings.

### Tint as Universal Category Layer

The tint dimension is not limited to network address families. Any categorical
distinction that needs to coexist at the same spatial coordinates without
collision is a tint value:

```
tint examples:
  network layer   →  routing, forwarding, multicast group membership
  service layer   →  http, storage, inference, key-exchange, time-sync
  data layer      →  file type (image, audio, code, structured data, key)
  index layer     →  search category, content hash prefix, mime type family
  access layer    →  public, authenticated, encrypted, signed, revoked
  state layer     →  available, busy, degraded, draining, offline
```

A file index and a routing table share the same coordinate space — the tint
distinguishes them. A node offering both HTTP and inference services occupies
the same (X, Y, Z) with two tint bits set. The coordinate system is the same
object viewed at different categorical layers simultaneously.

### Scale Invariance — Internal and External Addressing Unified

The cube coordinate system scales continuously from inside a process to across
a global network, with the node or container boundary representing the **1.0
scale point**:

```
scale < 1.0  [ inward ]   →  internal data structures, memory layout,
                               in-process service registry, local file index
scale = 1.0  [ boundary ] →  the node or container surface — where internal
                               addressing meets external routing
scale > 1.0  [ outward ]  →  LAN topology, WAN routing, inter-datacenter,
                               global mesh
```

The same (X, Y, Z, tint) tuple is valid at every scale. A data structure
inside a zenka process, a service registered on a local node, and a host in
the wider network all use the same coordinate vocabulary — only the scale
factor changes. Crossing the node boundary is a scale transition, not an
addressing system change.

This means internal and external addressing are **not two systems that must
be bridged** — they are the same system at different zoom levels. Distributed
data structures, local service discovery, and network routing topology are all
projections of the same cube, compatible and mutually navigable. A query that
starts inside a process can scale outward through the container boundary into
the network and back inward into another process without changing its
coordinate representation.

### Color Mixing — Multiple Categories at One Coordinate

Tint can be encoded compactly alongside the cube coordinate:

```
[ X:1 byte | Y:1 byte | Z:1 byte | tint:1 byte ]  →  4 bytes total
```

One tint byte = 256 categories, or used as a bitmask: 8 simultaneous category
flags per coordinate. Color mixing then corresponds to setting multiple bits in
the tint byte — popcount(tint) = number of active categories at that point.

For richer color spaces (RGB tint, HSL tint), 3 tint bytes map the cube's own
geometry onto its category axis — a cube of cubes, each point in the outer cube
having an inner cube of category space. The recursion is exact and consistent
with the base-255 geometry throughout.

### Spatial Color Gradients

Adjacent cube coordinates sharing similar tints form **color regions** — spatial
clusters of related services or address families. Routing decisions can exploit
color gradients: a packet destined for tint 'storage' at coordinate (5, 30, 11)
that finds no storage node there can search outward along the gradient toward the
nearest (storage-tinted) coordinate, without any lookup table.

The CCW routing matrix from the harmonic topology session already encodes
directional traversal — color gradient routing is that same traversal with a
tint filter applied at each step.

## IPv6 Coexistence — Not a Conflict

The clean cube mapping is not threatened by IPv6. The cube is a **logical**
coordinate system; what runs on the wire is a separate concern.

### VM Black Box Routing

Virtual machines act as routing boundary nodes: the cube's RFC1918 address space
lives entirely inside the VM, invisible to the external network. The VM's external
interface speaks whatever the host network requires (IPv4, IPv6, both) — the cube
mapping is an internal implementation detail that never leaks outward.

```
external network  [ IPv4, IPv6, dual-stack — cube does not care ]
        │
  [ VM boundary — translation at edge ]
        │
  internal cube  10.A.B.C  [ clean, undisturbed ]
```

This also gives **two full cubes** from standard RFC1918 allocations alone:

```
10.0.0.0/8     → cube 1  [ 256^3 = 16,777,216 points ]
172.16.0.0/12  → cube 2 partial  [ 16 × 256^2 planes ]
192.168.0.0/16 → single disc  [ 256^2 = 65,536 points ]
```

Two independent cube-1-sized spaces is already more than sufficient for any
conceivable local deployment; the 172/12 range adds a further partial cube for
a third domain.

### RFC4193 (IPv6 ULA) — Optional Extension

IPv6 Unique Local Addresses (`fc00::/7`, 128-bit space) can be treated as a
separate cube hierarchy — or collapsed back onto the existing cube via a
checksum projection:

```
ipv6_cube_coord = AMOS7_CHKSUM( ipv6_addr_bytes ) → 3-byte cube coordinate
```

This is a many-to-one projection (lossy for routing, lossless for grouping) —
useful for mapping the entire IPv6 address space into the same cube topology
for statistical analysis, visualisation, or approximate routing, while the
canonical cube uses RFC1918 for exact addressing.

The two approaches are orthogonal and can coexist: RFC1918 for precise internal
routing, RFC4193 for extended address spaces, checksum projection as a bridge
when needed.

### Bidirectional Stateless Any-to-Any Mapping

The checksum projection works as a universal intake function for any address
format — and critically, it is **stateless**:

```
AMOS7_CHKSUM( addr_bytes ) → 3-byte cube coordinate
```

- IPv4 source   (4 bytes)  → cube coord
- IPv6 source   (16 bytes) → cube coord
- MAC address   (6 bytes)  → cube coord
- pubkey        (32 bytes) → cube coord
- any byte string          → cube coord

The original address travels in the packet alongside the cube coordinate —
no reconstruction from the coordinate alone is needed. The return path uses
the carried original address directly. The projection is the routing index,
not the identity.

```
[ original_src_addr | cube_coord(src) | cube_coord(dst) | payload ]
         │                  │                │
   identity (carried)   routing hint    destination
```

### Why Stateless Matters: Attack Vector Elimination

Stateful translation systems (NAT, stateful firewalls, proxies) accumulate
state — and state is an attack surface:

```
stateful translation attack vectors:
  × session table exhaustion  [ flood new connections, fill table ]
  × state desync              [ RST injection, half-open sessions ]
  × session hijacking         [ guess sequence numbers in table ]
  × reflection / amplification [ exploit stateful return path ]
  × translation logic bugs    [ edge cases in state machine ]
```

With stateless any-to-any mapping, none of these exist:

```
stateless cube projection:
  ✓ no session table          → table exhaustion impossible
  ✓ no state to desync        → injection has no state to corrupt
  ✓ no tracked sessions       → nothing to hijack
  ✓ return path = pure fn     → reflection requires forging cube coord
  ✓ translation is hash(addr) → no state machine, no edge cases
```

Any node on the path computes the same cube coordinate for the same source
address — independently, without coordination. The "translation layer" is not
a service; it is a function. It cannot be taken down, exhausted, or confused.

### Source Address Spoofing Protection

The cube coordinate is checksum-derived — so a claimed source address is
immediately verifiable by any receiver without a handshake:

```
claimed_src_addr  →  AMOS7_CHKSUM( claimed_src_addr )  →  expected_cube_coord
                                                                    │
                                              compare to cube_coord in packet header
                                                                    │
                                              mismatch → spoof detected, drop
```

This is a **zero-round-trip** first filter: inconsistent (address, coordinate)
pairs are rejected before any handshake occurs. A spoofer must forge both the
source address AND its correct cube coordinate simultaneously — and the cube
coordinate is a deterministic function of the address, so consistency is
trivially checkable by anyone.

For stronger confirmation — especially across asymmetric routes where the return
path differs completely from the forward path — a simple reverse reachability
challenge closes the loop:

```
1. receiver sends challenge token to claimed cube_coord(src)
2. only the true owner of src_addr can receive it and sign the response
3. signed response proves reachability at that coordinate
4. asymmetric routing is irrelevant — the challenge follows the cube
   coordinate to wherever the address actually lives
```

The math result is always the same for the same address, computed independently
by every node. No central validator, no trust anchor, no session state. A node
that can respond to the challenge IS the node it claims to be, regardless of
what route the packets took to get there.

This also means the handshake itself is stateless from the verifier's perspective:
the challenge is a function of the claimed address, the response is a signature
over the challenge — both verifiable with no stored context.

### Privacy and Anonymity as a Routing Property

The system supports two distinct operating modes without any additional anonymity
layer — the choice is made at the point of network re-entry:

```
identified mode:   source re-enters network with real address
                   → cube coord = AMOS7(real_addr)
                   → verifiable, attributable, consistent

anonymized mode:   source contacts an intermediate cube coordinate
                   → that node is NOT the actual target
                   → actual target addressed by public key only
                   → source network address never reaches target
```

In anonymized mode the contacted cube-coordinate node is a routing intermediary.
The target is a pubkey — which may or may not coincide with the intermediary node.
If it does coincide, the target accepts based on private key knowledge alone, with
no network address required. The two addressing systems (cube coordinate for routing,
pubkey for identity) are orthogonal, and that orthogonality is the privacy property.

### Immutable Route Record — Hop-Signed Chain

At network re-entry the first observed source address is recorded and signed by
the entry node. Each subsequent hop appends its own signature:

```
entry node:   sign( timestamp, src_addr_first_seen, cube_coord )
hop 1:        sign( prev_entry_hash, hop_pubkey, timestamp )
hop 2:        sign( prev_entry_hash, hop_pubkey, timestamp )
...
target:       receives chain — N signatures deep
```

This is the self-assembling route log from the zenka key identity infrastructure,
applied at the network packet level. Properties:

- **Append-only by construction**: each signature covers all prior entries;
  altering any earlier entry invalidates all subsequent signatures
- **Depth = security**: the deeper the route, the more signatures must be
  simultaneously forged to alter the origin record — passively hardening
  with every hop traversed
- **Encrypted for target alone**: the route record payload is encrypted for
  the target pubkey; intermediate nodes sign without reading the inner content
- **Surveillance resistance**: an observer watching any segment of the route
  sees signed hops but cannot read the payload or determine the true target
  from the cube coordinates alone — the pubkey is the only complete identity,
  and it is encrypted end-to-end

The source address at re-entry is thus simultaneously:
- **verifiable** (anyone can check consistency with the cube coord)
- **immutable** once signed by the entry node
- **protected further** with each additional hop signature
- **invisible to intermediaries** in anonymized mode (they sign without decrypting)

This gives surveillance and traffic profiling a fundamental problem: they can
record hop traversals, but the record they produce is the same tamper-evident
chain the target receives — no separate audit log needed, and no version of
the chain exists that reveals more than the target's decryption of it.

### Why the IPv6 Objection Was Invalid

IPv6 is not a constraint on the cube — it is one possible external transport
among several. The cube makes no assumptions about what carries its packets.
A Protocol-7 node behind a dual-stack router can announce cube coordinates over
IPv4 multicast, IPv6 multicast, or both simultaneously, and any source address
regardless of family maps into the same cube via the checksum projection.
The coordinate system is transport-agnostic and address-family-agnostic
by construction.

## Implementation Notes

### Phase 0 : Coordinate Convention (no code needed)
Agree on axis assignment (which octet = which axis) and commit to
`data/yaml/conventions/cube-address-space.yaml`.

### Phase 1 : Virtual Address Allocation
Assign 10.x.x.x sub-ranges to services and hosts in the local setup.
Document in the same yaml. No translator yet — just the coordinate map.

### Phase 2 : Translator Zenka (prototype)
A zenka that accepts `(src_ip:port, dst_ip:port)` tuples and returns
a P7 routing decision. Start with static table, add proximity search later.

### Phase 3 : Listen Socket Integration
Backends register virtual addresses via translator zenka. Incoming P7 packets
addressed to that coordinate are forwarded as localhost TCP connections.

### Phase 4 : Cube-Aware Routing in discover/nodes
nodes zenka gains cube proximity queries; discover announcements include
cube coordinate; routing decisions use Manhattan distance or CCW geodesic.

#,,,,,...,...,.,.,,..,.,.,.,,,,,,,...,.,.,,,,,..,,...,..,,.,.,,,,,.,,,,,.,,,,,
#4SDWZLPWZEP2FUOATBNLXEMS2ZUMFBRH7MW7PM2LAQQ3VBBCKASLICF5TAWCK73AAPTI5CFS26W6E
#\\\|TXHV5QMHGKUVC6K3RDQW7WVHTDS6ERMTHJWTDJ7C4AMUULO4G7G \ / AMOS7 \ YOURUM ::
#\[7]GMHXRPTVYZWJFQUKNMUQCI22H7F64JZGTNKXM7MGLHHPML4PYIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
