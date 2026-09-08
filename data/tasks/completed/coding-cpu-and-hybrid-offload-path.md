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

## status update (2026-09-08) -- scope #3 DONE, fallback shape, live-verified

implemented the "graceful-degradation fallback" shape called out below (try
full GPU first, retry with reduced gpu_layers on the existing VRAM check's
failure branch) rather than proactive pre-calculation -- matches what this
file already flagged as simpler/lower-risk to land first.

new files:
- `models.gguf.file.extract_layer_count` -- reads `<arch>.block_count` from
  the GGUF header [ the layer-count half the per-layer-VRAM estimate needed,
  that this file's "what already exists" section noted was missing ]. while
  building it, found and fixed a real bug shared with the two existing gguf
  parsers (`models.gguf.file.extract_metadata`, `models.parser.gguf_metadata`):
  their array-skip logic multiplies count*fixed-size to seek past an array
  value, which is wrong for GGUF_TYPE_ARRAY-of-STRING [ eg `general.tags`,
  `general.languages` -- variable-length elements ] and corrupts every read
  after it. only fixed in the new file; the two existing ones are masked by
  an early-exit that happens to fire first for their specific field sets --
  not fixed there, flagging in case that assumption ever stops holding.
- `coding.helper.calculate_partial_gpu_layers` -- given model_size_mb,
  free_mb, safety_mb, configured_layers, returns a computed gpu_layers value
  using total-footprint/layer-count as the per-layer estimate, clamped to
  [0, layer_count, configured_layers]. unit-tested live via `devmod.cmd.
  eval-code` against the real running model file, including edge cases
  (below-safety-margin -> 0, way-more-than-needed -> clamped to layer_count).

modified `coding.spawn_inference_server`: the existing vram-check's
"insufficient vram" branch now tries `calculate_partial_gpu_layers` first
[ config-gated via `coding.cfg.partial_offload_enable`, default **on** per
user request, with `coding.cfg.partial_offload_min_layers` (default 4) as
the floor below which it still fails outright rather than attempt a
near-useless offload ] -- both new keys live in `cfg/zenki/coding/zenka.v7`,
zenka-start-file configurable as asked. stores `gpu_layers`/`offload_mode`
(`full`|`partial`) on `<coding.inference_servers>->{$backend}` for
observability.

two real, pre-existing bugs found and fixed along the way, both discovered
because they were silently disabling this exact feature (and the vram
hard-fail check it replaces) during live testing, not found by inspection:
- **this environment's `nvidia-smi` intermittently ignores `--nounits`**
  under GPU-state churn [ reliably reproduced right after killing the prior
  GPU server -- exactly the moment this check matters most ], returning
  `"12288 MiB, 10395 MiB"` instead of `"12288, 10395"`. the CSV-parsing
  regex in both `coding.spawn_inference_server` and `coding.helper.
  calculate_safe_context` required a literal comma immediately after the
  first number, so it silently failed to match and the entire vram check
  (full-fit hard-fail AND the new partial-offload path alike) no-op'd with
  no log trace. fixed both regexes to tolerate trailing unit text. this
  means the pre-existing "insufficient vram" hard-fail may have rarely or
  never actually fired in this environment before today -- worth keeping in
  mind if VRAM-pressure behavior elsewhere looked suspiciously absent.
- added a log line for the case nvidia-smi output still doesn't parse at
  all post-fix, so a future recurrence of this class of issue leaves a
  trace instead of silently defaulting to full offload.
- **found, NOT fixed here (separate concern, real blast radius, own task
  file)**: `POSIX::setpgid($pid, $pid)` in `coding.spawn_inference_server`
  is not taking effect in this environment -- the spawned llama-server's
  real pgid stays the shared session pgid (confirmed live: pgid 713573,
  the whole pts/9 session's zenki fleet, not the child's own pid), so
  `kill('KILL', -$old_pid)` targets a process group that doesn't exist and
  silently kills nothing. the process only actually dies later via the
  unrelated `fuser -n tcp $port` literal-pid kill further down the same
  function, which has no reap/wait afterward -- that's what produces the
  VRAM-read race above (a distinct, additional cause on top of the
  nvidia-smi units bug). see
  `data/tasks/coding-spawn-setpgid-not-taking-effect.md`.

live validation performed (not just unit-level):
1. real spawn forced into the "doesn't fit" branch by temporarily raising
   `coding.cfg.vram_safety_mb` via `devmod.cmd.set` [ a legitimate, real
   VRAM-insufficiency reproduction per this file's own validation bar, not
   a mocked call -- reverted after ], against the real running 5.3GB/32-layer
   model on the real GPU (RTX 3060, 12GB).
2. result: real spawned process with `-ngl 11` in its actual command line
   (`ps` confirmed), `offload_mode=partial` in server metadata, log line
   `full gpu offload does not fit -- hybrid partial offload : layers=32
   model=5368MB (~167.8MB/layer) free=10419MB safety=8500MB -> 11/32 layers
   fit`.
3. the coding zenka's own self-test suite (`coding.helper.
   trigger_backend_self_test`) then ran a real HTTP round-trip against that
   partial-offload server on port 8000 and **passed** (`prompt 1 : PASS
   [ literal ttft=24.26s ]`) -- vs `ttft=5-11s` for the same model at full
   GPU offload moments before/after. slower but genuinely working, exactly
   the task's own bar ("a demonstrated partial-offload spawn that actually
   serves inference successfully, slower than full-GPU but working").
4. also tried the real production path end-to-end via `coding.switch-model
   M7XXVGY:AH6BYCA` (a real 8.9GB model) at *default* settings [ no
   artificial override ] -- it fit fully and did NOT trigger partial
   offload, confirming the feature doesn't over-trigger on a case that
   genuinely fits.
5. restored the zenka to its original model/state afterward; confirmed
   healthy (self-test PASS on the original model post-restore).

known gap, intentionally not addressed now (scope discipline, flagged by
reviewer): `calculate_safe_context`'s context-size auto-calc still assumes
the model's *full* file size occupies VRAM regardless of how many layers
actually got offloaded -- it doesn't know about a partial-offload decision
made moments earlier in the same function. this makes the context ceiling
more conservative than necessary during a partial-offload spawn (safe
direction, not a crash risk in what was tested), but a real co-calculation
[ ctx budget should account for the *actual* VRAM the offloaded layers
occupy, not the whole file ] would let partial-offload spawns use more of
their real headroom. next increment if this needs tightening.

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
- #3: DONE -- see 2026-09-08 status update above. real reproduction of
  "model doesn't fit in free VRAM", a real partial-offload spawn
  (`-ngl 11` confirmed in the live process), and a real self-test PASS
  serving inference through it (slower than full-GPU, genuinely working).

#,,,.,,.,,,,.,,,,,..,,,,.,.,.,.,.,,,.,,,.,,..,..,,...,...,...,...,,.,,,..,.,.,
#2BOHWEQV5DFZGJUJSOYWQ7MZOTEQWMLN6BFZRVXXXZ3JZ6PWVHTJY5SNTTHGSAHFVVSAACODYTJP2
#\\\|2C3C2C2GT43IMWEQDM4MUGAJOU6AYEPJEH4EBR5MXNFAWS5JJPT \ / AMOS7 \ YOURUM ::
#\[7]X2FDKSQSMB5KH5UABLAVNTUDBS2FPFTZF6YNHBBXUYEGKZUFKMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
