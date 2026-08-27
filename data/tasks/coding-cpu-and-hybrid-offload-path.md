## [:< ##

# name  = task: coding zenka CPU-only spawn path + hybrid/partial GPU offload
# descr = CPU-only startup spawn landed 2026-08-26/27 (see status note) --
#         what remains open is hybrid/partial GPU+CPU layer-offload [ what
#         lm-studio calls "hybrid" / partial offload ], which this
#         codebase still has no automatic detection or calculation for,
#         even though the underlying binary flag for it is already
#         wired and used unconditionally today.

## status update (2026-08-27) -- scope #1 and #2 below are DONE, don't re-investigate

when this file was written (2026-08-26), `coding.async_spawn_inference_servers`
had a literal placeholder comment where the CPU spawn block should be:
`# Note: CPU server spawning can be added here if needed for fallback` /
`# For now, focus on GPU server`. that's no longer true -- CPU startup
spawn was implemented the same/next day (commit `24f45740f`, "coding: fix
CPU inference spawn crash-loop and dead dependency wiring"): the function
now has a full symmetric CPU spawn block (model path resolution,
dependency gating via its own `spawn_ready_cpu`/`model_path_cpu` pair,
spawn call, retry/backoff) -- confirmed by direct read 2026-08-27, not
assumed.

scope #1's open question ("is spawn_smart's CPU path genuinely real, not
just plausible-looking config plumbing?") is also answered, with the
strongest possible evidence -- a live run, same session: parallel
gpu+cpu self-test (`coding-self-test-true-parallelization` task, landed
and live-verified 2026-08-27) produced a real CPU backend process
(`[spawn_inference_server] spawned: backend=cpu pid=985077 port=8001`),
which then genuinely served a self-test round over HTTP (real port
8001, real streamed tokens, real ttft numbers, eventually a real 1700s
watchdog abort on one contention-heavy round -- see
`coding-backend-aware-timeout-scaling.md`'s live evidence). this is
exactly the validation bar scope #2 set below ("a live cpu-only startup
verified end to end (real process, real port, real self-test pass)") --
met.

what's genuinely still open, unaffected by any of this: scope #3, hybrid
/ partial GPU+CPU offload. nothing done since this file was written
touches that at all.

## context (original, 2026-08-26 -- CPU-spawn parts below are now historical)

found 2026-08-26 while fixing the model-path-resolution race in
`coding.async_spawn_inference_servers` (see commit history same day,
"coding: consolidate model-path readiness onto the dependency system").
that function's GPU spawn block was real and working; CPU spawning was
not yet implemented at the time -- see status update above for what
changed since.

## what already exists (verified, not assumed)

- `inference.backend.cpu.binary` / `.model_id` / `.threads` / `.port` are
  real config keys, already read in several places (`coding.init_code`,
  `coding.handler.spawn_path_reply`, `coding.handler.spawn_smart`,
  `coding.handler.spawn_with_deps`, `coding.inference.spawn-server`).
- `coding.handler.spawn_smart` is NOT dead code -- it's actively called
  from `coding.handler.switch_model_reply` for "memory-aware server
  restart" during a live model switch. whether ITS cpu path is genuinely
  exercised/working in practice is unverified -- next step, not assumed.
- `coding.spawn_inference_server` (the actual process-spawning function,
  shared by both the startup and switch paths) already passes
  `-ngl <gpu_layers>` unconditionally when backend=gpu (line ~388). llama.cpp's
  `-ngl` flag natively supports any value from 0 [ pure CPU ] up to the
  model's full layer count [ full GPU ] -- **partial values are hybrid
  offload, and the binary already supports it**. today `gpu_layers`
  defaults to a hardcoded 33 (or config override) and nothing in this
  codebase ever computes anything other than "the configured/default
  value" -- there is no automatic partial-offload fallback.
- the existing VRAM-awareness in `coding.spawn_inference_server` [ the
  "vram: free=... model=... safety=..." / "calc / clamped" log lines seen
  live ] is about **context-window size** clamping, NOT layer-offload
  clamping -- confirmed by reading the surrounding code, not assumed from
  the log line alone. it does not reduce `gpu_layers` when VRAM is tight;
  it only shrinks the context window.

## scope

### 1. investigate before building: is spawn_smart's CPU path real? -- DONE, see status update

resolved 2026-08-27: yes, confirmed live via the parallel self-test run
cited above, not just plausible-looking config plumbing.

### 2. CPU-only startup spawn -- DONE, see status update

landed via commit `24f45740f`, confirmed live 2026-08-27. no longer open
work.

### 3. hybrid / partial offload -- bigger, separate investigation, still fully open

lm-studio can run a model split across GPU+CPU when VRAM alone isn't
enough for the full model -- slower than full GPU, but it degrades
gracefully instead of failing outright or needing pure-CPU fallback. this
codebase currently has neither the automatic detection nor the calculation
for that middle ground: it's full-GPU-offload (`gpu_layers` at its
configured/default value) or nothing on the GPU side.

a real implementation needs, at minimum:
- a way to estimate per-layer VRAM cost for a given model [ total model
  VRAM footprint / layer count is a reasonable first approximation, the
  existing VRAM-detection code in `coding.spawn_inference_server` already
  has the total-footprint half of this ]
- a calculation that, given free VRAM and the safety margin already used
  for context-size clamping, picks a `gpu_layers` value LOWER than "all
  layers" when the full model doesn't fit, instead of the current
  behavior [ whatever that actually is today under VRAM pressure --
  verify live rather than assume: does spawn currently fail, or silently
  run with insufficient VRAM and let llama.cpp itself reject/OOM? ]
- decide whether partial-offload is a graceful-degradation fallback
  [ try full GPU first, retry with reduced gpu_layers on a VRAM-related
  spawn failure ] or a proactive pre-calculation [ compute the safe
  gpu_layers value before ever attempting to spawn ]. the fallback shape
  is simpler and lower-risk to add first; proactive calculation is more
  elegant but needs a reliable per-layer VRAM estimate to not just guess.

not urgent -- this is a capability gap, not a live bug like the
model-path race that prompted noticing it. worth scoping properly rather
than rushing given it touches the same spawn path multiple other fixes
landed in today.

recompiling `ik_llama.cpp` is NOT off the table if investigation shows
the current binary/build lacks something needed here [ eg a build-time
flag relevant to how partial offload or CPU-only inference performs --
don't assume the existing binary is the ceiling ]. per user: build
scripts can be adjusted freely, that's a low-friction option, not a
blocker to route around.

## future: generalized multi-slot / multi-model support

raised 2026-08-26 while scoping this task, deliberately NOT in scope
here -- capturing the direction so the reasoning isn't lost.

once CPU-only startup lands (this task), running GPU and CPU
concurrently should fall out close to free: `coding.state.backend`
(`coding.async.backend_acquire`/`.backend_release`) and
`coding.inference_servers` are ALREADY keyed per-backend with
independent locks/queues/status, and `coding.handler.spawn_smart`
already checks each backend's own readiness independently rather than
assuming only one backend is ever active. the only reason GPU+CPU don't
already run in parallel today is that the startup path never calls the
CPU spawn at all -- not a deeper architectural gap.

**confirmed correct, 2026-08-27**: CPU-only startup landed (see status
update above), and genuine GPU+CPU concurrent self-testing then landed
right behind it (`coding-self-test-true-parallelization`), live-verified
the same day -- exactly the "falls out close to free" prediction made
here, not a coincidence. the per-backend-keyed state pattern called out
above is the same substrate that task's per-backend guard hash and
per-backend watchers used.

genuine multi-MODEL support [ eg two different GPU models loaded at
once, or more slots than just the two hardcoded `gpu`/`cpu` backend
names ] is real, separate future work, but has a real head start: the
model-lookup-by-name logic already in `coding.handler.spawn_smart`
[ normalize + match against `coding.model_metadata` by `amos`/
`model_id`/exact/partial name ] is already fully backend-agnostic -- it
resolves "the model configured for this slot" generically, it doesn't
hardcode gpu/cpu semantics. generalizing from two fixed slot names to N
dynamic slots mainly needs: a slot-key abstraction [ replace the
literal `gpu`/`cpu` strings threaded through `coding.state.backend` /
`coding.inference_servers` with arbitrary slot ids ], and admission
logic [ does a requested model fit in remaining free VRAM/RAM before
it's allowed to claim a new slot -- this overlaps directly with the
per-layer VRAM estimate needed for hybrid/partial offload above ]. the
"find and spawn the right model for a slot" mechanics would not need
to be reinvented.

separately considered and set aside for now: this could instead be
built as multiple `coding` zenka INSTANCES [ v7's existing per-instance
isolation, already exercised heavily today via the dependency/resolve-
hook work ] with a coordination/routing layer on top, rather than
multiple backend slots inside one zenka. both approaches converge on
similar new work [ routing, concurrent-slot tracking, admission control
], so pick based on architectural fit when this is actually scoped, not
raw effort estimate.

## validation

- #1: DONE -- live-verified 2026-08-27, see status update above.
- #2: DONE -- standalone coverage exists via
  `bin/test-scripts/test-coding-cpu-spawn-path.pl` and the other
  same-cluster test scripts from the CPU-spawn-crash-loop fix; live
  cpu-only startup verified end to end 2026-08-27 (real process, real
  port, real self-test pass) -- see status update above.
- #3: at minimum, a real reproduction of "model doesn't fit in free VRAM"
  and a demonstrated partial-offload spawn that actually serves inference
  successfully, slower than full-GPU but working -- not just a
  calculation that looks plausible on paper.

#,,..,,,.,...,..,,,..,..,,,..,...,,,,,.,,,...,..,,...,...,.,,,,,.,,..,,,.,,,.,
#YZGYAGHBOLULEGPOIXT5K6BHXQ4SR5ZPAWGC53JHDAEFH25CIW5JCQ7DIHYDUACFUVHI3O6YUVRNC
#\\\|S3B4KX4LPMC5P7BCVBXUJ6RXFPZSPKUT7YFYPO7DPAB4FYKNUE2 \ / AMOS7 \ YOURUM ::
#\[7]R6Y32R6SBNBFZZMUEUHKZZJOMWP3XCN2MGDD3CASFT5IZICZFWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
