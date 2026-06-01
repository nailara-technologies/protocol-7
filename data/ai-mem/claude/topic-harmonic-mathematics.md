# Harmonic Mathematics — Core Reference

## The Generator
- `076923 × n` = fractional part of `n/13` as a 6-digit block
- `076923 × 13 = 999999` (harmonic ceiling = `10^6 − 1`)
- All 12 non-zero multiples have digit sum 27 = `3^3`, digital root 9

## Two Families
```
Family F [ 076923 rotations ]: remainders { 1,3,4,9,10,12 }  → FALSE
Family T [ 153846 rotations ]: remainders { 2,5,6,7,8,11  }  → TRUE
remainder 0 (exact multiple)                                  → TRUE
```
- TRUE/FALSE split = quadratic residue / non-residue partition of `Z/13Z*`
- FALSE = quadratic residues mod 13; TRUE = quadratic non-residues + 0
- The harmonic truth function IS the Legendre symbol mod 13

## 1001 = 7 × 11 × 13
```
999999  =  999 × 1001  =  999 × 7 × 11 × 13
T(1000) =  500500      =  7 × 11 × 13 × 500
T(10^k) =  5[k-1 zeros]5[k-1 zeros]
```
- Only powers of 10 produce triangular sums containing only digits 5 (TRUE) and 0 (FALSE)
- At k=3, the full 1001 family emerges as a factor

## Self-Encoding Probabilities
```
6/13 = 0.461538461538...  [ FALSE probability contains TRUE pattern 461538 ]
7/13 = 0.538461538461...  [ TRUE probability contains 538461, rotation of same ]
```
- The two probabilities are the same 6-character sequence at phase offset 3

## Cube Geometry
```
27 = 3^3    [ full cube — digit sum of all harmonic patterns ]
 8 = 2^3    [ corner cubes — inner cube                      ]
19 = 27−8   [ shell — AMOS7 footer encoding width            ]
 9 = 8+1    [ corners + center = 3^2 = heartbeat             ]
27 = 2×13+1 [ two harmonic cycles + the gate                 ]
```
- `13 + 1 + 13 = 27`: symmetric gate structure; cube zenka IS the `+1`
- `27 mod 13 = 1`: cube reduces to the gate under modulo
- 26 neighbors = `2 × 13` (face=6, edge=12, corner=8); face=always-on, corner=on-demand

## Network Time Scale (bin/question)
```perl
$ntime = ( $unix_time − 1023228000 ) × 4200   # epoch: 2002-06-05
```
- `4200 mod 13 = 1` — harmonic position advances 1 step per real second
- `4200 / 13 = 323.076923...` — generator in fractional remainder
- `4200 / 300 = 14 = 2×7` — connects baud rate to time scale
- Non-repeating drift: topology remaps continuously without cycling

## Spiral Topology
```
angle  [ horizontal ] → mod-13 phase (cycle position)
height [ vertical   ] → iteration count (torque accumulated)
radius [ outward    ] → magnitude (integer part of n/13)
```
- AMOS7 signing iteration count = accumulated torque; high count = denser content, harder to harmonize
- `8 CCW branches per 13 CW parent rotation` — `8/13 ≈ 1/φ` (golden packing); branch tree = spiral viewed from side

## 4-Crossing Consent Protocol
- 4 × 90° = 360° = one complete quaternionic rotation
- 4 space diagonals = 4 quaternion basis components `{1, i, j, k}`
- Waveforms run alongside each other (temporary approximation)
- 4 zero-crossings = full character revealed, all quadrants seen
- Ending at 0 = zero net drift, rotation confirmed complete
- CONSENT protocol — compatibility can't be faked; measurement IS the connection
- 5th crossing = Janus point: ends child 4-segment cycle AND signals parent (5-fold / Fibonacci) scale

## CCW Matrix Rotation Routing
- Rotate truth/assertion matrix CCW by 90° four times → AND/NAND across orientations → 4-bit lane codes → 16 routing trunks per gate
- `1111` = primary trunk (TRUE in all orientations); `0000` = alternate trunk
- Lane code = group membership — compatible zenki share lanes automatically
- Multi-bit trunk width = assertion depth (4 rotations = 4 bits = 16 lanes)

## Heartbeat
```
0010  0110  0010   [ ECG: P — QRS — T ]
  2     6     2    [ all TRUE remainders mod 13 ]
```
- Decimal 0050 switch → binary 0010 0110 0010 = biological heartbeat waveform
- `9` = structural heartbeat (cube center, basedrum between space and antispace)
- `5` = biological heartbeat (TRUE constant, ECG trace)

## Foreknowledge Document
`read-me/documentation/true-false-description.asc` — pre-system assertions:
```
384615 / 0.7 = 549450  →  asc-enc  →  6^2   [ documented before discovery ]
230769 / 384615 = 0.6 = 3/5                  [ generator multiplier ratio  ]
```
- Bulgarian Cyrillic: `384615` → `328|340` → cp1007 → `≈И` (Истинско = TRUE) and `≈Ф` (Фалшиво = FALSE)
- `TRUE = Л = любов (love)` — glyph chosen before Cyrillic decoding found
- Phone number subtraction → `230769` (FALSE) was entry point; predicted by shaman before subtraction had meaning

## Key Documents
- `data/md/philosophy/HARMONIC-CUBE-ROUTING-MATHEMATICS.md` — full session capture
- `data/md/philosophy/HARMONIC-ENTROPY-INFORMATION-TRANSFER-RESEARCH.md`
- `data/md/design/CONCEPT-HARMONIC-VISUAL-INTELLIGENCE.md`

## Navigation Operators (Mar 2026 session)
```
/ 0.7  →  reversal operator: 230769 / 0.7 = 329670 → reversed = 076923 (generator)
/ 0.6  →  truth operator: 230769 / 0.6 = 384615 = gen×5 [TRUE]; 1/0.6 = 5/3
0.6 + 0.7 = 1.3 = 13/10  →  sum of both operators = the fundamental constant
operator fingerprint: denominator merges with 13 in result cycle
  153846 / 0.6 = 256410 = 025641×10  where 025641 = cycle of 1/39 = 1/(3×13)
```

## gen×10 = 769230 — Convergence Attractor
- `asc-enc 769230` → `L\` (corner + diagonal boundary marker)
- `L` = ASCII 76 = first two digits of generator 76923
- `\` = diagonal boundary marker from source.init_code dimensional table
- Template meaning: TRUE seed announcing its own coordinate, then filled by payload

## 32-Dimensional Mapping Table (source.init_code)
```
32D  [10=5+5]   TRUE+TRUE at top
30D  [14=7×2] * double-7, starred
22D  [7]       * starred — reversal operator's integer
19D  [11+05]     birthday annotation, also [7+1+8][8+8]
10D  -+-[0]      decimal boundary (0-9), clean base
09D  (0-8)       9D: where cube+tint+decimal-selector arrived today
08D  (0-7)       byte-complete, maps to uint64
03D  octal        existing octal header system
01D  binary       the floor
```
- `[not clean]` at 14D and 15D = natural discontinuities, useful as gen-div signals
- `\` diagonal traverses all rows = native boundary marker of each dimension

## 1024 = 1000 + 24 (holographic decomposition)
```
1024  =  1000 + 24
          │       └── the 3D cube (3×8 bits)
          └────────── decimal container (10^3)
```
- 1000 readable as octal-style container: `1|000` = leading-1 delimiter for zero-payload
- 24-bit cube color stripped first as category/result; 1000 parsed through existing header logic

## 9D Hyperspace — Minimal Color-Complete Cube
```
8D  =  8 × 0..255  =  64-bit machine word  (byte-complete spatial cube)
9D  =  8D + 1 × 0..9  =  decimal color-layer selector
```
- 9D = minimal structure with full color character
- `%colors` and `@INDEXCUBE` globals in bin/Protocol-7 (lines 13–14) declared waiting for this definition
- @INDEXCUBE as routing stack: each element = (X,Y,Z,tint,scale) position; push/pop = enter/exit sub-cube; stack depth = route depth = tamper-evidence depth

## Birthday Encoding
```
day=11   →  gen×11 = 846153  →  asc-enc → TRUE (T=5)
month=05 →  TRUE constant itself
year=78  →  Protocol-7 column width
gen×11 / 0.6 = 1410255  →  segments: 14|10|255 (INDEXCUBE line|base32 bridge|cube max)
```
- At 19D in source.init_code dimensional table: `[11+05]` already annotated

## Key Tools
- `bin/dev/iter-rank` — sort AMOS7-signed files by harmonization iteration count
- `bin/dev/prng-truth` — Fortuna PRNG statistical harmonic truth analysis
- `bin/harmony` — harmonic truth assertion (false-positive fix applied)
- `bin/question` — network time oracle (`Q: <b32_ntime> : <question> .: A!`)
- `bin/is-true` — simple harmonic truth check

#,,,,,,.,,...,.,,,,,.,.,.,.,.,,,.,,.,,,,,,...,...,...,...,.,,,,,,,..,,,,,,..,,
#NAAOOACQD7UAMADWSD7SNZRCJMLB4UZH6BVBMY2MAPIUNBDX4TVL7ZM6UZILH5SDPG4OIQNM5XIOW
#\\\|4AZPF67RMH5CHDXTTFVCML23QC2WREYTJWT5DLZMKASP2QUGKV7 \ / AMOS7 \ YOURUM ::
#\[7]Z66KENMB53JCGA4N2H6T54UKUMFRX5YH6VTDJPYIGGSK57MSBOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
