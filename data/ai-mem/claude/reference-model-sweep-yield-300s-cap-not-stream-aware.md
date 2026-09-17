---
name: reference-model-sweep-yield-300s-cap-not-stream-aware
description: model-sweep's yield-to-task-activity has a flat, non-stream-aware 300s wall-clock cap (coding.model_sweep.handler.poll_sweep's yield_since check) that can trip and pause the sweep even while the real task it's yielding to is genuinely healthy and actively streaming -- confirmed live 2026-09-17, safe (no data loss, resumable), just needs an occasional :force: resume
metadata:
  type: reference
---

Confirmed live 2026-09-17: a real coding task's self-test/switch-model
probe (`coding.self_test.handler.poll_switch`) ran past its own 300s
soft threshold but kept extending correctly because the underlying
stream was genuinely alive (`chunks=996 -> 2402 -> 2867 -> 3330`,
steady real progress, same "stream alive, extend toward outer 5400s
cap" resilience pattern `async.http_timeout` also uses at the
transport layer). Meanwhile `coding.model_sweep.handler.poll_sweep`'s
OWN yield mechanism -- a flat wall-clock timer (`yield_since`) checked
every 1s tick against a fixed 300s ceiling, with zero awareness of
whether the thing it's yielding to is actually healthy -- tripped
anyway and escalated to a persisted `paused [ yield-timeout ]`, even
though the real task was nowhere near failing.

**Not a bug, a known-and-accepted gap between two independently
correct mechanisms**: the sweep's yield logic and the self-test/
transport-layer stream-alive extensions were built at different times
for different purposes and were never made aware of each other. The
sweep's escalation-to-pause on a 300s yield is itself intentional and
correct in isolation -- see the "bounded, matching vision_switch_poll's
own 300s bound" comment in `poll_sweep` -- it exists specifically so a
genuinely-stuck queue doesn't yield forever. It just isn't smart enough
to distinguish "stuck" from "legitimately long but healthy."

**Consequence, confirmed safe**: the sweep pauses cleanly (cursor
persisted, `idx` unchanged, no candidate progress lost) and needs a
`model-sweep-resume <backend> :force:` to continue -- harmless to issue
immediately even if the real task is still in flight, since resuming
just re-enters yielding with a fresh 300s window on the next tick
rather than retrying anything destructively. This can recur any time a
real task's own request runs a legitimately long-but-healthy stream
(several minutes+) while a sweep happens to be yielding to it.

**How to apply**: if `model-sweep-status` shows `paused [ yield-timeout
]` and the coding zenka's own logs show a healthy, actively-chunking
stream around the same time, that's this known gap, not a new
investigation -- just `:force:` resume. If this recurs often enough to
be annoying, the real fix would be making the sweep's yield check
stream-aware (mirror the "chunks alive" extension logic instead of a
flat timer) rather than raising the flat 300s number, which would just
shift the same problem to a longer wall-clock -- not attempted, not
scoped as a task yet.

#,,,,,.,,,.,.,,,,,,,.,...,.,,,,,,,,,.,.,.,,..,.,.,...,...,.,.,.,,,,,.,,,.,,,.,
#YVC23ULV5DA4GAXNGGDK5RIEQ25CGWCTYAI3BZN7W52XEEDGK3NDNB3CDUIIAXRF6BMLNT3EENGAA
#\\\|ZO4FASD5QA3DWI4FL3AY3UIAGXQ3VCAZS4HEQEUAXGJZ4MOHRWY \ / AMOS7 \ YOURUM ::
#\[7]VDWDQ4MWSX5RJJDMBRF6IQJ2GKXNKD437HEF7MXQKBJMPX3UU6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
