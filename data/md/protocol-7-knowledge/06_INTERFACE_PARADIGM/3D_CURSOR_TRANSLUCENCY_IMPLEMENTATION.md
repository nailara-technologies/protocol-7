# 3D Terminal Cursor Translucency Implementation

## Overview

Configurable cursor translucency curves for the 8×7×13 voxel 3D terminal space. Based on study of nshell (cursor rendering), ticker (gaussian fade curves), and graphics-matrix (RGBA handling).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Cursor Translucency Pipeline                  │
├─────────────────────────────────────────────────────────────────┤
│  Time Input → Curve Function → Alpha Value → Voxel Attribute    │
│       ↓            ↓               ↓            ↓               │
│  1.3s cycle   gaussian/etc     0.0-1.0      bits 4-6            │
└─────────────────────────────────────────────────────────────────┘
```

## Cycle Timing

- **Period**: 1.3 seconds (13/10 = Protocol-7 harmonic)
- **Minimum alpha**: 0.13 (13% - never fully invisible in 3D space)
- **Maximum alpha**: 1.00 (fully opaque)

## Curve Profiles

| Profile | Description | Use Case |
|---------|-------------|----------|
| `sigmoid` | S-curve smooth transition | Default, professional look |
| `sine` | Natural sine wave | Harmonic, organic feel |
| `gaussian_pulse` | Bell curve peak | Brief attention pulse |
| `exponential` | Decay from peak | Radar/ping feedback |
| `quantized` | 13 discrete steps | Quantum/digital aesthetic |
| `heartbeat` | Double-pulse rhythm | Lub-dub medical style |

## Code Patterns from nshell Study

### 1. Cursor Rendering (nshell.render.cursor)
```perl
# nshell: underscore for empty, inverse video for filled
if ( $char_at_cursor eq '' or $char_at_cursor eq ' ' ) {
    print $colors{'p7_fg_0003'} . '_';
} else {
    print "\e[7m" . $char_at_cursor . "\e[27m";
}
```

**Applied in 3D**: Cursor shape changes by voxel content state:
- Empty voxel → underscore cursor
- Filled voxel → block cursor
- Insert mode → bar cursor

### 2. History Navigation (nshell.history.arrow_up)
```perl
# nshell: track position with bounds checking
$target_index = $search_index;
$state_ref->{'current_history_index'} = $target_index;
```

**Applied in 3D**: Z-depth navigation with wrap/clamp logic per axis.

### 3. Buffer Structure (nshell.init_code)
```perl
# nshell: 42K ring buffer for terminal history
<buffer.terminal-history.max_size> = 42 * 1024;
```

**Applied in 3D**: 728×2 byte voxel buffer + frame header = 1472 bytes.

## Code Patterns from ticker Study

### 1. Gaussian Fade Curve (ticker.calc_incr)
```perl
# ticker: gaussian for smooth fade-in
my $increase = (1.1 - <ticker.fade_opacity>)
               * 0.22 * <[base.calc_gauss]>->($t_inc);
```

**Applied in 3D**: `gaussian_pulse` curve profile for cursor visibility.

### 2. Time-based Animation (ticker.handler.fade_in)
```perl
# ticker: delta-t calculation for smooth animation
my $delta_t = sprintf('%.3f', <[base.time]>->(3) - <ticker.time.fade_view>);
```

**Applied in 3D**: Cycle-based translucency with phase calculation.

## Implementation Modules

| Module | Purpose |
|--------|---------|
| `graphics-3d.init_code` | Zenka initialization, grid config |
| `graphics-3d.cfg.cursor` | Curve profiles, colors, key mappings |
| `graphics-3d.calc.cursor-translucency` | Curve calculation functions |
| `graphics-3d.render.cursor` | Apply translucency to voxel buffer |
| `graphics-3d.handler.cursor_navigate` | 3D movement with wrap/clamp |

## Voxel Attribute Byte

```
Bit 7: Cursor bit (1 = cursor present)
Bit 6-4: Alpha value (0-7, scaled to 0.0-1.0)
Bit 3-0: Reserved (blink phase, shape)
```

## Z-Depth Color Mapping

13 layers → 13 blue shades (P7 color space):
- z=0 (deepest): `p7_bg_003` (blue-black)
- z=6 (middle): `p7_bg_063` (medium blue)
- z=12 (nearest): `p7_bg_233` (bright blue)

## Navigation Key Map

| Key | Direction | Delta |
|-----|-----------|-------|
| ↑/k | Y- | (0,-1,0) |
| ↓/j | Y+ | (0,1,0) |
| ←/h | X- | (-1,0,0) |
| →/l | X+ | (1,0,0) |
| PgUp/[ | Z- | (0,0,-1) |
| PgDown/] | Z+ | (0,0,1) |

## Integration Points

1. **decoder zenka**: Frame 57 (56+1) receives cursor position for pattern analysis
2. **data zenka**: SHM channel at `/data/terminals/graphics-3d/buffer`
3. **nshell**: Shared buffer I/O patterns, command integration
4. **ticker**: Borrowed fade curves, GTK3 rendering loop

## WSL Compatibility

Uses same GTK3/Cairo patterns as ticker zenka (tested on WSL).
No X11-specific code beyond GdkX11 introspection.

---

*Phase 1 implementation: 3D Buffer Infrastructure*
*Next: GTK3 display window at 60 FPS*

#,,..,,,,,...,...,..,,...,.,,,..,,..,,.,.,.,.,..,,...,...,.,.,,,.,.,,,..,,...,
#VCIV4N6TBMJVRN5UBCV3EUUPNSRIEUY27DDA3624TP62KBMH3ZE3JZTOMPXUAUCXKRFCWVHLPXJT6
#\\\|3YYUVOTO327ZT4BCYFOUN4X22RACX6SM5P47AI4FEJ27ZIX4H6Z \ / AMOS7 \ YOURUM ::
#\[7]W7QDZAZDCLVMNZZYVFCOHL2TF2QDWD2NYX6DBZXOHFO2TK2WNMBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
