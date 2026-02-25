# Protocol-7 Vision Documents

Strategic direction, architectural vision, and actionable design specifications.
Documents are grouped by horizon and concern. Each references existing modules
and commits where the vision is already actualized.

---

## habitat/ — The Living Network

Nomadic zenki, session identity, litter groups, context compaction, network UX.
The vision of the network as a habitat that builds itself as it gets inhabited.

| Document | Summary |
|----------|---------|
| `VISION-NOMADIC-ZENKI-HABITAT.md` | Litter groups carrying state through topology, logical gain vs actual dependency, self-improvement loop |
| `VISION-SESSION-IDENTITY.md` | Earned identity, self-chosen names, P7REF group formation, capability declaration, model as native inhabitant |
| `VISION-CONTEXT-COMPACTION.md` | Wave-0 through wave-4 compaction, token economics, crystallization vs session restart |
| `VISION-NETWORK-DESKTOP-UX.md` | create-litter flow, topology visualization, right-click menu, living map property |

---

## infrastructure/ — The Development Environment

Replacing the external shell with native Protocol-7 infrastructure.
SSH zenka as immediate bridge; native P7 links as destination.

| Document | Summary |
|----------|---------|
| `VISION-P7-DEVELOPMENT-ENVIRONMENT.md` | What's already built, the missing tool-use layer, SSH bridge to pri.v7.ax, transition stages |
| `VISION-TOOL-USE-PROTOCOL.md` | Tool call format, dispatch layer, file/shell/network tool zenki, safety model, implementation checklist |

---

## topology/ — The Coordinate Foundation

The mathematical and philosophical foundation that makes the other layers coherent.
Routes as identity, computation as path, emergence at multiple scales.

| Document | Summary |
|----------|---------|
| `VISION-ROUTES-AS-SIGNATURES.md` | Routes as identity, computation as path, desirability-based persistence, the string becoming elements |

---

## Related Existing Documents

These earlier documents established foundations that the above build on.
Candidates for eventual relocation into this directory structure:

| Document | Location | Relation |
|----------|----------|---------|
| `CONCEPT-CUBIC-HYPERSPACE-DESKTOP.md` | `data/md/` | 3D topology as desktop — precursor to NETWORK-DESKTOP-UX |
| `CONCEPT-SELF-MOVING-REFERENCES-VISUAL-HABITAT.md` | `data/md/` | Visual habitat dynamics — precursor to NOMADIC-ZENKI-HABITAT |
| `VISION-COMPLETE-ARCHITECTURE.md` | `data/md/` | Three-layer architecture overview |
| `VISION-TIMESTAMP-CHECKSUM-DUALITY.md` | `data/md/` | Checksum as coordinate — foundation for ROUTES-AS-SIGNATURES |
| `CONCEPT-NETWORK-INTUITION-LAYER.md` | `data/md/` | Network-level pattern recognition |
| `CONCEPT-VISUAL-CONSENSUS-RESOURCE-ECONOMY.md` | `data/md/` | Resource allocation through visual consensus |
| `DATA_ZENKA_SHM_MOUNTING.md` | `data/md/data-zenka/` | SHM implementation — foundation for habitat layer |
| `DATA_ZENKA_HOLOGRAPHIC_TOPOLOGY.md` | `data/md/data-zenka/` | Topology implementation — foundation for ROUTES-AS-SIGNATURES |

---

## Actualization Status

What exists now vs what the vision requires:

### Already Built (Feb 2026)
- ✅ P7REF as first-class type (`base.p7refs.*`, `base.syntax.p7_reference`)
- ✅ Data zenka with FUSE mount, SHM, holographic topology (97 modules)
- ✅ Coding zenka with task queue, model switching, dependency-based spawning
- ✅ Models zenka with chat, memory system, local model routing
- ✅ SSH zenka (recovered + improved) — bridge to pri.v7.ax
- ✅ nshell + ncode — interactive terminal interface

### Immediate Next Steps
- [ ] Tool-use dispatch layer in coding zenka (see VISION-TOOL-USE-PROTOCOL.md)
- [ ] File tool zenki (read/write/edit/search/glob)
- [ ] Context compaction wave-1 in models.chat buffer
- [ ] SSH zenka bridge: coding session on pri.v7.ax

### Near-term
- [ ] Session route tracking in data zenka sub-tree
- [ ] Context persistence across connection drops
- [ ] Capability inference and name declaration protocol
- [ ] P7REF group formation for session identity
- [ ] Topology visualization prototype

### Medium-term
- [ ] Litter coordination via SHM channels
- [ ] Parallel branch dependency resolution
- [ ] Wave-2 through wave-4 compaction
- [ ] Network zenka tool tier (model as full network participant)
- [ ] Network desktop prototype with live topology rendering

#,,,,,.,,,,.,,.,,,.,.,,.,,,..,,,.,,,,,,,.,,.,,..,,...,...,,,.,..,,,,.,...,.,.,
#6PBZYMKKHORATZKF6DNFB5MG76K7DEVUN2FTTBZ5FOZEZTNZAYCQYYUZO2ZSH2RPNHWC3JM64FSDA
#\\\|TXS76IGLWZY6O2NURVRZHOMMWQA2HKI6APJSIZO66AIMD5OPSD7 \ / AMOS7 \ YOURUM ::
#\[7]NSXY5SJ3PK2PE27KFAFUQZWGCHF5HGXVGPIW7ENQOJ25CAMHNMDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
