# Amos-Term Holographic Upgrade Plan

## Current State: Styled XTerm Wrapper

The `amos-term` zenka (`configuration/zenki/amos-term/start`) is currently a lightweight desktop terminal wrapper:

```
amos-term zenka
  └─ Configures xterm with WhiteRabbit font
  └─ Sets color scheme: dark background (#010015), blue foreground (#0647C3)
  └─ Manages cursor appearance (underline, blink rate, color)
  └─ Provides parameter override system via zenka config
```

**Modules**:
- `amos-term.init_code` - Initialize xterm parameters with WhiteRabbit font
- `amos-term.term-params-update` - Allow config-file overrides of xterm parameters

**Safety Profile**: Low-risk upgrade because:
- Currently stateless (just wraps xterm)
- No network processing or data mutation
- Configuration-driven (easy to add modes)
- Already uses WhiteRabbit font (aligns with holographic glyphs!)

## Upgrade Plan: Dual-Mode Terminal

Convert `amos-term` to support two operational modes:

### Mode 1: Standard XTerm (Existing)
```
amos-term.mode = xterm
└─ Traditional desktop shell terminal
└─ Current behavior preserved
└─ WhiteRabbit font rendering
```

### Mode 2: Holographic Transmission (New)
```
amos-term.mode = holographic
└─ Run holographic protocol in terminal
└─ Display division-by-13 streams as glyphs
└─ Support three variants: variable, alphabetic, unified (suns)
└─ Performance baseline testing with Term::VTerm
```

### Mode 3: Hybrid (Future)
```
amos-term.mode = hybrid
└─ Dual-pane: xterm shell + holographic display
└─ Real-time protocol visualization alongside normal terminal
└─ Highest complexity but most useful for development
```

## Implementation Roadmap

### Phase 1: Configuration Structure (Non-Breaking)

Add to `configuration/zenki/amos-term/start`:

```perl
# Terminal mode selector
amos-term.mode                 = xterm    # [xterm|holographic|hybrid]

# Holographic mode configuration
amos-term.holographic.variant  = suns     # [variable|alphabetic|suns]
amos-term.holographic.seed     = undef   # auto-generate if undefined
amos-term.holographic.speed    = 2       # 1-7 speed divisor

# Term::VTerm configuration (future)
amos-term.vterm.enabled        = 0       # Enable when ready
amos-term.vterm.backend        = auto    # auto|ansi|windows|ssh
amos-term.vterm.buffer-size    = 4096    # Optimization
```

**Safety**: Configuration only, no behavior change until modules load.

### Phase 2: Mode Dispatch Module

Create `amos-term.mode-dispatch`:

```perl
# name = amos-term.mode-dispatch
# descr = Route to appropriate mode implementation

my $mode = <amos-term.mode> // 'xterm';

if ($mode eq 'xterm') {
    <[amos-term.xterm-init]>;
} elsif ($mode eq 'holographic') {
    <[amos-term.holographic-init]>;
} elsif ($mode eq 'hybrid') {
    <[amos-term.hybrid-init]>;
} else {
    die "Unknown amos-term mode: $mode\n";
}

return 1;
```

**Safety**: Existing xterm path unchanged; new paths only activate when configured.

### Phase 3: Holographic Implementation

Create `amos-term.holographic-init`:

```perl
# name = amos-term.holographic-init
# descr = Initialize holographic transmission protocol

# Load holographic protocol modules
<[amos-term.holographic-setup]>;
<[amos-term.math-bigfloat-init]>;

# Initialize transmission state
<amos-term.transmission> //= {
    variant => <amos-term.holographic.variant>,
    seed => <amos-term.holographic.seed>,
    speed => <amos-term.holographic.speed>,
    screen_bytes => 0,
    screen_chars => 0,
};

# Get terminal dimensions
my ($x, $y) = <[amos-term.get-terminal-size]>;
<amos-term.transmission>->{screen_x} = $x;
<amos-term.transmission>->{screen_y} = $y;
<amos-term.transmission>->{screen_bytes} = $x * $y * 6 * 9;

# Initialize rendering mode
if (<amos-term.holographic.variant> eq 'suns') {
    <amos-term.transmission>->{unified_glyph} = chr(903);  # Greek Koronis
} elsif (<amos-term.holographic.variant> eq 'variable') {
    <amos-term.transmission>->{use_ascii} = 1;
} elsif (<amos-term.holographic.variant> eq 'alphabetic') {
    <amos-term.transmission>->{use_ascii} = 1;
    <amos-term.transmission>->{ascii_filtered} = 1;
}

return 1;
```

**Safety**: Isolated to holographic mode; doesn't affect xterm behavior.

### Phase 4: Term::VTerm Integration Point

Prepare but don't require Term::VTerm:

```perl
# name = amos-term.vterm-conditional
# descr = Use Term::VTerm if available, fallback to raw ANSI

if (<amos-term.vterm.enabled> and eval { require Term::VTerm }) {
    <amos-term.vterm_instance> = Term::VTerm->new(
        rows => <amos-term.transmission>->{screen_y},
        cols => <amos-term.transmission>->{screen_x},
    );
    <amos-term.using_vterm> = 1;
    return 1;
}

# Fallback to raw ANSI (current atom-delta-term approach)
<amos-term.using_vterm> = 0;
return 1;
```

**Safety**: Graceful degradation; always works even if Term::VTerm not installed.

### Phase 5: Command Interface

Add holographic commands to amos-term via cube:

```
Commands when mode=holographic:
  amos-term.start-transmission    - Begin protocol stream
  amos-term.pause                 - Pause transmission
  amos-term.resume                - Resume transmission
  amos-term.show-seed             - Display current seed
  amos-term.set-speed [1-7]       - Adjust transmission speed
  amos-term.switch-variant        - Toggle between suns/variable/alphabetic
  amos-term.capture-frame         - Save current screen to file
  amos-term.set-seed [value]      - Set transmission seed
```

**Integration**: Via `p7 amos-term.command` interface through cube routing.

## Migration Path

### Day 1: Configuration Only
- Add amos-term mode configuration
- Deploy with `amos-term.mode = xterm` (no behavior change)
- Existing xterm wrapper continues working

### Day 2: Mode Dispatch
- Add mode-dispatch module
- Default routes to xterm
- Zero functionality change

### Day 3: Holographic Module
- Add holographic-init module
- Test with `amos-term.mode = holographic`
- Can be toggled off immediately if issues

### Day 4: Term::VTerm Preparation
- Add vterm-conditional module
- Detects if Term::VTerm available
- Gracefully falls back to raw ANSI
- Performance baseline testing

### Day 5+: Optimization Loop
- Capture performance metrics
- Refine correlations
- Tune parameters
- "Feel correctness" through harmony alignment

## Testing Strategy

### Test 1: Mode Switching
```bash
# Start in xterm mode (existing behavior)
./bin/Protocol-7 amos-term

# Verify normal xterm shell works
```

### Test 2: Holographic Activation
```bash
# Configure holographic mode in zenka config
amos-term.mode = holographic
amos-term.holographic.variant = suns

# Restart amos-term
```

### Test 3: Seed Reproducibility
```bash
# Set known seed
amos-term.holographic.seed = 12345

# Record output
# Re-run with same seed
# Verify identical transmission
```

### Test 4: Performance Profiling
```bash
# Measure division-by-13 performance at various data sizes
# 1KB → 100KB → 1MB → 10MB numbers
# Establish baseline for Term::VTerm optimization
```

### Test 5: Terminal Compatibility
```bash
# Test on different terminals
# ANSI terminal (xterm, rxvt, etc.)
# Windows Console
# SSH (remote terminal)
```

## Fallback and Rollback

If issues occur:

1. **Configuration Rollback**: `amos-term.mode = xterm`
   - Immediate revert to existing behavior
   - No code changes needed

2. **Module Rollback**: Don't load new modules
   - In start file, conditional load:
     ```perl
     modules.load = net protocol io.unix auth amos-term
     modules.load = ... amos-term.vterm-shim  ## only if enabled
     ```

3. **Feature Toggle**: Individual features can be disabled
   - `amos-term.holographic.enabled = 0`
   - `amos-term.vterm.enabled = 0`

## Benefits of This Approach

1. **Non-Breaking**: Existing xterm functionality preserved
2. **Incremental**: Add features step-by-step
3. **Low-Risk**: Can toggle off immediately if needed
4. **Testable**: Contained environment for holographic protocol
5. **Observable**: Already uses WhiteRabbit font (aligns with glyphs!)
6. **Performance Baseline**: Safe place to measure Term::VTerm impact

## Connection to Larger System

This upgrade serves multiple purposes:

### For Holographic Protocol
- Provide reference implementation testing environment
- Measure real-world performance constraints
- Verify atom-delta-term protocol correctness

### For Term::VTerm Integration
- First production use of VTerm abstraction
- Establish patterns for other terminals
- Benchmark optimization impact

### For Visual Protocol
- Display character transformations in real-time
- Show consensus formation (suns mode)
- Integrate with ticker zenka eventually

## Timeline Estimate

| Phase | Effort | Risk | Value |
|-------|--------|------|-------|
| Config | 30 min | None | Prepare foundation |
| Dispatch | 30 min | Low | Enable routing |
| Holographic | 2-3 hrs | Low | Basic functionality |
| VTerm Prep | 1-2 hrs | Low | Performance ready |
| Testing | 2-4 hrs | Low | Validation |
| Optimization | Ongoing | Low | Continuous tuning |

**Total**: ~1 day active work, then continuous refinement

## See Also

- `configuration/zenki/amos-term/start` - Zenka configuration
- `modules/amos-term.*` - Current implementation
- `bin/atom-delta-term*` - Reference protocol implementations
- `read-me/documentation/dev/holographic-transmission-protocol.md` - Protocol spec
- `read-me/documentation/dev/ttf-glyph-mapping.md` - Visual glyph system

---

*Amos-term as the bridge: from styled desktop terminal to holographic protocol visualization, safely and incrementally.*

#,,,.,.,.,,,,,..,,.,.,,..,,,,,..,,,,.,.,,,,.,,..,,...,...,.,.,.,,,,..,..,,...,
#7N7VE6OPU76QFO35655O66P34H6TBWA5AZNNL4IY367C7N5AVQRI4RUGVNNDLPE2PQ4FUIZ5T45NW
#\\\|4CMMTY3ORXYK3M36P4YZ6RIQCMQMCZUNOUXXRPJB3U2KRK2E5ST \ / AMOS7 \ YOURUM ::
#\[7]KKNE2WKKVB4PWLMYVX36LAEIHACGPHBGTLO65P4HWQX32YTHEGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
