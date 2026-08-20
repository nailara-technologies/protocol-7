---
name: reference-wslg-pulseaudio-bridge-check-before-mpv-debug
description: when mpv playback silently stays idle in this WSL environment, check the WSLg PulseAudio bridge (pactl info) before deep-diving into Protocol-7 routing/STRM code
metadata:
  type: reference
---

Symptom: `mpv.play <url>` returns "submitted for playback", `mpv.is-idle` stays `yes`,
and nothing obviously errors in Protocol-7's own logs at a glance. mpv's own event log
(`<zenka>.show-buffer zenka <n>` on the mpv zenka) shows it actually connecting and
loading the file fine (`file-loaded`, `playback-restart`, `audio-reconfig` events all
fire normally), then immediately:

```
"event":"end-file","reason":"error","file_error":"audio output initialization failed"
```

This is the WSLg PulseAudio bridge (`unix:/mnt/wslg/PulseServer`, per commit `89ff0cd31`)
having no server process behind it — `pactl info` returns `Connection refused` even
though the socket file still exists on disk (a stale/orphaned socket, not a missing one).
No amount of Protocol-7-side fixing helps; it needs the WSLg audio bridge restarted,
which is a Windows-host-side action (`wsl --shutdown` + reopen from PowerShell, or killing
a hung WSLg audio-relay process in Task Manager first to let it respawn without a full
restart).

**Why:** an hour-plus radio-zenka streaming investigation chased cube's STRM/TRM routing
tables as the suspected cause (plausible-looking `!TRM!`/"unknown route id"/"orphaned
STRM" log lines correlated with failed playback attempts) before checking mpv's own event
log or `pactl info` directly. The routing layer turned out to be healthy the whole time
(confirmed via a clean multi-KB sustained curl pull with no routing errors); the actual
cause was one specific mpv IPC event that a generic Protocol-7 log line ("event 'end-file'
received ( no handler )") had no visibility into.

**How to apply:** when mpv silently fails to play in this environment (idle after
"submitted for playback", no video/audio, no obvious Protocol-7-side error), check in this
order before spending time in Protocol-7's routing/STRM code: (1) mpv zenka's own event
log for `end-file`/`file_error`, (2) `pactl info` against the WSLg bridge. Only pursue
Protocol-7-side routing bugs once those two are ruled out. See also
[[feedback-bash-tool-http-proxy-contaminates-localhost-curl]] — a separate false trail
from the same session, caused by a misconfigured curl test rather than a real bug.

Follow-up landed same session: `src/mpv.handler.event.end-file` now logs any
`end-file` `reason:error` at level 0 (was silently falling through to the generic
level-2 "no handler" catch-all in `mpv.handler.event`) when the instance is audio-only
(`<mpv.audio_only>`, e.g. radio's `mpv[audio-0]`) — playback IS the entire intent there,
so any end-file error is total failure and should never be buried again.

#,,,.,...,...,.,.,...,.,,,.,.,,,,,.,.,.,,,,,.,..,,...,...,.,,,...,,,.,,..,,..,
#7BEZVOAOC4EUBTMR4QX2HKCHUPBKJ6JTQJ7TKGVH23TIYC7DYAMU3QAYOCRAWBBQJ6AXQVEI42DLK
#\\\|JVVPUO2ZFIXGZXHMLQ4GJRR5YF2EUIFOWPPE5HEOEBCOA6RBSG4 \ / AMOS7 \ YOURUM ::
#\[7]TOO6WWWIVNYML5Q5CHLDJYSQ3ZUK5PKXNEGOD52NEYPDZDQYPGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
