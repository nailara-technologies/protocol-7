---
name: base.cmd.cancel-stream design [ sender-side stream abort ]
description: command-layer stream-abort design agreed 2026-04-19, pending implementation; preferred over off-band !CANCEL! for simplicity + ack semantics
type: project
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## motivation

cube logs `SIZE-reply to unknown route id [N]` when target session closed
before sender finished emitting a reply. sender keeps emitting chunks into
a drop path at cube → web zenka blocked in emission → v7 heartbeat
timeout → SIGTERM + restart.

Need: receiver-side cube tells sender "stop this stream" and gets an ack.

**Why:** off-band `!CANCEL!` would need parser work + mid-frame excise
rules + no ack. A plain P7 command is simpler, reuses existing plumbing,
gives TRUE/FALSE confirmation, stays within frame-atomicity.

**How to apply:** next time the orphan-route log spam / web-SIGTERM
pattern recurs, this is the fix path — implement the command first, then
wire cube trigger.

## the command

    base.cmd.cancel-stream <cmd_id>

- **cmd_id required** [ not optional ]. Without it sender cannot identify
  which stream; multi-cube multiplexing means several sequential streams
  share a route — wrong one would get axed.
- Returns `TRUE stream cancelled` or `FALSE no active stream transfer`.
- Generic `base.cmd.*` — any zenka implementing streams can honour it.
  Cube is one sender, but so is any zenka returning SIZE/STRM-SIZE.

## sender-side state [ what gets cancelled ]

1. **route entry** — deleted. Critical for STRM because routes stay open
   across multiple STRM packets [ unlike TRUE/SIZE which auto-delete on
   one complete frame ].
2. **`$session->{'streams'}{$cmd_id}`** — the per-stream accumulator/
   dispatch state [ base.handler.command:715-722 for STRM, ~849 for
   STRM-SIZE ].
3. **pending-reply flag** on deferred commands — if handler hasn't
   produced its reply dict yet, set cancelled flag ; the eventual reply
   is discarded instead of appended.
4. **output buffer excise** — for already-emitted but not-yet-drained
   SIZE/STRM-SIZE frames belonging to this cmd_id. Use recorded byte
   offsets, **do not re-parse** the buffer.

## stream registry [ new sender-side structure ]

    $session->{'outbound_stream'}{$cmd_id} = {
        state      => 'pending' | 'buffered' | 'flushed',
        byte_start => $offset_in_output_buffer,
        byte_len   => $total_frame_bytes,
    };

Updated at:
- deferred accept → state pending
- emission call → state buffered, record byte_start = length(output_buf)
  before append, byte_len = bytes::length(appended)
- write-watcher drain past byte_start+byte_len → state flushed, delete

cancel-stream consults registry to pick branch:
- pending  → set cancel flag, delete entry, TRUE
- buffered → substr-excise output buffer [ byte_start, byte_len ], TRUE
- flushed / absent → FALSE

## safety invariants

- **complete-packet strip is always safe** [ user 2026-04-19 ]: next hop
  doesn't know about packets still in sender's buffer, cannot desync on
  their disappearance.
- **never mid-frame strip**: emission is synchronous
  [ base.handler.command:1465-1483 ] so open+chunks+close land as one
  contiguous block ; trusting recorded byte_start/byte_len is safe. If
  that loop ever becomes event-driven per chunk, registry must record a
  list of (offset,len) per emitted chunk, or registry-aware emission
  must suppress remaining chunks.
- **ack ordering**: write TRUE/FALSE reply *after* excise so ack always
  lands on the wire strictly after any non-cancelled predecessor bytes.

## pass-plan

1. **pass 1** — base.cmd.cancel-stream command + sender-side stream
   registry + excise/flag logic. Testable manually via p7c.
2. **pass 2** — cube-side trigger: on `SIZE-reply to unknown route id`
   [ and STRM/STRM-SIZE equivalents ], send cancel-stream to the source
   session [ deduped per cmd_id ]. On route teardown from session close,
   proactively cancel-stream each in-flight route through that session
   before deleting it.

## test client role-extension

`bin/test-strm-size-client.pl` already has the auth + framing machinery.
Extend to play **both** roles in a routing-case test:
- connection A : source client, issues the cube→target command
- connection B : target-side client, receives the reply stream
- single process, two sockets [ or forked ]
- close B mid-stream → exercise orphan-route path → verify cube issues
  cancel-stream to A's sender → verify A's registry transitions to
  cancelled → verify no SIGTERM cascade on surrounding zenki

## known open question

`base.cmd.*` vs `cube.cmd.*` namespace — leaning `base.cmd.cancel-stream`
so any zenka with streams can implement it consistently. Cube gets its
own implementation that knows about its routing-side streams table.

#,,,,,..,,..,,,.,,,..,,,.,.,.,,,,,,,.,,,,,,,,,..,,...,...,.,,,..,,..,,,,,,,,.,
#MZCNHTNCPPEI6IKIHKAEU7WZAFFJ3QKN7JRIPDEPH44ORYZIR7QDPRWEMQR4O5TVFNPDTH733YUXA
#\\\|HDQJTJKQ6DGDLRXKXWIVRONGTMDWY3XOEO3EWYBXDNLGVYGX7XC \ / AMOS7 \ YOURUM ::
#\[7]JAUSXB5IOWTMFWYCWCOTEZEVLTHKO4W7M6O7PNBPGRWLG7KWIGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
