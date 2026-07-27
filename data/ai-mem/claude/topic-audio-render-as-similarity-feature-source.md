---
name: topic-audio-render-as-similarity-feature-source
description: "vision seed: audio.render_standing_wave's visual output tracks actual audio similarity (confirmed empirically: two purring samples render visibly similar, a meowing sample renders visibly different/denser after fixing the shared-grid + normalization bugs) -- the renderer's own per-render stats (e_low/e_mid/e_high, ring/cell/speckle counts) are a lightweight deterministic feature vector that could feed the already-planned similarity-graph-cell-connections.md system, which explicitly needs an upstream similarity-score source it doesn't yet have"
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

## status

design-only, seed stage. not scoped, not built. the practical next step
if pursued: expose `$stats` (or a normalized subset of it) somewhere
queryable per rendered file — e.g. alongside the PNG in
`/var/protocol-7/audio/`, or via a content-checksum-keyed lookup per the
[[project-audio-waveform-visualization-landed-2026-07-26]] generalization
doc's own note about checksum-keyed caching for non-purr audio — rather
than only using it for the one-shot log line it currently produces.

#,,,,,,,.,.,.,,..,.,,,,..,,..,..,,.,,,..,,.,.,..,,...,..,,.,,,..,,,,.,.,.,.,.,
#5QZ6RDAMEPODEQGPB3EQEZV27IXSEAV2ESUOFNETWL56XFSWYOJOVUMMI3S5UL67AMGB6NGF5ADJY
#\\\|JI2CNJF6IQ4RPQYTPV5RUPSDQY6CV6T7OMNBWIUD6JHKVXLWZ3U \ / AMOS7 \ YOURUM ::
#\[7]MMMCTMCBQNHKIJ5D7QU76V2GS3RXME6FEPN6SASIGOOVO674IIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
