# Searchable Index — Session State Document

## 1. Vision

Protocol-7's searchable index is a **content-addressed dataspace** where every file, fact, and node is located by its checksum rather than by path. The semantic axis (checksum/cubic topology) combines with the temporal axis (timestamps) to form a self-organizing coordinate space. Web visualization — already served by `space.v7.ax` — becomes the primary interface for discovering, navigating, and validating this space. The immediate goal is to index the code repository as a test case, then extend to knowledge-base deduplication and multi-node discovery.

---

## 2. Unified Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              VISUALIZATION LAYER                                 │
│  ┌─────────────────────────┐    ┌─────────────────────────┐                      │
│  │   space.v7.ax           │    │   source.v7.ax          │                      │
│  │   (checksum grid UI)    │    │   (code browse + search)│                      │
│  └───────────┬─────────────┘    └───────────┬─────────────┘                      │
└──────────────┼──────────────────────────────┼────────────────────────────────────┘
               │                              │
               ▼                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           SEARCH / QUERY INTERFACE                               │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │  query.harmonic()   ──→ division-by-13 resonance clusters                │  │
│  │  query.checksum()   ──→ exact content address / coordinate range         │  │
│  │  query.visual()     ──→ pattern-vector similarity                        │  │
│  │  query.wave()       ──→ temporal spike / branch aggregation              │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                    ▲                                             │
│                    ┌───────────────┴───────────────┐                            │
│                    │      SEARCH ZENKA (planned)    │                            │
│                    │   search.harmonic              │                            │
│                    │   search.coordinates           │                            │
│                    │   search.visual                │                            │
│                    │   search.wave                  │                            │
│                    └───────────────────────────────┘                            │
└─────────────────────────────────────────────────────────────────────────────────┘
               ▲
               │
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           INDEXER / COORDINATE LAYER                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐  │
│  │  Harmonic    │  │  Checksum    │  │   Visual     │  │      Wave           │  │
│  │   Index      │  │   Index      │  │   Index      │  │     Index           │  │
│  │              │  │              │  │              │  │                     │  │
│  │ • mod-13     │  │ • Spatial    │  │ • Pattern    │  │ • Local spikes      │  │
│  │   truth      │  │   coords     │  │   vectors    │  │ • Branch trends     │  │
│  │ • clusters   │  │ • Temporal   │  │ • Color grid │  │ • Global patterns   │  │
│  │              │  │ • Semantic   │  │              │  │                     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └─────────────────────┘  │
│                                    ▲                                             │
│                    ┌───────────────┴───────────────┐                            │
│                    │    INDEXER ZENKA (planned)     │                            │
│                    │   indexer.harmonic             │                            │
│                    │   indexer.checksum             │                            │
│                    │   indexer.visual               │                            │
│                    │   indexer.wave                 │                            │
│                    └───────────────────────────────┘                            │
└─────────────────────────────────────────────────────────────────────────────────┘
               ▲
               │
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         CONTENT / STORAGE LAYER                                  │
│  ┌─────────────────────────┐    ┌─────────────────────────┐                      │
│  │  Checksum Filesystem    │    │  Existing Storage Zenka  │                      │
│  │  (planned)              │    │  (partial, untested)     │                      │
│  │  base.checksum-fs.*     │    │  plugin.storage.checksum.*│                     │
│  │                         │    │  storage.9p.*            │                      │
│  │  • store / retrieve     │    │  storage.map-dirs.*      │                      │
│  │  • verify / deduplicate │    │                          │                      │
│  │  • CoW / metadata       │    │                          │                      │
│  └─────────────────────────┘    └─────────────────────────┘                      │
│                                    ▲                                             │
│  ┌─────────────────────────────────┴─────────────────────────────────────────┐   │
│  │                         DEDUPLICATION TREE (existing)                      │   │
│  │   Content storage + reference counts + semantic clusters + temporal index  │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
               ▲
               │
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         ROUTING / ADDRESSING LAYER                               │
│  ┌─────────────────────────┐    ┌─────────────────────────┐                      │
│  │      @INDEXCUBE         │    │        P7REF            │                      │
│  │   (per-zenka stack)     │    │   TYPE:CHKSUM7:ADDR_B32 │                      │
│  │  base.indexcube.*       │    │   base.p7ref.self       │                      │
│  │                         │    │   plugin.storage.p7ref.*│                      │
│  │  • push / pop / here    │    │                         │                      │
│  │  • depth / reset        │    │                         │                      │
│  └─────────────────────────┘    └─────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────────────────────┘
               ▲
               │
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         KNOWLEDGE / CONTEXT LAYER                                │
│  ┌─────────────────────────┐    ┌─────────────────────────┐                      │
│  │    Context Tree         │    │   Knowledge Base        │                      │
│  │   context.tree.*        │    │   (planned)             │                      │
│  │                         │    │   knowledge.dedup.*     │                      │
│  │  • checksum state       │    │   knowledge.storage.*   │                      │
│  │  • stream / template    │    │   knowledge.zenka.*     │                      │
│  │  • summary branches     │    │                         │                      │
│  └─────────────────────────┘    └─────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**How to read the diagram:**
- **Bottom layers** (routing, knowledge, context) already exist in part.
- **Middle layers** (checksum filesystem, indexer) are specified but largely unimplemented.
- **Top layers** (search interface, visualization) connect to the working `space.v7.ax` web host.

The architecture replaces five scattered diagrams from the source docs with a single vertical stack. Data flows upward from checksum-addressed storage through indexing engines to search interfaces, while routing and context layers provide the coordinate frame that makes the stack navigable.

---

## 3. Module Status Matrix

| Namespace | Specified In | Actual State |
|---|---|---|
| `modules/index.*` | Topic file + implicit | **7 modules exist**: `index.init_code`, `index.gen_path`, `index.callback.wordlist-import`, `index.cmd.add-wordlist`, `index.cmd.gen-path`, `index.cmd.stop-job`, `index.cmd.add-path` (stub — returns "not implemented yet") |
| `modules/storage.*` + `plugin.storage.*` | Phase-2 YAML, storage zenka docs | **Many exist**, largely kimi-generated: `storage.init_code`, `storage.9p.*` (13 modules), `storage.map-dirs.*` (7 modules), `storage.cmd.*` (5 modules), `plugin.storage.checksum.*` (12 modules), `plugin.storage.inference.*` (3 modules), `plugin.storage.p7ref.*` (7 modules), `plugin.storage.visual.*` (3 modules), `plugin.storage.util.*` (10 modules). Style issues noted; largely untested |
| `modules/base.indexcube.*` | CONTEXT-TREE doc (phase 1 "DONE") | **5 modules exist**: `base.indexcube.push`, `base.indexcube.pop`, `base.indexcube.here`, `base.indexcube.depth`, `base.indexcube.reset`. Basic implementations in place; no signing or route-log sync yet |
| `modules/context.tree.*` | CONTEXT-TREE doc (phase 1 "DONE") | **10 modules exist**: 4 checksum modules (`checksum.init_code`, `checksum.state`, `checksum.stream`, `checksum.template`), 1 index stub (`index.position`), 5 summary modules (`summary.add-event`, `summary.checkpoint`, `summary.compact.check` [stub], `summary.get-branch`, `summary.init-code`) |
| `modules/base.checksum-fs.*` | Phase-2 YAML (7 modules planned) | **NONE exist**. Planned: `init`, `store`, `retrieve`, `verify`, `deduplicate`, `cow-create`, `metadata-update` |
| `modules/search.*` | INDEXER-SEARCH doc | **NONE exist**. Specified: `search`, `search.harmonic`, `search.coordinates`, `search.visual`, `search.wave` |
| `modules/indexer.*` | INDEXER-SEARCH doc | **NONE exist**. Specified: `indexer.harmonic`, `indexer.checksum`, `indexer.visual`, `indexer.wave` |
| `modules/knowledge.*` | KNOWLEDGE_BASE_INDEXING doc | **NONE exist**. Specified: `knowledge.dedup.paragraph_cluster`, `knowledge.dedup.sentence_extract`, `knowledge.dedup.concept_unify`, `knowledge.storage.fragment_store`, `knowledge.zenka.query_interface` |
| `modules/base.p7ref*` / `*.p7ref.*` | CONTEXT-TREE doc | **10+ modules exist**: `base.p7ref.self`, `base.p7refs.gen_template_chksum`, `base.p7refs.get_refaddr_prefix`, `plugin.storage.p7ref.*` (7 modules: `init_code`, `index`, `nested-resolve`, `parse`, `resolve`, `search`), `storage.cmd.p7ref` |

### Existing Module Roles

The following modules are worth calling out because they can be reused rather than rebuilt:

- **`modules/index.gen_path`** — Takes a string or scalar ref, generates an anti-entropic directory path from AMOS checksum character matrix with truth filtering. Already used for checksum-derived directory trees. This is the closest thing to a "directory structure specification" that is actually running.
- **`modules/base.indexcube.push`** — Validates a P7REF (`TYPE:CHKSUM7:ADDR_B32`), timestamps it, and appends it to `@INDEXCUBE`. No cryptographic signing yet, but the data structure and validation logic are solid.
- **`modules/plugin.storage.checksum.map-file`** — Maps a filesystem path to its checksum (with mtime/size cache). Operates on the legacy path-based filesystem; useful as a migration bridge, not a replacement for content-addressed storage.
- **`modules/context.tree.checksum.state`** — Full resumable checksum state for incremental AMOS/ELF/BMW calculation. 389 lines, action-based interface (`create`, `add`, `finalize`, `save`, `load`, `clone`).
- **`modules/context.tree.checksum.stream`** — Position-aware stream checksums with `open`, `add_chunk`, `checksum_at`, `close` actions.

---

## 4. Design Tensions and Open Questions

### Tension 1: Width-1 namespace grid vs 19-bit border addressing

The topic vision file describes nodes as "single base32 character in namespace grid" (width-1 = fully public, zero attack surface). The CONTEXT-TREE doc describes 19-bit border addressing (13-bit L-matrix + 6-bit face selector).

**Resolution:** Width-1 is the **degenerate public case** of the larger scheme. A single base32 character occupies one coarse region of the 1001 cube topology, similar to how a /8 network prefix summarizes many /24 subnets. The 19-bit border address provides the internal routing precision used by P7REF and `@INDEXCUBE`; the width-1 grid is the user-facing visualization abstraction. They are the same coordinate plane at different zoom levels. No reconciliation is needed — visualization can render width-1 cells while routing uses the full 19-bit addresses underneath.

### Tension 2: `index.gen_path` vs phase-2 directory structure specification

`modules/index.gen_path` already implements anti-entropic path generation via AMOS checksum character matrix with truth filtering. The phase-2 YAML separately calls for a "directory structure specification" task.

**Resolution:** `index.gen_path` **subsumes the index-specific directory structure** question. It already splits checksum entropy into a deterministic, filtered directory tree. However, the phase-2 YAML's broader concern — metadata format, copy-on-write semantics, deduplication transactions, and migration tooling — is **not covered** by `index.gen_path`. The existing module is a building block, not a replacement for the full `base.checksum-fs.*` layer. The recommended path is to reuse `index.gen_path` inside `base.checksum-fs.store` rather than invent a second layout scheme.

### Tension 3: `@INDEXCUBE` as per-zenka stack vs network-wide grid

`@INDEXCUBE` is explicitly a per-zenka routing stack, while the checksum dataspace vision describes a network-wide grid.

**Resolution:** The per-zenka stack is a **local traversal trace** through the shared global grid. Cross-zenka handoff appends the foreign zenka's entry-point P7REF to the caller's stack, so the combined array represents a continuous route through the unified coordinate space. The stack is the view; the grid is the territory. This means searchable-index queries can be routed by comparing the query checksum against the `@INDEXCUBE` positions of candidate zenki without requiring a separate global routing table.

### Tension 4: `base.checksum-fs.*` vs `plugin.storage.checksum.map-file`

Phase-2 YAML proposes 7 new `base.checksum-fs.*` modules. The CONTEXT-TREE doc says storage goes through `plugin.storage.checksum.map-file`, which already exists.

**Resolution:** These are **different layers**. `plugin.storage.checksum.map-file` is a utility that maps an existing filesystem path to its checksum (with caching). It operates on the **legacy path-based filesystem**. `base.checksum-fs.*` is a full content-addressed filesystem abstraction with metadata, deduplication, and CoW semantics. The existing plugin is a bridge; the planned modules are the destination architecture. Both will coexist during migration: `map-file` ingests legacy files, `base.checksum-fs.store` places them into the new content-addressed tree.

### Tension 5: `search` zenka as standalone vs expanded `index.*`

The INDEXER-SEARCH doc specifies a standalone `search` zenka. No `search.*` or `indexer.*` modules currently exist, while `modules/index.*` is an older path/wordlist indexing system.

**Resolution:** Given the current state, the **cleanest incremental path** is to introduce `search.*` modules as a command/query layer that interfaces with the existing `index.*` infrastructure and the planned checksum filesystem. A full "search zenka" vs "index zenka" split is premature when neither the indexer nor the filesystem backend exists yet. The first implementation should be `search.checksum` and `search.visual` commands that can query whatever indexes are available, without requiring a fully separate zenka process. Once the backends mature, the command layer can be promoted to a zenka without changing its interface.

---

## 5. Actionable Sub-Components

Ordered by: (1) unblock visualization, (2) validate architecture on small test case, (3) extend to broader vision.

### 5.1 Index Visualization Data Endpoint for `space.v7.ax`

- **Effort:** small
- **Blockers / dependencies:** none — `space.v7.ax` template pipeline is already working
- **Acceptance criteria:**
  - A new HTTP endpoint (e.g., `/index/grid.json`) returns JSON describing the current checksum-derived namespace grid
  - Consumes output from `modules/index.gen_path` to map a small test directory (e.g., `modules/` or `data/md/`) into coordinate tuples
  - `space.v7.ax` renders at least one interactive view (grid or tree) from this endpoint
  - Endpoint is idempotent and reloadable for development

### 5.2 Code Repository Indexing Pipeline

- **Effort:** medium
- **Blockers / dependencies:** 5.1 (endpoint spec defines output shape)
- **Acceptance criteria:**
  - Batch process all files under `modules/` (or a representative subset), compute checksums via existing `base.chk-sum.*`, and generate a persistent JSON index
  - Index maps each file to `{ checksum, path, gen_path_result, size, mtime }`
  - The index is reloadable and idempotent (same input = same output)
  - No deduplication logic required at this stage
  - A command or cron-able module triggers re-indexing on demand

### 5.3 Checksum Filesystem Core (`base.checksum-fs.store` + `base.checksum-fs.retrieve`)

- **Effort:** medium
- **Blockers / dependencies:** none for design; 5.2 provides test content
- **Acceptance criteria:**
  - Implement `base.checksum-fs.store` and `base.checksum-fs.retrieve` (2 of the 7 planned modules)
  - Store uses `index.gen_path` for directory layout, writes a sidecar metadata YAML file
  - Retrieve returns content given a checksum, verifying integrity on read
  - Unit tests pass for store/retrieve round-trip with text and binary files
  - Error handling covers missing checksums, permission failures, and integrity mismatches

### 5.4 Search Query Command Layer (`search.checksum` + `search.visual`)

- **Effort:** medium
- **Blockers / dependencies:** 5.2 (needs indexed data to query); 5.3 optional but preferred
- **Acceptance criteria:**
  - Implement `search.checksum` command: exact checksum lookup and coordinate-range listing
  - Implement `search.visual` command: given a checksum, return N nearest neighbors by character-level distance
  - Commands return JSON suitable for both CLI and HTTP consumption
  - Integration test: index a directory, run a query, verify results contain expected files
  - Search results include enough metadata for `space.v7.ax` to render them

### 5.5 Storage-to-Filesystem Bridge (migrate `data/asc/what-AI-thinks/`)

- **Effort:** medium
- **Blockers / dependencies:** 5.3 (core filesystem must exist)
- **Acceptance criteria:**
  - Batch-import the 461 files in `data/asc/what-AI-thinks/` into the checksum filesystem
  - Preserve original paths in metadata
  - Report deduplication candidates (identical checksums) without auto-deletion
  - Verify round-trip integrity: every imported file retrievable by checksum
  - Generate a migration report showing file counts, unique checksums, and duplicates found

### 5.6 Knowledge Base Fragment Store (`knowledge.storage.fragment_store`)

- **Effort:** large
- **Blockers / dependencies:** 5.3 (checksum filesystem); 5.5 (proven migration workflow)
- **Acceptance criteria:**
  - Chunk markdown documents into paragraph-level fragments
  - Compute checksum per fragment, store in checksum filesystem
  - Build a manifest mapping document paths to ordered fragment checksums
  - Manifest itself is checksum-addressed
  - Test on a single directory (e.g., `data/md/design/`)
  - Provide a read command that reconstructs the original document from fragments

---

## 6. References

| Path | Unique Contribution |
|---|---|
| `data/ai-mem/claude/topic-searchable-index-and-visualization.md` | The current initiative vision: base32 namespace grid, width-1 security model, and UI-first phasing |
| `data/yaml/coding-tasks/phase-2-indexer-checksum-filesystem.yaml` | Full 70-110 hour implementation plan from Feb 2026: 7 `base.checksum-fs.*` modules, indexer upgrade, LLM file analysis |
| `data/md/design/INDEXER-SEARCH-ZENKA-INTEGRATION.md` | Specification of 4 search modes (harmonic, coordinate, visual, wave) and the indexer/search zenka split |
| `data/md/design/CONTEXT-TREE-INDEXCUBE-INTEGRATION.md` | P7REF coordinate system, 19-bit border addressing, 1001 cube topology, DTM, and covert channel signaling |
| `data/md/design/UNIFYING-PRINCIPLE-CHECKSUM-COORDINATES.md` | Foundational insight unifying information, documentation, and network layers under checksum coordinates |
| `data/md/system/CODING_TASK_KNOWLEDGE_BASE_INDEXING.md` | Knowledge-base deduplication plan: paragraph clustering, sentence extraction, concept unification, cubic spatial mapping |
| `data/md/coding-tasks/indexcube-routing-stack.md` | `@INDEXCUBE` push/pop/here/depth spec, per-zenka routing stack, and dual reading as compression index |
| `data/md/research/INDEX-DATA-FABRIC-DOCUMENTATION.md` | Index of the data-sync fabric docs; confirms Layer 1 (timestamps) is implemented, Layer 2 (checksums) is designed but pending |

---

*Last updated: 2026-04-17. This document is a synthesis reference; implementation tasks should use Section 5 as their starting checklist.*

#,,,.,,.,,.,.,,.,,.,,,,.,,,..,.,.,.,.,.,.,.,,,.,.,...,...,.,,,..,,,,,,..,,.,.,
#5JPSI53UI2GSHMDGQOUMTLSFOJUJICGRBVADUDPMAT573CLKSDNOC4KQZ5B2LVW5TGTRCYQ7SMWRS
#\\\|ZCBDFZNPP74IBXCSFZHAHMSQDRTLPVOHVYBK62RM3RYI2JA2LXY \ / AMOS7 \ YOURUM ::
#\[7]FAKJT3SSOKBK4M75X36DTPXGE57CHZYXUVXWPBEVLSU7ZTZLEODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
