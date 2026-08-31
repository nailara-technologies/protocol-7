---
name: psytrance radio relay zenka
description: jingle-filtering radio relay with keep-library, stream-ripper mode, STRM output to httpd, mpv playback; first real unbounded STRM consumer
type: project
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## current status (2026-04-25)

### completed (all committed to branch `base`)

- **phase 1**: ICY stream reader + unbounded STRM relay (radio.cmd.listen)
- **phase 2**: jingle detection + skip/keep commands
- **phase 3**: keep-library accumulation + gap filler (idle watcher)
- **base**: local STRM consumer primitive (base.strm.local.register/cancel/consume)
- **base**: recv-test dev tool (base.strm.callback.recv_test)
- **httpd bridge**: plugin.httpd.radio.* — /radio/stream HTTP endpoint, per-client radio.listen
- **TCP rewrite**: radio.connect uses base.open ip.tcp output + TLS (IO::Socket::SSL) for HTTPS
- **phase 4**: mpv[audio-0] background player via v7.start_once + v7.notify_online

### STRM cancel — FIXED (2026-04-25, commit 01b6be26e)

root cause: `base.session.cancel_route` deleted the route from `$data{'route'}` when
a consumer session disconnected, but:
1. never sent `!TERM!` to the STRM producer
2. left a stale `route{M}` entry in the producer's session

consequence: producer's next push → cube looked up deleted route → undef dereference
→ Perl crash → orphan handler at line 1417 never reached → stream continued forever.
the crash also left binary ICY payload in cube's buffer → "protocol mismatch" logs,
and a bare `FALSE\n` recovery attempt → "FALSE-reply to unknown route id [0]" in producer.

fix: in `base.session.cancel_route`:
- check `$data{'session'}{$t_sid}{'streams'}{$t_cmd_id}` (no `producer` flag needed —
  in cube's context the streams entry exists without it; `producer` is only set in the
  producing zenka's own process via `base.stream.open`)
- send `($t_cmd_id)!TERM!\n` to target session buffer
- set `stream_cancelled{$t_cmd_id}` on target session
- delete stale `route{$t_cmd_id}` from target session

verified: mod-test.strm-open + socat disconnect → "gated off" logged correctly.
both paths now work: cancel_route fires immediately on disconnect, orphan handler
catches any chunk already in-flight. log ordering between zenki is not reliable for
ordering analysis (each zenka timestamps independently via base.anum_log_time).

### protocol cmd_id format — FIXED (2026-04-25, commit 01b6be26e)

`sprintf '(%d) '` in base.handler.command, base.stream.open, base.stream.emit,
base.callback.cmd_reply was producing `(N) CMD` with a trailing space instead of `(N)CMD`.
receiver regex tolerated it (` *` before command type) but protocol output should be exact.
fixed to `sprintf '(%d)'` in all four files.

### verified working

- radio zenka starts, connects to `https://cast.magicstreams.gr/sc/psyndora` via TLS
- `/radio/stream` HTTP endpoint activates and serves audio/mpeg
- `NO_PROXY=127.0.0.1 curl http://127.0.0.1/radio/stream` confirms stream
- `mpv http://127.0.0.1/radio/stream` plays audio
- mpv[audio-0] starts automatically on radio startup, fades in to 70% volume
- STRM cancel on disconnect now works end-to-end

### resilience refactor — COMPLETE (Apr 25 2026, commit `a4154a294`)

all issues fixed via kimi task `radio-resilience`:
1. **reconnect**: exponential backoff 5s→60s (radio.handler.reconnect); guard against double-schedule
2. **gap_fill pacing**: 1s repeating timer; chunk 65KB→16KB (~128kbps) — "stopped suddenly" bug eliminated
3. **mpv offline**: radio.audio.handler.player_offline; v7.notify_offline in audio.init; re-inits after 3s
4. **post-hoc jingle**: tracks under min_track_seconds trigger gap_fill; magicstreams/PsyNdora in filter

### key config

- `radio.stream.url = https://cast.magicstreams.gr/sc/psyndora` (in radio/start, BEFORE [init_modules])
- `radio.stream.auto_connect = yes` (must be before [init_modules] in radio/start)
- `radio.stream.path = /radio/stream`
- `radio.audio.stream_url = http://127.0.0.1/radio/stream`
- `radio.audio.start_volume = 70`
- `radio.jingle.min_track_seconds = 90`

### STRM cancel propagation chain (as fixed)

when HTTP client disconnects:
1. strm_open watcher: `cancel_strm` → writes `($cmd_id)!TERM!\n` to cube session buffer
2. cube !TERM! handler (route found): sets stream_cancelled + writes `(tgt_cmd_id)!TERM!\n` to radio
3. radio: local producer check → sets stream_cancelled → next push: gate returns undef → push=0 → listener removed

when socat/direct client disconnects:
1. cube: `session.check.close` → `cancel_route` → finds streams{M} on target (radio) session
   → writes `(M)!TERM!\n` to radio session buffer + sets stream_cancelled + cleans stale route entry
2. any in-flight chunk from radio → orphan handler → also sends !TERM! (harmless duplicate, stream_cancelled already set)
3. radio: stream_cancelled → push=0 → listener removed

### architecture as implemented

    internet radio (HTTPS/Icecast) via TLS socket
      └─ IO::Socket::SSL → radio.handler.stream-chunk (Event->io)
           └─ ICY metadata parser → radio.filter.jingle
                ├─ gap filler (keep-library 1s timer, 16KB/tick on jingle)
                └─ STRM relay → radio.listeners array
                     └─ cube → httpd STRM consumer (base.strm.local)
                          └─ HTTP session output buffer → curl/mpv HTTP client

    radio.post_init (1s timer) → httpd.radio_online → plugin.httpd.radio.cmd.radio_online
    radio.audio.init (2s timer) → v7.notify_online + v7.start_once mpv[audio-0]
    mpv[audio-0] online → player_online handler → mpv[audio-0].play http://127.0.0.1/radio/stream

### future: buffer-fill curve (phase 5 / post-resilience)

unified delivery rate curve driven by buffer fill level — one curve, no state machine:
- x-axis: buffer fill level (0 = empty → 1.0 = target fill)
- y-axis: delivery rate multiplier
- shape: starts steep (fast burst fill on new connection), flattens asymptotically
  toward 1.0x as buffer saturates, can extend below 1.0x for underrun mitigation
- no burst/steady-state modes, no threshold crossings — curve IS the logic
- on new listener connect: buffer is empty → curve delivers at high rate from
  recorded keep-library material → mpv cache fills before real-time rate kicks in
  → gapless start without separate burst state tracking
- underrun mitigation: if buffer drains (network latency), curve naturally slows
  mpv playback rate slightly (±2% inaudible at psytrance BPM) to preserve frames
  → graceful degradation before reconnect path is needed
- implementation: `base.curve.*` system + periodic timer sampling lc->{'buf'} length
  → mpv[audio-0].set-speed calls
- mpv cache thresholds tuned against curve's target fill level (not arbitrary values)

### phase 4 (mpv twin crossfade) — still pending, confirmed not done (2026-08-01)

use mpv[audio-1] for crossfade on jingle/track transitions. Re-checked
2026-08-01 (user recalled possibly missing it — checked, they hadn't):
only "step 1" of `data/yaml/coding-tasks/radio-phase4-mpv-audio-background.
yaml` ever landed — `mpv.open_player`'s subname regex already accepts
`audio-0`/`audio-1` (confirmed live in code). The actual twin-instance
orchestration and crossfade logic was never written: no `radio.*` module
references `audio-1` anywhere, only `audio-0`. The task file itself
explicitly scoped this out at authoring time ("audio-1 is not used in
this phase (reserved for crossfade in a later extension)") — that later
extension never happened. Dispatcher `L45OX7I` status unverified/unknown.

### shutdown fade + endpoint dedup fixes (2026-08-01, `bac000eef`)

`radio.handler.sig_term` (overrides the generic `base.sig_term` watcher,
mirroring `tile.init_code`'s precedent) now fades `mpv[audio-0]` to
silence on both restart and stop, before chaining to `base.sig_term`'s
normal teardown+exit(0) — live-verified smooth in both cases, no more
abrupt cutoff. First attempt (`radio.end_code`, a plain `<callbacks.
end_code>` callback) segfaulted — see [[feedback-zenka-shutdown-end-code-callback]]
for why that mechanism can't safely pump the event loop. Also fixed:
`plugin.httpd.radio.cmd.radio_online` was re-subscribing to
`v7.notify_offline` on every call with no guard, so repeated restarts
during testing left multiple stale subscriptions that all fired at once
on the next real shutdown (observed as 3 duplicate "endpoint disabled"
log lines) — now guarded to only subscribe once per active period.

This shutdown-fade work is a natural stepping stone toward the phase 4
crossfade above — the fade primitive it reuses (`$instance.fade` via
`protocol-7.route-send`) is exactly what twin-instance crossfading would
need for both instances, just not yet orchestrated between two of them.

### playback resilience phase 2 — landed (2026-08-31, commit `814d0f963`)

Reported symptom: "off when I wake up" — **turned out NOT to be the zenka
or mpv[audio-0] process dying** (user corrected this mid-session after I'd
spent real effort chasing v7 process-supervision/crash-restart forensics
first — see [[feedback-verify-symptom-shape-before-hypothesis]]). The real
symptom was playback silently stalling while both processes stayed online.
Four independent real bugs found and fixed, two dispatched to kimi k2.7
against `data/yaml/coding-tasks/radio-playback-resilience-phase2.yaml` and
`radio-startup-notify-and-backoff-fix.yaml` (kept in-repo as reference):

1. **jingle suppression could get stuck true forever**: `is_jingle` was
   only ever re-evaluated inside the "ICY StreamTitle changed" branch of
   `radio.handler.stream-chunk` — if upstream metadata stalls or repeats,
   nothing ever clears it. While stuck true: real stream relay stays fully
   gated off, mpv stays faded to 0, and if the keep-library was empty,
   `radio.gap_fill.start` silently no-ops with no timer left running to
   ever revisit the flag — total, permanent silence with no self-heal.
   Fixed with a timeout keyed off `track_started`:
   `radio.jingle.max_duration_seconds` (default 45s), checked
   unconditionally on every `stream-chunk` invocation (not gated on
   gap_fill/headers_done state — that was the whole point).
2. **mpv playback health was never tracked, only process presence**:
   `radio.audio.active` only ever reflected v7's `notify_online`/
   `notify_offline` (process up/down) — a silent `end-file` or buffer
   stall while the process stayed alive left it stuck active with zero
   retry. New `radio.audio.watchdog.tick` / `.handler.reply` poll mpv's
   already-observed `core-idle` property (via the pre-existing
   `mpv.cmd.is-idle` command) every 20s, re-issue play after 40s sustained
   idle. **Needed a live cube `access.zenki` grant for
   `mpv[audio-0].is-idle`** under `access.cmd.usr.radio` — this was not
   caught by kimi's static verification (ptd -c) or by my own diff review,
   only by actually running it; see
   [[feedback-narrow-scoped-kimi-task-file-pattern]]'s cross-zenka-access
   addendum.
3. **`httpd.radio_online` silently dropped at startup**: `radio.post_init`
   deferred through `<system.init_reports>`, believed correct (that
   memory file itself listed `radio.post_init` as the canonical
   fire-and-forget example) — but live logs showed "no clients in
   session, dropping 'httpd.radio_online'" happening in production. Root
   cause: `radio.post_init` fires on a 1.0s timer, while
   `<system.init_reports>`'s one-shot flush is timed around the initial
   connect (~t≈0) — the flush can drain an empty queue before post_init's
   item ever gets pushed. Fixed by switching to
   `<system.callbacks.initialized>`, mirroring `lm-vision.init_code`'s
   existing fix for the identical failure class. **Correction to
   [[feedback-init-reports-one-shot-flush]]**: that file's own worked
   example was itself later proven wrong by live log evidence — don't
   trust "this looks like the fire-and-forget case" without checking
   actual delay-vs-flush-timing race potential.
4. **reconnect exponential backoff defeated by a flapping connection**:
   `radio.connect` reset `reconnect_delay` to 5s immediately on raw
   TCP/TLS accept, before the stream was confirmed to actually be serving
   data — so a server that accepts-then-immediately-drops never let the
   backoff accumulate (5→10→20→38→77), hammering the upstream every 5s
   instead. Moved the reset to fire only once ICY headers finish parsing
   in `radio.handler.stream-chunk` (`headers_done=1`), a real signal the
   connection is genuinely serving stream data.

Live-verified stable afterward (user's own words: "playback is working in
the background, no errors").

#,,..,,,,,,.,,,.,,.,.,.,.,,,,,,.,,.,.,,,.,,,,,..,,...,...,...,,,.,,.,,...,,,,,
#7BKGLPFZ2NDWFNIZ4TSJ7WEM2CICOVHNSDXDEBXQJR4EEJNQY4RBNHLDL5ZCROLDTZRYMM2LZW2AS
#\\\|UDMUR3SX7AZUXABNNDAVFCN74WOLXTCDBKRE3SHRF44ZB2XVOTX \ / AMOS7 \ YOURUM ::
#\[7]BSQUROXPDOFFWQCVQ7DWUHUSO63C2EDFS4DGN6N26XOJOCN43IBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
