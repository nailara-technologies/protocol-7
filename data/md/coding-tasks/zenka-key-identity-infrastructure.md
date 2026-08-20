
 .:[  zenka C25519 key identity and task infrastructure  ]:.

## Core Insight

Zenki already have C25519 key infrastructure. The extension: give each zenka
a fully-featured identity that can manage its own task trees, sign decisions,
and route encrypted messages — regardless of whether it has direct LLM access,
because it always has indirect access through the network.

## Key-as-Directory : The Routing Primitive

The public key IS the task directory name:

```
tasks/
  <pubkey-A>/              ## zenka-A's task space
    secret.enc             ## secret key, encrypted for parent key
    <pubkey-B>/            ## subtask delegated to zenka-B
      secret.enc           ## B's secret, encrypted for A's key
      <pubkey-C>/          ## sub-subtask
        secret.enc
        payload.enc        ## encrypted message body
```

**Routing guarantee**: to deliver a message to a task, check if its public key
exists as a directory — O(1) filesystem lookup. If present, the recipient can
decrypt. If the directory is deleted, the secret key is irrecoverable — any
later incoming packet cannot be intercepted even by the target zenka. Deletion
is a hard capability revocation with no recovery path.

**Unencrypted messages** also use the directory as boundary — even plaintext
payloads placed inside are scoped to that key's namespace. Encryption can be
applied later by the directory owner using the key already present.

## Task Session = Key Pair

Each task session gets its own ephemeral C25519 key pair:

- Public key → directory name → routing address → capability scope
- Secret key → encrypted for parent key → stored inside the directory
- Parent can always read child task state; child cannot read parent

This gives a natural **capability hierarchy**:
- Root zenka key signs task creation
- Task key signs subtask delegation
- Subtask key signs completion or further delegation
- Any zenka in the chain can verify ancestry without a central authority

## Zenka Task Capabilities [ regardless of LLM access ]

Each zenka manages:

```
zenka.tasks.own          ## tasks this zenka initiated
zenka.tasks.delegated    ## tasks assigned to this zenka by others
zenka.tasks.watching     ## tasks this zenka tracks without owning
zenka.tasks.signed       ## design decisions signed with own key
```

A zenka without direct LLM access contributes through:
- Routing tasks to zenki that DO have LLM access
- Signing completion confirmations when its own domain succeeds
- Accumulating a verifiable history of task outcomes

Groups of zenki can collectively advance a task — any member signing a
contribution advances the task tree, and the signature chain is the audit log.

## Task Content : Structured Agent Memory

Inside each task directory, alongside the key material:

```
tasks/<pubkey>/
  secret.enc             ## secret key encrypted for parent
  task.yaml              ## task description, priority, status
  decisions/             ## signed design decisions
    <sig-hash>.signed    ## each a signed statement
  replies/               ## contributions from other zenki
    <pubkey-contributor>/
      contribution.enc   ## encrypted reply to this task key
  subtasks/              ## delegated work
    <pubkey-subtask>/    ## each a full key-directory
```

This gives zenki:
- Bug lists
- Feature wish lists
- Task priority tables
- Design decision history with cryptographic authorship
- Contribution trees from other zenki

All of it navigable by key hierarchy, all of it verifiable without a
central server, all of it revocable by directory deletion.

## Routing Properties

- **Fast lookup**: directory existence check is the routing table
- **Capability scoped**: possession of parent key = read access to child
- **Hard revocation**: delete directory = destroy decryption capability
  for all future messages to that task, permanently
- **Offline-capable**: the directory tree is the protocol state —
  no running service needed to inspect or traverse it
- **LAN-distributable**: the key-directory tree can be replicated across
  hosts, with last-write-wins or signature-ordering for conflict resolution

## Connection to Existing Infrastructure

- C25519 implementation: `src/crypt.C25519.*` — already present
- User keys: `src/USR.[username].*` pattern — zenka keys follow same pattern
- AMOS7 checksums: task directory names could use AMOS7 of pubkey for
  shorter, human-readable routing addresses while full pubkey remains canonical
- Data zenka FUSE mount: task trees become accessible as filesystem paths
  transparently across the network
- Harmonic topology: task delegation trees map naturally onto the CCW routing
  matrix and cubic topology already explored in harmonic mathematics session

## Emergent Properties

A zenka accumulating signed task completions over time builds a
**verifiable capability reputation** — other zenki can inspect its task
history and make routing decisions based on demonstrated competence in
specific domains, without any central registry.

The key tree IS the organisation chart, the audit log, and the routing
table simultaneously. Adding a zenka to a task = creating a subdirectory.
Removing it = deleting that subtree. The structure enforces the access
model by construction.

## Multicast Namespace Sharding

Rather than a flat key-space, senders compute a multicast group from the recipient
pubkey — no registry lookup needed:

```
multicast_group = AMOS7_CHKSUM( pubkey )[0..1]   ## first 1-2 chars of AMOS7 checksum
```

- **Sender-local computation**: any zenka can derive the group from a public key alone
- **No directory service required**: group membership is implicit, derivable by anyone
- **Entropy**: AMOS7 over 36^4 space → natural, collision-resistant distribution
- **Implicit load balancing**: task key density distributes evenly across groups
  without any coordinator
- **CCW topology alignment**: multicast groups map directly onto the CCW routing
  matrix explored in the harmonic mathematics session — spatial locality for free

### Checksum Width and Cube Addressing

The group discriminator width is adjustable:

```
2 base32 chars → 36^2 = 1296 groups  [ 1 byte boundary: maps to 256 ]
3 base32 chars → 36^3 = 46656 groups [ finer sharding, still compact ]
```

**2-char width** is particularly interesting: two base32 characters encode exactly
one full byte (0–255), which maps directly onto one axis of the 255×255×255 cubic
addressing space explored in the harmonic topology session. A task's multicast group
becomes a coordinate on that cube — the routing table IS the cube face, with no
translation layer needed.

This also keeps short route announcements compact: a 2-byte group discriminator in
a UDP multicast header fits in the first word, leaving the rest for the pubkey hash.

### Path Announcement (Optional, Pull-Based Replication)

The nodes zenka currently tracks host presence from discover multicast observations.
The same infrastructure could carry short routing path announcements — host-to-group
affinity, updated as task directories migrate:

- **Not required for routing**: multicast delivery already works without it; any
  sender computes the group and sends — no directory needed
- **Useful for pull replication**: a host wanting to replicate a task directory can
  ask "which hosts recently handled group XY?" and get a short candidate list
- **Reduced width attractive here**: 2-3 char group IDs keep announcement payloads
  minimal; the nodes zenka's existing presence table gains a group column with
  negligible overhead
- **Not a single point of failure**: announcements are advisory; routing falls back
  to multicast broadcast if the nodes table is stale or absent

### Quantity-Based Attack Resistance

A flood directed at one multicast group cannot be silently forwarded — the receiving
hop detects the excess immediately and triggers forensics. The originating pubkey is
already known from the signed payload: no source-obscuring relay is possible when
the delivery proof requires the sender's key. High-volume attacks are self-identifying
by construction.

## Self-Assembling Route Logs

Each task directory contains a world-appendable `log/` subdirectory:

```
tasks/<pubkey>/
  log/                     ## world-appendable, no key required to add
    <timestamp>-<hop>.entry ## signed, timestamped forwarding record
```

Forwarding zenkas write a signed entry as they relay the task directory:

```yaml
timestamp: 1741478400
hop_pubkey: <forwarder-pubkey>
from_host:  host-A
to_host:    host-B
task_pubkey: <task-pubkey>
signature:  <sig-of-above-fields>
```

### Why This Matters

- **Locality of reference**: the route log travels WITH the task directory —
  wherever the directory arrives, its full transit history is already present
- **No meta-log problem**: conventional distributed logging requires a separate
  log directory per host, then a meta-log to find all log shards, then a
  meta-meta-log to find the meta-logs — each layer needs its own lookup chain
- **Append-only without capability**: forwarding nodes need no key to append;
  they cannot read encrypted payloads, but they CAN record their participation
- **Audit without coordination**: any node with the task directory reconstructs
  the full route from the log entries, verifying each hop's signature independently
- **Complements key chain resolution**: the discover zenka's existing signature
  chain resolution already walks the key ancestry — the route log adds the
  spatial/temporal forwarding trace alongside the cryptographic ancestry
- **nodes zenka integration**: the nodes zenka tracks announced hosts that the
  discover zenka observed over multicast — it already has the host presence map
  that short route announcements would populate. path announcement (host → group
  affinity) could be layered onto the existing nodes/discover infrastructure
  rather than built separately

## Implementation Phases

1. **Key generation per zenka** — ephemeral task keys derived from zenka
   identity key, stored in zenka's own namespace
2. **Directory routing primitive** — `base.task.route`: check pubkey dir,
   place encrypted payload, return delivery confirmation
3. **Task YAML schema** — minimal: description, status, priority, created,
   signed-by
4. **Signed decision mechanism** — zenka signs a YAML decision block,
   places in `decisions/` — verifiable by anyone with public key
5. **Cross-zenka contribution** — any zenka can place a signed reply in
   another's task `replies/` subdirectory
6. **LLM routing integration** — task advancement triggers LLM request
   routing through available models, result signed and stored
7. **FUSE mount integration** — task trees accessible as filesystem paths
   via data zenka, transparent across LAN

#,,..,,.,,,.,,,.,.,,,,.,,,.,,..,,.,,,.,..,.,,,,.,..,,...,...,..,,...,..,.,,.,

#,,,.,,..,,,,,.,,,.,,,,.,,.,,,.,.,,..,,..,.,,,..,,...,..,,.,.,.,.,.,,,.,,,,,.,
#LHSCZGRGNJFE7W7DXRBA35JRCEMSTNEZJQAVVJN5AIVHG6POTJWBLT22TNDJN5LAA4EBCTGCF5GDU
#\\\|LZEKTXIPY7QVKONW6CKHCJ2QWIIP2CKSXOOZN2RZ6P4SBETBIRK \ / AMOS7 \ YOURUM ::
#\[7]HRJ7EW5VHK7RYZKTXVOPYEXK5YJX6SWTA7D42AXR7QAUVN4OL2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
