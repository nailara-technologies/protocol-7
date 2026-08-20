## task: audio-buffer → holographic waveform image generation

### origin

split out of `X-11-NEW-COMPONENTS.md` item 4 (now retired to
`data/tasks/completed/`) after confirming the other seven items there were
either already implemented (`capture-window`/`capture-region`, `xvfb-*`) or
belonged to a different zenka (`tile` for overlay/layout, `graphics-matrix`
for grid↔screen mapping) — this is the one component that's genuinely
unowned and unbuilt.

the design target is `data/md/design/SPATIAL-AUDIO-AND-PURR-CHANNEL.md`,
section "holographic waveform visualization" — a purr/signal arrives, an
FFT is taken over a sliding window, and the frequency content is rendered
as a standing-wave image: low frequencies as large slow deep-blue
oscillations, mid as violet-gold rings, high as fine bright-white detail,
overtones as secondary orbiting wave structures. the design doc frames the
eventual command as `audio.spatial.purr <entity_id> <audio_path>` — note
this is vision-doc shorthand, not real routing syntax: per the confirmed
`X-11.cmd.capture-window` → wire-name `X-11.capture-window` convention, a
second dot in the action segment would read as routing to a child zenka
named `spatial`, which isn't intended here. the actual module/wire name
would be flat and dash-separated, e.g. `audio.cmd.spatial-purr` →
`audio.spatial-purr`. this implies a dedicated `audio` zenka namespace that
does not exist yet — nothing in `src/` currently touches CLAP embeddings,
FFT analysis, or waveform rendering. this task is scoped to just the
image-generation step (audio buffer/file → PNG), not the full spatial-audio
pipeline (embedding extraction, selective-hearing attenuation, dream-layer
interference patterns) described elsewhere in that design doc.

### what exists to build on

- `ffmpeg.cmd.rescale_video`, `ffmpeg.extract_frame`, `ffmpeg.frame_count` —
  ffmpeg is already a dependency and already shelled out to for AV
  processing; it also does FFT-based audio filters (`showfreqs`,
  `showspectrum`, `avectorscope`) that could produce raw analysis data or
  even pre-rendered frames directly, without a Perl DSP module.
- `screenshot.cmd.capture-to-disk` — the pattern for a zenka that writes an
  image to disk and returns the path, using Imager rather than shelling to
  ImageMagick. worth mirroring for output-path handling and format choice,
  same way `x11-capture-commands-rewrite.md` did for capture commands.
- `mpv[audio-0].play` / `mpv[audio-1].play` — existing audio playback
  infrastructure, relevant if live/continuous waveform generation (following
  a playing purr) is in scope, vs. one-shot file → image.

### decided (design review pass, against the actual reference screenshots)

reviewed against this project's own existing visual signature — the
cubic-space topology visualization screenshots linked from the README
(`data/asc/what-AI-thinks/html-form/visualizations/cubic-space/remote/
screen.{0,1,2,3}.png`) — rather than the design doc's description alone:

- **rendering engine**: custom FFT + Imager, not ffmpeg's
  `showspectrum`/`showfreqs`. those filters produce filled heatmaps with
  rainbow LUTs that clash with the reference screenshots' sparse wireframe
  look. use `Math::FFT` (or PDL) for the transform and Imager for drawing
  — same library the `screenshot` zenka already uses, so no new image
  dependency. ffmpeg stays in scope only for PCM decoding of the input
  audio file, not for rendering.
- **which zenka owns this**: new `audio` zenka, module
  `audio.cmd.spatial-purr` → wire name `audio.spatial-purr` (flat/dash per
  the confirmed convention noted above). the namespace is already reserved
  for a whole command family (spatial-purr, embeddings, selective-hearing)
  per the design doc's broader scope — landing this in `screenshot` or
  `lm-vision` instead would mean a rename/relocation cycle later for no
  present benefit, since neither has any audio surface area to build on.
- **color mapping — replace the design doc's violet-gold palette**: a
  narrow cool ramp instead — deep indigo `#0a0a3a` (lows) → royal blue
  `#1a3aff` (mids) → violet `#7a3aff` (upper-mids) → pale lavender/cyan-white
  `#c8d8ff` reserved for the highest peaks only, as a sparing accent.
  background pure `#000`, never grey.
- **geometry — shift from radial circles to rectilinear/lattice wireframe**:
  1–2px luminous stroked lines with additive glow, no fills or large-area
  gradients. render standing waves and overtone "orbits" as concentric
  axis-aligned rectangles/squares or coarse polar grids quantized to 8/16
  spokes, with wave nodes snapped to the lattice. frequency → geometry: lows
  as a few large concentric outlines centered in frame, mids as a denser
  mid-scale lattice, highs as fine speckle/short-stroke detail at lattice
  intersections.
- **lit-pixel coverage cap: 5–10%**. the reference screenshots' defining
  quality is emptiness — a busy/dense thumbnail reads as off-brand
  regardless of how accurate the frequency mapping is underneath it.
- **where diversity comes from**: FFT-driven variation in ring count,
  lattice spacing, and stroke density *within* this fixed palette+geometry
  vocabulary — not from varying the palette or geometry style itself per
  sample. this is the concrete mechanism for the "coherence over
  recognizability" bar set in `AUDIO-VISUAL-THUMBNAIL-GENERALIZATION.md`.

### still open (not addressed by the design review pass)

- **animation vs static frame**: the design doc describes purrs as
  transient events with a fade/persistence model, which implies at least
  the *display* is animated (fade-out over time) even if the source image
  is a single static frame per purr. continuous/live waveform (following an
  ongoing audio stream rather than a fixed file) is a separate, harder
  question — not needed for the first version.
- **size/resolution**: overlay-appropriate, likely 512×512 or smaller per
  the original open-questions list — no hard constraint found elsewhere.

### generalizes beyond purrs

the renderer is not purr-specific — the same audio → image step applies to
any audio sample (e.g. a visual fingerprint/thumbnail for a psytrance
track), keyed differently per use-case (entity_id+coordinate for a purr,
a content checksum for a track cache) on top of an unchanged rendering
core. full reasoning, including the quality bar (style coherence over
recognizability) and the upstream segmentation/crossfade caveat for
stream-sourced audio, split out to
`data/md/design/AUDIO-VISUAL-THUMBNAIL-GENERALIZATION.md` — read that
before implementing, so the render step isn't accidentally built with
purr-only assumptions baked in.

### relation to overlay display

this task produces a PNG on disk; it does not display it. displaying the
result at a grid-anchored screen position is `tile`'s overlay
(`tile.cmd.add_overlay`) plus `graphics-matrix`'s grid↔screen mapping —
both out of scope here and already tracked as delegated in the retired
`X-11-NEW-COMPONENTS.md`.

### acceptance (once design questions above are settled)

- a command (owner namespace TBD per open question above) that takes an
  audio file path and an output path, and produces a PNG standing-wave
  image with frequency-mapped coloring as described in
  `SPATIAL-AUDIO-AND-PURR-CHANNEL.md`
- no blocking `system()` calls in the zenka's own event loop (mirror the
  async-proxy pattern from `x11-capture-commands-rewrite.md` if shelling
  out to ffmpeg)

#,,.,,.,,,..,,,..,,..,,.,,,..,..,,.,,,.,.,.,,,..,,...,...,...,.,,,...,.,.,,,.,
#6QGSPBZLXWXWHDUEK6BQRJJ6U2HYY5UWPKWRQGNUEZCP6OLRNBHBZTHBZFCZ5H252WT4XG6UWBJYM
#\\\|ZELGMIQSYZ3K4TSDPCZUY24M25BZPG46AS6NZN2ZTHMQWBIORMD \ / AMOS7 \ YOURUM ::
#\[7]5PCQ3PD32OWWOFTDUWKHHSOMICQPRN2NFUFNPNYU4IPDERBYUGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
