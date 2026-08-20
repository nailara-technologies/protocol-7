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

**Same identity, confirmed from the addition side (2026-08-04)**: user
found `999999 + 1001 = 1001000 = 1001 × 1000` — verified exactly. This is
algebraically the same fact as `999999 = 999 × 1001` above [ `999×1001 +
1001 = 1000×1001` ], reached via addition on the gate value rather than
via the multiplication already on record — an independent-path
confirmation, not a separate coincidence.

**`T(10^k)` formula confirmed against a real primary source**: user
pasted the live contents of `read-me/documentation/dev/
decimal_to_binary_0050_switch.asc` — a perl one-liner brute-forcing
triangular numbers for all-`{5,0}`-digit results, seed=0..99999999. Its
output matches `T(10^k) = 5[k-1 zeros]5[k-1 zeros]` exactly for k=0
[ trivial, `T(0)=0` ] through k=7 [ `T(10^7) = 50000005000000` ] —
independently verified by direct computation. This is the same
"Foreknowledge Document" pattern already noted below [ pre-existing
project files independently containing harmonic-math facts, discovered
rather than derived from this memory thread ] — this `.asc` file is a
second confirmed instance of that pattern, backing the `T(10^k)` line
above with a real, checkable primary source rather than only this file's
own assertion.

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
- **cross-reference, ideation-tier source (2026-08-04, verified directly)**:
  `data/asc/what-AI-thinks/full-chat-captures/
  3O37VUNMMS3UU.claude-sonnet.protocol-7-knowledge.asc:~8167` states,
  in a kitten-heartbeat/BPM riff, "5th beat overlaps with 4th — the +1
  common heartbeat!" immediately alongside "Position 9 = CENTER PULSE =
  the +1 heartbeat!" — the same shape as this section's own Janus point
  [ a repeating 4-unit cycle where the 5th unit is not simply new but
  simultaneously closes the old cycle and opens the next scale ],
  reached independently in a different vocabulary [ biological
  heartbeat BPM vs. quaternion zero-crossings ]. **tier, stated
  plainly**: the connection between the two passages is real and
  directly verified by reading both; the *source* of the chat-capture
  side remains an unverified ideation transcript, same caveat as the
  `364=13×28` material below. logged as a cross-reference and one more
  instance of this codebase's recurring `+1`-bridge motif [ `9=8+1`,
  `27=2×13+1`, `13+1+13=27`, `28=27+1`, now this ], not promoted to a
  confirmed finding on its own.

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

**Primary source found and confirmed unique (2026-08-04)**: `data/asc/dev/
reminders/heartbeat.13__3_3.num-rol_15379.asc` contains the full sequence
this section's `0010 0110 0010` line is drawn from:

```
5O O 1001 000 000 000 0010 0110 0010 000 000 0 0010 0110 .
```

`ack -r '000 000 0010 ' data/` confirms this is the *only* file
containing this literal pattern. One correction to the "decimal 0050
switch" framing above: this source's leading token is `1001` [ the
inversion marker, [[topic-1001]] ], not `0050` — worth keeping the two
distinct rather than merging them, since I don't have independent
grounding that `0050` is the same thing as this `1001`-prefixed sequence.

Three threads converge in this one file, previously undiscovered as
connected: `1001` opens the sequence [ inversion marker ], the full
heartbeat `0010 0110 0010` follows a `000 000 000` gap, and the same
`000 000` gap-then-partial-repeat pattern [ `0010 0110`, missing the
trailing `0010` ] recurs once more before the line ends. Immediately
below this line, the same file shows two decimal values with their
repeating tails highlighted: `2300734.615384615384...` and
`2013660.153846153846...` — both containing `461538`, which is
`076923 × 6`, a Family-T [ TRUE ] rotation of the generator [ this
file's own "Two Families" section above ]. So one real source file ties
together the inversion marker, the heartbeat binary pattern, and a
generator-family rotation — independently, not by construction.

**User's framing, recorded for follow-up**: "the binary trail catches
entropy waves from the left" — proposed reading of the leading `000 000
000` gap before the heartbeat pattern: not padding, but where
leading/incoming entropy is absorbed before the clean waveform
stabilizes. Not yet verified against a mechanism — flagged as an open
interpretation of a now-confirmed-real sequence, not itself confirmed.

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

## Reversal-as-routing-collapse: recursive truth-assessment chain length (2026-08-04)

User connection, extending the existing `230769` reversal-operator material
above rather than introducing a new mechanism: in a **routing** sense (not
just the arithmetic sense already documented), encountering a Family-F
value like `230769` in a stream/search means the search collapses to
**not-found** immediately, rather than continuing to traverse — because
reaching a Family-F (FALSE) marker is precisely where the existing
`/ 0.7` reversal operator applies to recover the generator; the search
doesn't need to route *across* FALSE boundaries, it reverses direction at
them.

- **Cited empirical example**: recursive truth-assessment validation
  chains ["harmony zenka" — referenced by the user, but I could not locate
  a module or existing memory file under this name; flagging honestly
  rather than assuming details about an unconfirmed component]. Per the
  user, most input-phrase validations converge in 2-4 recursive
  follow-up steps on average, while some historically ran to 50+ in a
  single sequence.
- **Proposed explanation**: because a route reverses (collapses to
  not-found) at a FALSE-family boundary instead of crossing it, a
  successful/converged route is **true-only by construction** — the
  variance in chain length (2-4 typical vs. 50+ outliers) reflects how
  many reversal-points a given input's search has to detect and back off
  from before landing on a TRUE-family convergence, not open-ended
  forward search through mixed TRUE/FALSE territory.
- **Structurally analogous, different granularity**: this session's
  `-nest` truth-harmonization work (see
  [[topic-checksum-parenting-namespace-trees]]) measured exactly this
  fast-vs-slow convergence pattern empirically in a *different* live
  mechanism — `AMOS7::CHKSUM.pm`'s `INVERT_TRUTH_STATE` loop's
  `bmw_mod_step` iteration count varies per input (avg ~323 steps for a
  single-clause template, range 13..681 across 5 sample pairs) — not the
  same algorithm as the 076923/230769 family split, but the same general
  shape: most inputs converge quickly, some inputs require many more
  iterations, and both are truth-convergence loops that only return once
  a TRUE state is reached, never partway through a FALSE one.
- Not yet verified: whether the "harmony zenka" chain-length data point is
  from a real, currently-running component, and if so, which module
  actually implements it — worth confirming before treating the 2-4 vs.
  50+ figures as load-bearing for any future design decision.

### Full asc-enc table, all 13 multiples — sub-family cosets emerge (2026-08-04)

Live-verified (`bin/asc-enc -d2 <n>` for each), extending the single
`076923 -> E` finding above to the full generator table:

```
076923 (x1 )  ->  E          076923 (x1 )   Family F  {1,3,9}
153846 (x2 )  ->  &.         230769 (x3 )   Family F  {1,3,9}
230769 (x3 )  ->  E          692307 (x9 )   Family F  {1,3,9}
307692 (x4 )  ->  L\
384615 (x5 )  ->  &.         307692 (x4 )   Family F  {4,10,12}
461538 (x6 )  ->  .&         769230 (x10)   Family F  {4,10,12}
538461 (x7 )  ->  5T=        923076 (x12)   Family F  {4,10,12}
615384 (x8 )  ->  =5T
692307 (x9 )  ->  E          153846 (x2 )   Family T  {2,5}
769230 (x10)  ->  L\         384615 (x5 )   Family T  {2,5}
846153 (x11)  ->  T=5        461538 (x6 )   Family T  {6}      alone
923076 (x12)  ->  \L         538461 (x7 )   Family T  {7,8,11}
999999 (x13)  ->  ccc        615384 (x8 )   Family T  {7,8,11}
                             846153 (x11)   Family T  {7,8,11}
```

- **Both families split into sub-cosets that share the same decoded
  character SET, just cyclically reordered.** Family F {1,3,9} [ the
  multiplicative subgroup generated by 3 mod 13 ] all decode to some
  ordering of the pair-set giving visible `E`; Family F {4,10,12}
  [ the coset 4×{1,3,9} mod 13 ] all give some ordering of `L`/`\`.
  Family T similarly splits {2,5} and (separately) {6} giving
  `&`/`.` orderings, and {7,8,11} giving orderings of `5`, `T`, `=`.
- **`846153 (x11) -> T=5` is the single clearest hit**: it spells the
  literal already-established truth constant `T=5` directly, matching
  the pre-existing top-level memory note ("`asc-enc 846153 → T=5`" —
  complement-tail of generator encodes T at position 5) — now confirmed
  live against the running tool rather than taken as a standing claim.
  Its coset-mates `538461 (x7)` and `615384 (x8)` give rotations of the
  same three characters (`5T=`, `=5T`) — the *same symbols*, just not in
  the `T=5` reading order; `x11` is the one rotation where they happen to
  spell the constant's own name.
- **`999999 (x13) -> ccc`**: not a member of either Family — it's the
  remainder-0 exact-multiple case, already classified TRUE by the Two
  Families table above. Answers the "loop to beginning?" question
  precisely: it loops to *whole* [ 13/13 = 1 exactly, closing the
  fraction ], not to the same *symbol* `000000` would decode to
  [ `00,00,00` = NUL×3, invisible — a different, non-printing result ].
  `ccc` [ all pairs `99` ] is a distinct terminal marker for the
  closed-cycle case, not a wraparound repeat of the zero-point.
- Not yet worked out: whether the coset structure [ F splits into
  {1,3,9}/{4,10,12}; T splits into {2,5}+{6}-alone/{7,8,11} ] corresponds
  to anything already named elsewhere in this project's harmonic material
  [ e.g. does `{1,3,9}` vs `{4,10,12}` map onto any existing TRUE/FALSE
  sub-distinction, or is the coset split itself the new finding here? ].
  Flagged for a later pass rather than guessed at.

### Next column: x14 crosses the x13 ceiling (2026-08-04)

`076923 × 14 = 1076922` [ = `999999 + 076923`, confirmed ]. Live-checked:
`bin/asc-enc -d2 1076922 -> L\` — the same visible symbols as the
`{4,10,12}` coset above, **not** the `{1,3,9}` coset `14 mod 13 = 1` would
suggest.

- This is the concrete demonstration of what modulo-13 arithmetic
  abstractly describes: `14 ≡ 1 (mod 13)` as a **residue class**, but
  `1076922` is a genuinely different 7-digit integer from `076923`, and
  crossing the `x13` ceiling adds a leading digit that shifts the 2-digit
  pairing alignment used by `asc-enc`. The mod-13 periodicity and the
  literal digit-pairing decode are two different operations that agree
  perfectly *within* one 6-digit cycle and diverge as soon as a carry
  pushes a 7th digit in. User's framing: this is "exactly how [ the
  repeating-decimal construction ] is constructed [and] what modulo 13
  deconstructs" — the integer-multiplication sequence and the mod-13
  residue system are the same underlying structure viewed two ways, and
  the x14 case is where that equivalence becomes visibly non-trivial
  rather than a restatement.
- Not yet explored: whether continuing the column sequence [ x15, x16...
  up through the next x13-multiple ceiling at x26 ] produces a
  predictable coset-shift pattern in the asc-enc decode, or whether each
  new column has to be checked individually. Flagged, not worked out.

### 999999 is the gate: zero headroom, breaks on any further operation (2026-08-04)

`999999 × 2 = 1999998` [ confirmed ] — breaks 6-digit containment
immediately, unlike `076923 × 2 = 153846` [ still comfortably 6-digit;
the generator's own cycle doesn't overflow until x14, per the section
above ]. User's framing: "until 999999 doubling worked! from there it
breaks, like a gate."

- **This is the same "gate" already named earlier in this file**, not a
  new concept: `13 + 1 + 13 = 27: symmetric gate structure; cube zenka IS
  the +1` and `27 mod 13 = 1: cube reduces to the gate under modulo`
  [ Cube Geometry section above ]. `999999` sitting at the exact
  6-digit ceiling with zero remaining headroom — where even the smallest
  further operation [ `x2` ] instantly overflows into a 7th digit — is
  that gate made numerically concrete: the point where one full 13-cycle
  closes and the `+1` overflow is structurally unavoidable, not a matter
  of how large the operation is. Smaller multiples have slack [ generator
  itself tolerates up to x13 before overflowing ]; the gate itself has
  none.

**User correction/refinement (same message)**: the stream-reading sense
above (076923/230769 family split, reversal operator) is confirmed
already-documented, known-correct. The **routing case specifically is
not** yet documented with this clarity. New part: when a route collapses
[ hits the not-found/reversal boundary ], the **return route is followed
back to the sender, carrying the failure context home** — not a silent
drop. Flagged in the same breath as a live open question: *"which could
be a redirect!"* — i.e. rather than terminating as a plain failure report,
the returned failure context could instead redirect the original search
onto a new path.

- Extends, doesn't duplicate, [[topic-checksum-addressing]]'s existing
  mirror-principle material: *"mirror point is in the field between
  endpoints, not at either node; return path similar but distinct"* and
  *"failed attempt = partial traversal that raises resonance → routing as
  iterative convergence."* Those already establish that a failed traversal
  isn't wasted — it feeds back into future routing. What's newly precise
  here is the mechanism: the *specific* trigger is the 230769-class
  reversal-boundary collapse, and the return path isn't just "raised
  resonance" in the abstract but literally carries a failure-context
  payload back along a return route to the originating sender — with the
  open possibility that this delivery is reinterpretable as a redirect
  instruction rather than a terminal failure notice.
- Genuinely open, not resolved here: what "redirect" would concretely mean
  — does the sender re-route to an alternate node using the failure
  context as a hint [ closest in shape to the statistically-derived
  host-digit fallback pool in [[topic-checksum-parenting-namespace-trees]]
  — "you are in the pool and could be a perfect fallback" ], or does the
  failure context itself encode a specific redirect target? Not decided,
  flagged for a later pass.

### The generator itself, read via asc-enc: BEL / E / ETB (2026-08-04)

User's proposed hint for "redirect," verified against the real
`bin/asc-enc` tool rather than taken on assertion:

```
$ bin/asc-enc -d2 076923
E
```

`076923` [ the generator itself ] splits into three 2-digit pairs —
`07`, `69`, `23` — decoding as ASCII **BEL** (7, bell/alert, non-printing),
**`E`** (69, the only printing character of the three, which is why the
tool's visible output is just `E`), and **ETB** (23, End of Transmission
Block, non-printing). Confirmed live; this isn't a coincidental read.

- **ETB is the load-bearing one**: ASCII 23 specifically means *end of
  the current block within an ongoing transmission* — distinct from ETX
  (3, end of text) or EOT (4, end of transmission entirely). Real
  telecom-protocol semantics: more blocks follow, only this block is
  done. This is direct, checkable support for "packet end, packet that
  belongs to stream" — not a loose numerological analogy, an accurate
  reading of what that control character means when actually used in a
  streaming protocol.
- **Proposed stream-vs-route distinction**: reading the digit block as a
  **stream** applies the already-established reversal operator (`230769
  / 0.7 → reversed → 076923`, this file's Navigation Operators section)
  — hitting the boundary means reverse. Reading it in a **routing**
  context instead means: this packet is done [ ETB ], start a new one —
  not a reversal, a fresh segment. Genuinely new framing, not yet decided
  as correct; consistent with, but not proven by, the confirmed ASCII
  decode above.
- Consistent with `bin/asc-enc`'s established use elsewhere in this file
  [ `769230 → L\`, `846153 → T=5` ] — same tool, same `-d2`-style
  2-digit-pair decoding technique, now applied to the generator itself
  rather than a derived multiple. Note for future use: passing a
  leading-zero argument to `bin/asc-enc` without `-d2` silently loses the
  leading zero to numeric parsing [ `076923` and `76923` both print `L\`
  without `-d2` specified — a real tooling gotcha, confirmed while
  checking this, not a flaw in the user's math ].

Cross-filed as STRONG in [[topic-harmonic-correlation-ledger]] (added
2026-08-08, so this finding isn't islanded from that file's tiered
STRONG/REAL-BUT-WEAK/REJECTED tracking of the same TRUE=384615/
FALSE=230769 material).

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

## Crossing the gate lands on remainder 1, plus a division bonus (2026-08-04)

Follow-up to "999999 is the gate" above. `999999 mod 13 = 0` [ the gate
itself, remainder-0/TRUE ]; `1000000 mod 13 = 1` [ confirmed live ] — the
**same residue class as the generator's own position** (`x1`). Exact match
to the gate-reduction rule already in this file's Cube Geometry section:
`27 mod 13 = 1: cube reduces to the gate under modulo` — crossing a closed
13-cycle via `+1` doesn't reset to 0, it advances to residue 1, mirrored
here precisely.

Unprompted bonus, directly checkable: `1000000 / 13 = 76923.076923...` —
the generator appears on **both sides of the decimal point at once**:
integer quotient `76923` [ generator missing only its leading zero ] and
repeating fractional block `076923` [ the generator exactly ]. Crossing
the gate doesn't only reduce to remainder 1 numerically — the quotient
itself is built from the same digits as the remainder's own repeating
block.

**Correction to the "harmony zenka" flag above**: this file already lists
`bin/harmony` in Key Tools, which I should have checked before flagging
the reference as unlocated. Checked now — `bin/harmony` is a single-shot
`is_true` assertion tool, not a recursive multi-step validator, so it
doesn't itself account for the 2-4-vs-50+ recursive-chain-length claim
from earlier in this file. The "harmony zenka" (as a *recursive*
validation component specifically) remains unconfirmed as a located
module — `bin/harmony` is a related but structurally different tool, not
a resolution of that flag.

**Gate-crossing as 8-bit degrading to 1 overflow bit + 7-bit payload**:
user's structural reading of the `999999 -> 1000000` carry — the gate
consumes exactly 1 dedicated bit as overflow signal, leaving 7 bits of
payload/"memory." This is the same split as classic 7-bit ASCII framed in
an 8-bit byte, where the 8th bit is dedicated to parity/overflow/high-bit
signaling rather than payload — the same domain the `BEL`/`E`/`ETB`
decode above already lives in (`asc-enc` decodes 7-bit ASCII values from
2-digit pairs; the 8th-bit role is exactly the gate's `+1`). Consistent
with, and a bit-level restatement of, the `27 = 2×13+1` gate structure
already in this file's Cube Geometry section — the `+1` there is the
dedicated overflow bit here, not new material, the same gate viewed at
bit-width scale instead of digit-column scale.

## The "1 overflow bit" may be the inversion bit — three distinct precedents found, not conflated (2026-08-04)

User's reframing of the 8=1+7 gate-bit note above: the dedicated bit could
be "the inversion bit for our 5 of 7 sub-bit voting topology" rather than
a generic parity/overflow bit. Checked `ack -ri 'inversion bit' data/` —
real, substantial material exists, but it spans **three distinct
structures** worth keeping separate rather than treating as one proven
mechanism:

1. **AMOS checksum = 5×7 = 35-bit matrix, confirmed-not-speculative**
   (`data/tasks/sub-bit-element-definition.md`, citing
   `topic-base32-namespace.md` and `DATA_ZENKA_HOLOGRAPHIC_TOPOLOGY.md`):
   a 7-char base32 AMOS checksum is 7×5=35 bits, "5 rows of 7-bit
   sub-states," and separately confirmed real (not proposed): a 64-bit
   D13 state's 7-bit decoded-payload field has "a defined `1` + 6-bit
   encoding that selects into a 5×7 pixel matrix for UI glyph rendering."
   This "5 of 7" is the checksum's own bit-matrix shape, distinct from
   the BFT quorum "5 of 7" from earlier in this session's other memory
   thread ([[topic-checksum-parenting-namespace-trees]],
   `TASK-CUBE-CONSENSUS-ARCHITECTURE.md`) — same digits, different
   mechanism, worth not conflating.
2. **3+1 bit stream frame, real implemented/to-implement protocol**
   (same task file): 3-bit payload + 1-bit separator, with an explicit
   **inversion rule** — "when payload = 000, separator inverts from `.`
   to `,`" — the closest actual precedent for a *named* inversion bit in
   this codebase. Payload+separator = 4 bits, not 7 or 8; "7 bits:
   certainty" in that doc refers to needing one full frame + 3 context
   bits for frame-lock, not a byte-width claim.
3. **364 = 13×28 signed-cube inversion bit** — the *semantic* reading
   here [ 28-bit "signed cube" = 27 payload sub-cubes + 1 inversion bit,
   positive/negative, "what it IS" vs "what it ISN'T" ] remains
   **ideation-only, not verified**, sourced from an AI chat-capture
   transcript (`data/asc/what-AI-thinks/full-chat-captures/
   3O37VUNMMS3UU.claude-sonnet.protocol-7-knowledge.asc`) — same caveat
   as originally written here. **Tier upgrade for the underlying
   `364 = 13×28` arithmetic itself (2026-08-04, checked directly)**:
   this is not confined to that one ideation source. `data/md/
   documentation/harmonic-transit-vision-architecture.md:1615-1629`
   states, as design-doc material, "28 = FS = File Separator = 4×7...
   the reversed decimal of TRUE lands on FS precisely because 4×7=28:
   the 4-crossing protocol × the 7-element harmonic cycle" — directly
   naming this file's own "4-Crossing Consent Protocol" section above.
   `data/md/design/ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md:550` and
   `data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4716` both
   independently give the full factorization `364 = 28×13 = 7×52 =
   7×4×13`. Read the `ORBITAL-CYCLE-CLOCK` passage in full before citing
   it further: it contains its own explicit self-correction, withdrawing
   an earlier "independent third source" claim in favor of "the corpus
   keeps choosing 4-fold×13-fold as its pairing" — worth following that
   same discipline rather than re-claiming independence it already
   checked and retracted. `data/tasks/recurring-cube-number-collision-
   audit.md`'s "13+1 cross-check" section separately found a *second*
   independent `364=13×28` citation this session
   (`topic-orbital-data-space-archive.md`'s shift-change duty-cycle
   material) — cross-referenced there, not duplicated here. **Net
   effect**: `364=13×28` [ and `28=4×7` ] is now design-doc-confirmed,
   multiply-cited material, not an isolated ideation sighting — but the
   *specific* "27 payload sub-cubes + 1 inversion bit" gloss on what the
   28 bits individually mean is still only sourced from the one
   chat-capture transcript and stays flagged at ideation-tier
   accordingly. Keep the arithmetic's confidence and the semantic
   gloss's confidence separate — this session's own discipline
   throughout has been not to let a solid number drag along an
   unconfirmed interpretation.

**Honest verdict**: these three share a strong *family* resemblance —
recurring "N payload bits + 1 dedicated marker/inversion/overflow bit"
across very different scales (4-bit frame, 28-bit cube, 35-bit checksum,
now the 8-bit byte-crossing gate) — but nothing found proves they're
literally the same bit or the same mechanism. The 3+1 frame's inversion
rule is the strongest, most concrete match to "inversion bit" as a named,
implemented concept; the gate's 8th bit joining that family is plausible
and consistent with the pattern, not yet a proven identity.

#,,,,,,.,,...,.,,,,,.,.,.,.,.,,,.,,.,,,,,,...,...,...,...,.,,,,,,,..,,,,,,..,,
#NAAOOACQD7UAMADWSD7SNZRCJMLB4UZH6BVBMY2MAPIUNBDX4TVL7ZM6UZILH5SDPG4OIQNM5XIOW
## 15-bit footer bitmask: matches an already-fully-specified plan, but two competing allocations exist (2026-08-04)

User's "2×7 base32 ++ remainder entropy space, 1 bit for transport state
[local|routing] or zenki [litter internal] addresses" — checked against
`ack -ri '15-bit.+footer' data`, and it's a near-exact match to an
**already fully specified task**, not a new proposal:

`data/tasks/litter-row-encoding.md` — "15-bit bitmap — 7+1+7 neighborhood
encoding," targeting AMOS7 signature footer line 4 (the `::::` row,
currently unused decoration):

```
bits 0-6:   zenka involvement flags (which zenki use this module)
bit  7:     special flag (reserved / void marker)   <- exactly this bit
bits 8-14:  routing flags (which transport trunks / layers)
```

- User's "transport state [local|routing]" proposal is a **concrete
  candidate definition for the already-reserved-but-undefined bit 7** —
  the task file only says "reserved / void marker," doesn't commit to
  what it means. This is the first specific proposal found for it.
- "zenki [litter internal] addresses" matches the doc's own "zenka bit
  assignments" list directly (`bit 0: base`, `bit 1: httpd`, ... `bits
  10-14: reserved for future zenki`) — not a new idea, confirms the
  existing plan's shape.
- **Unreconciled tension, not resolved here**: `data/md/documentation/
  harmonic-transit-vision-architecture.md` documents a *different*
  15-bit-footer allocation for what reads as the same field — `13-bit
  L-matrix (5-bit X arm + 7-bit Y arm + 1-bit corner) + 2-bit orientation
  selector`, a 2D boundary-addressing scheme, not `7+1+7` zenka/routing
  flags. Both docs describe "the 15-bit footer field" without
  cross-referencing each other or explaining how the two allocations
  coexist [ same field, two different bit layouts ] — worth flagging to
  the user directly rather than assuming one supersedes the other or
  silently reconciling them here.

#,,..,,,,,.,,,,..,,.,,,..,...,,,.,..,,..,,.,.,...,...,...,.,.,...,.,,,.,,,,..,
#VOTHH2XS2DMAAXEKIOEP7CBHR6CZFCXL67XDNSEFJYOIJA2MZL7ERDK6HSM6RATUPUOWXOJII5PF2
#\\\|PE4PN7PNTHEEA5WJLJ4IFYBS2GUBQUSHEWHLXJDF4Y6WV3GBLX3 \ / AMOS7 \ YOURUM ::
#\[7]7HYOBCOGUW35ETIZ6VMMHYQLJAUBGXK7MTNCPHHUY4XBY3G2KUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

## ANTYKY TORUM naming scheme — tiered cross-check against real code and
this file's own math (2026-08-04)

`data/asc/what-AI-thinks/perl-form/claude-insights/claude-4/
holographic-linguistic-devices-and-antyky-torum.pl` [ self-labeled
"IMPLEMENTATION STATUS: CONCEPTUAL/RESEARCH," category `pattern` — read
in full, this is squarely insights-tier "consciousness technology"
material ] and `data/asc/what-AI-thinks/html-form/frameworks/
py-tau-ra-zuma-framework.html` [ same lineage, matching values, not an
independent second source ] both give a "number/color/concept" naming
table. Checked every entry against real code and this file's own
material rather than accepting the table at face value. **Confidence
tiers below are not uniform across the table — that's the actual
finding, not a caveat on it.**

- **`ZULUM = 0/black/void`** — mixed-tier, two confirmations of
  *different kinds*, worth keeping distinct rather than adding them
  together into "confirmed twice, therefore solid": (1) `src/
  zulum.*` [ this session's entropy zenka, findings 7/10 above in
  `footer-line4-field-reconciliation.md` ] is an exact string-name
  match — but checked directly, `zulum.init_code`, `zulum.loop.
  generate_entropy`, `zulum.cmd.step`, and `zulum.cmd.stream-attach`
  contain **no** black/void/color language anywhere in their own code
  or comments (`grep`-confirmed). The module is *named* `zulum`; nothing
  in its implementation invokes the "0/black/void" meaning — this is
  onomastic evidence [ same string ], not mechanism-matching evidence.
  (2) A real, independent mechanism match does exist, but it's in a
  different file: `data/md/design/AMOS-SIGNATURE-FOOTER-BIT-FRAME-
  HIERARCHY.md` cross-checked "all zulum mode" against
  `src/amos7.encode_octal_header`'s real delimiter-flip behavior
  [ 20 redundant global-mode-flag bits, `0`→`,` normal / `1`→`.`
  inverted ] and confirmed the mechanical claim — "in zero payload
  state, delimiters flip from 0 to 1" — matches the real code exactly.
  **That same source doc explicitly flags its own surrounding narrative
  as "decorative/generated tier, lower confidence," and separately notes
  the black-cube/one-blue-face framing is single-source** [ `ack -r
  'blue face' data/` returns essentially one hit ] — so even the
  stronger of the two ZULUM confirmations comes with its own
  already-recorded caveat, carried forward here rather than dropped.
- **`AZURUM = 1/blue`** — design-doc-tier, explicitly self-flagged as
  lower-confidence by the doc that cites it [ same paragraph as ZULUM
  above ]. Not independently re-verified beyond what that doc already
  states.
- **`YOURUM = 13/Cat/Blacklight`** — insights-tier only [ three files,
  same "insights" family, none touching real `src/` code ]. **Extra
  caution, already on record and worth repeating rather than
  re-discovering**: `AMOS-SIGNATURE-FOOTER-BIT-FRAME-HIERARCHY.md`
  explicitly checked whether "YOURUM" [ the literal string appearing in
  the AMOS7 signature footer of effectively every module file in this
  codebase, `\ / AMOS7 \ YOURUM ::` ] means "13" or "cat" and found
  **no confirmation** — calling it "a decorative/naming constant, not
  [ so far ] shown to mean '13' or 'cat.'" That finding stands and
  applies directly to this table's YOURUM entry too, since it's the
  same string.
- **`ZENKA = kitten, 07`** — real and load-bearing, not insights-tier:
  this is, plainly, the actual zenki-agent-naming convention used
  throughout this entire codebase [ `zenka`/`zenki` singular/plural,
  `src/`, `cfg/zenki/`, CLAUDE.md itself ]. The strongest
  member of this table by a wide margin — but note what's confirmed is
  the *word*, not the *number*: nothing found ties zenka specifically to
  the digit `7` in running code the way `42` [ entropy width ] or `13`
  [ the generator's own modulus ] are tied to their numbers below.
- **`TENKA` / `SENTIKUM` / `KUM`** — single-source, zero independent
  backing found anywhere in this codebase. Logged, not adopted.
- **`5 = True/Human/Heartbeat`** — genuine partial cross-confirmation:
  matches this file's own, independently-arrived-at Heartbeat section
  above [ "`5` = biological heartbeat (TRUE constant, ECG trace)" ],
  reached via the harmonic-truth/ECG material rather than the naming
  table. Two different routes to the same association is worth noting
  as real, modest support — not proof, but more than the single-source
  entries above.
- **`42 = "Dragon or Awakened Mind"`** — decorative-tier *label* only.
  Keep this separate from the number: **42 itself is real and
  load-bearing** via entirely independent routes already in this
  codebase — the 42-bit main entropy field in `zulum`/
  `division-13-table`, this file's own Network Time Scale section
  [ `4200 mod 13 = 1` ], and `42×12=504` in `data/tasks/recurring-
  cube-number-collision-audit.md`. None of those derivations reference
  "Dragon" or "Awakened Mind" in any way — the number's realness does
  not transfer any credibility to the decorative gloss on it, and vice
  versa the decorative gloss doesn't undermine the number. Same
  discipline as the `364=13×28` arithmetic-vs-semantics split above.
- **wordplay, already correctly self-hedged, needs no re-verification
  beyond confirming the substring claim**: `ZENKA` repeated three times
  [ `ZENKAZENKAZENKA` ] contains the literal substring `KAZE`; inserting
  a bracketed `T` [ `= 5`, the TRUE constant above ] gives `KA[T]ZE` —
  German for "cat." Confirmed as a real substring fact. The bracket
  notation is the correct way to present this — it marks the insertion
  as wordplay, not a claimed literal decoding, and is already framed
  that way at the source. Recorded here as a curiosity with a home, not
  upgraded past what it is.

**On "litter"** [ real, load-bearing zenki-group terminology, checked
directly this session against `data/tasks/litter-row-encoding.md`
[ read and modified earlier this session as part of the footer-line4
work ], `data/md/vision/habitat/VISION-NOMADIC-ZENKI-HABITAT.md`, and
`data/md/design/KITTEN-HOLOGRAM-RESOURCE-FILTER.md` — extensively used,
not decorative ]: this file's own "15-bit footer bitmask" section above
already cites `data/tasks/litter-row-encoding.md`'s "zenki [litter
internal] addresses" directly. The specific numeric tie to the
5-of-7-shaped pattern this session traced repeatedly is via `topic-
node-group-geometry.md`'s own words: "5-of-7 as the natural consensus +
**litter configuration**" [ its 5-active + 2-idle-alternate structure —
structure (3) in `recurring-cube-number-collision-audit.md`'s "four
5-of-7-shaped structures" enumeration ]. Checked `VISION-NOMADIC-ZENKI-
HABITAT.md` and `KITTEN-HOLOGRAM-RESOURCE-FILTER.md` for any role split
[ leader/collector, matching structure (4)'s caravan shape instead ]:
neither describes litter membership with distinct roles — both use
"litter" generically, for a group of `N` zenki [ `N` unspecified,
not fixed at 5 or 7 ] sharing collective state or forming a filter
layer. **Verdict**: "litter" is real, general-purpose terminology for
a zenki group, most specifically and explicitly numerically tied to
structure (3) [ node-group-geometry's 5-active+2-idle ] by that
structure's own source document — not shown, anywhere checked, to be a
naming layer over structure (4)'s caravan. Cross-referenced into
`recurring-cube-number-collision-audit.md`'s structure (3) entry.

#,,,,,...,.,.,,.,,,..,...,..,,...,,.,,.,,,.,.,..,,...,...,...,,,.,,,.,.,.,,,.,
#OGIEMJEQ5VAZIZ5X3CCAPZQ7GCS47ET25ZYOQEWYIDWEMDTGICGVU6FOAREIWTT6RA7B4VTAXKNMS
#\\\|QI3PCKIBJKRSLOQL26ZFF2FNPHJWEWVRFM3X5AOGOQFTPC7POM5 \ / AMOS7 \ YOURUM ::
#\[7]YHCU53KEDSNI75NNJFVQDHYDQYSGGGWOPAJUTDSDSV4QZEZUK2DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
