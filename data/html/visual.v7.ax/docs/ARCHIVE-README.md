# Protocol-7 Topology Visualization Archive

This directory contains 42 visualization files tracking the evolution of Protocol-7 cubic topology representations.

## Quick Start

**Current Production Version:**
- **File**: `../production/grid-v13-final-baseline.html`
- **Size**: 47.4 KB
- **Date**: 2026-02-07
- **Status**: ✅ Production-ready
- **Key Features**:
  - Topologically correct 8x63 sub-cube node group visualization
  - Correct propagation beyond node group
  - Advanced mouse navigation
  - Recursive planes at larger zoom scales (Matrix-like effect)
  - Ready for deployment to http://visual.v7.ax/

**Deploy command**:
```bash
cp ../production/grid-v13-final-baseline.html /path/to/visual.v7.ax/index.html
```

## Archive Organization

### Generation 1: Early Experiments (v1/)
Early aesthetic and architectural exploration.
- **Files**: 4
- **Date Range**: March 2025
- **Size Range**: 25-61 KB
- **Purpose**: Research artifacts exploring different visual paradigms

Key files:
- `quantum-gateway.html` - Quantum-inspired effects
- `cosmic-shell.html` - Space-themed topology
- `bioluminescent.html` - Organic/glowing aesthetic
- `snake-formation.html` - Serpentine node arrangement

### Generation 2: Hyperspace Variants (v2/)
Refined topology with focus on spatial relationships.
- **Files**: 14
- **Date Range**: Feb 3-5, 2025
- **Size Range**: 19-35 KB
- **Purpose**: Testing coordinate projection methods

Key progression files:
- `hyperspace-clean.html` → Minimalist approach
- `with-neighbors.html` → Shows connections explicitly
- `unified-topology.html` → Comprehensive representation
- `hyperspace-v2.html` → Second generation
- `hyperspace-v3.html` → Third generation with improvements
- `infinite-zoom.html` → Zoom capability testing

### Generation 3: Network-Grid Series (v3/)
Cubic grid topology with progression toward correctness.
- **Files**: 23 (including variants)
- **Date Range**: Feb 4-7, 2025
- **Size Range**: 23-46 KB
- **Purpose**: Cubic topology refinement, leading to production

Progression path (recommended reading order):
1. `grid-v4.html` → Initial cubic grid
2. `grid-v8.html` → Feature expansion
3. `grid-v11.html` → Stabilization point
4. `grid-v13.html` → Major advancement (topology correctness focus)
5. `grid-v13-copy4.html` - `grid-v13-copy7.html` → Final refinements

**Note on duplicates**: Files like `grid-v11-copy1.html`, `grid-v12-copy1.html`, `grid-v13-copy1.html` are near-duplicates from the original batch. Kept for research completeness but `grid-v11.html`, `grid-v12.html`, `grid-v13.html` are the canonical versions.

## Detailed Manifest

See `MANIFEST.yaml` for comprehensive documentation of:
- Each file's visual properties
- Key differences from previous versions
- Visual features explored
- Research value classification

## Using the Archive

### For Research
Each file explores different visual approaches to cubic topology representation.
Compare side-by-side to understand evolution of ideas.

### For Template Extraction (Future)
These files will be decomposed into reusable visual elements:
- Coordinate projection techniques
- Node rendering styles
- Connection visualization methods
- Interaction patterns
- UI components

### For Validation (Phase 4)
The production version will be compared against the actual cubic topology
implementation being built in Phase 4 to verify correctness.

## File Size Distribution

| Range | Count | Examples |
|-------|-------|----------|
| 19-25 KB | 5 | hyperspace-clean, adaptive |
| 25-35 KB | 12 | bioluminescent, network-desktop |
| 35-47 KB | 25 | grid-v10 through grid-v13.7.1 |

**Total Archive Size**: ~1.3 MB

## Next Steps

### Phase 1 (Current)
- [x] Organize files
- [x] Create semantic naming
- [x] Generate manifest
- [ ] Deploy production version to http://visual.v7.ax/
- [ ] Create README for web serving

### Phase 4 (Topology Implementation)
- Use production version as validation tool
- Compare actual topology with visualization
- Verify 8x63 node group structure

### Future (WebKit3 Automation)
- Generate visual diffs between versions
- Automate screenshot capture
- Create visual regression test suite
- Enable LLM-assisted visualization refinement

## Research Notes

### Key Observations
1. **Size growth**: Early versions (19-25 KB) → Later versions (44-47 KB)
   - Indicates feature/complexity addition
   - Not necessarily bloat (structure/interaction improvements)

2. **Naming evolution**: From aesthetic (quantum-gateway) → functional (network-grid-v13)
   - Reflects shift from experimental to engineering focus

3. **Variant clustering**: Multiple copies near v13
   - Indicates final refinement push
   - Suggests convergence on topology correctness

### Visual Properties Tracked
- **Aesthetic**: Colors, glows, effects, themes
- **Structural**: Node placement, connection patterns, layouts
- **Interaction**: Zoom, pan, rotation, navigation
- **Performance**: File size, likely rendering optimization
- **Topology**: Connection accuracy, neighbor representation, propagation

## Questions to Explore

When decomposing into templates:
1. Which visual properties are essential vs. decorative?
2. What interaction patterns are most effective?
3. How does zoom affect perception of topology?
4. What color schemes best represent node relationships?
5. How do recursive planes affect understanding at different scales?

---

**Archive Created**: 2026-02-07
**Total Files**: 42 visualizations + 2 documentation files (this README + MANIFEST.yaml)
**Organization**: 3 research generations + 1 production version
**Status**: Ready for Phase 1 completion and Phase 4 validation
