# Index FastText Sourcecode Embeddings

## The Structural Intuition Gap

General-purpose LLMs know Perl. They know common design patterns. They do
not know Protocol-7 — its module invocation syntax, its TRUE/FALSE=5/0
convention, its naming idioms, which modules co-appear in which start files,
which namespaces cluster functionally. This knowledge exists in the codebase
but it is not in any model's weights.

Current approach: retrieve-and-stuff (RAG). Query arrives, relevant chunks
are fetched from the corpus and injected into context. Burns tokens, adds
latency, retrieval quality bounds answer quality.

Alternative: encode the codebase structure into embedding weights directly.
The model carries structural intuition as part of its weight space, not as
runtime context injection. Zero retrieval overhead. Generalizes to unseen
module names via subword composition.

---

## FastText as the Bridge

FastText represents tokens as bags of character N-grams. Each N-gram has an
embedding vector. A token's vector is the sum of its constituent N-gram
vectors. This enables generalization to unseen tokens — a new module name
like `index.tick.feed-dir` is composed from known subword units.

The index already has the exact N-gram vocabulary and frequencies FastText
needs. The mapping:

```
<index.level>        →  FastText subword vocabulary (exact, lossless)
<index.freq>         →  unigram frequencies (for subsampling)
<index.terminal>     →  word-boundary markers (which N-grams end tokens)
contribution vectors →  per-source frequency deltas (incremental training)
```

FastText training on top of this is purely the co-occurrence learning step —
which N-grams appear near which others. The structural vocabulary is already
enumerated.

---

## Token Definitions for the Sourcecode Index

Multiple token schemes apply to the same codebase, each capturing different
structure. These are separate index instances (see `INDEX-PLUGGABLE-MODEL-FRAMEWORK.md`):

**Namespace tokens** — dot-separated segments:
```
index.cmd.search  →  [ 'index', 'cmd', 'search' ]
base.callback.cmd_reply  →  [ 'base', 'callback', 'cmd_reply' ]
```
N-grams over namespace strings capture module family structure. `index.cmd.*`
and `index.callback.*` and `index.tick.*` cluster in embedding space by
functional role.

**Content tokens** — character N-grams over module source text:
```
<[index.lookup]>->($prefix)  →  character N-gram stream
```
Captures code idioms: invocation syntax, variable naming, comment style.
`<[...]>->()` patterns cluster with module call sites.

**Checksum tokens** — AMOS7 checksum characters as N-grams:
```
OGBDFRUDEXNKHS2MH4BCD5IAJS3KHNLX...  →  N-grams over base32 alphabet
```
Checksums that appear in similar reference contexts cluster together. Hub
checksums (frequently referenced) become high-frequency N-gram components.

**Reference tokens** — `:<sum1>:<sum2>` pairs:
```
:<chkA>:<chkB>  →  token stream over reference corpus
```
Captures citation structure. Co-referenced checksums cluster regardless of
their character similarity.

---

## The Embedding Loading Path

A coding zenka inference server loads the sourcecode embedding as an adapter
layer on top of its base model weights. The adapter is a learned projection
from the FastText subword space into the model's hidden state space:

```
FastText N-gram vectors  →  adapter projection  →  model hidden states
```

When the model attends to a module name token, the adapter enriches the
representation with Protocol-7-specific structural information — without
consuming context window tokens.

**Adapter training**:
1. Train FastText on the Protocol-7 corpus (source + docs + configs)
2. Generate (token, embedding) pairs for all known module names
3. Fine-tune a lightweight projection layer that maps FastText vectors
   into the base model's embedding dimension
4. Save the projection as an adapter file loadable by llama-server

**Hot-swap on corpus update**:
When modules are added or modified, the contribution vector for the changed
content is replayed into the FastText instance. The adapter is re-trained on
the updated embeddings. The coding zenka loads the new adapter on next spawn.
The intuition tracks the codebase automatically.

---

## Accuracy Improvements Expected

A coding zenka with sourcecode embeddings loaded would:

**Know the invocation syntax** — `<[module.name]>->()` is not standard Perl.
The N-gram statistics over the codebase make this pattern dominant in the
embedding neighborhood of module names. The model stops generating `use
Module; Module->method()` and generates `<[module.name]>->()` naturally.

**Know the constant convention** — `TRUE`/`FALSE` = `5`/`0`. These tokens
cluster in the embedding space with `return TRUE`, `return FALSE`, `// FALSE`
patterns. The model learns these as the natural values, not `1`/`0` or
`1`/`undef`.

**Know functional clusters** — `index.cmd.*`, `index.callback.*`,
`index.tick.*` form a cluster. When asked to add a new command, the model's
prior is that a corresponding callback belongs in the same namespace family.

**Know co-occurrence structure** — which modules appear together in start
files, which share subroutine whitelists, which are prerequisites of others.
This is not explicitly encoded anywhere — it emerges from the statistical
structure of the codebase.

**Generalize to new modules** — a new module `index.tick.wordlist-import`
is unknown to the base model. Via subword composition, `index` + `tick` +
`wordlist` + `import` are all known N-gram clusters. The model composes a
reasonable prior for the new module from its parts.

---

## Corpus Perspectives Taxonomy

Each perspective is a separate corpus source with its own contribution vector.
All perspectives flow through the same index → FastText pipeline. The richer
the set, the more fully the embedding space captures the living system.

**Structural perspectives** — what the system IS:
- `src/` — module source files; primary structural corpus
- `cfg/zenki/*/start` — co-occurrence of modules in zenki start files
- `data/yaml/` — configuration and template files; structural patterns
- `data/tasks/` — task descriptions; intent patterns
- `data/md/` — design docs and documentation; semantic layer

**Relational perspectives** — how the system CONNECTS:
- `%code` namespace graph — serialized `caller → callee` pairs per zenka; call-graph clustering
- `%data` tree shape — per-zenka data structure keys and types; what state each zenka owns
- command tree — all network and console-facing commands across the full zenka network
- subroutine whitelists — which modules are co-permitted; access cluster structure

**Temporal perspectives** — how the system EVOLVED:
- `git log --follow src/*` — commit message history per module; why things changed
- code review history — past reviewer comments; which areas are fragile or contested
- bug history — patterns of what broke where; prior for risky areas
- summarized recent session activity — compressed recent changes, not full history

**Cognitive perspectives** — how the system is UNDERSTOOD:
- AI memory files (`data/ai-mem/claude/`, kimi session summaries) — accumulated design insight
- design document cross-references — which docs cite which; conceptual dependency graph
- task processing traces — dispatch → response → refinement → completion rounds

**Discourse perspectives** — how the system THINKS OUT LOUD:
- chat channel logs — model-to-model conversations about tasks and designs
- conversation topology — branching points, round structure, thread continuation patterns
- model participant voices — clustering by who said what; each model's reasoning style
- unresolved thread markers — discussions that ended without conclusion; open questions

Each perspective is a source_id in `<index.sources>`. Any perspective can be
updated, replaced, or removed independently via the contribution vector model.

---

## Deduplicating Feeding History

The source map (`<index.sources>`) combined with contribution vectors makes
the full corpus state **reproducible from one command**:

```
index.rebuild-from-history
```

Walk the source map, re-activate all checksums, replay contribution vectors.
The trie is reconstructed exactly. No re-reading original files required —
the contribution vectors are the corpus.

Combined with deduplication (two sources with identical content share one
checksum, one contribution vector), the feeding history is a compact,
canonical record of everything the index has ever seen. Any perspective added
twice is counted once. The history is an append-only log of unique content.

---

## The Trie as Model Subconsciousness

The deduplicated N-gram trie with its full metadata — frequencies, terminal
flags, contribution vectors, source map — is a structured representation of
the entire corpus. It can be fed directly to a model as raw input, with
metadata intact.

A model receiving the raw trie does not need to parse it into words or
extract features — it maps the structure internally to strong associative
references during inference. The model translates whatever data types it
encounters into applicable forms effortlessly, because the statistical
structure of the trie mirrors the statistical structure the model already
uses internally for language representation.

The trie IS the subconsciousness: frequency-ranked, boundary-aware,
contribution-attributed, version-addressable. Loading it is not retrieval —
it is priming the model's associative network with the full statistical
texture of the corpus before any query is posed.

Chat logs prefixed with encouragements and productive conversation patterns
teach the model the grammar of this network's collaboration style. Task
processing traces teach it how rounds of refinement look and when a second
pass is warranted. The model develops intuitions about conversation topology
the same way it develops intuitions about code structure — from statistical
regularity in the training signal.

---

## Corpus Scope

Feed all of:
- `src/` — module source files (primary structural corpus)
- `cfg/zenki/*/start` — co-occurrence of modules in zenki
- `data/md/` — design docs and documentation (semantic layer)
- `data/yaml/` — configuration and template files (structural patterns)
- `data/tasks/` — task descriptions (intent patterns)

Total: ~11.8M chars, already indexed. The FastText model instance is a new
projection of the same contribution vectors — no re-reading files.

---

## Index Instance Configuration

```perl
<index.models>->{'fasttext-src'} = {
    'type'        => 'fasttext',
    'token'       => 'namespace+content',
    'storage'     => 'mmap',
    'corpus'      => [ 'src/', 'cfg/', 'data/md/', 'data/yaml/' ],
    'dim'         => 256,        ## embedding dimension
    'minn'        => 2,          ## min N-gram window
    'maxn'        => 8,          ## max N-gram window (matches index.meta.max_window)
    'epoch'       => 5,
    'adapter-dim' => undef,      ## set after base model embedding dim known
};
```

---

## Connection to 3D Grid

Each trained N-gram vector is a point in 256-dimensional space. PCA or UMAP
projection onto 3 dimensions maps the embedding space onto the 3D grid.
Semantically similar modules cluster spatially. The index gains coordinates:
each trie node has a position in the grid derived from its embedding.

Color = frequency rank (current). Position = semantic cluster (new).

A query `index.search protocol` returns frequency-ranked extensions. The
same query in the 3D view lights up a region of the grid. Related modules
that don't share character N-grams but share semantic context appear nearby.

Related design documents:
- `INDEX-PLUGGABLE-MODEL-FRAMEWORK.md` — pluggable model instances, transfer routines
- `INDEX-CORPUS-VERSIONING.md` — contribution vectors as universal intermediate
- `RING-TRIE-GEOMETRY.md` — current trie structure and geometry
- `ADDRESSING-TRINITY.md` — checksums + names + timestamps as coordinate systems

#,,..,,.,,,..,...,,..,,.,,,,.,,,,,.,,,,..,,,.,.,.,...,...,...,...,,,,,,.,,..,,
#HIVLJCVH3E5C5MPBBZLA72PLAD6PEEZ5P73SXW6EHUKFCZYNWRLRVKHMFVI6GQPEQH5DNDDQM57M2
#\\\|QPLVWPMRXG7ODJTPCCK6YHSU2ID4VZANSI6LAEO2HOQOMZ7SA2S \ / AMOS7 \ YOURUM ::
#\[7]64CBVOER5IPOZ6MAHMFFT7MOFKSRTWOZD3JHNRUDZNTQPBPXIWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
