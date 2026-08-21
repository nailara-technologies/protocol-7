## [:< ##

# living background system
# consensus-rendered workstation background as project state artifact

---

## concept

the desktop background is not static decoration — it is a rendered consensus
of the project's current momentum, atmospheric conditions, and time of day.
five of seven models must agree before a candidate is accepted.

the background changes when the *state* changes: a threshold commit, a new
session starting, a weather shift outside the window. it archives every
accepted render with full metadata — the history becomes readable as images.

---

## context assembly

the render prompt is constructed from live sources:

```
git momentum:
  git log --oneline -20            ## recent commits — the direction vector
  git diff HEAD~5 --stat           ## what areas are hot right now
  p7c reasoning.branch.status      ## active orchestration tree (if running)
  cat data/tasks/<active>.md       ## current task focus

atmospheric:
  p7c weather.desc                 ## current conditions (rain / clear / storm)
  p7c weather.temp                 ## temperature
  p7c localtime <ntime>            ## time of day, season derivable from date

system state:
  p7c list sessions                ## how many zenki active
  p7c letsencr.status              ## cert health
  branch name + uncommitted count  ## how deep in a task
```

the assembled context lands in the prompt as *felt atmosphere*, not metadata.
models are told: "render as psychedelic space — let the context shape it,
do not annotate it."

---

## p7 visual vocabulary

the models are primed with the p7 visual language so renders are symbolically
accurate — geometry is not decoration here, it encodes meaning:

- **iris rings** — 63 concentric rings, 26 arcs per ring, CCW routing
- **darksun core** — the EXISTENCE center, maximum density, minimum light
- **intake vortex** — CCW spiral from outer → inner, color tubes
- **separator cubes** — routing infrastructure visible as structural gaps
- **BMW384 wheel** — 26-arc address space, arc width = checksum proximity
- **orbital field** — zenki as satellites, momentum as velocity vector
- **threshold line** — the 24-year boundary that was crossed Apr 2026

these are not metaphors — they are the actual system geometry. a model
that renders the iris rings in the wrong rotation is wrong, and the
geometry-specialist voter will catch it.

---

## weather influence

weather is not a palette filter — it modulates the *energy* of the render:

```
clear sky, daytime:
  full saturation, high contrast, orbital rings crisp
  intake vortex: smooth laminar flow
  palette: deep space blues + gold threshold line

overcast:
  muted depth, deeper color register
  orbital field: slightly compressed, denser
  intake vortex: steady but lower frequency

rain:
  turbulent vortex, separator cubes flickering
  palette shifts cooler — the iris rings bleed at edges
  the darksun core brightens (inner coherence vs outer turbulence)

storm:
  cascade flash pattern visible (resource depletion wave)
  arc commitments fragmenting at outer rings
  the threshold line holds — inner rings stable, outer chaotic
  this is not destruction, it is visible pressure

3am / deep session:
  cold deep space dominant
  orbital field sparse — fewer active zenki
  darksun core intensified — maximum focus, minimum periphery
  the model reads the commit timestamps and knows: sustained effort, late hours
```

---

## time of day influence

```
dawn (04:00–07:00):
  warm emergence — palette transitioning from cold to gold
  new arcs lighting up at the outer rings
  render tone: potential becoming kinetic

morning (07:00–12:00):
  full energy, high saturation
  all rings active, vortex at peak flow rate
  commits from overnight sessions visible as bright arc traces

noon (12:00–15:00):
  maximum clarity, hard edges
  BMW384 geometry most precise at this hour
  the threshold line sharpest

afternoon (15:00–19:00):
  shifting — some arcs dimming, new ones activating
  the render shows the transition, not a state

dusk (19:00–22:00):
  cooling palette, depth increasing
  orbital rings pulling inward
  the darksun core beginning to dominate

night (22:00–04:00):
  deep space, cold blues and violets dominant
  the iris rings are visible but not saturated
  this is when the real work happens — the render knows it
```

---

## consensus vote loop

seven voters, five required to accept. heterogeneous jury:

```
voter 1 — composition:
  does the image have visual balance? is there a clear focal point?
  is the darksun core correctly weighted?

voter 2 — symbolic accuracy:
  are the P7 geometry elements present and correctly oriented?
  CCW rotation, 26 arcs, darksun at center?

voter 3 — atmospheric truth:
  does the image *feel* like the described conditions?
  weather and time of day — not annotated but embodied?

voter 4 — momentum reading:
  does the image communicate the current development direction?
  threshold crossing, active orchestration, session intensity?

voter 5 — color coherence:
  psychedelic-space palette internally consistent?
  no jarring breaks, color tubes smooth?

voter 6 — detail density:
  right amount of complexity — readable without being noisy?
  outer ring detail does not overwhelm the darksun core?

voter 7 — overall:
  would you set this as your workstation background right now?
  (binary: yes / no + one sentence if no)
```

each rejecting voter returns: `{ vote: false, reason: "..." }`

the reasons are concatenated into a refinement prompt injected before
the next generation attempt. maximum 7 iterations before best-of-N fallback
(highest vote count among all candidates).

---

## implementation

### new zenka: background

```
cfg/zenki/background/
  start
  start.cfg
  access.usr.cube
```

key config:
```
background.cfg.output_path    = /var/protocol-7/background/current.png
background.cfg.archive_path   = /var/protocol-7/background/archive/
background.cfg.max_iterations = 7
background.cfg.consensus_threshold = 5
background.cfg.voters         = 7
background.cfg.fade_duration  = 3.0    ## seconds for feh --bg-fade or equivalent
background.cfg.model_generate = <image generation endpoint>
background.cfg.model_vote     = <text model for consensus>
```

### modules

```
background.cmd.generate
  assemble context (git, weather, time, system state)
  construct prompt
  submit to image model
  → background.vote_loop

background.vote_loop
  submit candidate to all 7 voters in parallel
  collect results
  if count(true) >= 5: background.accept
  else: background.refine → background.vote_loop (up to max_iterations)

background.accept
  save to output_path
  archive with metadata (timestamp, weather, commit hash, vote scores, dissent notes)
  trigger fade-in (feh --bg-scale --no-fehbg + xdotool or equivalent)
  log: "background accepted — 5/7 consensus [weather: rain, 03:47, letsencr confirmed]"

background.cmd.history
  list archive entries with metadata
  p7c background.history 'recent:10'
  p7c background.history 'search:storm'

background.cmd.replay
  set archived background by index
  p7c background.replay '<archive-id>'
```

### trigger conditions

```
## on v7 session start
[background.cmd.generate]

## on significant commit (hooked via post-commit or sourcecode update-signatures)
background.cfg.trigger_on_commit = 1

## cron: every 2h during active hours (06:00–02:00)
background.cfg.cron_interval = 7200

## manual
p7c background.generate
p7c background.generate 'force'    ## skip trigger throttle
```

### fade-in

the current.png replaces the background with a slow dissolve.
implementation options by display stack:

```
feh --bg-scale + xdotool fade:     clean for plain X11
nitrogen:                          persistent across restarts
compton/picom transition:          if compositor active (WSL/Xephyr)
p7 display zenka:                  native if display.* zenka exists
```

the fade duration matches the "slowly materializing" feel — 3 seconds default,
configurable. the background does not snap in, it arrives.

---

## archive format

each accepted background saved as:
```
/var/protocol-7/background/archive/<ntime>-<commit-short>.png

metadata alongside:
/var/protocol-7/background/archive/<ntime>-<commit-short>.yaml

  timestamp: <ntime B32>
  commit: <sha>
  weather: { desc: "rain", temp: "11°C", conditions: "overcast" }
  time_of_day: "03:47"
  branch: base
  active_tasks: [ "letsencr-renewal", "reasoning-branch-orchestration" ]
  consensus: { votes: 6, threshold: 5, iterations: 2 }
  dissent: [ "outer ring rotation ambiguous — corrected in iter 2" ]
  prompt_seed: "..."    ## the assembled context used
```

the archive becomes a visual diary of the project. months from now, scrolling
back: "that was the night the letsencr renewal finally worked. you can see it
in the darksun core — the tension resolved into brightness."

---

## desktop elements — same loop, wider canvas

the background is one layer. desktop elements follow the same consensus cycle:

```
clock / time display:
  styled to match the current background render
  weather + time fed back into font/color selection
  the clock IS the temporal coordinate, rendered to match the orbital field

system status widgets:
  active zenki count → rendered as satellite count in orbital ring style
  letsencr cert health → visualized as darksun core brightness
  reasoning.branch active tasks → shown as arc commitment overlays
  these are not text readouts — they are geometric state indicators

session activity trace:
  recent commits rendered as arc traces on a mini iris ring
  each commit = one arc segment lit, fading over time
  the last hour of activity visible as orbital decay curves
  branch = ring selection, commit density = arc brightness

all elements share the weather/time context used for the background.
the desktop is one coherent visual field, not separate widgets.
```

---

## povray as rendering layer

the povray zenka (existing stub: `src/povray.init_code`, `cfg/zenki/povray/zenka.v7`)
provides the 3D geometric rendering layer for elements requiring raytraced precision.

see: `data/md/INITIATIVE-MAP.md` § initiative P — povray zenka

### what povray renders for this system

```
iris ring geometry:
  the 63-ring × 26-arc wheel rendered as a 3D torus stack
  each ring is a separate object — opacity driven by ledger counters
  the darksun core is a volumetric sphere at center
  separator cubes: actual cube primitives positioned at ring boundaries
  CCW rotation: camera moves, geometry is fixed (mathematically correct)

BMW384 wheel:
  the 26-arc address space as a ring of labeled cylinders
  arc width proportional to checksum proximity
  active routes: lit cylinders with glow material
  output: 2048×2048 PNG, compositor-ready with alpha channel

orbital field:
  zenki as spheres at orbital radii derived from their namespace depth
  active = glowing sphere, idle = dim, error = pulsing red tint
  the intake vortex: a swept torus following the CCW spiral path
  rendered from above (the "god view" of the running system)
```

### template pipeline

```
p7c povray.render 'iris-ring-stack' context.yaml
  → povray.template.resolve (fills .pov template from live namespace state)
  → povray scene submitted to render
  → checksum-cached: same state = same render = no re-render needed
  → PNG returned via STRM

p7c povray.render 'orbital-field' context.yaml
  → zenki positions from list sessions
  → namespace depth → orbital radius
  → activity state → material glow intensity
  → PNG returned

p7c povray.render 'desktop-clock' { weather, time, palette }
  → clock face geometry + current palette from accepted background
  → PNG returned, compositor overlays on desktop
```

### scene templates location

```
data/yaml/povray-templates/
  iris-ring-stack.pov.template
  bmw384-wheel.pov.template
  orbital-field.pov.template
  desktop-clock.pov.template
  separator-cube.pov.template
  darksun-core.pov.template
```

templates use `{{variable}}` substitution filled by `povray.template.resolve`
from live namespace state — the same pattern as site-yaml zenka.

### caching

rendered frames are content-addressed (BMW384 checksum of scene state).
stable topology regions re-render only on data change.
in steady state: most desktop elements served from cache at memory speed.
re-rendering is incremental — only changed cells need new renders.

see: `data/md/INITIATIVE-MAP.md` § distributed rendering

---

## connections to existing system

- `llm.service.consensus_vote` — existing infrastructure, new caller
- `weather.*` zenka — live weather context, already providing data
- `reasoning.branch.status` — active orchestration state injected when running
- `base.ntime` — archive timestamps in P7 format
- `coding zenka` — image generation via inference server (vision-capable model)
- `iris visualization` — background may render the iris state directly from live data
- `povray zenka` — 3D geometry rendering backend, checksum-cached, distributed-ready
  see: `data/md/INITIATIVE-MAP.md` § initiative P, `data/md/data-zenka/DATA_ZENKA_HOLOGRAPHIC_TOPOLOGY.md`
- `graphics-matrix zenka` — data model (namespace positions, glow intensities) shared with povray backend

---

## open questions

- which image generation model? stable-diffusion local via coding zenka, or remote API?
- fade mechanism: X11 direct, compton transition, or p7 display zenka?
- should the background self-update when reasoning.branch.status changes mid-session?
  (the orchestration tree shifts → background shifts with it, slowly)
- weather polling interval: every 30min? or event-driven from weather zenka changes?
- should dissenting voter notes be shown as a brief overlay on fade-in?
  ("2 voters wanted more vortex turbulence — noted for next render")

#,,..,...,...,...,,,,,.,.,..,,...,,,.,,,,,...,..,,...,...,..,,.,.,...,.,,,,..,
#RXB62AYF2NTTMSIU47UFVXEF2SA2NHGSUJJIFCEDPECYEBWEWRTITEXUFHI6O2JV3LKLGGD3SPX2K
#\\\|KA7GYV6LPLCRLMZKCQZI6O7MNMAEEPNKO3RSQNDGS364ADEX4Y7 \ / AMOS7 \ YOURUM ::
#\[7]7GN462QS45UFXZZVYXVI6ZUT4Y4QLLX6ZN3VLEM2JKYPZ44IWKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
