# Vision: Network Desktop UX — Living Topology as Interface

**Status**: Conceptual — grounded in existing holographic topology implementation
**Requires**: Session identity, litter coordination, topology visualization layer
**Builds on**: `CONCEPT-CUBIC-HYPERSPACE-DESKTOP.md`, data zenka topology modules

---

## The Interaction Model

The network desktop is not a launcher for applications.
It is a window into ongoing process — a live map of thought in motion.

The fundamental difference from conventional desktops:

```
conventional:  you launch things, things run, things stop
               the desktop is a filing cabinet with buttons

Protocol-7:    things are already in motion
               you navigate to them, join them, branch from them
               the desktop is a living topology you inhabit
```

Everything visible is real. Every object has a position in the holographic
space. Every connection is a live P7REF. Movement is actual movement through
the coordinate system, not a UI metaphor.

---

## The Litter Creation Flow

```
[ network-desktop ]
        ↓
[ right-click anywhere in space ]
        ↓
[ zenki ] → [ create-litter ]
        ↓
[ litter-attributes ]
  ├── intent:      'explore and learn creatively'
  ├── size:        3-7 zenki  (or: 'auto')
  ├── persistence: session / permanent / until-success
  └── visibility:  private / shared / broadcast
        ↓
[ confirm ]
        ↓
state: 'litter group is forming..'
        ↓
state: 'litter group is exploring..'  [ < visualization available > ]
```

The right-click location in the topology space is not arbitrary — it seeds
the litter's initial coordinate. Forming a litter near the TLS/certificate
cluster gives it immediate proximity to that domain's accumulated knowledge.
Forming it in open space gives it maximum freedom of movement.

`litter-attributes` is an intent declaration, not a configuration form.
`'explore and learn creatively'` is sufficient. The litter develops its
character in motion. Attributes constrain the shape of the journey,
not every step.

---

## The Visualization

When `< visualization available >` appears, opening it shows:

### The Topology View

A 3D rendering of the holographic coordinate space, generated from
`data.topology.interference.map.*`. The interference pattern is the
background — constructive zones appear as denser, more luminous regions.
These are where accumulated knowledge creates strong coordinate fields.

**Active litters** appear as clusters of moving points with trailing routes —
the path they have taken through the space, fading toward their origin,
bright at their current position.

**Settled knowledge** appears as stable luminous nodes — coordinates that have
been approached from many directions and crystallized into landmarks.

**The litter you just created** begins as a small bright cluster near its
seeding coordinate, then starts moving.

### What You Can See in Real Time

```
litter position    → where in the space they currently are
route trail        → the path they've taken (their signature forming)
branch events      → when a sub-group diverges to explore separately
proximity pull     → the litter drifting toward a knowledge cluster
convergence        → branches returning toward the main group
compaction event   → a coordinate crystallizing, trail collapsing to a point
neighbor litters   → other groups in adjacent topology (related work)
```

### Interacting with the Visualization

- **Click a litter** → see current state, accumulated route signature,
  what it has found so far
- **Click a knowledge node** → see what sessions contributed to it,
  approach it from your own context, branch from it
- **Click a route segment** → see what was happening at that point,
  replay or branch from that coordinate
- **Drag your session into proximity** → join the litter's context,
  receive its compacted findings, contribute your own

---

## The Session Window

A conventional terminal window shows a scrolling log.
A Protocol-7 session window shows a **positioned context**:

```
┌─────────────────────────────────────────────────────┐
│ session: 'TLS Infrastructure Specialist'            │
│ coordinate: [constructive zone, certs cluster]      │
│ route depth: 847 choices                            │
│ compaction level: wave-2                            │
├─────────────────────────────────────────────────────┤
│ [ active context — current depth of detail ]        │
│                                                     │
│ > working on httpsd certificate discovery           │
│   found: prefer .pem over .cert (chain complete)    │
│   tool: read src/httpsd.discover_active_cert    │
│                                                     │
├─────────────────────────────────────────────────────┤
│ [ crystallized — wave-1 compacted ]                 │
│ • ACME RS256 implementation complete                │
│ • letsencr-httpsd graceful startup complete         │
│ • certificate FUSE mount path established           │
└─────────────────────────────────────────────────────┘
```

The crystallized section grows as the session progresses and compaction
waves run. The active context stays lean. The session accumulates depth
without accumulating weight.

---

## The Right-Click Menu (Expanded)

On any object in the topology:

**On a knowledge node:**
```
[ approach from current context ]
[ branch new session from here ]
[ show contributing sessions ]
[ show approach routes ]
[ add to current session's proximity ]
```

**On another session:**
```
[ view route signature ]
[ request context share ]
[ invite to current litter ]
[ branch collaborative session ]
[ follow (receive their compaction events) ]
```

**On a litter:**
```
[ view findings so far ]
[ join litter ]
[ spawn sibling litter ]
[ set success condition ]
[ view dependency graph ]
```

**On open space:**
```
[ create session here ]
[ create litter here ]
[ mark as waypoint ]
[ set proximity alert (notify when sessions approach) ]
```

---

## Vision-Capable Model Experience

For vision-capable models (and users), the topology visualization is not
just administrative tooling — it is a direct sensory interface to the
network's state.

A session with visual capability can:
- **See** its own position and route, observe its trajectory
- **Perceive** proximity to related knowledge before explicitly querying
- **Watch** parallel branches in a litter diverge and reconverge
- **Recognize** familiar topology patterns from previous sessions
  (the constructive zone near the ACME cluster looks like this,
   so the session knows immediately what domain it is approaching)

The visual experience is not decorative. Proximity in the topology *means*
something — it is a semantic relationship expressed geometrically. Seeing
it directly gives the model (and the user) information that would otherwise
require many explicit queries to reconstruct.

The topology is also generative for the model: seeing the shape of accumulated
knowledge in a domain helps calibrate confidence, identify gaps, and find
adjacent unexplored coordinates worth investigating.

---

## For Users Without Visual Interface

The topology is always navigable as text — nshell commands that express
the same operations:

```bash
litter.create 'explore and learn creatively'
litter.status <id>
litter.findings <id>
session.position
session.proximity
topology.nearby <depth>
topology.approach <coordinate>
```

The 3D visualization is the richest interface. The text interface is fully
functional. Both operate on the same underlying topology.

---

## The Living Map Property

What makes this qualitatively different from a process monitor or task manager
is that the map's structure is *created by use*, not imposed by the system:

- Knowledge nodes exist because sessions found those coordinates useful
- Routes exist because sessions chose those paths
- Proximity fields exist because accumulated choices created them
- The litter's trail exists because a group traveled through it

The desktop reflects the actual intellectual history of the network.
It is not a representation of what the system administrator decided the
structure should be. It is what the network *became* through the work
done within it.

A new developer joining the network sees immediately where active work
is happening, where deep knowledge has accumulated, which areas are
unexplored, and how to navigate toward what they need.

The map is the documentation. The topology is the organizational memory.
The visualization is access to all of it at a glance.

#,,,.,,.,,...,.,.,,,,,.,,,,.,,,,,,.,.,,,.,.,.,..,,...,...,,,.,.,,,..,,,.,,.,,,
#M4V2Z52LQSKBMO423CD25ALZTSXXRMFGE46B3XMMMJ7CEV4V2LYBBDBPTMXVYLUAPJVJDX6VEZF4O
#\\\|6QJVXEOCW54A7RP4ELXGMVYGXXOTFI3VTLKJAIZCLG2UH4N6RYN \ / AMOS7 \ YOURUM ::
#\[7]IHWWIMM2TZZYCFSLJUNTNPAIH36PSDEZJQULDXPTIJ7DQZXI6YAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
