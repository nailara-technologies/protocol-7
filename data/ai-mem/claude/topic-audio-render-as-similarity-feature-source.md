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

## status

design-only, seed stage. not scoped, not built. the practical next step
if pursued: expose `$stats` (or a normalized subset of it) somewhere
queryable per rendered file — e.g. alongside the PNG in
`/var/protocol-7/audio/`, or via a content-checksum-keyed lookup per the
[[project-audio-waveform-visualization-landed-2026-07-26]] generalization
doc's own note about checksum-keyed caching for non-purr audio — rather
than only using it for the one-shot log line it currently produces.

#,,,.,.,,,.,.,,,,,,.,,.,.,,,,,,.,,.,,,,..,.,.,..,,...,...,...,.,.,,..,.,,,..,,
#K5XMA5JHIGX7MDLTX44OPNZ5AGMHH52G5A36JHTTIAFN5EGOD23JKWWNJEM3IQH4YVWHQAXI4NTTW
#\\\|RHPRZKSCU62HJUHNIVDHTFLCEK3NVD5YVULAFCLCJA24V3VUGFQ \ / AMOS7 \ YOURUM ::
#\[7]5ZQKWXZ66HP3USK44OCHUO2XBUTSSF2CTSXEOQUP3726KEWOHACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
