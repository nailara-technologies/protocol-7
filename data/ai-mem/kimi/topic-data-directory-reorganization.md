# Data Directory Structure Reorganization (March 2026)

> Extracted from MEMORY.md. See main memory for cross-references.

## Overview
Reorganized `data/yaml/` and `data/md/` directories to eliminate root clutter and establish clear categorization patterns. All loose files now have proper homes.

## Directory Structure Created

**data/yaml/:**
```
archive/
  build-logs/           # Build history files
  broken-symlinks/      # Moved broken symlinks (point to ../asc/...)
  completed-tasks-archive.yaml
  deferred-tasks/
  completed-fix-tasks/
  completed-coding-tasks/
build-instructions/     # Build configurations
code-reviews/           # Module review documents
code-style/             # CONVENTIONS.yaml, STYLE-AS-SYNTAX.yaml
coding-tasks/           # Active task definitions
docs/
  architecture/         # ARCHITECTURE-NOTES.md, DESIGN-PRINCIPLES.md
  formats/              # Signature format specs
  processing/           # Processing workflows
  workflows/            # Git, LLM, buffer workflows
docs/                   # PHASE-4-YAML-TOOL-CALLING.md, yaml-tool-calling-system.md
indexes/                # todos-index.yaml, workspace-transfer-index.yaml
meta/                   # (created for future metadata)
project-context/        # Session summaries and plans
research/               # fabric-reference, image-batch-processing, vision-models-registry
system/                 # Configuration templates, symlink-chains, templates
```

**data/md/:**
```
archive/
  completed-sessions/   # Session status/history
  completed-projects/   # Completed project docs
architecture/           # System architecture docs
concepts/               # CONCEPT-* files (moved from root)
data-zenka/             # Data zenka documentation
design/                 # VTERM, GFX toolkit specs
design-patterns/        # symlink-chains.md
development/            # Integration, coding docs
documentation/          # General documentation
guides/
  deployment/           # CUDA rebuild instructions
  testing/              # TOFU testing plan
investigation/
  yaml/                 # YAML gateway investigations
philosophy/             # Harmonic entropy, anti-entropic principles
protocol-7-knowledge/   # Structured knowledge base (00-09 topics)
research/               # holographic-topology-research, comprehensive-research
system/                 # CODING_TASK_KNOWLEDGE_BASE, MENU-CHECKLIST, SCENARIO-JOURNEY
vision/                 # VISION docs (complete, data-sync, timestamp)
  habitat/              # Context, nomadic, desktop UX
  infrastructure/       # Tool-use protocol, dev environment
  topology/             # Routes as signatures
```

## Key Moves Made

**From data/yaml/ root:**
- ARCHITECTURE-NOTES.md → docs/architecture/
- DESIGN-PRINCIPLES.md → docs/architecture/
- PHASE-4-YAML-TOOL-CALLING.md → docs/
- protocol-7-coding-style.md → docs/
- yaml-tool-calling-system.md → docs/
- SELF-IMPROVING-AGENT-ECOSYSTEM.md → docs/
- build-ik_llama_* → archive/build-logs/
- level-3-configuration-templates.yaml → system/
- symlink-chains.yaml → system/
- template-markup-syntax.yaml → system/
- zenki-creation-requirements.yaml → system/
- protocol-7-export-tasks-manager.yaml → system/
- workflow-suggestions.yaml → system/
- fabric-reference-architecture.yaml → research/
- image-batch-processing-architecture.yaml → research/
- vision-models-registry.yaml → research/
- completed-tasks-archive.yaml → archive/
- protocol-7-coding-style-refactoring-2025-12.yaml → code-style/

**From data/md/ root:**
- CONCEPT-*.md (7 files) → concepts/
- holographic-cubic-topology-research-2026-01-13.md → research/
- protocol7-comprehensive-research-feb2026.md → research/
- FABRIC-*.md (3 files) → research/
- GENERIC-DATA-SYNCHRONIZATION-FABRIC.md → research/
- INDEX-DATA-FABRIC-DOCUMENTATION.md → research/
- CODING_TASK_KNOWLEDGE_BASE_INDEXING.md → system/
- PROTOCOL-7-MENU-IMPLEMENTATION-CHECKLIST.md → system/
- SCENARIO-TRAIN-JOURNEY-ADAPTIVE-BUFFERING.md → system/
- VISION-*.md (3 files) → vision/

**Broken symlinks (all pointed to ../asc/... which doesn't exist):**
- harmonic-visualization-principles.md → archive/broken-symlinks/
- holistic-convergence-roadmap.md → archive/broken-symlinks/
- models-zenka-complete-architecture.md → archive/broken-symlinks/
- pattern-repository-and-authentic-agency.md → archive/broken-symlinks/
- protocol7-holistic-convergence-architecture.yaml → archive/broken-symlinks/
- the-receipts-efficiency-principle.md → archive/broken-symlinks/

**Cross-location move:**
- protocol7-math-topology-reference.yaml (was in md/) → yaml/research/

## Result
Both `data/yaml/` and `data/md/` root directories are now clean - no loose files. All content is categorized for easier navigation and maintenance.

#,,,,,,..,..,,,,,,.,,,.,.,.,,,,..,.,.,,.,,,,,,..,,...,...,.,,,.,.,.,,,..,,.,.,
#PP3UANYIU67ZCPF2BPVOWC6BMB4TZZAYTUGJ2PNPYPUNEH54WWQFBPCCJNFKQACGRNAWOY7DR24AO
#\\\|JHUZ2OUMJKUWGOPVCQKIG3LGKQJC4MV47WRXCQ7QKM6Y3JQCJGR \ / AMOS7 \ YOURUM ::
#\[7]FWBYQJPRFFDB6FNVFUFEU733ZCCKM7SOJQ3REIZLRNLLPSVCYQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
