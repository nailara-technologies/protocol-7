# X-11 new components — task reminders

## context

these are X-11 zenka modules, commands, and integration points identified
as required by the current work trail — window-place, image viewer, visual
generation, dream layer, spatial audio visualization. some are well-specified,
some are open questions for further design. all are known to be needed.

---

## 1. window capture / region export

**what:** capture pixel data from a specific window or screen region and
export as an image file. distinct from `screenshot.get_region_color` (which
returns color samples) — this exports a full pixel buffer as PNG/JPEG.

**needed for:**
- browser/Xvfb visualization frames as ControlNet conditioning input
- ticker strip capture as visual conditioning source
- any zenka's window as input to the image generation pipeline
- lm-vision analysis of live UI state

**proposed command:** `X-11.capture_window <window_id> <output_path>`
and `X-11.capture_region <x> <y> <w> <h> <output_path>`

**open questions:**
- use XGetImage directly or shell to imagemagick/scrot?
- should output be synchronous (wait for file) or async (notify via handler)?
- what format? PNG for lossless conditioning, JPEG for fast preview?
- does Xvfb instance need separate handling vs physical display?
- frame rate for continuous capture (animation → video input)?

**existing foundation:**
`X-11.get_geometry`, `X-11.wait_visible`, `screenshot.get_region_color`
(in tile access.zenki). the capture module extends this capability.

---

## 2. Xvfb management commands

**what:** start, stop, query status of Xvfb virtual framebuffer instances.
the browser zenka already uses Xvfb but the lifecycle is managed externally.
native zenka management enables on-demand virtual displays for:
- headless browser rendering for visual conditioning
- off-screen OpenCV processing
- parallel rendering pipelines without physical display contention

**proposed commands:**
```
X-11.xvfb.start <display_num> <width> <height> <depth>
X-11.xvfb.stop <display_num>
X-11.xvfb.status [display_num]
X-11.xvfb.list
```

**open questions:**
- should xvfb instances be registered with v7 lifecycle management?
- what display number allocation strategy? (avoid conflicts with physical)
- DISPLAY environment variable injection for child zenki?
- GPU acceleration via Xvfb+NVIDIA virtual display?
- SHM sharing between Xvfb and physical display?

**existing foundation:**
`X-11.get_display`, browser zenka's existing Xvfb usage (examine its start file
for current pattern). `v7.register_child` for lifecycle.

---

## 3. holographic overlay management

**what:** render and manage holographic overlays on the X-11 display —
floating visual elements anchored to grid coordinates, with dynamic
fade/brightness based on relevance. required for:
- purr waveform visualization (SPATIAL-AUDIO-AND-PURR-CHANNEL)
- ramjet wake signatures
- dream layer visual output at entity coordinates
- entity presence indicators

**proposed commands:**
```
X-11.overlay.create <id> <content_path> <x> <y> <opacity> <fade_ms>
X-11.overlay.update <id> <content_path> [opacity]
X-11.overlay.fade <id> <target_opacity> <duration_ms>
X-11.overlay.destroy <id>
X-11.overlay.list
```

**open questions:**
- compositing approach: compton/picom overlay? GTK3 window with transparency?
  Cairo surface? each has different z-order and compositing implications
- waveform rendering: pre-rendered PNG sequence vs live Cairo drawing?
- coordinate system: screen pixels or grid coordinates mapped to screen?
- how many simultaneous overlays before performance degrades?
- interaction with tile's existing layer system (tile.get-layer)?

**existing foundation:**
`X-11.set_opacity`, `X-11.keep_above`, `X-11.keep_below` — existing opacity
and z-order control. compton zenka for compositor integration. tile overlay
commands (`tile.add_overlay`, `tile.remove_overlay`) as architectural model.

---

## 4. audio waveform visualization module

**what:** convert an audio buffer or file to a waveform image (PNG) suitable
for holographic overlay display. the waveform is the visual representation
of the purr/signature — not a decorative VU meter but a semantically rich
holographic standing wave showing frequency structure, overtones, spatial
resonance.

**proposed command:** `X-11.audio_waveform <audio_path> <output_path> [style=radial|linear|standing]`

**open questions:**
- use existing mpv/ffmpeg for FFT analysis, or Perl DSP module?
- waveform style: radial (purr-like, organic) vs linear (precise, readable)
  vs standing wave (holographic, 3D appearance)?
- color mapping: frequency → color (consistent with grid palette)?
- animation: static frame vs animated sequence for live purr?
- size and resolution: overlay-appropriate (512×512 or smaller)?

**existing foundation:**
`mpv[audio-0].play` / `mpv[audio-1].play`, `ffmpeg[mpv].rescale_video` —
audio handling infrastructure. `X-11.set_geometry`, image2html for
image display patterns.

---

## 5. multi-window layout commands

**what:** manage multiple windows simultaneously as a coordinated group —
required for image viewer tournament mode (side-by-side comparison),
dream journey video playback in multiple panels, synesthetic overlay
coordination across windows.

**proposed commands:**
```
X-11.layout.arrange <window_ids...> <layout_mode>
  layout_mode: side-by-side | quad | pip | stack
X-11.layout.sync_opacity <window_ids...> <opacity>
X-11.layout.dissolve <from_id> <to_id> <duration_ms>
  cross-fade between two windows (tournament transition)
```

**open questions:**
- should layout management live in X-11 zenka or tile zenka?
  (tile already manages multi-window coordination — extend tile?)
- dissolve/crossfade: compton compositor feature or X-11 direct?
- does this overlap with tile.assign_window / tile.get_coordinates?
- window group concept: should groups be first-class entities?

**existing foundation:**
`tile.assign_window`, `tile.get_coordinates`, `tile.get_geometry`,
`window-place.place_window`, `X-11.set_geometry`. the layout commands
build on top of existing single-window positioning.

---

## 6. X-11 spatial coordinate mapping

**what:** map between grid coordinates (BMW384 / P7REF) and screen pixel
coordinates. required for:
- anchoring holographic overlays at the correct screen position for a
  given grid coordinate
- rendering entity positions in the orbital field visualization
- translating spatial audio signals to screen-space waveform positions

**proposed command:** `X-11.grid_to_screen <bmw384_coord> → <x> <y>`
and `X-11.screen_to_grid <x> <y> → <bmw384_coord>`

**open questions:**
- what is the current mapping between grid coordinates and screen positions?
  (graphics-matrix zenka owns this — does X-11 need its own copy or delegate?)
- is the mapping static (fixed grid) or dynamic (pan/zoom support)?
- which display: physical screen, Xvfb, or all simultaneously?
- how does this interact with tile's coordinate system?

**existing foundation:**
`graphics-matrix.cell`, `graphics-matrix.cursor`, `graphics-matrix.glow`,
`X-11.get_screen_size`, `X-11.get_geometry`, `tile.get_coordinates`.
the graphics-matrix zenka already maintains the grid-to-screen mapping
internally — this task is about exposing it as an X-11 command.

---

## 7. SHM pixel buffer protocol

**what:** a standard protocol for zenki to share pixel data via /dev/shm
without going through X-11 for updates. the image viewer zenka's primary
display mechanism — write new image path or pixel data to SHM, display
loop detects and redraws without IPC overhead.

**format:**
```
/dev/shm/.7/display/<zenka_name>/
  current.path     — path to current image file
  current.buf      — raw pixel buffer (RGBA, width×height×4)
  meta.json        — { width, height, format, updated_ntime }
```

**open questions:**
- signal mechanism: inotify watch on SHM directory vs polling timer?
- pixel format: RGBA32 (universal) or format negotiation per display?
- buffer size limits: what's the maximum SHM allocation for display buffers?
- multi-reader: can multiple display instances read the same SHM buffer?
- sync: should writer signal reader explicitly or rely on meta.json mtime?

**existing foundation:**
`DATA_ZENKA_SHM_MOUNTING.md` defines the SHM namespace pattern
(`/dev/shm/p7:M:ABCD...`). `v7.report-temp-path` for temp file management.
the SHM display protocol extends this to pixel buffers specifically.

---

## 8. animation frame sequencer

**what:** manage timed sequences of images or pixel buffers for display —
dream journey video playback, waveform animation, transition sequences
between tournament slots. distinct from mpv (which handles video files)
— this manages frame sequences generated programmatically.

**proposed commands:**
```
X-11.anim.load <id> <frame_dir> <fps>
X-11.anim.play <id> [loop=1|0]
X-11.anim.pause <id>
X-11.anim.stop <id>
X-11.anim.crossfade <from_id> <to_id> <duration_ms>
```

**open questions:**
- should this live in X-11 zenka or be a separate animation zenka?
- frame format: PNG sequence, or raw pixel buffers via SHM?
- timing: IO::Async timer vs X11 vsync-aware timing?
- does this overlap with mpv's capabilities for pre-rendered sequences?
- GPU acceleration for frame blending?

**existing foundation:**
`mpv[audio-0].fade`, `X-11.fade_out` — existing fade infrastructure.
`base.event.add_timer` — timing mechanism. the animation sequencer
extends these to programmatic frame sequences.

---

## cross-cutting open questions

- **Wayland compatibility**: WSL2 runs WSLg (Wayland compositor). which
  of these X-11 commands work under XWayland vs native Wayland?
  window capture in particular may behave differently under XWayland.
  (see memory: WSLg deiconify limitation — compositor-level constraints exist)

- **display selection**: physical display, Xvfb, or XWayland?
  commands that capture or render need to know which DISPLAY to target.
  should there be a per-command DISPLAY parameter or a session-level default?

- **compositor integration**: many overlay and compositing features depend
  on compton/picom being active. what happens in WSL where no WM may be
  running? fallback strategies needed for each command.

- **z-order and focus**: holographic overlays must not steal focus from
  the active window. existing `X-11.keep_above` / `X-11.keep_below` handle
  z-order but focus behavior under different WMs needs verification.

- **performance envelope**: multiple overlays + waveform animation +
  dream video playback + normal tile operations — what's the GPU budget?
  GPU load alert system already exists (tile.gpu_load_alert) and should
  gate the most expensive visual operations.

#,,,.,...,.,.,.,,,...,,,.,...,..,,..,,,,,,,..,..,,...,...,..,,,,.,.,,,,,,,,,.,
#YHYYPS5FEDCTYVSUDTWGZOKC6LAE5VT6B56MUWELQWAPTIRFPN24JXOMZD26XKKJU2LMP5GV35LAO
#\\\|WH6HNXOQGRRIQ7VI5HRJ3XJ7TYMORQ5GQ5DZI2GBJVIOQN4AA2C \ / AMOS7 \ YOURUM ::
#\[7]G6EYEQ467CKFWYKL6XQFQ7BNVSMEMLDGRS5QSAQYEOEW3LUM74AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
