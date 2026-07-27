# audio icon : povray glass-cylinder wrap around the waveform render

## status

**this file is the requirement, not the implementation plan.**
**agreed as the intended default presentation** for the audio-icon
pipeline going forward — not just an optional extra. deferred / not
started as an implementation: `povray.init_code` is currently just a
stub (`modules/povray.init_code`), and `data/pov/` only has three
water-surface test scenes (`water.000.pov`, `water.000.1.pov`,
`water.001.pov`), no cylinder template yet. the flat-square 3-stage
pipeline (`render_style` + `post_process` + `overlay.waveform_trace.v1`)
remains the real, live-verified, committed baseline this builds on top
of — the cylinder wrap is a rendering step applied to its output, not a
replacement for it.

the actual technical plan for building the `povray` zenka out from a
stub into working infrastructure — scene templating, invocation,
output handling, and how it serves this and other use cases across the
project — is being written separately as
`data/tasks/povray-zenka-implementation.md`, since the povray zenka
itself is broader in scope than this one audio use case (see that
file's own references). this requirement doc feeds into that plan as
one of its driving use cases, not the whole of it.

## the idea

the audio-icon pipeline (`render_style` + `post_process` +
`overlay.waveform_trace.v1`, see
`data/ai-mem/claude/project-audio-icon-three-stage-pipeline-landed-2026-07-27.md`)
produces square 512x512 output. user's observation: the meowing sample
(`ac.mp3`)'s scattered/denser background would actually work well as a
*wide, non-square* icon, but the full symmetric-square background
(v3 + rotation_stack.v4) is less suited to that aspect ratio.

proposed direction instead of forcing a wide square crop: render the
already-composited waveform (or waveform+background) image as a texture
wrapped around a horizontally-aligned, glass-like translucent cylinder
via povray — giving a genuinely 3D, wide-format presentation of the same
source image rather than trying to force the square composite into a
wide aspect ratio.

## why this is a hybrid solution, not just a wide-format fix

comparing `icon_aa.png` (purring) and `icon_ac.png` (meowing) directly:
`aa` fills the square with a dense, symmetric nested-square frame all
the way to the edges — well-suited to a square icon as-is. `ac`'s
content instead clusters into the four corners, leaving a comparatively
empty band top and bottom, with the *meaningful* visual content (the
dense burst-pattern waveform) sitting in a horizontal band through the
middle — that band is what would carry over naturally into a wide
format, and forcing it into a plain square wastes the empty space.

the cylinder wrap fixes both cases at once, not just `ac`'s: a
horizontally-aligned cylinder occupies the square frame differently
than the flat waveform does — its own geometry (rounded glass ends, a
consistent horizontal band shape) gives every render a defined,
consistent *external* silhouette regardless of how sparse, dense, or
differently-shaped the underlying waveform+background happens to be.
that decouples "does this read as a good icon shape" (now fixed by the
cylinder's own geometry) from "does this specific audio's content
happen to fill a square well" (which varies a lot, as aa vs ac shows).
the result works as both a static icon/button (defined, cylinder-shaped
silhouette, consistent across any input) and as a richer display when
viewed larger (the actual entropy-derived waveform+background still
fully visible through the glass) — closer to a genuine default
presentation than either the plain square or a forced-wide crop would
be alone.

## broader applicability, beyond the single square icon

the square-icon case (single cylinder or stacked rows) is one
presentation, not the whole scope — the same translucent-cylinder
format generalizes cleanly to:

- **wide / live displays**: with more horizontal space available than
  an icon has, a single cylinder gets to be wider and show more
  waveform detail directly, no row-stacking needed — the format scales
  up smoothly rather than needing a different design at a different
  size.
- **directory/listing views**: a row of individual, elongated (non-
  square) cylinder icons is a *natural* fit for something like an audio
  directory listing — each file gets its own thin horizontal cylinder
  as its row icon, which reads more like a real waveform-preview list
  (the way audio players already show file rows) than square icons
  would. this isn't a fallback for when square doesn't fit — it's
  arguably the more natural format for a listing context specifically.

so the format has (at least) three concrete presentation modes worth
keeping in mind for whenever this is implemented: single square icon
(one or stacked cylinders), wide/live display (single wide cylinder),
and listing-row icon (elongated non-square cylinder per file).

## extended version option : stacked multi-row cylinders

instead of always one thick cylinder, the square parent frame can hold
N thinner cylinders stacked as horizontal rows — same visual grammar
audio editors already use for tracks too long to fit one screen width
(wrapping into multiple lines, read top-to-bottom like lines of text on
a page). solves a real limitation of the single-cylinder version: one
cylinder's effective horizontal resolution is capped by the square's
width, so a longer or more detailed waveform gets compressed/lossy in
the trace. splitting into row-cylinders scales the effective resolution
with row count instead, while staying square-icon compatible either
way. open question if pursued: fixed row count vs row count derived
from audio duration/detail (e.g. longer files get more, thinner rows).

## how this connects to existing infrastructure

- `povray` zenka already exists as a stub (`povray.init_code`,
  `configuration/zenki/povray`) — plan already anticipated using it for
  UI elements and images-with-embedded-images generally, this would be
  a concrete first real use.
- `data/pov/` already has water-surface scenes as scaffolding/precedent
  for how scene files are organized in this project — a cylinder
  template would follow the same pattern (`cylinder.000.pov` or
  similar), with the waveform (or waveform+background) image swapped in
  as the texture/pigment source per render, same way water surface
  scenes presumably parameterize per-run.
- open design question, not yet decided: texture the cylinder with just
  the waveform trace, or the full composited background+waveform image.
  waveform-only is simpler; full composite lets the cylinder itself
  carry the entropy-derived background too.

## known dependency : color-to-alpha

povray texturing likely needs the waveform isolated with a clean alpha
channel (not baked onto black) to map onto the cylinder correctly,
especially if only the waveform-only option is chosen. this project
already has that — `graphics-matrix.filter.alpha`, a zenka ported from
GIMP's color-to-alpha algorithm (the `graphics-matrix` zenka was
originally named `colortoalpha`, see commit `63AD6F4E8232A668D0C23D409A3367BD8ECA8D27`).
`audio.overlay.waveform_trace.v1` already draws directly onto a true
alpha channel rather than a black background needing conversion (see
its own module header), so this dependency is really about whichever
new module *extracts* the waveform back out for povray's texture input
— not a rebuild of the overlay module itself.

## next steps if picked up

1. decide waveform-only vs full-composite as the povray texture source.
2. build a `cylinder.000.pov` (or similarly named) template in
   `data/pov/`, following the water-surface scenes' existing
   parameterization pattern.
3. flesh out `povray.init_code` and whatever `povray.cmd.*` /
   `povray.render.*` module(s) are needed to invoke povray with the
   audio-icon image as input and get a rendered glass-cylinder PNG back.
4. if waveform-only is chosen, build the `graphics-matrix.filter.alpha`
   extraction step feeding into it.

#,,..,,,.,.,.,.,,,..,,,,.,,,.,,,.,.,.,,.,,.,.,..,,...,...,,.,,,,.,...,,,.,,.,,
#4S3DG3S4DTIYTL6H6UNS6RABMWD42GQZ6WZITON57EJJNMWCTXL6DH3GUSSQY4KCNDIHO72SBX5M4
#\\\|6HDQTDXWVARFLT6WS6XQHXQUOGELOYMQRWL2OOBZMVT44BQQEL6 \ / AMOS7 \ YOURUM ::
#\[7]7CXWFRYK47XNHGLTBLVCZLMBSX4TQI7IGBXT6ACE5A2QAQQQHQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
