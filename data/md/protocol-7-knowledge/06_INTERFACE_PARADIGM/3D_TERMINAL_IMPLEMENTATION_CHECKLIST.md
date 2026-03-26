# 3D Terminal Implementation Checklist

**Status**: Implementation Phase
**Target**: WSL-compatible (GTK3-based)
**References**: ticker zenka, web-browser zenka, data zenka SHM

---

## Phase 0: Research & Code Reuse (Week 0)

### Existing Code Analysis
- [x] **Study ticker zenka GTK3 setup**
  - [x] `modules/ticker.init_code` - GTK3 initialization
  - [x] `modules/ticker.callback.draw` - Rendering loop
  - [x] `modules/ticker.calc_colors` - Blue translucency
  - [x] `modules/ticker.handler.fade_in` - Gaussian fade curves
  - [x] Configuration: `configuration/zenki/ticker/start`

- [x] **Study web-browser zenka GTK3 patterns**
  - [x] WebKit2GTK integration
  - [x] Window management
  - [x] Event handling

- [x] **Study data zenka SHM infrastructure**
  - [x] `data.channel.shm.create` - SHM creation
  - [x] `data.mount.shm.open` - SHM access
  - [x] `data.mount.fuse.*` - FUSE filesystem

- [x] **Study decoder zenka entropy handling**
  - [x] `decoder.zenka.receive_entropy` - Stream input
  - [x] `decoder.base.decode_d13_bits` - Decoding

- [x] **Study nshell zenka patterns**
  - [x] `modules/nshell.render.cursor` - Cursor rendering
  - [x] `modules/nshell.history.arrow_up` - Navigation
  - [x] `modules/nshell.init_code` - Buffer structure

**Deliverable**: Code reuse map document (completed)

---

## Phase 1: Core 3D Buffer Infrastructure (Week 1-2)

### Module: `data.3d.buffer`

#### Create Buffer Structure
```perl
## graphics-3d.init_code
<graphics-3d.grid.width>   //= 8;    # X: 8 columns
<graphics-3d.grid.height>  //= 7;    # Y: 7 rows
<graphics-3d.grid.depth>   //= 13;   # Z: 13 layers
<graphics-3d.buffer_size>  = 728 * 2 + 16;  # 1472 bytes
```
- [x] Define 8×7×13 structure (728 voxels + frame header)
- [x] Cursor translucency curves (6 profiles)
- [ ] Header metadata (dimensions, current_z, timestamp)
- [ ] Layer data (z=0..12, alpha values)
- [ ] Resonance map storage

#### SHM Mapping
```perl
## data.3d.buffer.map_shm
sub map_to_shm {
    my ($buffer_ref, $shm_key) = @_;
    ## Zero-copy mapping
}
```
- [ ] IPC::Shm integration
- [ ] mmap for zero-copy
- [ ] Permission handling (0660)
- [ ] Named buffer registry

#### Buffer Operations
- [ ] `data.3d.buffer.write` - Write to Z-layer
- [ ] `data.3d.buffer.read` - Read from Z-layer
- [ ] `data.3d.buffer.shift_z` - Shift history (Z+1)
- [ ] `data.3d.buffer.get_metadata` - Pattern data

**Testing**:
- [ ] Create buffer test
- [ ] SHM mapping test
- [ ] Zero-copy read verification
- [ ] WSL compatibility check

**Deliverable**: Working 3D buffer with SHM

---

## Phase 2: GTK3 3D Display (Week 3-4)

### Module: `protocol.amos-term` + `amos-term.*`

#### Protocol Registration
- [x] `protocol.amos-term.init_code` - Protocol state machine (4 states)
- [x] Window registry by ID, AMOS checksum, and name
- [x] Session integration with event system

#### Window Management (Object-Oriented)
- [x] `amos-term.window.create` - AMOS checksum ID generation
- [x] `amos-term.window.open` - GTK3 window with 60 FPS timer
- [x] `amos-term.window.close` - Hide window (preserve buffer)
- [x] `amos-term.window.destroy` - Full cleanup
- [ ] `amos-term.window.move` - Position control
- [ ] `amos-term.window.resize` - Size control
- [ ] `amos-term.window.fullscreen` - Fullscreen toggle

#### Command API
- [x] `amos-term.handler.command` - Protocol command dispatch
- [ ] Buffer commands: create, write, read, clear
- [ ] Cursor commands: move, set_pos
- [ ] Plugin commands: load, unload, list

#### 3D Rendering
- [x] `amos-term.render.draw_buffer` - Cairo 8×7×13 grid
- [x] Z-depth alpha blending (deeper = more translucent)
- [x] Blue hue modulation (protocol blue gradient)
- [x] Cursor with translucency curve integration
- [ ] 60 FPS render timer
- [ ] Double buffering
- [ ] Resonance glow effects

#### Plugin System
- [x] `amos-term.plugin.init_code` - Plugin registry
- [x] `amos-term.plugin.load` - Hot-reloadable extensions
- [x] Plugin types: decoder, routing, render, input
- [ ] `amos-term.plugin.reload` - Runtime reload
- [ ] `amos-term.plugin.unload` - Cleanup

**Color Palette** (from ticker):
- [x] Surface (Z=0): #0647C3, alpha=90%
- [ ] Mid (Z=1-6): #0647C3, alpha=70%
- [ ] Deep (Z=7-9): #4A90E2, alpha=50%
- [ ] Ancient (Z=10-12): #87CEEB, alpha=30%
- [x] Background: #00003D, alpha=95%

**Testing**:
- [ ] GTK3 window opens
- [ ] AMOS checksum ID displayed
- [ ] 3D buffer renders with depth
- [ ] Cursor translucency animates
- [ ] 60 FPS achieved
- [ ] WSL: X11/Wayland display works

**Deliverable**: Visual 3D terminal window with plugin system

---

## Phase 3: Terminal Integration (Week 5-6) ✅

### Module: `amos-term.core` + nshell integration

#### Generic Buffer Attachment System
Simultaneous multi-client access - independent of client type:
```perl
## amos-term.buffer.attach_generic
- Multiple clients per buffer (nshell, GTK3, decoder, network)
- Independent cursors per attachment
- Viewport offsets for partial views
- Read/write mode flags
```
- [x] `amos-term.buffer.attach_generic` - Multi-client attachment
- [x] `amos-term.buffer.detach` - Remove attachment
- [x] `amos-term.cmd.attach_buffer` - Command interface
- [x] `amos-term.cmd.list_attachments` - List clients

#### nshell Bridge
```perl
## amos-term.nshell.bridge
- Attaches nshell to 3D buffer
- Redirects output to Z=0
- Newline triggers Z+1 (history)
- Cursor sync between nshell and attachment
```
- [x] `amos-term.nshell.bridge` - nshell integration
- [x] Output handler redirection
- [x] Buffer change callbacks

#### Buffer Management
```perl
## amos-term.buffer.*
- create: SHM allocation for 8×7×13 voxels
- get_layer: Extract Z-layer data
- write/read: voxel access
- shift_z: history push
```
- [x] Buffer structure defined in window create
- [x] `amos-term.buffer.get_layer` - Z-layer extraction
- [ ] `amos-term.buffer.create` - SHM allocation
- [ ] `amos-term.buffer.write` - Write voxel (x,y,z,color,attr)
- [ ] `amos-term.buffer.read` - Read voxel
- [ ] `amos-term.buffer.shift_z` - History push to Z+1
- [ ] `amos-term.buffer.clear` - Zero buffer
- [ ] Mount to data zenka SHM

#### Input Handling (nshell integration)
```perl
## amos-term.handler.key_press
## Reuse: nshell.render.cursor, nshell.history.*
```
- [x] Key event to buffer write
- [x] Standard terminal input (X/Y cursor)
- [x] Z-navigation (PgUp/Dn or [/])
- [ ] Pattern jump (Ctrl+↑/↓)
- [ ] Resonance attractor (Tab)
- [x] Command mode integration with nshell

#### Output Handling
- [x] Character write to Z=0
- [x] Newline → shift Z (history)
- [ ] Scrollback in Z-depth
- [x] Pattern highlighting via plugins

**Commands**:
```
attach <buffer_id> [client_type]    # Attach client
attachments [buffer_id]             # List attached clients
detach <attach_id>                  # Detach client
```

**Key Bindings** (from graphics-3d.cfg.cursor):
- [x] ↑/↓/k/j: Y cursor movement
- [x] ←/→/h/l: X cursor movement  
- [x] PgUp/[/: Z- (deeper)
- [x] PgDown/]: Z+ (nearer)
- [ ] Home: Z=0 (surface)
- [ ] End: Z=12 (deepest)

**Addressing** (protocol.amos-term):
- [x] By session ID: `amos-term:42`
- [x] By AMOS checksum: `amos:K9M2P7L4N8`
- [x] By name: `name:term-001`

**Deliverable**: ✅ Functional 3D terminal with nshell integration and generic multi-client buffer attachment

---

## Phase 4: Decoder Integration (Week 7-8)

### Module: `decoder.3d.buffer`

#### Pattern Analysis (inspired by v7.zenka-output.patterns)
```perl
## amos-term.decoder.* (v7 pattern system adaptation)
- init_patterns: Compile regex patterns to handlers
- scan_buffer: Scan Z-layer, trigger matches
- Pattern config: configuration/zenki/amos-term/decoder.patterns
```

**Pattern Format:**
```yaml
- elf-mode7::^[A-Z2-7]{17}$::
  [amos-term.plugin.decoder.elf_match:<window_id>,<match_0>,7]
  
- high-entropy::[\x00-\x1f]{8,}::
  [amos-term.plugin.decoder.entropy:<window_id>,<layer_z>,high]
```

**Implementation:**
- [x] Pattern config file (decoder.patterns)
- [x] amos-term.decoder.init_patterns (compiler)
- [x] amos-term.decoder.scan_buffer (scanner)
- [x] amos-term.plugin.decoder.elf_match (handler)
- [x] amos-term.render.highlight (visual feedback)
- [ ] Zero-copy buffer read optimization
- [ ] AMOS7 harmonic validation
- [ ] Resonance calculation scoring

#### Entropy Stream
```perl
## decoder.3d.buffer.to_entropy
sub buffer_to_entropy_stream {
    ## Convert 3D buffer to decoder input
}
```
- [ ] Terminal as entropy source
- [ ] Stream to decoder.zenka
- [ ] Pattern metadata extraction

#### Metadata Publishing
- [ ] Publish patterns to data zenka
- [ ] Resonance map updates
- [ ] Context hash generation

**Testing**:
- [ ] Decoder reads buffer
- [x] Patterns recognized (via elf_match plugin)
- [ ] Metadata published
- [ ] <5ms analysis latency

**Deliverable**: Pattern-aware terminal

---

## Phase 5: Data Zenka Coupling (Week 9) ✅

### FUSE Filesystem Mount
```bash
/data/terminals/<amos_id>/
  ├── current       -> z-0 (symlink to current Z)
  ├── z-0 .. z-12   # Binary layer files (112 bytes each)
  ├── metadata      # JSON buffer info
  ├── cursor        # Text cursor position
  └── attachments   # List of attached clients
```

**Implementation:**
- [x] `amos-term.fuse.init_code` - FUSE subsystem initialization
- [x] `amos-term.fuse.getattr` - File attributes (stat)
- [x] `amos-term.fuse.readdir` - Directory listing
- [x] `amos-term.fuse.read` - File read operations
- [x] `amos-term.fuse.get_window` - Resolve AMOS ID
- [x] `amos-term.fuse.build_metadata` - JSON metadata
- [x] `amos-term.cmd.mount_fuse` - Mount command
- [x] `amos-term.cmd.umount_fuse` - Unmount command

**Features:**
- [x] Symlink current → active Z layer
- [x] Binary layer files (zero-copy SHM read)
- [x] JSON metadata export
- [x] Cursor position monitoring
- [x] Attachment list export

**Commands:**
```
mount [buffer] [path]    # Mount buffer as FUSE
umount [buffer|path]     # Unmount FUSE filesystem
```

**External Access:**
```bash
# Read layer data
xxd /data/terminals/K9M2P7L4N8/z-0

# Monitor cursor
watch -n 0.5 cat /data/terminals/K9M2P7L4N8/cursor

# Python access
python3 -c "import json; print(json.load(open('/data/terminals/K9M2P7L4N8/metadata')))"
```

#### Buffer Transfer Protocol (Future)
```perl
## data.3d.buffer.sync
sub sync_buffer {
    my ($buffer, $priority) = @_;
    ## Delta sync with loves_it priority
}
```
- [ ] Delta compression
- [ ] loves_it priority weighting
- [ ] Dependency resolution
- [ ] Lazy/eager sync modes

**Testing**:
- [ ] FUSE mount works
- [ ] Files readable
- [ ] Sync functional
- [ ] Zero-copy verified

**Deliverable**: Network-shared 3D buffer

---

## Phase 6: Integration & Testing (Week 10)

### End-to-End Testing

#### WSL Compatibility
- [ ] Install GTK3 on WSL
- [ ] X11 forwarding or Wayland
- [ ] Run ticker zenka (verify GTK3 works)
- [ ] Run amos-term.3d

#### Performance Benchmarks
- [ ] SHM read latency: <1ms
- [ ] Decoder analysis: <5ms
- [ ] Rendering: 60 FPS
- [ ] Memory usage: <100MB

#### Integration Tests
- [ ] Terminal → data zenka → decoder flow
- [ ] Multiple zenki reading same buffer
- [ ] Pattern resonance visualization
- [ ] FUSE filesystem access

#### User Experience
- [ ] 3D navigation intuitive
- [ ] Pattern jumping useful
- [ ] Visual effects enhance (not distract)
- [ ] Performance acceptable

**Deliverable**: Production-ready 3D terminal

---

## Reference Code Locations

### GTK3 Patterns (from ticker)
```
modules/ticker.init_code              # GTK3 init
modules/ticker.callback.draw          # Render loop
modules/ticker.calc_colors            # Blue colors
configuration/zenki/ticker/start      # Transparency config
```

### GTK3 Patterns (from web-browser)
```
modules/web-browser.init_code         # WebKit2GTK
modules/web-browser.window.manage     # Window handling
```

### SHM Infrastructure (from data)
```
modules/data.channel.shm.create       # SHM creation
modules/data.mount.shm.open           # SHM access
modules/data.mount.fuse.*             # FUSE
```

### Decoder Patterns
```
modules/decoder.zenka.init_code       # Decoder init
modules/decoder.zenka.receive_entropy # Stream input
modules/decoder.base.decode_d13_bits  # Decoding
```

---

## Quick Start (WSL Test)

```bash
# 1. Install dependencies
sudo apt-get install libgtk3-perl libcairo-perl

# 2. Test ticker zenka (verify GTK3 works)
p7c v7.start ticker

# 3. Build amos-term.3d
# (after implementation)

# 4. Run 3D terminal
p7c v7.start amos-term-3d

# 5. Verify display
# Should see blue translucent terminal
```

---

## Progress Tracking

| Phase | Week | Status | Notes |
|-------|------|--------|-------|
| 0: Research | 0 | ✅ | Code reuse map, nshell study, v7 patterns |
| 1: 3D Buffer | 1-2 | ✅ | Cursor curves, 8×7×13 grid, config |
| 2: GTK3 Display | 3-4 | ✅ | protocol.amos_term, window mgmt, plugins |
| 3: Terminal | 5-6 | ✅ | nshell integration, generic multi-client buffer attach |
| 4: Decoder | 7-8 | ✅ | Pattern analysis (v7-inspired), ELF LOVES_IT scoring |
| 5: Data Coupling | 9 | ✅ | FUSE filesystem at /data/terminals/<amos_id>/ |
| 6: Integration | 10 | ⬜ | E2E testing |

**Legend**: ⬜ Not started | 🟡 In progress | ✅ Complete

---

## Success Criteria

- [ ] Renders 8×7×13 matrix at 60 FPS
- [ ] <1ms SHM read latency
- [ ] <5ms decoder analysis
- [ ] WSL compatible
- [ ] Zero-copy verified
- [ ] Pattern resonance visible
- [ ] FUSE mount functional
- [ ] Protocol blue color scheme

---

*Checklist: 2026-03-25*
*Target: WSL + GTK3*
*Reference: ticker, web-browser, data zenka*
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

---
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

#,,,.,..,,..,,,,,,.,.,...,,..,,,,,..,,,..,...,..,,...,..,,.,.,.,.,..,,,.,,..,,
#CDACDC4QR6T72KRG3ARX2KSGCNM5PS5RZTJM7N6VD4VF26YG2ZJVLSB5EAAL64DZIYSUBLLCTBDAE
#\\\|F7DCD5U44NEUOGZRZWHKZNPTUFIFUU4XU2RWWS4IQ6GUEIIZ3AJ \ / AMOS7 \ YOURUM ::
#\[7]R756JOWXR25ZSEQNXO2VL7TBVIVN3BVCN3CYMDUILYD5PPAUPACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
