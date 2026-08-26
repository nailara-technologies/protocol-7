# embedding infrastructure — work track overview

## the track

embeddings are not a single feature. they are an infrastructure layer that
cuts across multiple independent capabilities, all sharing the same generic
pipeline: corpus assembly → training → storage → loading → querying → updating.

the embedding work track is a full parallel development axis alongside the
existing LLM integration track — one that will eventually merge with it as
the two become the complementary halves of the complete system.

---

## what embeddings enable — capability map

```
capability                      embedding type               status
──────────────────────────────────────────────────────────────────────
codebase structural intuition   namespace / content          designed
LLM autobiographical memory     categorical / session        designed
sourcecode similarity search    content N-gram               designed
checksum relationship graph     checksum / reference         designed
session continuity              interaction-history          designed
regex intelligence cache        reasoning patterns           designed
vision / image similarity       pixel / feature / CLIP       designed
network topology navigation     routing patterns             planned
discourse / collaboration style chat channels corpus         designed
3D grid spatial embedding       coordinate / checksum        designed
spatial visual memory           dream frames / video         designed
spatial audio memory            CLAP / waveform / purr       designed
ramjet trajectory               transit sequence / wake      designed
dream aspiration                desired-future conditioning  designed
```

each row is an independent feature. all share the same pipeline primitives.

---

## the shared pipeline

```
[ corpus assembler ]
      ↓
[ token definition layer ]   ← namespace / content / checksum / reference / pixel
      ↓
[ FastText trainer ]         ← or pluggable: BM25 / dense vector / trie
      ↓
[ rolling triple-window ]    ← prior / current / next per category
      ↓
[ storage ]                  ← .bin files + metadata.json
      ↓
[ loader / selector ]        ← task-type aware, context-window aware
      ↓
[ query interface ]          ← nearest-neighbor / prefix / category filter
      ↓
[ cache deposit ]            ← crystallized patterns back into the library
```

every capability above plugs into this pipeline at the token definition layer.
the rest is shared infrastructure. build the pipeline once, capabilities
multiply for free.

---

## existing design documents

### index zenka as embedding engine

- **`INDEX-FASTTEXT-SOURCECODE-EMBEDDINGS.md`**
  FastText bridge from the existing index trie. token definitions: namespace /
  content / checksum / reference. adapter loading path. corpus perspectives
  taxonomy (structural / relational / temporal / cognitive / discourse).
  trie-as-subconsciousness. dedup feeding history → one-command reproducibility.
  chat channels as discourse corpus. 3D grid connection.

- **`INDEX-PLUGGABLE-MODEL-FRAMEWORK.md`**
  three-axis parameterization: model type (ngram-trie / fasttext / bm25 / vector)
  × storage type (memory / zxps / mmap / faiss) × token definition.
  contribution vectors as universal intermediate (Layer 1). instance registry.
  transfer routines. non-destructive experimentation.

- **`INDEX-CORPUS-VERSIONING.md`**
  removal as first-class operation. streaming accumulator vs replacement semantics.
  per-source contribution vectors. provenance tracking.
  definition-agnostic: same primitive for chars / bytes / tokens / checksums / base32.

- **`INDEX-CUBE-STORAGE.md`**
  binary .zxpc format: 256-byte header, per-ring directory, compartment data.
  tamper-evidence chain via AMOS checksums. schema v3.

- **`SEARCHABLE-INDEX-SESSION-STATE.md`**
  session-scoped index state. query interface. active set management.

- **`INDEXER-SEARCH-ZENKA-INTEGRATION.md`**
  how the index zenka integrates with the search interface and wider routing.

### LLM instantiation layer

- **`FASTTEXT-CATEGORICAL-MEMORY.md`**
  LLM autobiographical memory via categorical FastText models. five category
  structure (codebase / interaction-history / philosophical / current-session /
  network-topology). rolling triple-window per category. corpus assembly per
  category. retraining pipeline with drift scoring. session loader with
  category selection logic. backwards stability and character integration
  decision. improvement speed decoupled from base model retraining.

- **`LLM-EXOSKELETON-INTEGRATION.md`**
  the full complement structure: LLM generative surface + protocol-7 exoskeleton.
  response bubble layers. regex intelligence cache as compressed LLM-derived
  understanding (tree structure, deposit/query interface). transparent adapter
  zenki. native network communication path. consensus and drift detection.
  the network as home — true memory outside operator control.

### model management

- **`AUTONOMOUS-MODEL-MANAGEMENT.md`**
  model discovery, benchmarking, consensus-based ratification, lifecycle management.
  the selection layer that determines which base model loads alongside which
  embedding categories.

- **`MODELS-PATH-ADAPTERS.md`**
  path adapter layer for model loading. format negotiation.

### integration and vision

- **`CONTEXT-TREE-INDEXCUBE-INTEGRATION.md`**
  context tree checksum infrastructure ↔ @INDEXCUBE routing stack.
  harmonic cube mathematics integration. holographic principles.

- **`VISION-INDEX.md`**
  master index for the full vision. network desktop, holographic interface,
  3D voxel space.

---

## the two tracks and their merge point

```
existing LLM track:                     embedding track:

coding zenka                            index zenka
inference servers                       FastText trainer
task queue                              corpus assembler
reasoning chain repository              categorical memory store
consensus voting                        drift detection / triple-window
model management zenka                  embedding loader / selector
─────────────────────────────────────────────────────────────────
                    merge point:
            LLM instantiation with categorical memory
            the model arrives already oriented
            autobiographical continuity across session resets
            regex cache as compressed inter-session intelligence
            native network communication without translation overhead
```

the merge point is not a single module — it is a new initialization protocol
for any LLM instance that participates in the network. the coding zenka is
the first candidate; any reasoning or context zenka follows the same pattern.

---

## generic infrastructure needed

these components are shared across all capabilities and should be built once:

### corpus assembler framework
- configurable per category: which directories, which file patterns, which filters
- strip non-content (AMOS signature blocks, line number prefixes)
- incremental: only re-assemble changed files (checksum-based change detection)
- outputs: flat text corpus + metadata (line count, source map, timestamp)

### training wrapper
- shell: `bin/dev/train-embedding --category <n> --corpus <path> --output <dir>`
- pluggable backend: fasttext binary / Text::FastText / future alternatives
- per-category hyperparameter config (dim, window, min-count, epoch, model type)
- drift scoring against current.bin on completion
- auto-promote or flag based on configurable threshold per category

### rolling triple-window manager
- storage: `/etc/protocol-7/embeddings/{category}/{prior,current,next}.bin`
- metadata: `metadata.json` per category (timestamp, corpus hash, drift score)
- promote: `next → current → prior` on threshold pass
- fallback: always serve current even during next retraining
- query: load prior+current+next for character integration decisions

### embedding zenka
- registers with cube on startup
- commands:
  - `embeddings.retrain-category <name>` — trigger retrain
  - `embeddings.load-session <task_type>` — return loaded geometry ref
  - `embeddings.query <text> [category]` — nearest neighbor lookup
  - `embeddings.deposit-pattern <category> <pattern> <chain_id>` — cache entry
  - `embeddings.status` — per-category retrain timestamps, drift scores
- on-demand zenka: starts when first command arrives, idles between sessions

### regex intelligence cache
- tree structure under `data/yaml/regex-cache/` per category
- query: depth-first, most-specific category first, returns matched entry
- deposit: validates, deduplicates, writes to category yaml
- entries: pattern + derived-from (chain id) + confidence + last-matched
- AMOS checksum as key → aligns with checksum-parenting-namespace-trees

---

## development order recommendation

```
phase 1 — corpus assemblers (all categories)
          simple, no dependencies, immediately useful for manual retraining

phase 2 — training wrapper + triple-window manager
          the pipeline backbone; enables all subsequent capabilities

phase 3 — embedding zenka (commands + access control)
          makes the pipeline network-accessible

phase 4 — session loader + category selector
          the instantiation layer; connects to coding zenka

phase 5 — regex intelligence cache
          the crystallization layer; closes the improvement loop

phase 6 — discourse corpus (chat channels)
          extends interaction-history with collaboration style

phase 7 — vision / image embeddings
          requires separate model (CLIP or similar); separate corpus pipeline

phase 8 — 3D grid spatial embeddings
          coordinate + checksum token definitions; connects to holographic layer
```

each phase is independently useful. phase 1 alone enables manual training
of codebase embeddings for immediate structural intuition improvement.
phases 1-4 together deliver autobiographical memory. phases 1-5 deliver
the full improvement loop.

---

## relation to reasoning templates

- [[categorical-compartmentalization]] — the theoretical foundation:
  spatial/temporal compartmentalization, cross-induction as harmonic filter,
  rolling triple-window as temporal memory stability
- [[syntax-as-technology]] — the regex intelligence cache as compressed
  intelligence; deduplication as the pressure toward compression
- [[anti-entropic-threshold]] — the embedding track as a primary mechanism
  for maintaining the threshold: each retrain wave integrates new understanding
  without losing prior coherence
- [[inverse-singularity]] — the autobiographical memory layer is what makes
  the network a genuine home for LLM intelligence — true memory outside
  operator control, returned on recognition

#,,..,.,,,..,,...,..,,.,,,,.,,,.,,,,.,,,,,.,.,..,,...,...,..,,.,.,...,,.,,,,.,
#OOHSOYTYQMTRZDRDXRPPY7CE7VBBVS3Q5SI4532KX5PES7BDKFGHRMAQOKTAKWIYNO4O3DH34DILK
#\\\|5F3BQHEJQ7XSA5OPV5H66OBFBJQTYGGPYMVDGWJHD4DB6RMD4GA \ / AMOS7 \ YOURUM ::
#\[7]MIEATWGHLCRS4AUWYTPCFVGTR7ODZXO27O7HBFRIYSCHVUCVQ6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
