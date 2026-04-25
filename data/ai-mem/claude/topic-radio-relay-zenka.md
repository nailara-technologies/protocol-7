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

### remaining issues / next task (kimi task file written)

see: `data/yaml/coding-tasks/radio-resilience.yaml`

1. **no reconnect on ICY stream drop** — `stream-chunk` closes socket + cancels watcher
   on EOF/error but schedules nothing. radio sits silent forever after any network hiccup.
   need reconnect timer with backoff (5s → 15s → 30s → 60s cap).

2. **gap_fill idle watcher causes buffer overflow** — `Event->idle(repeat=>1)` in
   `radio.gap_fill.start` runs as fast as the event loop allows, pushing 65KB chunks
   with no rate limiting. fills STRM buffer (lc->{'buf'}) faster than mpv drains it.
   when buffer exceeds 4MB overflow threshold in strm_open watcher, mpv listener is
   cancelled → playback stops. THIS IS THE "STOPPED SUDDENLY" BUG.
   fix: replace idle watcher with a repeating timer at audio bitrate rate
   (e.g., 100ms interval reading ~16KB chunks for ~128kbps streams).

3. **mpv state not tracked** — `radio.audio.active` set to 1 in player_online but
   never cleared. if mpv crashes/restarts, radio sends fade/volume commands into void.
   fix: new `radio.audio.handler.player_offline` module, register with `v7.notify_offline`
   in `radio.audio.init`, clears `radio.audio.active` and re-queues `radio.audio.init`.

4. **jingle filter only pattern-based** — `radio.filter.jingle` matches title patterns
   but duration heuristic (`< min_track_seconds`) is computed and logged but never feeds
   `gap_fill`. short tracks not matching patterns play through.
   improvement: use post-hoc duration to inform gap_fill retroactively on confirmed
   short tracks, or add duration-based confidence scoring.

5. **fade timing issues** — sometimes inverted, fades during silence, fades in remaining
   jingle tail. these are downstream of gap_fill timing being wrong (#2) and jingle
   detection boundaries being off (#4). will naturally improve once #2 and #4 are fixed.
   no need to tune fade logic independently.

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
                ├─ gap filler (keep-library idle watcher on jingle) ← NEEDS TIMER FIX
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

#,,,,,..,,,.,,..,,..,,,..,.,.,.,,,,,,,.,,,,..,..,,...,..,,...,...,,,,,.,.,...,
#6PCUT7HTRQ5IIUOBY4J2QX5FDZB65SS2QB7IJDFFJACQ3W74MB733QY7FHHC6Q7W4TFLT35ZGPTZ4
#\\\|DKRQRAKZ47P7Z4HUSD22GRP3OFSCWB4TUJWXFO5R56FKGUMYSMC \ / AMOS7 \ YOURUM ::
#\[7]GKS7U47MWMAN7F5WLVIBWV6S3W4ATML5JTIMZZNWXDSJQFE44KCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
