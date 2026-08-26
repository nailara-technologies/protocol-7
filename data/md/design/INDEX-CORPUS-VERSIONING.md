# Index Corpus Versioning

## The Clash

The current index zenka is a streaming frequency accumulator. Every `feed-dir`
call increments N-gram counts in `<index.level>` and character counts in
`<index.freq>`. There is no provenance — the trie is the sum of all
contributions with no record of what came from where.

This creates an invisible clash between two mental models:

**Streaming accumulator** — ingest is append-only. Fast, minimal, irreversible.
The trie IS the corpus. No undo, no replacement, no per-source attribution.

**Replacement semantics** — re-feeding an edited file should reflect the new
version. But the accumulator has no subtraction operation. Old contributions
from previous file versions remain silently embedded in the trie, mixed
indistinguishably with new ones.

The implicit current pointer moves forward without tracking provenance. Stale
N-gram contributions from old file versions accumulate invisibly.

---

## Contribution Vectors

The resolution: each version of a piece of content is identified by its content
checksum. The index stores a **contribution vector** per checksum — a sparse map
of N-gram frequency deltas that this content contributes to the global trie.

The global trie is the union-sum of all **active** contribution vectors:

```
trie = Σ active_contribution_vectors
```

**Replacement** becomes a pointer operation, not a recomputation:

```
deactivate(old_checksum)   →  subtract its contribution vector
activate(new_checksum)     →  add its contribution vector
```

**Removal** is replacement without an activate step:

```
deactivate(HEAD_checksum)   →  subtract its contribution vector
remove source_id from <index.sources>
```

The trie returns to exactly the state it would have been in had the source
never been fed. No re-parse, no recomputation — the stored vector is the
exact inverse of what was added.

**Definition-agnostic** — the contribution vector stores frequency deltas for
whatever unit the ingestion layer defined: characters, bytes, tokens, diff
chunks, checksums, base32 symbols. Removal operates on stored deltas and
never needs to know what a "word" is. The same primitive works identically
across all granularities and all chain topologies.

**Deduplication** falls out naturally — two files with identical content share
one checksum, one contribution vector, one contribution to the trie. Referenced
any number of times, it counts once.

---

## The Index Is Mode-Agnostic

The index engine is a blind vector-sum: `trie = Σ active_contribution_vectors`.
It does not know whether a vector is a delta or a full snapshot. That
interpretation belongs entirely to the **source-tracking layer**, which decides
which checksums to mark active.

Two activation policies, same index primitives:

**Delta policy** — mark the entire chain root→HEAD as active; each vector is a
diff. The trie is the accumulated sum of all diffs from origin to current state.

**Snapshot policy** — mark only HEAD as active; each vector is a full state.
Replacement is deactivate old HEAD, activate new HEAD.

Both use the same `Σ active_vectors` index arithmetic. No type field is stored
in the index. Policy complexity is isolated in L3 (source tracker) and never
leaks into L2 (index engine).

Mixing delta and snapshot policies within the same active set would require type
tags and routing logic for counting — added complexity with no current need.
Keeping one policy per source-chain avoids this entirely.

---

## The Diff Stream

The model is **resolution-independent**. Contribution vectors are checksum-keyed
whether the checksum covers an entire file or a single diff chunk. The chain
structure is identical at any granularity:

```
[checksum, content, parent_checksum]
```

At whole-file resolution:

```
file_v1_chk  →  file_v2_chk  →  file_v3_chk
```

At diff resolution:

```
diff_a_chk [ parent: ∅     ]
diff_b_chk [ parent: diff_a ]
diff_c_chk [ parent: diff_b ]
```

Both are the same linked structure. A whole-file feed is a valid diff stream of
one chunk with no parent. Resolution can be mixed freely within a chain: initial
ingest at file granularity, incremental edits as diff streams. Activation policy
(delta vs snapshot) must remain uniform per chain.

The **current state** of any corpus source is a HEAD pointer into its chain.
The source tracker resolves reachability — under delta policy it walks the chain
root→HEAD; under snapshot policy it points directly to HEAD. The index receives
only the resulting active set and sums it.

---

## Partial Rewind

Because each step in the chain has an explicit contribution vector, rewinding is
free:

```
walk back N steps  →  subtract those contribution vectors
```

The index reflects an earlier state without full recomputation. Forward replay
is equally free — re-apply vectors in chain order.

---

## Branching

Branching means multiple active HEAD pointers. Each branch activates its own
set of contribution vectors. The trie can project any branch or any combination
of branches by adjusting which HEAD pointers are active.

This is the content-addressable network applied to corpus state. The index
becomes a **live projection of the reachable checksum graph**, not a snapshot.

---

## Boundary Terminals

The `<index.terminal>` boundary-tracking hash (see index.deduplicate) fits
naturally into this model. Contribution vectors carry both raw N-gram frequency
deltas AND boundary-terminal frequency deltas as orthogonal components. A true
terminal (sequence ending at a word boundary) remains a terminal across
replacement operations as long as the active chain contains a version where it
appears at a boundary.

---

## Implementation Path

**Near term** — no changes required to the current streaming model for single-
pass corpus ingest. The current `feed-dir` / `ingest` / `deduplicate` pipeline
remains valid as the zero-parent single-chunk case.

**Contribution vector store** — a new `<index.contributions>` structure keyed
by content checksum, storing sparse N-gram delta maps. Populated during ingest,
consulted during deactivation.

**Active set** — `<index.active_checksums>` tracks which contribution vectors
are currently summed into the live trie. Per-chain policy marker (delta vs
snapshot) lives here, not in the index engine.

**Source map** — `<index.sources>` maps `source_id` (file path, document ID)
to its current HEAD checksum. Replacement is a pointer move in this map.
Deletion is removal of the source_id entry and deactivation of its HEAD.

**Replacement operation** — `index.cmd.replace` : update source map, deactivate
old checksum, activate new checksum, defer trie rebuild.

**Active set size** — under delta policy the active set is O(chain length) per
source, not a flat list. Under snapshot policy it is O(1) per source. Choose
policy based on expected edit frequency and retention needs.

**GC** — snapshot policy allows pruning non-HEAD vectors to cold storage; delta
policy requires full chain retention for rewind. Both compress well in `.zxps`.

**Persist** — contribution vectors, source map, and active set persist alongside
`level` and `freq` in the `.zxps` state file.

---

## References as Index-Transparent Sequences

References between content items are checksum pairs:

```
:<sum1>:<sum2>
```

This is a string. The index has no knowledge of what it means — it counts
N-grams over the sequence exactly as it would over natural language text. The
leading `:` is convention: it namespaces reference sequences away from content
N-grams in the frequency distribution, but the index engine never parses or
routes on it.

Three-element chains express intermediate hops:

```
:<sum1>:<sum2>:<sum3>
```

Co-citation frequency, hub detection, and reference-chain statistics fall out
of the existing ring structure at no additional cost. A checksum that appears
in many pairs is a high-frequency N-gram prefix in the reference corpus —
hub detection is just a ring-0 frequency query.

**References are their own corpus** — fed as a separate source, with their
own contribution vectors. The reference corpus can be replaced or removed
without touching content vectors. The `:` prefix is not stored in the index;
it is a query-layer convention for distinguishing result types.

**Separate index instance** — reference N-gram distributions (long, uniform-
length, high-entropy checksum tokens) are structurally different from natural
language N-gram distributions. A dedicated reference index keeps frequency
rankings meaningful in both domains. Both instances use the same index engine
and the same contribution vector model.

---

## Connection to Protocol-7 Addressing

This model is the content-addressable network applied locally. Checksums are
addresses. Contribution vectors are the payload at each address. The chain
`[checksum, parent]` is the same structure as the Protocol-7 checksum tree wire
format — immutable, append-only, self-verifying.

The index is not a database. It is a **reified convergence of checksum-addressed
content streams**.

Related design documents:
- `CHECKSUM-FRAME-CONTAINER.md` — 2D/3D recovery frames, provenance chains
- `ADDRESSING-TRINITY.md` — named tree + checksums + timestamps as orthogonal
- `SELF-DELIMITING-CHECKSUM-PATTERN.md` — 2-bit type system, payload tokens

#,,.,,,..,,..,,.,,.,,,,..,..,,..,,,,.,...,.,,,..,,...,...,..,,...,...,...,,,,,
#C4MWTZL2S6QHPQ5V2IHO5X7MSGNLFCIU7KIDEFN3UBK47Y43KFOGIUHSKNSZPGUZN4DX6ICDZAEG2
#\\\|QYTCCWJ4VQCVIEHTHPVX335RCXOSLBS7EG4AI37HTULRHUVBVIY \ / AMOS7 \ YOURUM ::
#\[7]5HCTRVEOFZUCKPYDWBSPJIVYS47PXRPYMOTKJBTTOZ56BVE7FKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
