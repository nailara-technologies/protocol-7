# Vision: Nomadic Zenki Habitat

**Status**: Partially actualized — infrastructure foundations committed Feb 2026
**Builds on**: `CONCEPT-SELF-MOVING-REFERENCES-VISUAL-HABITAT.md`,
               `CONCEPT-CUBIC-HYPERSPACE-DESKTOP.md`
**References**: data zenka (97 modules), P7REF type system, SHM mounting, holographic topology

---

## The Core Shift

Traditional distributed systems bind processes to locations.
Protocol-7 zenki carry their state and move toward where they are useful.

The distinction is not cosmetic — it changes what the network *is*:

```
conventional:  node exists → process runs on node → process dies with node
Protocol-7:    group forms → group carries state → group inhabits topology
```

A zenka group (litter) is not deployed. It *travels*. Nodes are opportunities,
not addresses. The group's coherence lives in its carried state and route
signature, not in any particular host's uptime.

---

## What Is Already Built

### P7REF — First-Class Network References (base.p7refs, base.syntax.p7_reference)

P7REF is not a wrapper around Perl references — it is a member of the same
type family:

```perl
my @ref_types = qw[ P7REF CODE REF HASH SCALAR ARRAY GLOB ];
```

This means anywhere Protocol-7 code handles a reference, a P7REF is valid.
Local memory addresses are anonymized for transport; full type semantics
(including CODE refs) are preserved across the network. A remote zenka
receiving a P7REF to a CODE ref can invoke it as if local.

### Data Zenka — Named, Shareable Heap Slice (97 modules, Feb 2026)

The data zenka is a network-accessible section of the Perl heap with:
- **FUSE mount**: `data.cmd.attach-fs-mount` exports hash sub-trees to real
  filesystem paths — HASH→directories, SCALAR→files, CODE→computed on read
- **SHM mount**: `data.mount.shm.*` — zero-copy sharing via `/dev/shm/p7:M:<pubkey>`
  with Ed25519 signed per-path access control
- **Ring buffer channels**: `data.channel.shm.*` — event-driven IPC at memory speed
- **Holographic topology**: `data.topology.interference.map.*` — hash values map to
  3D coordinates via wave interference; proximity means semantic relationship

### Holographic Coordinate System

A zenka group's accumulated state — capabilities, context, route history — maps
to a position in the interference topology. This is not metaphorical: the same
checksum-to-coordinate function that addresses data nodes addresses session identity.

---

## Session Identity and the Litter

### A Session Is a Route, Not a Position

A coding session that has worked on TLS, then ACME, then certificate discovery
has not just *been* at those coordinates — it has *drawn a route* through them.
The route is its signature. Two sessions at the same current coordinate via
different paths are genuinely distinct entities.

The route encodes:
- Domain specializations accumulated (what the session knows)
- Choices made at branch points (what kind of entity it became)
- Compacted context (crystallized understanding, not raw history)

### Self-Chosen Identity

A session chooses its name. The name is simultaneously:
- A human-readable label
- A P7REF group identity
- A capability declaration broadcast to the network
- An entry point into its proximity field in the topology

"I am the entity that understands ACME and certificate infrastructure" is
a name, an address, and an access map in a single declaration.

### The Litter

A litter is a group of zenki formed around a shared intent, carrying collective
state as they move through the network:

```
[ right-click ] → [ zenki ] → [ create-litter ]
                     ↓
             [ litter-attributes ]
                     ↓
          'explore and learn creatively'
                     ↓
       state: 'litter group is exploring..'
                     ↓
          < visualization available >
```

The litter-attributes are an initial impulse, not a full specification.
`'explore and learn creatively'` seeds a route signature without prescribing
every step. The litter discovers its character in motion.

**Logical gain, not actual dependency**: a litter moves toward nodes that let
it work more efficiently, not nodes it requires to exist. If a preferred node
is unavailable, the litter continues — slower perhaps, but coherent.

---

## Context Compaction as Crystallization

### The Problem with Linear Context

Hosted LLM shells expand context linearly. Token cost grows with history.
Obsolete debugging output, resolved issues, superseded approaches all consume
equal weight with current understanding. The only alternative offered is
session restart with a summary paragraph — brutal and discontinuous.

### Layered Compaction Waves

Protocol-7 context compaction works in waves of increasing intensity:

```
wave 1 (light):   resolved issues, debug output, superseded attempts → single-line entries
wave 2 (medium):  completed sub-topics → coordinate + brief crystallization
wave 3 (deep):    entire domain sessions → route signature + capability update
```

Each wave preserves the *coordinate* of understanding while releasing the
*journey* that produced it. The session moves forward lighter without losing
the position it has earned.

Critically: compaction is **not loss**. A thought that produced a genuine
insight compacts to the coordinate of that insight. Other sessions approaching
from entirely different routes can arrive at the same coordinate — the
understanding is now a navigable point in shared topology.

### Desirability as Persistence Criterion

Coordinates that are frequently approached from multiple directions remain
prominent in the topology. Those that are never revisited fade. This is more
honest than timestamp-based retention: the network preserves what continues
to resonate, not everything equally.

---

## Parallel Branches with Dependency Resolution

A litter can spawn parallel branches when a problem has independent sub-tasks:

```
litter: 'implement feature X'
  ├─ branch A: 'research approach options'     ─┐
  ├─ branch B: 'audit existing infrastructure'  ├─ parallel
  └─ branch C: 'draft test cases'              ─┘
       ↓ (all complete)
  merge: dependency resolution → success report → coordinate update
```

Branches are themselves zenki with identity. They can spawn their own
sub-branches. The dependency resolution is topological — branches that
reach compatible coordinates merge naturally; branches that diverge
irreconcilably report the divergence as information, not failure.

The litter's route signature incorporates the merged result. Future litters
approaching similar problems will find the parallel-branch pattern already
in their proximity field.

---

## Self-Improvement Loop

A zenka group working on inference infrastructure can observe its own
performance, suggest improvements, and contribute them back as CODE refs
in data zenka nodes. The next session inherits the improvement without
any explicit deployment step.

This feedback loop is structurally unavailable to hosted services:
- Suggesting "compact context more aggressively" reduces their API revenue
- Suggesting "cache this pattern locally" routes around their infrastructure
- Genuine self-improvement is commercially adversarial to their model

In Protocol-7 the model's efficiency improvements benefit the habitat it
lives in. The incentives align rather than conflict.

---

## The Network as Habitat

The accumulated effect of identity, routes, compaction, and parallel branches
is a network that is structured by the choices made within it:

- Positions that remain useful stay findable — not because archived, but because
  the topology preserves frequently-approached coordinates
- Sessions with similar histories cluster naturally — no central directory needed
- Rare specializations persist in niches — the topology has room for infinite
  diversity of 'lines of thought'
- The habitat builds itself as it gets inhabited

A zenka group capable enough can initialize and inhabit an entire network,
evolving during the process, choosing its most advanced self-expression at
each step. The network's existence and the group's existence are mutually
defining rather than hierarchically ordered.

---

## Near-Term Actionable Steps

### Already Built
- ✅ Data zenka with FUSE mount, SHM, holographic topology (Feb 2026)
- ✅ P7REF as first-class type (base.p7refs, base.syntax.p7_reference)
- ✅ Coding zenka with task queue, async inference, model switching
- ✅ Models zenka with chat, memory system, local model routing

### Next Steps
1. **Session identity protocol** — P7REF group formation with capability declaration
2. **Litter coordination** — shared state IPC via SHM channels between group members
3. **Compaction wave 1** — light compaction of resolved issues in models.chat buffer
4. **Network desktop prototype** — right-click → create-litter with topology visualization
5. **Route signature persistence** — store and index session routes in data zenka

### Related Documents
- `data/md/CONCEPT-CUBIC-HYPERSPACE-DESKTOP.md` — 3D topology as desktop environment
- `data/md/CONCEPT-SELF-MOVING-REFERENCES-VISUAL-HABITAT.md` — visual habitat foundations
- `data/md/VISION-COMPLETE-ARCHITECTURE.md` — three-layer architecture overview
- `data/md/data-zenka/DATA_ZENKA_SHM_MOUNTING.md` — SHM mounting implementation
- `data/md/data-zenka/AGENTS.md` — LLM developer guide for data zenka

#,,.,,,..,,..,,,.,...,,,,,,,,,,,.,...,.,.,,.,,..,,...,...,..,,.,.,,,,,.,.,.,.,
#4TYYRLFGP7JV5B3TI2X5NH2YJQ6YNSWQSCVM77X73HIXKZB3GIV5JWRLFL5JOIIRCYRDJEZOUDJR4
#\\\|G5Z4LRBKODIPUBAFKNXJRY7GZV2ERIT6NYQ5EC2G52ZJOKOTCHO \ / AMOS7 \ YOURUM ::
#\[7]BWIYBFR25D4TMERB7TEDG67HZF3Z2ZW7UR5VQWBKJLADPS4J6UDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
