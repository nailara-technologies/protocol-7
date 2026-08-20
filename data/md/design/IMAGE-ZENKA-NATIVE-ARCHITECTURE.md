# image zenka — native architecture

## the core argument

InvokeAI's overhead is almost entirely its web UI, workflow graph editor,
model management interface, and API compatibility shim. none of these are
needed. what remains after stripping them:

```
InvokeAI (full):                image zenka (native):

web UI + workflow editor        ✗ removed — zero lines
model management UI             ✗ removed — models zenka handles this
API compatibility layer         ✗ removed — p7 routing is the API
graph builder (invoke.api.*)    ✗ removed — direct inference request
process manager (invoke-web.*)  ✗ removed — spawn pattern from coding zenka
HTTP polling (invoke.handler.*) ✗ removed — async http client from coding zenka
──────────────────────────────────────────────────────────────────────────────
remaining:                      inference backend (spawn + feed + receive)
                                queue management (task zenka pattern)
                                result routing (p7 message routing)
```

the complexity reduction is 80%+. what remains is already implemented
in the coding zenka — it just needs a new namespace.

---

## reusable components — clone by namespace

the coding zenka has solved every sub-problem the image zenka needs.
these modules are cloned into the `image.*` namespace with minimal changes:

### inference server lifecycle
```
coding.spawn_inference_server       → image.spawn_inference_server
  spawn with GPU/CPU backend selection, concurrency guards, binary lookup,
  LD_LIBRARY_PATH setup, IPC::Open3 async, watcher cleanup before respawn

coding.handler.monitor_inference_startup → image.handler.monitor_inference_startup
  non-blocking readiness polling: hit /health endpoint on timer until ready
  on ready: mark server live, flush deferred queue

coding.handler.inference_crash_restart  → image.handler.inference_crash_restart
  SIGCHLD-triggered crash detection and respawn with cooldown
  deferred queue survives crash: jobs re-execute after respawn

coding.handler.inference_server_sigchld → image.handler.inference_server_sigchld
  SIGCHLD watcher: detect unexpected server exit, trigger crash restart
  distinguishes graceful stop from crash

coding.async_spawn_inference_servers    → image.async_spawn_inference_servers
  timer-deferred spawn: schedules spawn 100ms after init completes
  zenka initializes in < 100ms, server spawns non-blocking
```

### async HTTP client (for inference requests)
```
coding.async.http_client     → image.async.http_client
  non-blocking HTTP via Protocol-7 event system
  chunked response handling, progress callbacks
  scaled data-start timeout based on request complexity

coding.async.send_request    → image.async.send_request
coding.async.complete        → image.async.complete
coding.callback.http_chunk   → image.callback.http_chunk
coding.callback.http_error   → image.callback.http_error
coding.callback.retry_request → image.callback.retry_request
```

### task queue
```
coding.task.execute          → image.task.execute
coding.task.execute_round    → image.task.execute_round
coding.task.complete         → image.task.complete
coding.task.queue_next       → image.task.queue_next
coding.task.bury             → image.task.bury
```

### quality scoring — already exists, zero changes needed
```
image-quality.*              — reused directly, unchanged
  image-quality.vision.http_api — calls llama-server with vision model
  image-quality.vision.encode_image — base64 encodes for API
  image-quality.analyze — scores image on aesthetic quality dimensions
```

### model path resolution — reused directly
```
models.get_model             — find model by capability: image-generation
models.recommend             — select best available for current GPU load
models.record_invocation     — track what was used, when, with what result
```

---

## the minimal inference backend

InvokeAI is replaced by a minimal Python diffusers script — no web UI,
no workflow engine, no model manager:

```python
## image-inference-server.py — minimal diffusers HTTP server ##
## accepts: POST /generate { prompt, negative_prompt, steps, seed, ##
##          width, height, model_path, controlnet_inputs,          ##
##          ip_adapter_inputs }                                     ##
## returns: { image_path, seed_used, steps, duration_ms }          ##
## also:    GET /health → { status: ready/loading }                ##
##          GET /progress → { step, total_steps, preview_path }    ##

from flask import Flask, request, jsonify
from diffusers import StableDiffusionXLPipeline, ControlNetModel
import torch, threading, uuid, time
```

spawned exactly like llama-server: IPC::Open3, stdout/stderr piped to
non-blocking watchers, `/health` polled until ready, then job queue flushed.

the script is in `bin/image-inference-server.py` — small, auditable,
no hidden complexity. LD_LIBRARY_PATH setup for CUDA libs, same pattern
as the llama-server spawn.

**backends supported by the same script:**
- SDXL (text-to-image baseline)
- FLUX (higher quality, different architecture)
- ControlNet conditioning (depth/normal/canny from povray)
- IP-Adapter conditioning (reference image embeddings from visual memory)
- LCM / turbo variants (fast generation for previews)

model selection via `models.recommend capability:image-generation` —
the models zenka already handles the selection logic.

---

## new generic UI zenki

dropping InvokeAI's UI creates space for purpose-built components
that are generically useful far beyond image generation:

### image viewer zenka

```
purpose:  display images natively — zero browser overhead,
          instant load, SHM-backed pixel buffer
model:    window-place zenka for positioning and sizing
          same drag-to-place, ESC cancel, Enter confirm flow

features:
  p7c image-viewer.show <path>      display image, auto-position via window-place
  p7c image-viewer.show <path> at=<geometry>  direct placement
  p7c image-viewer.slideshow <dir>  tournament review mode — prev/next keys
  p7c image-viewer.tournament       show current tier-1/tier-2 slots side-by-side
  p7c image-viewer.compare <a> <b>  side-by-side comparison (tournament decision)
  p7c image-viewer.close            dismiss

SHM path: /dev/shm/.7/image-viewer/<instance>
  pixel buffer written by zenka, read by GTK3 display loop
  update = write new path to SHM → display loop detects and redraws
  no IPC overhead: display update is a file write to /dev/shm

generically useful for:
  screenshot review, image archive browsing, vision-batch result inspection,
  lm-vision analysis display, graphics-matrix thumbnail grid, data visual output
```

### generation progress widget

```
purpose:  live progress display during image generation — ASCII frame style
display:  ticker-style narrow strip or modal frame overlay
content:  step N/total, preview (if LCM turbo pass), ETA, model, prompt excerpt

ascii frame:
  .:[ {{STEP}}/{{TOTAL}} steps ]::[ generating ]:.
  : prompt: {{PROMPT_EXCERPT}}                    :
  : model:  {{MODEL_NAME}}   eta: {{ETA}}s        :
  :...............................................:

generically useful for:
  any long-running operation (povray render, index retrain, batch analysis)
  same template parameterization as all other ascii frames
```

### queue status widget

```
purpose:  persistent display of image generation queue state
display:  ticker-adjacent strip or dashboard panel

content:  pending / active / completed slots
          per-job: id, prompt excerpt, model, elapsed time, status

generically useful for:
  task zenka queue display, coding zenka job status, batch vision queue
  → becomes the generic task queue visualization component
```

---

## cross-usability gains

these components emerge from image generation but are immediately usable
across the whole system:

```
image viewer zenka    →  screenshot viewer, archive browser, vision output,
                         lm-vision analysis, data visual, graphics-matrix grid

progress widget       →  povray render progress, index retrain progress,
                         embedding retrain progress, any long job

queue status widget   →  task zenka display, coding zenka status,
                         kimi dispatch queue, any async job list

minimal inference     →  whisper (audio-to-text is the same spawn pattern),
server pattern        →  any GPU-bound Python model serving,
                         lm-vision could move to same pattern
```

the window-place zenka is already the template for how this works:
a generic positioning/interaction component that any window-owning zenka
can use by sending a single message. the image viewer zenka follows exactly
the same pattern — generic display primitive, usable from anywhere.

---

## development order — minimal to full

### phase 1 — inference backend (1-2 sessions)
```
bin/image-inference-server.py     minimal diffusers HTTP server
image.init_code                   clone coding.init_code, strip LLM parts
image.spawn_inference_server      clone + adapt for diffusers backend
image.handler.monitor_inference_startup  clone, change /health endpoint path
image.cmd.generate                simple: prompt → queue job → return job_id
image.cmd.status                  job_id → { pending/running/done, path }
image.handler.poll_jobs           clone invoke.handler.poll_jobs, simplify
```
at this point: `p7c image.generate prompt="..." model=sdxl` works.
invoke zenka can be retired immediately.

### phase 2 — task queue + quality (1 session)
```
image.task.*                      clone coding.task.* namespace
image.cmd.generate-batch          N generations → tournament → winner
image-quality.*                   already exists — wire into tournament
image.tournament.*                tier-1/tier-2 slot management
```

### phase 3 — image viewer zenka (1 session)
```
cfg/zenki/image-viewer/ start, access, zenka-startup
modules/image-viewer.*            GTK3 + SHM display loop
  image-viewer.init_code          GTK3 init + window-place request
  image-viewer.cmd.show           receive path, load into SHM buffer
  image-viewer.cmd.slideshow      directory mode, key navigation
  image-viewer.handler.draw       GTK3 draw callback from SHM buffer
```

### phase 4 — strategic embedding layer (builds on FASTTEXT-CATEGORICAL-MEMORY)
```
image.visual-memory.*             categorical reference embedding management
image.conditioning.*              IP-Adapter + ControlNet assembly
image.povray-bridge.*             request depth/normal/edge from povray zenka
image.cmd.embed-reference         add image to visual memory corpus
image.cmd.style-status            per-category embedding status
```

### phase 5 — distributed generation
```
image.cmd.generate dispatches to available GPU nodes via cube routing
results pooled into shared visual memory corpus
povray rendering likewise distributed (already designed for this)
```

---

## what is removed permanently

```
invoke.api.build_graph            → ✗ replaced by direct diffusers API call
invoke.cmd.*                      → ✗ replaced by image.cmd.*
invoke.handler.poll_jobs          → ✗ replaced by async http client pattern
invoke.init_code                  → ✗ retired
invoke-web.cmd.*                  → ✗ retired (spawn handled by image zenka)
invoke-web.handler.*              → ✗ retired
cfg/zenki/invoke/       → ✗ archived
cfg/zenki/invoke-web/   → ✗ archived
```

the InvokeAI process itself may still be available as an optional backend
in phase 1 (image.spawn_inference_server can target either the native script
or InvokeAI's headless API). but no new development effort goes into it.

---

## connection to the current work trail

the window-place zenka showed the pattern: a focused generic positioning
component, built cleanly, immediately useful to every window-owning zenka.
the image viewer zenka is the same pattern for display.

the ticker zenka is the template for the progress widget — a narrow,
always-present strip that carries live state without demanding attention.

the GPU load countermeasures already in the system apply directly:
`image.enable_auto_speed` reduces generation batch size under GPU pressure,
the same way `ticker.enable_auto_speed` reduces scroll rate. the feedback
loop is already understood.

what emerges is not an image generation feature bolted onto the system —
it is the system becoming fluent in a new modality, using the same
architectural vocabulary it already speaks. [:

---

## relation to other design documents

- [[VISUAL-GENERATION-NATIVE-ZENKA]] — the strategic layer this architecture
  serves: visual memory, conditioning assembly, tournament, distributed incentive
- [[VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES]] — the tournament and template
  library that phase 2 implements
- [[EMBEDDING-INFRASTRUCTURE-TRACK]] — phase 4 plugs into the shared
  embedding pipeline at the visual memory category
- [[FASTTEXT-CATEGORICAL-MEMORY]] — the rolling triple-window that makes
  visual style memory stable across sessions

#,,.,,,.,,,..,,.,,,,.,.,.,.,,,,,.,,,.,...,,.,,..,,...,...,,.,,...,.,.,,..,,,.,
#7LVAGFEY3HREAEB3UJ5UA5KR4JK56GJL3BXWDZBD7BQXLFITUO3DVV33A6MPJTLDNYGBNAXEKJKK2
#\\\|ID5DUJVTXFM76JEDSEYVWE3SI5SGMXJ7WQWU6OUV7IYG3GLEKOV \ / AMOS7 \ YOURUM ::
#\[7]YWQHQX6SLEMHFNOLPBGMCGARMPUJG5WDMZ4LR2H4PJOWDKQ4LCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
