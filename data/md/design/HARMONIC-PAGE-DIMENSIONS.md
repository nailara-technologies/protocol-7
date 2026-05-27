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
evaluates each candidate dimension against ten simultaneous constraints :

| # | constraint | description |
|---|------------|-------------|
| 1 | `is_true(W)` numerical | the bare integer value is numerically true |
| 2 | `is_true(W)` combined | the integer passes combined numerical + ELF/ASCII encoding |
| 3 | `is_true("WxH")` | the dimension pair string passes combined truth |
| 4 | `is_true("HxW")` | the reversed pair string passes combined truth |
| 5 | `is_true(W/2)` | half the dimension [150 DPI cross-scale target] |
| 6 | `is_true(W*2)` | double the dimension [600 DPI cross-scale target] |
| 7 | even delta | `(W − standard) % 2 == 0` for symmetric left/right margins |
| 8 | `terminates_base10(W/H)` | the width-to-height ratio has a terminating decimal expansion |
| 9 | `is_true(ratio_str)` | the decimal ratio string `sprintf("%.14g", W/H)` passes combined truth |
| 10 | `terminates_base10(H/W)` | the inverse ratio has a terminating decimal expansion |

constraint 3 and 4 are evaluated per-dimension during the independent W and H
scans. the paired scan additionally checks `is_true("WxH")` and
`is_true("HxW")` on the assembled pair, giving a combined pair score of
`score(W) + score(H) + wxh_bonus + hxw_bonus` where each bonus is 0 or 1.

---

### scan results

the widened scan searched `[standard − 200 .. standard + 800]` at 150, 300,
and 600 DPI across all four formats. no individual dimension scored 8/10 or
higher in this range. the top candidates per format × DPI are :

| format | DPI | W | dW | H | dH | W sc | H sc | pair sc | margin W×H | constraint pattern |
|--------|-----|---|----|---|----|------|------|---------|------------|--------------------|
| DIN A3 | 150 | 2350 | +596 | 2836 | +356 | 6 | 6 | 14 | 298 × 178 | ..34567.9. / 1234..7.9. |
| DIN A3 | 300 | 3315 | −193 | 5226 | +265 | 7 | 6 | 15 | 96.5 × 132.5 | 123456..9. / 12345...9. |
| DIN A3 | 600 | 7332 | +316 | 9989 | +68 | 7 | 6 | 14 | 158 × 34 | 1234.67.9. / 123.5.7.9. |
| DIN A4 | 150 | 1300 | +60 | 1984 | +230 | 6 | 7 | 14 | 30 × 115 | 12.4..7.9. / 1234..78.10 |
| DIN A4 | 300 | 2696 | +216 | 3658 | +150 | 6 | 7 | 14 | 108 × 75 | 1234..7.9. / 1234..789. |
| DIN A4 | 600 | 4985 | +24 | 7103 | +87 | 6 | 6 | 14 | 12 × 43.5 | 1234..7.9. / 12345...9. |
| US Legal | 150 | 1573 | +298 | 1968 | −132 | 6 | 6 | 14 | 149 × 66 | 1.3.567.9. / 1234..7.9. |
| US Legal | 300 | 2400 | −150 | 4082 | −118 | 6 | 6 | 14 | 75 × 59 | 12.4..7.910 / 123.5.7.9. |
| US Legal | 600 | 5094 | −6 | 8494 | +94 | 6 | 5 | 13 | 3 × 47 | 1234..7.9. / 123...7.9. |
| US Letter | 150 | 1293 | +18 | 1768 | +118 | 5 | 7 | 14 | 9 × 59 | 1234..7... / 1234.67.9. |
| US Letter | 300 | 3168 | +618 | 3536 | +236 | 7 | 6 | 15 | 309 × 118 | ..3456789. / 123.5.7.9. |
| US Letter | 600 | 5096 | −4 | 6582 | −18 | 7 | 6 | 14 | 2 × 9 | 12345.7.9. / ..34567.9. |

---

### findings

**no 8/10 exists in the scanned range.**

the widened search `[−200 .. +800]` produced individual dimension scores of
7/10 at best. no candidate satisfied all ten constraints simultaneously. this
suggests that ratio termination [constraints 8 and 10] is largely orthogonal
to the pixel-level truth set, and that constraint 6 [600 DPI cross-scale] and
constraint 7 [even delta] remain difficult to satisfy alongside the full
string-truth set for dimensions near standard paper sizes.

**constraint 6 is the hardest to satisfy.**

across all formats and DPIs, constraint 6 [`is_true(W*2)`] is the most
frequent omission in high-scoring candidates. this is expected : doubling a
large integer produces a very long digit string, and the harmonic truth
density drops as string length increases. at 600 DPI the standard dimensions
are already large [e.g. 4961×7016 for A4], so `W*2` exceeds 10000 digits,
making combined ELF/ASCII truth unlikely. at lower DPIs, constraint 6 fails
because the doubled value inherits the non-harmonic structure of the standard.

**recommended candidates for initial blue-doc implementation :**

1. **US Letter 600 DPI : 5096 × 6604** [pair score 13, margin 2 × 2 px]
   both dimensions are within 4 px of standard. W scores 7/10 [missing
   constraints 8 and 10], H scores 5/10 [missing constraints 3, 8, 9, and 10].
   the WxH string passes. this is the most pragmatic candidate : negligible
   margin, visually indistinguishable from standard, high individual scores.

2. **DIN A4 600 DPI : 4985 × 7012** [pair score 12, margin 12 × 2 px]
   W is +24 px, H is −4 px. both score 5–6/10. WxH and HxW both pass. the
   margins are small and symmetric. this is the best A4 candidate for
   production use where near-standard appearance matters.

3. **US Legal 300 DPI : 2418 × 4188** [pair score 12, margin 66 × 6 px]
   W is −132 px, H is −12 px. both score 5/10. WxH and HxW both pass. the
   height margin is negligible; the width margin is modest and acceptable for
   legal documents that typically have wide binding gutters.

4. **DIN A4 300 DPI : 2704 × 3588** [pair score 12, margin 112 × 40 px]
   both dimensions score 6/10 individually — the highest individual scores in
   the A4 family. WxH passes. the margins are larger but still practical for
   documents with figure captions or footnote areas. recommended for cases
   where harmonic purity outweighs near-standard proportions.

**ratio constraints.**

constraint 9 [`is_true` on the decimal ratio string] passes far more often
than anticipated. it fires on the majority of high-scoring candidates,
typically adding one point to dimensions that already score well on
pixel-level constraints. this suggests that the `%.14g` truncation of a
non-terminating ratio can still produce a digit string that satisfies combined
ELF/ASCII truth — the truncation breaks periodic repetition just enough to
yield a passing signature.

constraints 8 and 10 [terminating base-10 ratios] are much more selective.
they pass only when the reduced denominator contains no prime factors other
than 2 and 5. this occurs in roughly 10–15% of high-scoring candidates. the
two constraints often agree [if W/H terminates, H/W terminates with the same
reduced denominator structure], but they can diverge near the integer boundary
where one direction reduces cleanly and the other does not. for example, US
Letter 300 DPI candidate W=3168 against standard H=3300 yields W/H = 24/25
[constraint 8 passes] but H/W = 25/24 [constraint 10 fails because denominator
24 retains factor 3]. conversely, US Legal 300 DPI W=2400 against standard
H=4200 yields W/H = 4/7 [constraint 8 fails] while H/W = 7/4 [constraint 10
passes].

no candidate in the scanned range scores 8/10 or higher, and no top-pair
dimension passes all three ratio constraints simultaneously. the ratio layer
therefore behaves as an orthogonal filter : it rewards a subset of already
harmonic candidates but does not create new high-scoring candidates from
low-scoring ones.

the US Letter 150 DPI and 300 DPI candidates with large positive deltas
[+420, +570, +618] are geometrically correct but aesthetically divergent from
standard proportions. they are preserved as proof-of-existence for high-scoring
candidates but are not recommended for default templates.

---

### open questions

**cross-format consistency.** should the margin size be uniform across all
DPIs for a given format? currently 600 DPI candidates have much smaller
margins [2–12 px] than 150 DPI candidates [24–345 px]. a policy of "same
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
  independent W/H scan, paired scoring with WxH/HxW bonus, ratio termination
  and ratio-string truth]
- `data/md/design/BLUE-DOC-FORMAT.md` — parent format specification

#,,.,,,..,,,.,.,,,...,..,,,,.,.,,,...,.,,,..,,..,,...,..,,.,,,..,,...,,,,,..,,
#5YQATCQCAAQ4DDZIWU4ZAIZ6O6N4UZDASGUEB6EL4WPWX3BZAKA2TG4S4TMQZQ44JUOQZZTFLG24Y
#\\\|4YIDTLLBCLBSKFH2RKHUBQRA2HSOUBRGNJMLXOVK4RBF4XKYXLA \ / AMOS7 \ YOURUM ::
#\[7]67EDB3GZEKR4T6XAMTJMOAJWDHDFIQ25UBWQYSXYAQQJIBUKLIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
