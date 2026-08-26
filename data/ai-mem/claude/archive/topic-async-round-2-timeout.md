---
name: Async Timeout + Subtask Spawn — RESOLVED
description: llama-server silent hang + subtask deadlock root causes found and fixed (Apr 2026)
type: project
originSessionId: f73dfdbb-4f5e-44b2-ab06-4e1807bec037
---
## status: RESOLVED (2026-04-30)

### primary root cause: context size too small

The original round-2+ timeouts were caused by `n_ctx` being too small. At 7777 tokens,
`ctx_est + max_tokens` exceeded capacity at round 2 (larger history), causing llama-server
to silently hang rather than error. Some round-0 calls worked by chance (smaller context).
Raising to 13500+ resolved the majority of timeouts. Safe minimum appears to be ~13500;
values below that are unreliable under multi-round tool use.

The `calculate_safe_context` module was refined to auto-calculate from VRAM. Config now
has `inference.model.context_length = 13500` and `inference.model.max_tokens = 13500` as
the hardcoded safe floor. Future refinement: handle low-VRAM states more gracefully
(e.g. queue tasks rather than failing when context must be reduced significantly).

### secondary root cause: double-spawn stealing VRAM

Two llama-server processes spawned with the same seed when `model_path_reply` and the
deferred timer both called `async_spawn_inference_servers` in the same event loop tick.
The second process failed to bind port 8000 but held ~250MB VRAM, reducing the first
server's available KV cache. The first server accepted TCP connections but silently
failed to allocate KV cache → tiny GPU spike → no response → 780s timeout.

**Fix**: `coding.async_spawn_inference_servers` now has a `<coding.spawning_in_progress>`
guard (set before spawn, cleared on all exit paths) that blocks any concurrent call.

### secondary fix: stale-process kill race

`fuser` killed stale pid, `waitpid` was a no-op (non-child), then `pgrep` immediately
found the same pid as "foreign process" and blocked the spawn.

**Fix**: `coding.spawn_inference_server` tracks `@killed_stale_pids` from the fuser scan
and skips those PIDs in the foreign-process check.

### secondary fix: subtask backend lock deadlock

Parent task held backend lock while transitioning to `subtask` state. Child task ran
immediately via jobqueue, hit `coding.routing.select_backend` which did a blocking LWP
`/health` request — during which the server was still busy streaming the parent's
response, so health check could fail.

**Fix A**: `coding.tools.handler.subtask_spawn` releases the parent backend lock after
setting `pending_subtask`. Child acquires the lock when it runs.

**Fix B**: `coding.routing.select_backend` uses `<coding.inference_servers>->{backend}{status}`
(set to `'ready'` by startup monitor) as a fast path, skipping the blocking LWP call.

**Fix C**: `coding.callback.http_complete` has an explicit `subtask` case that returns
cleanly (lock already released by subtask_spawn).

### timeout recovery fix

When all retries fail on a timeout error and server status was `'ready'`, the server is in
a silent-hang state. `coding.callback.http_error` now marks it `restart_needed`, clears
`<inference.gpu_pid>`, and schedules `spawn_servers_deferred` at +0.5s.

### verified working

Full subtask round-trip tested via `coding.submit` → `coding.wait-done`:
- Parent spawned child `task-ARIN7QY` (about number 42)
- Child completed, result injected into parent context
- Parent resumed, reported child result correctly

#,,..,...,...,,,.,,,.,..,,..,,.,.,,,,,,,,,..,,..,,...,...,.,,,..,,...,...,,..,
#CVS4LZNDHXSFB7LGOAGLM6FFTID2VJTUI7CAATQURIUXYQMFGEXJCU54MEFKKTVO2OO63W4UUGCXA
#\\\|NRBNJWIG7DKFSLKEXJR2SKVZTJ7LYBRAVNOMCISAICBYE4Q7X6P \ / AMOS7 \ YOURUM ::
#\[7]36DTYPNQI3F7RMHYZG2RCIT2S4LWMWVZR2THAF35JTU2JUWVUIDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
