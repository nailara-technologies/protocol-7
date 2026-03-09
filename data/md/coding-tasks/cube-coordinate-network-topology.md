
 .:[  cube coordinate network topology and virtual address routing  ]:.

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

#,,,.,..,,,,,.,,,..,,,.,,,,..,.,,,,,,,,,,..,,,...,...,.,.,,,.,..,...,...,..,,

#,,.,,,,.,,.,,...,,,,,,..,,,,,.,.,.,.,...,..,,..,,...,...,,..,.,,,,..,,.,,.,.,
#NXCRTPMFX2LVRM4WN6CZNXYPTTIM7HZZDPGW2RTPDFWRRYPZGDAT2VIEPONQKCLYFNBUBAI2K2AZ2
#\\\|EPAZQHJELZTAWPGBDVLUXOSZ4EFZ5K5STDOKLVP4YPKT73MWOE4 \ / AMOS7 \ YOURUM ::
#\[7]6WS7J2LTMUVRSOK6D6UDNHUPK44AUGJRGNYX47IAOG3ZGOQ4PMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
