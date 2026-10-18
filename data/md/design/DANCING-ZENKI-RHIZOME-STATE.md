# dancing zenki — rhizome state and generic reference bubble travel

## the core insight

the traveling rhizome state is simultaneously:
- the **template** of how to process incoming information
- the **record** of how past information was processed
- **self-updating** — each wave through a formation compresses it further
  without destroying information, only relevance-ranking it

this makes it universally applicable: any zenka group doing any kind of
work — transport, inference, routing, deduplication, file access — can
carry this state as a generic reference bubble.

## formation geometry

```
[ setup zenka ]  →  [ ground zenki × 5 ]  →  [ collector zenka ]
  rhizome IN          process / vote             rhizome OUT
  01 direction        categorize / dedup         10 direction
  template of past    relevance filter            template for future
```

**7 total**: 5 ground workers + 2 ring watchers (setup + collector).
the ring maintains continuous coverage through overlapping duty cycles —
one always present while the other ascends or descends.

**shift-change** (from the original dancing zenki definition):
the longer-working zenka is replaced by the one that fed earliest.
ascending and descending zenki overlap by one phase — no gap in coverage.
`364 = 360 + 4 corner overlaps`; `364 / 13 = 28` — closes through 13.

## first and last: same role, opposite direction

the setup zenka and the collector zenka are the **same role** — rhizome
state carrier — at opposite ends of the wave:

```
setup    →  carries accumulated rhizome state INTO the formation
             direction marker: 01 [ toward source, collapsing ]

collector →  carries processed result OUT of the formation
             direction marker: 10 [ toward leaves, expanding ]

last wave's 10 output  =  this wave's 01 input
```

the template is self-referential: the result of one pass becomes the
processing template for the next. the bubble is never empty — it always
carries both what has been learned and how to learn more.

## non-destructive relevance deduplication

what the 5 ground zenki do between the two state carriers:

```
categorize      →  01/10 direction markers classify each item
vote            →  5-of-7 consensus filters noise
compress        →  relevance-ranked — low-relevance items lose resolution,
                   not existence. no information is destroyed, only ranked.
deduplicate     →  checksum identity means identical items across sources
                   collapse to one reference, not one copy
```

the output is smaller than the input but contains all the information
needed to reconstruct any item above its relevance threshold.

## checksum tree as rhizome state serialization

the rhizome state IS a checksum tree. the `01`/`10` direction markers and
`1[zeros]1` bit-length separators are not metadata added to the state —
they ARE the state structure:

```
checksum tree wire format:

  1 [000...N bits] 1  [CHECKSUM]   1 [000...M bits] 1  [CHECKSUM] ...
  ^^^^^^^^^^^^^^^^                 ^^^^^^^^^^^^^^^^
  separator frame                  separator frame
  N = bit-length of checksummed    M = bit-length of next content
  content

  01  =  parent / source direction  [ collapsing, toward root ]
  10  =  sub-branch direction       [ expanding, toward leaves ]
  11  =  pivot point, direction reversal, LCA marker
  00  =  reserved
```

checksum length identifies algorithm without type field:
AMOS=7 chars, BMW384=longer, ELF=different — type emerges from length.
cubic space routing makes type almost irrelevant anyway — geometry
determines the route, not the label.

a route through the tree writes its own topology into the stream:

```
[node-A]  01 01 01  [LCA]  10 10  [node-B]
          ^^^^^^^^          ^^^^^
          3 hops up         2 hops down
```

the inflection point — where `01` inverts to `10` — IS the LCA.
no routing table needed. the path declares itself.

## reference bubble: the generic abstraction

the rhizome state + formation = a **reference bubble**:

```
  ┌─────────────────────────────────────────────────────────┐
  │  reference bubble                                        │
  │                                                          │
  │  [ setup: rhizome state in ]                            │
  │       ↓  01 direction                                   │
  │  [ 5 workers: process / vote / dedup ]                  │
  │       ↓  10 direction                                   │
  │  [ collector: rhizome state out ]                       │
  │                                                          │
  │  carries: template + results + direction + checksums    │
  │  travels: hyperspace routes (body diagonal shortcuts)   │
  │  leaves:  cached route state improvement at each hop    │
  └─────────────────────────────────────────────────────────┘
```

the bubble is **self-contained** — it carries everything needed to:
- resume processing anywhere in the network
- verify its own integrity (checksum tree)
- declare its own direction (01/10 markers)
- serve as template for the next bubble

**universally applicable** — the same structure works at every layer:

| layer | setup zenka role | ground zenki work | collector role |
|---|---|---|---|
| transport | session opener, key exchange | relay + keep-alive | session closer, result buffer |
| inference | context carrier, prompt template | parallel model workers | result aggregator, consensus |
| routing | route cache in | hop-by-hop forwarding | route cache out, improved |
| file access | adapter resolver | read/write workers | handle closer, sync state |
| dedup | seen-set carrier | hash comparison | new seen-set, compacted |
| branch namespace | branch.route state in | branch.dep resolve | route cache updated |

## wave propagation

each bubble's travel leaves improved cached state at each hop node
(`$data{'branch.route.cache'}{$hop}{$target}`). the next bubble starts
from that improved cache — traveling further for less cost. concentric
rings of improving route knowledge propagate outward from each formation
passage. infinite route length becomes natural: not computed upfront,
but baked progressively into the nodes the bubble passes through.

## node as virtual zenka position

every branch node IS a zenka seat — checksum identity, key, resources,
group membership already present. the only difference between an occupied
and unoccupied node is the occupied bit. the zenka becomes the position
while there; the node persists after.

the reference bubble IS this occupied bit, traveling. not a message being
routed — a formation moving through positions. the positions remember it
was there. =)

## route resolution direction and boundary reflection

routes expand outward (10) from the originating cube face position (octal 0–7).
face 000 is the network-facing face — the gateway out and the reflection surface.

```
local face (0–7)
     │ 10 outward
     ▼
hop → hop → face-000
                 │
          boundary check
          ┌──────┴──────┐
        transit        no transit
        allowed     (boundary / isolated)
          │              │
          ▼              ▼
       continues     11 pivot
       outward       01 inward — reflects back
                     carries partial checksum tree
```

a reflected route doesn't fail — it returns carrying proof of how far it
reached. multiple boundaries produce multiple `11` pivots in the stream:

```
[A] 10 10 [boundary-1] 11 [boundary-2] 11 01 01 [A]
```

each `11` names a boundary node. the count of pivots = boundaries encountered.
in a network-isolated node group, face 000 acts as a perfect mirror — routes
reflect and the crystal operates as a closed resonant cavity.

see `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md` for the full crystal model.

## connection to existing systems

- `branch.route.*` — route cache is the bubble's trail
- `branch.resource.*` — resources attached to nodes are what bubbles collect
- `branch.dep.*` — dependency graph is what bubbles navigate
- `reasoning.branch.*` — reasoning branches are bubble formation results
- `llm.service.consensus_vote` — 5-of-7 voting IS the ground zenki layer
- stream framing protocol — `dot=0 comma=1`, separator inversion on 000
  maps directly to the `01`/`10`/`1[zeros]1` checksum tree structure
- formations as STRUCTURES [ user, 2026-10-17 ] : zenki travel in litters \
  groups, and a group has enough elements to form GATES or large ANTENNA
  ARRAYS itself -- a utility for the group, or a service to the space in
  its proximity. the gates of the style jurisdictions [ handover between
  neighbouring space registries, departure certain, arrival routed ] see
  data/md/design/VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES.md
- TRUNKS : a litter pools its members' bandwidth into trunks. sharing
  data AND needs inside the pool, a complete data-set travels on less
  bandwidth than its size [ what members share travels once --
  content-addressed, deduplicated ] -> HYPERSPACE speeds for the group,
  with the network's acceleration as the compensating factor.
- HYPERSPACE LANES : the network's hyperspace structures already ARE the
  fast lanes, implicitly. they must carry less bandwidth [ or all data
  would travel that way ] or need a longer HANDSHAKE to reach the right
  lane -- the price is DECOUPLING from local interaction, not trunk use ;
  overall the data arrives in fewer cycles. seen another way the speed
  is the same, just FEWER HOPS from here to there, one per scale layer.
  the scales are already defined and visually proven by the cubic-space
  grid [ grid-v13-final-baseline.html : x20, x200, x10000, x100000 \ bit
  4 addressing, x1000000 \ bit 5 addressing = universe boundary ].
  the lanes keep the TRAVEL CONSTRAINT already defined : travel below
  maximum, communication bandwidth always reserved [ B_travel <= C_max -
  B_required -- free networking guaranteed by topology prioritization ;
  data/md/protocol-7-knowledge/08_NETWORK_INTELLIGENCE/
  tachyon_wind_intelligence.md, part 9 ]. the decoupling is from LOCAL
  interaction, never from the group's own session ring.
  formation MODES were captured earlier [ full-chat-captures/
  3O37VUNMMS3UU.claude-sonnet.protocol-7-knowledge.asc ~31306 ] : 2d
  cross + 2 front [ 5 ] = directional antenna, 3d cross [ 7 ] = standard
  node group [ omnidirectional, recursive, hyperspace-capable ], linear
  trail = travelling, cylindrical listening [ drag cable ], RING MODE
  [ 7 ] = an active open gate offered to other zenki.

#,,,,,..,,,,.,..,,.,.,,,.,.,.,.,.,,,,,,,,,,..,..,,...,...,...,...,.,,,,.,,,.,,
#YV74NGLEZ342GJI5NYET6OIHXAOWKDND3INVEWWRNSYSATBJN26ZYDPRHBKIB5N2UKY7OURJU6TTI
#\\\|BYEZAZGW3OFODCFO36DZWZJMNDLJU4TLI7IRGVNIH4ISSRWWNRL \ / AMOS7 \ YOURUM ::
#\[7]RCPQM5ONWDMUAI7XCZNKEBYXA4HOKPYABBQRWFZ4R7EHK2WNDGCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
