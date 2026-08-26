---
name: topic-strm-write-blocking
description: Root cause and fix for p7c/nshell blocking on large STRM-SIZE streams (>212KB)
type: project
originSessionId: 2b441c09-69f0-4ec5-b59b-2135110f8363
---
## STRM-SIZE Large-Stream Write Blocking — RESOLVED 2026-05-07

### Root cause
`base.handler.write` uses a var watcher on `$session->{'buffer'}->{'output'}`.
When syswrite returns 0 (EAGAIN / kernel socket buffer full), the code immediately
restarted the var watcher (`$event->w->start`). The var watcher fires on WRITES to
the output buffer — so it works while coding zenka is still delivering STRM-SIZE
chunks. But once the last chunk arrives, nothing else writes to the buffer, the
watcher just waits, and the remaining ~117KB sits frozen. p7c/nshell block.

Socat works because it reads fast enough that EAGAIN rarely occurs; also verified
with the older 419331-byte big-utf8 buffer where timing was different.

### Observation
Buffer = 8000 lines × 41.3 bytes = 330400 bytes. Kernel socket buffer = 212992 bytes.
After writing 212992 bytes via syswrite, EAGAIN. Remaining 117420 bytes stuck forever
once coding zenka's STRM-SIZE stream completes (no more writes to trigger the watcher).
User observed nshell/p7c stall at test-line-06240.

### Fix (base.handler.write)
Track `$hit_eagain` flag in the write loop. When EAGAIN: do NOT call `$event->w->start`.
This leaves the watcher stopped, so `event.io_idle_restart` fires (line 121-124 condition
`not $event->w->is_active` is now TRUE). The idle mechanism calls `->now` to retry on
the next idle cycle until the socket drains.

### Secondary fix (base.session.cancel_route)
When the client session disconnects mid-stream, STRM-SIZE stream state on the coding
zenka session was not cleaned up — blocked_by_stream remained set, timers ran for 12s.
Fix: in cancel_route, after deleting the target route entry, cancel timers, clear
blocked_by_stream, and delete the stream state immediately.

**Why:** base.handler.write is called from the output_buffer var watcher.
The input_buffer watcher is stopped in base.handler.command (line 114) to prevent
re-triggering during buffer modification. The output_buffer watcher is separate and
only stopped within base.handler.write itself.

#,,.,,,.,,.,,,.,,,.,,,..,,.,.,.,.,..,,,,,,,..,..,,...,...,...,..,,,,,,,,,,.,.,
#7QS7HTEGJ5Q2DXSHEEMV3NOZ7L6KMHJKCRTWB4JLQPRSLPP6Y6I6O6AFJD4PGVRFYU5MN5LFYHAMU
#\\\|PUZTEPJU3LXALOCKKUT6JDGR6O3PIRNQ5UPPJWTALKX4A633SLD \ / AMOS7 \ YOURUM ::
#\[7]KCOCAYWHJAYPSCMUBGENUNJOEFQSSSYYKYBAIIE5ZIMHXUANJ6BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
