# protocol.amos-term Implementation Summary

## Overview

First-class 3D terminal window management for Protocol-7 using AMOS checksum IDs and event-driven architecture.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    protocol.amos-term                            │
├─────────────────────────────────────────────────────────────────┤
│  Protocol States:                                                │
│  • 0: Created (awaiting buffer)                                  │
│  • 1: Active (with buffer, rendering)                            │
│  • 2: Hidden (buffer updates, no render)                         │
│  • 3: Fullscreen                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Window Mgmt  │    │    Buffer     │    │    Plugin     │
│               │    │               │    │               │
│ • create      │    │ • create      │    │ • load        │
│ • open        │    │ • write       │    │ • unload      │
│ • close       │    │ • read        │    │ • reload      │
│ • destroy     │    │ • shift_z     │    │ • decoder     │
│ • move        │    │ • clear       │    │ • routing     │
│ • fullscreen  │    │               │    │ • render      │
└───────────────┘    └───────────────┘    └───────────────┘
```

## Module Inventory

### Protocol (1)
| Module | Purpose |
|--------|---------|
| `protocol.amos-term.init_code` | Protocol registration, 4-state machine |

### Window Management (5)
| Module | Purpose |
|--------|---------|
| `amos-term.window.create` | AMOS checksum ID generation, window struct |
| `amos-term.window.open` | GTK3 window with 60 FPS render timer |
| `amos-term.window.close` | Hide window, preserve buffer |
| `amos-term.window.destroy` | Full cleanup, SHM release |
| `amos-term.session.set_state` | Session state transitions |

### Handlers (3)
| Module | Purpose |
|--------|---------|
| `amos-term.handler.command` | Protocol command dispatch (OO-style) |
| `amos-term.handler.key_press` | GTK3 key → 3D navigation |
| `amos-term.render.draw_buffer` | Cairo 8×7×13 grid render |

### Plugin System (2)
| Module | Purpose |
|--------|---------|
| `amos-term.plugin.init_code` | Plugin registry, type definitions |
| `amos-term.plugin.load` | Hot-reloadable extension loader |

### Pattern Matching / Decoder (5)
| Module | Purpose |
|--------|---------|
| `cfg/zenki/amos-term/decoder.patterns` | Pattern definitions (YAML) |
| `amos-term.decoder.init_patterns` | Compile patterns to regex handlers |
| `amos-term.decoder.scan_buffer` | Scan layer, trigger pattern matches |
| `amos-term.buffer.get_layer` | Extract Z-layer data from SHM |
| `amos-term.plugin.decoder.elf_match` | ELF checksum decoder plugin |

### Visual Effects (1)
| Module | Purpose |
|--------|---------|
| `amos-term.render.highlight` | Visual feedback for decoder events |

### Total: 18 modules + 1 config file

## Window Identity System

### AMOS Checksum Generation
```perl
$seed = "$client_name:$timestamp:$zenka_name:$$"
$bmw_hash = chk-sum.bmw.filesum(256, $seed)
$amos_id  = uc(substr($bmw_hash, 0, 10))  # 42-bit ID
```

### Addressing Modes
```perl
# By session ID
<[amos-term.window.open]>->(42)

# By AMOS checksum  
<[amos-term.window.open]>->('amos:K9M2P7L4N8')

# By client name
<[amos-term.window.open]>->('name:term-001')
```

## Command API

### Window Lifecycle
```
window create client_name=myterm geometry=800x600
window open
window move 100 100
window fullscreen on
window close
window destroy
```

### Buffer Operations
```
buffer create
buffer write 0 0 0 "A" 3
buffer clear
cursor move 1 0 0
cursor set 5 3 7
```

### Plugin Management
```
plugin load decoder.pattern-match
plugin unload decoder.pattern-match
plugin list
```

### Pattern Matching (Decoder Integration)
Inspired by `v7.init_zenka_output_patterns` and `zenka-output.patterns`:

**Pattern Format:**
```
<pattern_name>::<regex>::[flags]
  [action_command:<window_id>,<match_1>,...]
```

**Example Patterns:**
```yaml
- elf-mode7::^[A-Z2-7]{17}$::
  [amos-term.plugin.decoder.elf_match:<window_id>,<match_0>,7]
  
- high-entropy::[\x00-\x1f]{8,}::
  [amos-term.plugin.decoder.entropy:<window_id>,<layer_z>,high]
  
- amos7-banner::^\\7\\\\AMOS7\\\\[A-Z2-7]+\\\\::$::
  [amos-term.handler.decode.protocol:<window_id>,<match_0>,amos7]
```

**Scanning:**
```perl
# Scan Z-layer 0 for patterns
<[amos-term.decoder.scan_buffer]>->($window_id, 0);
```

### Info
```
info
→ amos-id: K9M2P7L4N8
→ name: myterm
→ state: 1
→ visible: yes
```

## Key Bindings (from graphics-3d.cfg.cursor)

| Key | Action |
|-----|--------|
| ↑/k | Y- (up) |
| ↓/j | Y+ (down) |
| ←/h | X- (left) |
| →/l | X+ (right) |
| PgUp/[ | Z- (deeper) |
| PgDown/] | Z+ (nearer) |
| F11/Ctrl+f | Fullscreen toggle |
| Escape | Close window |

## Plugin Types

| Type | Hook | Purpose |
|------|------|---------|
| decoder | buffer.decode | Pattern recognition |
| routing | event.route | Event distribution |
| render | render.frame | Custom graphics |
| input | input.key | Key handling extensions |

## Render Pipeline

```
Cairo Context
    ↓
Background (#000006 with alpha)
    ↓
For Z in 0..12 (deepest first):
    Calculate depth_alpha (1.0 → 0.3)
    Calculate blue_shift (0.76 → 1.0)
    Draw 8×7 grid with parallax offset
    ↓
Cursor at (cx,cy,cz):
    Calculate translucency from curve
    Draw #4427AC block
    ↓
GTK3 Window
```

## Integration Points

| System | Integration |
|--------|-------------|
| Session | `base.session.init` with pipe handles |
| Events | Glib::Timeout for 60 FPS, Event.pm for I/O |
| SHM | `/dev/shm/amos-term/<amos_id>/buffer` |
| Decoder | Plugin hook `decoder.pattern-match` |
| nshell | Key handler reuses navigation patterns |
| graphics-3d | Cursor translucency curves |

## WSL Compatibility

- GTK3 initialization same as ticker zenka
- No X11-specific code (uses GdkX11 introspection)
- Pipe-based session handles (no network sockets)

## Next Steps

1. **Buffer I/O**: `amos-term.buffer.*` modules for SHM
2. **nshell Integration**: Command bridge to existing terminal
3. **Decoder Plugins**: Pattern recognition extensions
4. **FUSE Mount**: `/data/terminals/amos-term/<amos_id>/`

## File Count

- Protocol: 1 module
- Window: 5 modules  
- Handlers: 3 modules
- Plugins: 2 modules
- Documentation: 3 files
- **Total new files: 14**

---

*Phase 2 implementation: GTK3 3D Display*
*Architecture: Object-oriented, event-driven, hot-reloadable*
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

#,,,.,,.,,.,,,.,,,,,,,,..,,..,,,,,,.,,.,.,...,..,,...,...,...,,,.,.,,,,,,,.,.,
#5YMWGRJKZSUCDCWEZDMXLXCFTZSR5JOLAF2YEC6QQB3AVJUYR6YZBDEKOYO3JBLBNUG6CODV7ZXG6
#\\\|JRPFIPLIGQCJRZ3X45COLDD6YVBGHHJR2CC4UO7MIKOX6UTOBAZ \ / AMOS7 \ YOURUM ::
#\[7]FTVLBKTXOYZBKZRVWEUNOH6B2MN4ZMZGTFFGVBY2LN7UVMOAU2CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
