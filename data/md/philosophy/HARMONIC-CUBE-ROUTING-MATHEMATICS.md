# Harmonic Cube Routing Mathematics

## Status

Research / Design — mathematical foundations of the mod-13 harmonic system as a
complete routing and assertion topology, derived from session exploration Feb 2026.

---

## The Generator

`076923` is the single seed of the entire mod-13 harmonic table.

Every `n/13` repeating fractional block is `076923 × n`:

```
× 1  =  076923   [ FALSE ]     ×  8  =  615384   [ TRUE  ]
× 2  =  153846   [ TRUE  ]     ×  9  =  692307   [ FALSE ]
× 3  =  230769   [ FALSE ]     × 10  =  769230   [ FALSE ]
× 4  =  307692   [ FALSE ]     × 11  =  846153   [ TRUE  ]
× 5  =  384615   [ TRUE  ]     × 12  =  923076   [ FALSE ]
× 6  =  461538   [ TRUE  ]     × 13  =  999999   [ ← harmonic ceiling ]
× 7  =  538461   [ TRUE  ]
```

The TRUE/FALSE sequence in the multiplication table IS the mod-13 truth table.
The generator is `1,000,000 / 13` — its 13th multiple is `10^6 − 1`, the harmonic
ceiling. All 12 non-zero multiples have digit sum 27 = 3^3.

`076923 = 9 × 8547` — divisible by 9, so all multiples inherit digit sum divisible
by 9. Digital root of every harmonic pattern = 9 = 3^2 (fixed point of digit summing).

The TRUE/FALSE distinction lives entirely in the *arrangement* of digits, not their
set. Both families of 6 share the same multiset structure. Permutation carries
the truth signal; digit sum is the invariant that doesn't change.

---

## Two Families

The 12 non-zero harmonic patterns split into two rotation families:

```
Family F  [ 076923 rotations ]  :  076923  769230  692307  923076  230769  307692
  corresponds to  :  1/13  10/13  9/13  12/13   3/13   4/13
  remainders      :  { 1, 3, 4, 9, 10, 12 }  →  all FALSE

Family T  [ 153846 rotations ]  :  153846  538461  384615  846153  461538  615384
  corresponds to  :  2/13   7/13  5/13  11/13   6/13   8/13
  remainders      :  { 2, 5, 6, 7, 8, 11 }   →  all TRUE

0/13 = 0  →  remainder 0  →  TRUE  [ ring closure, completion ]
```

Multiplying by 2 crosses from one family to the other. Family F generator (`076923`)
times 2 = `153846` (Family T generator). The families are not separate — they are
the same generator at phase offset.

---

## Quadratic Residue Structure

The TRUE/FALSE split is not arbitrary — it corresponds exactly to the quadratic
residue / non-residue partition of `Z/13Z*`:

```
Quadratic residues mod 13    : { 1, 3, 4, 9, 10, 12 }  →  FALSE
Quadratic non-residues mod 13: { 2, 5, 6, 7, 8, 11 }  →  TRUE
Remainder 0 (exact multiple) : →  TRUE  [ ring closure ]
```

The harmonic truth function is the Legendre symbol mod 13:
- `(n/13) = 1`  (n is a square mod 13)  →  FALSE
- `(n/13) = −1` (n is not a square)     →  TRUE
- `(n/13) = 0`  (13 divides n)          →  TRUE

FALSE = "already squared" (settled, completed).
TRUE = "not yet squared" (dynamic, in motion).

The assignment was not designed — it falls out of the prime field's own internal
structure. Two families of 6, plus the zero element making TRUE the larger set (7:6).

---

## The 1001 Family

`1001 = 7 × 11 × 13` — three primes linked through a single product.

```
999999  =  999 × 1001  =  999 × 7 × 11 × 13
```

`999999` — the harmonic ceiling — factors through all three. So `1/7`, `1/11`, and
`1/13` all produce repeating decimals contained within `999999`:

```
1/13  →  076923   [ period 6 — generator of the mod-13 table     ]
1/7   →  142857   [ period 6 — the other famous cyclic number     ]
1/11  →  090909   [ period 2 — fits inside 6 digits               ]
```

Canceling any two via `1001` makes the third appear as a reciprocal:

```
7 × 11 / 1001  =  1/13    →  × 11  =  11/13  =  0.846153...  [ TRUE ]
```

`076923 × 3 = 230769` (FALSE), `076923 × 5 = 384615` (TRUE).
The canonical FALSE and TRUE are separated by factor `3:5` in generator-space.
`230769 / 384615 = 3/5 = 0.6`.

---

## Harmonic Self-Encoding of Probabilities

The theoretical TRUE/FALSE probabilities are themselves harmonically encoded:

```
FALSE probability  :  6/13  =  0.461538461538...  [ 461538 = TRUE pattern, repeating ]
TRUE  probability  :  7/13  =  0.538461538461...  [ 538461 = TRUE pattern, rotated    ]
```

The FALSE probability contains the TRUE harmonic pattern. Both probabilities are
rotations of the same 6-character sequence — separated by exactly 3 rotation steps
(the midpoint of the 6-rotation cycle). The complement of TRUE is the same harmonic
string at phase offset 3.

---

## The Foreknowledge Document

`read-me/documentation/true-false-description.asc` contains pre-system assertions
(documented as "foreknowledge") that were verified to be true upon investigation:

```
384615 / 0.7  =  549450   →  asc-enc  →  6^2
230769 / 0.7  =  329670   [ same 6 digits as 230769, rearranged, still FALSE ]
```

`6^2 = 36`: squaring a TRUE remainder (6) produces a FALSE remainder (10).
The encoding captures the state-flip under self-multiplication.

Decoding chain from `384615` to TRUE/FALSE in Bulgarian Cyrillic:
```
TRUE  digits 384  ×10  +  FALSE digits 230  →  32 83 40  →  concat  →  328 340
decimal codes 328 and 340 in cp10007 (Apple Cyrillic)  →  ≈И  ≈Ф
  ≈И  =  ASSERT[I]  =  'Istinsko'   [ Истинско : TRUE  in Bulgarian ]
  ≈Ф  =  ASSERT[F]  =  'Falshivo'   [ Фалшиво  : FALSE in Bulgarian ]
```

The harmonic constants, decoded through their own internal structure, produce the
words for TRUE and FALSE in the language of the culture where the system's
mathematical foundation was first encountered (via a shaman's introduction to
division by 13 on a desk calculator). `TRUE = Л = любов (love)` was the glyph
chosen before the Cyrillic decoding was found. Both arrived at the same meaning
independently.

The phone number subtraction that gave `230769` (FALSE) was predicted by the shaman
before it had meaning — the entry into the system through its shadow side.

---

## The Digit Sum Cube

All 12 harmonic patterns have digit sum 27 = 3^3:

```
076923  :  0+7+6+9+2+3  =  27    153846  :  1+5+3+8+4+6  =  27
...all 12 rotations...           →  digital root  →  9  =  3^2
```

`27` is the cube (`3^3`). `9` is the fixed point of repeated digit summing.

The 3D plus sign has 6 arms (±x, ±y, ±z) — corresponding to the 6 rotations per
harmonic family. The cube (`3^3 = 27`) is its volumetric complement/inverse — the
solid that the arms define the axes of.

```
27  =  2 × 13 + 1    [ two harmonic cycles + the gate ]
 8  =  2^3            [ corner cubes — inner cube       ]
19  =  27 − 8         [ shell — AMOS7 footer encoding width ]
 9  =  8 + 1          [ corners + center = 3^2 = the heartbeat ]
```

`19 = 3^3 − 2^3` — the difference of two consecutive perfect cubes, and the cubic
shell formula `3n^2 − 3n + 1` for n=3. The AMOS7 footer encodes across exactly 19
octal positions because 19 is the shell count — the new positions added when
expanding from a 2×2×2 cube to a 3×3×3 cube.

---

## 13 + 1 + 13 = 27 — The Gate Structure

```
13  [ this side ]  +  1  [ gate ]  +  13  [ other side ]  =  27
```

The `+1` is not an offset — it is the second 13 viewed from across the link. Each
side sees `13 + 1`, where the 1 is the other side collapsed to a point at the
interface. The cube zenka IS the `+1` — the center through which all messages pass.

`27 mod 13 = 1` — the whole cube reduces to the gate under modulo.

The gate (`1`) is owned by neither side — it's the shared point where both 13-cycles
touch. From any position within either cycle, the gate is always exactly 1 step away
at the modular boundary.

---

## The Network Time Scale Factor

`bin/question` uses a custom time epoch (2002-06-05) scaled by 4200:

```perl
$ntime  =  ( $unix_time − $ntime_start ) × 4200
```

Key resonances:

```
4200 mod 13  =  1       [ each second advances mod-13 position by 1 net step ]
4200 / 13    =  323.076923...   [ generator appears in fractional remainder   ]
4200 / 300   =  14  =  2 × 7   [ baud rate × 14 = time scale factor          ]
```

Every 4200 seconds (the calc zenka idle timeout — same number), the system
completes `4200/13 = 323` full harmonic cycles with a generator-sized fractional
remainder (`076923...`). The topology is continuously remapped without exact
repetition — the generator prevents periodic locking.

At microsecond resolution: `4,200,000,000 / 13 = 323,076,923.076923...` — the
generator appears in the integer part AND the fractional part simultaneously.

The question encoding: `Q: <base32_ntime> : <question> .: A!` — network time is
injected directly into the truth assertion input. The oracle is seeded by the
continuous harmonic walk of real-time clock advance.

---

## The Spiral

The mod-13 harmonic walk through time traces a spiral with three coordinates:

```
angle   [ horizontal ]  →  mod-13 phase  [ 0..12, cycle position    ]
height  [ vertical   ]  →  iteration count  [ torque accumulated     ]
radius  [ outward    ]  →  magnitude  [ integer part of n/13         ]
```

Viewed from above: pure angle — the cycle phase, which remainder, TRUE or FALSE.
Height collapses to zero. This is what `n mod 13` extracts.

The iteration count in the AMOS7 footer is accumulated torque: each failed
harmonization attempt adds one unit of angular work. Files with high iteration
counts are high on the spiral — they required more rotational force to align.

Pitch ratio 7:6 (TRUE:FALSE steps per revolution) — golden-ratio-adjacent at the
Fibonacci scale. The spiral never returns to the same height because the TRUE:FALSE
asymmetry creates a non-integer advance per revolution.

---

## Branch Management — CCW Rotations per CW Parent

Viewed from above the spiral:

```
CW  rotation  [ forward, 13 steps ]  :  parent cycle, main execution
CCW rotation  [ branch event       ]  :  child fork, deviation from parent
ratio CCW/CW                         :  branch density at that depth level
```

`8 CCW branches per 13 CW parent rotation` — because `8/13 ≈ 0.615 ≈ 1/φ`.
`8` and `13` are consecutive Fibonacci numbers. The branching ratio naturally
approximates the golden ratio's reciprocal — the most efficient packing density,
the same proportion plants use for leaf and seed arrangement (phyllotaxis).

```
branch opens  :  at TRUE phase  [ 7 possible gate points per parent revolution ]
consolidates  :  at FALSE phase [ 6 closing points                              ]
merge         :  CCW branch completing counter-rotation, rejoining CW path
```

The iteration count of the branch = how many CCW steps before merge. The branch
tree is the spiral viewed from the side. View from above = routing phase. View
from the side = version/fork tree. Same object, two projections.

---

## The 4-Crossing Consent Protocol

Simple multiplication forces a merge regardless of compatibility. The longer
sequence approach gives waveforms the choice of whether they *want* to merge:

```
waveform A  [ parent branch, period 13, phase 0 ]
waveform B  [ child branch,  period 13, phase θ ]
                    ↓
               cross-map  [ multiply point by point ]
                    ↓
               beat pattern  [ interference of two 13-cycles ]
                    ↓
           count 0-crossings  [ resonance events ]
```

The 4 space diagonals of the cube map exactly to 4 × 90° = 360° — one complete
rotation of a scalar waveform. The waveform's full character is visible only after
all 4 quadrant components have been seen:

```
crossing 1  :   0° →  90°  [ first component  ]
crossing 2  :  90° → 180°  [ second component ]
crossing 3  : 180° → 270°  [ third component  ]
crossing 4  : 270° → 360°  [ fourth — full rotation — ending at 0 ]
```

This is the quaternion structure: `q = a + bi + cj + dk` — four basis components
for full 3D rotation description. Two waveforms are confirmed compatible only when
all 4 quaternion components have been mutually tested. Ending at 0 confirms zero
net drift — the rotation was complete and undeformed.

Consent protocol: the test doesn't push waveforms together. It creates the
approximation space where compatibility can show itself. The resonance is either
structurally present or absent — no waveform can fake 4 crossings with an
incompatible partner.

```
compatible   :  4 crossings emerge naturally
incompatible :  fewer crossings regardless of duration
```

The temporary approximation becomes permanent when resonance is confirmed — the
measurement IS the connection. No separate merge step.

The same protocol runs at every scale:

```
harmony-filtered seed     :  timestamp walks until it WANTS to be the seed
signing iterations        :  content walks until it WANTS the footer
stargate handshake        :  two sides approximate until WANTING to connect
branch merge              :  CCW returns to CW only when WANTING to close
```

---

## The 5th Crossing — Janus Point and Parent Signal

The 4th crossing completes the child cycle. The 5th crossing is simultaneously:

```
child scale  :  end of current 4-segment cycle
parent scale :  beginning of next — the parent signal
```

The 5th zero belongs to neither cycle exclusively — it is the shared boundary.
The child never owns its ending: the 5th zero is the parent already speaking.

```
child cycle  :  4-fold  [ cubic, 90° rotations, Z/4Z symmetry ]
parent scale :  5-fold  [ Fibonacci, golden ratio              ]
```

5 is the first element that transcends the 4-fold child structure. The gap between
4-fold (cubic) and 5-fold (Fibonacci/golden) symmetry is the irrational interval
containing the golden ratio. The 5th crossing is precisely that gap — where the
cubic routing protocol hands off to the larger organizing structure.

`4 × 13 = 52`. And `52` is the Mayan Calendar Round — where the 260-day Tzolk'in
and 365-day Haab' cycles first resynchronize. Cultures using 13 as their ring
completion also used 52 as the 4-crossing period.

---

## Triangular Numbers — Heartbeat Encoding

The triangular sum `T(n) = n(n+1)/2` produces numbers with ONLY the digits 5 and 0
for exactly the powers of 10:

```
T(10^k)  =  5[k−1 zeros]5[k−1 zeros]

T(10)    =       55   =  5 × 11
T(100)   =     5050   =  5 × 10 × 101
T(1000)  =   500500   =  7 × 11 × 13 × 500     [ 1001 family emerges at k=3 ]
T(10000) = 50005000   =  ...
```

The 1001 family (`7 × 11 × 13`) appears as a factor at exactly the cubic scale
(`k=3`). The two TRUE constants (`5`) are symmetrically placed, separated by
growing FALSE spacers — the routing distance between TRUE nodes increases with
scale while TRUE remains singular.

`5` is the Protocol-7 TRUE constant. `0` is the FALSE constant. The triangular
sums of powers of 10 contain ONLY these two constants — the counting system itself
encodes the TRUE/FALSE binary at its power-of-10 boundaries.

The binary encoding of the decimal `0050` switch:

```
0010  0110  0010     [ P — QRS — T waveform shape ]
  2     6     2
```

All three components of the heartbeat are TRUE (remainders 2, 6, 2 — all in
Family T). The TRUE constant, when switching through the FALSE baseline, traces
the ECG pattern of a biological heartbeat. The system beats at the structural
level (9 = cube center, basedrum) and the biological level (5 = TRUE constant,
heartbeat) simultaneously — same rhythm, different scales.

---

## CCW Matrix Rotation — Multi-Bit Routing

The 2D assertion matrix rotated CCW by 90° four times produces four orientations.
AND and NAND operations across orientations generate multi-bit lane codes:

```
truth matrix at   0°  [ primary orientation    ]
truth matrix at  90°  [ CCW rotation 1         ]
truth matrix at 180°  [ CCW rotation 2         ]
truth matrix at 270°  [ CCW rotation 3         ]
         ↓
    AND  all 4  →  coherent in ALL directions  [ primary trunk ]
    NAND any 1  →  exception routing            [ sub-lane     ]
```

Each position gets a 4-bit routing code — 16 possible lane assignments per gate
crossing, computed simultaneously across the entire traffic matrix. Not one message
at a time: an entire routing plane decided in one operation.

```
lane 1111  :  primary trunk       [ ALL orientations TRUE  ]
lane 0000  :  alternate trunk     [ ALL orientations FALSE ]
lane 1010  :  oscillating sub-ch  [ phase-specific         ]
lane 1100  :  directional         [ half-coherent          ]
    ...16 total lanes...
```

Traveling zenki groups: zenki with compatible 4-bit codes share a lane naturally.
The routing code IS the group membership. Proximity is maintained because the
harmonic structure assigns compatible zenki to the same lane — no explicit group
management required.

The CCW direction for rotation is key: the primary flow is CW (forward execution).
CCW rotations reveal the orthogonal structure invisible to the primary flow. Routing
decisions happen in the perpendicular dimension, leaving the primary lane uncontested.

Multi-step assertions build awareness of the parent pattern: an element passing all
4 orientations is coherent with the full parent matrix from every angle — not just
locally TRUE but globally fitting. The 4-crossing test is the group entry credential.

The bit-depth of the trunk equals the assertion depth: 4 rotations → 4 bits → 16
lanes. Deeper assertion → wider trunk — without adding physical connections.

---

## Neighbor Cube Traversal Protocol

Any cube in a 3D lattice has exactly 26 neighbors:

```
6  face neighbors    [ ±x ±y ±z — the 3D plus sign arms     ]
12 edge neighbors    [ the 12 non-zero harmonic patterns     ]
8  corner neighbors  [ 2^3 — the inner cube                  ]
─────────────────────────────────────────────────────────────
26 neighbors  =  2 × 13     [ two complete harmonic cycles   ]
+ 1 center   =  27  =  3^3  [ the full neighborhood cube     ]
```

Traversal protocol emerges directly from the structure:

```
face neighbors    [ 6  ]  →  primary routes, always-on zenki
edge neighbors    [ 12 ]  →  secondary routes, one harmonic rotation away
corner neighbors  [ 8  ]  →  on-demand zenki, activated only when needed
center            [ 1  ]  →  the cube zenka itself, the gate
```

The 27-beat stargate pulse advances by 1 each cycle (`27 mod 13 = 1`), so no
neighbor configuration ever exactly repeats. The protocol explores the full
neighborhood space without cycling back to the same gate alignment.

Grid travel = ring-to-ring hops via gate nodes. Local traversal = within-ring
cycling. The network is self-similar: each node is a gate for its neighbors, each
center is another node's neighbor. Every cube simultaneously contains a `13+1+13`
gate structure when seen from either neighboring ring.

---

## The Shaman's Prediction

Predicted before the system was built:

```
300 baud bandwidth      →  4200 / 300 = 14 = 2 × 7  [ baud × 14 = time factor ]
universal truth oracle  →  bin/question + AMOS7::Assert::Truth
phone system topology   →  cube zenka as switchboard, zenki as extensions
Unix TTY interface      →  nshell, p7 binary, domain socket IPC
```

The 300-baud oracle is a single-bit output of the cross-mapped waveform resonance
calculation. The full quaternionic compatibility model underneath collapses to one
bit at the channel boundary. 300 baud is fast enough for that.

The constraints (300 baud, TTY, phone system) were described as features, not
limitations. A patient system that asks before merging. A truth oracle that gives
waveforms the choice of whether they want to connect.

---

## References

- `bin/question` — network time oracle implementation, 4200 scale factor
- `bin/dev/prng-truth` — Fortuna PRNG harmonic truth statistics
- `bin/dev/iter-rank` — file ranking by AMOS7 signing iteration count
- `bin/harmony` — harmonic truth assertion, ELF + mod-13
- `data/lib-path/pm/AMOS7/Assert/Truth.pm` — quadratic residue implementation
- `read-me/documentation/true-false-description.asc` — foreknowledge document
- `read-me/documentation/dev/decimal_to_binary_0050_switch.asc` — triangular heartbeat
- `data/md/design/DECODER-VTERM-ARCHITECTURE.md` — spiral buffer sync, VTERM layers
- `data/md/philosophy/HARMONIC-ENTROPY-INFORMATION-TRANSFER-RESEARCH.md` — entropy protocol
- `data/md/design/CONCEPT-HARMONIC-VISUAL-INTELLIGENCE.md` — visual encoding model

#,,,.,,.,,..,,,,.,.,,,..,,,,,,.,.,,.,,,,,,,,,,..,,...,...,,..,.,.,,.,,,..,,,,,
#VJ5JX2UVZZMROZEPQ3WB7UFKJ3AA6I6S3UO63AGOTNARROJ4TQMRCOGG5L3VYBFDWBRLUGSSRB57I
#\\\|ODT6CNY2VX4HFZA3C7QLT7YB5GEVXZPRZHMNLTMCDL7UKD5SW2X \ / AMOS7 \ YOURUM ::
#\[7]7XGV2HHAUDQLR3TSLE27Q4VJL3HIWVOLWWHA6UFAUW2JGOQ2CUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
