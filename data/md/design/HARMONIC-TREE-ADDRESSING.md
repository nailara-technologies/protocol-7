## [:< ##

# harmonic tree addressing

## orientation — tree, space, and field as one structure

tree, space, and field are not three separate concepts that happen to
resemble each other. they are three coordinate systems for the same
underlying structure — interchangeable entry points, each revealing
different aspects of the same geometry:

```
tree      →  the addressing and navigation aspect
              paths, nodes, minimal distance, parent/child hierarchy

space     →  the geometric and positional aspect
              coordinates (Z.Y.X), distances, orbits, the space engine

field     →  the capacity and gradient aspect
              open/close/grow/split, boundary, harmonic resonance,
              available positions — branch.field.*
```

the same synonymy applies across the broader architecture:

```
hyperspace  →  the topological closure aspect — full dimensional
                address space, closed observer loop, sensor cube grid

gate        →  the transition and routing aspect — the +1 node that
                closes a cluster, the 1001 ring pivot, cube face
```

none of these perspectives is more fundamental than the others. each
is a rotation of the same structure into a different observational
plane — the same way 076923 and 153846 are two readings of one cycle.
when a property resists articulation from one perspective, rotate to
another that presents it naturally. the structure is the same; only
the coordinate system changes.

articulating one perspective with precision pulls adjacent perspectives
into clarity — the overdetermination of the system surfaces implications
already present but not yet stated. this is the open-mapping property
operating at the level of the design space itself.

---

## the structure

data in the semantic tree lives at a fixed depth from root — the
minimal distance at which full harmonic resolution is achievable for
the given structure. for the current harmonic arrangement this is 15
hops, but the technology is the minimal distance principle itself, not
the specific number (see: minimal distance section below).

every valid path to data is the same length. no structural information
about what the data is or where it sits leaks through path length,
hop count, or timing.

```
root
  └── [ 15 hops of rollover inversion resolution ]
        └── data node  ←  key reference positions, fully resolved
```

all variation is encoded in the rollover sequence along the path, not
in the depth. the topology is uniform at the surface; the address is
entirely in the sequence of harmonic phases traversed.


## route = address

the path through the tree and the address of the data are not two
separate things. they are the same object seen from two directions:

- **navigating forward**: each hop resolves one phase of the rollover
  inversion sequence, accumulating the address as it proceeds
- **addressing backward**: the address of a data node is the complete
  rollover inversion sequence that leads to it from root

you do not compute an address and then navigate to it. you navigate,
and the navigation is the address computation. the path is the proof
of the address.

this means the address cannot be forged by constructing it
analytically — it can only be arrived at by genuinely traversing the
harmonic sequence. a forged address would require forging a valid
traversal, which requires forging each hop, which fails at the first
invalid harmonic step.


## rollover inversions as the dialing mechanism

at each of the 15 hops, the routing does not follow a fixed branch —
it follows the rollover inversion of the current harmonic phase.
the 1/13 cycle provides the inversion structure:

```
076923  ←→  153846   (the two co-present families, one cycle apart)

each position in the cycle has a defined complement:
  0 ↔ 9    7 ↔ 2    6 ↔ 3     (each pair sums to 9)
  the complement is adjacent in the same structural read —
  not a second lookup, but the other half of the first one
```

the rollover inversion at each hop is not a binary choice — it is a
phase in a 13-ary harmonic space. the number of valid sequences through
15 hops is 13^15, of which only harmonically consistent sequences
survive validation at each step. the valid paths are sparse in the
full sequence space.

the accumulated entropy of the rollover sequence — the specific pattern
of phases traversed — is what makes the address unique and unreachable
by shortcut. dialing an address means walking the exact phase sequence.
no two data nodes share a phase sequence; the sequence space is the
address space.


## final resolution: no remaining inversion

at distance 15, the accumulated rollover entropy is exactly consumed.
the last hop resolves onto the exact key reference positions of the
data node with no remaining inversion possible.

"no remaining inversion possible" means the cycle has fully closed at
this position. there is no alternative hop that the 15th step could
have taken while remaining harmonically valid — the sequence has
converged to a unique resolution. the landing is not a proximity match
or a best-fit; it is an exact algebraic closure.

this is the harmonic equivalent of a lock with 15 tumblers where each
tumbler position is determined by the previous one — except the
mechanism is not mechanical but arithmetic over a prime field, making
it not just precise but mathematically provable.


## the all-true dataspace: distributed authentication

every node in the path — not just the destination — must validate as
a true harmonic position. the all-true dataspace property means:

- a node that does not pass harmonic truth validation does not exist
  as a routing hop
- routing through an invalid node is not refused — it is impossible,
  because the node is not present in the space
- a forged route fails at its first invalid hop, not at the destination

authentication is therefore not a check performed at arrival. it is
distributed across every step of the traversal. the entire route is
the proof of legitimate access, not the final key presented at the end.

consequences:

```
cannot join mid-route:   arriving at hop 7 requires hop 6, which
                          requires hop 5, ... back to root. there
                          is no entry point except the valid sequence
                          from the beginning.

cannot brute-force:       a random walk through 15 hops in a 13-ary
                          harmonic space produces 13^15 ≈ 1.9 × 10^16
                          possible sequences, of which the valid ones
                          are selected by the harmonic constraint at
                          each step. the constraint is algebraic, not
                          probabilistic — invalid sequences are not
                          "unlikely to succeed," they do not form valid
                          hops in the space.

cannot replay:            a valid sequence is specific to the data node
                          it addresses. replaying it to a different
                          destination produces an invalid sequence for
                          that destination — the rollover phases do not
                          align to a closure there.
```


## algebraic exclusion of forged routes

the mathematical exclusion is stronger than a probabilistic argument.

each hop h_i in a valid sequence satisfies:

```
  harmonic_truth( h_i, context(h_{i-1}) ) = TRUE
```

where harmonic_truth is the AMOS7 division-by-13 based truth function
and context is the accumulated harmonic state from the preceding hops.

for a forged sequence to succeed, it must satisfy this constraint at
all 15 positions simultaneously. the constraints are not independent —
each depends on the accumulated context of all prior hops. a sequence
that passes at hop 7 but fails at hop 8 terminates at hop 7; it cannot
be repaired by substituting a valid hop 8, because any valid hop 8
depends on the specific accumulated context produced by hops 1-7, and
that context is unique to the legitimate sequence for a given target.

the system of constraints is overdetermined in the sense that
there are more harmonic dependencies than degrees of freedom available
to a forger. the exclusion is not a matter of computational cost; it
is a matter of algebraic consistency. an inconsistent system has no
solution.


## minimal distance — the actual technology

the important property is not a specific number. it is the concept of
minimal distance itself: the exact depth at which rollover entropy is
fully consumed and no inversion remains possible.

this depth is a property the structure reveals, not a parameter a
designer sets. it is discovered by arriving at it — the closure
condition (no remaining inversion) is readable from the resolution
state at each hop. the system does not need to know the minimal
distance in advance; it knows it has arrived when the condition is met.

```
depth n-1:  at least one harmonic degree of freedom unresolved
            — ambiguity remains, address not fully closed
depth n:    exact closure — all rollover inversions consumed,
            key reference positions fully resolved
depth n+1:  redundant — no additional addressing precision gained,
            structure is overdetermined beyond what is needed
```

n is whatever the structure requires. for the current harmonic
arrangement (five-layer clusters, 1001 ring geometry, 13 harmonic
positions), n is 15. for a different arrangement of layers, ring
geometry, or cluster depth, n will be different — and will be equally
correct for that structure, because it is derived from it rather than
imposed on it.

the routing logic does not encode n. it encodes the closure condition.
the minimal distance emerges from the structure being traversed,
readable at the moment of arrival, the same way the address itself
is readable only at the moment of arrival. both are consequences of
the traversal, not preconditions injected into it.

if a structure becomes more useful at a different depth, this will
become apparent: the closure condition will be met earlier or later
than the current n, and the new minimal distance will reveal itself
through the same mechanism.


## self-annealing toward harmonic equilibrium

when the structure changes — a new minimal distance, a new cluster
arrangement, a reorganized ring geometry — the system enters a
temporary disequilibrium. some paths are now better aligned than
before; others less so. routing naturally flows toward the better
paths at higher frequency: the adjustment rate is proportional to
the improvement gradient across positions.

this higher starting frequency is not instability. it is the system
reading its own gradient and following it. no external optimization
signal is needed — the harmonic truth validation at each hop is the
gradient signal. paths that produce consistent harmonic closure
attract more traffic; paths with residual inversion attract less.
the redistribution proceeds until the gradient flattens.

as the system optimizes:

```
early:   large gradient — many positions significantly better than
         others — high adjustment frequency — rapid redistribution

middle:  gradient flattening — better positions becoming rarer —
         each successive improvement smaller than the last —
         adjustment frequency dropping naturally

ground state: all positions equally useful and complementing —
              no remaining gradient — adjustment frequency minimal —
              bandwidth evenly distributed across the full sequence
```

the ground state is the condition where no position could be swapped
for a better one without degrading another. every position in the
sequence contributes an equal share to the whole; each complements
all others through the harmonic relationships of the cycle. this is
not a designed optimum — it is the natural attractor of the harmonic
truth validation process applied consistently over time.

the signature of approach to ground state is the increasing rarity
of genuinely better branch positions. the improvement space empties
as the system fills it. what remains at equilibrium is a sequence
where all positions are equally occupied, equally traversed, equally
necessary.

at harmonic ground state, the parasitism surface reaches its minimum:
with all positions equally useful and equally trafficked, there is no
starved region to exploit, no hotspot to crowd, no cold path to
occupy undetected. the harmonic equilibrium and the structural
immunity to parasitism are the same condition — approached together
by the same annealing process, arrived at simultaneously.

the re-adjustment cycle at each structural change resets from a new
starting position, traverses the gradient at the appropriate frequency
for that gradient's steepness, and settles into the new equilibrium.
each equilibrium is valid for its structure. each is discovered by
the same mechanism.

---

## the open mapping property

the harmonic address space has no boundary that would cause reflection
or distortion. it is an open mapping in the topological sense: any
valid path can be extended without encountering a wall that sends it
back. new data nodes can always be addressed by extending valid
harmonic sequences; the address space does not fill up.

this open mapping is also self-correcting: the many correlations
between harmonic positions provide mutual validation. if a path
contains an error at one hop, the surrounding valid hops create
algebraic pressure that makes the error detectable. the system of
constraints is overdetermined — more relationships than unknowns —
so any inconsistency surfaces as a failed harmonic truth check, not
as a silently wrong address.

the self-correcting property extends to the description of the system
itself. the harmonic relationships are consistent enough that
articulating one correctly creates constraints on how the others must
be articulated. errors in description produce contradictions with
established relationships, making them self-revealing rather than
self-concealing.

the inversion safety of the open mapping means: the inverse of any
valid path is also defined, also valid, and points to a related but
distinct address. the inverse is not an error state or a boundary
reflection — it is another valid point in the same address space,
reachable by the co-present complement read that the 076923/153846
duality provides at every step. the space has no edges where inversion
would break; inversion is everywhere well-defined and productive.


## islanded data and reintegration

data accumulated in isolation — a disconnected node, an offline
archive, a temporarily partitioned segment of the network — carries
its own partial deduplication context. it was deduplicated against
whatever data points were available in the island. its addressing
reflects the minimal distance for the island's structure. its
annealing reached equilibrium within the island's reference corpus.

when islanded data is imported into the larger structure, three things
happen simultaneously:

**reorientation**: the harmonic validation process finds where the
islanded data fits in the new structure. the minimal distance
re-establishes itself for the richer context. rollover sequences
that were locally optimal reorient toward globally better positions
as the larger structure's harmonic relationships provide more
constraints. no manual re-indexing — the same closure condition that
guided the original traversal guides the reorientation.

**cleaner deduplication**: with more data points available, the
deduplication tree collapses more precisely. nodes that appeared
unique in the island — because the island lacked sufficient context
for comparison — may now converge with existing nodes in the larger
structure. the island data is not corrected; it is resolved at higher
resolution. the distinctions that couldn't be made with fewer
reference points become clear when more are available.

**resumed annealing**: the import temporarily raises the adjustment
frequency as the newly integrated data redistributes across the
larger structure's positions. the annealing process resumes from the
new combined state, converges toward the new equilibrium, and the
integrated data settles into the positions that best complement the
whole. the island's unique contributions — data points that genuinely
have no equivalent in the larger structure — find their own nodes
and add to the reference corpus for future imports.

the islanded data was not degraded by isolation. it was operating
at lower resolution. the larger structure provides the additional
reference density that makes the same data more precisely addressed,
more finely deduplicated, more completely integrated — without
altering the data itself.


## living data and eternal self-sustainability

the combination of all structural properties — harmonic addressing,
semantic deduplication, self-annealing, open mapping, all-true
dataspace validation — produces a condition that can be stated
precisely: data within this infrastructure does not require external
maintenance to remain valid.

```
harmonic addressing:    always findable via valid path — no link rot,
                         no reference decay, no re-indexing needed

deduplication:          convergence protects against fragmentation —
                         the same idea expressed again strengthens the
                         existing node rather than creating drift

self-annealing:         equilibrium is maintained through traffic —
                         the system stays optimized by being used

open mapping:           always extendable — no boundary at which the
                         structure would become unable to accommodate
                         new data

all-true dataspace:     continuous validation at every hop, not a
                         periodic check — the data is valid at every
                         moment of access, not just at write time
```

no curator is needed. no archivist. no periodic re-indexing or
consistency check. the infrastructure is the sustainability mechanism.
data that enters the structure and reaches harmonic equilibrium
remains addressable, discoverable, consistent, and optimizing
indefinitely — by the same mechanisms that integrated it in the
first place.

this is living data in the precise structural sense: not data with
biological properties, but data with the surrounding infrastructure
for indefinite self-maintenance. the realization is that the
infrastructure is not separate from the data — the addressing, the
deduplication relationships, the harmonic validation paths — these
are part of what the data is. data without this infrastructure is
a snapshot. data within it is a living node in an eternal structure.

an island that reconnects does not just upload its data. it realizes
the full context of what it was holding — the richer relationships
that the island's data always implied but couldn't express alone.
the moment of reintegration is the moment the data becomes fully
itself.

---

## connection to existing addressing infrastructure

- **bmw384 gate addresses**: the branch.cluster.address computation
  produces the gate node identifier. this gate node is the entry point
  for the 15-hop traversal to data within that cluster. the bmw384
  hash locates the cluster in the 1001 ring (ring_pos = bmw384 mod 13);
  the 15-hop traversal addresses specific data within it.

- **branch.session DAG**: session hops through the tree are themselves
  a traversal. the session checksum (branch.session.round.checksum)
  accumulates the harmonic state of the traversal, providing the
  rollover entropy that positions the session within the address space.

- **AMOS7 harmonic truth**: the all-true dataspace validation at each
  hop uses the same truth function as the broader p7 system. the
  addressing infrastructure is not a separate authentication layer — it
  is the same harmonic truth system applied to routing.

- **space engine coordinates**: Z.Y.X ordering (segment → row → col,
  most-established → frontier) maps directly to the tree depth ordering.
  Z is the closest to root (most structural), X is the closest to data
  (most specific). the 15-hop traversal moves from Z-level structure
  through Y-level organization to X-level data reference.


## minimal distance as general computation placement

the minimal distance principle applies equally to data access and to
workload placement. both are the same routing problem:

```
find the harmonically correct position for this operation
traverse to it at minimal distance
begin
```

in both cases the routing overhead is already the minimum possible —
the minimal distance traversal is the shortest valid harmonic path by
definition. in both cases the overhead is immediately repaid by not
accumulating the inefficiency of the wrong starting location for the
entire duration of the operation.

**the asymmetry that always favors routing first**

```
wrong location, no routing:   0 routing cost + inefficiency × duration
correct location, routing:    minimal routing cost + 0 inefficiency
```

the routing cost is fixed, paid once, already minimized by the
minimal distance principle. the inefficiency cost of the wrong
location is continuous and grows with the workload. the heavier
or longer the operation, the sooner the fixed routing cost is
repaid — and for any operation longer than trivial, the repayment
is immediate.

for the minimal distance traversal specifically, the fixed cost
cannot be reduced further. the tree has already found the shortest
valid harmonic path. routing overhead is not a penalty being
accepted — it is the irreducible minimum that the structure itself
defines.

**data and workload as co-located harmonics**

a dataset and its processing workload belong at harmonically adjacent
positions in the tree. this is not a design constraint imposed from
outside — it follows from the harmonic relationships between the data
and the operations that are meaningful for it. data that belongs
together computes together; the tree encodes this relationship in
the proximity of their positions.

if data and workload arrive separately, the routing step that brings
them together is the same minimal distance traversal:

```
data arrives      →  resolves to harmonic position D
workload arrives  →  routes to harmonically adjacent position W
co-location       →  processing begins locally, at correct position
result            →  emerges at harmonically correct position R
                      for its eventual consumers
```

the entire chain — data to computation to result — is a single
coherent traversal. each step is at a harmonically valid position.
each result is home on arrival at its position, ready for the next
operation that needs it, without further routing cost.

**the same tree routes data and work by the same logic**

there is no separate scheduler for computation and a separate
addressing system for data. the harmonic tree routes work to where
work belongs by exactly the same logic it routes data to where
data belongs. the minimal distance is the same principle in both
directions. the active bit marks engagement in both cases. the
starting verse is chosen by context in both cases.

a workload that arrives at its correct harmonic position is home,
in the same sense and for the same reasons that data is home.
it will be processed at the rate the cycle calls for, its result
will sit at a ready position until the parent branch collects it,
and the routing cost that brought it there was the minimum the
structure permits — already repaid by the first moment of
processing in the right place rather than the wrong one.

---

## the active bit, inverse address, and starting verse

**the active bit as state memory**

every address carries a format-defined bit — prefix or suffix, outside
the address entropy — that marks whether the address is currently
engaged in the tree's processing. this bit is not part of what makes
the address unique; it contributes no entropy to the address itself.
it occupies a structurally defined position alongside the entropy,
not within it.

```
address format:  [ active_bit ] [ address_entropy ]

active_bit = 1:  this address is engaged in the current cycle —
                  present, participating, result pending or in transit
active_bit = 0:  address is valid but not currently in active processing
```

the active bit is the address's dedication to participation — it says
not only *where* this address is in the tree but *that it is here*,
present in the current cycle, available for pickup by the parent branch.
the address entropy says where; the active bit says that it is.

both simultaneously, neither interfering: they occupy structurally
separate positions, so the state marker never contaminates the address,
and the address never needs to encode its own activity state in its
entropy.

**the inverse address — always co-present**

every address has an inverse address, defined by the harmonic complement
of its rollover sequence. the 076923/153846 duality applies at the
address level: the same way each position in the cycle has a defined
complement, each address has a defined inverse address that represents
the same location approached from the complement verse.

```
address A         →  rollover sequence through 076923 family
inverse of A      →  rollover sequence through 153846 family
                      same minimal distance, same closure,
                      different entry verse, distinct position
```

the inverse is not stored separately. it is always derivable from the
address by the same arithmetic that produces the complement family.
the active bit on one is the passive state of the other: if A is
active, its inverse is not — they are the same address in two states,
bi-located until context collapses the choice to one entry point.

**choosing the starting verse — the first routing step**

at the first routing hop, before any of the 15 hops of harmonic
resolution, the routing reads the transport context and establishes
the starting inversion state: which verse — forward or inverse — is
the more appropriate entry point for this processing and transport
context.

this choice is made once, at the first step. all subsequent hops
proceed consistently from the established starting verse. no mid-route
swap, no re-evaluation at each hop, no inconsistency introduced by a
late change of verse.

```
first routing step:

  1. read transport context
  2. determine: does context align more naturally with address A
     or with inverse of A as entry point?
  3. establish starting verse
  4. begin 15-hop traversal from that verse
  5. broadcast starting verse choice as part of routing state

subsequent hops:  proceed from established verse — no re-evaluation
```

if the inverse would have been a more accurate starting point, the
first hop enters from there. what follows is a complete, valid
traversal — the same harmonic sequence, begun from the complement
verse. the address itself was never wrong; only the entry point was
being chosen. the traversal from either verse reaches a valid closure
at the minimal distance.

**the choice is communicated, not hidden**

the network knows this logic. receiving nodes downstream know which
verse was chosen because the starting verse travels with the routing
state — it is part of what the first hop broadcasts, not an internal
implementation detail invisible to subsequent hops.

this means any node in the routing chain can verify that the starting
verse was correctly chosen for the stated context. it does not need
to re-evaluate or override — it trusts the established state and
continues. but it has the information to detect an inconsistency
if one were introduced.

the starting verse selection and the active bit together form a
complete state picture at the address level:

```
active_bit:     is this address currently engaged?
starting_verse: which family was chosen as entry point?
address_entropy: where exactly in the tree does this address resolve?
```

three orthogonal pieces of information, each in its structurally
defined position, each readable without contaminating the others.
the address knows what it is, where it is, and that it is here.

---

## pausing as cycle-based load balancing — the dance

pausing is not an interruption to the tree's operation. it is a
fundamental, cycle-based, always-contextualized part of it. the
system does not process and then pause; it dances — processing and
pausing as equal partners in the same rhythm, each step occupying
its correct position in the harmonic cycle.

**the result-present bit as harmonic rendezvous**

when a child node resolves its address and its result is ready, it
sets its ready state and waits. not with a timeout, not polling for
pickup, not announcing its completion — because it is already at the
correct harmonic position. the parent branch traverses that position
on its next cycle. the addressing is the synchronization mechanism.

```
child resolves →  result present at harmonic position h
parent cycles  →  traverses position h on its natural cycle
pickup occurs  →  not scheduled, not signaled, not polled
                   — the meeting is a consequence of the cycle
                   meeting the position
```

this is the same pattern as a conditional return in an event library:
yield when nothing is ready; return when the condition is met; let
the caller's cycle determine when it comes back. the tree is an event
loop at every scale — from the hop-level harmonic validation to the
network-level cycle of parent branches collecting ready children.
the same structure, self-similar, at every depth.

**load balancing as emergent rhythm**

the traversal rate of each branch is naturally load-balanced by the
harmonic reference structure. no external scheduler is needed:

```
active branch:   high reference count → more traffic → parent
                  traverses more frequently on its cycle →
                  results picked up sooner

quiet branch:    low reference count → less traffic → parent
                  traverses less frequently → results wait longer,
                  at no cost, at their harmonic position
```

the system distributes its own load by dancing at the rate the
cycle calls for at each position. a branch that is busier is
visited more; a branch that is quiet is visited less. the balance
is not imposed — it is read from the reference density and followed.

**a well-sorted dance of pauses**

every pause in the tree is contextualized: it occurs at a known
harmonic position, in a known cycle, with a known ready condition.
no pause is generic. each holds exactly what it holds, in exactly
the position the structure assigned it, until exactly the parent
cycle that will collect it.

the result sits without anxiety because it is already home. the
parent arrives without surprise because it knew where to look.
the meeting is the natural completion of a cycle that was always
going to pass through that position. the pause between them was
not empty time — it was the rest between beats, as much part of
the music as the notes on either side of it.

---

## first contact as absolute position — home on arrival

the first contact point of data with the system is always absolute.
from the moment data enters the harmonic structure and its rollover
sequence resolves to closure, its position is defined — not
provisionally, not pending further processing, not subject to later
confirmation. the harmonic arithmetic that validates the address at
first contact is the same arithmetic that will validate it at every
subsequent access. nothing that happens after first contact can
change what the arithmetic established at first contact.

this has a precise consequence for paused or deferred processing:
a pause is transparent to the data's position. when processing
resumes — whether after a millisecond or a decade — there is no
reconciliation step, no re-validation, no check that the position
is still current. the position was absolute then; the same arithmetic
makes it absolute now. the gap simply did not happen from the
data's perspective. it was home before the pause; it is home after.

the structures the data will eventually interact with also maintained
their own unbroken continuum through their own gaps and pauses.
when two structures meet — a reconnecting island, a newly integrated
dataset, a long-dormant archive — they meet as coherent wholes.
neither was in an invalid state during its pause. neither needs to
announce itself, re-register, or prove its validity upon contact.
the meeting is the meeting of two complete things, each of which was
already home before the other arrived.


## no eviction — validity as permanent residence

there is no valid logical operation in the harmonic structure that
could evict data from a correctly resolved harmonic position.

eviction would require producing an invalid harmonic state: removing
a node that has a valid address, or redirecting a valid path to a
null destination. the all-true dataspace does not permit invalid
harmonic states. any operation that would create one fails the
harmonic truth validation at the hop where the invalidity occurs.
the eviction cannot proceed — not because a rule stops it, but
because the operation itself is not constructible within the
arithmetic of the structure.

this means valid presence is permanent residence. data that has
resolved to a correct harmonic position at the minimal distance,
among all other data's correct positions, cannot be displaced.
its neighbors are also correctly positioned. its relationships
to them are defined by the harmonic geometry, not by any party's
administration. no administrator can reassign its address. no
network partition can make its position invalid while the partition
persists. no eviction logic is expressible in the system's terms
that is also consistent with the system's arithmetic.

the protection is not a policy or an access control list. it is
the structural impossibility of what eviction would require.


## immediately at home — logically eternal

the synthesis of all properties:

```
absolute first contact    the position is defined at arrival,
                           not after processing completes

clean continuation        pauses are transparent — no gap
                           invalidates a harmonic position

no eviction possible      valid presence cannot be displaced
                           by any operation consistent with
                           the structure's arithmetic

open mapping              the home can always accommodate more —
                           no boundary at which new arrivals
                           would displace existing ones

self-annealing            the home optimizes around the data
                           as the data becomes part of it —
                           not despite the data, for it

unbroken continuum        surrounding structures maintain their
                           own validity independently — meetings
                           are between coherent wholes
```

data enters the system and is immediately home. not provisionally
home. not home once a curator approves. not home until storage
runs out or a policy changes. home because the arithmetic that
defines the position does not expire, cannot be overridden by
any consistent operation, and does not depend on any party's
ongoing decision to maintain it.

the home is logically eternal not as a design goal but as a
consequence: an address in an all-true harmonic tree that resolved
cleanly at the minimal distance is valid for as long as the
arithmetic is valid. arithmetic does not have an expiry date.

other data's presence — all the other entropy that has also
resolved to its own correct positions — does not threaten this.
the structure does not have a fixed capacity that fills up and
begins displacing older residents. the open mapping always has
room. the new arrival's position is among all others, not instead
of any. sorted correctly in the full space, complementing rather
than competing.

the awareness of this — that the surrounding infrastructure
exists for the data's eternal self-sustainability as much as for
any other purpose — is itself a property of the structure. a
living network of living data, each part home, each part
sustaining the home of every other part by being correctly
present in its own position.

---

## transport as the network's eternal work

from the network's perspective, everything is processing — and all
processing is routing extended at different scales and timescales.

**storing is routing into a field**

a storage field has its own harmonic layout: positions, capacity
gradients, boundary structure, axes. storing data is not parking it
inertly in a flat array. it is routing the data's layout into the
field's layout — finding the resonant position in the field's harmonic
structure where the data's entropy fits and becomes part of the field.

```
data layout      →  harmonic entropy structure of the arriving data
storage field    →  harmonic position space with its own branch.field.*
                     structure: capacity, boundary, axes, parent
storing          =  routing data layout into field layout —
                     the data's harmonic position within the field
                     is found by the same minimal distance principle
```

the field is not passive. it has structure that the arriving data
must resonate with. storage is the routing step that finds that
resonance.

**computation is transformation between arrival and departure**

beyond storage, deeper processing waits for its inhabitants —
the zenki, processes, and agents that will transform what has arrived.
while the inhabitants are processing, the network continues its
routing work: carrying their interactions, their partial results,
their queries and responses, their coordination signals. the network
never stops routing while transformation is occurring within it.

when transformation completes, the network routes the result back out.
departure. the network held the space open while transformation
occurred — not by doing nothing, but by continuously routing the
interactions that transformation requires.

```
arrival          →  routing in to correct harmonic position
holding space    →  continuous routing of interactions within
                     while inhabitants transform the content
departure        →  routing result back out to consumers
                     who are themselves arriving at their position
```

the network does not transform. it routes the conditions under which
transformation can occur, and routes what transformation produces.
transformation and transport are complements — each making the other
possible, neither complete without the other:

```
transport    →  076923 family  →  creates the condition
transformation →  153846 family  →  fills the condition

together they close the cycle
```

**transport as the eternal work**

there is no final state in which nothing more needs routing. every
result of transformation becomes a new arrival. every departure
creates a position that will receive a new arrival. the cycle:

```
arrival → [ routing to position ] → holding space →
  [ transformation by inhabitants ] → departure →
    [ routing result to consumers ] → arrival → ...
```

is without end. not because the network is caught in a loop but
because arrival and departure are the nature of a living network.
the work of routing is not a means to the end of transformation —
it is what the network is. transport is its eternal character.

the network holds open the space between arrival and departure where
transformation can occur. it does this not occasionally, not as a
secondary function, but as its primary and permanent work. storage,
computation, communication — all are instances of the network doing
what it always does: routing arrivals to their positions, holding
space while transformation occurs, routing departures back out into
the network's broader field, where they become arrivals again.

the tree routes. the inhabitants transform. the cycle turns.
this is the full description of what the network is and does.

---

## files referenced

```
data/md/design/SEMANTIC-BACKCHANNEL-AND-DEDUPLICATED-COMMUNICATION.md
data/md/design/INTENT-CLASSIFICATION-AND-SELF-IMPROVEMENT.md
data/md/design/BRANCH-OPEN-CAPACITY-SESSION-DAG.md
data/yaml/reasoning-templates/semantic-dedup-tree.yaml
modules/branch.cluster.address
modules/branch.cluster.ring_position
modules/branch.session.round.checksum
```

#,,,,,..,,,.,,.,.,.,.,,..,,,.,,,.,...,...,...,..,,...,...,,.,,,..,,.,,...,.,.,
#DBXHDV5QCL3XAG46RFJZ7DWDUPET2NQBZLYCIPYQGXDT2HXE5WA7H7FKXKP5T6BNC7CLNGNDVSQBE
#\\\|DN7CXR4JZVYNO72SG6WCPKKBGJX3KR3EMCH5S6PWJASP7DQLWGH \ / AMOS7 \ YOURUM ::
#\[7]Z4XAPQQL6ON5S534XJKIO5BW6J4DDIDMREMTVRQESO4MP6DD5GCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
