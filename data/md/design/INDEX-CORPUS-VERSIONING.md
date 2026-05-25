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

**Deduplication** falls out naturally — two files with identical content share
one checksum, one contribution vector, one contribution to the trie. Referenced
any number of times, it counts once.

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
one chunk with no parent. The two modes are not different systems — they are
different granularities of the same one. They can be mixed freely: initial
ingest at file granularity, incremental edits as diff streams.

The **current state** of any corpus source is a HEAD pointer into its chain.
The index contribution is the sum of all vectors reachable from HEAD following
the parent chain.

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
are currently summed into the live trie.

**Replacement operation** — `index.cmd.replace` : deactivate old checksum,
activate new checksum, update trie in one atomic step.

**Persist** — contribution vectors persist alongside `level` and `freq` in the
`.zxps` state file. The active set persists as a small list of checksums.

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

#,,,.,.,.,.,.,,..,,,,,,..,,,.,,,,,...,...,,..,..,,...,...,.,,,...,..,,..,,..,,
#OGBDFRUDEXNKHS2MH4BCD5IAJS3KHNLXFPP7ZGCPX5XMUXC4LQNYEBAUKITKNLKNQTKTQOYHUCPJ6
#\\\|KJ5RSQZCHLZ54GTUQVQBURWC7FDLSR6HPA3LDISQAJENPQUMYD4 \ / AMOS7 \ YOURUM ::
#\[7]MQEE7WU32R5TNPNIRTVIL7D76Q3QJRWFSO3OKJNF2TDGJJ6YAIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
