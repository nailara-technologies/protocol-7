---
name: cube-socket pause starves all routed traffic on buffer-full
description: base.handler.read pauses input on buffer-full; on a cube-multiplexer socket this starves heartbeats and every other destination's commands — leading to v7 SIGTERM
type: feedback
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## the bug

`base.handler.read:116-122` pauses the input watcher whenever the
session input buffer hits capacity (`$size_left == 0`). For a direct
peer this is correct backpressure. For the **cube socket** — the
single multiplexer carrying commands for every destination a zenka
talks to — it is catastrophic.

Concrete failure mode [ 2026-04-18 ]:

1. web zenka emits a ~1 MB SIZE reply destined for httpd via cube
2. cube routes it as SIZE [ not STRM-SIZE ] because httpd↔cube
   session has not declared `strm_size_support` — cube works as
   configured and cannot auto-promote
3. httpd's cube-input buffer fills before the SIZE frame completes
4. `base.handler.read` pauses the cube socket
5. v7 heartbeat pings to httpd route via cube — they queue behind the
   paused read
6. heartbeat timeout fires, v7 SIGTERMs httpd, zenka restart

The zenka that gets killed is not the one producing the big payload —
it's whichever zenka is *receiving* on a cube-only socket with
insufficient buffer. Cube is not at fault; it did not have the
capability to fragment.

## the missing capability

STRM-SIZE is already implemented as a protocol primitive. The
framework **auto-fragments SIZE replies > 65536 bytes** when both
sides of a session have declared support. See:

- `auth.callback.cap-neg.declare-strm-size-support` — flips
  `$session->{'strm_size_support'} = TRUE` on capability negotiation
- `auth.callback.cap-neg.select-strm-mode` — per-session `locked` vs
  `normal` switching policy
- `base.handler.strm_size_{absolute,idle}_timeout` — per-chunk
  liveness tracking
- `devmod.cmd.test-strm-size` — "protocol auto-fragments if >
  threshold (65536 bytes)"

A zenka that does not declare STRM-SIZE support [ or hasn't wired its
reply handlers to accept re-assembled chunks, depending on framework
internals ] forces cube to fall back to unfragmented SIZE — which is
exactly what triggers the pause bug for any reply large enough.

## why the existing drop path does not save us

`base.handler.command:1162-1174` has an `ignore_bytes` drop path for
SIZE/STRM/CHRSIZE/STRM-SIZE, but it is gated on **unknown route /
unknown reply-id / expired session** — it drops payloads the receiver
explicitly does not want. A legitimate reply with a live handler
accumulates into the session buffer and never hits drop logic.

There is currently **no size-threshold overflow drop**. The buffer-
full branch in `base.handler.read` simply pauses.

## the constraint on any overflow-drop fix

If you drop a SIZE payload partway, you MUST consume **exactly** the
remaining announced bytes before command parsing resumes. Otherwise
the tail of the payload lands in the command parser and executes as
injected Protocol-7 commands. The existing `ignore_bytes` machinery
already does this correctly — an overflow handler reuses it, it does
not invent its own drop.

## enforcement tiers (where rejection can happen in the routing chain)

1. **Cube at route-time** — first opportunity. Cube sees the SIZE
   announcement before forwarding. Can reject anything exceeding its
   own buffer as an upper bound. Cheapest; protects cube itself;
   rejects egregious payloads before they hit the wire to the target.
   **Blind spot**: cube does not currently know target buffer sizes.
   In the current config [ cube ≥ target ], cube can accept a payload
   that still overflows the target — exactly how this bug triggered.
2. **Target zenka at `base.handler.command`** — authoritative for its
   own capacity. On SIZE / STRM-SIZE / CHRSIZE announcement, compare
   `announced` against local `buffer_max - headroom`. If oversized:
   - set `ignore_bytes = announced` to drain exact framed payload
     [ reuses existing machinery, respects SIZE boundary — no
     injection ]
   - emit FAIL upstream so sender learns
   - skip handler delivery
   Minimal patch; no new primitive; no handler-API change.
   Both `base.handler.read` and `base.handler.command` can see
   `buffer.current` / `buffer.max` via session id, but enforcement
   belongs at the command layer because that is where SIZE semantics
   are parsed — read handler only sees opaque bytes.
3. **Route-traversal buffer probe** [ future ] — a dedicated command
   type modelled on `base.cmd.heart`'s roundtrip-timing pattern.
   Originator sends a "max-size probe" toward target carrying an
   initial value. Each routing hop reduces the carried value to
   `min(carried, local_buffer_max)` before forwarding. Target
   bounces the result back along the return path. Originator learns
   the path's minimum buffer — the true maximum safe reply size for
   that route. Self-healing under dynamic reconfiguration; needs no
   pre-coordinated capability table; composes with STRM decisions.
   Eliminates the sizing-mismatch blind spot so tier-2 becomes
   belt-and-suspenders rather than necessary.

## complementary options (orthogonal to tier 1/2/3)

- **STRM-with-handler** — large replies use STRM-SIZE and the handler
  receives chunks as they arrive. No buffer accumulation of full
  payload. The architecturally right path for arbitrary-size content
  [ future `file`/`files` zenka ]. Does not replace enforcement —
  rather, it enables intentional large transfers to bypass the
  threshold.
- **Per-stream side-buffer** — on SIZE, detach a dedicated allocation
  so main ring stays small. Middle ground between rejection and full
  STRM. Heavier than simple reject, lighter than STRM.
- **Peer-aware pause policy** — read handler refuses to pause on cube
  socket. Symptom-only; trades starvation for unbounded memory
  growth. Not recommended as sole fix.

## recommended minimum

**Step 1 — declare STRM-SIZE support at the target zenki** [ httpd,
web, etc ]. Cube auto-fragments, pause bug never fires for normal
replies. Smallest effective change, no protocol-layer work.

**Step 2a — declared read capacity at session init** [ complements
STRM-SIZE ]. Target advertises `buffer_max_read` at auth handshake;
senders and cube size replies accordingly without probing. Cheap,
no protocol chatter after connect.

**Step 2b — off-band `!CANCEL!` reverse-channel command** [ preferred
resilience fallback ]. When target discovers post-hoc that it cannot
absorb an in-flight payload [ oversized STRM-SIZE chunk, locked mode,
unknown capacity path, runtime memory pressure ], send an off-band
`!CANCEL! <session_id> <stream_id>` upstream via the reverse channel
— which stays writable even when the target's input is paused. The
**sender side [ cube ] holds the unsent tail bytes** in its output
queue; on receiving `!CANCEL!` it drops exactly those bytes. Because
cube owns the pending data, SIZE boundary is preserved naturally —
no `ignore_bytes` tracking needed at the target, no protocol
injection risk because the dropped bytes never reach the target.

The pattern fits the existing `!TERM!` off-band shape [ used by
`base.cmd.term-all` for connection termination ], just contextualized
to a specific stream. Generalises the backchannel from "end everything"
to a framework for off-band stream lifecycle signals.

**Step 2c — configurable per-session buffer-full policy** [ lowest
priority once 2a/2b land ]. Edge cases remaining: drop-with-FAIL
[ tier 2 command-handler local enforcement ], per-stream side-buffer,
pause [ current default, only safe for direct peers ]. Select per
peer type, per session capability.

**Step 3 — route-traversal buffer probe** [ future, tier 3 above ].
Originator learns true min-of-path capacity, enabling precise sender-
side decisions about SIZE vs STRM-SIZE vs pagination.

## how to apply, ordered

1. When adding a new zenka: ensure STRM-SIZE support is declared on
   its cube session at auth handshake. Without it, any reply > buffer
   capacity [ default ~64 KB ] can SIGTERM the zenka.
2. When a zenka gets SIGTERM'd with no obvious blocking call and
   something large was routed to it just before: check
   `$session->{'strm_size_support'}` on its cube session. Missing →
   declare it.
3. When designing an endpoint that returns > few-hundred-KB through
   cube: STRM-SIZE capability + sensible chunk size is usually enough.
   Pagination at the API level is still good practice, independent of
   protocol concerns.
4. When reviewing any new drop path in `base.handler.read` or
   `base.handler.command`: must set `ignore_bytes =
   remaining_payload_bytes` — never truncate mid-frame without
   honouring the SIZE boundary [ protocol injection risk ].

## application-layer workaround (always valid)

**Keep replies small.** Pagination, chunked API endpoints, compressed
payloads — prevent the buffer-fill case from arising. This is the
fastest path to unblocking a specific broken pipeline, independent of
any protocol-layer fix.

## how to apply

- **When designing an endpoint that could return > few-hundred-KB to
  another zenka via cube**: paginate by default, or opt into STRM.
  Do not assume a large SIZE reply will "just work" across cube.
- **When reviewing `base.handler.read` or `base.handler.command`
  changes**: any new drop path must set `ignore_bytes =
  remaining_payload_bytes` — never truncate mid-frame without
  honouring the SIZE boundary.
- **When debugging a zenka that gets SIGTERM'd with no obvious
  blocking call**: check if something big was routed to it via cube
  just before. Watchdog killed the victim, not the culprit.

#,,,.,..,,.,,,...,,..,,,.,,,,,,.,,,,,,,..,.,.,..,,...,...,..,,,,,,..,,,,,,.,.,
#TAPVITKW564CP2OUH4CGIKLNYNMCNQJVMV65TKQX7ZL4EP2FGZSB4WC2FHPI7UQ3PDXBX7RID3WNS
#\\\|6L7XNWGOTSSTZNZBZBQABXREOAMXKMMDL2QVCP23WWAAFWFK6VI \ / AMOS7 \ YOURUM ::
#\[7]AEJ766EZY4W7YI724PS45MY36QNR5PWTRFUVI4L3AG7M4QNBKOAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
