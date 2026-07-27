---
name: topic-audio-render-rotational-depth-stack
description: "vision seed: a depth/spiral effect for the audio renderer via translucently combining 4 copies of the same render, each rotated 90 degrees CCW from the last, with the first (original, unrotated) copy darkest and placed at the bottom of the stack -- gives a symmetrical spiral appearance from compositing order + rotation alone, no new geometry or FFT work needed"
metadata:
  node_type: memory
  type: vision
  originSessionId: 16c8ce74-d9e2-429d-bafb-25fae9c0c30f
---

## the idea

take one rendered frame (any style — v1/v2/v3's existing rectilinear
lattice output) and composite four translucent copies of it on top of
each other, each rotated 90° CCW from the previous copy, with the
*first* (unrotated, original) copy the darkest and placed at the bottom
of the stack. the rotation + darkness-ordering alone produces a
symmetrical spiral appearance — no new geometry, no new FFT analysis,
purely a compositing technique applied on top of whatever a style
already renders.

## why this fits the existing work

connects directly to [[topic-audio-render-cubic-zoom-transition]] (the
already-noticed "nested squares read as traveling along a cubic grid
under zoom" effect) and the "depth is latent in anything layered/
constructed" root principle captured there — this is a second, concrete
technique in the same territory: depth from compositing/transformation
order, not from any new rendered content. rectilinear lattice geometry
(axis-aligned squares) rotates cleanly through 90° steps without any
resampling/interpolation artifacts, which is presumably why this
specific rotation angle was chosen — it stays pixel-exact through each
step given the existing square-based geometry.

## prototyped 2026-07-27: two distinct variants, not one

built and tested via standalone Imager script (4 copies, rotate 90°
CCW cumulatively, `compose(combine=>'normal', opacity=>0.5)` — verified
this is real 50/50 blending via direct pixel check, not assumed).

**critical finding: needs an asymmetric base to work at all.** v1/v4's
rings are axis-aligned squares centered on the canvas — mathematically
*invariant* under 90° rotation (a centered square rotated 90° maps onto
itself exactly). stacking rotations of a v1/v4 render only visibly
affects the small scattered accent/speckle elements — barely
perceptible, reads as "basically the same image," not a spiral. v3's
rings are deliberately off-center (phase-anchored), so they genuinely
move under rotation and produce a real pinwheel/spiral pattern. **this
technique specifically pairs with v3, not v1/v2/v4.**

**darkening is animation-semantics, not static-composite semantics**
(user's own correction): the original idea specified the first
(unrotated) copy as darkest, at the bottom of the stack — that darkness
gradient implies a "before/after," meaningful for an *animated*
continuous-rotation version (older frames fade, like a motion trail) but
importing false directionality into a *static* single-frame composite
where nothing is actually sequenced. tested both: uniform-brightness
(no darkening) vs darkened-base on the same source — visually near
identical on the elements that actually matter, confirming the darkening
wasn't doing much for the static case either way, so drop it there.
**two variants going forward**: static composite = uniform opacity
across all 4 rotations, no darkening. animated composite (sliding-window
live-stream, see [[topic-audio-render-sliding-window-live-stream]]) =
darkening gradient as an actual history/trail cue, since there really is
a "before" in that context.

**verdict on the v3+rotation-stack static result**: keeping it as a real
variant, not just a prototype — even though it isn't perfectly
symmetric (v3's other passes — mids/highs/accents — are independently
scattered and don't reinforce into clean 4-fold symmetry the way the
rings do), the resulting denser, more textured entropy distribution is
considered valuable specifically *for* the fingerprinting/similarity-
signal use case (see
[[topic-audio-render-as-similarity-feature-source]]) — more visual
entropy to discriminate on, not a flaw to fix.

## landed 2026-07-27: separate versioning axis, not folded into render_style

built as `audio.post_process.rotation_stack.v1` — a standalone module,
NOT a `render_standing_wave.v5`. reasoning: this is a compositing
technique orthogonal to which style produced the input (could equally
apply to a future style with asymmetric geometry), not a new
analysis+geometry style itself, so it gets its own independent `v{N}`
sequence rather than consuming a number in the render-style sequence.
wired via a new `audio.cfg.post_process` config (default `''` = none)
and a dispatch stage in `audio.finalize_decode`, applied in place on
the file the render_sub already wrote, after it succeeds. whitelisted
via `bin/dev/gen-sub-whitelist audio` (auto-picked up, no manual
whitelist edit needed for new zenka-local subs going forward).

**user feedback on landed output**: correctly darker than the
unprocessed input — expected and not a flaw, since averaging 4 copies
at uniform 0.5 opacity mathematically compresses peak brightness (each
composite step is a weighted blend toward the layer being added, not
an additive sum). user's framing: treat this as *one layer/mask* in a
gimp-style layer stack rather than a finished, standalone visual —
suitable as an automated mask/filter-effect input for something
brighter layered on top, or as raw material for the still-unbuilt
animated variant, where the darkness is even less relevant since each
frame is transient. the spiral structure itself reads clearly at this
brightness already (v3+aa/ac/saturnians all confirmed legible), so no
brightness tuning was applied — correcting exposure here would be
solving a problem this layer doesn't actually have on its own.

## status

**built and landed** as `audio.post_process.rotation_stack.v1` (static,
uniform-opacity variant). not yet tested through the live zenka via
`p7c` / devmod — only verified by loading the actual module file
standalone against v3 renders (aa/ac/saturnians), output visually
confirmed. animated variant (darkening-as-history-cue) still unbuilt,
waiting on the sliding-window infrastructure it depends on — see
[[topic-audio-render-sliding-window-live-stream]].

#,,.,,.,,,...,.,.,..,,...,...,.,,,,..,,,.,..,,..,,...,...,...,,.,,,.,,.,,,.,.,
#KFLRDYG6IJBWM3DRIUA7PGVTQ4X2RFO7BHBPZKPSNMUZ2FFOCM7J75CBHCAGDEZBINYCDTWMRHWGO
#\\\|DZBXAGIPAHCGMQ4A2YDZJU5M3GJC7VXYMV4GT2UUVKCKQ2WCKL7 \ / AMOS7 \ YOURUM ::
#\[7]XT6UXTK6GWDXEGYOPFVTH33B646UVDGW7YIYO6F4F7JFFB3Q5QAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
