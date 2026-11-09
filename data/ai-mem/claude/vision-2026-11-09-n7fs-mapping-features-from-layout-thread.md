---
name: vision-2026-11-09-n7fs-mapping-features-from-layout-thread
description: owner thread 2026-11-09 : 35-bit amos width as an implicit time mapping, layout modes, catalog nesting, 5 of 7 alternates, trickle checks, orbit transport, relative tags
metadata:
  type: project
---

long horizon for N7FS, beyond the migration. goes into the open list of N7FS-SEALED-REPLICAS.md with the stage 4 part 1 commit. economy details : NRT.NRD.asc and RESOURCE-ECONOMY-DEMYSTIFICATION.md, search those first.

**implicit mapping feature [ owner : significant, record it ]** : the amos address field is 7 base32 chars = 35 bits, and a year in milliseconds is 2^34.9. so the existing width names each millisecond of a year [ wraps about every 398 days ]. this is not epoch or network time yet. separately, the orbital model already connects 3 amos checksums with the 3 space axes [ 3 x 35 = 105 bits ]. location needs 12 bits for 4032 nodes.

x, y, z, t as four fields of equal width = 140 bits for one point in space and time. a year is by definition one full orbit, so the time axis closes on itself like the orbit does. in plain ms the field wraps at 397.7 days, not 365.25 ; one julian year = exactly 2^35 ticks needs a tick of about 0.918 ms.

the 4-field address [ x:y:z:t, 31 chars ] is either a sampling time or a packet arrival time, and a future t is a workload request for a table not yet valid, so the network plans resources in advance [ spatial and temporal compartmentalization ]. the sender aims at a position valid only on arrival ; the parent cube the target is registered to absorbs the remaining error and answers for both.

current position = own clock + network time offset, always locally calculated ; a received t is old by an unknown amount. offsets come from routing traffic [ time sync in the routing geometry, topic-checksum-addressing ]. the network is drift and latency aware and reorders grid positions, so a node playing with time moves itself away from its target zone. owner : steering could only occur by adding precision, not by playing with it. open check : exact added delay needs only a good clock and can look like precision ; delay is additive only, so it moves outward, and placement keeps an input the node cannot foresee.

steering is legitimate through the pre-agreed accounting tables : position is chosen by booking, measured latency checks whether the slot can be served. cycles are recalculable at a distance, a precise slot names its cycle ; missing it costs a full round, imprecision is priced as time spent at cycle overlaps. the latency grid homogenizes distance, so distance-based drift is compensated and only active fuzzing is not : it maps a node down to cold storage quality, by its neighbours. price curves make an attack yield nothing or something in the network's favour. guard : false reports must not demote an honest node, so demotion needs observers across control domains.

owner : demotion of offered values is already built into selection. a value outside the 5 best of a sampling group of 7 is simply not used, and the 5 true ones still have an alternate that is not the fuzzing node. changing the outcome takes at least three colluders per group, so the seven are spread across control domains.

orbital position form : four 35-bit amos-format fields joined by colons, `XXXXXXX:YYYYYYY:ZZZZZZZ:TTTTTTT` [ 31 chars ], is a grid cell for one orbit. a field is a real coordinate, or a checksum the orbital model maps to a position. for earth's orbit [ diameter 2.99e11 m ] a cell is about 8.7 m per axis and a tick about 0.918 ms, in which earth moves about 27 m. rendezvous : a zenka gives its orbit, both ends calculate the same cell, no directory needed, like the head locator. the aim point is valid only on arrival [ 1 AU is about 499 s of light travel, about 15000 km of movement ]. a cube 2^10 cells wide is about 8.9 km, 2^20 about 9100 km, so fresher orbit data resolves deeper. a given orbit acts as a capability : seal it to the group, keep it short-lived, rotating orbit parameters works like rotating a key. the arithmetic is mine, the concepts are the owner's.

network time as a virtual optimum plane : locally always unattainable, always alignable to in its proximity. the orbit millisecond [ the t field ] is already a bucket compared to a full resolution network timestamp, so agreement is only needed to within a bucket and the fine value serves local alignment. bucket edges need the adjacent-frame tolerance.

t alone is a cross-section through all potential orbits, with an orbit fixed it is a ring of 2^35 cells [ fixed-time tick closes only for a one year orbit, a phase tick closes every orbit ]. less resolution is an arc : a shorter t prefix names a time range of movement. per base32 char dropped from 7 : 0.918 ms, 29.4 ms, 0.94 s, 30 s, 16 min, 8.6 h, 11.4 days.

load mapping : the 63K and 63M sizes already act as static load balancing by compartment size. a space cube gets a new neighbour opened at a certain count of registered clients, so load is spatial, set by address range thresholds, and nests recursively. needs : hysteresis around a threshold ; checksum addresses spread evenly, real positions do not.
owner example : open a new neighbour at 70 %, forward everything new exclusively to it at 97 %. existing registrations stay, so a split moves nobody. 64512 x 0.70 = 45158, x 0.97 = 62577. the 3 % held back is room for existing clients.
between 70 % and 97 % the share of new clients likely follows an increasing cube overlap : the neighbour's range grows into the cube's, and a new client belongs to whichever its address falls in, so assignment stays calculated.
management layer : dimensionally orthogonal, scale mapped, virtual but exact in proportions, verifiable by all mapped positions. its mapping or 3D shadow defines the assignment area of extension addresses. the fill level is the one input not calculable from the geometry, so it needs attesting.

the shadow layer resembles the dancing zenki formation [ owner ] : 2 ring zenki above or around, 5 workers within their radius, the dance is promotion of a ring zenki into the working 5. see data/md/design/DANCING-ZENKI-RHIZOME-STATE.md, dancing_kittens_formation.md, topic-node-group-geometry, TASK-CUBE-CONSENSUS-ARCHITECTURE.md. already on record : 5 x 7 = 35 as a tracked resonance [ holographic-cubic-topology-research-2026-01-13.md ], the same 35 as the amos width : 7 chars x 5 bits.

a 5th field is a layer address for multi-dimensionality or a color frequency, giving 5 fields x 7 chars. a 35-bit field is also a 5 x 7 bit matrix, so each field can be expressed as a glyph [ bin/dev/ttf-glyph-mapper ].
two 5-field addresses [ color included ] define a color gradient arc, start and end on an orbit, so entities can have cycles, likely several and likely 7 [ owner ]. under posterization a color is the average of its bucket. cycles map exactly to a number of elements ; the encoded advance does not say how they are stretched.
the gradients may represent spiraling or axial rotation on the waypoint curve, the travel through quadrants already being virtual precision. with 7 color based elements the 5th value might be an alpha toward that fixed scale instead of a free color selection ; the element still has its own average color [ owner, open ].
the axial rotation can be the direction of curve change if a change occurs exactly then : the when defines the where to, with mappable floating point precision [ owner ]. timing error becomes direction error, growing with distance, which fits steering only by adding precision.
mapped cubically this limits which 90 degree turns a zenka can take where : the suspected small movement constraints hidden in the division by 13 remainder patterns when protocol rules are assigned to stream elements, protecting against entropy despite free travel [ owner ]. to check against bin/dev/division-13-table : base 10 remainders mod 13 form two cycles of six [ 1 10 9 12 3 4 and 2 7 5 11 6 8 ], and a cube has six axis directions.

CONFIRMED in bin/dev/division-13-table : the stream decodes as 7-bit states and the grammar already holds this thread. `00` route : forward with a hop count, or a 90 degree turn with 2 direction bits [ up, right, left, down ], no reverse. `01` : 0 + 5 bits a BASE32 character, or document cube headers. `1` + 6 bits : 5x7 matrix positions, then color operations : set and reset, add \ subtract, K B G R in two steps [ 0 and 0.24 ], and A0 A1 alpha. so the mapping is by state bits, the two mod 13 remainder cycles above are only a side observation.

- **sizes** : 16 MiB x 8 x 8 x 63 = 63 GiB exactly, 64512 = 63 x 1024 is the existing 63K unit [ buffer default, read sizes, 1024 header + 64512 payload = 65536 ]. 64512 bits = 168 BMW384 digests. doubling [ 16 \ 32 = ((5x3)+1)x2 ] also matches ; the cubic space mapping decides the default. owner open to a 1 : 63 header split
- **layout record per sealed node** : mode + sizes. complete, segment [ parent id, position ], catalog. unknown mode refused. a mode must pay back its overhead per use, return counted across ALL users [ dedup, overlap ]
- **catalog disk** : the root block's empty space maps several whole disks and segment groups, even with different C25519 parents. entries sealed and signed per parent, uniform padded slots, slot found by keyed derivation, per-group version counters. fits compartments
- **nesting** : unlimited size, checksum-based internal address trees, cubic routing alignment, quantization by reduced branch counts. owner hypothesis : at scale overhead inverts against other structures, latency becomes a predictable cycle range. to measure : structure bytes per payload byte, steps per read
- **5 of 7** : 5 live, 2 hot alternates, using one recruits two more. needs at most 2 per control domain and a recruitment rate limit. can be 7 fragments of a 5-of-7 code
- **role pricing** : different token proportions for active work and alternate duty saturate the field ; damped against oscillation
- **trickle checks** : tiny, frequent, paid, symmetric between holders of the same data, random bits from the whole range. commit before reveal, joint randomness, time limits per holder class [ ssd \ spinning ]. identical bytes only : erasure fragments need other tokens
- **movement as proof** : orbit on the cubic grid, checksum at each temporary hop, no release before the next hop's receipt, moved data counts zero durable redundancy, each move changes the form of the bits
- **disjoint planes** : 5th sub-bit parallel streams ; validators are not the hops, trunk does not know what it carries, validators have no access window. recording is the threat timing does not cover, sealing and a moving map cover it
- **relative tags** : relative addresses valid for a reference frame, entropy only as wide as that scale needs, derivable from division-13 streams [ bin/dev/division-13-table, zulum zenka, cube-13 : read these first ]. location and time binding stops reuse ; forgery by a compromised hop still needs a secret input, since a hop knows its own position and time

#,,,,,...,,,.,,,,,,.,,,,.,,.,,,..,,,,,,.,,,,.,..,,...,...,,,,,,..,,,,,,..,,.,,
#DLX64ZXHHIRU3GFQ3RQIXCXMT2346QGWDMGLVN557LEF4EKLVLXQ5DF3SALANOD3CKWOSCZDLRNAM
#\\\|4REUDEN32NQ6C4N7IZSGQSKCRCZMNOXPJUCEKZLSIWN2OQHWTLZ \ / AMOS7 \ YOURUM ::
#\[7]3IXKIQJ2YQXMPOXJQLFFFI3KZP3GRXK2CICZOYOXIRLOYZ3H5OCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
