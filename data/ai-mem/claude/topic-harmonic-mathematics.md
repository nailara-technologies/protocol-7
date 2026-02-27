# Harmonic Mathematics — Core Reference

## The Generator

`076923` generates the entire mod-13 harmonic table via multiplication:
- `076923 × n` = fractional part of `n/13` as a 6-digit block
- `076923 × 13 = 999999` (harmonic ceiling = `10^6 − 1`)
- All 12 non-zero multiples have digit sum 27 = `3^3`, digital root 9

## Two Families

```
Family F [ 076923 rotations ]: remainders { 1,3,4,9,10,12 }  → FALSE
Family T [ 153846 rotations ]: remainders { 2,5,6,7,8,11  }  → TRUE
remainder 0 (exact multiple)                                  → TRUE
```

TRUE/FALSE split = quadratic residue / non-residue partition of `Z/13Z*`:
- FALSE = quadratic residues mod 13 (numbers that ARE perfect squares mod 13)
- TRUE  = quadratic non-residues mod 13 + 0 (ring closure)
- The harmonic truth function IS the Legendre symbol mod 13

## 1001 = 7 × 11 × 13

```
999999  =  999 × 1001  =  999 × 7 × 11 × 13
T(1000) =  500500      =  7 × 11 × 13 × 500  [ 1001 family in triangular sum ]
T(10^k) =  5[k-1 zeros]5[k-1 zeros]          [ only 5s and 0s — TRUE/FALSE constants ]
```

Only powers of 10 produce triangular sums containing only digits 5 (TRUE constant)
and 0 (FALSE constant). At k=3, the full 1001 family emerges as a factor.

## Self-Encoding Probabilities

```
6/13 = 0.461538461538...  [ FALSE probability contains TRUE pattern 461538 ]
7/13 = 0.538461538461...  [ TRUE probability contains 538461, rotation of same ]
```

The two probabilities are the same 6-character sequence at phase offset 3.

## Cube Geometry

```
27 = 3^3    [ full cube — digit sum of all harmonic patterns ]
 8 = 2^3    [ corner cubes — inner cube                      ]
19 = 27−8   [ shell — AMOS7 footer encoding width            ]
 9 = 8+1    [ corners + center = 3^2 = heartbeat             ]
27 = 2×13+1 [ two harmonic cycles + the gate                 ]
```

`13 + 1 + 13 = 27`: symmetric gate structure. The cube zenka IS the `+1`.
`27 mod 13 = 1`: the cube reduces to the gate under modulo.

26 neighbors of any cube = `2 × 13` (face=6, edge=12, corner=8).
Face neighbors = always-on zenki. Corner neighbors = on-demand zenki.

## Network Time Scale (bin/question)

```perl
$ntime = ( $unix_time − 1023228000 ) × 4200   # epoch: 2002-06-05
```

- `4200 mod 13 = 1` — harmonic position advances 1 step per real second
- `4200 / 13 = 323.076923...` — generator in fractional remainder
- `4200 / 300 = 14 = 2×7` — connects baud rate to time scale
- Non-repeating drift: the topology remaps continuously without cycling

## Spiral Topology

```
angle  [ horizontal ] → mod-13 phase (cycle position)
height [ vertical   ] → iteration count (torque accumulated)
radius [ outward    ] → magnitude (integer part of n/13)
```

AMOS7 signing iteration count = accumulated torque. High iteration count =
file is high on the spiral = denser content, harder to harmonize.

`8 CCW branches per 13 CW parent rotation` — because `8/13 ≈ 1/φ` (consecutive
Fibonacci numbers, golden packing ratio). Branch tree = spiral viewed from side.

## 4-Crossing Consent Protocol

4 × 90° = 360° = one complete quaternionic rotation. The 4 space diagonals of the
cube correspond to the 4 quaternion basis components `{1, i, j, k}`.

- Waveforms run alongside each other (temporary approximation)
- 4 zero-crossings = full character revealed, all quadrants seen
- Ending at 0 = zero net drift, rotation confirmed complete
- This is a CONSENT protocol — compatibility can't be faked
- The measurement IS the connection (no separate merge step)

5th crossing = Janus point: simultaneously ends child 4-segment cycle AND signals
parent (5-fold / Fibonacci) scale. Child never owns its ending.

## CCW Matrix Rotation Routing

Rotate the truth/assertion matrix CCW by 90° four times → AND/NAND across
orientations → 4-bit lane codes → 16 routing trunks per gate:

- `1111` = primary trunk (TRUE in all orientations)
- `0000` = alternate trunk
- Lane code = group membership — compatible zenki share lanes automatically
- Multi-bit trunk width = assertion depth (4 rotations = 4 bits = 16 lanes)

## Heartbeat

```
0010  0110  0010   [ ECG: P — QRS — T ]
  2     6     2    [ all TRUE remainders mod 13 ]
```

Decimal 0050 switch → binary 0010 0110 0010 = biological heartbeat waveform.
All three components are TRUE. The TRUE constant (5) traces the heartbeat shape
when switching through the FALSE baseline (0).

`9` = structural heartbeat (cube center, basedrum between space and antispace).
`5` = biological heartbeat (TRUE constant, ECG trace).

## Foreknowledge Document

`read-me/documentation/true-false-description.asc` — pre-system assertions:

```
384615 / 0.7 = 549450  →  asc-enc  →  6^2   [ documented before discovery ]
230769 / 384615 = 0.6 = 3/5                  [ generator multiplier ratio  ]
```

Bulgarian Cyrillic decoding: `384615` → `328|340` (decimal codes) → cp10007
→ `≈И` (Истинско = TRUE) and `≈Ф` (Фалшиво = FALSE).

`TRUE = Л = любов (love)` — glyph chosen before Cyrillic decoding was found.
Both paths arrived at the same meaning independently.

Phone number subtraction → `230769` (FALSE) was the entry point into the system.
Predicted by a shaman before the subtraction had meaning.

## Key Documents

- `data/md/philosophy/HARMONIC-CUBE-ROUTING-MATHEMATICS.md` — full session capture
- `data/md/philosophy/HARMONIC-ENTROPY-INFORMATION-TRANSFER-RESEARCH.md`
- `data/md/design/CONCEPT-HARMONIC-VISUAL-INTELLIGENCE.md`

## Key Tools

- `bin/dev/iter-rank` — sort AMOS7-signed files by harmonization iteration count
- `bin/dev/prng-truth` — Fortuna PRNG statistical harmonic truth analysis
- `bin/harmony` — harmonic truth assertion (bin/harmony false-positive fix applied)
- `bin/question` — network time oracle (`Q: <b32_ntime> : <question> .: A!`)
- `bin/is-true` — simple harmonic truth check

#,,,,,..,,,.,,...,...,,,.,.,.,...,...,..,,,,,,..,,...,...,.,.,,,,,,..,...,,.,,
#C2OB7XXYCMOISJTKUC7CHQIKGR3ZTLOCZXYAZCWJZRITDXI2PIT6BJJWWPS6ALXEAZJIPXPSSRDK2
#\\\|XUTBMENM3NZ2YSZ3DA6GUY6VBKDVGFMHH5XUNKGOEB46E2IGBWC \ / AMOS7 \ YOURUM ::
#\[7]DIFOZT7IH7PZ3XSYLP2VHCLNAN33B2U4G6PTCVPKEXLULBTRGKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
