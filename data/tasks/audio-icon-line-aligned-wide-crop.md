# audio icon : line-aligned wide crop with padding

## status

deferred / not started. captured from conversation so it isn't lost.
a simpler, flat alternative (or complement) to the povray cylinder
wrap (`data/tasks/audio-icon-povray-glass-cylinder-wrap.md`) for
producing an actually wide (non-square) image once
`audio.cfg.format_hint_threshold` (see
`data/tasks/audio-icon-format-hint-from-am-depth.md`) says a file
should get one — that task generates the *signal*, this one is one
possible *consumer* of it.

## the idea

when cropping a square render down to a wide aspect ratio, don't crop
at a fixed/arbitrary row offset — that risks slicing straight through
the middle of a background square's edge stroke, which reads as a
broken/incomplete render rather than an intentional wide crop. instead,
snap the crop boundary to an actual horizontal boundary line already
present in the background geometry (all the `render_standing_wave.*`
styles draw axis-aligned rectangles/strokes, so horizontal boundary
lines are common and structurally meaningful, not incidental).

**user's refinement:** don't snap the crop line exactly flush to the
detected boundary line either — that would leave the line sitting
right at the image edge, which reads as an incomplete/cut-off icon
boundary just as badly as slicing through a square would. leave a
small padding margin of background (black) beyond the detected line
before the actual crop edge, so the boundary line sits fully visible
with breathing room, reading as an intentional frame edge.

## proposed algorithm (simple, per user's own framing)

1. define a target crop margin (how much to trim from top and bottom
   to reach the desired wide aspect ratio).
2. scan inward from the top edge, and separately from the bottom edge,
   within a small search window centered on that target margin.
3. for each candidate row in the window, measure the fraction of
   pixels matching the background's line color (or simply count lit
   pixels) — a genuine horizontal boundary line shows up as a row with
   much higher, near-full-width coverage than its neighbors.
4. pick the first row (scanning inward) that spikes above a coverage
   threshold as the detected boundary.
5. add a fixed pixel padding beyond that detected row (further toward
   the image edge, i.e. keeping more of the original image) before
   actually cropping, so the line isn't flush against the new edge.

## open questions

- does snapping purely to horizontal-line rows suffice, or does a
  detected row also need checking for vertical lines crossing it (a
  square's left/right edge passing through that same row)? tentative
  answer: probably fine as-is, since a horizontal boundary line row by
  definition sits between two rectangle interiors, not through one —
  but worth confirming against a real case before considering it
  settled.
- how much padding is "enough" — needs the same kind of visual
  spot-check this session already demonstrated is necessary for
  `audio.cfg.format_hint_threshold` (see that task's own correction
  from `0.4` to `0.9` after a numeric-only choice turned out visually
  wrong).
- coverage threshold for "this row is a boundary line" needs
  calibrating against real renders, same caveat.
- relationship to the povray cylinder-wrap task : this flat crop
  approach and the cylinder wrap aren't mutually exclusive — a line-
  aligned crop could be a fast/simple default, with the cylinder wrap
  as the richer presentation for whenever that's built. not yet
  decided whether both should exist or one supersedes the other.

#,,.,,,,,,.,,,,,.,..,,...,,,.,,,.,.,,,,,,,,,,,..,,...,...,.,.,,..,..,,,..,,,.,
#4COGT2V6R2UYQTPFG33ILZ7W66C2EZA2WBCHPNI3WTXTLQPVEFEKZGYODYA2H3YHSB35VLYDSTZZO
#\\\|Z4MJSETH5P6GZA2ODGW4EFM56DY5ZODLD2VOWLDPLA3HFSFELB3 \ / AMOS7 \ YOURUM ::
#\[7]F23PMOVNMCJ6PFWCP7FJSE2CIZ5ULZYATITOOLZVLTRGLQZWFOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
