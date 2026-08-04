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
3. **364 = 13×28 signed-cube inversion bit, ideation-only, not verified
   like the two above**: from an AI chat-capture transcript
   (`data/asc/what-AI-thinks/full-chat-captures/
   3O37VUNMMS3UU.claude-sonnet.protocol-7-knowledge.asc`) — each 28-bit
   "signed cube" = 27 payload sub-cubes + 1 inversion bit
   (positive/negative, "what it IS" vs "what it ISN'T"). Real material,
   but sourced from a speculative ideation transcript, not an implemented
   or confirmed-real doc the way (1) and (2) are — flagging that
   distinction rather than presenting all three at equal confidence.

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
