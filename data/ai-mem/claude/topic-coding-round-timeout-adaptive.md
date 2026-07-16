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

## open / not done

GPU-temperature-aware timeout stretch — extend timeouts when the GPU is
thermally throttling (`coding.handler.gpu_temp_update` already tracks
temp and is consulted elsewhere, e.g. `coding.helper.calculate_safe_context`)
so a fixed timeout doesn't misfire when inference is legitimately just
slower under throttle. Discussed, not designed, not started.

#,,..,.,.,.,.,..,,,,.,...,,.,,.,.,.,.,,.,,,.,,..,,...,..,,...,.,.,...,.,.,...,
#T62DGDULYLLFTDFFMIAXDMEVGXS3BULISBOWE3VBOGBK42XTJB2TAS6XEJ35LIMBU2HBAMPEM73EW
#\\\|UNCXRJWLTPEVGJLAGY7PMKYMXJHC3DQCFSD3DX6YSBHOI3QCR7T \ / AMOS7 \ YOURUM ::
#\[7]QOSYR7XSB2NKWK65DR6LPKTNL3CCXSOQQJKDVTOECD7PDUELICBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
