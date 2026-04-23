---
name: psytrance radio relay zenka
description: jingle-filtering radio relay with keep-library, stream-ripper mode, STRM output to httpd, mpv playback; first real unbounded STRM consumer
type: project
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## vision

a relay zenka that pulls a psytrance internet radio stream, strips
jingles in real-time, and re-serves the filtered audio locally via
httpd → mpv. jingles detected by ICY metadata title matching and/or
track length below threshold. during jingle: substitute from keep
library or loop last N seconds of previous track. when no listener:
stream-ripper mode accumulates tracks up to configurable pre-saturation
cap. "to-keep" tagged files fill jingle gaps and are replaced by better
(longer / higher quality) versions if streamed later.

**Why:** jingle interruptions break mental rhythm; every non-jingle
minute has positive value; filtering cost is low.

**Future expansion:** self-mixing relay (BPM-aware crossfader replaces
gap filler), generative psytrance source, P7-native distributed streams
(nodes relay to each other instead of pulling from central broadcast).

## architecture

    internet radio (HTTP/Icecast)
      └─ pipe-open curl → radio.handler.stream-chunk
           └─ ICY metadata parser → radio.filter.jingle
                └─ gap filler (keep-library / loop-back)
                     └─ STRM relay → httpd local endpoint
                          └─ mpv zenka (audio mode)

## jingle detection

- **ICY metadata** — Icecast/Shoutcast embeds StreamTitle at configurable
  byte intervals; near-realtime track title available without audio analysis
- **title pattern match** — station name, "ID", "jingle", promo keywords
- **length heuristic** — track < N seconds (configurable threshold, e.g. 90s)
  catches untagged jingles; requires buffering one track before deciding

## internal stream structure — multi-stream from the start

streams indexed by stream_id so the interface is multi-stream capable
without redesign. each stream slot carries independent state:

    radio.streams = {
      $stream_id => {
        url           => $source_url,
        role          => 'primary' | 'background' | 'keep-library',
        buffer        => ...,       ## rolling audio buffer
        current_track => { title, length, started_at },
        listener_count => N,
        saturation    => { used => N, cap => M },
      }
    }

**background saturation source:** a secondary stream of genre-similar
content that runs continuously alongside the primary. eliminates
pre-buffering delay entirely — when a jingle is detected the gap-filler
cuts to already-buffered background material immediately, making skip
and filter available from the first moment of playback. the background
source can be a second radio URL, a keep-library rotation, or a future
P7-native stream from another node.

## gap filler priority (simplest first)

1. background saturation source buffer [ already running, zero delay ]
2. keep library (pre-loaded track)
3. fallback: loop last N seconds of previous track
4. future: BPM-aware crossfade / generative fill

**Why background source first:** options 2 and 3 require either disk I/O
or a backward-seek buffer; option 1 is already in memory and gapless.

## stream-ripper mode

- active when listener count = 0
- saves complete tracks (not jingles) to disk
- pre-saturation cap: configurable max total size
- "to-keep" flag: marked tracks excluded from saturation cap
- replacement rule: if a better version (longer / higher bitrate) of a
  kept track arrives, replace it silently

## module outline

- `radio.init_code` — init stream table, connect primary + background sources
- `radio.cmd.start` / `radio.cmd.stop` — playback control
- `radio.cmd.status` — current track, listener count, keep-library size
- `radio.cmd.skip` — immediately trigger gap-filler for current track
- `radio.cmd.keep` — flag current track as to-keep (excluded from saturation cap)
- `radio.cmd.add-stream` / `radio.cmd.remove-stream` — manage stream slots
- `radio.handler.stream-chunk` — read pipe per stream_id, parse ICY, buffer
- `radio.filter.jingle` — title + length detection, per stream_id
- `radio.handler.gap-fill` — cut to background source or keep-library
- `radio.ripper` — save tracks in idle mode, per stream_id saturation cap
- `radio.menu` — protocol-7-menu provider: start, stop, skip track, keep track

## relation to STRM infrastructure

this is the **primary motivating use case for unbounded STRM**:
- relay output is continuous, no declared total
- requires `follow => 1` mode in transport.register
- base.stream-file (bounded) tests transport layer first; radio relay
  tests unbounded extension immediately after

## implementation sequence dependency

1. STRM mode fix in base.handler.command [ prerequisite ]
2. unbounded STRM protocol extension [ total=0 allowed ]
3. base.stream.transport.register [ transport layer ]
4. base.stream-file [ bounded integration test ]
5. base.curve.* — generic curve evaluator + compose in base namespace
   mpv.param.curve becomes a thin wrapper wiring callback to set_property
6. radio relay zenka [ unbounded integration + real consumer ]
   uses two mpv instances + mpv.param.curve for crossfade

## crossfade engine — two parallel mpv zenki

two mpv instances (mpv-A, mpv-B) handle playback. gap-fill is a
coordinated handoff: pre-load next track on idle instance, then
simultaneously fade volume A→0 / B→full via the generic parameter
curve routine. no custom DSP or audio processing required — mpv
handles everything via JSON IPC.

    mpv.param.curve {
        player   => $mpv_id,        ## 'A' | 'B'
        param    => 'volume'        ## or speed, hue, contrast,
                  | 'speed'        ##    gamma, brightness, zoom, ...
                  | 'hue' | ...,
        from     => $start_val,
        to       => $end_val,
        duration => $seconds,
        curve    => 'linear' | 'ease-in' | 'ease-out' | 'ease-in-out',
    }

this is a direct generalization of the existing volume fade: same
JSON IPC call pattern, same timer-driven value steps, same mpv socket
interface — just parameterized. cost: ~20 lines to extract and abstract.
all other parameters (video, visual, speed) follow for free.

**BPM-aware mixing (future, no immediate resampling needed):**
when BPM metadata is available (from tags or offline analysis), the
speed ramp runs alongside the volume crossfade — current track slows
to target BPM, incoming track speeds up from its BPM to match, then
cross-fades. this is exactly the DJ pitch/tempo transition. mpv's
`speed` property handles the ramp; mpv.param.curve handles the curve.
no pitch correction needed for the basic version (slight pitch drift
is acceptable and authentic); pitch-preserving resampling can be
added later as an mpv filter if wanted.

## minimal useful interface

start / stop / skip / keep — these four menu entries are the complete
minimal interface. skip and keep close the feedback loop: skip triggers
the gap-filler immediately (extends jingle detection beyond automatic
rules); keep builds the library that fills those gaps. both map directly
to commands that must exist anyway — no extra logic required.

**How to apply:** when starting radio relay implementation, check that
steps 1-3 are complete. the zenka itself is not complex — the transport
layer does the heavy lifting.

#,,..,,,,,.,,,...,..,,,,.,...,,,.,,,,,,.,,.,,,..,,...,...,.,.,...,,.,,,,,,.,.,
#6HSRG7P7QUWZTIMWG46FAMORCRCZ6EZ2RILFGBOJZQATOVDFUM3SPIXDXK2OUKZZZIAAKUZX7YOFY
#\\\|WHYNCKVBGQZSGM6I6ZYBQLDVUWUNFKHYWWF6F5GH3DE4UFBWXMX \ / AMOS7 \ YOURUM ::
#\[7]FXCFXSS4ECW2M4MC5H3V4Q47VJ3DSXYFXPZNEIO5OJUTDCGTTADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
