---
name: feedback-p7-route-send-wire-protocol
description: P7 route-send/reply actual wire shapes — verified from base.protocol-7.command.send.local and base.handler.command.process_reply, not assumption
metadata:
  type: feedback
  originSessionId: 47367c65-b043-47a7-be00-11d29ff7b99d
---

Cost three wrong implementations in one session before reading the actual
protocol code instead of guessing. Verify against these files directly
(`base.protocol-7.command.send.local`, `base.handler.command.process_reply`,
`base.handler.command`) before building any cross-zenka command.

**call_args only transmits one string field over the wire.** `route-send`'s
`call_args` hashref is NOT serialized whole — only `call_args->{'args'}` is
ever put on the wire (`$cmd . ' ' . $call_args->{'args'} . "\n"`). Any other
key (`call_args->{'id'}`, `call_args->{'foo'}`) silently never arrives at
the target. To send structured data, encode it into one string yourself
(plain delimited tokens for small fixed fields, JSON for anything bigger —
see below for why JSON doesn't need base32 here).

**Reply shape depends on `cmd`, there is no `mode` key on the delivered
reply.** The reply handler receives `{sid, cmd, call_args, params, data?}`.
`cmd` is the discriminator:
- `TRUE`/`FALSE`/`WAIT`/`GET`/`TERM`: no `data` key at all — the message
  text is in `call_args->{'args'}`.
- `SIZE`: `data` holds the complete string. This covers both a small
  direct reply AND a large one that got auto-fragmented via STRM-SIZE —
  the receiving side reassembles fully before calling your handler exactly
  once. **Just return `{mode=>'size', data=>$string}` from the producer
  side and the framework decides bounded-vs-fragmented for you** — no
  manual chunking, no base32 wrapping needed regardless of payload size.
- `STRM` (the explicit/manual streaming mode): handler fires once on
  *open* with no data yet; you must call `<[base.strm.local.register]>`
  with `watcher`/`on_eof` callbacks to actually receive chunks. This is
  for cases needing per-chunk processing (unbounded live feeds); for
  ordinary "send this string, possibly large" just use `mode=>'size'`.

**Producer side mode names**: `{mode=>'size', data=>$str}` from a `.cmd.`
module is sufficient for arbitrary-size string payloads — see
`base.handler.command`'s SIZE branch: it checks
`$count > $data{'size'}{'buffer'}{'input'}` and transparently switches to
STRM-SIZE fragmentation, or sends directly if small. Don't hand-roll
base32-encoded single-line payloads to dodge buffer limits — that's a
workaround for a different, narrower problem (see
[[feedback-oversize-single-line-protocol]]) and isn't elegant to reuse.

**Cross-zenka access is two-sided.** A command from zenka A relayed via
cube to zenka B needs: (1) `cube/access.zenki`'s
`access.cmd.usr.<A> = ... B.command` entry (cube permits A to address this
command at all), AND (2) B's own `start` file's
`access.cmd.usr.cube = ... command` entry (B permits cube to relay this
specific command to it — from B's perspective every cube-relayed call
arrives with src='cube', not the true origin zenka name). Missing either
side fails silently with `no perm. [ src '<X>' cmd|usr '<command>' ]` —
check which side logged it (X tells you which gate rejected).

**How to apply:** before designing any new cross-zenka command exchange,
read the actual delivery code paths instead of inferring from one example.
Don't assume an unfamiliar reply shape matches a shape you've seen in a
different context (e.g. httpd-specific STRM consumers) without checking
whether it's the same code path for non-HTTP zenka-to-zenka traffic.

#,,.,,,.,,,..,.,.,,,.,,.,,,,.,,..,,..,.,.,,,,,..,,...,...,,,.,..,,,,.,..,,.,.,
#GZISQL2XYAJ7P3X4VO3Y2E6OYKN65DQT6RA2BWCKIXYNFSYN3FZN7XOGZ7TE7AQY4QNWXA2ZUGVTW
#\\\|F7OT3ISGGLKJB2DT5ALB4ISGE5IEGTNCWJWM3MT5OKXTR24C3KP \ / AMOS7 \ YOURUM ::
#\[7]PYQZ7VDMGNIRCY5MFLGY5YGP4TPNKSDORJSS234O54V3AXINQ6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
