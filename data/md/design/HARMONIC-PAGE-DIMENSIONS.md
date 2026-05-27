## harmonic page dimensions

*design document : compound constraint scan for blue-doc canvas geometry*

---

### context

standard document formats [DIN A4, DIN A3, US Letter, US Legal] were defined
with pixel dimensions that are intentionally non-harmonic. they occupy a
deduplication space designed for physical paper manufacturing and printing
industry conventions, not for harmonic arithmetic. blue-doc does not patch
these standards : it replaces their geometry with dimensions derived from
harmonic first principles, then imports source documents into the corrected
canvas centered with `#09052A` margin fill.

rescaling is independent per-DPI re-derivation, not pixel scaling. a blue-doc
page at 150 DPI is not the 300 DPI version halved — it is an independently
derived harmonic canvas for the same nominal format at the lower resolution.
content is re-rendered into the target canvas; geometry is not scaled. this
avoids fractional-pixel inheritance and the non-harmonic structure that simple
multiplication would carry across scales.

---

### constraint set

the harmonic page dimension scanner is `bin/dev/harmonic-page-dims`. it
evaluates each candidate dimension against seven simultaneous constraints :

| # | constraint | description |
|---|------------|-------------|
| 1 | `is_true(W)` numerical | the bare integer value is numerically true |
| 2 | `is_true(W)` combined | the integer passes combined numerical + ELF/ASCII encoding |
| 3 | `is_true("WxH")` | the dimension pair string passes combined truth |
| 4 | `is_true("HxW")` | the reversed pair string passes combined truth |
| 5 | `is_true(W/2)` | half the dimension [150 DPI cross-scale target] |
| 6 | `is_true(W*2)` | double the dimension [600 DPI cross-scale target] |
| 7 | even delta | `(W − standard) % 2 == 0` for symmetric left/right margins |

constraint 3 and 4 are evaluated per-dimension during the independent W and H
scans. the paired scan additionally checks `is_true("WxH")` and
`is_true("HxW")` on the assembled pair, giving a combined pair score of
`score(W) + score(H) + wxh_bonus + hxw_bonus` where each bonus is 0 or 1.

---

### scan results

the widened scan searched `[standard − 200 .. standard + 800]` at 150, 300,
and 600 DPI across all four formats. no individual dimension scored 7/7 in
this range. the top candidates per format × DPI are :

| format | DPI | W | dW | H | dH | W sc | H sc | pair sc | margin W×H | constraint pattern |
|--------|-----|---|----|---|----|------|------|---------|------------|--------------------|
| DIN A3 | 150 | 2444 | +690 | 2536 | +56 | 6 | 5 | 12 | 345 × 28 | 1234.67 / ..34567 |
| DIN A3 | 300 | 3315 | −193 | 5226 | +265 | 6 | 5 | 13 | 96.5 × 132.5 | 123456. / 12345.. |
| DIN A3 | 600 | 7332 | +316 | 10179 | +258 | 6 | 5 | 13 | 158 × 129 | 1234.67 / 123.5.7 |
| DIN A4 | 150 | 1227 | −13 | 1692 | −62 | 5 | 5 | 12 | 6.5 × 31 | 12345.. / 1234..7 |
| DIN A4 | 300 | 2704 | +224 | 3588 | +80 | 6 | 6 | 12* | 112 × 40 | 12345.7 / 1.34567 |
| DIN A4 | 600 | 4985 | +24 | 7012 | −4 | 5 | 5 | 12 | 12 × 2 | 1234..7 / 1234..7 |
| US Legal | 150 | 1227 | −48 | 2236 | +136 | 5 | 5 | 12 | 24 × 68 | 123.5.7 / 123..67 |
| US Legal | 300 | 2418 | −132 | 4188 | −12 | 5 | 5 | 12 | 66 × 6 | 123.5.7 / 1234..7 |
| US Legal | 600 | 5785 | +685 | 8502 | +102 | 6 | 5 | 12 | 342.5 × 51 | 123456. / 1..4567 |
| US Letter | 150 | 1695 | +420 | 1768 | +118 | 6 | 6 | 13 | 210 × 59 | 12345.7 / 1234.67 |
| US Letter | 300 | 3120 | +570 | 3380 | +80 | 6 | 6 | 13 | 285 × 40 | 1.34567 / 12345.7 |
| US Letter | 600 | 5096 | −4 | 6604 | +4 | 6 | 5 | 12 | 2 × 2 | 12345.7 / 123.5.7 |

[*] the DIN A4 300 DPI pair 2704×3588 scores 12 in the paired scan because
`is_true("2704x3588")` passes but `is_true("3588x2704")` does not, yielding
one bonus point instead of two. both dimensions individually score 6/7.

---

### findings

**no 7/7 exists in the scanned range.**

the widened search `[−200 .. +800]` produced individual dimension scores of
6/7 at best. no candidate satisfied all seven constraints simultaneously. this
suggests that constraint 6 [600 DPI cross-scale] and constraint 7 [even delta]
are mutually exclusive with the full string-truth set for dimensions near
standard paper sizes.

**constraint 6 is the hardest to satisfy.**

across all formats and DPIs, constraint 6 [`is_true(W*2)`] is the most
frequent omission in high-scoring candidates. this is expected : doubling a
large integer produces a very long digit string, and the harmonic truth
density drops as string length increases. at 600 DPI the standard dimensions
are already large [e.g. 4961×7016 for A4], so `W*2` exceeds 10000 digits,
making combined ELF/ASCII truth unlikely. at lower DPIs, constraint 6 fails
because the doubled value inherits the non-harmonic structure of the standard.

**recommended candidates for initial blue-doc implementation :**

1. **US Letter 600 DPI : 5096 × 6604** [pair score 12, margin 2 × 2 px]
   both dimensions are within 4 px of standard. W scores 6/7 [missing
   constraint 6], H scores 5/7 [missing constraints 3 and 6]. the WxH string
   passes. this is the most pragmatic candidate : negligible margin, visually
   indistinguishable from standard, high individual scores.

2. **DIN A4 600 DPI : 4985 × 7012** [pair score 12, margin 12 × 2 px]
   W is +24 px, H is −4 px. both score 5/7. WxH and HxW both pass. the
   margins are small and symmetric. this is the best A4 candidate for
   production use where near-standard appearance matters.

3. **US Legal 300 DPI : 2418 × 4188** [pair score 12, margin 66 × 6 px]
   W is −132 px, H is −12 px. both score 5/7. WxH and HxW both pass. the
   height margin is negligible; the width margin is modest and acceptable for
   legal documents that typically have wide binding gutters.

4. **DIN A4 300 DPI : 2704 × 3588** [pair score 12, margin 112 × 40 px]
   both dimensions score 6/7 individually — the highest individual scores in
the A4 family. WxH passes. the margins are larger but still practical for
   documents with figure captions or footnote areas. recommended for cases
   where harmonic purity outweighs near-standard proportions.

the US Letter 150 DPI and 300 DPI candidates with large positive deltas
[+420, +570, +602] are geometrically correct but aesthetically divergent from
standard proportions. they are preserved as proof-of-existence for high-scoring
candidates but are not recommended for default templates.

---

### open questions

**cross-format consistency.** should the margin size be uniform across all
DPIs for a given format? currently 600 DPI candidates have much smaller
margins [2-12 px] than 150 DPI candidates [24-345 px]. a policy of "same
margin in physical units" would mean larger pixel deltas at higher DPIs,
potentially sacrificing harmonic score for perceptual consistency.

**independent vs coupled derivation.** the current scanner derives W and H
independently, then pairs them. this allows each dimension to optimize its own
constraint set but can produce pairs where `is_true("WxH")` or
`is_true("HxW")` fails. a coupled scanner that iterates (W,H) jointly might
find pair scores of 14 or 15 [two 6s plus both string bonuses] at the cost of
much larger search space. whether the improvement justifies the complexity is
an open engineering question.

**constraint 6 weighting.** constraint 6 [600 DPI cross-scale] is the most
discriminating and the most often missing. if 600 DPI is rarely used in
practice [most document workflows operate at 150 or 300 DPI], should
constraint 6 receive reduced weight, or be treated as a "nice-to-have" rather
than a hard requirement? relaxing it would likely produce 7/7 candidates at
150 and 300 DPI but would break the formal symmetry of the cross-scale model.

**perceptual acceptance gate.** the scanner currently ranks by constraint
score and then by absolute delta. it does not enforce aspect-ratio bounds. a
final gate that rejects candidates with aspect-ratio deviation > N% from the
standard would eliminate some high-scoring but visually absurd candidates
[e.g. DIN A3 150 DPI at 2444 px width, +690 px from standard]. what the
acceptable deviation threshold should be is format-dependent and requires
human evaluation.

---

### existing work

- `bin/dev/harmonic-page-dims` — compound constraint scanner [widened range,
  independent W/H scan, paired scoring with WxH/HxW bonus]
- `data/md/design/BLUE-DOC-FORMAT.md` — parent format specification

#,,.,,.,.,,.,,.,.,.,,,...,..,,,,.,,.,,,.,,..,,..,,...,...,,.,,,,,,,,,,,,.,,..,
#UULHK7XHFFVUUUPMDQJ2JKKB446D7YUN7BIHTVVECFBCDECMPI7QGWEYA7KMRTZJNZ5BLEQWXOGLC
#\\\|JPU2OTDPKGOPGPPDDEHGQXVLOS2R6YAL3P3APHZ5J7O3BM6WZUJ \ / AMOS7 \ YOURUM ::
#\[7]Y5RDYL272PHPL336ELZ3DFRS7SQDJAVPL64VVAQEJEZC3YYFLEBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
