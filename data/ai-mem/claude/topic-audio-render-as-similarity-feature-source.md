---
name: topic-audio-render-as-similarity-feature-source
description: "vision seed + correction: audio.render_standing_wave's visual output tracks actual audio similarity empirically, but kimi K3 independent review found the multi-style (v1/v2/v3) cross-correlation idea overstates independence -- all three share one analysis front-end, so agreement is nearly guaranteed by construction, not a real signal, unless the analysis itself (not just geometry) is diversified. also found v3's absolute-phase placement is not shift-invariant (real bug), and that the renderer discards all temporal/rhythm information by averaging FFT windows -- a concrete v4 idea (per-window energy variance) would capture what v1-v3 structurally cannot"
metadata:
  node_type: memory
  type: vision
  originSessionId: 16c8ce74-d9e2-429d-bafb-25fae9c0c30f
---

## origin

confirmed empirically 2026-07-27 while testing
[[project-audio-waveform-visualization-landed-2026-07-26]]'s two bug fixes
(shared source-prefix grid between mids/highs, and per-render-relative-only
normalization) — `data/audio/purring/aa.mp3` and `ab.mp3` (both genuine
purrs) render as visibly similar compositions; `ac.mp3` (turns out to be
meowing, not purring — confirmed after the fact by listening) renders
visibly denser/more scattered. this wasn't designed in; it fell out of
fixing the two bugs that had been artificially flattening/collapsing
per-sample differences. two audio files that sound similar now produce
visually similar renders, and a spectrally richer sound (meowing vs a
steady purr) produces a proportionally busier render.

## the connection

`data/md/coding-tasks/similarity-graph-cell-connections.md` (an existing,
already-scoped task) adds a graph layer to `graphics-matrix` where edges
connect cells sharing similarity, and explicitly states: *"the similarity
scores themselves come from above (vision pipeline, manual assignment, or
namespace queries) — this layer does not compute similarity, it stores
and renders it."* there is currently no described source of similarity
scores for audio content specifically.

`audio.render_standing_wave` already computes, per render, a small
deterministic feature vector as a side effect of rendering
(`e_low`/`e_mid`/`e_high` band energies, ring count, lattice cell size,
cell count, speckle count, accent count — all in `$stats`, already
returned from the function, already used for nothing but logging today).
This is a natural, already-computed, zero-extra-cost candidate source
of similarity scores for audio content feeding the similarity graph —
either by comparing these stats vectors directly (cheap, no image
processing), or, more literally, by perceptual/visual comparison of the
rendered PNGs themselves (since the render is deterministic and content
is proportionally represented, visual similarity IS a reasonable proxy
for audio similarity, not just a coincidental resemblance).

## multi-style cross-correlation strengthens the signal

confirmed 2026-07-27, same session: with `audio.render_standing_wave.v2`
(multi-scale mids) and `.v3` (phase-anchored off-center rings) landed
alongside `.v1`, the same audio file rendered through all three produces
outputs that are visibly distinct from each other *and* visibly
correlated with each other — expected, since all three derive from the
same underlying FFT/band-energy analysis, just visualized differently.

this sharpens the similarity-feature-source idea above: comparing a
single style's stats/render for two files is one signal; comparing
*agreement across multiple independently-designed styles* for the same
pair of files is a stronger one — two files that are genuinely similar
should correlate across v1, v2, *and* v3, while a coincidental
resemblance in just one style (an artifact of that style's specific
geometry choices) would not carry across the others. this is a
multi-dimensional similarity vector essentially for free, since each
style already computes its own `$stats` independently and the styles are
designed to diverge from each other precisely so their agreement means
something when it happens.

## relation to multi-algorithm checksum collision-avoidance

the multi-style cross-correlation idea above is structurally the same
technique as running multiple checksum algorithms in parallel against
collisions (this project already does exactly this — BMW/JHA/ELF/AMOS
families coexisting in `base.chk-sum.*` for that reason): independent
functions over the same input, agreement across them is a much stronger
signal than any one alone, since each function's own blind spots/false
positives are unlikely to coincide.

but there's a qualitative difference worth keeping distinct: blind
algorithm-stacking (checksums) gains entropy *linearly* and generically,
regardless of what's being hashed — more algorithms just means more
collision resistance, uniformly, for any input. here, because there's
visual feedback in the loop (a human can actually look at the output and
judge whether a style resolves a given kind of audio well or poorly),
style choice and parametrization can be deliberately matched to input
type instead of blindly stacked — e.g. a style tuned for percussive/high
transient content vs one tuned for sustained tones. that's not linear
entropy gain, it's *contextualized resolution*: disproportionately better
discrimination for the input classes a style was actually chosen/tuned
for, rather than uniform improvement across all inputs. worth keeping
this distinction explicit if this ever gets built — the value isn't just
"more styles = more signal," it's "the right style for this input class
= sharper signal than uniform stacking would give."

## correction (kimi K3, 2026-07-27): the checksum analogy overstates current independence

independent review flagged a real gap in the reasoning above: v1/v2/v3
are **not** independent the way BMW/JHA/ELF checksums are. all three
share the *identical* analysis front-end — `e_low`/`e_mid`/`e_high` and
the peak lists are computed once and are exactly the same numbers across
all three styles; only the *geometry/placement* differs. checksum
algorithms are independent all the way down (different math, different
collision surfaces); these three styles are independent only in their
rendering layer, sitting on top of one shared analysis layer. cross-style
agreement between v1/v2/v3 as currently built is therefore **nearly
guaranteed by construction, not a meaningful signal** — two files
produce correlated output across styles because they're fed the same
underlying numbers three times, not because three genuinely independent
measurements happened to agree.

the fix, if this is pursued: diversify the *analysis*, not just the
geometry. different `fft_size`/band splits per style, or genuinely
different feature *types* (temporal-modulation energy vs. spectral peaks
— see the next section) would make cross-style agreement an actual
signal rather than a near-tautology. `v3`'s phase data is currently the
only genuinely independent feature family across the three styles — and
it's also the one flagged as unstable below, so as of this note there
isn't yet a second truly independent signal to correlate against v1.

## known issues found by independent review (kimi K3, 2026-07-27)

- **v3's absolute-phase placement is not shift-invariant.** FFT phase
  rotates by `2πfΔt` under any time-shift of the same content, so the
  *same audio re-segmented from a different start offset* renders
  differently under v3 — this is exactly the crossfaded/differently-
  segmented-stream instability already flagged as a concern in
  `AUDIO-VISUAL-THUMBNAIL-GENERALIZATION.md`'s "segmentation is upstream"
  section, now confirmed to exist *inside* v3's own placement mechanism,
  not just in hypothetical upstream stream-chunking. concrete fix
  proposed: use phase *differences between adjacent peaks* (relative,
  not absolute) instead — shift-invariant. not yet implemented.
- **renders are underexposed independent of the `lit_ratio` budget** —
  the actual ceiling is the hardcoded count caps (`n_rings≤6`,
  `n_cells≤32`, `n_speck≤80`), not pixel budget; unused per-pass
  allowance isn't redistributed, and `$dim`'s 0.35 floor on top of an
  already-dark base color compounds it for sparse (purr) content. raising
  `lit_ratio` alone will not fix this.
- **the renderer discards all temporal information.** averaging all 96
  Hann windows into one static magnitude spectrum eliminates the ~25Hz
  amplitude modulation that's structurally what defines a purr's
  character. the renderer is a pure spectral snapshot; it cannot
  represent rhythm/variation at all, by construction, regardless of
  style. this is also *why* the checksum-independence gap above matters
  more than it might seem — no style currently derived from this same
  front-end could ever capture temporal difference between two spectrally
  similar but temporally distinct sources.
- **v2's improvement is real but uneven** — visibly better on busy
  content (`saturnians`), but v2's `aa` output is nearly indistinguishable
  from v1's.
- **concretely warranted v4 idea, not yet built**: per-window band-energy
  *variance* (captures the purr's actual AM/rhythm — the temporal
  information v1-v3 all discard) mapped to ring dash/gap patterns. cheap
  to add since per-window FFT results already exist before being averaged
  away; genuinely new information, not a geometry variant of existing
  data like v2/v3 are.

## status

design-only, seed stage. not scoped, not built. the practical next step
if pursued: expose `$stats` (or a normalized subset of it) somewhere
queryable per rendered file — e.g. alongside the PNG in
`/var/protocol-7/audio/`, or via a content-checksum-keyed lookup per the
[[project-audio-waveform-visualization-landed-2026-07-26]] generalization
doc's own note about checksum-keyed caching for non-purr audio — rather
than only using it for the one-shot log line it currently produces.

#,,,.,,,,,..,,.,.,.,.,...,.,,,.,.,,,.,,.,,...,..,,...,...,.,,,,,.,,,,,,,,,...,
#XDAHWGD6CYLFITDCVLKA46QGO6TUUXLFYCKUJBXWSUPWFG7XJFCCKTKZSJBDO5YCVI3TZWRQZWT4U
#\\\|KRSUH7L6XUHHLKJFIORJHC7E7MTEWUAA7DB3GRAM3XE7EIGMCQD \ / AMOS7 \ YOURUM ::
#\[7]BJBVIAF4WW2MZQAS6WQUMJ2GJWWFAWAT4PAPDNVXOCPLXXAZGUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
