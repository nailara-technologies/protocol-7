---
name: Coding Zenka Session 7 — Stability Fixes
description: Spawning guard, drain pipe lifecycle, context floor semantics, task-append, loop detection
type: project
originSessionId: f73dfdbb-4f5e-44b2-ab06-4e1807bec037
---
## status: completed 2026-05-01

Details in `topic-completed.md` session 7. Key architectural points:

### context_length is a floor, not a fixed value
`inference.model.context_length` = minimum desired context. Server uses `max(auto_calc, floor)`.
Small models auto-expand (7B Q4 → 77777), large models use floor (9B Q8 → 17777).
All three context-sensitive modules now use actual `n_ctx` from `inference_servers->{'n_ctx'}`:
- `send_request` (overflow check, max_tokens cap, CTX% display)
- `compact_context` (53% threshold)
- `spawn_inference_server` (context sizing)

### spawn guard is in spawn_inference_server, not async_spawn_inference_servers
The `spawning_in_progress` flag lives in `spawn_inference_server` (central) so all callers
are protected: `restart_server`, `inference_crash_restart`, `model_path_reply`, deferred timer.

### drain pipe lifecycle
After startup monitor cancels: drain watchers replace startup watchers, stored in
`inference_servers->{backend}{watcher_drain_stdout/stderr}`. On next spawn, these are
cancelled before the old FDs close (prevents sysread-on-closed-FD warning).

### task-append resumes with full tool set
`async.complete` saves `messages` + `tools` to task record. `task-append` restores both.
If tools not saved (pre-fix tasks), re-assembles from `coding.tools.definitions`.

### loop assertion interception
`loop_assertion_pending` flag in state. When set, `finish_stop` → intercepted:
- processes model's answer through detect_loop assertion phase
- injects "please continue" user message
- re-enqueues round instead of completing task

### Additional fixes (same session, continued)

**Model switch / spawn lifecycle:**
- `spawn_inference_server`: remove watcher_pair entries BEFORE cancelling — prevents queued "ready" event from old server setting drain watchers on reused fd numbers (was causing tasks to stay queued after switch-model)
- `monitor_inference_startup`: liveness check `kill(0, pid)` before declaring EOF crash; reset dep object `failed` flag when server becomes ready (model switch killed mid-startup could permanently block jobqueue)
- `inference_server_sigchld`: `POSIX::waitpid` reaps any child PID to prevent zombies

**Loop detection / tool use:**
- `detect_loop`: parse JSON args string to build tool key — pagination calls (`read_file offset=1` vs `offset=101`) now produce distinct history keys, no false `stuck_retry`
- Loop warning injected as `user` role (was `system` — broke Gemma's strict alternation → 500 errors)
- Loop assertion interception: `loop_assertion_pending` flag prevents model's assertion answer from completing the task; injects "please continue" and re-enqueues

**Context sizing:**
- `calculate_safe_context`: `coding.cfg.context_max` configurable (0=uncapped, default 131072); context ceiling no longer hardcoded 77777
- `read_file` tool: budget defaults to 32000 chars when n_ctx > 30000 (was 8000 — caused pagination loops on large-context models)
- `model_output` buffer: always written even with no reasoning text

**apply-staged mkdir:**
- `start.chmod_child`: added `mkdir` command — creates dir + parents as admin user (0775, correct group)
- `apply-staged`: routes missing parent directory creation through chmod child, not direct `file.make_path`

**models zenka:**
- `discover_files`: two `@ARG`/implicit-call bugs fixed — scan and populate were silent no-ops
- `adapter.invoke.discover`: uses `system.admin-user` for InvokeAI DB path (was falling back to protocol-7 home)
- Model `Huihui Qwen3.5 4B Claude 4.6 Opus Abliterated` Q8_0 added — vision capable, ~156K context, good for large refactoring and CPU remote servers

**llama-server process group + child worker:**
- `setpgid($pid, $pid)` after fork makes server its own process group leader
- Group kill `kill('KILL', -$pid)` in cleanup kills parent + all forked workers
- `coding.end_code`: kills process groups on zenka shutdown (v7 only kills registered parent)
- `register_server_children`: exponential-backoff poll 0.7s × 1.6, cap 47s — registers worker with v7 after first request
- Foreign process check now skips child PIDs (reads `/proc/PID/status` for PPid)
- Root cause of "double server same seed": KV overflow → llama-server forks worker child → child inherits cmdline including --seed → looks like double spawn; foreign process check was then blocking future spawns

**Context size calibration (4B Huihui Qwen3.5 Q8_0 on RTX 3060 12GB):**
- 110007 tokens: works reliably
- 130007 tokens: fails (KV allocation silent failure → worker fork → hanging)
- 128K (131072): not tested after group-kill fix — worth retrying after ik_llama.cpp update
- Empirical: only 43MB VRAM free during active inference at 110K context
- `cuda_overhead_mb = 1256` in calculate_safe_context is too low; actual ~3000-3500MB
  (accounts for CUDA context, FlashAttention workspace, mmproj activation buffers, WSL2 overhead)
- `context_max = 110007` in start file currently; update after ik_llama rebuild

**kimi.handler.ws_message:** 4B model attempted bugfix for auto-approval regression;
duplicate code cleaned up; actual fix (flush_on_acquisition) still needs implementation — marked `[LLL]`

**Next: rebuild ik_llama.cpp**
Build scripts: `bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh`
Build docs: `data/md/documentation/LLAMA-SERVER-BUILD-FLASHATTN.md`
Previous build instructions: `data/yaml/build-instructions/ik_llama.cpp-cuda-debian-wsl2.yaml`

### open items
- `loop_detect_count` is zenka-global, not per-task — a model switching between tools
  can reset the counter; should move into `$state->{'loop_detect_count'}`
- Large file operations (>10KB) still hit context limits on 9B model (17777 n_ctx);
  context pressure warning (< 3000 tokens) helps model adapt strategy but not a full fix
- `coding.task.fail` has a P7 data-path bug at line 19 (`<coding.task.failed.queue>`);
  `async.complete` inlines the fail path instead of calling it

#,,,.,,.,,,,.,,,,,...,..,,...,...,,..,,..,,.,,..,,...,...,...,.,,,.,,,,.,,,,.,
#FRN5S57WDOTUNF2EF7HS7PP5Y3H2LNIKZJADJORTRNAESR72C4IFZQYIMOQLRKICHKTWQTI75SE6U
#\\\|Q6G3UNSEOY2LUDHS5NYCX4BC7NRUAHRW2IK7EAYDNZMNHPIG4KN \ / AMOS7 \ YOURUM ::
#\[7]DE7WIVLC2KMZC2UTR6IXRUC6IKSTFEVNUZBSRBDROKLGVLK2ZMAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
