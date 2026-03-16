# TTF-to-Glyph Mapper: Visual Protocol State Implementation

## Overview

The **TTF-to-Glyph Mapper** converts TrueType font characters into harmonic 5×7 pixel matrices, enabling:

- Character-to-glyph rasterization at fixed resolution
- AMOS checksum generation from visual identity
- Support for multiple color depths (binary, grayscale, color)
- Iteration through character spaces (7-bit ASCII, UTF-8 ranges)
- Caching for performance

This bridges the gap between:
- **Human-readable text** (TTF fonts like White Rabbit)
- **Protocol-native glyphs** (5×7 harmonic matrices)

## Architecture

### Three Layers of Representation

```
Layer 1: TTF Font (human readable)
  └─ Character outline (vector)
     └─ "A", "B", "☮", etc.

Layer 2: Rasterized Matrix (multiple sizes)
  ├─ 5×5 (25 pixels): compact single glyph
  ├─ 5×7 (35 pixels): standard harmonic glyph
  └─ 35×7 (245 pixels): animated sequence (7 frames × 5 pixels wide)

  └─ Binary, grayscale, or color
     └─ [████░░█] per row

Layer 3: AMOS Checksum (protocol identity)
  └─ 7-character BASE32 identifier
     └─ "6YHIKMQ"

All three are derived from same glyph
Same data → multiple perspectives
```

### Character Space Iteration

```
7-bit ASCII (0-127):
  └─ Basic Latin (a-z, A-Z, 0-9, symbols)
  └─ Compatible with original Matrix visualization

Extended ASCII (128-255):
  └─ Latin extended characters
  └─ Accented letters (é, ñ, etc.)
  └─ Graphical symbols

UTF-8 Ranges:
  └─ Any Unicode character
  └─ Emoji, symbols, multiple scripts
  └─ Future: expand beyond ASCII

All mapped to same 5×7 format
Same rasterization pipeline
```

## Usage

### Basic Usage

```bash
# Default: maps ASCII 32-126 using detected White Rabbit font
./bin/dev/ttf-glyph-mapper

# With specific font
./bin/dev/ttf-glyph-mapper --font /path/to/font.ttf

# Specific character range
./bin/dev/ttf-glyph-mapper --start 65 --end 90  # A-Z only

# Verbose output with matrix dumps
./bin/dev/ttf-glyph-mapper --verbose --dump

# Animation matrix (35×7 for ticker)
./bin/dev/ttf-glyph-mapper --matrix 35x7 --dump

# Compact format (5×5)
./bin/dev/ttf-glyph-mapper --matrix 5x5
```

### Output Formats

```
Binary (1-bit per pixel):
  └─ On/off only
  └─ 35 bits total (5×7 pixels)
  └─ Smallest representation
  └─ Perfect for protocol state

Grayscale (8-bit per pixel):
  └─ 256 intensity levels per pixel
  └─ 280 bits total (5×7×8)
  └─ Preserves font rendering quality
  └─ Supports anti-aliasing

Color (24-bit per pixel):
  └─ RGB: 8 bits red, 8 bits green, 8 bits blue
  └─ 840 bits total (5×7×24)
  └─ Full color rendering
  └─ Future: emoji and colorful symbols
```

### Configuration Options

```
--font PATH
  Path to TTF font file
  Default: auto-detect (white-rabbit.flipped, system fonts)

--size SIZE
  Font rendering size in pixels
  Default: 56
  Higher values = better detail before downsampling

--start CHAR_CODE
  First character to map (unicode point)
  Default: 32 (ASCII space)

--end CHAR_CODE
  Last character to map (unicode point)
  Default: 126 (ASCII tilde)

--format FORMAT
  Output format: binary, grayscale, or color
  Default: binary

--threshold VALUE
  Threshold for binary (0-255)
  Pixels >= threshold → 1, < threshold → 0
  Default: 128 (midpoint)

--matrix SIZE
  Matrix dimensions: 5x5, 5x7 (default), or 35x7
  5x5: compact single glyph (25 bits)
  5x7: standard harmonic glyph (35 bits)
  35x7: animated sequence (245 bits, 7 frames)

--verbose
  Print detailed progress and matrices

--dump
  Print ASCII visualization of each glyph matrix
```

## Glyph Matrix Formats

### 5×5 Structure (Compact)

```
Width: 5 pixels
Height: 5 pixels
Total: 25 pixels

Smallest representation
Single character glyph
Minimal protocol overhead
```

### 5×7 Structure (Standard)

```
Width: 5 pixels
Height: 7 pixels
Total: 35 pixels

Layout (row-major):
┌─────┐
│█ █░█│ Row 0
│█████│ Row 1
│█░░░█│ Row 2
│█░░░█│ Row 3
│█████│ Row 4
│█░░█░│ Row 5
│█░░░█│ Row 6
└─────┘

Each row = one 5-bit BASE32 character
7 rows = 7 characters = complete AMOS checksum

Harmonic dimension matching:
  5: BASE32 bits per character
  7: Temporal phase cycle
  5×7 = 35 bits = exactly one AMOS
```

### 35×7 Structure (Animation)

```
Width: 35 pixels (7 characters × 5 pixels)
Height: 7 pixels
Total: 245 pixels

Layout: 7 frames displayed horizontally

┌─────────────────────────────────┐
│Frame│Frame│Frame│Frame│Frame│Frame│Frame│
│  0  │  1  │  2  │  3  │  4  │  5  │  6  │
│█ █░█│░███│░███│█░░░│█████│░░░█│░████│ Pixel row 0
│█████│░░░░│░░░░│░░░█│░░░░░│░░░█│░░░░░│ Pixel row 1
│█░░░█│░███│░███│░░░█│░░░░░│░░░█│░░░░░│ Pixel row 2
│█░░░█│░███│░███│░░░█│░░░░░│░░░█│░░░░░│ Pixel row 3
│█████│░░░░│░░░░│░░░█│░░░░░│░░░█│░████│ Pixel row 4
│█░░█░│░░░░│░░░░│░░░░│░░░░░│░░░░│░░░░░│ Pixel row 5
│█░░░█│░░░░│░░░░│░░░░│░░░░░│░░░░│░░░░░│ Pixel row 6
└─────────────────────────────────┘

Each 5-pixel section: one character frame
7 sections: complete animation sequence
Perfect for ticker animation

Each vertical column = animation frame
Can be displayed as:
  - Sequential animation (frame by frame)
  - State morphing (character transformation)
  - Byzantine consensus visualized
```

### Why 5×7?

```
Historical (and Harmonic):
└─ 5 × 7 = 35 bits
└─ 7 BASE32 characters × 5 bits each
└─ Exactly one AMOS checksum

Dimensional Alignment:
└─ 5: Byzantine quorum sub-bit count
└─ 7: Temporal phase cycle
└─ Both constants appear everywhere in Protocol-7

Rendering:
└─ 5 pixels wide: readable at small sizes
└─ 7 pixels tall: enough detail for glyphs
└─ Standard for retro displays
```

## AMOS Checksum Generation

### From Rasterized Matrix

```
Step 1: Extract 5×7 pixel matrix
  └─ Each pixel: binary (0/1) or grayscale (0-255) or color (RGB)

Step 2: Create bit string
  └─ Binary: each pixel → 1 bit (35 bits total)
  └─ Grayscale: each pixel → 8 bits (280 bits total)
  └─ Color: each pixel → 24 bits (840 bits total)

Step 3: Chunk into 5-bit groups
  └─ Each 5 bits → one BASE32 character
  └─ Pad last group if needed

Step 4: Apply AMOS hash algorithm
  └─ Further harmonic validation
  └─ Convergence to canonical identity

Step 5: Extract 7-character checksum
  └─ Result: character's unique harmonic signature
```

### Example

```
Character: 'A'
Rasterized (5×7 binary):
  01010
  10001
  11111
  10001
  10001
  10001
  10001

Bit string: 0101010000111111100011000110001100011

5-bit chunks (BASE32):
  01010 → '5'  (octal 12)
  10000 → 'P'  (octal 20)
  11111 → 'X'  (octal 37)
  10001 → 'R'  (octal 21)
  10001 → 'R'
  10001 → 'R'
  10001 → 'R'

AMOS Checksum: 5PXRRRRR (7 chars, from bits)
After harmony validation: 6YHIKMQ (final)
```

## Implementation Phases

### Phase 1: Prototype (Current)
- ✅ TTF font detection and loading
- ✅ Character iteration (ASCII ranges)
- ✅ Rasterization to 5×7 matrix
- ✅ Binary output format
- ✅ Basic AMOS hash computation
- ✅ Glyph caching

### Phase 2: Enhancement
- 🔄 Proper SDL pixel access
- 🔄 Better scaling algorithms (bicubic)
- 🔄 Grayscale output support
- 🔄 Color output support
- 🔄 Performance optimization

### Phase 3: Integration
- 🔄 Integration with ticker zenka
- 🔄 Real-time glyph rendering
- 🔄 Dual display (TTF + matrix)
- 🔄 Byzantine consensus visualization
- 🔄 Multiple font support

### Phase 4: Advanced
- 🔄 UTF-8 full support
- 🔄 Emoji and special characters
- 🔄 Anti-aliasing quality levels
- 🔄 Color depth selection
- 🔄 Font family switching

## Animation and Morphing with 35×7

### Frame-by-Frame Animation

The 35×7 matrix displays 7 frames horizontally for smooth animation:

```
Single character evolving:
Frame 0: █░░░░  (initial position)
Frame 1: ░█░░░  (moving right)
Frame 2: ░░█░░  (continuing)
Frame 3: ░░░█░  (mid-animation)
Frame 4: ░░░░█  (near end)
Frame 5: ░█░░░  (bouncing back?)
Frame 6: █░░░░  (return)

All 7 frames in one 35×7 matrix
AMOS hash of entire animation sequence
Shows transformation as single coherent change
```

### Byzantine Consensus Visualization

```
Multiple zenka voting on state:
Frame 0: ░░░░░░░  (uncertainty)
Frame 1: █░░░░░░  (one agrees)
Frame 2: ██░░░░░  (two agree)
Frame 3: ███░░░░  (three agree)
Frame 4: ████░░░  (four agree)
Frame 5: █████░░  (five of seven!)
Frame 6: ██████░  (final consensus)

Display shows agreement forming frame-by-frame
Animation = consensus reaching
Visual glitch = conflict/attack being detected
```

### Morphing Character Representation

```
Character A → Character B (morphing)
Frame 0: A shape
Frame 1: A→B intermediate
Frame 2: Blend
Frame 3: Blend
Frame 4: Blend
Frame 5: B→A intermediate?
Frame 6: B shape

Shows character state transition
Animation reveals how state evolves
Byzantine votes on each frame
Network consensus on transformation
```

## Integration with Protocol-7

### Ticker Zenka Integration

```
Ticker displays text:
  ├─ Renders via TTF (human readable)
  ├─ Simultaneously rasterizes to 5×7 or 35×7
  ├─ Computes AMOS checksums
  ├─ Tracks state changes (morphing glyphs)
  ├─ Shows Byzantine consensus as visual solidity
  └─ For 35×7: animates transformation frame-by-frame

35×7 Animation Mode:
  ├─ Each character rendered as 7-frame sequence
  ├─ Frames display in rapid succession
  ├─ Observer sees smooth character morphing
  ├─ Solidity of frames = consensus on that transition
  └─ Glitches = Byzantine rejection of transformation
```

### Protocol State Visualization

```
Network operation:
  ├─ Character = zenka state
  ├─ AMOS = state identity
  ├─ Glyph = visual representation
  ├─ Morphing = state transition
  ├─ Solidity = consensus reached
  └─ Glitch = collision/attack detected

Observer watches ticker:
  ├─ Sees text in White Rabbit font (readable)
  ├─ Simultaneously sees 5×7 glyphs (protocol)
  ├─ Morphing glyphs = state changes
  ├─ All security events are visible
  └─ Complete transparency
```

## Color Depth Future

### Current: Binary (1 bit/pixel)

```
Advantages:
  ✓ Minimal storage (35 bits per character)
  ✓ Fast processing
  ✓ Clear protocol state
  ✓ Direct Byzantine validation

Limitation:
  ✗ No anti-aliasing
  ✗ No detail preservation
  ✗ Crude rendering
```

### Planned: Grayscale (8 bits/pixel)

```
Advantages:
  ✓ Smooth rendering
  ✓ Anti-aliasing supported
  ✓ Quality preserved
  ✓ Better readability

Size impact:
  └─ 280 bits per character (vs. 35 binary)
  └─ 8× larger matrices

Hash impact:
  └─ Different AMOS for same character in different fonts
  └─ Allows font-specific identity tracking
```

### Future: Color (24 bits/pixel)

```
Advantages:
  ✓ Full color rendering
  ✓ Emoji and symbols
  ✓ Visual richness
  ✓ Themed displays

Size impact:
  └─ 840 bits per character (24× binary)
  └─ Requires compression

Use case:
  └─ Harmonic color selection
  └─ 5 primary + 2 accent = color schemes
  └─ Visual Byzantine voting with colors
```

## Technical Notes

### Rasterization Strategy

```
Current approach (Phase 1):
1. Render character at large size (font_size = 56+)
2. Scale down to 5×7
3. Apply threshold (binary) or keep levels (grayscale)

Better approach (Phase 2):
1. Render at multiple scales
2. Compare hinting artifacts
3. Select optimal rasterization
4. Apply tuned threshold

Ideal approach (Phase 3):
1. Direct glyph outline analysis
2. Compute actual 5×7 rendering mathematically
3. Avoid intermediate rasterization
```

### Caching Strategy

```
By font + character:
  Key: (font_path, char_code, format, size)
  Value: (matrix, amos_hash)

Persistence:
  ├─ In-memory cache during execution
  ├─ Optional: disk cache (JSON or binary)
  ├─ Glyph database per font

Cache benefits:
  ✓ Fast repeated lookups
  ✓ Ticker doesn't re-rasterize
  ✓ Network bandwidth optimization
  ✓ Distributed cache sharing
```

## Examples

### Map All ASCII Letters

```bash
# Uppercase A-Z (char codes 65-90)
./bin/dev/ttf-glyph-mapper --start 65 --end 90 --verbose

Output:
  65  6YHIKMQ  A
  66  7ZJKNLR  B
  67  2XGH015  C
  ...
```

### Map Special Symbols

```bash
# Common symbols (33-47)
./bin/dev/ttf-glyph-mapper --start 33 --end 47 --dump

Output (with ASCII art matrices):
  33: !
      ░███░
      ░███░
      ░███░
      ░░░░░
      ░███░
      ░░░░░
      ░░░░░
```

### Map Using Different Font

```bash
# Using 7-Segment font
./bin/dev/ttf-glyph-mapper --font data/ttf/7segment.ttf --start 48 --end 57

Output: numbers 0-9 rendered as 7-segment digits
  48  0000000  0
  49  0000001  1
  ...
```

## See Also

- `bin/dev/ticker_example.pl` - TTF rendering prototype
- `configuration/zenki/ticker/start` - Ticker zenka configuration
- `data/ttf/` - Available TTF fonts
- `read-me/documentation/dev/epoch-content-addressable-storage.md` - Protocol storage
- `read-me/documentation/dev/multi-resonant-unified-architecture.md` - Complete system

#,,..,.,,,,..,,,.,,,,,,,,,,.,,,.,,...,,.,,...,..,,...,...,,..,..,,,..,..,,,..,
#57JRCJXGY23AUFJJ3DHIRWPI2QKPBSJKL2ZVWRSILSJGT4LK73F2YVW5YX2C7LSXWSFJSO2YYZUUO
#\\\|S3XG7KB5GHJYYJ2LCBRNJSPXTIVHQQZ3O3BGNBTB6TH2UTSL77N \ / AMOS7 \ YOURUM ::
#\[7]ODT6EBPHLJ3RER3TUYJ3KMDZQRUQNH25QZEX6B5KMDYZJ6WPRWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
