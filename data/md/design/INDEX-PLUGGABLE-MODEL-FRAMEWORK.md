# Index Pluggable Model Framework

## The Single-Model Limitation

The current index zenka hosts exactly one model: a character N-gram frequency
trie over natural language text. The architecture is correct but specific.
Every structural decision — alphabet, window size, storage format, query
interface — is wired to this one model type.

The index engine is already mode-agnostic (`trie = Σ active_contribution_vectors`).
The contribution vector layer is already model-agnostic (it stores frequency
deltas for whatever unit the ingestion layer defined). The missing piece is
making the model and storage layers explicitly pluggable.

---

## Three-Axis Parameterization

Each index instance is defined by three orthogonal axes:

**Model type** — what computation runs over the ingested tokens:
- `ngram-trie` — current model: frequency-ranked character N-gram trie
- `fasttext` — subword embedding vectors, trained from N-gram co-occurrence
- `bm25` — term frequency / inverse document frequency, per-source scoring
- `vector` — dense embedding store, queryable by nearest-neighbor

**Storage type** — how the model state is persisted:
- `memory` — in-process Perl hashes (current)
- `zxps` — XZ-compressed Perl Storable (current persist format)
- `mmap` — memory-mapped flat file, shared across processes
- `faiss` — FAISS index file for billion-scale vector search

**Token definition** — what constitutes a symbol for this instance:
- `char` — individual Unicode characters (current)
- `base32` — 32-symbol alphabet over encoded content
- `namespace` — dot-separated segment tokens (`index`, `cmd`, `search`)
- `checksum` — AMOS7 checksum strings as atomic tokens
- `reference` — `:<sum1>:<sum2>` pairs as token sequences

These axes are independent. A FastText model over namespace tokens stored in
FAISS is as valid as an N-gram trie over characters stored in `.zxps`.

---

## The Universal Intermediate: Contribution Vectors

Transfer between model types does not require re-reading raw files.
Contribution vectors (see `INDEX-CORPUS-VERSIONING.md`) are the universal
intermediate representation — a checksum-keyed map of token frequency deltas
that is model-agnostic.

Re-projecting the corpus into a new model type is replaying stored deltas
into a different compute kernel:

```
for each active checksum:
    cv = <index.contributions>->{checksum}
    new_model.apply_delta(cv)
```

The contribution vector store is Layer 1. Model instances are Layer 2.
Layer 2 is disposable and reconstructable from Layer 1 at any time.

```
Layer 0 : raw corpus          (files, checksums, references)
Layer 1 : contribution vectors  ← universal intermediate, never discarded
Layer 2 : index models        (trie | fasttext | bm25 | vector)
Layer 3 : query interface     (prefix | semantic-nn | rank | score)
```

---

## Instance Registry

The index zenka maintains a registry of active model instances:

```perl
<index.models> = {
    'ngram-char'   => { type => 'ngram-trie', token => 'char',      ... },
    'fasttext-src' => { type => 'fasttext',   token => 'namespace', ... },
    'ref-trie'     => { type => 'ngram-trie', token => 'reference', ... },
};
```

Each instance has its own state namespace under `<index.model.$name.*>`,
its own persist path, and its own query command prefix.

Commands route to instances by name prefix:

```
index.search <prefix>               ## default model
index.model.fasttext-src.search <prefix>   ## named model
index.model.ngram-char.lookup <token>
```

---

## Transfer Routines

`index.cmd.model.transfer` — project the active corpus from one model
instance into another:

```
index.model.transfer src=ngram-char dst=fasttext-src
```

Iterates `<index.active_checksums>`, retrieves each contribution vector,
and applies it to the destination model's ingestion kernel. The destination
model does not need to know anything about the source — it receives the same
token delta stream that original ingest would have produced.

**Migration** — moving the primary model from one storage type to another:

```
index.model.migrate src=ngram-char:memory dst=ngram-char:zxps
```

Exports the in-memory model state, writes to the new storage backend, updates
the instance registry.

---

## Experimentation Path

Because Layer 1 (contribution vectors) is preserved across model changes,
experimentation is non-destructive:

1. Create a new model instance with different type/token/storage
2. Transfer from the existing active corpus via contribution vectors
3. Run queries against both instances in parallel
4. Promote the better-performing instance to default
5. Discard the experiment — the original model is unchanged

No re-feeding required. No corpus lock-in to a single model choice.

---

## Per-Instance Pluggable Components

Each model instance declares:

```perl
{
    'ingest'      => 'index.ingest.ngram',      ## how to process a content delta
    'query'       => 'index.query.ngram',       ## how to answer a search query
    'persist'     => 'index.persist.zxps',      ## how to save state
    'restore'     => 'index.restore.zxps',      ## how to load state
    'transfer-in' => 'index.transfer.ngram',    ## how to receive a contribution vector
}
```

The contribution vector format is shared across all instances. The
`transfer-in` handler knows how to map a generic `{freq, level}` delta into
the model's native representation.

---

## Connection to Corpus Versioning

The pluggable model framework and the corpus versioning model (`INDEX-CORPUS-VERSIONING.md`)
are the same system viewed from different angles:

- Versioning: one model, multiple corpus states over time
- Pluggable models: one corpus state, multiple model projections simultaneously

The contribution vector store serves both. It is the single source of truth
from which any model at any corpus version can be reconstructed.

Related design documents:
- `INDEX-CORPUS-VERSIONING.md` — contribution vectors, source map, active set
- `INDEX-FASTTEXT-SOURCECODE-EMBEDDINGS.md` — FastText model instance, coding zenka integration
- `ADDRESSING-TRINITY.md` — named tree + checksums + timestamps as orthogonal

#,,,,,,,,,,.,,,..,,..,.,.,,,,,,..,,,,,,.,,..,,.,.,...,.,,,.,,,,..,,,,,,,,,.,.,
#24WLYFOVAIULIWUXF4MB4BKMPXD4LLU2PQIZQMS5WHLDXAQP4LVT63MATQBX4ELIBEKUACX2PL4KS
#\\\|D3JUYQOCKHICFZBCZ4CBLSC5IRTCYPKIE532V6Q6SIUZQWXMT42 \ / AMOS7 \ YOURUM ::
#\[7]2VJJHPWGTXPKI7VNH5QPBNDSEGZFMA6X43IHRRRZIABTKIUML4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
