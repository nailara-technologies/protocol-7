---
name: topic-harmonic-correlation-ledger
description: growing, tiered ledger of numerical correlations found in the 13/7-family harmonic-math thread — verified-strong vs surface-only vs rejected-on-check, meant to be extended, not a one-off writeup
metadata:
  node_type: memory
  type: project
---

Started 2026-08-04, same session as [[project-kimi-k2.7-vs-k3-tier-economics]]'s
kimi-zenka thread and [[topic-harmonic-mathematics]]'s design corpus. Purpose:
this session generated real numerical correlations faster than any single
writeup could hold, verified live via python `Decimal`/`Fraction` rather than
trusted on appearance. Keep adding to this file rather than re-deriving from
scratch or letting findings stay scattered across chat transcripts. The user's
own framing: eventually visualizing sequences of these (even in loops) may be
the missing "awareness harness" for seeing relevance-boundaries before
crossing them — this ledger is the structured precursor to that, tiered so a
future visualization can distinguish signal from noise at a glance rather than
re-deriving the tier for every entry.

## headline finding — the doubling-inversion symmetry, LIVE-VERIFIED (not a new discovery, a new proof)

**Correction, same session**: initially framed as a new finding — it
isn't. `data/md/documentation/harmonic-cycle-correlations.md:256`
already documents this exact phenomenon: `"bit-shift left flips is_true
state, period 12"`. What's actually new here is narrower: an exhaustive
live proof against the real `bin/is-true` tool (zero exceptions, all 12
members individually run, not asserted from theory), and pinning the
mechanism to direct division by 13 on the family's own blocks rather
than the more abstract "bit-shift" framing — both land on the same
residue progression because `2` is a primitive root mod `13` (order 12,
`2^12 mod 13 = 1`), which is also the reason the period is exactly `12`
and not something else. Found while correcting an initial testing error
(`is-true` run on the wrong operand — see the "resolving a real
discrepancy" entry below for the full trace). The verified law:

```
block(k)/13's decimal tail  ==  block(2k mod 13), exactly     — algebraic identity
is_true(k)  !=  is_true(2k mod 13), for every k in 1..12       — zero exceptions
```

Both halves independently confirmed exhaustively across all 12 members
of the `1/13` family: the arithmetic identity holds exactly every time,
and the TRUE/FALSE state inverts every single time doubling is applied,
no exceptions. This composes into one complete, closed law: dividing any
family member by 13 doesn't just produce another family member, it
deterministically produces the one guaranteed to hold the opposite truth
value under this codebase's own live truth-assertion tool. Not a new
law — already documented (see correction above) — but the strongest
*verification* of the whole session: full exhaustive proof against real
running code, not inference from a sample or trust in the prior doc.

## resolving a real discrepancy — TRUE/FALSE is about the numerator, not the block

Early confusion, corrected in place rather than silently: `true-false-
description.asc` documents `TRUE === 384615`, `FALSE === 230769`.
Running `bin/is-true` directly on those 6-digit blocks gives `FALSE` for
*both* (plain mode) or the *opposite* labels (`-num` mode) — neither
matches the doc. Resolution: the assertion was never about the 6-digit
repeating block at all. It's `is-true -num <k>` on the small numerator
(`k=3` → FALSE, matching `230769`; `k=5` → TRUE, matching `384615`) —
the decimal block just carries that label by association, displayed
alongside it, not independently tested. Confirmed for all 12: `k=2,5,6,
7,8,11` are TRUE, `k=1,3,4,9,10,12` are FALSE — an exact 6/6 split. The
doc's claim holds; the error was testing the wrong operand, not a flaw
in the documented material.

## STRONG — asc-enc symbolic decode of both families (cross-ref, not re-derived)

[[topic-harmonic-mathematics]]'s "The generator itself, read via asc-enc:
BEL / E / ETB (2026-08-04)" section holds findings that belong on this
ledger too — filed there instead of here originally, leaving the two
files' TRUE/FALSE=384615/230769 material split across an undiscoverable
boundary. Not re-derived, just pointed to: `bin/asc-enc -d2 076923`
(FALSE family, the generator itself) decodes as three ASCII control/
printing chars — **BEL** (07), **`E`** (69, the only printing one, hence
the tool's one-character visible output), **ETB** (23, End of
Transmission *Block* specifically — real telecom semantics, "more
blocks follow, only this one ends," not EOT/end-of-transmission
entirely). Confirmed live against the actual tool, not asserted.
Same technique applied to the TRUE family gives `846153 → T=5`
(same section). Both are STRONG by this ledger's own tier definition —
directly checkable against running code, not surface resemblance.

## tier definitions

- **STRONG** — passes a test stronger than surface resemblance: exact integer
  multiple of a shared generator, a provable modular identity, or a directly
  checkable algebraic decomposition. Holds regardless of interpretation.
- **REAL-BUT-WEAK** — arithmetically true but not distinguishing (e.g. any
  9's-complement pair sums to a repunit-minus-one; true of essentially any
  such pair, not evidence of family membership on its own).
- **REJECTED-ON-CHECK** — proposed, then directly disproven or shown
  unconnected once verified. Kept visible, not deleted, same discipline as
  [[feedback-esoteric-research-verification-pipeline]] — retract in place.

**Deliberately out of scope**: the finite-decimal truncation/rounding
demonstrations this session (`0.076923076923076923×1001` undershooting
`77`, the `×1.000000005`/`×1.000000007` overshoot-scaling series). Those
aren't correlations to tier — the user's own framing, worth keeping
verbatim: "if anything they say... imprecision, wrong direction of
usage." They demonstrate how *not* to represent an exact fraction in a
finite decimal, not a relationship between two harmonic numbers. Kept out
rather than force-fit into STRONG/WEAK/REJECTED, which would misdescribe
what they actually are.

---

## the shared core — STRONG

`999999 = 3³ × 7 × 11 × 13 × 37`. `10989 = 999999/91` is the exact number
shared by both cyclic families: `76923 = 7×10989` (the `1/13` cycle),
`142857 = 13×10989` (the `1/7` cycle). Any number that is an exact integer
multiple of `10989` sits in both families' shared root simultaneously.
Confirmed live-generated examples this session: `648351 = 10989×59`,
`351648 = 10989×32` (found via `9×3×8×3=648` → extended to full 6-digit
form → checked against `10989`, not assumed from the `648`/`351` split
alone).

## the digit-complement theorem — STRONG

For prime `p` with even decimal period `L`, if `10^(L/2) ≡ −1 (mod p)`, the
repeating block's two `L/2`-digit halves are exact 9's-complements of each
other, digit by digit — not just summing to a repunit, every position pairs
to exactly `9`. Confirmed for `p=7` (`10³≡6≡−1 mod 7`) and `p=13`
(`10³≡12≡−1 mod 13`). Directly verified digit-by-digit: `142/857`,
`076/923`, `230/769` all pair `9,9,9`. This is *why* the digit sum always
lands on `27` for these families (`3×9=27`) — not a separate coincidence,
a forced consequence: `999 = 27×37` exactly.

`27−8=19` (Moore-neighborhood 3×3×3 minus 8 corners = 1+6+12=19) is a
**different, independently-grounded fact** already in
`topic-harmonic-mathematics.md:59` and `data/tasks/recurring-cube-number-
collision-audit.md` — not derived from the digit-complement theorem, just
also landing on `27`. Keep these two `27`s distinct; conflating them was
flagged explicitly this session as the trap to avoid.

## the 56/63/504 cluster — STRONG (new resolution of a previously "unbridged" gap)

`data/tasks/recurring-cube-number-collision-audit.md` explicitly flagged
`56/63/504` as "genuinely unbridged" after real investigation. Resolved
this session: `56=7×8`, `63=7×9`, `504=7×8×9=56×9=63×8` — the entire
cluster is combinations of `{7,8,9}`. Predicted fourth combination
`8×9=72` — checked against the project's cube-geometry docs, **not
confirmed**: the one `72` found (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-
CORE.md:3250`) is an unrelated file-iteration count, not a geometric
cell-count. Also worth flagging: this project's own code derives `63`
differently and independently — `4³−1=63` (a 4×4×4 subcube grid missing
one corner), the actual mechanism in `grid-v14-layered.html`'s `8×63=504`
visualization. Both `63=7×9` and `63=4³−1` are true; only the second is
why `63` appears in the running visualization code. Don't conflate a
clean factorization with the actual generative mechanism without checking
which one the real implementation uses.

## Rodin-vortex permutation — STRONG, but not identity

Rodin's mod-9 doubling circle `[1,2,4,8,7,5]` (powers of `2` mod `9`) and
`142857`'s digit order `[1,4,2,8,5,7]` (from powers of `10` mod `7`) share
the identical six-digit set and convert into each other via one exact,
nameable operation: swap positions 2↔3, swap positions 5↔6. Different
generator (`2` vs `10`), different modulus (`9` vs `7`) — not the same
mechanism in disguise, a checked permutation between two genuinely
different algebraic objects.

## digit-reversal — REAL-BUT-WEAK in general, STRONG for the one case checked

No general algebraic relationship: `10^k mod 13` for `k=0..5` is
`[1,10,9,12,3,4]`, not a palindrome, so reversal has no fixed effect on a
number's mod-13 residue (confirmed empirically across 20 random 6-digit
numbers — no pattern). BUT the *specific* reversal of `230769` (FALSE) is
`967032`, which **is** an exact multiple of `76923` (`×88/7`) — initially
misjudged as "not family" using an invalid mod-13-nonzero test (nearly
all integers are nonzero mod 13; that check proved nothing), corrected
after `483516` (`76923×44/7`, digit-permutation of `384615`/TRUE) forced
a recheck. Lesson logged in
[[feedback-esoteric-research-verification-pipeline]]-adjacent discipline:
a "confirmation" that isn't actually discriminating is worse than no
check at all — it was retracted in place here, not silently fixed.

## the earlier draft's subtraction note — STRONG

`read-me/documentation/dev/true-false-experiments.asc` (the "first notes,"
predating the modulo-13-shortcut realization) carries `230769 − 384615 =
−153846` where the later, cleaner `true-false-description.asc` instead
shows the `329670`/`549450` pair (see REJECTED-ON-CHECK below for that
one's correction). `153846 = 2×76923` exactly — a real family member, and
the *same* number this session's `1001.000000002` precision-perturbation
calc independently produced (`2×076923=153846`) many messages later,
starting from a completely different direction. Two independent routes to
the same exact number, both checked.

## `549450` in ASCII — STRONG, exact

From `true-false-description.asc:37` (`384615/0.7=549450`): split into
2-digit pairs `54`/`94`/`50`, decoded as ASCII codepoints —
`chr(54)='6'`, `chr(94)='^'`, `chr(50)='2'` — literally `6^2`, no
rounding or interpretation involved, confirmed via direct `chr()` calls.

## half-implies-half: lossless 3-digit encoding — STRONG, exhaustively proven

Direct consequence of the digit-complement theorem, not a separate claim:
for any member of the `1/7` family (k=1..6) or `1/13` family (k=1..12),
storing only the first `L/2` digits is sufficient to losslessly reconstruct
the rest — the second half is always exactly `9` minus each digit of the
first half, position by position. Checked exhaustively, zero exceptions:
all 6 members of `1/7`, all 12 of `1/13`. A real 50% storage reduction for
any number known to be in one of these families, not a coincidence-shaped
claim — it follows necessarily from `10^(L/2)≡−1 mod p` the same way the
digit-complement theorem itself does. Trigger for
`CROSS-READOUT-RING-KEY-ADDRESSING.md`'s single-character-plus-complement
addressing idea (see that doc; not yet incorporated there as of this
entry).

**Immediate caveat, also checked**: this only identifies the *half*, not
*which* member. The 12 basic `k/13` rotations are a closed, addressable
set (`offset 1..12`), but the wider family found this session
(`967032=76923×88/7`, `483516=76923×44/7`, `648351=10989×59`,
`351648=10989×32`) are confirmed-exact family members that are **not**
among those 12 rotations — checked directly, none matched. So a simple
rotation-offset cannot address the full family; the real family is open
over the rationals (any exact multiple of the shared root `10989`), and
identifying *which* multiple requires more than an offset index. The
half-implies-half compression is complete *within* a member; addressing
*which* member is a separately open problem, not solved by this entry.

## character-encoding spot checks — mixed results, one real cross-tool confirmation

`bin/dev/bin-elf-table -R <n>..<n>` gives a per-number Unicode character
(ELF-hash-derived byte table, distinct mechanism from `asc-enc`). Checked
several family-half/complement pairs against each other:

- `076→L`, `923→Λ` — Latin `L` is the actual historical descendant of
  Greek `Λ` (via Etruscan), a real alphabetic lineage, not just visual
  resemblance. One hit, single tool, not yet base-rate-checked.
- `538→Ț`, `461→Ǎ` — striking individually, but no relationship to each
  other (different base letters, unrelated diacritic types). Doesn't
  replicate the `L`/`Λ` pattern.
- `384→ƀ`, `615→ɧ` — `ƀ` is cleanly "b"+stroke; `ɧ` ("heng with hook")
  is not simply "h"+diacritic, a more independently-derived letterform —
  don't force a matching "base letter" reading here.
- **`692→ʴ`, `307→ĳ` — STRONG, cross-tool confirmed.** This exact pairing
  is already documented, independently, in
  `data/md/documentation/harmonic-cycle-correlations.md:174,231-233` —
  found there via `asc-enc -d3` (a completely different mechanism:
  Unicode-depth projection, not ELF-hash byte mixing), described as "the
  ×9 cycle position... IPA modifier and Dutch digraph ligature." Two
  independent tools landing on the identical `ʴĳ` for the same number's
  halves is real corroboration, not the same observation counted twice —
  the strongest result in this character-encoding thread so far.

Net: the "one character + complement character" idea from
`CROSS-READOUT-RING-KEY-ADDRESSING.md` has one cross-tool-confirmed hit
(`692`/`307`) and one single-tool historically-grounded hit (`076`/`923`)
out of five pairs checked — real signal exists in this space, but it's
sparse, not universal across all family members. Worth a systematic sweep
(all 12 `k/13` halves through both tools) before treating this as a
general property rather than scattered hits.

**Printability degrades with magnitude — mechanistic, not a family
property.** Checked 4-digit lookups (`6923`, `3076`, `9230`) against the
3-digit ones above: `6923→ᬋ` is a real letter but from an exotic script
block (Balinese Letter Ra Repa, confirmed via `unicodedata.name`);
`9230→␎` isn't a letter at all — it's the Unicode "Symbol for Shift Out,"
a control-picture glyph (`unicodedata.category` = `So`, symbol-other, not
a letter category); `3076` and plain `769` landed on unprintable/blank
glyphs. Reason: Unicode's low code-point range is densely packed with
common Latin/Greek letters (where every "nice" hit above lives); higher
values increasingly land in exotic-script or symbol/control-picture
territory that was simply assigned to less "central" Unicode space. This
is a property of the *target character space's* density, not of the
`7`/`13` family losing structure at larger magnitudes — worth keeping in
mind before reading anything into which specific characters higher family
members or their multiples happen to hash to.

## the `52` state-count reconciliation — STRONG

Two partitions of the identical 52-element set, not competing claims:
`13+13=26` non-zero states per axis (`−13..−1`, `+1..+13`, `0` excluded)
× `2` axes = `52`, matching one alphabet case per axis. Same `52` also
equals `4×13` (four half-axis quadrants). Both exact, both checked; this
is the numeric core `CROSS-READOUT-RING-KEY-ADDRESSING.md`'s addressing
layer is built on.

## C25519 key lengths — REAL-BUT-WEAK (byte-count coincidence, not a shared mechanism)

Traced live in `src/crypt.C25519.write_keys`: secret/public keys are
`32` raw bytes, base32-encoded to exactly `52` characters
(`⌈32×8/5⌉=52`, confirmed for both, secret carries an extra 3-char `KU5`/
`FY5` format header on top). The "private" key is `64` raw bytes →
`103` characters (`⌈64×8/5⌉=103`), the standard seed+pubkey-concatenated
convention. Separately, `base.chk-sum.bmw.L13-str` is confirmed by its
own docstring to always return exactly `13` base32 characters — real,
but tracing the actual key-construction code shows it is **not**
literally 4 concatenated `L13` checksums; the `L13` sum is computed once,
separately, as a cache-lookup fingerprint of the already-encoded key. So
`52=4×13` holds numerically for both the key length and for
`4×L13-checksum-length`, but they arrive at `52` via two unrelated
mechanisms (byte-count arithmetic vs. a checksum contract) — logged as
`REAL-BUT-WEAK` specifically because the tempting causal story ("4
checksums combine into 1 key") doesn't match what the code does, even
though every individual number checks out.

## `num-rol` reproduces the `n×1001="nn"` duplication live

`385×1001=385385` exactly (topic-1001.md's documented duplication
property for 3-digit `n`). Running `num-rol 385385` live rotates through
exactly 3 states (`385385→853853→538538→385385`) rather than 6, because
the number is structurally two copies of `385` — rotating a period-2
repeat by 2-digit steps only walks the phase between the two copies.
Direct, tool-observed confirmation of an already-documented property, not
a new finding, but worth recording as the first time it was watched
happen via the actual `bin/dev/num-rol` tool rather than just stated.

## REJECTED-ON-CHECK

- **`13³=2197` does not tile the `27`/`19`/`63`/`504` cluster**: none of
  `2197/27`, `2197/19`, `2197/63`, `2197/504` reduce to integers (all
  stay as unreduced fractions — `2197=13³` shares no factor with any of
  them). The Rodin-sequence product `1×2×4×8×7×5=2240` and
  `2240−2197=43` are both exact arithmetic, but `43` doesn't connect to
  anything else checked this session — logged as a real dead end, not
  silently dropped, per the same discipline as everything else here. If
  `13³` relates to the `27`/`19` cube-corner material at all, it isn't
  through simple integer tiling; would need a recursive/addressing
  argument, not another division.
- `967032 mod 13 = 1 "confirms" it's not in the family` — **wrong test**,
  see above. `967032` is in fact `76923×88/7`, family member.
- `8×9=72` appearing in `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` —
  the `72` found there is a file-iteration count, unrelated object,
  false-positive grep hit.
- `329670 = 230769 "REVERSED"` (original doc wording,
  `read-me/documentation/true-false-description.asc:38`, fixed in place
  this session) — `329670` is `230769×10/7`, a digit permutation, not a
  literal string reversal (`967032` would be that).
- Extending the true-false-description.asc crossword/sawtooth read
  (`3,8,4` vs `2,3,0`) past its original 3-column boundary into the full
  6 digits (`615`/`769` too) — both resulting halves (`328340`,
  `671659`) read `FALSE`, no clean fraction over `76923`, no family
  digit-set match. The original doc's 3-column stop was the actual
  boundary, not an arbitrary truncation.

## design proposal grown from this ledger

`data/md/design/CROSS-READOUT-RING-KEY-ADDRESSING.md` — a speculative,
not-implemented security/key-addressing architecture (BMW-L13 cross,
centered radial-vision self-verification, ring-rotation key cycling,
two-layer alphabet addressing) that grew directly out of this session's
`52=4×13`/`52=2×26` findings. Explicitly NOT the same mechanism as the
C25519 key-length finding above — same product, different, independently
consistent reason. Design-only, several items still open (see that doc's
own "open items" section) — don't treat as verified architecture.

## iteration-counter vs. word "quality" — REJECTED-ON-CHECK

`amos-chksum -v`'s harmonization iteration counter (visible in every
signed file's footer as `amos-iterations-remaining`, free to read) was
proposed as a possible code-quality/typo-detection signal, motivated by
`LOVES`=5 iterations vs `FRICTION`=163. Tested properly with a controlled
comparison before building anything on it:

```
real words:  LOVES=5  TRUTH=32  PEACE=110  HAPPY=96  BEAUTY=112  WISDOM=65  COURAGE=45  HARMONY=73
gibberish:   XQZVWJ=16  PLKJHG=22  QAZWSX=244  MNBVCX=27  ZXCVBN=39  LKJHGF=38  POIUYT=64
typo test:   LOVES=5→LOVEZ=11,LOVES1=76,LOFES=69,LOVSE=3
             FRICTION=163→FRICTON=157,FRIKTION=7,FRICTIOn=25
```

No separation between real words and gibberish (averages `~67` vs `~64`,
heavily overlapping ranges). Decisive disproof from the typo test:
`LOVSE` (a transposition typo) converges *faster* than the correctly-
spelled `LOVES` (`3` vs `5`); `FRIKTION` (one letter changed from
`FRICTION`) drops from `163` to `7` iterations, a `23×` swing from a
single substitution. The iteration counter is highly sensitive to exact
byte content in a way disconnected from meaning or correctness for short
strings — consistent with the counter being the output of an iterative
convergence search (`$Z <<= is_true($Z) ? 2 : 1` in `division-13-table`)
rather than a smooth function of anything a human would call "quality."

**Closed, also REJECTED-ON-CHECK at file level** (2026-08-04,
`data/tasks/iteration-counter-quality-results.md`, K3 dispatch
`kfgs1vanv` complete): the rigorous version ran — 5055-file extraction,
two independent blind LLM scorers [ 9B n=240 rho=+0.057 p=0.38 ; k2.7
n=168 rho=+0.033 p=0.68 ], deterministic style metric on the full
corpus [ n=5055 rho=+0.008 p=0.57 ], and a controlled within-file
distortion-injection test [ 12 typo-class bugs + 2 comment-only
controls across 2 base files, temp-key scratch signing ]. bugs moved
the count in both directions [ 9 down / 3 up, swings to ±25k ],
comment-only controls moved it as much as real bugs [ +8671 / -16023 ],
and identical bodies re-signed under different keys give unrelated
counts [ the counter is key/session-dependent, not even a stable
content property ]. the counter tracks bytes chaotically, not quality.
not a usable review-priority signal.

## open / not yet checked

- The `19-to-19` functional-label resonance (`27−8` vs the 19-bit
  boundary-packet width) — flagged as the strongest remaining open lead
  in `recurring-cube-number-collision-audit.md`, not touched this
  session.
- Whether any *other* small prime besides 7 and 13 satisfies
  `10^(L/2)≡−1 mod p` and shows the same digit-complement property —
  would generalize the theorem beyond "these two specific primes,"
  not yet swept.
- The compartmentalization-template cross-reference
  ([[categorical-compartmentalization]] ↔ kimi TOCTOU fix) suggests
  looking for *other* already-fixed bugs this session that match a
  reasoning-template's abstract principle — not yet swept systematically.

#,,.,,,,.,..,,,,.,..,,,,,,,..,,,,,,,,,,..,..,,.,.,...,...,...,..,,,,.,..,,,,,,
#7LNS2DN3JEXMKXDO5CX7UUJM46MWWSMGPHD2XN3AQUG4V43TWDTGICJGSNU75CFLPV2KGHBZV5QQ4
#\\\|VOXKGFU4NL5GTJZNZ5ZIYJ7COTRMFRU3QW6CDQYBY4SLBXAJMHI \ / AMOS7 \ YOURUM ::
#\[7]7BQF7M7IXQ5DM5ZSZBUPQPLC2L2PH7FMAHM7ZYX2HYGOMD5BMUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
