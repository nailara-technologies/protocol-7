---
name: event-driven stream transport layer
description: generic event-loop-driven STRM/STRM-SIZE transport routines above base.stream primitives; scalar and filehandle sources; replaces sync buffer-dump in base.handler.command
type: project
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## motivation

current STRM-SIZE in base.handler.command dumps all frames synchronously
onto the client output buffer in one go — 'cramped', blocks the event loop
for large payloads, and requires callers to know session buffer internals.
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

## current state

base.stream.{open,push,close,gate,emit} are implemented and working
[ 2026-04-20 session ]. transport registration layer not yet started.
STRM-SIZE in base.handler.command still uses sync dump; refactor deferred
until transport layer lands.

**How to apply:** when next touching STRM-SIZE fragmentation or adding
file/audio streaming, implement transport.register first; then migrate
base.handler.command STRM-SIZE branch to use it.

#,,..,,,.,.,.,.,,,,,.,...,,,.,...,,.,,,.,,,,.,..,,...,...,.,.,,,.,.,.,..,,,..,
#BL7XBTOXA7LRKLXYWYMZSPGU66C4MYXEAF2FRNMJXM7GCPHYAVG27K5SCNHKWMPKUUR6IXSHTTM62
#\\\|2USVC3PEA3LMDBN7AFQJFXDJ5FZ4C2PDYMFFDA4KS5T7SI56V65 \ / AMOS7 \ YOURUM ::
#\[7]TOGCS2ZLMRY46YTU5SM3CUHKIFCP6C6SXA53MEBNOW7T26JBG6BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
