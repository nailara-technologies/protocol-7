---
name: project-x11-xvfb-crash-loop-and-cleanup-2026-09-06
description: "X-11 xvfb-start/status/list/stop went from crash-looping and structurally broken to a fully working, live-verified command cycle in one session; 7 bugs found and fixed, task file data/tasks/x11-xvfb-start-async-refactor.md rewritten with the real root causes"
metadata:
  type: project
---

Started as: check `data/tasks/x11-xvfb-start-async-refactor.md` for
whether it's a clean dispatch-to-kimi candidate. It wasn't (real open
questions, live-testing hazard from prior crash-loops) - ended as a full
live debugging session that fixed everything in the task, plus 3 more
bugs found along the way.

**Why this matters**: the user's actual goal is automatic headless
capture recreation (vision-generic-web-template-hybrid-doc-browser
work) - a prior session had aborted trying xvfb mode for this and used
the non-headless web-browser zenka instead, because xvfb-start was
fundamentally broken. It now works.

## bugs found and fixed, all live-verified

1. Dependency deadlock (pre-existing fix, confirmed still correct)
2. **The actual crash-loop** - `X-11.cmd.xvfb-start` queued a redundant
   second `finalize_server` job on top of the one `X-11.job.start_server`
   already queues itself; both fired on the same dependency resolving,
   double-registering `event.add_io` on Xvfb's output pipe (never set
   non-blocking), so the second watcher's `sysread()` blocked the whole
   event loop and tripped v7's heartbeat watchdog. The task's original
   theory (slow `X11::Protocol->new()` connect) was wrong - live timing
   data showed every stage was fast. See
   [[feedback-audit-shared-state-when-multi-instance-bolted-on]] for how
   a related bug (6, below) was found via git archaeology.
3. Resource guard (pre-existing fix, confirmed still correct)
4. `xvfb-status`/`xvfb-list`/`xvfb-stop` all read `<X-11.xvfb.pid>`,
   which nothing ever wrote to - real state lives in `<X-11.servers>`.
   Fixed to read the right structure, with a `mode eq 'xvfb'` guard so
   these commands can never touch the primary/host display.
5. `server_output` logged every deliberate `xvfb-stop` identically to an
   unexplained crash ("shut down unexpectedly" at error level). Fixed by
   having `xvfb-stop` mark its own pid as an intentional stop before
   signalling it.
6. `output_buffer`/`first_error` were single global scalars (not keyed
   by pid/display) and `"done."` (a zenka-shutdown idiom) logged
   unconditionally even on the non-exiting auxiliary-server path - all
   three predate 2026-06-18's multi-server support and were never
   audited when it landed (see the linked feedback memory for the git
   archaeology that proved it). Fixed: moved onto per-server state
   (`$event->data`, confirmed same hashref for a watcher's lifetime),
   `"done."` now only logs when actually exiting.
7. Ported the `log_whitelist` convention from `openbox.start_wm` /
   `base.handler.child_output.simple`: Xvfb's benign xkbcomp keymap
   warnings now demote to log level 3 instead of 2, per the user's
   clean-logs-for-regular-operation policy (a level-2 diagnostic session
   should show only output that isn't already known-safe, not require
   re-figuring out "is this noise or signal" every time).

## process notes worth remembering

- `v7-zenki` is the zenka name (not `v7` - `p7c v7.list` returns "client
  not present"). Routable commands drop the `.cmd.` infix from the
  filename AND, for `v7-zenki.zenka.cmd.terminate`, also the `zenka.`
  segment - the actual command is `v7-zenki.terminate` (confirmed via
  `p7c v7-zenki.commands`, don't guess from the filename).
- `show-buffer` must be routed to the target zenka
  (`p7c X-11.show-buffer zenka N`) - the bare `show-buffer` command reads
  whatever zenka is p7c's own default target, which is NOT the zenka you
  think you're diagnosing.
- A zenka's own diagnostic-level (2+) log lines can be filtered at the
  source by its own `<system.zenka.verbosity.buffer>` (codebase default:
  1) - bumping it needs either a `devmod.change-log-verbosity` runtime
  call (only works if `devmod` is loaded into that zenka's module set,
  it often isn't) or a `system.zenka.verbosity.buffer = N` line added
  directly to the zenka's own `zenka.v7` config + a restart. Reverted
  back to default after this session's diagnostics were done, per the
  clean-logs policy - re-add it (2 or 3) for any future live session on
  this zenka.
- A restart of a v7-managed zenka after a source or config edit is
  `v7-zenki.restart <instance-id>` (from `v7-zenki.list zenki`, NOT the
  cube session id from `list sessions`/`list subnames` - different id
  spaces). A crash-loop can leave duplicate instances under the same
  zenka name; `v7-zenki.instance_pids <id>` + `ps -o lstart` tells you
  which is newer, `v7-zenki.terminate <older id>` cleans up.

## status

All 7 bugs fixed and live-verified, including a two-concurrent-display
stress test (separate Xvfb output streams stay un-interleaved, both
stop cleanly, no crash). Task file fully rewritten to document the real
root causes; ready to archive. Not done: nothing in this task remains
open. Separate, not attempted this session: X-11 zenka's `zenka.v7` mode
is still `host` by default - actually wiring headless-capture workflows
to use xvfb (vs. just being ABLE to start/stop one) is the next real step
toward the user's stated goal.

#,,.,,,.,,,,.,,.,,...,...,,,,,,.,,,,,,...,,..,..,,...,...,..,,.,,,..,,...,...,
#TYMSHP5J5PD3P4J5JSJSZTSOIXGR5HLRUUTBFWIUPXOQJQX5XBQQMUXP3OL253IUS6VYZW5H5642S
#\\\|JPYPK2GFHI5JJMMZRWBWHQJS26JJMDZWB5H4XWVX5LJPSCFALII \ / AMOS7 \ YOURUM ::
#\[7]RUWPYOTBINEILCHZBIOCN54IYFDKH6HIC5HYACNDFZTALUFTNGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
