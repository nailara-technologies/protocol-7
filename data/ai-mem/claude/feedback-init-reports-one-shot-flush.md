---
name: feedback-init-reports-one-shot-flush
description: system.init_reports only flushes once around the initial connect event and drops deferred reply handlers across that flush — use system.callbacks.initialized instead for pre-connect sends that need a reply
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2d7f74d1-9a12-4f1d-a522-f128bdffe22d
  modified: 2026-07-19T18:20:28.072Z
---

`<system.init_reports>` (`base.session.send_init_reports`) is a
**one-shot, connect-time-only** queue, not a general "send whenever
ready" mechanism. It is registered as the reply handler for the zenka's
*initial* cube connect in `base.net.connect`, drains + deletes the
whole queue once `<system.zenka.initialized>` is true, and is never
triggered again afterward (short of an actual reconnect).

Two failure modes from using it outside that narrow window:

1. **Fire-and-forget items queued pre-connect** (e.g. a notification
   with no reply handler) work fine — this is the mechanism's actual
   intended use (see `base.tmp_dir`, `base.n_pipe.open`,
   `base.file.temp`, `radio.post_init`).
2. **Items with a deferred reply handler queued pre-connect** are
   unreliable through the one-shot flush — confirmed live: routing
   `v7.notify_online` (whose *reply* triggers the real action, e.g.
   `radio.audio.handler.player_online` issuing the actual mpv `play`
   command) through `init_reports` sent the initial command fine but
   the reply-triggered follow-up never fired. Playback silently never
   started even though the command was visibly sent in logs.
3. **Anything invoked again later at live runtime** (not just at
   startup) — e.g. a module re-triggered by another handler hours into
   the zenka's life — will queue into `init_reports` and then sit there
   forever, since nothing re-flushes the channel after the first
   connect.

**Why:** I (assistant) queued three separate `init_code`/`post_init`-time
`route-send` calls through `init_reports` to fix real "no clients in
session" drops (send.local diagnostic logging added in b963bcc2b
surfaced these). One of the three (`radio.audio.init`) also gets
re-invoked live via `radio.audio.handler.player_offline` — using
`init_reports` there broke mpv restart entirely after the first
success. A second (`lm-vision.init_code`) needed a deferred reply
handler through the flush, which `init_reports` didn't reliably carry
— confirmed by the same live symptom (mpv `play` command never issued,
diagnosed from the equivalent radio.audio.init regression before the
lm-vision case was even tested).

**How to apply:** For a `route-send` (or `send.local`) call that must
happen from `init_code`/`post_init` (i.e. genuinely pre-connect):
- **No reply needed, and it's genuinely a one-time startup thing** →
  `<system.init_reports>` is correct and simplest.
- **A reply handler must survive to fire later** (subscribe-style,
  "notify me when X"), OR **the call site can also be re-invoked later
  at live runtime** (not just during startup) → use
  `<system.callbacks.initialized>` instead (`push @{ <system.callbacks.initialized> //= [] }, sub { ... }`
  or `push <system.callbacks.initialized>->@*, sub { ... }` — both
  forms exist in-repo). This is what `coding.init_code`'s GPU-stats
  subscribe and the fixed `lm-vision.init_code` use.
- If the call site is invoked well after startup in practice (e.g. a
  timer with several seconds' delay) AND is also re-invoked at live
  runtime by another handler, don't defer through either mechanism —
  direct `route-send` is correct, since by the time it fires the
  connection is reliably already up (see reverted `radio.audio.init`).

Always verify end-to-end after a fix like this, not just "the log error
is gone" — the error clearing is necessary but not sufficient; the
regression here cleared the log noise while silently breaking the
actual reply-triggered behavior.

#,,,,,,,,,,..,.,.,,,,,,..,,..,,,.,,,,,..,,,,.,..,,...,..,,,..,,..,,,,,..,,..,,
#PXE2NWS6UC67SZ5DKP4CF3B23BEIQZNIAP67H5BPO467RETNJ425UY3Z3DE4W7R565EK4QQRRFSM4
#\\\|VYFVNMUOSDCPQ3AMY25YE7UDPEOZDSSDDQBKCPHDNQSEYO4DKKZ \ / AMOS7 \ YOURUM ::
#\[7]Q2CZB7OXKDPRBMDEPFUCUPHUMOSGTV5H2LFYDG3JWV6RS7WXMGAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
