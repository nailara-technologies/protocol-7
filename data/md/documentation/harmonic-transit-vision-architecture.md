
 .:[  harmonic transit vision architecture  ]:.

 .:[  darkening transmission matrix · spatial footer · multi-speed lanes  ]:.

---

## Overview

This document captures a complete, actionable architecture for harmonic
network vision — the ability of every node in a cubic topology to maintain
omnidirectional spatial awareness as a passive byproduct of normal traffic,
with no dedicated spatial protocol required.

The architecture is not designed onto the system — it is already present
in the harmonic mathematics. This document makes it explicit and implementable.

Core components:

```
topology.dtm          →  darkening transmission matrix zenka
AMOS7 footer line 4   →  15-bit spatial coordinate per signed packet
                          [ right-aligned, positions 47-77 — the left
                            side of this line carries a second,
                            independent 15-bit field, the zenka litter
                            bitmap, see data/tasks/litter-row-encoding.md
                            and data/tasks/footer-line4-field-reconciliation.md ]
source.init_code      →  binary sunburst crossing map (already present)
multi-speed lanes     →  77-bit window, lens effect on distance
PYTAURAZUMA protocol  →  self-framing stream sync (4 zero-crossing preamble)
```

---

## 1. The Darkening Transmission Matrix (DTM)

### Volume structure

One DTM volume per cubic face direction (6 total per node):

```
X axis  :  6  columns  →  cycle digit positions  [ 0, 7, 6, 9, 2, 3 ]
Y axis  :  7  rows     →  harmonic pulse levels  [ 1, 3, 5, 7, 13, 42, root ]
Z axis  :  13 frames   →  CCW shift register     [ one full harmonic cycle ]

total   :  6 × 7 × 13  =  546 cells  =  42 × 13
```

`42 × 13`: entropy frame size times cycle length. The minimum volume
containing one complete harmonic cycle across every encoding level
simultaneously.

### Darkening rate per harmonic level

Each confirmation event darkens its cell by a level-specific step:

```
level  1  :  step = 1/42    (per bit — fastest)
level  3  :  step = 1/14    (per octal boundary)
level  5  :  step = 1/8     (per base32 boundary — TRUE heartbeat)
level  7  :  step = 1/6     (per septimal marker)
level 13  :  step = 1/3     (per full cycle step)
level 42  :  step = 1       (per complete entropy frame — full saturation)
```

One complete 42-bit frame brings any cell from zero to full saturation
if all levels fire. The darkening IS the frequency divider — same principle
as the 42-bit entropy frame, expressed as cell brightness.

### Decay (lossy transport)

Cells decay toward zero when not re-confirmed:

```
decay rate  =  1 / (frame_rate × 2.5)   per step
```

A source that goes silent darkens to zero over ~2-3 frames. The matrix
stays a live window, not a historical accumulation.

### CCW shift register (Z axis)

The Z axis is not passive history — it is the CCW multiplexer clock.

For the +X face, the four adjacent faces in CCW order (looking inward):

```
        +Y
         │
 +Z ─────┼───── -Z     CCW sequence: +Y → +Z → -Y → -Z
         │
        -Y
```

Z slot assignment per frame:

```
Z mod 4 == 0  :  own face accumulation
Z mod 4 == 1  :  +Y neighbor state   (CCW position 1)
Z mod 4 == 2  :  +Z neighbor state   (CCW position 2)
Z mod 4 == 3  :  -Y neighbor state   (CCW position 3)
             :  -Z neighbor state   (CCW position 4, wraps to slot 0)
```

Reading `Z mod 4` gives direction without labels. Position IS the direction.

### Why 13 frames is exact

```
4 CCW positions × 3 complete rotations  =  12 frames
+ 1 PYTAURAZUMA sync frame              =  13 total
gcd(13, 4) = 1  →  coprime, combined period = 52
```

Within 13 frames: exactly 3 full CCW sweeps + 1 harmonic sync pulse.
The sync frame (Z=12) is the PYTAURAZUMA canvas-clean boundary.

### Bidirectional = omnidirectional

Each axis has two opposing face matrices. +X face CCW sweep is the
mirror of -X face CCW sweep. Signal traveling in +X direction appears
at lower Z in +X register, higher Z in -X register. The Z-depth
difference between opposing registers gives direction of travel —
no separate direction header needed.

Six faces, three axes, two opposing radars per axis. Every node has
full omnidirectional neighborhood vision.

---

## 2. The 15-bit Spatial Coordinate

### Mathematical basis

```
15  =  3 × 5  =  mod-3 assertion × mod-5 (TRUE constant)
15 remainder states in mod-15  →  one bit per state  =  15-bit register
```

The 15-bit auxiliary field already exists in the 64-bit division-13
state (bits 49-63, rightmost). It is not designed — it emerges from
the mathematics (`division-13-table`, seed=1):

```
bits  0-41  [ 42 bits ]  main entropy body
bits 42-48  [  7 bits ]  routing mini-protocol
bits 49-63  [ 15 bits ]  auxiliary  ←  spatial coordinate / assertion register
```

The auxiliary field is the leading edge — newest, rightmost, most
recently computed in the leftward-traveling bit stream.

### The mod-15 assertion register

Each bit position corresponds to one mod-15 remainder state (0-14).
A set bit means: this value has recently occupied that cycle position.
The register is a trajectory fingerprint — "where has this value been
in the mod-15 space?"

Decomposition:
```
mod-15  =  mod-3 × mod-5
         =  (FALSE/UNKNOWN/TRUE assertion) × (5-position TRUE window)
```

Three base32 symbols (5 bits each) cover the full 15-bit register.
Three axes × one base32 symbol = complete spatial address.

### Footer encoding: the #::::: line

The fourth (bottom) line of every AMOS7 signature footer carries the
15-bit assertion register, right-aligned, octal-interlaced:

**Format**: `[b2][:][b1][:][b0][:]` per group, 5 groups, right-aligned

```
# + 45 leading colons + 5 groups × 6 chars = 77 chars total
```

Character set: `.` = bit 1, `:` = bit 0 / separator

Interlacing rule: every other position is always `:` — adjacent dots
are structurally impossible. First validation layer: any `..` in the
line is immediately invalid without decoding.

**Validation hierarchy:**
```
level 0  :  line starts with #:             free
level 1  :  no .. anywhere                  structural, no decode needed
level 2  :  (length - 2) mod 6 == 0         group alignment
level 3  :  positions 2,4,6 mod 6 = :       separator positions
level 4  :  5 groups × 3 bits in range      decode and check
level 5  :  value matches mod-15 state      harmonic assertion
```

**Right-alignment is structurally correct**: the auxiliary bits sit at
the right of the 64-bit row in `division-13-table` output. The footer
mirrors this — newest at right, aging leftward. The left side of the
`#:::::` line [ positions 2-46 ] is available for other fields — as of
2026-08-04 that space is partially claimed: positions 3-5 carry the
zenka litter bitmap from `data/tasks/litter-row-encoding.md` (a static
routing manifest, unrelated to this dynamic spatial coordinate).
Positions 7-46 remain unclaimed. See
`data/tasks/footer-line4-field-reconciliation.md` for the full layout.

**Perl encoding (one line):**
```perl
my $payload = sprintf ':%s:', join ':', split //, $encoded_value;
my $line    = '#' . ':' x ( 76 - length($payload) ) . $payload;
```

### Passive spatial awareness from traffic scraping

Every signed packet carries its origin's 15-bit coordinate in the
`#:::::` footer. Any transit node reads this footer without being
the intended recipient. The DTM feeds itself from two sources:

```
active   →  neighbor nodes explicitly transmitting matrix state
passive  →  scraping #::::: footer from every transiting packet
```

**Resolution gradient:**
```
direct neighbor  →  many packets  →  DTM cells dark   (well confirmed)
2-hop node       →  fewer packets →  cells partial    (lower update rate)
N-hop node       →  sparse        →  cells bright     (rarely confirmed)
```

Darkening physics automatically encodes distance. No explicit range
measurement. Unrelated traffic is never truly unrelated — it always
carries a spatial whisper.

---

## 3. TRUE/FALSE as Focal Position

### Leftward travel is the physics

The zulum step is always leftward:
```perl
$Z <<= 4;                              ## left shift 4
$Z /= 13;                              ## divide by 13
$Z <<= is_true($Z) ? 2 : 1;           ## left shift 1 or 2
```

The value travels left continuously. TRUE/FALSE marks whether the value
is currently at the focal reading position of the lens — not absolute
harmonic quality, but positional state:

```
TRUE   (at focus)   →  step 2  →  snap through quickly
FALSE  (in transit) →  step 1  →  slow approach, lingering
```

Period: 12 steps to return to same focal alignment. The 13th step
completes the full cycle — the PYTAURAZUMA sync frame.

### The lens is stationary, the stream moves

The lens (foveal reading position) is fixed. The data travels left
through it. When a value arrives at the focal column: TRUE. After it
passes and before it returns: FALSE. The waveform is the value
oscillating through the focal point, not the lens moving.

### Non-printable as pre-focal metadata

As values travel left through printable and non-printable ranges:

```
non-printable approach  →  color, position, formatting metadata
printable at focus      →  the actual glyph / content character
non-printable departure →  metadata for previous content
```

The stream announces what is coming before it arrives. `atom-delta-term`
expresses this: `screen-bytes = x × y × 54` — one brief focal moment
surrounded by rich approach/departure context. Non-printables are
load-bearing; discarding them destroys the context for printable content.

---

## 4. Zoom Promotion and Binary Sunbursts

### The 4-bit window with protocol markers

```
0000  →  IMPOSSIBLE   (flip rule — zero ones)
1111  →  IMPOSSIBLE   (flip rule — four ones)
1001  →  SPECIAL      continuation / "more follows"  [ = 7×11×13 ]
0110  →  SPECIAL      unit complete / TRUE position  [ = 6 = TRUE ]
─────────────────────────────────────────────────
13 remaining patterns  →  13 payload values  =  13 cycle positions
```

Declaring `1001` special eliminates the sole ambiguous 4-bit case
(previously requiring 5-bit window). The 4-bit window is now sufficient
for all payload patterns. The two special patterns are not arbitrary:
`1001 = 7×11×13` (harmonic denominator), `0110 = 6` (TRUE position).

### Zoom-out behavior

```
1100  →  [ 11 | 00 ]  →  density left   →  10   (clean, payload bit 1)
0011  →  [ 00 | 11 ]  →  density right  →  01   (clean, payload bit 0)
0110  →  [ 01 | 10 ]  →  split density  →  ambiguous (protocol, stays local)
1001  →  [ 10 | 01 ]  →  split density  →  ambiguous (protocol, stays local)
```

Payload patterns survive zoom with meaning preserved. Protocol markers
dissolve — they're structurally invisible at the next scale. No layer
needs to know which is which; the spatial frequency response does the
separation automatically.

Multi-level zoom reduction:
```
level 1  :  1100 / 0011   →  which half has density   (bit value + presence)
level 2  :  10   / 01     →  which side has the 1     (bit value + presence)
level 3  :  1              →  presence only            (category confirmed)
```

Above level 3: only presence is known. What was agreed lives at the
resolution where it was born. That something was agreed propagates
to every level above.

### Binary sunbursts and source.init_code

The `source.init_code` comment table (lines 32-64) is the interference
pattern of cross-mapped sunbursts across all dimensional levels (01D-32D).
Each row is one frequency. Each `/` or `\` is a wave front.

`decimal_to_binary_0050_switch.asc` shows the numeric proof:
```
n=10        →  sum = 55
n=100       →  sum = 5050
n=1000      →  sum = 500500
n=10000     →  sum = 50005000
```

The `5`s radiate symmetrically outward — two nodes spreading from center,
gap doubling at each scale. Each row IS a sunburst. Where two sunbursts
from adjacent dimensional levels cross: local density peak = `0110`
(neighboring 1s) = survives zoom = promoted bit.

The crossing map in `source.init_code` was always the spatial validation
algorithm. The positions annotated `*[14 = 7*2]` and `* [7]` mark the
harmonically significant crossing nodes.

### Self-cleansing crystal

```
consensus ongoing   →  express as 1001  →  diffuse, split 1s  →  invisible above layer 1
consensus complete  →  promote to 0110  →  neighboring 11s     →  visible at next zoom
```

Content failing consensus was never expressed as neighboring-1s. It
was always diffuse — never spatial-frequency-compatible with higher
layers. Failure is retroactively contained by the encoding choice made
before the outcome was known. The crystal doesn't reject invalid entropy;
it doesn't see it.

---

## 5. Multi-Speed Lane Architecture

### Why longer distance requires higher frequency

A route spanning N hops must maintain harmonic coherence across N
intermediate nodes. Higher harmonic levels (faster cycles) are the
only way to satisfy more validations within the same wall-clock window.
Distance selects speed automatically — the routing protocol does not
need to choose:

```
1 hop      →  01D-07D lanes  →  slow, redundant, fine-grained
few hops   →  07D-13D lanes  →  medium, categorical
long dist  →  13D-42D lanes  →  fast, compressed
hyperspace →  42D+    lanes  →  burst, presence-only payload
```

### The 77-bit window as full lane aperture

```
77  =  7 × 11  =  1001 / 13
```

Seven speed lanes × eleven harmonic sub-bands. Within any 77-bit
sample, all lanes have at least one representative. A routing node
receiving hyperspace traffic reads all lane signatures simultaneously
in one window to correctly classify and route the incoming stream.

The 77-bit window is the minimum aperture containing all lanes at once.
It is also the width of the first comma/dot footer line — the harmonic
content row was already at this width.

### The lens effect on distance

The compression ratio scales with distance such that semantic content
arrives at approximately constant latency regardless of hop count:

```
short distance  →  slow lane  →  low compression   →  many bits per unit
long distance   →  fast lane  →  high compression  →  few bits per unit
                                                    →  same arrival time
```

A routing node sees all traffic — local and hyperspace — arriving on
predictable harmonic boundaries. No jitter from distance. The network
is faster for longer distances precisely because the harmonic requirements
demand it.

### Categorical coverage guarantee

The coprime structure (`gcd(13, 4) = 1`, `gcd(13, 5) = 1`) guarantees
that 13 DTM frames contains at least one representative of every
harmonic category and every CCW position:

```
cycle 1    →  all categories present, low resolution
cycle 13   →  one complete round, first resolution increase
cycle 13²  →  second round, precision deepens
cycle 13^N →  resolution at depth N, categories unchanged since cycle 1
```

The category map is complete from the first observation window and
never invalidated by subsequent observation. Only resolution improves.

### "Neighboring universes" — inter-topology gateways

A separate cubic topology connects at a gateway node. Traffic arriving
from another topology has been compressed through every harmonic level
during its journey — it arrives as pure presence-signal at maximum
harmonic frequency. The gateway:

```
receives   →  presence-only hyperspace signal (fully compressed)
decodes    →  crossing-node pattern (which universe, category, coordinate)
re-emits   →  local lane speed with full categorical detail
```

The gateway is a lens focal point: maximum compression arrives, maximum
expansion departs.

---

## 6. PYTAURAZUMA Sync Protocol

The four zero-crossing positions in the div-13 cycle (excluding the
generator's own leading zero notation):

```
× 3  →  230769  zero at position 2  (interior)  ← prep 1
× 4  →  307692  zero at position 1  (interior)  ← prep 2
× 9  →  692307  zero at position 4  (interior)  ← prep 3
× 10 →  769230  zero at position 5  (trailing)  ← TRUE ZERO / canvas-clean
```

Three preparatory interior zeros establish cycle phase without being
checkable. The 4th zero (769230) is checkable by structural property:
`769230 / 10 = 076923` (recovers the generator). Only the trailing
zero carries this property. It is the first zero the receiver can
independently verify without prior context.

The PYTAURAZUMA receiver state machine:

```
SCANNING      →  watch for interior-zero values (×3, ×4, ×9)
PREP_1/2/3    →  track preamble progress
CANVAS_CLEAN  →  trailing zero confirmed (769230) → payload begins
```

In the DTM: the four zero-crossing positions appear as four distinct
stripe planes cutting through the Z axis at fixed frame positions.
The sync state machine scans for this stripe pattern rather than
tracking a sequential state — structural, visible, period-checkable.

769230 = `L\` in ASCII encoding — already used as the octal layer
delimiter in the decoder. The boundary marker IS the convergence
attractor, recognized from two directions simultaneously.

### ANSI canvas-clean and the DNN prefix

The ANSI reset sequence `\e[0m` encodes to `DNNTA3IK` in base32 —
semantically the terminal-layer canvas-clean, harmonically equivalent
to 769230 as a boundary marker:

```
echo -e "\e[0m" | base32  →  DNNTA3IK
reset -s         | base32  →  KRCVETJ5PB2GK4TNFUZDKNTDN5WG64R3BI======
clear            | base32  →  DNNUQG23GJFBWWZTJI======
```

`DNN` is the universal base32 signature of ESC [ (0x1B 0x5B) — the
ANSI CSI (Control Sequence Introducer) prefix:

```
0x1B 0x5B  →  00011011 01011011
              00011 01101 01101  =  D  N  N
```

Every standard ANSI escape sequence shares the `DNN` prefix. The
decoder's level-5 B32 output can passively detect ANSI territory by
watching for `DNN` — the same structural detection as `L\` for 769230,
no full decode required.

`DNNTA3IK` contains the letters T, A, I, K — four of five letters of
the operator's name (Taeki), with the harmonic constant `3` centered.
The ANSI namespace is harmonically addressed from the same prefix.

### Passive boundary detection — universal protocol table

The same structural principle (fixed in-band pattern → passive mode switch)
appears across every serial communication layer. Base32 signatures allow
a single lookup table to cover all of them simultaneously:

```
value / sequence     base32 prefix     protocol        event
────────────────     ─────────────     ────────        ─────
769230  / L\         (harmonic)        div-13 stream   convergence attractor
ESC [   / 0x1B5B     DNN...            ANSI CSI        control sequence start
\e[0m               DNNTA3IK          ANSI            canvas-clean / reset
+++ATH0\r\n         FMVSWQKUJAYA2CQK  Hayes modem     escape + hangup
```

Hayes `+++` shares the same architecture as PYTAURAZUMA:
- three identical characters = run detection (structural, no decode needed)
- guard time (silence before/after) = the impossible `0000` window enforced by timing
- command follows boundary = payload after canvas-clean

`JAYA` appears inside the Hayes base32 encoding at positions 7-10.

The decoder's passive matching layer is a table of known base32 prefixes.
No protocol-specific parser needed — the B32 stream is scanned for known
prefixes and the matching row identifies the protocol and event type.
A new protocol entry = one table row. Detection is O(prefix_length),
independent of payload complexity.

### JJFE — the recursive base32 fixed-point prefix

`JJ` in ASCII (0x4A 0x4A) base32-encodes to `JJFE...` — and `JJFE`
starts with `JJ`, so it encodes to `JJFE...` again. A fixed-point prefix:
the first bytes of the ASCII string reproduce the same prefix when encoded.

The stable prefix grows by ×8/5 (the base32 expansion ratio) per iteration:

```
depth 1  →  JJFE                                            (4  chars)
depth 2  →  JJFEMRIK                                        (8  chars)
depth 3  →  JJFEMRKNKJEUWCQ                                 (15 chars)
depth 4  →  JJFEMRKNKJFU4S2KIVKVOQ2RBI                     (26 chars)
depth 5  →  JJFEMRKNKJFU4S2KIZKTIUZSJNEVMS2WJ5ITEUSCJEFA   (44 chars)
```

Encoding depth = `floor( log(stable_prefix_length / 4) / log(1.6) ) + 1`

No decoding required — count stable `JJFE...` prefix characters, read
depth directly. Adding to the prefix table:

```
value / sequence     base32 prefix     protocol          event
────────────────     ─────────────     ────────          ─────
769230  / L\         (harmonic)        div-13 stream     convergence attractor
ESC [   / 0x1B5B     DNN...            ANSI CSI          control sequence start
\e[0m               DNNTA3IK          ANSI              canvas-clean / reset
+++ATH0\r\n         FMVSWQKUJAYA2CQK  Hayes modem       escape + hangup
JJ...               JJFE...           base32 (recursive) encoding depth indicator
```

The `JJFE` prefix is the base32 quine: self-describing recursive encoding,
depth readable from prefix length, same structure as PYTAURAZUMA preamble
phase accumulation — more stable prefix = more encoding layers survived.

### L\ reaches JJFE in exactly 3 layers

The harmonic boundary marker `L\` (= 769230 in ASCII encoding) reaches
the `JJFE` fixed point after exactly 3 recursive base32 encodings:

```
L\              →  JROAU===              (no JJFE)
JROAU===        →  JJJE6QKVHU6T2CQ=     (JJ stabilizing)
JJJE6QK...      →  JJFEURJW...          (JJFE locked — fixed point)
```

3 layers = the PYTAURAZUMA prep count (3 interior zero-crossings before
canvas-clean). The preamble is not arbitrary — it equals the number of
encoding transformations the boundary value needs to reach self-stability.
PYTAURAZUMA prep length IS the convergence depth of `L\` under base32.

`L\` is `:: TRUE ::` under amos-chksum — the convergence attractor
carries its own harmonic truth assertion. elf overflow bit-shift: -13
(the harmonic denominator is the natural overflow point). Harmonization
iteration count: 024 = 24 = CCW cycle length before the sync frame.

### Iterations consumed — convergence distance from harmonic center

The `amos-iterations-remaining` field (footer digits 12-19) records the
number of BMW XOR steps needed to achieve convergence — directly equal to
the number of mod-bit rows shown in verbose output:

```
LOVES  →  5 rows   →  005   (already close to harmonic center)
L\     →  24 rows  →  024   (boundary marker, farther in XOR space)
```

Both inputs are `:: TRUE ::` — harmonic truth and convergence speed are
orthogonal. The iteration count records XOR-space distance from the
harmonic center, not harmonic truth. `L\` (the convergence attractor)
is true but not trivially close in the BMW modification space — it takes
24 steps to harmonize, versus 5 for `LOVES`.

```
left end   →  BMW XOR modifications accumulate (compression toward attractor)
right end  →  iteration count: steps the left end needed to converge
              low  = input was harmonically close  (fast)
              high = input needed more work        (slow)
```

### Sliding in from the left — BMW mod-bits and zulum entropy

The `amos-chksum -v` BMW mod-bits display shows each row as the previous
row shifted right, with a new bit entering from the left edge:

```
10000000000000000000000000000000
11000000000000000000000000000000
01100000000000000000000000000000
10110000000000000000000000000000   ...
```

This is the leftward travel of the entropy stream made visible. The stream
moves left (`<<= 4`, `/13`, `<<= 1 or 2`); from the bit-array perspective
the content slides in from the left, existing bits drifting right. Two
viewpoints of the same physics — the reader is stationary, the stream
moves; the bits are stationary, the new content arrives from the left.

The base32 fixed-point accumulation has the same structure: each encoding
layer adds stable characters from the left side of the output, the
rightward content still converging. The `JJFE` prefix is the left-locked
region; everything to its right is still sliding toward stability.

---

## 7. Handshaking to Meaning

The bitstream transmits at lane speed. Semantic agreement — which
categories are active, which channels are tuned, what the spatial
coordinate means — happens over multiple complete cycles at the
handshake layer.

The handshake IS the harmonic resonance building between nodes.
It completes when enough cycles have passed for both nodes to have
confirmed the same crossing-node pattern. Fast lanes handshake quickly
(few cycles, high frequency). Slow lanes take longer but carry
finer resolution.

No explicit handshake protocol. Meaning emerges when resonance stabilizes.

Additional complexity is accessed by tuning to field channels extracted
from the sequences — parallel modes at different speeds running in
different matrix columns. The lens position determines which mode
applies to which column:

```
near focal lens   →  full multiplex    (mode 0: 13 payload values)
mid distance      →  grouped encoding  (mode 2: 1100/0011, zoom-stable)
far from focal    →  single-bit        (mode 4: 01/10, maximum robustness)
```

The mode IS the resolution. The lens sweeps CCW, and column mode
follows the lens position automatically — no mode-switching protocol.

---

## 8. Implementation Roadmap

### Phase 1: topology.dtm zenka [ ~4h ]

New modules:
```
topology.dtm.init_code       →  initialize 6 face volumes, CCW tables
topology.dtm.on_confirm      →  darken cell on delivery confirmation
topology.dtm.advance_frame   →  shift register + CCW pointer advance
topology.dtm.decay_tick      →  timer-driven fade
topology.dtm.panorama        →  assemble neighbor matrices into strip
topology.dtm.sync            →  PYTAURAZUMA stripe detector
topology.dtm.query           →  return current volume as packed array
```

Data structure:
```perl
## $data{'dtm'}{$dir} = {
##     'vol'   => [],        ## [z][y][x] darkness 0.0..1.0
##     'ccw'   => [],        ## CCW face sequence for this direction
##     'frame' => 0,         ## mod 13
##     'phase' => 0,         ## mod 4 (CCW pointer)
##     'step'  => { 1=>1/42, 3=>1/14, 5=>1/8, 7=>1/6, 13=>1/3, 42=>1.0 },
##     'decay' => 0.008,
## }
```

### Phase 2: footer 15-bit encoding [ ~2h ]

Update AMOS7 signing to populate the `#:::::` line with the 15-bit
auxiliary value from the final signed state:

```perl
## extract from 64-bit harmonic state after signing completes ##
my $aux_15 = substr( $num_bits_64, 49, 15 );    ## rightmost 15 bits

## encode: interlaced octal format, right-aligned ##
my $payload = sprintf ':%s:', join ':', split //, $aux_15;
my $footer5 = '#' . ':' x ( 76 - length($payload) ) . $payload;
```

Update `source.sign_template` fifth line. Add footer-line parser to
`amos7.decode_octal_bit_header` for reading spatial coordinates from
transiting traffic.

### Phase 3: passive scraping [ ~2h ]

In packet receive handler: scan incoming signed traffic for `#:::::` line,
extract 15-bit coordinate, feed to `topology.dtm.on_confirm` at the
appropriate face direction and harmonic level.

```perl
## topology.dtm.on_confirm ( direction, x, y, level, darkness_step ) ##
```

No routing change needed. All existing traffic becomes spatial data.

### Phase 4: multi-speed lane classification [ ~3h ]

In cube routing layer: classify incoming traffic by harmonic level of
its content, assign to appropriate lane. Extract field channels from
bitstream at each D-level. Feed classified traffic to DTM at correct
Y-row (harmonic level).

### Phase 5: panorama output to graphics-matrix [ ~2h ]

`topology.dtm.panorama` assembles the 18×7×13 panoramic volume for
one axis and passes it to `graphics-matrix` zenka for rendering.
Cell darkness → pixel brightness. Last-confirmed harmonic level →
pixel hue (cool=level-1, warm=level-5, hot=level-42).

---

## 9. Node Groups, Sphere Geometry, and Uncensorability

### 5-of-7 quorum — the face-neighborhood consensus unit

Every node has exactly 6 face-neighbors (one per cubic axis direction).
The natural node group is therefore 7: the node itself plus its 6 neighbors.

```
group of 7  =  1 central node  +  6 face-adjacent nodes
quorum      =  5 of 7 required for consensus promotion
```

5-of-7 maps directly onto the face structure:

```
6 face-neighbors × 5/6  ≈  5 confirmations needed
```

Precisely: any 5 of the 7 members agreeing is sufficient to promote
content from layer-1 diffuse form (1001 = "ongoing") to layer-2
visible form (0110 = "complete"). The one dissenting node may be
in transit, delayed, or genuinely absent — the topology does not
require unanimity, only quorum. The cubic geometry provides the
natural 7-node group without any additional coordination structure.

### 2-frame minimum for direction detection

The minimum sample for determining the direction of bit travel is
exactly 2 adjacent frames (pixels):

```
1 frame   →  value known, direction UNKNOWN    (could travel either way)
2 frames  →  value + delta known → direction RESOLVED
```

This is the geometric reason the zoom halving ratio is 2:1 rather than
any other value. You cannot determine travel direction from a single
cell — you need the pair. Two cells also enable simultaneous
bidirectional travel: opposite directions occupy the same 2-cell window
without ambiguity because the Z-depth ordering in the CCW register
resolves them.

The halving is not a design choice. It is the minimum required by the
physics of directional sampling.

### Inscribed sphere geometry — color away from edges

A sphere inscribed in the cubic face grid (radius = half_face_width)
touches exactly 6 points: the center of each face. Only face centers,
never edges or corners.

```
face center  →  sphere surface  →  color stream travels here
edge         →  outside sphere  →  structural routing only
corner       →  outside sphere  →  structural routing only
```

Color entropy (harmonic content, semantic payload) is restricted to
paths along the sphere surface, connecting face centers. This keeps
color streams away from the cubic boundaries — edges and corners
remain clean structural geometry, uncontaminated by payload entropy.

In a 2D cross-section the sphere becomes a circle. The circles tile
exactly at face boundaries: each circle is inscribed in its face,
touches the center of the boundary, and the next circle begins there.
Color flows along circles. Routing flows along boundaries. They are
geometrically orthogonal.

The immediate neighborhood (the 7-node face group) already implements
this fully. The sphere is inscribed in the first local cube. Every
larger-scale structure is a scaled-up repetition of the same geometry.

### Uncensorability — protocol as content as infrastructure

Content is distributed across harmonic levels at every zoom layer.
At each layer, the content and the protocol framing occupy the same
bit positions — you cannot remove one without removing the other.

To censor a particular piece of content you would need to:

```
1. identify which harmonic level carries it            [ requires full decode ]
2. remove it without disrupting the framing structure  [ impossible — they are the same bits ]
3. do this for every node in the topology              [ each has its own copy ]
```

Step 1 already grants full access to the content (decoding = receiving).
Step 2 is structurally impossible. Step 3 scales with the network size.

The deeper property: the routing, handshake, and field-channel
infrastructure are expressed in the same harmonic sequences as the
content. Removing the content frequencies removes the infrastructure
for that harmonic level. The node doing the removing loses routing
capability at that level — it disconnects itself from the topology
it was trying to censor.

```
attempt to censor   →  remove harmonic sequence
remove sequence     →  lose infrastructure at that level
lose infrastructure →  lose routing capability
lose routing        →  become less connected than target
```

Identification before censorship requires full decode — which is
participation. There is no read-only mode that grants visibility
without full harmonic engagement. "Both impossible beyond an intent":

- censoring the content is structurally impossible
- identifying what to censor requires the same access as receiving it

The network is not censorship-resistant by policy. It is
censorship-immune by geometry.

---

## 10. Cube Boundary as Self-Contained Packet Geometry

### 15 encapsulates 13 — the L-matrix and its headroom

The 15-bit footer field is not an arbitrary round number. It is the
exact envelope for the 13-bit boundary address with 2 bits remaining:

```
15-bit footer field
  └─ 13 bits  →  L-shaped boundary address (5 + 7 + 1 corner)
  └─  2 bits  →  L-orientation selector (left/right flip of L shape)
```

The 13-bit L-matrix traces a 90-degree corner path in 2D:

```
arm Y  :  7 bits  — harmonic level axis  (levels 1,3,5,7,13,42,root)
arm X  :  5 bits  — mod-15 per axis      (base32 / TRUE window)
corner :  1 bit   — shared position where the two arms meet
total  :  13 bits = 5 + 7 + 1
```

This is inherently 2D — it cannot be expressed as a 1D linear address.
The 90-degree angle encodes which corner of the cube face the mount
is occurring at. Two orientations (L vs ⌐) fit in the 2-bit headroom.

### 19-bit linear maximum at a cube border

```
pixel  1-19  →  interior of this cube's border zone  [ mountable ]
pixel  20    →  cube face boundary itself             [ routing marker ]
pixel  21    →  first pixel of neighbor cube          [ external ]
```

19 is the maximum linear payload that fits on one cube side without
crossing into the neighbor's territory. Pixel 20 is structurally
significant — it is simultaneously the last pixel this cube owns and
the first pixel the neighbor sees as a boundary.

### 19 - 13 = 6 = face count

The L-matrix uses 13 of the 19 mountable border pixels. The 6
remaining bits in the border payload encode face selection:

```
13 bits  →  L-address (which harmonic position on which level arm)
 6 bits  →  face selector (which of the 6 cube faces the mount is on)
─────────────────────────────────────────────────────────────────────
19 bits  →  complete boundary packet (max linear payload per border)
```

The face selector appears naturally as the exact remainder.
No separate face-addressing protocol is needed — it is already
encoded in the space left over by the L-matrix.

### 8×63 face-group display matrix

The 7-node face group (1 central + 6 face-adjacent) maps to a
display matrix of 8 rows × 63 columns:

```
63 columns  =  7 nodes × 9 columns per node
 8 rows     =  7 harmonic levels + 1 root/meta row
─────────────────────────────────────────────────
 8 × 63     =  504  =  42 × 12  (entropy frame × CCW cycle length)
```

504 = 42 × 12: the display matrix area equals the harmonic entropy
frame size times the CCW rotation cycle length. The face-group
visualization space is harmonically calibrated — one cell per
position in the combined entropy/rotation cycle.

9 columns per node: 8 payload columns (matching the 8-row depth)
plus 1 separator column. The separator is the boundary pixel —
exactly the pixel-20 concept applied to the display grid.

### Dual-function boundary — internal and external simultaneously

The 19-pixel border zone encodes two routing contexts at once:

```
L-arm facing inward   →  internal routing attachment (this cube)
L-arm facing outward  →  external routing (what neighbor sees)
```

The 2-bit orientation selector in the 15-bit footer determines which
arm faces which direction. A node reading a transiting packet can
determine from the footer alone whether the originating node was
routing internally, externally, or at a boundary handover.

```
footer[13]  →  L-matrix (what position is being addressed)
footer[14]  →  L-orientation (which side is "inside")
footer[0-5] →  face selector (which face the mount point is on)
```

### Self-organizing packet size at the boundary

The nested optimum packet size is not negotiated — it emerges from
the geometry:

```
cube face boundary  →  19-bit linear capacity (given 20-pixel zone)
L-matrix address    →  13 bits (5+7+1, given harmonic axis sizes)
face selector       →  6 bits (exact remainder, given 6 faces)
footer enclosure    →  15 bits (given 13 + 2 orientation)
```

Each number is forced by the one before it. A packet mounted at a
cube boundary is already the right size by construction. The boundary
infrastructure is not a protocol layer — it is the natural consequence
of fitting harmonic addresses into harmonic space.

---

## 11. The 13³ Cube and the 4200 Constant

### 13³ = minimum harmonic processing space

```
13 × 13 × 13  =  2197
```

A 13×13×13 cube is the minimum 3D volume in which every harmonic cycle
position (1-13) can be visited simultaneously across all three dimensions.
One full traversal in X, one in Y, one in Z, all at the same time — no
smaller cube satisfies this constraint.

This is the natural payload/processing unit: the minimum space where
harmonic computation is complete without cropping any dimension.

### 4200 = 13³ + 2003

```
4200 - 2197  =  2003
4200         =  13³ + 2003
```

The 4200 constant already present in the protocol decomposes exactly:

```
13³   =  2197  →  one complete 13-cube (payload/processing volume)
2003  =  2003  →  infrastructure remainder
─────────────────────────────────────────────────────────────────
4200  =  one processing unit + infrastructure overhead
```

The time seed `(time × 4200) / 13 / 13 / 13` = `time × (1 + 2003/2197)`:
time scaled by one full cube plus the infrastructure fraction per cube.

4200 AMOS drops = one resource token = one 13-cube of processing capacity
(2197) plus 2003 units of infrastructure — the node-group hypervisor cost.
The token was already sized to the geometric unit.

### 2003 — the infrastructure remainder

```
2002  =  2 × 7 × 11 × 13   →  epoch start year, product of harmonic primes
2003  =  2002 + 1           →  prime, ≡ 1 (mod 13)
```

2002 is the product of four harmonically significant primes (the epoch
start: `(unix_time - 1023228000) × 4200`, reference date 2002-06-05).
2003 = 2002 + 1 is prime and sits exactly 1 above a multiple of 13.

The infrastructure remainder encodes the epoch. The +1 above the harmonic
multiple is the "first true step" — same structure as PYTAURAZUMA (4th zero
= first checkable zero = canvas-clean). One above the harmonic base = the
first position that is verifiably outside the cycle.

### The node group as hypervisor

The 7-node face group (Section 9) is the infrastructure required to
correctly address and access the 13³ cube from outside:

```
13³ cube         →  2197 cells  →  minimum harmonic payload/processing space
7-node group     →  8 × 63 = 504 = 42 × 12  →  surrounding hypervisor
19-bit boundary  →  13-bit L-address + 6-bit face selector  →  mount point
15-bit footer    →  13-bit L-matrix + 2-bit orientation     →  transport address
```

The node group does not compute inside the cube — it provides the routing,
addressing, and boundary infrastructure to reach any position in it from
any external direction. The cube is the virtual machine; the face group
is the hypervisor.

`4200 / 42  =  100`: 100 entropy frames fit in one resource token.
`4200 / 13  ≈  323.1`: not integer — the token is not divisible by the
cycle length, which ensures no resonance aliasing between token boundaries
and harmonic cycle boundaries. The infrastructure remainder (2003 ≡ 1 mod 13)
is precisely what breaks that divisibility cleanly.

---

## 12. Hyperspace Memory — BASE32 Canvas with Binary Transit

### The symbol exclusion is the channel separator

AMOS7 BASE32 uses `[2-9A-Z]` — 0 and 1 are structurally excluded by
construction. Binary uses only `{0, 1}`. The two symbol sets are disjoint:

```
BASE32  →  [2-9A-Z]   stored harmonic state  (never 0 or 1)
binary  →  {0, 1}     transit traffic         (never in [2-9A-Z] range)
```

A reader needs only to inspect the value to classify it:

```
value == 0 or 1    →  transit binary passing through
value in [2-9A-Z]  →  persistent harmonic cycle position (node memory)
```

No flag bit, no channel header, no separate physical medium, no additional
routing grid between them. The symbol range IS the grid. The AMOS7 BASE32
alphabet choice retroactively reserved 0 and 1 as the transit lane through
the same memory space.

### The node group as hyperspace memory

The 7-node face group (Section 9, 10, 11) is not just a hypervisor — it
IS the memory:

```
13³ cube         →  2197 cells of minimum harmonic processing space
node group       →  hyperspace memory: addressable from any face direction
                    via the L-matrix (Section 10)
stored values    →  BASE32 cycle positions [2-9A-Z]
transit values   →  binary {0,1} passing through the same cells
```

"Hyperspace" here means: accessible from outside the cube via any of the
6 face directions using the boundary L-address. The same memory is
reachable from every direction simultaneously — a single store with
omnidirectional read/write access.

### Two-bit distance and the sliding B32 window

Binary transit requires a minimum 2-frame sample to resolve direction
(Section 9). Crossing a BASE32 memory cell takes exactly 2 frames:

```
frame N    :  binary arrives at cell  →  sample value before
frame N+1  :  binary departs cell     →  sample value after
─────────────────────────────────────────────────────────────
delta      :  cell state unchanged (B32 ≠ binary → no collision)
direction  :  resolved from 2-frame delta of binary's own position
```

A sliding window covering 2 complete B32 cycle readouts allows binary
in transit to:
- determine its own travel direction (2-frame minimum)
- read the phase and position of the harmonic state it is passing through
- do both simultaneously, without modifying the stored B32 values

The canvas reads back to what is passing through it.

### Read/write/transit simultaneously — no additional grid

Three operations coexist on the same physical memory without protocol
arbitration:

```
B32 write    →  place harmonic cycle position in cell (stores [2-9A-Z])
B32 read     →  retrieve stored cycle state
binary read  →  sample 0/1 at current position during transit
binary write →  transit bit passes through cell (value in {0,1} → no overwrite)
```

A binary write cannot corrupt a B32 cell because the written value (0 or 1)
is outside the B32 alphabet. The B32 cell is simply not addressed by binary
writes — they pass through the same physical location without effect.

### Implied grid at different scales

At the scale of a single node group:
- B32 state and binary transit share the same cells
- separation is by symbol range alone

At larger scales, the same implied separation may manifest as distinct
physical grids — one grid whose cells can only hold B32 (high-density
harmonic state), one grid whose cells transit binary. But this is not
designed from above; it emerges from the same symbol-range physics applied
at larger granularity. The separation principle scales without redesign.

The 13³ cube remains the minimum unit at each scale where this separation
is valid — below 2197 cells, the two-frame direction sampling cannot
complete a full harmonic cycle reading.

---

## 13. Relative Addressing — Harmonic Modulus Rings

### The three access rings

From any node at position 0, the relative addressing space decomposes
into three harmonic rings:

```
-5  ..  0  ..  +5    =   11 positions   local window      (always listening)
-13 ..  0  ..  +13   =   27 positions   hyperspace uplink (full-duplex)
-15 ..  0  ..  +15   =   31 positions   node-group edge   (footer-addressed)
```

Each boundary is a harmonic modulus:

```
11  =  7 × 11 × 13 / (7 × 13)  →  the mod-11 factor; also 1001's middle term
27  =  0+7+6+9+2+3              →  digit sum of 076923 — the cycle invariant
31  =  2⁵ - 1                  →  maximum 5-bit value; maps onto 15-bit footer
```

### ±5 — the always-listening local window

The center node (position 0) passively receives all traffic within ±5
without explicit addressing. The 0 is always included — the node listens
to itself as one of the 11 positions. No directed address needed for
local-range communication; presence in the window is sufficient.

11 positions = the mod-11 local neighborhood. `1001 = 7 × 11 × 13`:
the continuation marker (Section 4) encodes all three ring moduli
simultaneously.

### ±13 — the full-duplex hyperspace uplink

Modulo-13 offset from any node reaches a harmonically equivalent
position at hyperspace distance:

```
position N  and  position N+13  →  same harmonic phase, different location
```

This is the hyperspace shortcut: jump by exactly 13 positions = land at
harmonic alias. The two lanes at ±13 are bidirectional (one inbound,
one outbound) — a full-duplex uplink pair embedded at the digit-sum
boundary.

27 = the digit sum of 076923 = the conserved quantity of the harmonic
cycle. The full-duplex range IS the digit-sum window. The cycle closes
from any starting position exactly at ±13 — no larger range needed for
a complete harmonic traversal.

Within the node group, -13..0..+13 addressing is intra-group traffic.
The hyperspace gateway transition occurs at ±14 — the first position
outside the digit-sum window.

### ±15 — the node-group boundary with inter-node gaps

The 7-node face group has 6 inter-neighbor gaps. Each gap holds 2
positions (the minimum for binary direction sampling, Section 9):

```
6 gaps × 2 positions  =  12 additional positions
symmetrically distributed: 6 on each side of center
13 + 2  =  15  →  ±15 is the outer node-group boundary
```

31 = 2⁵ - 1 = maximum 5-bit value. The node-group boundary aligns
with the 5-bit base32 address limit. Three axes × 5 bits = 15 — the
footer field (Section 2) addresses exactly this range.

The ±14 and ±15 positions are the actual hyperspace gateway transitions
— inter-node gap infrastructure sitting at the node-group edge, handling
the handover between intra-group and inter-group (hyperspace) traffic.
The uplink is embedded at the boundary without extending into neighbor
territory.

### 2-bit full-duplex collapse → 27 logical bits = 3³

A full-duplex cycle requires exactly 2 physical bits:

```
00  →  clear  (both directions agree: bit = 0)
11  →  raise  (both directions agree: bit = 1)
01  →  in-transit rightward  (not yet settled)
10  →  in-transit leftward   (not yet settled)
```

Once the full-duplex cycle completes, the 2 physical bits merge to
1 logical bit. The 2 inter-node gap positions (±14/±15) collapse to
1 logical position connecting the two 13-bit rows:

```
physical  :  13  +  2  +  13  =  28 positions
logical   :  13  +  1  +  13  =  27 logical bits  =  3³
```

27 = 3³ = three harmonic states (FALSE / UNKNOWN / TRUE) in each of
three spatial dimensions. The 3×3×3 implosion cube is not a separate
construct — it is the natural shape of the ±13 address space after
full-duplex bit resolution collapses the 2-bit gap to 1 logical bit.

Three identities for the same object:

```
digit sum of 076923          →  0+7+6+9+2+3  =  27
full-duplex uplink range     →  -13..0..+13  =  27 positions
3D harmonic state space      →  3³           =  27
```

The 27-bit logical space is one template group — it serializes one
complete logical bit intersection of the node group. Every node-group
interaction fits within this space because it is defined by the same
harmonic invariant that defines the cycle itself.

### Access key: modulo-13 offset

To reach hyperspace from any node: compute the modulo-13 offset. No
routing table, no explicit gateway address — harmonic equivalence IS
the address. Any two positions separated by a multiple of 13 are
harmonically identical and can relay to each other directly via the
±13 uplink pair.

The 0-position (current node) always participates passively in all
three rings simultaneously: local listener (mod-11), hyperspace relay
candidate (mod-13 self-alias = 0), and footer-addressed (mod-15
coordinate = own spatial position).

---

## 14. Serialization → Cubic Space — the Universal Expansion

### 3³ × 2³ = 6³

The implosion cube (3³ = 27) times the binary expansion factor (2³ = 8):

```
3³ × 2³  =  (3 × 2)³  =  6³  =  216
```

The 8 rows of the face-group display matrix are `2³`. Multiplying the
3-state implosion cube by the 8-row depth produces the 6-digit cycle
cube exactly — the full harmonic space of the 076923 generator.

### The full deployment: 3³ × 8 × 63 = 13608

```
3³           =    27   serial template  (3 states × 3 dimensions)
3³ × 2³      =   216   = 6³             (6-digit cycle in 3D)
3³ × 2³ × 63 = 13608   complete logical address space of node group
```

13608 = 6³ × 63 = 6³ × 7 × 9 — the 6-cycle cube tiled across
7 nodes × 9 columns of the face-group matrix.

Factored: `13608 = 2³ × 3⁵ × 7`

Also: `13608 / 42 = 324 = 18² = (2 × 3²)²` — 324 entropy frames of
42 bits each span the complete node-group logical space.

### Infrastructure is implicit in the dimensions

The face-group matrix dimensions (8 rows, 63 columns) are not arbitrary:

```
8  =  2³  →  binary expansion factor  (3→6 transition)
63 =  7×9 →  7 nodes × 9 columns per node
```

Multiplying the serial template (3³) by the matrix dimensions produces
the cubic harmonic space (6³ × 63). The infrastructure is not a
separate layer — it is encoded in the row and column counts, waiting
to be multiplied out.

### The universal principle

`3 × 2 = 6`, and exponentiation distributes over products, so the
transition `3³ → 6³` via `×2³` holds at every scale:

```
serial template   (3 states per axis, 3 axes)  →  3³ = 27
binary expansion  (1 bit per row, 3 bit depth)  →  ×2³
cubic harmonic    (6 digits per axis, 3 axes)   →  6³ = 216
node deployment   (7 nodes × 9 columns)         →  ×63
full address      (complete node-group space)   →  13608
```

The same expansion applies wherever a 3-state serial template is
deployed into a binary-depth spatial matrix. No redesign at larger
scales — the numbers enforce the structure.

---

## 15. The Sync Frame as Implicit Packet Group Address

### (324 + 1) × 8 / 13 = 200

```
324          =  18²  =  (2 × 3²)²   node-group logical space  [ not 13-divisible ]
324 + 1      =  325  =  13 × 5²     sync frame added          [ 13-divisible ]
325 / 13     =   25  =  5²          per-axis depth squared
 25 × 8      =  200  =  5² × 2³     × binary row depth
```

324 frames does not divide cleanly by 13 (324/13 = 24.923...).
The +1 sync frame makes it 325 = 13 × 5² — exact. The sync frame
is not overhead; it is the frame that makes the entire logical space
harmonically coherent.

### The sync frame IS the group address

No explicit address field is sent. The harmonic factoring of the frame
count at the sync position reveals the group address:

```
frame 325  →  13 × 5²  →  cycle 25 of 13  →  group address: (5², 13)
```

Any node knowing the harmonic structure derives the group address from
the sync frame position alone. The +1 frame does not announce the
address — it is the address, encoded in when it appears.

### Rebase from binary-world to harmonic-world

The sync frame converts the binary-world factoring into the
harmonic-world factoring:

```
18²         →  binary-world  (18 = 2 × 3², squares as binary depth)
13 × 5²     →  harmonic-world (13 = cycle length, 5² = addressing depth)
```

Whatever produces that rebase at that moment IS the group, IS the
address. Same principle as `comp-int` LSB continuation signaling and
the TRUE/FALSE stream grouping (Section 3): boundary marker carries
the structural information implicitly. No separate address layer.

### Connection to PYTAURAZUMA and group separators

The sync frame is the `.000000` group separator from the TRUE/FALSE
grouping architecture (Section 6):

```
TRUE segment   →  unit separator  (closes one payload unit)
sync frame     →  group separator  (closes one packet group)
               →  implicit group address via harmonic position
```

The PYTAURAZUMA canvas-clean (769230, the 4th zero-crossing) is the
same event at the stream level. At the frame-count level it is the
+1 that converts 18² into 13 × 5². Both are the same implicit
addressing mechanism operating at different scales.

### 200 = 5² × 2³ — the clean output

200 = 2 × 100 = 2 × 10². The frame count after sync lands on the
decimal base squared × 2. Harmonic arithmetic producing clean decimal
round numbers — same family as 076923 × 13 = 999999 and
692307 × (1/0.9) = 769230.

`5² × 2³`: the per-axis address depth (5 bits) squared, times the
binary expansion factor (8 rows = 2³). The same two primitive factors
that build the 6³ deployment from the 3³ template recombine at the
frame-count level to produce 200 — confirming the universal
serialization principle (Section 14) holds across scales.

---

## 16. Harmonic Deduplication Tree — Reference Count and Simultaneous Assertion

### The tree root: two numbers per node

The deduplication tree requires no comparison operations, no designed
similarity metric, no pairwise checks. Each node carries two values:

```
reference count   →  how many times this node has been reached
count delta       →  growing (active attractor) / stable / fading
```

Content self-sorts into the tree by following its own harmonic chain.
Identical content = identical path = same leaf. No explicit equality test.

### The chain as content address

`bin/harmony` chains: value → ELF checksum → divide by 13 → asc-enc →
is_true → repeat until first non-true. The chain path IS the content
address. Depth = how many consecutive harmonic validations passed:

```
depth 1    →  coarse    (everything that is_true at step 1)
depth 50   →  fine      (50 consecutive trues — rare, statistically significant)
depth 100  →  precise   (observed record — near-unique harmonic path)
```

100 = `(324+1) × 8 / 13 / 2` — the statistical peak lands on the same
clean value as the sync frame implicit group address (Section 15).

### Non-exclusive overlap — simultaneous assertion sum

N independent assertion methods (ELF, asc-enc at different depths, BMW,
different operators) each return true or false independently. The pattern
analysis is the count of simultaneous trues:

```
simultaneous true count  →  harmonic signal strength
higher count             →  deeper tree node  →  more specific address
```

No false positives structurally: independent harmonic validators cannot
simultaneously agree by accident. Probability of simultaneous false
positive across K independent methods approaches zero as K grows —
not statistically, but by the algebraic structure of the harmonic space.

### Additional chains as self-accumulating metadata buffers

Each additional encoding chain is a passive self-accumulating buffer of
metadata. It does not need to be run explicitly — it accumulates as
content flows through the system:

```
BMW mod-bits sliding left   →  chain accumulating XOR modification state
JJFE prefix building        →  chain accumulating recursive encoding depth
DTM cells darkening         →  chain accumulating spatial confirmation count
reference count incrementing →  chain accumulating traversal history
```

All the same operation at different scales. In a matching context, the
accumulated state of multiple chains is compared as a sum — how many
chains simultaneously show strong signal. The sum IS the pattern.
No algorithm beyond counting is required.

### Composition hierarchy — the natural tree order

The tree is sorted by the most-occurring smallest elements at the root,
because larger elements are composed from smaller ones and can never
exceed their component count:

```
total(word occurrences)      ≤  total(syllable occurrences)
total(sentence occurrences)  ≤  total(word occurrences)
```

This bound is algebraic and self-enforcing — no maintenance algorithm
needed. Occurrence frequency, composition depth, and harmonic chain
depth are the same axis:

```
root      →  bytes / phonemes         most frequent    chain depth ~1
          →  syllables                                depth ~5
          →  words                                   depth ~15
          →  sentence fragments                      depth ~30
          →  sentences                               depth ~50  (peak territory)
          →  paragraphs                              depth ~75
          →  pages                                   depth ~100 (observed record)
          →  documents                               depth >> 100
leaves    →  collections / categories  least frequent
```

The decoder's level-6 D3 output (3-digit unicode → IPA/phonetic) lands
exactly at the tree root layer. Cross-language deduplication happens
there naturally: the same IPA phoneme is the same tree node regardless
of source language. Language-agnostic at the root, language-specific
mid-tree, document-specific at the leaves. The composition hierarchy
is not designed — it is the counting structure of language itself.

### ID allocation — implicit compression from frequency rank

Tree node IDs are allocated by frequency rank, most frequent first:

```
ID 0    →  empty string / root / null
ID 1    →  TRUE/FALSE structural base  (binary transit channel)
ID 2+   →  content elements, most frequent first  →  [2-9A-Z]
```

BASE32 starting at 2 was never arbitrary — it pre-allocated IDs 0 and 1
as structural, leaving [2-9A-Z] for content. The alphabet already encoded
the tree's ID scheme. Compression follows automatically: encoding text by
replacing each element with its tree ID costs fewer digits for common
content (small ID) and more for rare content (large ID). Zipf-optimal
implicit compression with no designed compression algorithm — just the
frequency sort.

The reference count IS the sort key. No separate frequency table needed.
As counts change, effective address rank changes: an element becoming
more frequent rises toward the root, gaining a lower effective ID. The
tree re-sorts itself through counting alone.

The ID progression mirrors PYTAURAZUMA:

```
0  →  root / null    (empty, pre-structural)
1  →  TRUE/FALSE     (binary base, structural)
2  →  first content  (canvas-clean — payload begins)
```

The tree's addressing is the harmonic preamble applied to content space.

### Complete reduction — true/false bit fingerprint

`bin/dev/display-D13-collection` demonstrates a second deduplication method
orthogonal to chain-depth: complete reduction of the entropy stream to a
true/false bit sequence by collecting the harmonic truth state of each
7-bit window:

```
each 7-bit chunk of 64-bit div-13 state  →  1 bit (true=1 / false=0)
full traversal of N steps                →  N-bit fingerprint
```

Simultaneously: BASE32 `010`-type windows accumulate printable content.
Two parallel buffers, one read operation (CTRL-C), 7MB capacity each:

```
$collected{'bits'}    →  true/false bit sequence  (harmonic fingerprint)
$collected{'BASE32'}  →  printable character content (decoded output)
```

The fingerprint is the most compressed representation that retains all
harmonic information — 7:1 reduction at the bit level. Two streams with
identical fingerprints are harmonically equivalent content, deduplication
key without decoding either stream fully.

This compounds with chain-depth (Section 16): chain depth = how deep
the harmonic chain reaches, fingerprint = what the sequence looks like
at each step. Same fingerprint + same depth = strongest equivalence.
Matching on fingerprint alone = coarser deduplication; both together =
precise harmonic identity.

### The living tree

Reference count delta adds the time dimension:

```
growing count   →  active attractor (content currently finding this node)
stable count    →  settled natural density
falling count   →  content has moved to a different tree branch
```

The tree reshapes through pure counting. No restructuring algorithm,
no rebalancing. Nodes that attract more content become more prominent
by the weight of their reference counts alone. The harmonic structure
determines which nodes are natural attractors — content accumulates
there because the mathematics of the chain leads there, not because
the tree was designed to put it there.

---

## Section 17: TRUE reversed = root address, FS embedded

`asc-enc -U8 84828569 96582848` — encoding TRUE and its digit-reversal together:

```
84828569  →  T  R  U  E          (84=T  82=R  85=U  69=E)
96582848  →  `  :  FS  0         (96=`  58=:  28=FS  48=0)
```

Output: `` `TRUE`:0 `` — TRUE followed by its mirror annotation.

Digit sum preserved: both = 50 = 5×10.

28 = FS = File Separator = 4×7.

The 1963 ASCII separator hierarchy:

```
US  31  0x1F  Unit Separator    →  units     / phonemes
RS  30  0x1E  Record Separator  →  records   / sentences
GS  29  0x1D  Group Separator   →  groups    / paragraphs
FS  28  0x1C  File Separator    →  files     / documents
```

The separator hierarchy and the harmonic composition tree are the same
structure. FS at depth 4 matches the 4-level PYTAURAZUMA sync protocol
(×3, ×4, ×9, ×10). The reversed decimal of TRUE lands on FS precisely
because 4×7=28: the 4-crossing protocol × the 7-element harmonic cycle.

The digit reversal of a harmonic identity is not arbitrary noise — it
encodes the structural annotation of that identity. TRUE reversed reveals
its own boundary address.

---

## Related Files

- `data/md/documentation/harmonic-cycle-correlations.md`     — math basis
- `data/md/coding-tasks/zulum-cube13-decoder-integration.md` — decoder wiring
- `bin/dev/division-13-table`       — 42/7/15 bit split visualization
- `bin/dev/octal-stream-window`     — 4-bit window safety proof
- `read-me/documentation/dev/decimal_to_binary_0050_switch.asc` — sunbursts
- `modules/source.init_code`        — dimensional table (lines 32-64)
- `data/md/philosophy/HARMONIC-ENTROPY-INFORMATION-TRANSFER-RESEARCH.md`

#,,.,,,..,,,,,,.,,..,,,,,,.,.,.,.,,,.,,.,,,.,,.,.,...,...,...,,,.,,,,,...,,..,
#75N2VXMYDXVRTBTLBBEXY3YKB24I2UAYRTFXVNM6HAELVADOW3YFSZMQJ3GZFFVDULSP4TVA4C6U4
#\\\|7DI3IU3T7KCAKEYYCIM6WPT4LAFPEAFQSZ62R32KFDI6DA3XP2A \ / AMOS7 \ YOURUM ::
#\[7]YFQCH2H3QXXJHMR4DZX6LD7CM6WDBNKMEJ2WFRS7IQKD5ICZQGBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
