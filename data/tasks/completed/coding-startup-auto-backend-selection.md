## [:< ##

# name  = task: auto backend selection + fallback for startup spawn
# descr = prefer gpu at zenka startup, fall back to cpu on insufficient
#         resources or genuine startup failure -- reuse spawn_smart's
#         existing VRAM/RAM check rather than building new logic.

## context

raised 2026-08-27, same session as the self-test parallelization
landing and the backend-aware-timeout-scaling evidence gathering: "a
sort of auto and fallback mode for spawning the correct backend type
... preferring GPU, but if not available choosing CPU spawn if
resources allow that ... perhaps think about fallback behaviour
desirability if either GPU is present but server startup fails, or
perhaps even a second coding zenka is started and GPU [mem] is already
used in full."

full audit of current backend-spawn/selection code done before writing
this file (trust it, don't re-audit from scratch) -- the good news:
most of what's being asked for already exists, just not wired to the
place it's needed.

## what already exists (three separate "auto" concepts, none of them
## covering startup)

1. **spawn-time auto, via `switch-model` only.**
   `src/coding.cmd.switch-model` already accepts `backend=auto` and
   defaults to it (line ~15-16: "Default: auto [ tries gpu, falls back
   to cpu if gpu lacks VRAM ]"). the actual logic is in
   `src/coding.handler.switch_model_reply` (~96-119): tries
   `coding.handler.spawn_smart` with `backend=>'gpu'`, and only if that
   returns FALSE does it log `"gpu unavailable, trying cpu"` and retry
   with `backend=>'cpu'`.

   `coding.handler.spawn_smart` (~line 128 onward) does the actual live
   resource check: `nvidia-smi --query-gpu=memory.free --format=csv,
   noheader,nounits` for GPU, compared against `model_size_mb + 512`;
   `/proc/meminfo`'s `MemAvailable` for CPU, compared against
   `model_size_mb + 1024`. returns FALSE if insufficient either way.

   **this is exactly the "prefer GPU, fall back to CPU if resources
   don't allow" mechanism being asked for -- it's fully built and
   working today, just unreachable from zenka startup.**

2. **routing-time auto, for picking which already-running server
   handles the next request** -- a different problem entirely.
   `src/coding.routing.select_backend` (`descr = Select best available
   backend (GPU preferred, CPU fallback)`) health-checks both backends
   (cached ready-status, else a synchronous 1s `/health` GET) and picks
   GPU if ready, else CPU if ready, else `available => 0`. orthogonal to
   which servers get spawned in the first place -- don't conflate this
   with the startup-spawn decision, it's solving a different question.

3. **restart/reload self-succession ["twin" handover], not concurrent
   multi-instance.** `coding.spawn_inference_server` writes an
   instance-scoped pid file (`state/inference.gpu.<pid>.pid`) so "old
   and new twins never clobber each other" during a reload/redeploy.
   `coding.handler.await_resources` scans sibling pid files for an OLD
   instance of itself mid-shutdown and waits for it to actually free
   the GPU port/VRAM before spawning. `coding.handler.
   inference_server_sigchld` and `coding.handler.
   inference_crash_restart` both skip crash-recovery while "draining
   [ new twin instance owns GPU ]". this is about ONE zenka handing the
   GPU to its own replacement, not about two independently-running
   coding zenki genuinely competing for the same GPU at once -- see
   "second zenka / GPU contention" section below, that case is
   unhandled by this mechanism.

## the actual startup-spawn path today : unconditional, no auto, no fallback

`src/coding.async_spawn_inference_servers` spawns GPU and CPU
**independently**, each gated only by a static boolean from
`coding.init_code:238-239`:

```
$params->{'gpu_enabled'}  = <inference.backend.gpu.enabled> // TRUE;
$params->{'cpu_enabled'}  = <inference.backend.cpu.enabled> // FALSE;
```

live config (`cfg/zenki/coding/zenka.v7:109,118`) currently sets BOTH
to `yes` -- so today both backends always attempt to spawn at boot when
enabled, unconditionally, with zero VRAM/RAM pre-check and zero
cross-backend fallback. each backend's own spawn failure only retries
ITSELF with exponential backoff (`2**retries`, capped 120s, via
`coding.spawn_retry_count_gpu`/`_cpu` +
`coding.handler.spawn_servers_deferred`) -- no code path anywhere
tries the other backend as compensation.

**genuine startup failure (not resource-insufficient, an actual failed
process):** `coding.handler.verify_inference_startup:105-115` -- each
backend tracks its own `restart_count`; at `restart_count >= 5` it
logs `"%s server failed to start after max retries"`, sets
`status = 'failed'`, returns FALSE. that's the end of the line for
that backend specifically. no fallback to the other backend is
triggered anywhere in this handler or its callers.

## scope

1. **resolved 2026-08-27, `auto` as an explicit third value -- not a
   reinterpreted boolean.** the actual requirement (from the user,
   directly): the SAME `cfg/zenki/coding/zenka.v7` must work unmodified
   on a GPU-rich workstation AND on a GPU-poor/absent remote server,
   with zero per-host config editing. that does NOT require silently
   changing what `cpu.enabled = yes`/`no` mean -- it only requires that
   the ONE value COMMITTED to that file work everywhere, and this repo
   already has the right precedent for exactly this shape:
   `coding.cmd.switch-model` accepts `backend=gpu|cpu|both|auto` as
   four explicit, independent values, `auto` meaning "try gpu, fall
   back to cpu live" (see item list above). `inference.backend.
   gpu.enabled` / `.cpu.enabled` should follow the same pattern:
   `yes` / `no` keep their EXACT current unconditional meaning
   (`yes` = always spawn this backend at boot regardless of fit,
   `no` = never spawn it) -- unchanged, so any existing deployment that
   deliberately set `cpu.enabled = yes` for a reason other than
   "fallback only" (e.g. deliberately running both backends
   concurrently for throughput) keeps working exactly as it does
   today, no silent behavior change. `auto` is the new third value,
   meaning "spawn this backend only if the live per-host resource
   check (item 2) says it's needed as a fallback." the "same file
   everywhere" goal is met by shipping the committed default in
   `cfg/zenki/coding/zenka.v7` as `cpu.enabled = auto` (instead of
   today's `yes`) rather than by overloading what `yes` means --
   self-documenting in the config file itself, and a GPU-rich host's
   live check naturally never triggers the cpu fallback while a
   GPU-poor/absent host's does, from that identical committed value.
   `gpu.enabled` most likely only needs `yes`/`no` in practice (gpu is
   always attempted first when enabled, "auto" doesn't add meaning on
   the preferred backend) -- keep it a plain boolean unless a real use
   case for `gpu.enabled = auto` turns up during implementation.
2. wire `coding.async_spawn_inference_servers`'s gpu path to call
   **`coding.helper.check_resource_fit`** (landed 2026-08-27, already
   in the tree -- the VRAM/RAM check this item originally asked to
   extract FROM `spawn_smart` now already exists as a shared helper,
   used by `spawn_smart` itself and by `coding.model_sweep.cmd.
   model-sweep`'s pre-filter; this item is now "call the existing
   helper," not "extract new shared logic") before committing to a GPU
   spawn attempt; on a fit failure, spawn CPU instead IF
   `cpu.enabled` is `auto` or `yes` (both mean "cpu may spawn," only
   `no` blocks it) rather than the current behavior of just deferring
   gpu and retrying gpu again later.
3. **resolved 2026-08-27** -- yes, exhausting `verify_inference_
   startup`'s 5-retry ceiling on GPU (genuine startup failure, not the
   resource pre-check) ALSO triggers a CPU fallback spawn, same
   `auto`-or-`yes` gate as item 2. rationale directly from the user's
   stated goal: a host with a technically-present-but-broken GPU
   driver must still produce a WORKING coding zenka via CPU, not
   silently fail to start any usable backend at all -- "without it
   doing impractical things" only holds if both failure classes
   (resource-insufficient AND genuine-startup-failure) fall back, not
   just one.
4. **second zenka / GPU-memory-contention case: flagged by the user as
   "less likely... as we are implementing parallel processing" --
   correctly so, this is the lowest-priority part of this task. no
   existing mechanism handles two independently-running coding zenki
   competing for the same GPU (the twin-handover pattern above is
   restart continuity, not this). if pursued at all, `spawn_smart`'s
   live VRAM check would at least make a second instance's GPU spawn
   attempt fail cleanly and fall back to CPU -- IF that second
   instance's startup path also goes through the auto/spawn_smart
   route from item 2. don't build anything dedicated to this case
   beyond what items 1-3 already provide for free.

## do NOT touch / do NOT conflate

- `coding.routing.select_backend` -- solves a different problem
  (routing an in-flight request), do not merge its logic with the
  startup-spawn decision.
- the twin-handover pid-file mechanism
  (`coding.handler.await_resources`, the sigchld/crash-restart drain
  guards) -- restart continuity for ONE zenka's own replacement, orthogonal
  to this task.

## related stale premise, flagged not fixed

`data/tasks/coding-cpu-and-hybrid-offload-path.md` opens with "the
current async startup-spawn path only ever spawns the GPU inference
server; CPU-only spawning is an explicit unimplemented placeholder" --
that premise is now WRONG, `coding.async_spawn_inference_servers` has
had a full symmetric CPU spawn block since the CPU-spawn-crash-loop fix
(`24f45740f`). that file's hybrid/partial-GPU-offload (`-ngl`) content
is unrelated and still current -- only its opening framing is stale.
worth a small correction pass on that file separately, not part of
this task.

not urgent -- both backends spawning unconditionally today works fine
on a machine with both a working GPU and enough CPU RAM, which is the
only environment this has been used in so far; this matters once a
CPU-only or resource-constrained deployment is actually being set up.

#,,,.,...,,.,,.,.,,,,,,..,.,.,..,,.,,,,..,,..,..,,...,...,...,.,,,,..,,.,,.,.,
#FSN36RZEE4MQGGHABD4NANNY4JDYOLDDY5FP54WHZ7WSRSQSSSITJ5KHZ5A2762GVDQGSIU76TPYA
#\\\|NQY4CINSTZDJBCJQ32ZBCCXGVHZW5HOUA2AL6AMD27L62HGLZ7X \ / AMOS7 \ YOURUM ::
#\[7]42D6A34WPSZUTBIYT7E73P4G4RS265R667NG6RKAGIMGIGPDFSBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
