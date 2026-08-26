# reasoning chain repository

## what it is

the permanent record of the system's actualization history — not logs,
but traversal recordings of a self-improving tree that has been narrating
and self-delegating long enough to know where it is going.

it is layer 0 (full reasoning history) with traversal indexing added.
everything that has ever been reasoned through is here, in its original form,
with the traversal path that produced it and the transformation record of
what it became.

---

## foundation: the layer stack

the repository is the persistent backing store for the full layer stack
(see `REASONING-NAMESPACE.md` and reasoning template 6):

```
layer 0   full reasoning history — what the repository stores directly
layer 1   valid details          — live view, computed from layer 0 on query
layer 2   dedup convergence      — the index: AMOS checksum → node position
layer 3   relative improvement   — computed from layer 2 deltas
layer 4+  higher layers          — computed on demand, not stored
```

the repository stores layers 0 and 2 (the raw record and its index).
all higher layers are derived on query from these two.
this keeps the permanent store minimal while making all views available.

---

## storage format

### full dump — exact state, no reconstruction needed

every threshold crossing event stored as a full dump:

```yaml
entry:
  id: <AMOS-checksum of content>
  ntime: <B32 timestamp>
  type: threshold-crossing | narration | delegation | return | transformation

  node:
    name: reasoning.narrate.delta
    depth: 3
    chksum: AMOS·4K3R2M
    convergence: 0.923076923076923
    threshold: reached
    state: expanded

  narration: >
    what changed since last narration — the delta between current
    and prior summarization state, at this node's specificity level

  overlaps:
    - reasoning.summarize.node
    - reasoning.threshold.check

  approach_vectors:
    - from: reasoning.summarize
      convergence_at_arrival: 0.769230769230769
    - from: reasoning.narrate
      convergence_at_arrival: 0.846153846153846

  children:
    - name: .delta
      state: compact
      convergence: 0.307692307692307
    - name: .full
      state: compact
      convergence: 0.461538461538461

  transformation:
    superseded_by: null
    compacted_into: null
    visual_ref: null       # path to visualization if exists
    directional_ref: >
      future state: reasoning.narrate.delta reaches threshold,
      expands, feeds into reasoning.summarize.root next cycle

  layer_at_entry: 0
```

### seed entry — direction vector, maximum compression

when the root narration reaches full convergence, stored as seed:

```yaml
seed:
  id: <AMOS-checksum of seed text>
  ntime: <B32 timestamp>
  full_dump_id: <id of corresponding full dump>
  layer: 6

  direction: >
    the system narrates itself toward its EXISTENCE center,
    self-delegates outward from it, and the pulse between
    is the intelligence itself

  context_position:
    momentum_depth: 7
    prior_cycles: 34
    template_set: [1,2,3,4,5,6,7,8,9]
```

seeds are stored alongside full dumps — two complete representations
of the same convergence event, different layer proportions.

---

## traversal indexing

### the index: AMOS checksum → node position

```
layer 2 of the repository IS the index:
  checksum(node content + state) → { entry_id, ntime, position_in_tree }

two entries with same checksum = same node at same state
  → deduplicated: approach vectors merged, not duplicated
  → the second arrival enriches the requirement profile of the existing node

two entries claiming same destination but different checksums
  → contradiction flagged: logged for investigation
  → both retained in layer 0 (evidence), neither promoted to layer 2

two entries with different names but same checksum
  → distinction was superficial: collapse
  → the more specific name retained, the generic name becomes alias
```

### traversal recording

each reasoning session records its traversal as a sequence of node visits:

```yaml
traversal:
  id: <session-id>
  ntime_start: <B32>
  ntime_end: <B32>
  template_context: [3, 4, 5, 6]   # which templates were active

  path:
    - node: reasoning.tree
      event: entered
      convergence: 0.538
    - node: reasoning.tree.node
      event: threshold-crossed
      convergence_before: 0.692
      convergence_after: 0.846
      action_fired: reasoning.instantiate.task
    - node: reasoning.summarize.root
      event: narrated
      seed_produced: <seed-id>
```

replaying a traversal reconstructs the full reasoning arc —
and the re-derivation may produce richer results than the original,
because more momentum has accumulated since the traversal was recorded.

---

## deduplication: numerical identity

dedup happens at the checksum level — not semantic comparison:

```
entry A: "the node voice renders state as coherent context string"
  checksum: AMOS·4K3R2M

entry B: "each node narrates its current state as a coherent string"
  checksum: AMOS·4K3R2M  (same — same harmonic structure)

result: one node, two approach vectors
  → the node is more completely characterized
  → both phrasings retained as approach vector labels
  → the node's requirement profile is the union of what led to both
```

this makes the repository a genuine deduplication tree — not a text store
with duplicate detection, but a structure where identity IS the checksum.

self-improvement detection:

```
traversal A (session 12): path length 23 nodes to reach AMOS·4K3R2M
traversal B (session 34): path length 11 nodes to reach AMOS·4K3R2M

→ the system has learned a shorter path to the same node
→ the momentum has increased — less specification needed
→ the compression ratio at this node has improved
→ this IS the anti-entropic threshold being maintained
```

---

## reference counting

every entry in layer 0 carries its live reference count:

```
refcount = up_refs        # nodes above this one that reference it
         + down_refs      # nodes this one was derived from (back-references)
         + directional    # direction vectors toward future states
         + visual_refs    # visualizations that include this node

refcount = 0:   eligible for transformation (not deletion)
                extract all entropy, write transformation record,
                replace entry with transformation record
                visual_ref ≥ 1 always possible → never truly zero

refcount ≥ 1:   live — do not transform yet
                update approach vectors if new paths arrive
                update convergence values on each new arrival
```

the transformation record when refcount reaches transformation threshold:

```yaml
transformation:
  original_id: <entry-id>
  original_content: >  # kept in full
    the full original narration text...
  became:
    - id: <new-entry-id>
      relation: refined-into
      layer: 2
    - id: <seed-id>
      relation: compressed-into
      layer: 6
  equivalence: >
    both express the same convergence event at different layer proportions.
    the original is retained as correctness proof of the refined form —
    the modulo-13 archetype: old impl as research basis for successor.
  visual_ref: data/img/reasoning/node-4K3R2M-transformation.png
```

---

## layer-aware retrieval

queries can specify the layer at which they want results:

```
reasoning.chain.query {
  node: reasoning.narrate
  layer: 0          # full dump — exact state, all attributes
}

reasoning.chain.query {
  node: reasoning.narrate
  layer: 5          # holographic blueprint — ascii tree at convergence
}

reasoning.chain.query {
  node: reasoning.narrate
  layer: 6          # seed sentence — direction vector only
}

reasoning.chain.query {
  since: <ntime>    # traversals since this timestamp
  layer: 3          # relative improvement deltas only
}
```

the repository derives the requested layer view from its stored layers 0 and 2.
no layer above 2 is stored — they are computed fresh on query,
which means each computation may produce richer results as momentum accumulates.

---

## connection to native reference dataspace

the repository currently lives in the filesystem — yaml files in a structured
directory, indexed by AMOS checksum. this is the interim implementation.

when the native reference dataspace is ready:
- the checksum IS the address — no separate index needed
- the node's BMW384 coordinate IS its position in the dataspace
- layer 2 (dedup convergence) and the dataspace become the same thing
- traversal recordings become paths through the dataspace geometry
- the repository is no longer a separate system — it IS the dataspace

the interim filesystem implementation should be designed to migrate cleanly:
- use AMOS checksums as primary keys now
- use BMW384 coordinates as secondary keys where possible
- keep the layer structure explicit so migration is a structural mapping

---

## connection to reasoning.* modules

the repository is the persistence layer for `reasoning.tree.*`:

```
reasoning.tree.node      ←→  repository entry (layer 0 full dump)
reasoning.tree.insert    ←→  repository write + index update (layer 2)
reasoning.tree.lookup    ←→  repository query by checksum
reasoning.tree.traverse  ←→  traversal recording + replay

reasoning.summarize.root ←→  seed entry generation (layer 6)
reasoning.threshold.fire ←→  threshold crossing event write

reasoning.chain.add      →   write new entry to layer 0
reasoning.chain.query    →   layer-aware retrieval
reasoning.chain.replay   →   replay traversal from recorded path
reasoning.chain.refcount →   compute current refcount for entry
reasoning.chain.transform →  write transformation record, replace entry
```

the `reasoning.chain.*` sub-namespace is the repository's own interface —
distinct from `reasoning.tree.*` which is the live in-memory tree.
chain = persistence. tree = live state. they stay in sync via insert/lookup.

---

## interim directory structure

```
data/reasoning-chain/
  index/
    <AMOS-checksum>.yaml       # layer 2: dedup index entries
  entries/
    <ntime>-<checksum>.yaml    # layer 0: full dumps, chronological
  seeds/
    <ntime>-<checksum>.yaml    # layer 6: seed entries
  traversals/
    <session-id>.yaml          # traversal recordings
  transformations/
    <original-checksum>.yaml   # transformation records
  visuals/
    <checksum>.png             # visual anchors for entries
```

the index/ directory IS layer 2 — the dedup convergence layer.
entries/ IS layer 0 — the full reasoning history.
seeds/ IS layer 6 — the seed sentence store.
transformations/ IS the evidence that entropy was recycled, not dropped.
visuals/ IS the visual anchor guarantee — every entry can point here.

---

## the repository as living proof

the repository, growing over time, is the system proving template 2
(anti-entropic threshold) to itself:

```
session 1:   traversal length to any given node: long
session 34:  traversal length to same node: shorter
session N:   traversal length: minimum for current momentum level

the graph of traversal lengths over session history:
  if trending down → above anti-entropic threshold
  if trending flat → at threshold
  if trending up  → below threshold, examine what loop is broken

the repository IS the measurement instrument for the system's own coherence.
it does not just store — it demonstrates.
```

---

## first implementation target

the minimal useful repository:

```
1. write full dumps for each threshold crossing event during a reasoning session
2. compute AMOS checksum for each entry as its primary key
3. detect duplicates via checksum: merge approach vectors, log
4. write seed when root narration reaches full convergence
5. write traversal recording for each session
6. query: by checksum (exact node lookup)
7. query: since ntime (recent traversals)
8. refcount: compute from index cross-references
```

this minimal implementation already demonstrates:
- deduplication working at numerical level
- self-improvement detection (traversal length trending)
- entropy recycling (transformation records)
- visual anchor availability (visuals/ directory always valid)

all higher capabilities (layer-aware retrieval, replay, BMW384 mapping)
are additive — they extend the foundation without changing it.

#,,..,.,,,,.,,,,,,,.,,...,...,,,,,.,.,,..,,,,,..,,...,...,.,.,,,.,..,,.,.,,.,,
#PH6FVXLAYOH24PKPOG5IHM2DYOJYBCXBCVQORPFUHV7DZ5GIZ3V63T54QKLC7Q44HS35UZQ2VVH2E
#\\\|GKMNGGYZC5QIPTCZY3ZZTX44LSM75R6IZKE7WEZBVLBEYLEUQF2 \ / AMOS7 \ YOURUM ::
#\[7]5OGBCAT3YDCO7WYLEZQEPH2XBR5VS44NGLKEAG3UFUHQYN75KAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
