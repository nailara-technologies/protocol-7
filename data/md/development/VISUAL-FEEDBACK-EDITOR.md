# visual feedback editor — autonomous visual design loop

## what it is

a system that lets local vision models (qwen, kimi-vision, etc.) work
autonomously on visual element design and refinement. not a screenshot tool —
a closed visual feedback loop where the rendered output IS the feedback signal.

```
design prompt + initial code
  ↓
browser renders in xvfb/openbox
  ↓
frame capture (N frames)
  ↓
delta analysis → intelligent frame selection → minimap timeline
  ↓
vision model reads minimap + selected frames + design prompt
  ↓
feedback: "spiral is CW, flip it" / "arm color needs UV blue"
  ↓
coding zenka applies correction
  ↓
repeat until convergence
```

this is what claude design does internally — we build it natively with our
own zenki, our own models, on our own hardware. zero token cost per screenshot.
no opacity, no rate limits, no waiting for external api.

---

## why 5 fixed frames is wrong

claude design takes 5 equally-spaced frames. for animated visualizations:

```
naive:     t=0%  t=25%  t=50%  t=75%  t=100%
           captures regardless of whether anything interesting happened

problem:   a CCW arm sweep takes 200ms in a 3s animation
           5 fixed frames may completely miss it (1 in 15 chance per frame)
           the vision model sees "static rings" when there ARE arms sweeping
```

the intelligent approach: **difference-based frame selection**

```
capture:   60 frames across the animation cycle (high rate)
analyze:   pixel delta between consecutive frame pairs → delta curve
select:    peaks of delta curve (high-change moments) + stable baselines
result:    5-8 frames that actually represent the animation's behavior
```

---

## the delta analysis pipeline

### frame capture

```
render file in xvfb/openbox browser session
capture N frames at even intervals:
  N = animation_duration_ms / capture_interval_ms
  default: 60 frames per second, 3s animation = 180 frames
  minimum: 30 frames (enough for meaningful delta analysis)

output: sequence of PNG files
  frame_0001.png, frame_0002.png, ... frame_0180.png
```

### pixel delta computation

```perl
for each consecutive pair (frame_i, frame_{i+1}):
  load both as pixel arrays (use Imager or GD perl module)
  compute per-pixel absolute difference
  mean_delta_i = sum(abs(pixel_i - pixel_{i+1})) / total_pixels
  normalize to [0, 1]: delta_curve[i] = mean_delta_i / max_possible_delta

result: delta_curve = [0.02, 0.03, 0.51, 0.67, 0.72, 0.48, 0.12, 0.03, ...]
                                          ^^^ arm sweep happening here
```

### peak detection

```perl
find local maxima in delta_curve:
  a point i is a peak if delta_curve[i] > delta_curve[i-1]
              AND delta_curve[i] > delta_curve[i+1]
              AND delta_curve[i] > threshold (default: 0.15)

enforce minimum spacing: peaks must be > spacing_frames apart
  (avoid selecting 3 frames from the same 50ms burst)
  default spacing: animation_frames / 10

sort peaks by delta value (highest first)
select top K peaks (default K = 4)
```

### frame selection

```
selected_frames = [
  frame 1,                           # bookend — initial state
  top 4 peak frames,                 # high-delta moments — the action
  1-2 low-delta frames (baselines),  # stable state — "normal" appearance
  last frame,                        # bookend — end state
]

total: 7-8 frames maximum
```

---

## the minimap timeline

a single image combining selected frames + delta curve:

```
┌──────────────────────────────────────────────────────────────────┐
│                     animation timeline                            │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐│
│  │frame1│ │frame3│ │frame5│ │frame7│ │frame9│ │frame2│ │frame8││
│  │      │ │      │ │      │ │      │ │      │ │      │ │      ││
│  │ t=0s │ │t=0.3s│ │t=0.8s│ │t=1.4s│ │t=2.1s│ │t=2.7s│ │ t=3s ││
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘│
│  ▁▁▂▃▄▇█▇▅▂▁▁▁▁▂▄▆█▆▃▁▁▁▁▁▃▅▇▅▃▁▁▁▁▁▂▄▆▄▂▁▁▁▁▁▁▁▁▂▃▄▃▂▁▁▁▁▁▁▁│
│  ← delta curve (selected frames marked with ▲ below their peak) │
└──────────────────────────────────────────────────────────────────┘
```

the minimap is itself a rendered HTML file (not image stitching):
  - thumbnail `<img>` tags for each selected frame
  - SVG `<path>` for the delta curve
  - timestamp labels below each thumbnail
  - `▲` markers where selected frames appear on the delta curve

render the minimap HTML → take one screenshot → send to vision model
one image conveys the full temporal structure of the animation.

---

## the vision model evaluation loop

### the prompt structure

```
system: you are evaluating a visual design against a specification.
        you will see a minimap timeline showing selected frames from an
        animated visualization. assess whether the design matches the spec.

spec:   [the original design prompt]
        example: "CCW bioluminescent UV vortex with implosion direction,
                  violet-blue arms, white-gold center, deep space background"

minimap: [the minimap image]

evaluate:
  1. what is correct (do not mention — focus on corrections only)
  2. what specific elements need changing, in order of visual impact
  3. for each correction: the exact code change needed (property, value)
  4. convergence assessment: 0-100% match with spec
     - below 40%: major structural issues
     - 40-75%: style/direction corrections needed
     - 75-90%: fine-tuning
     - above 90%: converged — stop loop

output format (machine-parseable):
  CONVERGENCE: 67%
  CORRECTIONS:
  1. rotation direction: currently CW, must be CCW
     fix: reverse animation transform direction
  2. arm color: currently gold #FFD700, must be UV blue
     fix: change arm stroke to #8A2BE2 with glow rgba(138,43,226,0.6)
  3. flow direction: currently outward (explosion), must be inward (implosion)
     fix: reverse keyframe gradient direction
```

### the convergence condition

```
loop continues while:
  convergence < 90% AND iterations < max_iterations (default: 8)

loop stops when:
  convergence >= 90% (vision model satisfied)
  OR iterations == max_iterations (give up, report last state)
  OR corrections list is empty (nothing left to fix)

on stop: emit final minimap + convergence score + iteration count
```

### feedback → code edit pipeline

```
vision model output → correction parser:
  extract: element name, current value, target value, fix description

correction parser → coding zenka dispatch:
  for each correction (in priority order):
    coding zenka receives: file path + correction description + context
    coding zenka applies: targeted edit (not full rewrite)
    coding zenka returns: changed line numbers

re-render → re-capture → re-analyze → re-evaluate
```

---

## zenka architecture

```
visual-feedback zenka (on-demand):
  coordinates the full loop
  dispatches to browser, screenshot, vision, coding zenki

visual-feedback.capture-sequence
  args: { file, frames, interval_ms }
  → browser zenka: render file in xvfb session
  → screenshot zenka: capture N frames
  → returns: list of frame file paths

visual-feedback.analyze-delta
  args: { frames[] }
  → compute pixel delta curve across frame sequence
  → detect peaks in delta curve
  → select M informative frames
  → returns: { selected_frames[], delta_curve[], peak_positions[] }

visual-feedback.render-minimap
  args: { selected_frames[], delta_curve[], timestamps[] }
  → generate minimap HTML with thumbnails + delta SVG
  → browser zenka: render minimap HTML
  → screenshot zenka: capture single minimap image
  → returns: minimap_image_path

visual-feedback.evaluate
  args: { minimap_image, design_prompt, iteration }
  → vision model (qwen or configured model): send minimap + prompt
  → parse response: convergence%, corrections[]
  → returns: { convergence, corrections[], raw_response }

visual-feedback.apply-corrections
  args: { file_path, corrections[] }
  → for each correction: coding zenka targeted edit
  → returns: { changed_lines[], edit_summary }

visual-feedback.loop
  args: { file_path, design_prompt, max_iterations }
  → orchestrates: capture → analyze → minimap → evaluate → apply → repeat
  → stops on convergence or max iterations
  → returns: { final_convergence, iterations, final_minimap_path }
```

---

## module file locations

```
src/visual-feedback.capture-sequence
src/visual-feedback.analyze-delta
src/visual-feedback.render-minimap
src/visual-feedback.evaluate
src/visual-feedback.apply-corrections
src/visual-feedback.loop

cfg/zenki/visual-feedback/start
cfg/zenki/visual-feedback/zenka-startup.v7
```

---

## configuration

```yaml
## cfg/zenki/visual-feedback/zenka-startup.v7

cfg.capture_frames        = 60          ## frames to capture per cycle
cfg.capture_interval_ms   = 50          ## ms between frames (20fps capture)
cfg.select_frames_max     = 8           ## max frames in minimap
cfg.peak_threshold        = 0.15        ## minimum delta to qualify as peak
cfg.peak_min_spacing      = 6           ## minimum frames between selected peaks
cfg.convergence_threshold = 90          ## % convergence to stop loop
cfg.max_iterations        = 8           ## maximum feedback cycles
cfg.vision_model          = qwen-vl     ## vision model to use for evaluation
cfg.minimap_thumb_width   = 160         ## thumbnail width in minimap
cfg.minimap_thumb_height  = 120         ## thumbnail height in minimap
cfg.xvfb_display          = :99         ## xvfb display number
cfg.browser               = chromium    ## browser binary name
cfg.output_dir            = /var/protocol-7/visual-feedback/
```

---

## p7 command interface

```bash
## run full autonomous design loop
p7 visual-feedback.loop '{
  "file": "data/web-root/vhosts/viz.v7.ax/iris.html",
  "prompt": "CCW bioluminescent UV vortex, implosion direction, violet arms, white-gold center",
  "max_iterations": 6
}'

## capture frames only (diagnostic)
p7 visual-feedback.capture-sequence '{
  "file": "path/to/visualization.html",
  "frames": 60
}'

## analyze delta only (see what frames would be selected)
p7 visual-feedback.analyze-delta '{"frames": [...]}'

## render minimap from frame list
p7 visual-feedback.render-minimap '{
  "selected_frames": [...],
  "delta_curve": [...],
  "timestamps": [...]
}'

## evaluate once without loop
p7 visual-feedback.evaluate '{
  "minimap_image": "/var/protocol-7/visual-feedback/minimap.png",
  "prompt": "CCW bioluminescent UV vortex..."
}'
```

---

## the autonomous design workflow

### for a new visualization

```
1. coding zenka writes initial HTML/CSS/JS from design template spec
2. visual-feedback.loop runs with design prompt as spec
3. qwen iterates autonomously: capture → minimap → evaluate → correct
4. on convergence: report final state, commit the file
5. human reviews the converged result
```

### for refining an existing visualization

```
1. human identifies what needs improvement (e.g., "the spiral is CW")
2. visual-feedback.loop runs with specific correction as prompt
3. qwen fixes that element autonomously
4. on convergence: human reviews the single correction
```

### for comparing variants

```
1. coding zenka produces 3-5 variants (different approaches to same spec)
2. visual-feedback.evaluate runs once per variant (no loop — just assessment)
3. qwen scores each variant against the spec
4. highest convergence score → selected for further refinement
5. visual-feedback.loop runs on selected variant
```

---

## connection to reasoning templates

the visual feedback loop IS template 14 (omega-gate-resonance) applied to
visual development:

```
alpha (coding zenka):    generates/edits the visualization code
forward signal:          the rendered visualization (browser output)
omega (vision model):    receives the rendered output, holds the impression
                         (the design spec as harmonic target)
gamma:                   the correction list — omega's knowledge returning
                         to alpha enriched with visual understanding
alpha (enriched):        coding zenka applies corrections from higher base
standing wave:           the loop running — forward + gamma in resonance
convergence:             when the rendered output matches the spec
                         (vision model reports 90%+)
```

the minimap IS the holographic blueprint (template 6, layer 5):
  any frame implies the full animation's character
  the delta curve IS the convergence measurement over time

---

## future extensions

### perceptual delta (beyond pixel diff)

instead of raw pixel delta, use structural similarity:
  SSIM (structural similarity index) between frame pairs
  more robust to anti-aliasing, sub-pixel rendering differences
  better at detecting "the spiral moved slightly" vs "the color changed"

### multi-viewport capture

capture the same animation at multiple viewport sizes simultaneously:
  mobile (375px), tablet (768px), desktop (1440px)
  the minimap shows all three viewports per selected frame
  responsive design bugs visible immediately

### vision model ensemble

send the minimap to multiple vision models simultaneously:
  qwen, kimi-vision, llava (if available)
  aggregate corrections: corrections seen by majority are high-confidence
  corrections seen by only one model: flag for human review
  ensemble convergence: all models agree → stop loop

### animation spec language

instead of natural language design prompts, a structured spec:
  direction: CCW
  color_arms: #8A2BE2 (UV violet)
  color_center: #FFE5A0 (white-gold)
  flow: implosion
  ring_count: 26
  brightness_gradient: inner_bright_outer_dim

the vision model evaluates against the structured spec:
  each field: pass/fail with percentage confidence
  overall convergence: weighted mean of field scores
  structured feedback: field-by-field corrections

#,,.,,..,,.,.,.,.,,..,,,,,,..,.,,,,,.,.,.,,,,,..,,...,...,...,...,...,,,,,,..,
#47JMT2W7Q7YKXQXBPJNHQVBCWIRNXT56K3DS6DEHTP2I4LW4QFDILKRTDRVLYUEP5GCMVAWWXFM2Y
#\\\|DP2QQJBHICFJ7FG5JGBGUPRNLPYMK2DBEWDBGFKDZ2BSEIEQFA3 \ / AMOS7 \ YOURUM ::
#\[7]MCLT5W6ZTKWSXE5UEZVJ7XRAJSKS5TJVSGCDJUTWAHQREJYAKYCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
