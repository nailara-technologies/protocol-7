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

### phase 4 (mpv twin crossfade) — pending

use mpv[audio-1] for crossfade on jingle/track transitions. task file:
`data/yaml/coding-tasks/radio-phase4-mpv-audio-background.yaml` (already complete)
dispatcher: kimi task `L45OX7I` (verify status first).

#,,,,,.,,,.,.,.,.,,,.,.,.,,,.,,,,,,,.,,,,,,..,..,,...,...,.,,,...,,..,.,,,..,,
#IBPGCBFQDE65C5FK4ZUH6YVEXD6ISSDE7U3CRSMFGRLFWE77RNXE2JGJY4YXX6OAGURVWKQHGVLKO
#\\\|5OO4DW4BJGZQPVC65XDRJQ4TZIFIHGWFNDM2IVD7J2ZOSLOZ3CU \ / AMOS7 \ YOURUM ::
#\[7]J3OXOP3A6HT2YK5NIWEZFTLPY4TDTGCZV3IOOEBJZHCYBYWH5UDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
