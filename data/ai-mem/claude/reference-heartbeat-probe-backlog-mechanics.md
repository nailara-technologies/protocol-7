---
name: heartbeat-probe-backlog-mechanics
description: "how v7's heartbeat probe/timeout mechanism actually works, and why a big heartbeat.timeout doesn't make a long single blocking call safe"
metadata:
  node_type: memory
  type: reference
  originSessionId: session_01Md1xAjX8TDDBrkT85uyp5P
---

`heartbeat.timeout` and `[base.zenki.set_ondemand_timeout:N]` are two
completely separate axes — don't conflate them (I did, initially, this
session). `set_ondemand_timeout` is the idle-shutdown window (see
[[ondemand-timeout-tiering]]). `heartbeat.timeout` bounds how long v7
waits for a *single* `.heart` reply before treating the zenka as hung.

**Probe cadence is fixed, independent of heartbeat.timeout.**
`v7.handler.heartbeat_timer` runs on a repeating timer (~5.7s interval,
`v7.enable_heartbeat_timer`'s `status_timer_interval` default), and on
*every* firing it unconditionally queues a fresh `.heart` command via
`base.protocol-7.command.send.local` — there is no guard anywhere that
checks "is a previous probe already outstanding" before sending another.
The only thing `heartbeat.timeout` gates is the failsafe kill timer
(`v7.handler.heartbeat_response_timeout`), which is armed once and left
alone while active (not re-armed each cycle).

**Consequence: backlog scales with block-duration / 5.7s, not with
heartbeat.timeout.** If a zenka's command handler blocks the whole
event loop for its own legitimate reasons (e.g. a synchronous
`waitpid($pid, 0)` or `system()` call with no forked-off async I/O), it
cannot read its inbound socket at all during that window — so every
~5.7s probe queues up unanswered, each logged at level 2
(`:network: v7 ..:. <zenka> ..:. heart`, unless
`<devmod.skip_v7_heartbeat>` is set). A 780s block → ~135 queued
probes; a 300s block → ~53. When the zenka finally frees up it drains
and answers the whole backlog in one burst, competing with whatever
real work was actually queued. **A bigger `heartbeat.timeout` does not
fix this** — it only delays the hypothetical kill; the probe backlog and
log noise happen regardless of the timeout value, because that value
never governs the probe-send cadence, only the failsafe.

**The retry model** (`v7.enable_heartbeat_timer`): `max_retries`
defaults to 3, seeded into `retry_count` once per instance. On a true
non-response, `heartbeat.timeout` (default 17s, from
`$zenka_config->{heartbeat}{timeout} || $globals->{heartbeat}{timeout}
|| 17`) is the *first* wait, then up to 3 fast retries (~1-2s each,
decaying) before `zenka.change_status(..., 'error')`. So total
tolerance ≈ `heartbeat.timeout` + a few seconds, not
`heartbeat.timeout` × 3.

**`restart.disabled = 1` doesn't fully neutralize an 'error' status
either** — `v7.handler.zenka_status` tolerates up to
`restart.disabled.consecutive-failure-tolerance` (default 3)
consecutive error/offline transitions before calling `zenka.cmd.stop`
and giving up for real. So a single false-positive heartbeat miss on a
restart-disabled on-demand zenka doesn't kill it outright, but repeated
ones eventually stop it early, mid-idle-window.

**Why not just add a "skip sending a new probe while one's outstanding"
guard?** Considered and rejected (2026-08-24, this session): it breaks
failure detection over lossy transport — a single dropped probe packet
would wedge the guard forever with no resend, and a late stray reply
arriving after the guard had moved on risks desyncing whatever the next
expected reply/buffer state is. Not a fix, a different bug.

**How to apply:** before enabling heartbeat on any on-demand zenka,
actually read its command-handler code for real blocking calls
(`system()`, backticks/`qx()`, `sleep`, synchronous `LWP::UserAgent`
without a small bound, or `waitpid($pid, 0)`/`base.waitpid($pid, 0)`
called directly rather than via a fork + `event.add_io` async pattern
or `waitpid(-1, WNOHANG)`). If a single call can legitimately run for
minutes with no real bound, heartbeat is a structurally bad fit
regardless of the timeout chosen — leave it disabled until the code is
refactored to real async, don't just pick a bigger number. See
[[topic-ondemand-heartbeat-upgrade]] for the 2026-08-24 zenka-by-zenka
rollout this came out of, and which zenki landed on which side.

#,,.,,,..,.,,,.,,,.,,,,.,,...,.,.,...,,,.,...,..,,...,...,.,.,..,,..,,,,,,.,,,
#CLVGWRFGO3BOXY6SFLN5K75UQAIKSNI3HQOMJTGNIOZPR7GSRINQJH3HR5ORGG2CEKNXFVG75X5NC
#\\\|XKHUPHZVYFXO45ZIBPAOHTINIXBMPUW4OWXAV6HY2F4FLZO7RWC \ / AMOS7 \ YOURUM ::
#\[7]UHBOQVUS4HWXY2P5G4G47TEQOWRJT4VXJVZ5DS4MLC6QAEENHYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
