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

## current state [ 2026-04-25 ]

### completed
- **STRM cancel infrastructure**: passes 1-3 complete (`01b6be26e`);
  session-close proactive teardown still deferred (open item)
- **unbounded STRM**: working in practice — radio relay proves producer-driven
  close with no pre-declared total. formal `open 0` sentinel not yet in protocol
  spec but the stack handles it correctly for the relay case.
- **base.stream-file**: implemented (`61688a279`) — idle-driven bounded file
  streaming over STRM; exercises the full stack end-to-end.
- **radio as first real consumer**: full STRM pipeline verified end-to-end
  (ICY relay → STRM → httpd → curl/mpv) with cancel propagation working.

### remaining

**unbounded STRM protocol extension** — formal `open 0` / `open ?` sentinel;
relax the `total > 0` assertion in base.stream.open; skip `received == total`
check on close. spin a task when webcam/log-tail becomes concrete — not blocking
anything currently.

**transport.register** — extract from radio.gap_fill + base.stream-file once a
second consumer appears with similar idle/timer loop patterns. premature now.

**webcam / log-tail relay** — depends on unbounded formal extension.

**How to apply:** next STRM consumer is the trigger to extract transport.register.
unbounded extension needed for any open-ended feed (no known total at open time).

#,,..,,,.,...,,,,,.,.,..,,,.,,..,,.,.,...,...,..,,...,...,..,,,.,,...,..,,,.,,
#4N5EGWZJG5BOROI5DT6DNLYGAS25KW7IV63APN5ABZSXNMO35LOXNJTOZ2EY24JIJVCGFTFDE3ZIW
#\\\|2OINBF5NU573CVUY3COF54V44IBXK6Z66KPBNCQRIISHHXMKEOY \ / AMOS7 \ YOURUM ::
#\[7]RNF5L4FBO3Y4XP2QTRISYU4NRR55NBI2XE3YOQ3VOU6NHXDQ6ABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
