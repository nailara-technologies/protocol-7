# VTERM Buffer System Specification

## Context & Purpose

This document captures the design and implementation of the `vterm.*` module namespace, created to support **visual consensus rendering** for Protocol-7's distributed terminal system. The work emerged from discussions around:

1. **Harmonic Visual Intelligence** (`CONCEPT-HARMONIC-VISUAL-INTELLIGENCE.md`)
2. **Decoder VTERM Architecture** (`DECODER-VTERM-ARCHITECTURE.md`)
3. The **5-of-7 Byzantine consensus algorithm** with sub-bit voting

The vterm system provides a **generic, reusable terminal buffer infrastructure** that any zenka can use for multi-layer visual output with built-in consensus visualization.

---

## Core Concepts

### The 11-Member Consensus Body

The system implements the mathematical structure `-5..0..+5`:
```
-5  -4  -3  -2  -1   0   +1  +2  +3  +4  +5
 └── NEGATIVE 5 ──┘   ↑   └── POSITIVE 5 ──┘
                  0 = ROUTER
                  (alternation phase memory)
```

- **±5 threshold**: Declaration boundary (SET/CLEAR)
- **0 state**: The 11th member holding the alternation secret
- **Even/odd phase**: Routes between positive/negative consensus

### Visual Consensus Mechanism

When 5+ layers agree on pixel state → **sharp, visible output**
When <5 agree → **sub-visible interference pattern** (blur/ghost trails)

This makes Byzantine fault tolerance **visually perceivable** - disagreement literally creates visual artifacts.

---

## Module Architecture

Protocol-7 enforces: **one callable = one file**. The vterm namespace follows this strictly.

### Core Dispatchers (Action-based)

| Module | Purpose |
|--------|---------|
| `vterm.init_code` | Constants, configuration, SHM auto-detection |
| `vterm.cell` | 16-byte cell structure (pack/unpack/create) |
| `vterm.instance` | Buffer lifecycle management per zenka |
| `vterm.shm` | Shared memory interface (optional, auto-fallback) |
| `vterm.subbit` | Sub-bit voting accumulator |
| `vterm.consensus` | 5-of-7 consensus computation |
| `vterm.compositor` | Layer blending and forensic modes |

### Extracted Helpers (Individual files)

**SHM utilities:**
- `vterm.shm.path` - Generate SHM path for layer

**Sub-bit operations:**
- `vterm.subbit.check_threshold` - Test ±5 boundary, update state
- `vterm.subbit.determine_route` - 0-state routing from alternation history

**Consensus functions:**
- `vterm.consensus.check_channel` - Declaration test (set/clear/superposition)
- `vterm.consensus.declaration_value` - Convert declaration to RGB value
- `vterm.consensus.interference_pattern` - Sub-visible blur calculation
- `vterm.consensus.ghosts` - Identify dissenting layers
- `vterm.consensus.cell_fingerprint` - Sub-bit fingerprint for agreement check

**Blend modes:**
- `vterm.compositor.blend.consensus` - 5-of-7 weighted blend
- `vterm.compositor.blend.normal` - Overlay (last layer wins)
- `vterm.compositor.blend.additive` - Glow effect blend

**Forensic layouts (placeholders):**
- `vterm.compositor.layout.grid` - Grid arrangement
- `vterm.compositor.layout.stack` - Vertical stack
- `vterm.compositor.layout.diff` - Difference view

**Utilities:**
- `vterm.util.clamp` - Numeric range clamping

---

## Cell Structure (16 bytes)

```
┌──────────┬──────────┬──────────┬──────────┐
│ subbit_r │ subbit_g │ subbit_b │ subbit_attr│  # Sub-bit accumulators (-128..+127)
├──────────┼──────────┼──────────┼──────────┤
│ codepoint (4 bytes)                     │  # UTF-8 or raw
├──────────┼──────────┼──────────┼──────────┤
│ fg_r │ fg_g │ fg_b │ attrs                 │  # Declared foreground + attributes
├──────────┼──────────┼──────────┼──────────┤
│ bg_r │ bg_g │ bg_b │ state                 │  # Background + consensus state
├──────────┼──────────┼──────────┼──────────┤
│ confidence │ alternation │ vote_count │ last_update │  # Metadata
└──────────┴──────────┴──────────┴──────────┘
```

**State values:**
- `0` = SUPERPOSITION (voting in progress, -4 to +4)
- `1` = DECLARED_SET (+5 reached)
- `2` = DECLARED_CLEAR (-5 reached)
- `3` = INDETERMINATE (no consensus)
- `4` = ERROR (corruption detected)

---

## Configuration (Idempotent Init)

All settings use `<vterm.X> //= default` pattern:

```perl
<vterm.subbit.threshold>     //= 5         # ±5 declaration
<vterm.consensus.threshold>  //= 5         # 5 of 7 agree
<vterm.shm.enabled>          //= FALSE     # Optional SHM
<vterm.shm.use_data_zenka>   //= FALSE     # Auto-detect data zenka
<vterm.compositor.blend_mode> //= 'consensus_5of7'
```

---

## Usage Pattern

```perl
## 1. Initialize (loads via init_code)
<[vterm.init_code]>;

## 2. Create instance
my $vterm = <[vterm.instance]>->('create', {
    zenka   => 'decoder',
    rows    => 24,
    cols    => 80,
    layers  => 7,  # 5 positive + 2 secret-holders
});

## 3. Write sub-bit votes from peers
foreach my $peer_id (0..6) {
    my $cell = <[vterm.cell]>->('create');
    <[vterm.subbit]>->('vote', $cell, +1, 'even', 'r');
    <[vterm.shm]>->('write_cell',
        $vterm->{layers}{$peer_id}, $x, $y, $cell);
}

## 4. Composite to output (layer 13)
<[vterm.compositor]>->('blend', {
    layers => [map { $vterm->{layers}{$_} } 0..6],
    mode   => 'consensus_5of7',
    output => $vterm->{output_layer},
});

## 5. Forensic mode when investigating disagreement
<[vterm.compositor]>->('forensic_expand', {
    layers    => [map { $vterm->{layers}{$_} } 0..6],
    layout    => 'grid',
    highlight => 'dissent',
});
```

---

## SHM Integration

The system gracefully degrades:
1. **First**: Try data zenka SHM mounting (`data.shm.mount` or `data.mount_hash`)
2. **Fallback**: Local hash storage (`$data{'vterm'}{'local_shm'}`)
3. **Always works**: No external dependencies required

Path format: `/dev/shm/p7:vterm:<cube>:<layer_id>`

---

## Connection to Broader System

### Relation to stdout log redirection
The recently implemented `v7.setup_stdout_redir` system was the **text-mode prototype** for this architecture:
- tmpfs backing → SHM backing
- Ring buffer rotation → Spiral sync priority
- Early message capture → Sub-bit superposition
- Color preservation → Full RGB consensus blending

### Relation to 5-of-7 consensus
This is the **visual implementation** of the mathematical framework:
```yaml
temporal_structure:
  phases: 7
  consensus: "5 of 7"
  byzantine_tolerance: true
```
The vterm system demonstrates 5-of-7 consensus at the pixel level.

### Relation to Decoder/Zulum
The `decoder` zenka will use vterm as its rendering backend:
- 7 zulum streams → 7 input layers
- Division-by-13 truth → Sub-bit harmonic assertion
- Spiral sync → Damage-priority rendering
- Layer 13 → Compositor output

---

## Files Created (22 modules)

```
modules/vterm.init_code
modules/vterm.cell
modules/vterm.instance
modules/vterm.shm
modules/vterm.shm.path
modules/vterm.subbit
modules/vterm.subbit.check_threshold
modules/vterm.subbit.determine_route
modules/vterm.consensus
modules/vterm.consensus.check_channel
modules/vterm.consensus.declaration_value
modules/vterm.consensus.interference_pattern
modules/vterm.consensus.ghosts
modules/vterm.consensus.cell_fingerprint
modules/vterm.compositor
modules/vterm.compositor.blend.consensus
modules/vterm.compositor.blend.normal
modules/vterm.compositor.blend.additive
modules/vterm.compositor.layout.grid
modules/vterm.compositor.layout.stack
modules/vterm.compositor.layout.diff
modules/vterm.util.clamp
```

---

## Status & Next Steps

**Completed:**
- ✅ Core architecture following P7 module rules
- ✅ 16-byte cell format with sub-bit accumulators
- ✅ 5-of-7 consensus algorithm
- ✅ SHM integration with data zenka auto-detect
- ✅ Three blend modes (consensus, normal, additive)
- ✅ Sub-bit voting with ±5 threshold
- ✅ 0-state routing (the 11th member)

**Placeholder stubs:**
- ⏳ Forensic layout implementations (grid/stack/diff)
- ⏳ Actual SHM read/write for data zenka mounted paths
- ⏳ Damage tracking and spiral sync optimization

**Next steps for decoder integration:**
1. Implement `decoder` zenka initialization using vterm
2. Connect 7 zulum streams to input layers
3. Wire cube-13 routing to sub-bit votes
4. Add Term::VTerm Screen integration for actual terminal output

---

## Design Principles Observed

1. **Generic namespace**: `vterm.*` usable by any zenka, not decoder-specific
2. **Optional dependencies**: SHM features auto-detect, gracefully degrade
3. **Idempotent init**: All config uses `//=` pattern
4. **One callable = one file**: Strict P7 architecture compliance
5. **Mathematical fidelity**: Faithful implementation of 5-of-7 sub-bit consensus
6. **Visual truth**: Consensus failures are perceivable as blur/ghosts

---

## References

- `data/md/design/CONCEPT-HARMONIC-VISUAL-INTELLIGENCE.md`
- `data/md/design/DECODER-VTERM-ARCHITECTURE.md`
- `data/md/protocol7-math-topology-reference.yaml`
- `data/asc/what-AI-thinks/holographic-cubic-topology-research-2026-01-13.md`

---

*Document created: 2026-03-02*
*Authors: taeki / claude*
*Status: Ready for review*

#,,..,...,,..,,,.,...,..,,,.,,,..,.,.,..,,...,.,.,...,...,,,.,,.,,,..,,,,,...,
#PJHKQDGLM34SLWAX3ND5TFEU3UIIU63GJ5WLO3ZOYAJ3DXE35VSEAYWZDD3WW6DNSO4EGAHAEKRF6
#\\\|WE7Z4QC3YJQKRTIFJQ36A7IVYOUXARE6CS4PDY3M4BFQB5UQAN5 \ / AMOS7 \ YOURUM ::
#\[7]67Y4AMADCWTQ6U5SJW6EHXYZ6NW6SX6K5NI3PDZMBJQKK4S57UAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
