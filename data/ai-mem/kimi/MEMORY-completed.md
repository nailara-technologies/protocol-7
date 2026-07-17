# Kimi Development Memory — Completed (Protocol-7)

> entries explicitly marked COMPLETE / RESOLVED / FIXED, moved out of the
> auto-loaded `MEMORY.md` index. links remain valid.

## Round-Based Scheduling & Subtask Spawn — COMPLETE (April 2026)

complete — full subtask round-trip verified. 4 post-handover fixes (double-spawn VRAM starvation, stale-process kill race, subtask backend lock deadlock, timeout recovery).
see [topic-round-scheduling-subtasks.md](topic-round-scheduling-subtasks.md)

## May 1 2026 Session — Regression, Revert, and nshell (0) Bug

regression in `base.log.send-buffer.send-idle-callback` reverted in commit `3b01d2e81` — cube-only guard restored.
nshell cmd_id (0) bug **FIXED** 2026-06-02 — orphaned route handler in `base.handler.command` generated `(0)!TERM!` for prefix-less replies; added `$cmd_id > 0` guard.

## Dynamic Context Templates — Integration Complete (March 3 2026)

see [topic-context-template-system.md](topic-context-template-system.md)

## 2026-04-02 — Bug #5 Fixed: Empty Task Result

`coding.async.complete_task` uses `||` not `//` for result fallback — `||` checks truthiness so empty `''` falls through.

## Async Round-2+ Timeout Bug (2026-04-29)

RESOLVED — n_ctx floor raised to 13500; root cause was KV cache limit.
see `data/ai-mem/claude/topic-async-round-2-timeout.md` (archived, resolved)

## UTF-8 Buffer Handling + Large-Stream Write Fix (2026-05-07) — COMPLETE

`bytes::length`/`bytes::substr` for protocol logic; `base.handler.write` write-ready watcher on EAGAIN; STRM-SIZE stream cleanup.
see `data/ai-mem/kimi/SESSION-2026-05-07-UTF8-STRM-SIZE.md`

## Web-Browser Input Capture/Replay — COMPLETE (July 2026)

all 6 steps landed + live-verified on the running zenka. steps 4-6 added `wait-state-poll`, `replay_template.dispatch_js`, `replay.dispatch`, `cmd.replay-synth`; wait-for-state/replay-play refactored onto the shared modules; whitelist regenerated, signatures pending. see [topic-web-browser-replay-verify-synth.md](topic-web-browser-replay-verify-synth.md) and webkit quirks in [coding-style.md](coding-style.md).

## Web-Browser State-Play + Waypoints — COMPLETE (July 2026)

value-injection replay landed + live-verified: `cmd.state-play`, `cmd.waypoint-set`, `cmd.goto-waypoint`; `__p7SetState` hook in visualization.html [ zoom hook pins manualZoom — updateCamera eases zoom->manualZoom every frame ]; `replay.dispatch` gained force_set [ FORCED exact-landing label ]. gotchas: $1/$2 clobbered by second regex test [ save captures immediately ]; pipe alternation inside m|..| breaks at runtime load [ use m{..} ]. see [topic-web-browser-state-play-waypoints.md](topic-web-browser-state-play-waypoints.md).

#,,,.,...,...,.,,,.,,,,,,,..,,...,.,.,,..,,,,,..,,...,...,,..,...,,..,,,.,,,,,
#KFMQBJ5DPKTCJUIJGGVYD4EZ3OYD7TL3F3IKWBYARVJJDLVF3QFIH5Q55LIWBSO5SBQZLHBOB4XPG
#\\\|XBEITCADM4M7F5IG5MWFCQNGP4AWIG6ED36Q6FHDTYRPOPYOEVS \ / AMOS7 \ YOURUM ::
#\[7]65O7UDGG7IKBWUBAMFYTRPV2FLPXJDCGW5TSAP2RS45JVES2QADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
