---
name: feedback-x11-xvfb-blocking-connect-crash
description: "RESOLVED 2026-09-06 (was: X-11.cmd.xvfb-start crash-loops the X-11 zenka every time it's exercised) — real cause was a duplicate job-queuing bug, not the blocking-connect theory this memory originally described; kept for two still-valid standalone lessons (alarm()/SIGALRM hazard, duplicate-instance cleanup)"
metadata:
  type: feedback
---

**RESOLVED 2026-09-06** — see
[[project-x11-xvfb-crash-loop-and-cleanup-2026-09-06]] for the full fix
(7 bugs, all live-verified) and `data/tasks/x11-xvfb-start-async-
refactor.md` for the detailed root-cause writeup. The original theory
this memory was written under — a slow `X11::Protocol->new()` connect
stalling the event loop — was WRONG; live timing data showed the connect
was always fast. The real cause was `X-11.cmd.xvfb-start` queuing a
redundant second `finalize_server` job, which double-registered an
`event.add_io` watcher on a blocking pipe. `xvfb-start`/`status`/`list`/
`stop` all work correctly now, including concurrent auxiliary displays.

Kept below for two lessons that are still correct and worth carrying
forward on their own, independent of this specific incident.

**Never use `alarm()`/`$SIG{ALRM}` to bound a slow call inside an Event.pm-based zenka's
timer callback.** Event.pm almost certainly uses `alarm()`/`SIGALRM` internally for its
own timer scheduling — it's a single global OS resource. A `local $SIG{ALRM}` override
from inside a callback the framework itself fired clobbers the framework's own alarm
state instead of safely bounding just your call. Tried this in
`X-11.handler.display_poll` (bounding what turned out to be an already-fast
`X11::Protocol->new()` connect) and it made the crash-loop WORSE, cascading into an
unrelated `dbus` restart too. Any bound on a blocking call inside this codebase's zenka
event loops needs to be signal-free — a non-blocking `IO::Socket` connect polled via
`select`/`getsockopt(SO_ERROR)` across ticks, not a timeout signal, or (the actually-used
fix pattern elsewhere in this codebase for a call that must stay blocking) run it in a
forked/spawned child process and poll that instead.

**A crash-restart of a zenka can leave TWO live instances both tracked "online"** — not
just a stale registration pointer (see also
[[feedback-v7-restart-stale-zenka-registration]] for the cube-session-routing variant of
this same family of issue), an actual duplicate OS process each time, confirmed via
`instance_pids <id>` returning two distinct real pids. **Naming correction (this memory
predates the 2026-09-02 v7→v7-zenki rename, `23a0e8d53`): the zenka is `v7-zenki`, not
`v7`** — `p7c v7.list` returns "client not present". Cleanup:
`v7-zenki.instance_pids <id>` on each listed instance id to get pids (note: this is the
numeric instance id from `v7-zenki.list zenki`, NOT the cube session id from
`list sessions`/`list subnames` — different id space, a source of confusion
mid-incident), `ps -o lstart` to tell which is newer, `v7-zenki.terminate <older id>`
(NOT `v7-zenki.zenka.terminate` despite the filename `v7-zenki.zenka.cmd.terminate` —
routable command names can drop more than just the `.cmd.` infix; confirm the real name
via `p7c v7-zenki.commands` rather than guessing from the filename).

**Also relevant, general**: network-called zenka commands drop the `.cmd.` infix present
in the `src/` filename — see [[feedback-network-command-omits-cmd-infix]], the thing that
looked like an access-control gap in this same incident and wasn't one.

#,,,,,,.,,,,,,.,.,,.,,,..,.,.,..,,.,.,.,,,...,..,,...,...,...,..,,.,,,,..,..,,
#E57WUTNUAPVR5QDOXOWVO3GXS5C6ZHWS3PKUWC7RU6YUJR4BBDWD2RTLPTD6VEUQMTP5PPZU2OIPU
#\\\|7EMT7BYXBA2UEHM34NHFWB24HI7SGDGMWB2QZRA2W5I2WVMJXYQ \ / AMOS7 \ YOURUM ::
#\[7]QXWP2V66P43ZYFOTA3TUSBWXDBFTTKO2NKDQFVNY5RFJ7LLVGCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
