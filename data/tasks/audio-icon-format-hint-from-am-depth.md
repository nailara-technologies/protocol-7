# audio icon : automatic square-vs-wide format hint from am_depth

## status

deferred / not started. captured from conversation so it isn't lost.
depends on the povray cylinder-wrap work
(`data/tasks/povray-zenka-implementation.md`,
`data/tasks/audio-icon-povray-glass-cylinder-wrap.md`) existing as a
real alternate presentation before this decision has anything to
switch between.

## the idea

decide automatically, per file, whether a given audio's icon should
default to the plain square presentation or the wide/cylinder
presentation — rather than a global fixed choice — based on a signal
already available from the render pipeline itself, no new analysis
pass needed.

## why `am_depth` is the right signal, not silence detection

comparing `icon_aa.png` (purring, dense) and `icon_ac.png` (meowing,
scattered) directly: `aa` fills the square with a dense, symmetric
nested-square frame edge-to-edge — well-suited to a square icon.
`ac`'s content clusters into the four corners with a comparatively
empty band top/bottom, its meaningful content sitting in a horizontal
band — better suited to a wide format (see
`audio-icon-povray-glass-cylinder-wrap.md` for the fuller reasoning
and the cylinder-wrap proposal this feeds into).

`audio.render_standing_wave.v4` already computes exactly the metric
that predicts this: `am_depth`, the coefficient of variation of
low-band energy across FFT windows (built originally for v4's
dash/gap ring pattern, see
`data/ai-mem/claude/topic-audio-render-as-similarity-feature-source.md`).
already-measured values from earlier testing this session: `aa` =
0.125, `ab` = 0.06 (both low, both render dense), `saturnians` = 0.78,
`ac` = 1.0 (clamped max, both render scattered) — a near-perfect
correlation between `am_depth` and "will this render dense or
scattered" already observed, not hypothesized.

silence/loudness detection was considered and rejected as the primary
signal: it measures gaps/dynamic range, not spectral or temporal
complexity. a loud continuous drone and a loud chaotic burst pattern
can have identical silence profiles (neither has any) while rendering
completely differently — `am_depth` measures the actual thing driving
visual scatter, since it comes from the same FFT content that feeds
the renderer, computed *before* any pixel is drawn. deriving a scatter
signal from the *rendered PNG's pixels* after the fact was also
considered and rejected as strictly more roundabout than a signal
already computed upstream.

## proposed mechanism

1. thread `am_depth` (or an equivalent band-energy-spread stat) out of
   the render pipeline regardless of which `render_style` actually ran
   — currently it's v4-specific; either compute it generically in
   `audio.finalize_decode` before dispatching to a style, or have
   every `render_style` variant report it in `$stats` even if it
   doesn't use it for its own geometry.
2. pick a threshold (needs real calibration against more than the 4
   samples tested so far — `aa`/`ab`/`saturnians`/`ac` is a start, not
   a real distribution) above which the wide/cylinder format is
   selected as the default instead of square.
3. expose the choice as a hint in `audio.finalize_decode`'s reply
   (e.g. `format_hint: 'square' | 'wide'`) rather than forcing a
   decision inside the renderer itself — the caller (whatever
   eventually invokes the povray cylinder stage) decides what to do
   with the hint.

## explicitly out of scope here

**whether/when to mix square and wide icons within the same list or
directory view** is a separate, later UI/UX decision — a directory
listing might want visual consistency (all-square or all-wide) even
if individual files would "prefer" different formats on their own.
this task is only about generating the per-file signal; consuming it
consistently across a listing context is deferred to whoever builds
that UI.

#,,.,,,..,,,,,.,,,.,.,,..,,,,,.,,,,..,.,.,..,,..,,...,...,,.,,.,,,...,..,,.,.,
#ZUNRWMWNYVHXOMNE5ZBC5B73Q2TVO6AAJYC4NP7TJNF2P7ZNPZ76ZHV7F62TJIBRIK47NHY7WGIM2
#\\\|4L7S3QW2LLWFHWTFLKUHGP2XKEJIN47ALXMPF3ILVJT75OUZ55E \ / AMOS7 \ YOURUM ::
#\[7]R4H2SYRKFJQ4INBJ7DANTOR4GO6YGJBYBLNPT74HRBXGW5GVUUDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
