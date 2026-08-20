# Decoder + VTERM Layer Architecture

## Status

Design / Implementation Ready — decoder and zulum zenki stubbed, Term::VTerm v0.08 installed

---

## Overview

The `decoder` zenka replaces `bin/atom-delta-term` with a networked, multi-mode stream
renderer backed by shared memory layers. The `zulum` zenka produces correlated harmonic
number streams. Both connect to `cube-13` — the harmonic routing layer — using a
publish/subscribe stream architecture.

---

## Decoder Zenka — Selectable Mode Spec

A number stream can be simultaneously interpreted as multiple parallel channels. The
decoder renders each as a separate VTERM layer rather than choosing one interpretation:

| mode       | description                                                        |
|------------|--------------------------------------------------------------------|
| `printable` | character codepoints via asc-enc table selection (`-C 857` etc.)  |
| `color`     | 5×7 matrix ops + RGB ± adjustments (bit values 48-63)             |
| `control`   | routing opcodes — direction + hop count (bits 00/01 prefix)       |
| `payload`   | BASE32 UTF-7 characters from 010xxxxx bit windows                 |
| `harmonic`  | truth coloring per value via `true_int` — harmonic spike overlay  |

These are not mutually exclusive decodings — they are parallel lenses on the same stream.
Each writes to its own VTERM layer. The compositor blends them; positions where multiple
layers agree are cross-channel spikes.

The `bit-desc` tool documents the full decoding table: 6-bit values 0-63 decode as 5×7
matrix positions (0-47) or color operations (48-63). The routing table covers 5-bit
values via `decoded_bits_route`. BASE32 via `decoded_bits_BASE32`.

### VTerm Integration

`Term::VTerm` v0.08 is installed with full surface: Screen, State, Color, Pos, Rect,
LineInfo, GlyphInfo.

```perl
## decoder.vterm module pattern ##

use Term::VTerm;
use Term::VTerm::Screen;

my $vt  = Term::VTerm->new( rows => $rows, cols => $cols );
my $scr = $vt->obtain_screen;
$scr->set_damage_merge( VTERM_DAMAGE_SCROLL );

## feed decoded number stream as bytes ##
$vt->input_write( $decoded_bytes );

## read cell buffer → write to SHM layer (damage regions only) ##
## Term::VTerm::State handles cursor + attribute stack separately ##
## for the control-code interpretation layer ##
```

`Term::VTerm::Screen` provides damage tracking — only changed cells need writing to SHM
per frame. `Term::VTerm::State` exposes cursor trajectory independently of screen
rendering, useful for the control layer where cursor movement is its own data channel.

---

## VTERM Layer System — SHM Backing

The data zenka's SHM mounting provides zero-copy layer access between zenki.
All layers are `/dev/shm/p7:M:<pubkey>:<path>` backed, with Ed25519 access control
per path.

### Layer Structure

```
vterm.layer.N.cells      ##  rows × cols × (codepoint + fg_rgb + bg_rgb + attrs)
vterm.layer.N.cursor     ##  Term::VTerm::Pos — current cursor position
vterm.layer.N.meta       ##  source zenka, seed, timestamp, iteration-count
vterm.layer.N.damage     ##  last dirty rect — compositor reads only this region
```

### Bandwidth

At 13 layers, 80×24 terminal, ~11 bytes per cell:

```
80 × 24 × 11 × 13  ≈  275 KB per frame state
SHM bandwidth       ≈  10+ GB/s
per-frame write     ≈  damage regions only (typically << full frame)
```

The ring buffer (`data.channel.shm.*`) carries only frame-complete notifications and
damage rect coordinates — not the data itself. Consumers read directly from the SHM
cell buffer the decoder wrote into. Zero copy end-to-end.

### Layer Assignment

```
layer 0-12   ←  zulum streams (one per harmonic walk, different seeds)
layer 13     ←  decoder compositor output (weighted blend by iteration count)
layer 14     ←  LLM group annotation overlay (correlation rules, flagged spikes)
layer 15     ←  pattern memory (stored harmonic signatures for match highlighting)
```

Cryptographic path structure gives access control for free — each zenka writes only to
authorized paths, the compositor reads all layers it has read permission for.

---

## Spiral-Based Buffer Sync Algorithm

Damage tracking enables dynamic relevance focus via spiral traversal rather than
rectangular dirty-rect sync. Priority is encoded as geometry: distance from spiral
center = sync urgency.

### Principle

```
sync order:   center → outward spiral
              ↑
              dynamic origin: weighted toward recent damage rect
```

The spiral origin drifts toward recent VTerm activity (where changes are happening)
and toward high-iteration-count cells (harmonically dense content). Both influences
contribute to origin weighting.

**Progressive rendering**: consumers can composite from whatever spiral depth has been
written — coherence is guaranteed from center outward. Bandwidth-limited channels
always receive the most relevant region first.

**Anti-artifact property**: harmonic weighting means the most harmonically dense cells
are synced first. A slow compositor working outward from center always has the best
available representation at whatever depth it has reached.

### Notification format

The ring buffer notification is three values only:

```
( origin_row, origin_col, radius_written )
```

Consumer reconstructs the full priority map from those. No dirty bitmask, no rect list.

### Scroll handling

`Term::VTerm::Screen::set_damage_merge(VTERM_DAMAGE_SCROLL)` reports scroll events
separately. Scroll damage = shift the spiral origin by the scroll delta, preserving
center-relative priority across scroll events.

### Mod-13 step geometry

The spiral step function can use the mod-13 lookup table to determine cell visit order,
creating harmonically-structured traversal: cells at harmonically aligned distances from
center share sync priority, grouping related content into the same sync wave.

---

## Zulum-13 Stream Architecture

The `zulum` zenka produces 13 correlated division-by-13 walks simultaneously, each with
a different seed or offset. `Math::BigFloat` is already loaded in `zulum.init_code`.

### Purpose

Where streams cross-validate harmonically at the same step — both hitting TRUE at the
same iteration — is a synchronization point. These synchronization points are:

- **Natural routing nodes** for cube-13 topology decisions
- **Strong harmonic spikes** for the LLM annotation layer
- **Compositor blend anchors** for the VTERM layer system

### Cube-13 routing

The routing opcodes already embedded in division-13-table output (bits 42-48: direction
+ hop count) are the native language for stream-derived topology. Zulum-13 generates 13
parallel streams whose routing opcodes, when cross-validated, produce a harmonically
consistent network topology.

### Stream commands

Both `decoder` and `zulum` expose `stream-add`, `stream-remove`, `stream-attach` via
`cube-13`. The decoder subscribes to zulum streams and renders them; the LLM group
subscribes to the same streams for autonomous pattern detection.

---

## Mod-7 and Mod-13 Lookup Table Optimization

The existing `bin/atom-delta-term` and `bin/harmony` tools use `Math::BigFloat` division
for harmonic assertion. For the inner loop of the decoder and zulum, this is replaceable
with a modulo + table lookup:

### Mod-13 table

```
remainder  pattern    state
0          000000     exact multiple
1          076923
2          153846
3          230769
4          307692
5          384615
6          461538     TRUE  ← CUBE
7          538461
8          615384
9          692307
10         769230     FALSE ← PYRAMID
11         846153
12         923076
```

`is_true($n)` → `$n % 13` → lookup → check if pattern is `461538`. No BigFloat.

### Mod-7 table

```
remainder  pattern
0          000000
1          142857
2          285714
3          428571
4          571428
5          714285
6          857142
```

### Mirrored symmetry

Tracking the column position of digit `1` in both tables reveals a precise structural
relationship. Reading through the 6 rows that contain `1`:

```
table 7:   col positions  0  4  5  2  1  3
table 13:  col positions  0  4  2  5  1  3
```

First pair identical (0, 4), last pair identical (1, 3). **Center pair is exactly
swapped**: table 7 has (5, 2) where table 13 has (2, 5). The two cyclic groups cross
each other at the midpoint of the 6-step run. This structural mirror is a natural
joint-distribution feature for the combined mod-7 / mod-13 lookup.

### Joint optimization

For simultaneous mod-7 and mod-13 assertion: `$n % 7` and `$n % 13` from the same value.
Input ranges producing simultaneous harmonic alignment in both tables are double-harmonic
candidates — the strongest spikes in the parallel-assertions framework.

---

## Implementation References

- `modules/decoder.zenka.init_code` — stub, ready for implementation
- `modules/zulum.init_code` — stub with `Math::BigFloat` loaded
- `cfg/zenki/decoder/start` — connects to cube-13 + cube
- `cfg/zenki/zulum/start` — connects to cube-13 + cube
- `bin/atom-delta-term` — reference implementation for stream rendering
- `bin/dev/division-13-table` — reference for harmonic walk + protocol decode
- `bin/amos-data-pager-56` — reference for `AMOS7::INLINE` true_int coloring
- `Term::VTerm` v0.08 — installed, full surface available

#,,,.,,,,,.,,,,..,..,,,,,,,,.,,.,,..,,,,.,,..,..,,...,...,,,,,,,,,,..,,.,,..,,
#3MD5VAFEBFDUNZTDBTP5R6GY4OX33CBQBDVFM2JODAVMCO5SOJZLWPUPDYQDPZDKPYQZ4KIIJO3CC
#\\\|VQF6I245FKGLLL3VJV7TOCS6BA7LGURYE7SDT7CQOZUTDDC27GZ \ / AMOS7 \ YOURUM ::
#\[7]DG4QN7Y24IHZ5M5UTBEANMLXUQDMZYSMQ7BH5HEKDUXX7YLXEQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
