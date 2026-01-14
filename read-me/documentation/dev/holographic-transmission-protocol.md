# Holographic Transmission Protocol: Framework-First Design

## Overview

The **Holographic Transmission Protocol** establishes a transmission order that mirrors the shaman principle: transmit the rules before the tools, the tools before the patterns, and the patterns before the payload.

This document describes the Protocol-7 implementation of this concept, as demonstrated in the `atom-delta-term*` scripts and connecting to the harmonic visual system (TTF-to-Glyph mapping and AMOS checksums).

## Transmission Order: The Shaman Framework

The protocol transmits in this sequence:

```
1. [TRUE and FALSE Framework]
   └─ Establish the rules/states (harmonic validation)
      └─ Created by: bin-elf-table (character truth analysis)
      └─ Transmitted as: seed initialization, mode validation

2. [Entire Character Set]
   └─ Define the alphabet/visual tools
      └─ Can be: variable (ASCII 32-255), unified (single glyph), or mapped (TTF/5×7)
      └─ Validated by: bin-elf-table truth filtering
      └─ Created by: ttf-glyph-mapper (custom glyph maps)

3. [Templates] (Optional)
   └─ Structural patterns and rules
      └─ Can be: display algorithms, color mappings, animation patterns
      └─ Protocol: ANSI color sequences, position calculations, rendering rules

4. [Payload]
   └─ Actual data manifest
      └─ Encoded as: character codes, positions, colors, timing
      └─ Displayed by: terminal renderer or UI system
```

## Implementation: The atom-delta-term Series

Three working implementations demonstrate the protocol at different abstraction levels:

### atom-delta-term (Main Implementation - 648 lines)

The complete reference implementation showing all layers of the holographic protocol.

**Transmission Format** (decoded sequentially from numerical stream):

```
[3 digits] RGB Red component     (0-255)
[3 digits] RGB Green component   (0-255)
[3 digits] RGB Blue component    (0-255)
[3 digits] Color Intensity       (0-255, affects brightness)
───────────────────────────────────
[3 digits] Position X coordinate (terminal column)
[3 digits] Position Y coordinate (terminal row)
───────────────────────────────────
[3 digits] Character Code        (32-255 = ASCII printable)
```

**Key Features:**

- **Seeded Streams**: Two entropy sources
  - `fortuna` - Cryptographic PRNG for initialization
  - `zulum` - Division-by-13 stream for harmonic generation

- **State Management**:
  ```perl
  $state->{'screen-bytes'} = $x * $y * 6 * 9;  # 18 chars per position
  $state->{'screen-chars'} = $x * $y * 9;      # 9 groups per screen
  ```

- **Division-by-13 Core**:
  ```perl
  $state->{'result-13'} = scalar $math->{'zulum'}->copy()
      ->bdiv(13, $state->{'screen-bytes'});
  ```
  The transmission is fundamentally a continuous division-by-13 sequence, decoded into display elements.

- **Interactive Control**:
  ```
  Commands: clear, reset, start, resume, rewind, show-seed
  Displays: result-13, zulum, loop-count, network-time
  Settings: set, unset, speed adjustment (1-7)
  ```

**Harmonic Constants Embedded**:
- `$freq / $speed_div` - Frame timing harmonized to display refresh rate
- Time seed: `(time * 4200) / 13 / 13 / 13` - Triple division encoding
- Network time: `(unix_time - 1023228000) * 4200` - Since 2002-06-05, using 4200 harmonic constant

### atom-delta-term-alphabetic (Simplified - 605 lines)

Cleaner implementation focusing on alphabetic character transmission.

**Differences:**
- Simplified color calculation: `255 * (0.001 * col_num) * (0.001 * col_num3)`
- Directly maps 3-digit groups to color channels without intermediate scaling
- ASCII character validation (32-255 printable range)
- More readable character handling path

**Use Case**: Baseline protocol testing with standard ASCII characters.

### atom-delta-term-suns (Unified Glyph - 607 lines)

Demonstrates the **unified character set** mode where all characters become the same glyph.

**Key Change** (line 334):
```perl
## my $character = chr($char_num);
##
my $character = chr(903);    # Greek Letter Koronis: ΄
```

This forces all transmitted characters to map to Unicode U+037F (Greek Koronis), creating a unified visual field where:
- Position varies (x, y coordinates)
- Color varies (RGB for each glyph)
- Glyph is constant (single unified character)
- Only the color and position encode information

**Why This Matters**: This is the **template layer** at work. A single glyph repeated across the display creates a "sun field" pattern where information density is encoded in the spatial arrangement and coloring, not the character variation.

This is precisely how the TTF-to-Glyph system could work:
- Replace chr(903) with a specific 5×7 glyph
- The glyph represents state/identity
- Position and color represent routing/phase
- Animation (35×7) shows state morphing

## Connection to Character Truth Analysis

**bin-elf-table** provides the TRUE/FALSE framework mentioned in step 1:

```bash
# Find characters that are TRUE in modes 4 and 7
bin-elf-table -m 4:7 -T

# Examine character range 65-90 (A-Z)
bin-elf-table -R 65..90 -T

# Filter for specific harmonic properties
bin-elf-table -M 01 -T        # Characters with ELF sum containing '01'
```

The transmission protocol uses this truth framework:
1. Before transmission begins, establish which characters are valid (TRUE) and which aren't (FALSE)
2. The character set transmitted contains only validated characters
3. Invalid characters (FALSE state) are either:
   - Filtered out during transmission prep
   - Mapped to substitute glyphs
   - Cause transmission errors/retransmission

## Connection to TTF-to-Glyph Mapping

The atom-delta-term transmission protocol is currently character-agnostic: it transmits a character code, and the terminal renders whatever character code that is.

Integration points with TTF-to-Glyph:

### Current Path (ASCII Characters):
```
atom-delta-term → character code (65) → terminal renders 'A'
```

### Enhanced Path (Protocol Glyphs):
```
atom-delta-term → glyph code (0-127)
                → ttf-glyph-mapper lookup
                → render 5×7 matrix at screen position
                → display as protocol-native glyph
```

### Unified Glyph Path (atom-delta-term-suns model):
```
atom-delta-term → color + position → chr(903) or 5×7 glyph
                → render unified glyph with color
                → creates "sun field" of colored glyphs
                → animation shows color morphing
```

### Full Integration (Ticker-Mode):
```
atom-delta-term → character sequence + position + color
                → ttf-glyph-mapper(char_code)
                → get 5×7 or 35×7 glyph matrix
                → compute AMOS checksum (char identity)
                → ticker renders morphing glyph
                → observe character state transition + Byzantine consensus
```

## Protocol Layers in Action

### Layer 1: Framework (TRUE/FALSE)

**Source**: bin-elf-table filtering

The transmission begins by establishing:
- Which character codes are harmonically valid
- Which modes (4, 7, 10, 13) are active
- What harmonic truth state each transmission element claims

### Layer 2: Alphabet (Character Set)

**Source**: bin-elf-table validated subset

Example character set for transmission:
```
Characters validated as TRUE in modes 4:7:
  A (65) - TRUE    → included in set
  B (66) - FALSE   → filtered out OR mapped to substitute
  C (67) - TRUE    → included in set
  ...
```

**Alternative: Unified Glyph Set**
```
All characters → map to single glyph (chr(903) or 5×7 matrix)
                → creates uniform visual field
                → position/color become primary information channel
```

### Layer 3: Templates (Display Rules)

**Built into decode_char() function**:

```perl
sub decode_char {
    my $input = $_[0];

    # Extract RGB from 3-digit groups
    my $col_num_0 = substr($input->$*, 0, 3);  # Red
    my $col_num_1 = substr($input->$*, 0, 3);  # Green
    my $col_num_2 = substr($input->$*, 0, 3);  # Blue
    my $col_num_3 = substr($input->$*, 0, 3);  # Intensity

    # Apply color template
    $fg_color .= color(sprintf('r%dg%db%d',
        int(255 * (0.001 * $col_num_0) * (0.001 * $col_num_3)),
        int(255 * (0.001 * $col_num_1) * (0.001 * $col_num_3)),
        int(255 * (0.001 * $col_num_2) * (0.001 * $col_num_3))
    ));

    # Extract position template
    my $pos_x = substr($input->$*, 0, 3);
    my $pos_y = substr($input->$*, 0, 3);

    # Extract character template
    my $char_num = substr($input->$*, 0, 3);
    my $character = chr($char_num);  # or use unified glyph

    # Render using ANSI position + color + character
    return join('', "\e[${pos_y};${pos_x}H", $bg_color, $fg_color, $character);
}
```

Templates define:
- Color mixing formula: `intensity * RGB_channel`
- Position wrapping logic (handle overflow)
- Character validation (32-255 range)
- Fallback behavior (invalid characters → space)

### Layer 4: Payload (Data)

The actual numbers flowing through the division-by-13 stream:

```perl
$state->{'result-13'} = scalar $math->{'zulum'}->copy()
    ->bdiv(13, $state->{'screen-bytes'});
```

This produces a decimal number like:
```
0.123456789012345678901234567890...
└─ First 3 digits: 123 (color red)
   Next 3 digits: 456 (color green)
   Next 3 digits: 789 (color blue)
   Next 3 digits: 012 (intensity)
   Next 3 digits: 345 (position x)
   Next 3 digits: 678 (position y)
   Next 3 digits: 901 (character code)
   ... repeats
```

The payload is **deterministic**: same seed always produces same transmission.

## Harmonic Constants in the Protocol

### The 4200 Constant
- Appears in time encoding: `(unix_time - ntime_start) * 4200`
- Related to: `5 * 7 * 120` or `1680 * 2.5` or other factorizations
- Creates harmonic frequency relationship with 13-division

### Speed Divisions (1-7)
```perl
$speed_div = 8 - $ARGV_speed;  # Range: 1-7
$frame_delay = 1 / ($freq / $speed_div);
```
- 7 speed levels (the harmonic constant)
- Inverse relationship to frequency
- Higher speed_div = slower display

### Screen Byte Calculations
```perl
$state->{'screen-bytes'} = $x * $y * 6 * 9;   # 54 bytes per cell
$state->{'screen-chars'} = $x * $y * 9;       # 9 fields per cell
```
- 9 fields: RGB (3) + Intensity (1) + Position (2) + Character (1) + padding (1)
- 6 × 9 = 54 bytes per encoded position
- Relates to 5×7 = 35 bit glyph + overhead

### Division by 13³
```perl
$state->{'seed'}->{'num'} = sprintf('%.13f', (time * 4200) / 13 / 13 / 13)
```
- Triple division creates harmonic resonance
- Three scales of harmonic reduction
- Encodes high-precision timing in narrow decimal

## Data Signature Integration

Each atom-delta-term script ends with:

```
#,,,...,.,...,,,.,
#[AMOS-STYLE-BASE32-CHECKSUM-1]
#\\\|[AMOS-STYLE-BASE32-CHECKSUM-2] \ / AMOS7 \ YOURUM ::
#\[7][AMOS-STYLE-BASE32-CHECKSUM-3] 7  DATA SIGNATURE ::
#:::::::::::::::::
```

These signatures validate:
- The transmission protocol implementation itself
- The correctness of the encoding/decoding logic
- The harmonic integrity of the seed generators

## Protocol Variations and Modes

### Mode 1: Variable Character Transmission (atom-delta-term)
- **Characters**: ASCII 32-255 (full printable set)
- **Information density**: Character + color + position
- **Use case**: Complex information, varied symbols
- **Truth requirement**: Characters must pass bin-elf-table filtering

### Mode 2: Unified Glyph Transmission (atom-delta-term-suns)
- **Characters**: Single glyph (chr(903) or mapped 5×7 matrix)
- **Information density**: Color + position only
- **Use case**: Symbolic fields, consensus visualization, "suns"
- **Truth requirement**: Glyph itself is validated; position/color carry meaning

### Mode 3: Harmonic Glyph Transmission (future)
- **Characters**: Mapped TTF glyphs from ttf-glyph-mapper
- **Information density**: Glyph state + color + position
- **Use case**: Complete visual protocol integration, ticker animation
- **Truth requirement**: Glyph AMOS checksum validates character state

## Example: Transmission Walkthrough

### Initialization Phase

```
User starts: atom-delta-term

1. Establish framework
   └─ fortuna PRNG seed from entropy
   └─ zulum BigFloat seed from 7 irand() calls
   └─ network_time established

2. Initialize state
   └─ Validate time encoding
   └─ Set screen dimensions
   └─ Configure speed (1-7 range)

3. First division-by-13
   └─ Divide zulum by 13 to screen-bytes precision
   └─ Extract decimal digits
   └─ Separate into RGB, position, character
```

### Transmission Phase

```
1. Start main loop: while(13) { ... }
   └─ Continue until CTRL+C (harmonic constant!)

2. Each iteration:
   └─ Recalculate: zulum / 13
   └─ Match zulum offset (find decimal point)
   └─ Slice result to screen-bytes precision

3. Decode characters:
   for each position on screen:
      └─ extract 3 digits: red channel
      └─ extract 3 digits: green channel
      └─ extract 3 digits: blue channel
      └─ extract 3 digits: intensity
      └─ extract 3 digits: position x
      └─ extract 3 digits: position y
      └─ extract 3 digits: character code
      └─ render: "\e[y;xH" + color + character

4. Display result
   └─ ANSI positions each character
   └─ Colors applied per transmission spec
   └─ Character from 0-255 range (or unified glyph)
```

### Payload Phase

```
The displayed result is the manifest of the payload:
  ├─ Character set visible: which codes are being used
  ├─ Color field visible: intensity/direction encoding
  ├─ Position field visible: spatial distribution
  ├─ Animation visible: smooth morphing through iterations
  └─ Truth observable: solid characters = consensus, glitches = conflicts
```

## Integration with Protocol-7 Ecosystem

### Connection to Zenka Architecture
- `atom-delta-term` could run as a standalone zenka
- Receives transmission seed from cube routing
- Displays result on connected terminal
- Commands routed through p7 interface

### Connection to Ticker Zenka
- atom-delta-term provides transmission framework
- ticker applies TTF font rendering
- ttf-glyph-mapper provides glyph lookup
- bin-elf-table validates character sets
- AMOS checksums track glyph state identity

### Connection to Storage
- Epoch-based storage paths: `<EPOCH>/<AMOS>/<BMW>/`
- Each transmission could be archived by its AMOS checksum
- Replaying a transmission with same seed reproduces exact visual
- Distribution across network: transmission = search query

## See Also

- `bin/atom-delta-term` - Main holographic protocol implementation
- `bin/atom-delta-term-alphabetic` - Simplified ASCII-focused version
- `bin/atom-delta-term-suns` - Unified glyph mode demonstration
- `bin/dev/bin-elf-table` - Character truth analysis and validation
- `bin/dev/ttf-glyph-mapper` - TTF to harmonic matrix conversion
- `read-me/documentation/dev/ttf-glyph-mapping.md` - Glyph system
- `read-me/documentation/dev/multi-resonant-unified-architecture.md` - Full system context

---

*The holographic transmission protocol: rules before tools, tools before patterns, patterns before payload.*

#,,,...,...,...,..,..,,,,...,,..,...,...,,..,...,...,,.,,,.,,,,.,,,,,,,.,,,,,.,.
#PLACEHOLDER-AMOS-SIGNATURE-1
#\\\|PLACEHOLDER-AMOS-SIGNATURE-2 \ / AMOS7 \ YOURUM ::
#\[7]PLACEHOLDER-AMOS-SIGNATURE-3 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
