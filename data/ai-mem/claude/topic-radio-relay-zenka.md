---
name: psytrance radio relay zenka
description: jingle-filtering radio relay with keep-library, stream-ripper mode, STRM output to httpd, mpv playback; first real unbounded STRM consumer
type: project
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## current status (2026-04-24)

### completed (all committed to branch `base`)

- **phase 1**: ICY stream reader + unbounded STRM relay (radio.cmd.listen)
- **phase 2**: jingle detection + skip/keep commands
- **phase 3**: keep-library accumulation + gap filler (idle watcher)
- **base**: local STRM consumer primitive (base.strm.local.register/cancel/consume)
- **base**: recv-test dev tool (base.strm.callback.recv_test)
- **httpd bridge**: plugin.httpd.radio.* — /radio/stream HTTP endpoint, per-client radio.listen
- **TCP rewrite**: radio.connect uses base.open ip.tcp output + TLS (IO::Socket::SSL) for HTTPS
- **phase 4**: mpv[audio-0] background player via v7.start_once + v7.notify_online

### verified working

- radio zenka starts, connects to `https://cast.magicstreams.gr/sc/psyndora` via TLS
- `/radio/stream` HTTP endpoint activates and serves audio/mpeg
- `NO_PROXY=127.0.0.1 curl http://127.0.0.1/radio/stream` confirms stream
- `mpv http://127.0.0.1/radio/stream` plays audio
- mpv[audio-0] starts automatically on radio startup, fades in to 70% volume
- audio playing with fade-in working

### remaining issues

1. **STRM cancel on disconnect**: when HTTP client (curl/mpv) disconnects, radio keeps
   pushing. !TERM! propagation chain: cube → httpd → radio. Fixes committed but NOT yet
   verified working. test with `mod-test.strm-open` (unbounded STRM) + socat disconnect.
   expected: mod-test strm-tick logs "gated off" after disconnect.

2. **session-close stream teardown**: when any session disconnects, active `$session->{'streams'}`
   entries are NOT cleaned up. producers keep pushing until !TERM! arrives via data path.
   proper fix: in `base.session.check.close`, iterate `$session->{'streams'}`, send !TERM! to
   each producer. **not yet implemented.**

3. **jingle detection**: jingle filter exists (`radio.filter.jingle`) but not filtering correctly
   in practice — jingles are playing through. needs live stream testing + regex tuning.

4. **mpv show_playlist blocking**: after radio STRM is active, mpv show_playlist SIZE replies
   stop arriving. suspected STRM state interference. investigate after cancel bug is fixed.

5. **kimi auto-approve regression**: task `BHHXHDQ` dispatched.

### key config

- `radio.stream.url = https://cast.magicstreams.gr/sc/psyndora` (in radio/start, BEFORE [init_modules])
- `radio.stream.auto_connect = yes` (must be before [init_modules] in radio/start)
- `radio.stream.path = /radio/stream`
- `radio.audio.stream_url = http://127.0.0.1/radio/stream`
- `radio.audio.start_volume = 70`
- `radio.jingle.min_track_seconds = 90`

### STRM cancel propagation chain

when HTTP client disconnects:
1. strm_open watcher: `cancel_strm` → sends `($cmd_id)!TERM!` to cube
2. cube !TERM! handler (route found): sets stream_cancelled + sends `(tgt_cmd_id)!TERM!` to radio
3. radio: local producer → sets stream_cancelled → base.stream.gate returns undef → push=0 → listener removed

when socat/direct client disconnects:
1. cube: source session gone, STRM data from radio → forward-to-source path: source not found
   → sends `(tgt_cmd_id)!TERM!` to radio (new else branch in base.handler.command)
2. radio: local producer → stream_cancelled → push=0

### architecture as implemented

    internet radio (HTTPS/Icecast) via TLS socket
      └─ IO::Socket::SSL → radio.handler.stream-chunk (Event->io)
           └─ ICY metadata parser → radio.filter.jingle
                ├─ gap filler (keep-library idle watcher on jingle)
                └─ STRM relay → radio.listeners array
                     └─ cube → httpd STRM consumer (base.strm.local)
                          └─ HTTP session output buffer → curl/mpv HTTP client

    radio.post_init (1s timer) → httpd.radio_online → plugin.httpd.radio.cmd.radio_online
    radio.audio.init (2s timer) → v7.notify_online + v7.start_once mpv[audio-0]
    mpv[audio-0] online → player_online handler → mpv[audio-0].play http://127.0.0.1/radio/stream

### phase 4 (mpv twin crossfade) — pending

use mpv[audio-1] for crossfade on jingle/track transitions. task file:
`data/yaml/coding-tasks/radio-phase4-mpv-audio-background.yaml` (already complete)
dispatcher: kimi task `L45OX7I` (verify status first).

#,,,,,,.,,,..,.,.,,.,,,,,,..,,,,,,,.,,.,.,,..,..,,...,...,,..,..,,,,.,...,.,,,
#JT65T5SHS5ZGNXD2GGQ7TLQRXW2OCXVBARAWF4FUZMQD2U3YJZ6OLJ2EEUB2CY3BRX2Z6TPVRTVUA
#\\\|BEGESAMYSORRLQCYAUPLOQFHGMQKE45CWV23LU5YLBGRIC2JXN4 \ / AMOS7 \ YOURUM ::
#\[7]76AV7X4LRQRLQJDRG56V5JHSC2GO2MY6UMELPRSMWEZOE7YO2KAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
