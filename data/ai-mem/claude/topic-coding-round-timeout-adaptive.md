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
completion), `configuration/zenki/coding/start` (two new config keys).

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

#,,,,,.,,,.,.,,,.,.,.,,,.,..,,..,,.,.,,,,,.,,,..,,...,...,...,.,,,...,..,,,.,,
#5IQGSM4KUCLYNO33C56ZKWLAAABX3MKLSWPZAQDLVGEORZAJW5V5VBXRRTSQHVERLPSRMHL3DOSI6
#\\\|434WOABSYTYBVKSRMLRMENHYDMCIAKHXZ3WQPWTDHUFIRJKRHPG \ / AMOS7 \ YOURUM ::
#\[7]JNECPVEENQTMFYNUW7IRF6UPAV4BNV5WZU7SSSFSSP6HVDOTOWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
