---
name: feedback-x11-xvfb-blocking-connect-crash
description: "X-11.cmd.xvfb-start crash-loops the X-11 zenka every time it's exercised; one real bug fixed (dependency deadlock), one still open (blocking connect stalls the event loop) — full detail in data/tasks/x11-xvfb-start-async-refactor.md"
metadata:
  type: feedback
---

Full incident detail, root causes, what's fixed vs. not, and the live-testing hazard/
cleanup procedure: `data/tasks/x11-xvfb-start-async-refactor.md`. This file is the short
pointer + the two standalone lessons worth carrying forward on their own.

**Never use `alarm()`/`$SIG{ALRM}` to bound a slow call inside an Event.pm-based zenka's
timer callback.** Event.pm almost certainly uses `alarm()`/`SIGALRM` internally for its
own timer scheduling — it's a single global OS resource. A `local $SIG{ALRM}` override
from inside a callback the framework itself fired clobbers the framework's own alarm
state instead of safely bounding just your call. Tried this in
`X-11.handler.display_poll` (bounding a blocking `X11::Protocol->new()` connect) and it
made the crash-loop WORSE, cascading into an unrelated `dbus` restart too. Any bound on a
blocking call inside this codebase's zenka event loops needs to be signal-free — a
non-blocking `IO::Socket` connect polled via `select`/`getsockopt(SO_ERROR)` across ticks,
not a timeout signal.

**A crash-restart of a zenka can leave TWO live instances both tracked "online" by
`v7.list zenki`** — not just a stale registration pointer (see also
[[feedback-v7-restart-stale-zenka-registration]] for the cube-session-routing variant of
this same family of issue), an actual duplicate OS process each time, confirmed via
`v7.instance_pids <id>` returning two distinct real pids. Cleanup: `v7.instance_pids <id>`
on each listed instance id to get pids (note: this is the numeric instance id from
`v7.list zenki`, NOT the cube session id from `list sessions`/`list subnames` — different
id space, a source of confusion mid-incident), keep the newer, `v7.stop <older id>`.

**Also relevant, general**: network-called zenka commands drop the `.cmd.` infix present
in the `src/` filename — see [[feedback-network-command-omits-cmd-infix]], the thing that
looked like an access-control gap in this same incident and wasn't one.

#,,,.,...,,,,,,.,,.,,,.,.,,,.,.,,,,,,,,,,,,,.,..,,...,...,,,,,,,.,.,.,,.,,.,,,
#C36D2VAP5LPVOGO5P4NCFVJTS6PQF5OPD2JYP6JKJ365Q56SDCWKC3PKUJYDHH5V66ULUCBUNGJIC
#\\\|L7QIDGSWAFDIDXYNAA7WUM3PC3CXPBEEG5GSOZ5XH4UBOZ4ECJU \ / AMOS7 \ YOURUM ::
#\[7]DZBCZJTYQQOAOOUBBWRDDQO2N7JH34FJPDI76L3UDPUXFGCPECBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
