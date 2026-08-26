# 3D Buffer Integration: data zenka + decoder zenka + Zero-Copy Architecture

**Status**: Design Integration  
**Components**: data zenka (SHM/FUSE), decoder zenka (entropy/patterns), amos-term.3d  
**Key Feature**: Zero-copy terminal content sharing across network

---

## Vision

```
┌─────────────────────────────────────────────────────────────────────┐
│                    3D BUFFER ECOSYSTEM                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   AMOS-TERM.3D          DATA ZENKA           OTHER ZENKI            │
│   ╭──────────────╮     ╭──────────────╮     ╭──────────────╮       │
│   │ 8×7×13 buffer│────▶│ Named SHM    │────▶│ decoder      │       │
│   │ Z-depth      │     │ /terminals/  │     │ (patterns)   │       │
│   │ history      │     │ /amos-term/  │     │              │       │
│   ╰──────────────╯     ╰──────────────╯     ╰──────────────╯       │
│          │                    │                    │               │
│          │                    ▼                    │               │
│          │             ╭──────────────╮            │               │
│          │             │ FUSE mount   │            │               │
│          │             │ /data/term/  │            │               │
│          │             ╰──────────────╯            │               │
│          │                    │                    │               │
│          └────────────────────┴────────────────────┘               │
│                         ZERO-COPY                                 │
│                    (all read same SHM)                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Named 3D Buffers in data zenka

### Buffer Naming Convention

```
/data/terminals/<zenka-name>/<buffer-id>

Examples:
/data/terminals/amos-term/main          # Primary terminal
/data/terminals/amos-term/aux1          # Auxiliary terminal
/data/terminals/kimi-console/session-7  # Kimi console
```

### Buffer Structure (8×7×13)

```perl
## data.3d.buffer.create

my $buffer_3d = <[data.3d.buffer.create]>->({
    'name'        => 'amos-term.main',
    'dimensions'  => [8, 7, 13],      # X, Y, Z
    'type'        => 'terminal',       # Content type
    'permissions' => 'zenka.read',     # Access control
});

## Structure:
## {
##   'header' => {
##     'dimensions' => [8, 7, 13],
##     'current_z'  => 0,              # Surface layer
##     'write_pos'  => [0, 0],         # X, Y cursor
##     'timestamp'  => <epoch>,
##     'checksum'   => <BMW>,
##   },
##   'layers' => [
##     { 'z' => 0,  'data' => [...], 'alpha' => 90 },  # Surface
##     { 'z' => 1,  'data' => [...], 'alpha' => 70 },
##     ...
##     { 'z' => 12, 'data' => [...], 'alpha' => 30 },  # Deep
##   ],
##   'metadata' => {
##     'resonance_map' => {...},       # Pattern harmonics
##     'context_hash'  => <AMOS7>,
##   },
## }
```

### SHM Mapping (Zero-Copy)

```perl
## data.3d.buffer.map_shm
## Maps 3D buffer to shared memory for zero-copy access

my $shm_path = <[data.3d.buffer.map_shm]>->({
    'buffer_name' => 'amos-term.main',
    'shm_key'     => 'term_amos_main_3d',
    'permissions' => 0660,
});

## Result: /dev/shm/term_amos_main_3d
## Other zenki can mmap() this directly
```

---

## Decoder Zenka Integration

### Pattern Recognition in Terminal Streams

```perl
## decoder.3d.buffer.analyze
## Analyzes 3D terminal buffer for patterns

my $patterns = <[decoder.3d.buffer.analyze]>->({
    'buffer_path' => '/data/terminals/amos-term/main',
    'analysis_type' => 'harmonic_resonance',
    'depth_range'   => [0, 6],         # Surface to mid
});

## Returns:
## {
##   'resonance_clusters' => [
##     { 'center' => [x, y, z], 'strength' => 0.87, 'pattern' => 'command_sequence' },
##     { 'center' => [x, y, z], 'strength' => 0.92, 'pattern' => 'error_recovery' },
##   ],
##   'entropy_distribution' => [...],
##   'harmonic_matches'     => [...],
## }
```

### Decoder Entropy Collection

```perl
## From existing: decoder.zenka.receive_entropy
## Extended for 3D buffers

## Terminal content becomes entropy stream for decoder
sub stream_terminal_entropy {
    my ($terminal_buffer, $decoder_channel) = @_;
    
    ## Convert 3D buffer to entropy stream
    my $entropy_stream = buffer_to_entropy($terminal_buffer);
    
    ## Feed to decoder
    <[decoder.zenka.receive_entropy]>->({
        'stream'   => $entropy_stream,
        'source'   => 'terminal',
        'metadata' => { 'buffer' => $terminal_buffer->{'name'} },
    });
}
```

### Existing Decoder Modules Reused

| Decoder Module | 3D Buffer Application |
|----------------|----------------------|
| `decoder.base.decode_d13_bits` | Decode Z-depth layers |
| `decoder.cmd.reduce-entropy` | Compress terminal history |
| `decoder.cmd.harmony` | Find harmonic patterns |
| `decoder.zenka.init_code` | Initialize 3D stream handling |
| `decoder.handler.on-boundary` | Z-layer boundary detection |

---

## Zero-Copy Read Architecture

### Terminal Content Access Patterns

```
1. DISPLAY (amos-term.3d)
   └── mmap(SHM) → render to GTK3 window

2. ROUTING (data zenka)
   └── FUSE mount /data/term/ → route to other zenki

3. DECODING (decoder zenka)
   └── SHM read → pattern analysis → entropy reduction

4. REMOTE (other zenki)
   └── SHM read → local processing → zero copy!
```

### Permission Model

```perl
## data.3d.buffer.permissions

my $acl = {
    'amos-term'       => ['read', 'write'],  # Owner
    'decoder'         => ['read'],           # Pattern analysis
    'graphics-matrix' => ['read'],           # Visual matching
    'lm-vision'       => ['read'],           # Content OCR
    'kimi'            => ['read'],           # Context awareness
};

## Zero-copy only for read permissions
## Write requires copy-on-write
```

---

## Integration Flow

### Terminal Mounts Buffer

```perl
## amos-term.3d → data zenka

sub mount_3d_buffer {
    my $buffer = initialize_8x7x13();
    
    ## Create named buffer in data zenka
    my $buffer_ref = <[data.3d.buffer.create]>->({
        'name'   => 'amos-term.main',
        'buffer' => $buffer,
    });
    
    ## Map to SHM for zero-copy
    my $shm = <[data.3d.buffer.map_shm]>->({
        'buffer_ref' => $buffer_ref,
    });
    
    ## Register with decoder for pattern analysis
    <[decoder.3d.buffer.register]>->({
        'buffer_name' => 'amos-term.main',
        'shm_path'    => $shm,
    });
    
    return $buffer_ref;
}
```

### Decoder Analyzes Patterns

```perl
## decoder zenka → pattern recognition

sub analyze_terminal_patterns {
    my ($buffer_name) = @_;
    
    ## Zero-copy read from SHM
    my $buffer = <[data.3d.buffer.read_shm]>->($buffer_name);
    
    ## Run pattern analysis
    my $patterns = <[decoder.3d.buffer.analyze]>->({
        'buffer' => $buffer,
        'modes'  => [4, 7, 13],  ## Truth modes
    });
    
    ## Publish patterns back to data zenka
    <[data.3d.buffer.metadata.update]>->({
        'buffer_name' => $buffer_name,
        'metadata'    => { 'patterns' => $patterns },
    });
}
```

### Other Zenki Consume

```perl
## Any zenki → zero-copy read

sub read_terminal_content {
    my ($buffer_name) = @_;
    
    ## Direct SHM mmap - no copy!
    my $shm_handle = <[data.mount.shm.open]>->(
        "/data/terminals/$buffer_name"
    );
    
    ## Read 3D structure directly
    my $content = $shm_handle->read_3d();
    
    return $content;
}
```

---

## FUSE Mount Integration

### Terminal as Filesystem

```bash
## Mount terminal buffers as filesystem
$ mount -t fuse data-term-fuse /data/term

$ ls /data/term/
amos-term/
  main/
    current      # Z=0 (symlink to layer-0)
    history/
      z-1        # Z=1
      z-2        # Z=2
      ...
      z-12       # Z=12 (deep history)
    metadata/
      patterns   # Decoder analysis results
      resonance  # Harmonic map
```

### Navigation via Filesystem

```bash
## Read current terminal surface
cat /data/term/amos-term/main/current

## Read historical layer
cat /data/term/amos-term/main/history/z-7

## Read pattern analysis
cat /data/term/amos-term/main/metadata/patterns
```

---

## Existing Infrastructure Reuse

### data zenka Modules Used

```
data.channel.shm.*          → 3D buffer SHM mapping
data.mount.shm.*            → Zero-copy SHM access
data.mount.fuse.*           → FUSE filesystem exposure
data.cmd.mount-hash         → Named buffer mounting
data.topology.interference.* → Pattern resonance mapping
```

### decoder zenka Modules Used

```
decoder.base.decode_d13_bits    → Z-layer decoding
decoder.zenka.receive_entropy   → Terminal as entropy source
decoder.cmd.reduce-entropy      → History compression
decoder.handler.on-boundary     → Layer boundary handling
decoder.cmd.harmony             → Harmonic analysis
```

---

## Implementation Phases

### Phase 1: data.3d.buffer Core
```
- data.3d.buffer.create
- data.3d.buffer.map_shm
- data.3d.buffer.permissions
```

### Phase 2: Terminal Integration
```
- amos-term.3d → data.3d.buffer.mount
- FUSE exposure
```

### Phase 3: Decoder Integration
```
- decoder.3d.buffer.register
- decoder.3d.buffer.analyze
- Pattern metadata publishing
```

### Phase 4: Zero-Copy Optimization
```
- SHM performance tuning
- Lock-free reads
- Copy-on-write for writes
```

---

## Success Metrics

- [ ] <1ms latency for SHM read
- [ ] <5ms for pattern analysis
- [ ] 60 FPS terminal rendering
- [ ] Zero-copy verified (no memcpy in read path)
- [ ] FUSE mount functional
- [ ] Decoder pattern recognition >80% accuracy

---

*Integration Design: 2026-03-25*  
*Core Principle: Zero-copy terminal sharing*  
*Infrastructure: data zenka SHM + decoder patterns*  
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

---
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTDZOBQ*

#,,,.,..,,.,.,,,,,,,.,,,,,,,.,..,,,,,,,,.,..,,..,,...,...,..,,..,,...,.,,,.,,,
#4L6V4LHOKKANFHIUYQKLB4HLPIJFNBOMXEBRBJDJGN54RNBPLLKHB2OYH3EZTOYKLGLJYUJPWD2ZO
#\\\|CHKZTV5QSTWMFRVO27GYADIXYDRKEJJVUCLNLSJDIUYZ3RCQQ7W \ / AMOS7 \ YOURUM ::
#\[7]LPKJFCN35ZLYQMSBSYWDDASUYFNSNYRSMVIIMJNBEB2GAYTUKACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
