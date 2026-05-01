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

### open items
- `loop_detect_count` is zenka-global, not per-task — a model switching between tools
  can reset the counter; should move into `$state->{'loop_detect_count'}`
- Large file operations (>10KB) still hit context limits on 9B model (17777 n_ctx);
  context pressure warning (< 3000 tokens) helps model adapt strategy but not a full fix
- `coding.task.fail` has a P7 data-path bug at line 19 (`<coding.task.failed.queue>`);
  `async.complete` inlines the fail path instead of calling it

#,,..,,,,,,,,,,,.,,.,,,,,,...,...,,.,,,,.,,.,,..,,...,...,.,,,,..,.,.,,,,,,,,,
#UNO6OYD3A27LFWI4RJASR6VO6AMZTGRB74WDNKRQ5QKFOJACIVQF2DJTBJQX22HESAP5G5CRCV26E
#\\\|5MFBQEIH7MDZPFKNX6A24JQHSUB7QWZWF36WVZ44TGWDWO2IN6A \ / AMOS7 \ YOURUM ::
#\[7]4DZ5EO5FJ7BBS7NJXBZTAW5CP6EKGN57DORRMBP3HH3RPQA3DIDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
