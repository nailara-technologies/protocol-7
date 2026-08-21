# Console Zenka: Hyperspace Matrix Viewer

**Status**: Design Phase → Implementation Ready  
**Dependencies**: amos-data-pager-56, data.channel.hyperspace, graphics-matrix.visual  
**Integrates With**: cube, decoder, data zenki

---

## Overview

A console-based zenka that connects to the Protocol-7 cube and visualizes the hyperspace routing matrix using the existing `amos-data-pager-56` infrastructure.

**Key Innovation**: The 56-bit pager becomes a **window into 7-dimensional routing space** — each row is a consensus channel, each page is a quadrant of the cubic topology.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONSOLE ZENKA                                  │
│                    (Terminal Interface)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │ CUBE        │◄──►│ HYPERSPACE  │◄──►│ 56-BIT PAGER        │  │
│  │ CONNECTION  │    │ ROUTING     │    │ VISUALIZATION       │  │
│  │             │    │ MATRIX      │    │                     │  │
│  │ - Commands  │    │             │    │ - 7 rows visible    │  │
│  │ - Events    │    │ - 7 channels│    │ - 56 bits/row       │  │
│  │ - Heartbeat │    │ - Quadrants │    │ - true_int coloring │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
│          │                 │                    │                │
│          └─────────────────┴────────────────────┘                │
│                          │                                       │
│                    ┌─────┴─────┐                                  │
│                    │  KEYBOARD │                                  │
│                    │  NAVIGATION│                                 │
│                    │             │                                │
│                    │ ↑↓←→ : Move │                                │
│                    │ PgUp/Dn: Z+ │                                │
│                    │ Space: Dial │                                │
│                    └─────────────┘                                │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 56-Bit Visualization as Hyperspace Window

### Row Mapping (7 Consensus Channels)

```
Row 0: [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] Ch 0
Row 1: [▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] Ch 1
Row 2: [░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░] Ch 2
Row 3: [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓] Ch 3
Row 4: [▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓] Ch 4
Row 5: [░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░] Ch 5
Row 6: [░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░] Ch 6
       └──────────────────────────────────────────────────────┘
       0        14        28        42        56 bits

▓ = 1 (signal active)    ░ = 0 (signal quiet)
Color: true_int() ? Cyan : Dark Blue (harmonic truth coloring)
```

### Channel Meanings

| Row | Channel | Purpose |
|-----|---------|---------|
| 0 | Address Carrier | Base32 character transmission |
| 1 | Even/Odd Parity | Inversion group indicator |
| 2 | Threshold Accum | ±5 voting progress |
| 3 | Routing Direction | Next hop pointer |
| 4 | Scratch-Code 0 | Context metadata |
| 5 | Scratch-Code 1 | Inference data |
| 6 | Consensus Valid | +5 reached / locked |

---

## 3D Navigation Commands

### Standard Pager (Existing)
```
↑/↓     : Line up/down        (Y-axis)
PgUp/Dn : Page up/down        (Y-axis fast)
←/→     : Bit shift           (X-axis)
```

### Hyperspace Extensions (New)
```
Space   : "Dial" current address (trigger inference collection)
Tab     : Switch quadrant view
Z/z     : Ascend/Descend tree (Z-axis)
Q/q     : Quadrant skip forward/backward
Enter   : Enter selected node (zoom)
Esc     : Exit to parent (zoom out)
```

### Address Dialing Mode

When Space is pressed on a 56-bit row:

```
Current row: "7VNK3..." (partial address)
       ↓
Dial:  "7" → Query inference point
       ↓
Collect: Zone metadata displayed in status line
       ↓
Next:  "V" → Query next level
       ↓
Accumulate context as address assembles!
```

---

## Integration with Cube

### Command Interface

```perl
## console.hyperspace.connect
## Connects to cube and subscribes to routing events

my $viewer = <[console.hyperspace.connect]>->({
    'cube'       => 'unix:/var/run/.7/UNIX/NIW7OAQ',
    'zenka'      => 'data',           # Subscribe to data zenka events
    'visualizer' => 'amos-data-pager-56',  # Use existing pager
});

## Returns filehandle to 56-bit stream
```

### Event Handling

```perl
## Hyperspace packets arrive as 56-bit rows
## Visualized in real-time via pager

while (my $packet = <$hyperspace_fh>) {
    # 56 bits = 7 bytes
    my @channels = split_row_into_7_channels($packet);
    
    # Colorize based on true_int
    my $is_true = <[amos7.true_int]>->($packet);
    
    # Display via pager-56
    <[console.pager56.display]>->({
        'data'   => $packet,
        'color'  => $is_true ? 'cyan' : 'dark_blue',
        'row'    => $current_row++,
    });
}
```

---

## Implementation Plan

### Phase 1: Module Wrapper
**Module**: `console.hyperspace.viewer`

```perl
## Wrapper around amos-data-pager-56
## Adds cube connection and event handling

use AMOS7::INLINE;  # For true_int, bit_string_to_num

my $PAGER = '/data/projects/protocol-7/bin/amos-data-pager-56';

sub viewer_start {
    my $cube_socket = shift;
    
    # Fork pager process
    my $pid = fork();
    if ($pid == 0) {
        # Child: exec pager with hyperspace filter
        exec($PAGER, '--hyperspace-mode', '--cube=' . $cube_socket);
    }
    
    return $pid;
}
```

### Phase 2: Zenka Integration
**Configuration**: `cfg/zenki/console/zenka.v7`

```
access.cmd.usr.cube = connect visualize navigate dial

modules.load = auth net protocol io.unix console
[load_modules]

[zenka.loop]  # Interactive terminal loop
```

### Phase 3: Keyboard Mapping
**Module**: `console.input.keymap`

Maps existing pager keys + new hyperspace navigation:
- Reuses `bin/amos-data-pager-56` key handling
- Adds 3D navigation layer

---

## Usage Examples

```bash
# Start console zenka
p7c v7.start console

# Connect to data stream
p7c "console.connect data.hyperspace"

# Visualize 56-bit routing matrix
# [7 rows visible, true_int colored]

# Navigate
# ↑/↓ : Move between rows
# ←/→ : Shift bit view
# Space: Dial current address (collect inference)
# Z/z : Ascend/descend tree
# Q/q : Quadrant skip

# Example session:
# Row 0: [7VNK3...] ← Base32 address
# Row 1: [0101010.] ← Even/odd parity
# Row 2: [+++++..] ← Threshold accum (+5 reached!)
# ...
# Space pressed on row 0 "7"
# Status: "Quadrant 7: 23 nodes, heatmap [▓▓░░▓▓]"
# Space pressed on "V"  
# Status: "Sub-quad V: patterns [harmonic]"
# ...
```

---

## Relationship to Existing Infrastructure

| Component | Role in Console Zenka |
|-----------|----------------------|
| `amos-data-pager-56` | Core visualization engine |
| `data.channel.hyperspace` | 56-bit packet source |
| `graphics-matrix.visual` | Spatial addressing backend |
| `cube` | Event subscription target |
| `decoder.zenka` | Stream protocol handler |

---

## Harmonic Coloring (true_int)

```perl
# From bin/amos-data-pager-56:
my $color = $FNC{'true_int'}->($num) ? $C{'T'} : $C{'0'};

# In context:
# C{'T'} = Cyan/Harmonic = Valid routing path
# C{'0'} = Dark Blue/Void = Quiet/undecided

# Visual effect: True paths glow, false paths fade
```

---

*Design captured: 2026-03-25*  
*Leverages: bin/amos-data-pager-56*  
*Integration: cube, data, decoder zenki*

---
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

#,,,.,,..,.,,,...,..,,.,,,...,,.,,,.,,.,.,,,,,..,,...,...,.,.,...,..,,,,.,,..,
#UZS74E7J5QQX3BL2YXQXWDU2MTG2WIDCJ5M6DT44HCV5S4BTXNCMUY74AM3H6J4J444CD24YGKUHU
#\\\|6LQR4KCPV3V6LGQX3UFTHOE5N5I4Y7XIENEWWXKHV7J3LEQND5O \ / AMOS7 \ YOURUM ::
#\[7]VHJ5VGBJQTIK7CLTCRCIG4A3SBZJSCLOBNQSFA5GGMQWUESUJIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
