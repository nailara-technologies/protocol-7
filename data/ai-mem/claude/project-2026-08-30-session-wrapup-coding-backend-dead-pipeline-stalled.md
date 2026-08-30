---
name: 2026-08-30-session-wrapup-coding-backend-dead-pipeline-stalled
description: RESOLVED 2026-08-30 — jobsite/coding assessment pipeline was fully stalled (dead GPU backend + a real CPU-fallback bug in coding.async_spawn_inference_servers); the CPU-fallback bug is fixed and live-verified (self-test passing on CPU backend), pipeline unblocked. GPU orphaning root cause + v7/orphan_pids gaps remain open, separately, not blocking anymore
metadata:
  type: project
---

## RESOLVED — CPU fallback bug fixed and live-verified

root cause of "coding does nothing, claims success, spawns nothing" found via
git-history audit (user's idea: `git log --follow` on the spawn/teardown
files) of `coding.async_spawn_inference_servers` (commit `7a26b4386`,
2026-08-27 "auto backend selection"): `$cpu_fallback_requested` is captured
as a **local** snapshot of `<coding.cpu_fallback_requested>` at function
entry, then the global gets reset to `FALSE` immediately. When the GPU
resource-fit check fails *within that same call*, it sets the **global**
`<coding.cpu_fallback_requested> = TRUE` — but the CPU block's own spawn
condition (`$spawn_cpu = ... and $cpu_fallback_requested`) reads the stale
**local**, which still holds the pre-call value. So on the exact call where
GPU fails and triggers fallback, the CPU block is silently skipped
entirely — no fit-check, no spawn attempt, no logging from within it — and
`$spawn_ok` (initialized `TRUE`, never touched by this specific branch)
makes the function log "inference server spawning complete" despite
`coding.inference_servers` staying completely empty. This is why CPU
fallback "never worked since the refactor, even though it should have still
processed something, just slower."

**fix** (committed to working tree, not yet git-committed): `$spawn_cpu`'s
condition now ORs the local (a fallback request carried in from a *prior*
call, e.g. `verify_inference_startup`'s retry-exhaustion trigger) with the
live global (set fresh *within this same call* by the GPU block) —
`$cpu_fallback_requested or <coding.cpu_fallback_requested>`. Live-verified:
CPU server spawned (pid 146190, port 8001), self-test prompt 1 passed
(ttft=38.96s), prompt 2 in progress with its stall-timeout correctly
extending (127s ceiling → 904s, stream alive with chunks arriving) rather
than being killed — the pipeline is genuinely unblocked, not just
appearing to work.

**also fixed same session, smaller/related**: `base.callback.report_children`
(the `v7.register_child` sender) was fire-and-forget with zero visibility on
failure — added a reply handler (`base.callback.report_children_reply`,
new file) that logs at level 0 on a `FALSE` reply. Doesn't fix the
orphaning race itself, just makes any future failure-to-register visible
instead of silent.

**still open, NOT blocking anymore, lower priority**:
- why the original GPU backend (PID 4147, self-tested "functional" Aug 29
  02:56:58, per persisted `coding.model_status`) later got orphaned
  (reparented to init) — root cause not found, deliberately not chased via
  a destructive live-process core dump per user's call (see below). user
  has since restarted the backend.
- `v7.sub-process.orphan_pids`'s `$ARG->pgrp == $GID` check compares a
  process-group id against `$GID` (real Unix group id via `English.pm`,
  same convention as `$EGID` in `v7.zenka.start`'s privilege-drop code) —
  wrong quantity entirely, AND even fixed to compare v7's true pgid, would
  never catch any descendant deliberately `setpgid`'d into its own process
  group (confirmed `coding.spawn_inference_server:488` does exactly this,
  same pattern used this session in `site-yaml.async_fetch.spawn`/
  `povray.spawn_render`). top-level zenka processes (`coding`, `jobsite`,
  etc.) don't need a separate fix for this — confirmed `v7.zenka.start` has
  no `setpgid` calls, so they still inherit v7's own process group by
  default; only setpgid-isolated grandchildren (inference-server-style
  workers) are structurally invisible to this check.
- the fork→registration async round-trip (`base.callback.report_children`
  → cube → `v7.zenka.cmd.register_child`) has a real, if small, timing
  window where a child process exists but isn't yet known to v7 —
  registration send is genuinely fire-and-forget (now at least logs
  failure, see above, but still no retry).
- user has ideas for a richer per-worker registration scheme (beyond just a
  bare pid) to make cleanup on both `coding`-zenka-restart and
  `v7`-zenka-restart fully reliable — deliberately deferred, "can be
  postponed until the already obvious things are addressed."
- `v7.zenka.instance.restart` (single-zenka `v7.restart <name>`) and full
  `v7.teardown` were both read in full this session and confirmed to
  correctly TERM+KILL-escalate registered children when given a live
  target (user had this right, my initial claim otherwise was wrong and
  retracted) — NOT the source of any remaining gap on their own.

## state at session end, 2026-08-30 [ pre-fix, kept for the historical trail ]

**jobsite assessment pipeline: fully stalled, root cause identified, NOT fixed
— left as-is deliberately.**

`llama-server` GPU backend (PID 4147, port 8000, started Aug 29 02:52 —
running 22h51m at time of diagnosis) is alive at the OS/GPU level
(`nvidia-smi` shows it GPU-resident, all 6 threads state `S`) but its
listener is dead: `curl http://127.0.0.1:8000/health` → connection refused,
`ss -ltnp` shows nothing bound on port 8000 or 8001 at all.
`coding.inference-status` confirms coding itself has no working backend
registered (`pid: 0, status: unknown` for both gpu/cpu slots).

Every job `jobsite` dispatches goes through `jobqueue`'s generic dependency
gate (`base.dependency.ok`) before it can leave `queued`/`depending` — with
no live backend, this fails for every job, permanently. Matches all
observed symptoms exactly: `jobsite.pending_count` stuck at 16 while
`task.queue status=pending` shows nothing actually in flight, log
repeating `moved job '<id>' into 'depending' queue` forever, nothing
reaching trash or apply, `jss.assess-timeout` firing at 777s (jobsite's own
watchdog correctly giving up on dispatches that were never going anywhere).

**Diagnostic ceiling hit without root**: could not read `/proc/4147/fd/`
(permission denied — different uid, no sudo in a non-interactive shell) to
confirm whether a listen-socket fd still exists on the process; could not
get real kernel thread stacks. Suggested `sudo gcore`/`sudo gdb -p 4147`
live-backtrace/`journalctl -k` for GPU Xid/OOM history — user correctly
pushed back that a core dump of the llama-server binary (likely
symbol-stripped release build) is a static memory snapshot, not causal
diagnostics of *why* the listener died, and isn't worth chasing today.

**User's explicit decision**: do NOT restart/kill the dead backend process
yet (would destroy the only forensic evidence of *why* it died — "if i
restart it and it works, the entire coding zenka must be marked as
unreliable from here on"). Then: stop investigating further today, accept
the base system in a degraded state, halt all feature work for the
remainder of the session. This is a deliberate, informed choice, not an
unresolved blocker to pick back up reflexively — respect it next session
too unless the user brings it up.

**How to apply, next session**: before assuming the coding/jobsite pipeline
is healthy, check `coding.inference-status` for `pid: 0` and re-verify
`curl -m5 http://127.0.0.1:8000/health` (with `no_proxy=localhost,127.0.0.1`
— the shell's own proxy otherwise intercepts localhost). If still dead and
the user hasn't said otherwise, this is the same still-open incident, not a
new one — don't re-diagnose from zero. If the user wants to actually chase
the root cause (why does a `llama-server` process go listener-dead while
staying GPU-resident, twice now per [[topic-coding-zenka-wedged-backend-queue-gridlock-2026-08-05]]),
better tools than a stripped-binary core dump: build/run a debug build with
symbols, or check if `ik_llama.cpp`'s own upstream has known reports of
this exact failure mode, before reaching for gdb again.

## unrelated work landed cleanly this session, unaffected by the above

- `site-yaml` async job-detail fetch (`data/tasks/site-yaml-async-fetch.md`)
  and async search-page import (`data/tasks/site-yaml-async-import.md`) —
  both landed, fork-per-request worker pattern mirroring `povray`, live
  log-confirmed non-blocking (`SIGCHLD`/reap cycle observed, `site-yaml.
  import` replies without hanging `heart`).
- fork-per-request flagged as a real OOM risk on 1GB-RAM hosts (atom) — see
  [[site-yaml-async-fetch-fork-memory-risk]] for the full redesign note.
  Current best target: extend `clients.https.request` (already has a
  correct non-blocking TLS handshake via `IO::Socket::SSL`
  `start_SSL`/`connect_SSL` pumped through `event.add_io`) with HTTP
  `CONNECT`-through-proxy support, eliminating forking/exec'ing entirely.
  Not started — scoped only.
- an earlier proxy-env-var theory for a *different*, since-superseded
  version of "site-yaml can't reach the internet" was chased and found
  wrong (my `/proc/<pid>/environ` check via non-interactive `sudo` likely
  failed silently rather than proving an empty environment) — retracted
  mid-session, not left in any task file or dispatch prompt in its wrong
  form.

#,,..,,,.,.,,,,..,.,,,,,.,,..,.,.,,,.,..,,..,,.,.,...,...,.,.,..,,,,.,,..,,,,,
#3N3VQFSMH7COOLUCYBRVZB6SA46I32P7ZYDTWD4W2LBMDLLNX6TGKJ3UVC5LDKGEMO5BBF4KKHNWW
#\\\|HVMZXIYBKN54XIROS4KNE4BQPIFK6QYYC3UER5M2OV4IHAGDHSI \ / AMOS7 \ YOURUM ::
#\[7]KQM4AH3YCLS63LFVHPKIFPMJAX5YAEF5W5ZFJNOGKMXOMYX52SBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
