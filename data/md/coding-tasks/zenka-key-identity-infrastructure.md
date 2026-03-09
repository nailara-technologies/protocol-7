
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

- C25519 implementation: `modules/crypt.C25519.*` — already present
- User keys: `modules/USR.[username].*` pattern — zenka keys follow same pattern
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

#,,.,,.,,,..,,,.,,,,.,..,,,,,,...,,,,,,,.,,,.,..,,...,..,,..,,..,,,.,,..,,...,
#5B6OOU6TR3QU37DNRD3JYAZINH5F4E4WP2WU3N6KTYHCFP74QSUJIMBJAPSMONEL4DZH6QZW57JYA
#\\\|GT7JVUATM5L3KDBJC4RAVSEPH5NICUKCNHDBJFLAZWHSTON3EBE \ / AMOS7 \ YOURUM ::
#\[7]NC4K3H4CGFNY3RQHFXPLGMPMWWHCO4FR3UGLSIEY74BBLYGNB4DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
