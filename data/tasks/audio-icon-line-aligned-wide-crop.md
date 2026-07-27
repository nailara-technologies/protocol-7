# audio icon : line-aligned wide crop with padding

## status

**module built and live-tested** — `audio.post_process.crop_wide.v1`,
implemented by Kimi K3 dispatch, whitelisted for compile-timing. NOT
yet wired into `audio.finalize_decode`'s dispatcher on purpose: the
single-slot `audio.cfg.post_process` can't currently combine
`crop_wide` with `rotation_stack` in the same render, and that
integration decision is still open (see § below and
`audio.cfg.post_process`'s existing single-select limitation, also
noted in `project-audio-icon-three-stage-pipeline-landed-2026-07-27.md`).

tested directly (loading the actual module file, not a reconstruction)
against real renders: `ac` (the sample that actually crosses the
`format_hint` threshold in production) cropped cleanly at both edges —
boundary lines fully visible with padding, no square bisected. `aa`
(generic sanity check only, never actually reaches this module since
it stays `square`) cropped cleanly at top but fell back to a plain
margin at bottom with less visible padding — a minor edge-case in the
fallback path, not affecting the real target case.

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

#,,..,..,,,..,,.,,..,,,,,,,.,,,..,,,,,..,,,.,,..,,...,..,,..,,...,,,,,,.,,..,,
#BFWTEKCJWGKZT4XZWNMUACDSJQ6QH6PQ22IEVICQKOEEMBG54STW7NA22WGWD5OHH6FSPZ4YT2HFG
#\\\|LCH7P63U7ARGSTOZV4RFU2LKE5WST3GQ5QOVAWSIPTF3XY6RLB3 \ / AMOS7 \ YOURUM ::
#\[7]H6S66KNO45EQVVW5ZTAAAAYR4MXYDF22EHUWZGXVRLNAOB2DA6CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
