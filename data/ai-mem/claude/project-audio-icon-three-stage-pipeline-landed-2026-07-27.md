---
name: project-audio-icon-three-stage-pipeline-landed-2026-07-27
description: "landed: audio.finalize_decode grew a 3rd orthogonal dispatch axis, audio.cfg.overlay, alongside render_style and post_process -- audio.overlay.waveform_trace.v1 draws a classic min/max amplitude envelope (translucent phosphor-green, true per-pixel alpha) over an already-composited background, motivated by using rotation_stack.v4's mirror-symmetric spiral as a per-file entropy-derived icon background with the literal waveform as recognizable foreground"
metadata:
  node_type: memory
  type: project
  originSessionId: 16c8ce74-d9e2-429d-bafb-25fae9c0c30f
---

## the idea that started it

user's own framing: `rotation_stack.v4`'s mirror-symmetric output would
"perfectly serve as background for an audio file icon with as foreground
the actual waveform rendered into it" — pairs an entropy-derived, unique-
per-file abstract background (already built for the fingerprinting/
similarity use case, see
[[topic-audio-render-as-similarity-feature-source]]) with a literal
time-domain amplitude trace (the classic sample-editor look) that makes
the result instantly recognizable as audio, not just abstract art.

## why this became a 3rd axis, not a rotation_stack.v5

reasoned the same way `post_process` was originally split off from
`render_style`
(see [[topic-audio-render-rotational-depth-stack]]): different
signature, different kind of operation. `render_style` subs build a
background from FFT analysis. `post_process` subs transform an existing
image in place (rotate/mirror). this new kind needs BOTH the raw pcm
array AND an already-rendered image path, and it draws genuinely new
content (a waveform trace derived straight from the samples) rather
than transforming existing pixels. landed as `audio.overlay.<name>`,
dispatched from `audio.finalize_decode` as a third stage after
`post_process`, gated by a new `audio.cfg.overlay` config (default
`'none'`, same sentinel pattern as `audio.cfg.post_process`).

## audio.overlay.waveform_trace.v1

min/max amplitude envelope per pixel column (same downsampling approach
real sample editors use), drawn inside a margin frame (12% of canvas by
default) rather than touching the image edges, on a genuinely
transparent `channels=>4` Imager canvas — NOT a black-filled layer
blended at reduced opacity. that distinction mattered: an early
prototype used a black-filled layer + `compose(opacity=>0.6)`, which
darkened the ENTIRE background wherever the trace wasn't drawn too
(confirmed by user noticing "the background is even darker" and traced
via direct pixel comparison — corner pixels far from the trace had
changed when they shouldn't have). switching to true per-pixel alpha
(only line pixels carry alpha, `compose(combine=>'normal')` with no
extra opacity multiplier) fixed it — verified pixel-identical at 3
sample points away from the trace.

color defaults to the project's own phosphor-green console color
(`p7_fg_0003` in `bin/Protocol-7`, rgb `9,170,94`) rather than an
arbitrary choice — user explicitly asked for this instead of a generic
neon green, once the earlier white/pure-neon-green attempts read as too
harsh against the background palette.

user separately flagged the `graphics-matrix` zenka's ported GIMP
color-to-alpha filter (`graphics-matrix.filter.alpha`, zenka originally
named `colortoalpha`) as a relevant existing tool — not needed here
since this module sets alpha directly per-pixel while drawing rather
than deriving it after the fact from an opaque flattened render, but
worth remembering for a future overlay pass that wants soft/anti-
aliased edges baked into an opaque source first.

## live-verified, full 3-stage pipeline

confirmed end-to-end via `p7c audio.spatial-purr` with
`render_style=v3` + `post_process=rotation_stack.v4` +
`overlay=waveform_trace.v1` all three active together, not just each
stage individually.

## design observation : the frame masks waveform edge-truncation

confirmed on both `aa.mp3` (purring, dense) and `ac.mp3` (meowing,
scattered) through the full `v3` + `rotation_stack.v4` +
`waveform_trace.v1` combo. user's own observation on `aa`: its
waveform trace is dense enough to run edge-to-edge within the overlay's
margin frame, which on its own would read as an arbitrarily truncated
crop — but the nested-square background frame surrounding it, combined
with the overall canvas itself being square, makes that edge read as
an intentional boundary instead. the background isn't just decorative
alongside the waveform — it does real visual work resolving what would
otherwise look like a clipping artifact into a deliberate framing
choice. not something that was designed in on purpose, but a real
emergent benefit of layering a bounded geometric frame under a
content-derived foreground trace.

## status

landed and signed. all three axes (`render_style`, `post_process`,
`overlay`) are independently selectable via `audio.cfg.*`, defaulting
to `v1` / `none` / `none` respectively for production traffic. natural
combination for the icon use case is `v3` + `rotation_stack.v4` +
`waveform_trace.v1`, but nothing hardcodes that pairing — any
combination is valid since each axis only depends on the previous
stage's output file (or, for overlay, the pcm already in memory).

**known gap, not yet resolved:** `v3`'s color-boost + tinted
background and `v4`'s mirror symmetry are two different
`rotation_stack` variants, and `audio.cfg.post_process` only selects
one at a time — there's currently no way to get boosted colors AND
mirror symmetry together in a single render. would need either a
combined variant or a chainable multi-step post_process dispatcher.
not scoped or built this session.

#,,.,,.,,,,,,,,.,,,,,,.,.,...,,,,,..,,,,.,,,,,..,,...,...,..,,,..,,.,,..,,...,
#ZFI6VZV3QTEXOZLHR2AQSD6QYPVPT4ZYPHQIB6FCJSEQYMJ2HNYOV4CUTRKP2ABDLOYTLHJV6FEP6
#\\\|77IPKOSQLLMHHOUO6INK4NV4DKXJFQYUNTGD4CHADGXSZT6SLOC \ / AMOS7 \ YOURUM ::
#\[7]2ULX5NJ6WYXY7DUUHKYHCSHOMRSDX2TW7RZB2CNU65PLXJJFK4BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
