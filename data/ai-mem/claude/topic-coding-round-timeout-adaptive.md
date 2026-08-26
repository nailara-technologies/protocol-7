---
name: topic-coding-round-timeout-adaptive
description: "coding zenka round-timeout redesign — adaptive soft/hard ceiling, chunk-driven stall detection, manual restart-round command"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

**LANDED 2026-07-16, commit `411b5635c`.** Prompted by watching
`coding.round-progress` live during a long-running round and asking for a
manual restart plus a smarter timeout than the flat 780s total-duration
deadline that existed before.

## what changed

- **adaptive ceiling**: rounds now start at `coding.cfg.round_soft_ceiling`
  (384s, half the old flat ceiling) instead of the full
  `coding.http-timeouts.request-completed` (777s). Hitting the soft
  ceiling escalates `$task_state->{'timeout_ceiling'}` to the hard value
  and restarts the *same* round in place via the new
  `coding.async.round_soft_restart` helper — not the heavier
  `coding.callback.http_error` pipeline (backend restart + full task
  requeue), which is for genuinely broken connections, not "still working,
  just slow." A clean completion (`coding.callback.http_complete`) deletes
  the escalation so the next round starts fast again. Net effect: typical
  stuck-round recovery time roughly halves without permanently punishing
  legitimately slow rounds.
- **stall/inactivity detection**: separate 77s timer
  (`coding.http-timeouts.stall`), re-armed on every streamed chunk in
  `coding.handler.http_io` using the `last_activity` field that was
  already tracked there but unused for this purpose. Fires only on genuine
  silence, independent of total elapsed time — a stream producing tokens
  every second never trips it regardless of how long the round runs. Routes
  through the *existing* `http_error` retry/backend-restart pipeline
  (new `coding.handler.http_stall_timeout`), since dead air mid-stream is
  exactly the "server accepted the connection but never responds" case
  that pipeline already handles.
- **manual restart**: new `coding.cmd.restart-round [task_id]`, mirrors
  `coding.cmd.abort-inference`'s active-task lookup but ends in the same
  escalate-and-redispatch path instead of a terminal failure.

## key design point

Two failure signatures need different responses, not one timeout: "still
streaming, just slow" (soft-ceiling escalation, cheap same-round retry)
vs. "genuinely stalled/broken" (stall timer or hard-ceiling exhaustion,
routes to the existing backend-restart+requeue pipeline). Conflating them
into one flat deadline was the original bug.

## files touched

`coding.async.request` (ceiling init + stamp), `coding.async.http_client`
(stall watcher setup), `coding.handler.http_io` (re-arm on chunk),
`coding.handler.http_timeout` (soft/hard branch), new
`coding.async.round_soft_restart`, new `coding.handler.http_stall_timeout`,
new `coding.cmd.restart-round`, `coding.async.http_cleanup` (cancel
stall_watcher too), `coding.callback.http_complete` (reset on clean
completion), `cfg/zenki/coding/zenka.v7` (two new config keys).

## round-progress/round-time display fixes — LANDED 2026-07-17 (c8166f22f)

Both displays always showed the flat `coding.http-timeouts.request-
completed` default as denominator, ignoring the actual per-task
`timeout_ceiling` set by the adaptive system above — now read
`state->{timeout_ceiling}` first. Also fixed a live-observed blind spot:
`round-progress`'s lock-based task discovery went blank ("no active
task") whenever the task was deep in tool execution (no GPU load, no
backend lock held, but genuinely `in_progress` per `coding.status`) —
most of the wall-clock time for a tool-heavy task. Falls back to
whichever active task has the most recent round-activity timestamp when
no lock is held, not `active[0]` by position (that's exactly the
"misleading first-in-queue" case the original lock-check avoided).

## GPU-temp-aware timeout stretch — LANDED 2026-07-17

Correction to an earlier note here: `coding.stats.gpu.temp` had zero
consumers before this — `coding.helper.calculate_safe_context` and
`coding.spawn_inference_server` only touch GPU *memory* (VRAM), not
temperature. Checked directly before building on the wrong assumption.

Modeled on an older, unrelated but structurally identical precedent
pointed out mid-design: `web-browser.handler.gpu_load_reply` (GPU load →
scroll-speed slowdown) — a continuous proportional-feedback controller,
not a threshold trip: asymmetric acceleration (ramps up fast when over
target, relaxes slowly when under) plus a dead-band tolerance to avoid
jitter. That shape reproduced here for temp → timeout stretch instead of
load → speed. Unlike that precedent, no push/relay between zenki was
needed — coding already has the GPU temp STRM subscription locally, so
the stretch-factor recompute piggybacks directly on the existing consumer
in `coding.handler.gpu_temp_update` rather than needing a new trigger.

`coding.cfg.gpu_target_temp_c` (77 — tuned from observed behavior:
slowdowns already seen around 80C in practice on this WSL setup, not a
vendor spec number) is the target; `coding.stretch.timeout_factor`
(persistent, clamped `[1.0, 3.0]`) is recomputed on every temp reading.
Both `coding.async.request`'s soft ceiling and `coding.async.http_client`'s
stall timeout multiply their base value by the current factor at
round/connection start — read once per round/connection, not
continuously, consistent with how the ceiling itself already works.

## soft-ceiling gate was keyed on the wrong signal — LANDED 2026-08-07 (`4c3cf0e73`)

Found while chasing a self-test failure (`prompt 2 : inference failed :
request_failed` after a 90s timeout, despite the server actively
streaming). Root cause: `coding.handler.http_timeout`'s soft-ceiling
escalation branch (the "still streaming, just slow, extend instead of
hard-fail" path described above) was gated on `defined $task_state` —
i.e. "does this belong to a real queued task" — not on whether the
stream was actually alive. `coding.self_test.async_probe` deliberately
passes an empty `task_id` to stay decoupled from the task queue, so
self-test requests could **never** take the soft path and always
hard-failed at the flat per-request ceiling (90s), even mid-stream with
valid tokens still arriving. The `task_state`-existence check was a
proxy for liveness that happened to correlate for real tasks but said
nothing for self-test — same *shape* of bug as
[[feedback-coding-timeout-restart-loop]]'s floor/ceiling mixup: a gate
built on a condition that's merely correlated with the thing you
actually need to check.

Fix: the gate now checks real liveness directly — `chunks_received > 0`
and `last_activity` within `stall_timeout_sec` (the same signal the
stall watcher itself already uses) — then branches on `task_state` only
to decide *how* to continue: task-based requests still get the existing
tear-down-and-redispatch `round_soft_restart`; non-task requests (self-
test) get the deadline extended **in place** on the same open connection
instead (no redispatch machinery exists for them, and redispatching
would throw away real in-flight progress for no reason).

Two more fixes landed alongside it, all same commit:
- `coding.handler.verify_inference_startup`'s independent fallback
  queue-resume timer had its own 120s deferral ceiling — shorter than
  self-test's *own* worst-case duration. It could fire mid-retry and
  force-resume the task queue before self-test had actually concluded,
  which is the exact premature-resume race the
  `self_test_probe_in_flight` guard exists to prevent, just via a second
  uncoordinated timer nobody had reconciled against the first. Ceiling
  now derives from self-test's own hard watchdog
  (`coding.cfg.self_test_max_total`, `coding.self_test.handler.poll_probe`)
  instead of a smaller hardcoded number picked independently.
- new `coding.detect_stream_repetition` (cheap bounded-tail regex, unit
  8–60 chars repeated 4+ times back-to-back) wired into the shared
  `coding.handler.http_io_parse_line` transport layer, next to the
  existing `coding.abort.check_stream` pattern-match check. Needed
  because liveness-gated extension alone would let a technically-alive
  but content-degenerate stream (a model looping on its own output) run
  far longer than before — chunks-flowing and content-sane are
  completely decoupled signals. Real tasks route a match through the
  same `on_abort` recovery path already trusted for pattern-match
  aborts; self-test reports it as a non-retryable `on_error`, which for
  the cat-test prompt flows straight into the existing
  `monitor_inference_startup` seed-restart path used for any other
  prompt-2 failure — no new escalation plumbing needed, it composes with
  what already existed.

**How to apply**: when a boolean gate exists to answer "is this thing
still legitimately working," grep for what it's actually testing before
trusting it — `defined $x` where `$x` is merely *correlated* with
liveness (exists-because-it's-a-task, not exists-because-it's-alive) is
a different question than liveness itself, and the two conditions can
silently diverge for any caller that doesn't populate `$x` the same way.

#,,,.,,.,,..,,,..,,.,,...,,..,...,,.,,,.,,,..,..,,...,..,,...,.,.,,..,,.,,...,
#3EDACHAAJSPMG7TCCZ6QNU43JNDQE2QSXVFIEPREP4HNAOUB3VBAPHFJWBT2VWICLRZVFXV5WWQ2M
#\\\|3LDZRB7JPFPZK3IWWRNOE4XW2D5C2SZV5DGMUXUGV3ZD6LADAEV \ / AMOS7 \ YOURUM ::
#\[7]UYBIS4OR6JA3ZB2UXNYHNCHAAGVEYBFJRCW7AZWZ5Z3GXSKMS2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
