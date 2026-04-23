---
name: event-driven stream transport layer
description: generic event-loop-driven STRM/STRM-SIZE transport routines above base.stream primitives; scalar and filehandle sources; replaces sync buffer-dump in base.handler.command
type: project
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## motivation

current STRM-SIZE in base.handler.command dumps all frames synchronously
onto the client output buffer in one go — blocks the event loop for large
payloads, requires callers to know session buffer internals.
base.stream.{open,push,close} are correct primitives but still require
direct buffer access knowledge for anything beyond the simplest producer.

**Why:** STRM modes are experimental and direct-buffer writes are too
error-prone for wide usage. A transport registration layer hides protocol
framing and pacing behind a simple source description.

## proposed API

    base.stream.transport.register( {
        sid      => $sid,
        cmd_id   => $cmd_id,
        type     => 'STRM' | 'STRM-SIZE',
        source   => \$scalar | $fh,
        offset   => $start,          ## default 0
        length   => $bytes,          ## default = full content at reg time
        strip    => 1 | 0,           ## scalar: strip sent bytes (default 1)
        follow   => 1 | 0,           ## fh: keep reading appended content
    } )

event loop drives framing + pacing; on each tick pushes one chunk via
base.stream.push; stops on gate-fail (!TERM! / cancel) or end-of-source;
emits STRM close automatically.

## source modes

- **scalar range** — slices `$offset .. $offset+$length` from scalar ref;
  default strips sent bytes from front [ convenient for queue-style buffers ]
- **filehandle range** — reads from fh; default = bytes available at
  registration; `follow => 1` keeps reading as data is appended [ audio
  relay, webcam frames, log tail ]

## relation to unbounded-gap

filehandle + `follow => 1` resolves the unbounded-gap problem naturally:
no pre-declared total needed; event loop emits close only when producer
signals end [ or !TERM! arrives ]; total in STRM open frame sent as 0 or
omitted [ pending protocol extension ].

## layer diagram

    caller
      └─ base.stream.transport.register   ← new high-level API
           └─ base.stream.{open,push,close}  ← existing primitives
                └─ base.stream.gate          ← liveness / cancel check
                     └─ session output buffer

## current state [ 2026-04-23 ]

stream cancel infrastructure complete (passes 1-3, session-close
teardown, implicit !TERM! lookup, relay upstream propagation).
transport registration layer not yet started.
STRM-SIZE in base.handler.command still uses sync dump.

## next implementation sequence

### step 1 : STRM mode fix (prerequisite)

current base.handler.command treats STRM type same as STRM-SIZE
(sync fragment-and-close with deferred route). original semantics:
STRM open → route stays open → producer pushes chunks async →
STRM close signals end. fix: when mode=STRM, keep route open after
open frame and let producer drive close; do not use deferred-and-dump.

### step 2 : unbounded STRM protocol extension

current base.stream.open requires total > 0. for follow mode
(audio, log tail), total is unknown at open time. extend protocol:
total=0 in STRM open frame means unbounded; receiver buffers until
STRM close arrives. base.stream.open guard needs relaxing for type=STRM.

### step 3 : transport.register implementation

implement the API above; wire a timer-driven push loop per registration;
handle gate-fail (stop + optionally !TERM! if upstream set).

### step 4 : first real consumer — base.stream-file command

command: `base.stream-file <path> [offset] [length]`
streams a file to the caller over STRM; uses transport.register with
filehandle source. replaces the sync STRM-SIZE dump for file content.
this is the concrete motivating use case: bounded (size known), immediately
useful, exercises the full stack without needing unbounded extension.

**Why file-first:** bounded → no unbounded extension dependency; large
file transfers currently block the event loop; clean testable end result.

**How to apply:** implement steps 1-4 in sequence; test with
`base.stream-file` as the integration target. audio/log-tail/webcam
relay follow naturally once unbounded extension lands.

#,,.,,,.,,,,.,.,.,.,,,,..,..,,.,.,...,,..,...,..,,...,..,,...,,,.,.,,,..,,,..,
#4DZVLIG75MKZCABQESZ7YKRCBY7G7F5SLYGTUUNENGOUIDP7QRS5L6TCID5K6KOXZQW2O6XTUPMNG
#\\\|WTLJ2U77O3JOBRQ3ARFCZB4QG4CKJLODPUHDUQ3ODQYU6W7RJ6S \ / AMOS7 \ YOURUM ::
#\[7]NJEAGMLKHHMB55CGOWH5RU5P6C5DIRSQPIIHIPBXUMTITQ6PJYCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
