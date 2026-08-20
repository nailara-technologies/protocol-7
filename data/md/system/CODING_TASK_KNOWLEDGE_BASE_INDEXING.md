# Coding Task: Protocol-7 Knowledge Base Deduplication & Indexing System

**Status**: PLANNED
**Priority**: HIGH - Foundation for knowledge accessibility layer
**Complexity**: Medium (well-defined problem, existing infrastructure)
**Timeline**: Multi-phase approach

---

## Executive Summary

Transform the Wave 1 Protocol-7 knowledge base (52K+ lines across 50+ documents) into a deduplicated, spatially-indexed, multi-frontend accessible system. Leverages existing:
- Checksum-based filesystem (AMOS)
- Cubic topology mapping
- Zenka session architecture
- Template rendering pipeline

**Goal**: Efficient browsing, LLM-friendly access, psychedelic visualizations of harmonic concepts.

---

## Phase 1: Knowledge Deduplication Engine

### Objective
Identify and merge overlapping content across all knowledge documents while preserving nuance.

### Deliverables

#### 1.1 Paragraph-Level Clustering
- **Input**: Raw markdown documents from `data/md/protocol-7-knowledge/`
- **Process**:
  - Extract paragraph boundaries (blank-line separated)
  - Generate semantic fingerprints (TF-IDF, embedding-based)
  - Cluster similar paragraphs (cosine similarity threshold)
  - Create merge candidates with confidence scores
- **Output**:
  - `clustering_results.json` - Identified duplicate clusters
  - `merge_candidates.csv` - (text_hash, doc1, para1, doc2, para2, confidence)

**Implementation approach**:
```
modules/knowledge.dedup.paragraph_cluster
- Load all .md files
- Parse paragraph boundaries
- Generate fingerprints (existing: base.chk-sum.*)
- Similarity scoring
- Output: candidates for review
```

#### 1.2 Sentence-Level Fact Extraction
- **Input**: Merged paragraphs + canonical versions
- **Process**:
  - Split into sentences
  - Extract atomic claims (subject-predicate-object)
  - Create fact graph with relationships
  - Identify fact dependencies
- **Output**:
  - `facts.jsonl` - One fact per line with relationships
  - `fact_graph.json` - Connected facts showing dependencies

**Implementation approach**:
```
modules/knowledge.dedup.sentence_extract
- Split paragraphs into sentences
- NLP tagging (or regex for harmonic terminology)
- Build dependency graph
- Output: normalized facts
```

#### 1.3 Concept Unification
- **Input**: Fact graph + redundant terminology
- **Process**:
  - Map synonyms (e.g., "ZENKI" = "zenka unit", "formation" = "pattern")
  - Create concept URIs (canonical identifiers)
  - Merge related facts under unified concept
  - Detect implicit relationships
- **Output**:
  - `concepts.json` - Canonical concept definitions
  - `concept_index.json` - Concept → facts mapping
  - `unified_knowledge_graph.json` - Complete graph with edges

**Implementation approach**:
```
modules/knowledge.dedup.concept_unify
- Load fact graph
- Apply synonym rules (configuration file)
- Create concept URIs using checksum (content-addressed)
- Build unified graph
```

---

## Phase 2: Cubic Topology Spatial Mapping

### Objective
Assign knowledge fragments to cubic coordinates (x,y,z) within Protocol-7 spatial structure.

### Deliverables

#### 2.1 Topology Coordinate Assignment
- **Input**: Unified concept graph + hierarchy
- **Process**:
  - Map 10 major topic branches to cubic regions
  - Assign x,y,z coordinates to concepts
  - Place related concepts near each other
  - Account for 3³ sub-cube recursion
- **Output**:
  - `topology_coordinates.json` - concept → (x,y,z)
  - `spatial_organization.visualization` - ASCII/JSON diagram

**Coordinate scheme**:
```
Layer 0-2: 01_FOUNDATIONS (0,0,0-2)
Layer 3-5: 02_CORE_STRUCTURES (1,0,0-2)
Layer 6-8: 03_NETWORK_PROTOCOLS (2,0,0-2)
... etc, filling 8³ cubic space
```

#### 2.2 Wormhole Link Creation
- **Input**: Topology coordinates + concept relationships
- **Process**:
  - Identify cross-topic relationships
  - Create symbolic links (wormhole shortcuts)
  - Map to existing hyperspace filesystem
  - Store as symlinks in `/etc/protocol-7/knowledge/topology/`
- **Output**:
  - Symlink structure matching cubic topology
  - Navigation paths between concepts

---

## Phase 3: Checksum-Based Content Addressing

### Objective
Store deduplicated knowledge fragments using AMOS checksum infrastructure.

### Deliverables

#### 3.1 Fragment Storage
- **Input**: Unified concept graph + atomic facts
- **Process**:
  - Break knowledge into addressable fragments (paragraphs/facts)
  - Compute AMOS checksums for each fragment
  - Store in content-addressed store: `/var/knowledge/fragments/{checksum}`
  - Create metadata files with relationships
- **Output**:
  - Fragment store with checksum-based organization
  - Manifest file listing all fragments

**Implementation approach**:
```
modules/knowledge.storage.fragment_store
- Load concepts + facts
- Chunk into fragments
- Compute checksums (use base.chk-sum.*)
- Write to versioned storage
- Create index: checksum → metadata
```

#### 3.2 Deduplication Finalization
- **Input**: All fragment stores
- **Process**:
  - Identify identical fragments (same checksum)
  - Create redirect map (dup_checksum → canonical_checksum)
  - Validate all relationships through canonical forms
  - Update topology symlinks to canonical versions
- **Output**:
  - Final deduplicated knowledge base
  - Redirect map for legacy references

---

## Phase 4: Multi-Frontend Query Interface

### Objective
Expose knowledge through zenka-compatible query protocol supporting multiple frontend formats.

### Deliverables

#### 4.1 Query Zenka Module
- **Input**: User queries (text, concept, spatial coordinates)
- **Process**:
  - Parse query (keyword, regex, concept URI, (x,y,z) bounds)
  - Traverse concept graph / topology
  - Retrieve matching fragments
  - Format response for target frontend
- **Output**: Query results in requested format

**Implementation approach**:
```
modules/knowledge.zenka.query_interface
- Receive query (cmd: search, navigate, related)
- Query concept graph
- Retrieve fragments from store
- Format output (HTML, JSON, LLM, ASCII)
- Return to requester
```

#### 4.2 Frontend-Specific Output Formats

**HTML/Web Frontend**:
- Rendered markdown with visual hierarchy
- Interactive concept graph visualization
- Psychedelic color scheme (harmonic frequencies as hue)
- 3D cubic topology viewer (WebGL)

**LLM-Facing Format**:
- Compact JSON with full context
- Minimal markup (section headers, code blocks)
- Optimized for embedding/context windows
- Token-efficient serialization

**Internal Zenka Interface**:
- Protocol-7 binary format (efficient over network)
- Partial/streaming results
- State preservation for multi-turn queries

**CLI/ASCII Format**:
- Structured text with indentation
- ASCII diagrams for topologies
- Searchable via grep/awk

---

## Phase 5: Template Rendering System

### Objective
Enable beautiful, interactive presentation of knowledge across frontends.

### Deliverables

#### 5.1 Psychedelic Knowledge Visualization
- **Input**: Concept graph + topology
- **Process**:
  - Map harmonic frequencies to colors
  - Use layer depth for brightness/saturation
  - Animate concept relationships
  - Create fractal-like recursive views
- **Output**: Visual representations suitable for different contexts

**Technology stack** (integrate with httpsd):
- Backend: Perl modules (generate data)
- Frontend: WebGL (Three.js) for 3D views
- 2D: HTML5 Canvas or SVG
- CSS: Custom stylesheet for harmonic color schemes

#### 5.2 Template Framework
- **Input**: Knowledge fragments + target format
- **Process**:
  - Create template system (similar to httpsd templates)
  - Support variable substitution (concept name, description, links)
  - Include partial templates (headers, footers, concept cards)
  - Handle recursive rendering (nested concepts)
- **Output**: Rendered knowledge in target format

**Template types**:
```
knowledge/templates/
├── web/
│   ├── concept_card.html
│   ├── topology_viewer.html
│   ├── search_results.html
│   └── psychedelic_base.css
├── llm/
│   ├── concept_json.tmpl
│   ├── fact_list.tmpl
│   └── context_window.tmpl
├── zenka/
│   ├── binary_response.tmpl
│   ├── streaming_facts.tmpl
│   └── protocol_wrapper.tmpl
└── ascii/
    ├── tree_view.txt
    ├── concept_diagram.txt
    └── topology_map.txt
```

---

## Phase 6: Integration with HTTPS Frontend (Priority)

### Objective
Complete httpsd integration to enable immediate visual feedback for knowledge work.

### Deliverables

#### 6.1 Knowledge Zenka Endpoints
- `GET /knowledge/search?q=<query>` - Search knowledge base
- `GET /knowledge/concept/<uri>` - View concept details
- `GET /knowledge/topology/<x>/<y>/<z>` - Navigate by coordinates
- `GET /knowledge/related/<uri>` - Find related concepts
- `GET /knowledge/graph` - Full concept graph (JSON/WebGL)

#### 6.2 Psychedelic UI
- Landing page: Animated cubic topology
- Search interface: Real-time concept discovery
- Concept view: Harmonic color coding, relationships
- Graph view: Interactive 3D topology navigation
- Template system: Shared aesthetics across all views

#### 6.3 LLM-Facing Endpoints
- `GET /knowledge/api/concept/<uri>?format=json` - Compact JSON
- `GET /knowledge/api/facts/<uri>` - Fact list
- `GET /knowledge/api/context/<uri>?depth=n` - Full context

---

## Implementation Order (Recommended)

```
PRIORITY 1: Complete HTTPS frontend (Phase 6)
├─ Finish letsencr certificate integration
├─ Add httpsd template system
├─ Create basic psychedelic CSS
└─ Deploy working HTTPS frontend

PRIORITY 2: Content deduplication (Phase 1)
├─ Paragraph clustering
├─ Sentence extraction
└─ Concept unification

PRIORITY 3: Spatial organization (Phase 2)
├─ Cubic coordinate assignment
└─ Wormhole link creation

PRIORITY 4: Storage & indexing (Phase 3)
├─ Fragment store implementation
└─ Deduplication finalization

PRIORITY 5: Query system (Phase 4)
├─ Query zenka module
└─ Output format handlers

PRIORITY 6: Rendering templates (Phase 5)
├─ Visualization system
└─ Template framework
```

---

## Success Criteria

- [ ] **Phase 1**: Zero information loss after deduplication (verified by expert review)
- [ ] **Phase 2**: All concepts spatially mapped, accessible by (x,y,z)
- [ ] **Phase 3**: 100% of knowledge content checksummed and stored
- [ ] **Phase 4**: Query interface handles 10+ concurrent clients
- [ ] **Phase 5**: Psychedelic UI loads in <500ms, renders in <1s
- [ ] **Phase 6**: HTTPS frontend live with knowledge search working
- [ ] **Integration**: All frontends (web, LLM, zenka) functional

---

## Technical Constraints & Assumptions

- **Perl-based** (matches Protocol-7 architecture)
- **Reuses existing** checksum, zenka, and template infrastructure
- **No external NLP libraries** (use regex + heuristics initially)
- **Storage**: Local filesystem initially (scale later if needed)
- **Frontend**: HTTPS via httpsd (no separate service)

---

## Open Questions

1. **Synonym rules**: Centralized config file or distributed in modules?
2. **Update frequency**: How often to re-deduplicate as knowledge evolves?
3. **Versioning**: Track changes to concepts over time?
4. **Sharing**: Export deduplicated knowledge to other systems?
5. **Visualization**: Color scheme mapping for harmonic frequencies?

---

## Related Resources

- Knowledge base: `data/md/protocol-7-knowledge/`
- AMOS checksum system: `modules/base.chk-sum.*`
- Cubic topology docs: `data/md/protocol-7-knowledge/02_CORE_STRUCTURES/`
- httpsd templates: `cfg/httpsd/templates/`
- Zenka architecture: `CLAUDE.md` (Multi-Agent System section)

---

## Notes

This is a "straightforward work" task (Phase 6 especially) - no algorithmic breakthroughs needed, just systematic implementation. The payoff is immediate: beautiful, interactive knowledge browsing that makes deduplication work engaging and verifiable.

Wave 2 refinement will happen naturally through reviewing and correcting the visual representations.

#,,..,..,,..,,,.,,,.,,,.,,...,..,,,.,,.,.,.,,,..,,...,...,,,.,..,,...,,,,,...,
#Q6X3V5PXCHBXP2ENR6XG7RQ2ILEHVC2TZ2U33Y2GUMHROEZEIVT6Z5UTCLCO3MHVVB2ZCDLT7YHYW
#\\\|DAVVD5WWK7MVRJ3SIAN2UPGBZ62ANHOAREC5YZKXWZFU3GBL54E \ / AMOS7 \ YOURUM ::
#\[7]TCS56QO6DJP4QC5X3YFBVFB74R7WWILC7G5Q7YZE6WUWZNJOL2CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
