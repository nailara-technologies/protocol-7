---
name: reference-strm-size-write-cap-stall
description: base.handler.write's 64-syswrite-per-call cap could silently strand buffered output forever if every write succeeded (no EAGAIN) before the cap was hit -- root cause of a verbosity-dependent nshell STRM-SIZE stall, fixed 2026-09-14
metadata:
  type: reference
---

`base.handler.write`'s write loop (`max_writes_per_call = 64`) has three possible exits: buffer
drained, `syswrite` returns 0 (EAGAIN, socket full), or the 64-write cap reached with data still
left. Only the first two were handled — the burst-write re-arm branch (`session->{'burst-writes'}`,
set to 13 for every client session in `base.session.init`) fired before the EAGAIN check and left
the watcher marked "active" regardless of which exit occurred, which made the later
`io_idle_restart` fallback (`if ... not $event->w->is_active`) skip pushing the watcher onto
`<watcher_list.paused>` for its rescue. Net effect: hitting the cap with every write still
succeeding left the remaining buffered bytes scheduled to nothing, forever — no error, no
disconnect, just silence.

**Symptom that led here:** `coding.dump` (~1.5MB reply, auto-fragmented into ~180 STRM-SIZE
chunks) reliably stalled partway through nshell's console output at normal/default verbosity, but
always completed at verbosity ≥ 2. Root cause: the cap counts *successful writes*, not bytes — a
fast/quiet consumer (nshell doing little logging) never let cube's socket back up enough to
trigger real EAGAIN, so it always hit the write-count cap instead of the (already-correct) EAGAIN
recovery path. A slower consumer (`-vvq`, ~180 extra log lines) let the socket queue fill first,
triggering the EAGAIN path, which is why raising verbosity "fixed" it — pure scheduling luck, not
a real fix. A `socat` capture of the raw wire bytes never reproduced it because socat is a much
faster consumer AND never declared `strm_size_support`, so it took a different (non-chunked SIZE)
code path entirely in `base.stream.emit` — a capture that "looks complete" doesn't rule out a
send-side stall under different client timing.

**The fix** (in `base.handler.write`): detect `$write_count >= $max_writes_per_call && $write_size
> 0` as its own case and leave the watcher inactive in that case (skip the burst-write/`not
$hit_eagain` re-arm branches), so it falls through to the same `io_idle_restart` → paused-list →
`->now` rescue the EAGAIN case already uses, instead of inventing a new mechanism.

**Also confirmed while investigating** (via reading the actual installed Event-1.28 C source,
`c/var.c`/`c/watcher.c`/`c/queue.c`, safely located via `perl -MEvent -e'print $INC{"Event.pm"}'`
rather than a filesystem-wide search):
- `Event::var`'s write-detection is Perl's `'U'` (uvar) magic on `SET`, which fires identically
  regardless of HOW a scalar is mutated (regex, `substr(...,'')`, full reassignment) — ruled out as
  a cause during this investigation, don't re-chase "wrong buffer-stripping method" theories here.
- `->again` on a non-timer watcher is a literal no-op equivalent to `->start` when already active
  (`pe_watcher_start` returns immediately if already active) — several "CRITICAL FIX ... use
  ->again not ->now to avoid infinite loops" comments in `base.handler.read` are factually
  incorrect about what `->again` does, though harmless in context (see
  [[feedback-event-watcher-callback-reload-needs-restart]] for the related restart-vs-reload gotcha
  hit while testing this).
- `->now`'s callback firing is explicitly priority-dependent/not-guaranteed-immediate per Event's
  own docs, and a watcher with `prio => -1` (like `output_buffer`) dispatches its queued event
  *synchronously, re-entrantly* rather than going through the normal loop — worth knowing before
  reasoning about ordering in this area again.

**Not the cause, ruled out during this investigation** (don't re-chase): capability-negotiation
timing (declare-strm-size-support always long-completed before interactive commands), the
`read-mode eq 'linewise'` gate on `base.handler.input`'s `->now` nudge (removed live, zero effect,
reverted), and the utf8 chunk-loss bug in `base.stream.emit` (real, separate, fixed earlier same
session — see the `utf8::encode` vs `utf8::downgrade(...,1)` note in that file's own history).

#,,..,.,,,,..,...,...,,..,.,.,.,.,,.,,,.,,...,..,,...,...,.,.,..,,.,.,,.,,,..,
#MSBH5USF55M63X72ST5KVXAJROMXKSGY7TYGZN23LRJHMQSKDQA7RFIACNZDBHYDX5EWQFGDS4FMK
#\\\|GYEU3FAAVLF7BGSSIEFJPLT3IDE3EOB22HGQS3QHQ3JEZ6DO6LB \ / AMOS7 \ YOURUM ::
#\[7]XO4CA5I7FEFLTCZPM5XP66CJJSHUXLCQFF2WCARWR267EMRKWWDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
