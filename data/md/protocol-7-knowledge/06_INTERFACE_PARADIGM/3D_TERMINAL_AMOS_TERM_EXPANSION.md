# 3D Terminal Expansion: amos-term + GTK3 + data zenka coupling

**Status**: Design Phase → Implementation Planning  
**Dependencies**: amos-term, ticker (GTK3 rendering), data zenka, graphics-matrix  
**Inspiration**: ticker zenka (transparency, animation, GTK3)

---

## Vision

Transform `amos-term` from a 2D terminal into a **3D holographic workspace**:

```
2D Terminal (current):          3D Terminal (future):
┌─────────────┐                ╭──────────────────────╮
│  $ prompt   │               /  Z=0: Surface        /
│  text output│              /   [current terminal]  /
│  scrollback │             /───────────────────────/
└─────────────┘            /  Z=1: Recent history  /
                          /   [prior commands]     /
                         /───────────────────────/
                        /  Z=2-12: Deep buffer   /
                       /   [accumulated data]    /
                      ╰───────────────────────╯
                          ↑
                    Blue translucency
                    (GTK3 rendering)
```

**Key Innovation**: The terminal IS a 3D shift register—command history accumulates in Z-depth as a **visualizable, navigable data space**.

---

## Architecture

### Core Modules

```
amos-term.3d.init_code              ## GTK3 setup (inspired by ticker)
amos-term.3d.buffer.manager         ## 8×7×13 matrix management
amos-term.3d.render.gtk3            ## Blue translucency rendering
amos-term.3d.navigation             ## Z-depth keyboard controls
amos-term.3d.sync.data_zenka        ## Buffer transfer protocol
amos-term.3d.visual.matcher         ## Pattern resonance/harmonic matching
```

### Buffer Structure (8×7×13)

| Dimension | Size | Meaning |
|-----------|------|---------|
| X | 8 | Character width (byte) |
| Y | 7 | Terminal rows (temporal phases) |
| Z | 13 | History depth (accumulation) |

**Total**: 8×7×13 = 728 voxels per terminal state

---

## GTK3 Rendering (from ticker)

### Transparency & Colors (ticker-inspired)

```perl
## From ticker configuration:
ticker.cfg.fg_col   = '00003D'  # Protocol blue
ticker.bg_col       = '000047'  # Darker blue
ticker.cfg.alpha.bg = 93        # 93% transparent background
ticker.cfg.alpha.fg = 94        # 94% transparent foreground

## 3D terminal adaptation:
amos-term.3d.cfg.fg_col      = '0647C3'  # Protocol blue (active)
amos-term.3d.cfg.bg_col      = '00003D'  # Dark background
amos-term.3d.cfg.alpha.z0    = 90        # Surface: slightly opaque
amos-term.3d.cfg.alpha.z1_6  = 70        # Mid-depth: transparent
amos-term.3d.cfg.alpha.z7_12 = 50        # Deep: very transparent

## Translucency creates "depth perception"
## Deeper Z = more transparent = visually further away
```

### Rendering Pipeline

```perl
## amos-term.3d.render.gtk3
sub render_3d_buffer {
    my ($buffer, $current_z) = @_;
    
    for my $z (0..12) {
        my $alpha = calculate_alpha($z, $current_z);  # Fade with depth
        my $blue_modulation = calculate_blue_hue($z); # Hue shifts with depth
        
        for my $y (0..6) {
            for my $x (0..7) {
                my $char = $buffer->[$z][$y][$x];
                render_voxel($x, $y, $z, $char, $alpha, $blue_modulation);
            }
        }
    }
}
```

---

## Visual Pattern Matching (Magnetic Resonance)

### Harmonic Pattern Accumulation

```perl
## amos-term.3d.visual.matcher

## Patterns "attract" each other through harmonic resonance:
## Similar 56-bit pages gravitate toward each other in Z-space

sub calculate_pattern_resonance {
    my ($page_a, $page_b) = @_;
    
    ## ELF checksum comparison (harmonic distance)
    my $elf_a = <[chk-sum.elf]>->($page_a);
    my $elf_b = <[chk-sum.elf]>->($page_b);
    my $harmonic_distance = abs($elf_a - $elf_b);
    
    ## AMOS7 harmonic validation
    my $amos_a = <[chk-sum.amos]>->($page_a);
    my $amos_b = <[chk-sum.amos]>->($page_b);
    my $is_true = <[chk-sum.elf.get-true]>->($amos_a & $amos_b);
    
    ## Resonance: closer ELF + true AMOS = stronger attraction
    my $resonance = $is_true ? (1 / ($harmonic_distance + 1)) : 0;
    
    return $resonance;
}

## Visual effect: Similar patterns "glow" toward each other
## Creates magnetic field lines in 3D space
```

### Time-Bending Pattern Attraction

```perl
## Patterns with high resonance "bend time":
## - They persist longer in Z-depth (slower fade)
## - They influence adjacent Z-layers (field effect)
## - They create "attractor basins" in the 3D space

sub apply_temporal_bending {
    my ($buffer, $resonance_map) = @_;
    
    for my $z (0..12) {
        for my $y (0..6) {
            for my $x (0..7) {
                my $resonance = $resonance_map->[$z][$y][$x];
                
                ## High resonance = slower decay in Z
                my $persistence = 1 + ($resonance * 5);  # Up to 6x longer
                $buffer->[$z][$y][$x]{'persistence'} = $persistence;
                
                ## Visual: glow intensity based on resonance
                $buffer->[$z][$y][$x]{'glow'} = $resonance * 255;
            }
        }
    }
}
```

---

## Buffer Transfer Protocol (data zenka coupling)

### Efficient Synchronization

```perl
## amos-term.3d.sync.data_zenka

## Couple terminal buffers with data zenka's holographic topology

sub sync_to_data_zenka {
    my ($terminal_buffer, $priority_context) = @_;
    
    ## Priority-based transfer (loves_it scoring)
    my $loves_score = calculate_loves_it($priority_context);
    my $sync_priority = $loves_score / 13;  # 0-1 scale
    
    ## Context-based delta sync (only changed voxels)
    my $delta = calculate_3d_delta($terminal_buffer, $last_synced);
    
    ## Transfer via data zenka's SHM/FUSE channels
    my $result = <[data.channel.shm.write]>->({
        'path'     => 'terminals/amos-3d/' . <system.zenka.name>,
        'data'     => compress_3d_delta($delta),
        'priority' => $sync_priority,
        'context'  => $priority_context,
    });
    
    return $result;
}

## Dependency resolution:
## - High loves_it = synchronous transfer (immediate)
## - Medium loves_it = batched transfer (queued)
## - Low loves_it = lazy transfer (background)
```

### Context-Based Routing

```perl
## Buffers are routed based on their harmonic context:
## - Similar contexts cluster in same data zenka quadrant
## - High-resonance patterns form "constellations"
## - Terminal history becomes navigable 3D topology

sub route_by_context {
    my ($buffer_segment, $context_hash) = @_;
    
    ## Calculate 13³ cubic coordinate from context
    my $cube_coord = context_to_cubic($context_hash);
    
    ## Route to appropriate data zenka shard
    my $shard = <[data.topology.shard_for_coord]>->($cube_coord);
    
    return $shard;
}
```

---

## Keyboard Navigation (Z-Depth)

### Standard Terminal (2D)
```
↑/↓     : Command history (Y-axis)
←/→     : Cursor (X-axis)
Ctrl+C  : Copy
Ctrl+V  : Paste
```

### 3D Terminal (Expanded)
```
↑/↓     : Command history (Y-axis, same)
←/→     : Cursor (X-axis, same)
PgUp/Dn : Z-depth navigation (history layers!)
Home    : Jump to Z=0 (surface/current)
End     : Jump to deepest Z with content
Ctrl+↑  : Navigate to similar pattern above
Ctrl+↓  : Navigate to similar pattern below
Tab     : Cycle through resonance attractors
Space   : "Zoom" into selected Z-layer
Esc     : Return to surface (Z=0)
F1-F7   : Jump to specific Z-layer (0-6)
F8-F13  : Jump to deep layers (7-12)
```

---

## protocol-7-menu Integration

### Launch 3D Terminals

```perl
## protocol-7-menu action key configuration

## Add to menu:
## [F2] Launch 3D Terminal
##   ↓
## Spawns amos-term.3d with:
##   - GTK3 window
##   - 8×7×13 buffer initialized
##   - Connected to data zenka
##   - Context from current application

sub launch_3d_terminal {
    my $context = capture_current_context();
    
    my $term_3d = <[amos-term.3d.spawn]>->({
        'context'    => $context,
        'sync_data'  => TRUE,
        'visualize'  => TRUE,
        'dimensions' => [8, 7, 13],
    });
    
    return $term_3d;
}
```

---

## Implementation Phases

### Phase 1: GTK3 Foundation (Week 1)
- [ ] Copy ticker GTK3 setup to amos-term.3d
- [ ] Implement 8×7×13 buffer structure
- [ ] Basic transparency rendering

### Phase 2: 3D Navigation (Week 2)
- [ ] Z-depth keyboard controls
- [ ] Visual depth perception (alpha blending)
- [ ] Jump to pattern/resonance navigation

### Phase 3: Pattern Matching (Week 3)
- [ ] ELF/AMOS checksum comparison
- [ ] Magnetic resonance visualization
- [ ] Time-bending persistence

### Phase 4: data zenka Coupling (Week 4)
- [ ] SHM buffer transfer protocol
- [ ] Priority-based sync (loves_it)
- [ ] Context-based routing

### Phase 5: protocol-7-menu (Week 5)
- [ ] Menu integration
- [ ] Launch actions
- [ ] Context capture

---

## Visual Design (Blue Translucency)

### Color Palette (Protocol Blue)

| Element | Color | Alpha | Notes |
|---------|-------|-------|-------|
| Active text (Z=0) | #0647C3 | 90% | Protocol blue, nearly opaque |
| Recent (Z=1-3) | #0647C3 | 70% | Fading into depth |
| Mid-depth (Z=4-6) | #0647C3 | 50% | Blue with transparency |
| Deep (Z=7-9) | #4A90E2 | 40% | Lighter blue, ghostly |
| Ancient (Z=10-12) | #87CEEB | 30% | Sky blue, very faint |
| Resonance glow | #00FFFF | Variable | Cyan highlight for patterns |
| Background | #00003D | 95% | Dark blue, almost black |

### Resonance Visualization

```
High-resonance pattern:     Low-resonance pattern:
┌──────────┐                ┌──────────┐
│ ~~~~~~   │  Glow          │ ....     │  Dim
│ ~[##]~   │  Cyan aura     │ .[##].   │  No aura
│ ~~~~~~   │  Persists      │ ....     │  Fades fast
└──────────┘                └──────────┘
```

---

## Success Criteria

- [ ] 60 FPS rendering of 8×7×13 matrix
- [ ] <50ms latency for Z-depth navigation
- [ ] Pattern resonance visually detectable
- [ ] <100ms sync latency to data zenka
- [ ] Can launch from protocol-7-menu
- [ ] Blue translucency achieves "holographic" feel

---

*Design: 2026-03-25*  
*Inspiration: ticker zenka (GTK3, transparency, animation)*  
*Integration: amos-term, data zenka, protocol-7-menu*  
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

---
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

#,,..,...,.,,,,..,,..,,,,,..,,.,.,,..,,.,,.,,,..,,...,...,.,,,.,,,..,,.,,,,.,,
#CTSPWYCZUQWT3QVFF4YYTLEEQRMOTOL6BKKTJLXSUPDCO3ITPCFY2P5GIONVO76QEMM5HQURUZOI6
#\\\|3UOKHAHXUIBXB4IUVQQQBJX6TEKEN4PSI5SKXO57UJ24KRDJIU2 \ / AMOS7 \ YOURUM ::
#\[7]H535GRNTYCS4WM5RJY336EJDBCB67I5DITN7T3COEGQE5XFYCMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
