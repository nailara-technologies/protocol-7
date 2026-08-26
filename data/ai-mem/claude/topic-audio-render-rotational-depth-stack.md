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

## v1 live-verified, v2 added : equal-weight vs recency-biased blend

`v1` was subsequently verified end-to-end through the actual running
zenka via `p7c audio.spatial-purr` (not just the standalone harness) —
confirmed working, and also surfaced two unrelated `base.log`-vs-
`base.logs` argument-contract bugs in the audio zenka's log calls
(base.log's 3rd positional arg is a buffer name, not sprintf args;
fixed across `audio.finalize_decode` + `audio.handler.decode_timeout`).

user's response to v1's output: correctly darker (see above), but also
noted it still "isn't symmetric, as it is still the rotation" — pushed
on what v1's compositing actually does: `compose(combine=>'normal',
opacity=>0.5)` applied *sequentially* onto an accumulating stack is NOT
an equal-weight 4-way blend. it's a recency-biased geometric series —
the last-composited rotation ends up ~1/2 the final image, the one
before it ~1/4, then 1/8, 1/8. that's why it still read as "mostly the
original," not a genuine 4-fold blend.

built `audio.post_process.rotation_stack.v2` to fix the weighting:
scales each of the 4 rotations to exactly 25% brightness
(`convert(matrix=>...)`, same technique as the existing glow-layer
trick) and adds them (`combine=>'add'`), giving every rotation
identical weight. user confirmed this reads as genuinely different from
v1, worth keeping — but clarified "symmetric" in their original framing
meant *mirror* symmetry (horizontal/vertical), not rotational — v2 is
still rotation-only, just correctly *equal-weighted* rotation now, and
is being kept as its own distinct variant rather than a strict
correction/replacement of v1.

**numbering decision for what comes next** (both still unbuilt):
sticking with the project's flat-integer versioning convention (see
`render_standing_wave.v1`-`.v4` — no decimal sub-versions) rather than
a `v2.1`: `v3` = color-boosted variant of v2's equal-weight blend,
`v4` = the actual mirrored (horizontal+vertical reflection) technique
user described as genuinely symmetric — a distinct operation from
rotation, not a v2 tweak.

## v4 landed : true mirror symmetry, built ahead of v3

built `audio.post_process.rotation_stack.v4` next (out of numeric order
— v3 is still unbuilt) since the user chose to build the mirror
technique first, the effect they'd actually been asking for since v1.
composites the original with its horizontal flip, vertical flip, and
both-flipped (== 180° rotated) copy, all via the same equal-weight
25%-each additive technique v2 introduced, but applied to reflection
instead of rotation — genuinely symmetric under both a horizontal AND
vertical mirror, which pure rotation can never produce. prototyped
standalone first and user-confirmed ("affirmative") before building the
real module. live-verified via `p7c audio.spatial-purr` same as v1/v2.

## v3 landed : color boost, tuned through 3 iterations

built `audio.post_process.rotation_stack.v3` last, closing out the
planned 4-variant sequence. first attempt (1.7x channel scale +
`autolevels` contrast stretch) washed the cool indigo/blue/violet
palette out entirely to near-uniform cyan — `autolevels` stretches each
channel's min/max to full range, and since this image is mostly black
with sparse bright pixels, nearly everything bright clips to max.
dropped `autolevels`, landed on a gentle uniform channel scale alone
(tuned 1.25x → 1.6x across 3 rounds of visual feedback) which preserves
relative color relationships. also replaced the pure-black canvas fill
with a slightly blue-tinted background (`#000013`) for more perceived
depth than flat black.

both the boost factor and bg tint are exposed as opts rather than
fixed, per user's own follow-up: `#000013` was tuned for this layer
*alone* — once a waveform overlay
(`audio.overlay.waveform_trace.v1`) is drawn on top, a darker tint like
`#000007` likely gives the neon foreground more contrast headroom, so
the right value is genuinely context-dependent rather than a single
universal default.

## design principle : refining the container refines every entropy instance

user's own observation on seeing v3: it "looks very balanced, like
intentional design" — and the reason is structural, not luck. every
render's actual content (rings, cells, speckle placement) comes from
per-file FFT entropy and is never hand-tuned; what v1→v2→v3→v4 actually
iterated on was the deterministic *container* around that entropy —
blend math, palette, background tint, boost curve. because the
container is shared by every possible input, refining it once makes
*every* entropy-driven instance inherit that refinement automatically —
the same mechanism that let two different purr samples visually read as
similar despite being independently generated (see
[[topic-audio-render-as-similarity-feature-source]]) also means a
single round of container tuning reads as deliberate art-direction
across arbitrarily many future inputs, without per-file work. worth
keeping in mind for whatever gets built next (povray cylinder included)
— the leverage is in refining the deterministic wrapper, not the
content it wraps.

## status

**all four planned variants (v1, v2, v3, v4) built, landed, and
live-verified** via `p7c audio.spatial-purr`. the `rotation_stack`
family is functionally complete as originally scoped. animated variant
(darkening-as-history-cue) remains a distinct, still-unbuilt idea,
waiting on the sliding-window infrastructure it depends on — see
[[topic-audio-render-sliding-window-live-stream]]. broader next step is
the povray glass-cylinder wrap
(`data/tasks/audio-icon-povray-glass-cylinder-wrap.md`), which now
has an agreed-default status of its own.

#,,,.,,,.,,,,,...,..,,..,,,,,,,,.,,.,,..,,..,,..,,...,..,,..,,.,,,...,.,,,.,.,
#4F5TX2D37WONZ4WTZFPHBC34Y4RS7BSX5EOZHSFVC5ISWRPHINT3GA5Q2U6OJOWCPTUE6EDH642TA
#\\\|EJFQBY62DU446KXZFSO6UT7XPWA7WKV654EGPXQQWN4D3NP663N \ / AMOS7 \ YOURUM ::
#\[7]QBP5UR4MD2EOH52EX3XY24UW7PY23AV2AYPXMR73HXCV3WZVDUCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
