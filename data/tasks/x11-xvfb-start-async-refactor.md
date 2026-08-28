# task: X-11 xvfb-start/display_poll — fix blocking connect, needs async refactor

## context

`X-11.cmd.xvfb-start` (used to bring up a headless Xvfb display so a zenka
like `web-browser` can render without touching the live WSLg/Weston
display) crash-loops the whole X-11 zenka every time it's actually
exercised. Confirmed live, 2026-08-28, three separate attempts, each one
tripped v7's heartbeat watchdog and forced a full X-11 restart (which
cascades into restarting its dependents too — `dbus`, `openbox` — expected
dependency-cascade behavior, not a separate bug).

Related pre-existing task: `data/tasks/x11-capture-commands-rewrite.md`
documents the same underlying pattern elsewhere in this zenka (blocking
`system()` calls that should be async) — this is a recognized category of
debt in X-11 zenka, not a one-off.

Full incident writeup with the live debugging trail (auth rabbit hole that
turned out to be a red herring, the two bugs found, the failed alarm fix
and why): `data/ai-mem/claude/vision-generic-web-template-hybrid-doc-browser.md`
(under the 2026-08-28 screenshot-triage sections) and
`data/ai-mem/claude/feedback-x11-xvfb-blocking-connect-crash.md`.

## bug 1 — FIXED, `src/X-11.cmd.xvfb-start`

Both jobs it queued (`X-11.job.start_server` and `X-11.job.finalize_server`)
were gated on the SAME freshly-created `$dep_id`. But `start_server` is the
job that's supposed to *satisfy* that dependency (fork Xvfb, poll until the
socket connects) — gating it on its own dependency deadlocks permanently,
before any process even gets spawned. Fixed by changing the `start_server`
job's `object_id` to `0` (no dependency — jobqueue's own convention for
"run unconditionally", per the comment in `jobqueue.add_job`). Only
`finalize_server` still waits on `$dep_id`.

This fix is correct and should stay regardless of what happens with bug 2 —
without it, `xvfb-start` never does anything at all.

## bug 2 — NOT FIXED, needs real async work

`X-11.handler.display_poll` polls every 0.1s (via `event.add_timer`) for the
display socket to come up, then calls:

```perl
$conn = X11::Protocol->new($display_str);
```

This is a **synchronous, blocking** connect + setup-handshake to the X
server. Called from inside a timer callback in a single-threaded
Event.pm-based event loop, a slow instance of this call stalls the entire
zenka — including whatever lets v7's heartbeat get a timely reply — and
v7's watchdog kills and restarts the zenka.

### partial mitigation already applied, `src/X-11.handler.display_poll`

Added a cheap filesystem pre-check (`-S "/tmp/.X11-unix/X$disp_num"`)
before ever attempting the connect, so the blocking call is at least not
attempted on every 0.1s tick while the socket plainly doesn't exist yet.
Signal-free, safe, confirmed to not itself cause harm — but **confirmed
insufficient on its own**: crash-looped again even with only this check in
place, meaning the stall isn't (purely) about repeatedly probing a
nonexistent socket. Something about the connect/handshake itself — once the
socket *does* exist — is still slow enough to trip the watchdog, or the
real stall is happening somewhere earlier in the chain
(`X-11.job.start_server`'s process spawn) that wasn't fully ruled out.

### approach tried and REVERTED — do not repeat without understanding why it failed

Wrapped the `X11::Protocol->new()` call in a `Time::HiRes::alarm()` +
`local $SIG{ALRM}` guard to hard-bound its worst-case latency. This made
things WORSE, not better — still crash-looped, this time also cascading
into a `dbus` restart. Hypothesis (not fully confirmed): this zenka's
event loop is Event.pm-based, and Event.pm very likely uses `alarm()`/
`SIGALRM` internally for its own timer scheduling. A `local $SIG{ALRM}`
override from inside a callback fired *by* one of the framework's own
timers is a global, single, shared resource — it almost certainly
clobbered the framework's own alarm state instead of safely bounding just
this one call. **Any fix needs to be signal-free.**

### what's not yet known

- Does the stall happen inside `display_poll`'s connect at all, or inside
  `X-11.job.start_server`'s `open($out_fh, "$server_bin ... 2>&1 |")` /
  `<[base.zenki.report_child_pid]>` calls, before `display_poll` ever
  gets a chance to run? The ring-buffered `zenka` log didn't retain enough
  history across the crash to confirm which stage was reached each time —
  needs either a bigger buffer, `p7-log.verbosity` bumped for the duration
  of a controlled test, or a disk-log tail instead of the ring buffer.
- Whether `X11::Protocol->new()` supports being handed an already-opened,
  already-connected filehandle instead of a display string — if so, a
  proper fix is: do our own non-blocking connect via `IO::Socket::UNIX`
  (`Blocking => 0`, poll completion via `select`/`getsockopt(SO_ERROR)`
  across ticks, no signals involved), and only call
  `X11::Protocol->new($already_connected_fh)` once the raw connect is
  confirmed live — skipping whatever X11::Protocol's own connection
  establishment does internally (which may itself try a TCP fallback on a
  closed port, plausible source of multi-second stalls under WSL2
  networking, not confirmed).
- There's also an alternate `X-11[subname]` mechanism (the same
  `zenka[subname]` addressing used elsewhere, e.g. `taeki[nshell]`) for
  running a SEPARATE dedicated X-11 instance already configured for Xvfb
  from the start, rather than commanding the live primary X-11 instance to
  also manage a secondary display at runtime. User's own assessment: this
  doesn't avoid the underlying problem, since that instance would still
  need the same `xvfb-start`/`display_poll` chain to actually bring the
  display up — worth knowing about as a deployment pattern, not a
  substitute for the real fix.

## live-testing hazard, read before touching this again

Every live attempt so far (3 for 3) has crash-looped X-11 and left TWO
duplicate `X-11` zenka instances both tracked "online" by `v7.list zenki`
— a real duplicate-process state, not just a stale pointer (confirmed via
`v7.instance_pids <id>` mapping to two distinct live OS pids each time).
Cleanup procedure that worked each time: `v7.instance_pids <id>` on both
listed instances to get their pids, keep the newer one, `v7.stop <older
instance id>` (the numeric id from `v7.list zenki`, NOT the cube session id
from `list sessions`/`list subnames` — those are a different id space).

Do not attempt another live test of this without either (a) much better
visibility into which stage stalls first (bump verbosity, watch logs live
rather than polling the ring buffer after the fact), or (b) a genuinely
signal-free non-blocking connect implementation ready to test, not another
guess.

## bug 3 — NOT FIXED, no concurrency guard on xvfb-start

Confirmed via code reading, 2026-08-28: there was never a working
resource-exhaustion guard on `xvfb-start`, before or after the bug 1 fix.
`base.dependency.add_object` always mints a fresh, unique id per call (no
pooling across calls), and the callback registered for the
`x11_display_flag` type (`X-11.callback.object.x11_display_flag`) only
checks that ONE display's own `connected` flag — there's no shared counter
or slot limit anywhere in this path. The original design doc
(`data/tasks/completed/X-11-NEW-COMPONENTS.md`, "Xvfb management commands"
section) never specified one either — its open questions are about display-
number allocation, v7 lifecycle registration, GPU/SHM sharing, nothing
about concurrency limits. So the self-referential dependency bug 1 fixed
was near-certainly a copy-paste mistake (finalize_server's "wait for
connection" gate applied to start_server too), not a broken throttle
attempt — but the underlying concern is still real and unaddressed: now
that `xvfb-start` actually runs `X-11.job.start_server` unconditionally,
nothing stops a caller (buggy script, repeated retries, etc.) from starting
an unbounded number of concurrent Xvfb processes.

**Needs, revised per user 2026-08-28**: not a plain count-check — model this
on the SAME dependency-chain self-reference pattern already used correctly
elsewhere in this codebase, e.g. `src/coding.task.ensure_model_pinned`
(`dependency.add_object` + `dependency.add($dep_id, $dep_id)` with the
comment `## self-chain : invokes the callback ##`). That function's actual
shape is the template: it fires the resource-consuming action
(`switch-model`) UNCONDITIONALLY in the same call that creates the
self-chained dependency object, and only hands `$dep_id` back to the
CALLER for callers that need to block on readiness — it never gates the
action itself on its own not-yet-resolved dependency (that's what caused
bug 1's deadlock). Mirror that shape:
- new dependency type, e.g. `xvfb_resource_available`, with a registered
  callback (alongside `X-11.callback.object.x11_display_flag` in
  `X-11.init_code`'s `<[dependency.install_callbacks]>->('X-11')` block)
  that checks actual resource state — see
  `src/coding.helper.check_resource_fit` for the numeric-check shape to
  mirror (system RAM via `/proc/meminfo` `MemAvailable`, not GPU VRAM here
  — Xvfb allocates its full `WxHx24` framebuffer up front, see
  `data/ai-mem/claude/topic-x11-resolution-profiles.md`'s already-noted,
  not-yet-implemented memory-exhaustion concern: bound width/height to a
  sane ceiling too, e.g. reject anything above 4096 on either axis,
  regardless of the memory check)
- `X-11.cmd.xvfb-start` creates/reuses this dependency object the same way
  `ensure_model_pinned` gets-or-creates its `model_checksum_loaded` object,
  checks it's satisfied BEFORE queuing `start_server` (a plain
  `dependency.ok()` call, synchronous, not a jobqueue gate — `xvfb-start`
  itself can just reject with a clear error if resources don't fit, same
  as `spawn_smart` does with `check_resource_fit`'s `fits` flag)
- keep `start_server`'s own jobqueue `object_id => 0` from bug 1's fix —
  that part was right regardless; this is a NEW check ahead of queuing it,
  not a replacement gate on the queued job itself

## status

Bug 1 fix (dependency deadlock) is landed and safe to keep regardless.
Bug 2 (the actual blocking-connect crash) is NOT fixed — filesystem
pre-check mitigation is in place but confirmed insufficient. Diagnostic
timing logs have been added around the two suspected stall points in
`X-11.job.start_server` (`open()` spawn and `report_child_pid`) and in
`X-11.handler.display_poll` (`X11::Protocol->new()`), so the next live
attempt can pinpoint which stage stalls first. A signal-free non-blocking
connect refactor was NOT attempted; do not test live without using those
logs to confirm where the time is spent.

Bug 3 (no concurrency/resource guard) is IMPLEMENTED: new dependency type
`xvfb_resource_available` with callback in
`src/X-11.callback.object.xvfb_resource_available`, checked synchronously
in `src/X-11.cmd.xvfb-start` before queuing `start_server`. It rejects
requests whose dimensions exceed 4096 on either axis or whose framebuffer
(+ 128 MB overhead) does not fit in `MemAvailable`. It mirrors the
`ensure_model_pinned` get-or-create self-chained dependency pattern and
keeps `start_server`'s `object_id => 0` from bug 1 intact.

## dispatch notes [ for whoever picks this up, human or AI ]

Read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md`
first if you're kimi. P7 pitfalls to watch for regardless: `base.logs` not
`base.log` for multi-arg sprintf-style calls, never redeclare `my $call`,
never add fake `PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE` footers to new files
(the human signs new files separately), `TRUE`/`FALSE` are `5`/`0` in this
codebase not `1`/`0`. Do NOT attempt to test bug 2's fix live against the
running X-11 zenka without a clear plan for observability first (see the
"live-testing hazard" section above) — bug 3 (the concurrency guard) is
independently testable/reviewable without touching the live display-connect
path, safer to tackle first or in isolation. If you learn something
non-obvious about this dependency system or the X-11 zenka while working on
this, add a note to your own memory files, same as any other task.

#,,.,,,,,,,..,,,,,,..,,..,.,.,.,.,,..,,.,,,.,,..,,...,...,..,,,..,,.,,..,,.,.,
#3423ERYOBTBRI6UAFMK26RK2272TT4BG73WTEDJBI4K2OUYXS6N57HHYAMGMGZCNBNINSCF5DEWD4
#\\\|QMLNYXJ7INX4TQ6GPCHIB2IL5RR5EQBY5OBFCPGDRU367ODN4AN \ / AMOS7 \ YOURUM ::
#\[7]OLW4GYXDD55EAA42EBOAVVXAF6XGYHSETBCFO5QGDFER5PI5LMBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
