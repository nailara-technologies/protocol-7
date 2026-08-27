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

1. decide the config shape for opting a backend list into "auto"
   preference at startup -- likely a new value for
   `inference.backend.gpu.enabled`/`.cpu.enabled` (or a sibling key)
   rather than the current plain boolean, since "auto" needs to mean
   "try gpu first, cpu is the fallback slot" rather than "spawn both
   unconditionally."
2. wire `coding.async_spawn_inference_servers`'s gpu path to call
   `coding.handler.spawn_smart`'s existing VRAM check (or factor the
   check out for reuse -- it already lives in `spawn_smart`, don't
   duplicate the `nvidia-smi`/`/proc/meminfo` logic a second time)
   before committing to a GPU spawn attempt.
3. decide: does exhausting `verify_inference_startup`'s 5-retry ceiling
   on GPU (genuine startup failure, distinct from the resource
   pre-check) trigger a CPU fallback spawn, or only the pre-check does?
   the user explicitly separated these two cases ("resources don't
   allow" vs. "server startup fails") -- they likely want both to
   fall back, but this needs its own decision since retry-exhaustion
   fallback is a new code path, not reuse of `spawn_smart`.
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

#,,.,,..,,.,.,,,.,.,,,,..,,..,.,,,,,.,,.,,.,.,..,,...,...,,.,,...,.,,,,,,,.,.,
#B5J5J27UWCPQ7IHKWKTML7XJ24UQRWVOXAOJUMGLPEEDPIXUH73UYGE4ZJD566FE4RHG3WCS53LXO
#\\\|CHGZX5GA5F3HQ4DMH5TYCM7EMAQZPZQL6ICFWG4645MSK2MVUVS \ / AMOS7 \ YOURUM ::
#\[7]BSNYQIH3OS5J3JJTWGWO5HCV3M7E3OSOB3X7HKEMIP7OB6QXDCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
