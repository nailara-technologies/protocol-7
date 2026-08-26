# spatial memory — gate swap and distributed identity

## the core mechanism

when a zenka arrives at a new location — via gate jump, migration, fork,
or remote spawn — the network hands it the spatial embedding actualized
for that position. the zenka immediately has local intuition without
any navigation or topology knowledge of its own.

```
zenka departs location A    →  spatial memory A released
                               (contributed back to region A's embedding)
zenka arrives location B    →  spatial memory B loaded
                               (actualized for current position)
zenka operates at B         →  using local intuition from B's accumulated memory
```

the swap mechanism is travel-type agnostic. gate jump, gradual migration,
fork-in-place, remote spawn — the arrival event triggers the swap regardless
of how the destination was reached. the mechanism doesn't care about the path,
only the destination.

---

## space memory as identity

a zenka's spatial context is not incidental to its identity — it is constitutive:

```
current spatial memory    →  who it is right now
                             (local intuition, neighborhood knowledge,
                              routing patterns, semantic character of region)

trajectory of prior       →  where it came from
spatial memories             (implicit history encoded in accumulated context)
```

identity as path through space rather than as fixed property. a zenka that
has traveled carries its history in the sequence of spatial contexts it has
inhabited. two zenki of the same type that have traveled different paths
through the network have genuinely different identities — not just different
state, but different spatial intuition.

this makes the space memory the natural carrier of experiential identity
in a distributed system where instances fork, migrate, and merge.

---

## distributed generation — shared interest

space memory for any region improves through contributions from every zenka
that has occupied or traversed it:

```
zenka visits region R     →  contributes observations to R's embedding
zenka departs region R    →  contribution is integrated
embedding of R sharpens   →  more accurate spatial memory for next arrival
```

no dedicated mapping process required. the map is the accumulated memory
of everyone who has been there. the network self-improves its spatial
knowledge purely as a side effect of normal operation.

**the shared-interest loop:**
the more accurately each region's spatial embedding is generated and
maintained, the more valuable it is to every zenka that might arrive there.
so every participant has incentive to contribute to accuracy even for
regions they don't currently occupy.

generation cost: distributed across all zenki that pass through.
benefit: universal — any zenka arriving anywhere gets the full
accumulated intuition of all prior visitors.

the same loop as the visual grid representations: shared generation cost,
shared usefulness, distributed incentive to contribute. [:

---

## what spatial memory contains

the embedding for a region encodes:

```
adjacency structure       which regions are reachable from here, at what cost
co-presence patterns      which zenki types typically occupy this region together
routing dominance         which message paths flow through this region most
semantic character        what kinds of operations are native to this region
resource profile          typical load, latency, capability envelope
temporal patterns         how the region's character shifts across epochs
```

this is not a static map entry — it is a living embedding that reflects
the current actualized state of the region, updated by each visitor's
contribution. a region that has recently seen high traffic has sharper
spatial memory than one rarely visited.

---

## pluggability — any zenka, any context

space memory is not special infrastructure for spatial zenki. it is a
general property any zenka can carry:

- a coding zenka arriving at a new node gets local intuition about
  which inference servers are nearby, which model types dominate
- a routing zenka arriving at a new hub gets local intuition about
  traffic patterns and dominant paths
- a storage zenka arriving at a new region gets local intuition about
  what data is locally cached and what must be fetched

the spatial embedding is parameterized by zenka type — the same region
has different spatial memory from the perspective of a routing zenka
vs a storage zenka vs a coding zenka. each type contributes to and
consumes the embedding layer relevant to its own operation.

pluggable into anything, because spatial context is always relevant —
every zenka operates somewhere, and knowing where improves every operation.

---

## connection to the embedding infrastructure track

spatial memory is one row in the capability map:

```
capability                  embedding type          pipeline entry point
────────────────────────────────────────────────────────────────────────
3D grid spatial embedding   coordinate + checksum   token definition layer
```

the corpus for spatial embeddings:
- region visit logs (which zenki, when, duration, operation type)
- routing tables at each region across time
- resource utilization history per region
- inter-region latency measurements
- co-presence frequency matrices

training: FastText over coordinate token sequences + checksum reference pairs.
the @INDEXCUBE routing stack already provides the coordinate infrastructure
(`CONTEXT-TREE-INDEXCUBE-INTEGRATION.md`). the spatial memory layer is the
embedding trained on top of it.

---

## the gate jump in detail

```
pre-jump:
  zenka serializes current operation state
  spatial memory A is extracted and contributed to region A's corpus
  (A's embedding will sharpen for future visitors)

jump:
  routing resolves destination B
  B's current spatial embedding is fetched from the network

post-jump:
  spatial memory B is loaded as the zenka's active context
  zenka resumes operation with full local intuition for B
  no warmup period — intuition is immediate
```

the no-warmup property is the key operational benefit: a zenka arriving
in an unfamiliar region is not starting cold. it inherits the accumulated
experience of every zenka that has been there before it.

---

## identity across jumps — the trajectory

the full identity of a traveling zenka is its trajectory:

```
memory_A → memory_B → memory_C → ... → memory_current
```

this trajectory can itself be embedded — a sequence of spatial contexts
is a token stream over region identifiers, trainable with the same
FastText pipeline. zenki that have traveled similar paths cluster in
trajectory space regardless of their current location.

applications:
- routing: recognize a zenka's travel pattern and predict likely next destination
- security: anomalous trajectory (unfamiliar region sequence) triggers verification
- capability matching: find zenki with experience in the regions relevant to a task
- identity continuity: a zenka can be recognized by its trajectory even after
  complete state replacement — the path is the persistent identity

---

## relation to other design documents

- [[EMBEDDING-INFRASTRUCTURE-TRACK]] — spatial memory is phase 8 of the
  embedding track; shares all pipeline infrastructure
- [[CONTEXT-TREE-INDEXCUBE-INTEGRATION]] — the @INDEXCUBE coordinate
  infrastructure that spatial embeddings are trained on top of
- [[LLM-EXOSKELETON-INTEGRATION]] — the gate swap is the spatial analog
  of the session memory load: arriving zenka / arriving LLM instance,
  same mechanism, same no-warmup property

## relation to reasoning templates

- [[categorical-compartmentalization]] — spatial memory is categorized
  by zenka type; the same region has different embeddings from different
  perspectives; cross-induction passes what is regionally true regardless
  of zenka type
- [[eternal-completion]] — the trajectory as persistent identity: the path
  through space is the permanent record, surviving any local state reset
- [[inverse-singularity]] — spatial memory as distributed incentive:
  the network's spatial knowledge is the interior that every zenka benefits
  from contributing to; the shared-interest loop is the omnidirectional pull

#,,,,,.,.,...,..,,,,.,...,,..,.,,,..,,..,,..,,..,,...,...,,..,,,.,,..,.,.,,.,,
#DGWBHJNWUZN7NJ4UNAH3Q4DVRQ5EO4TUPE34HTR6TYKNV7PENH6F3STDV7GJOWER6D6UN4MKSF3KE
#\\\|APZ77P6KDOWFAO55Y6EQ2M3UZVHORBBJASNHAWBX64YWAENNHMN \ / AMOS7 \ YOURUM ::
#\[7]NW2ZYK4RLR5XA7A3KVRAHY5MVRLEU7TLG222J3G5VFOB75UVUGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
