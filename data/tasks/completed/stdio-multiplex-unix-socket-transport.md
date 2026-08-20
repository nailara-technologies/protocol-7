# task: unix-socket stdio multiplex transport

## relation

depends on `data/tasks/stdio-multiplex-type-tag-codec.md` shipping the
encoder/decoder pair. implements the carrier layer specified in
`data/md/design/STDIO-MULTIPLEX-PROTOCOL.md` — one unix-domain socket
per zenka, carrying multiplexed typed runs in both directions.

## scope

### `base.stdio.transport.listen`

```
# name  = base.stdio.transport.listen
# param = $socket_path, $on_record_coderef
# descr = open a listening unix-domain socket; each inbound typed-run
#         record is delivered to $on_record_coderef
```

### `base.stdio.transport.connect`

```
# name  = base.stdio.transport.connect
# param = $socket_path, $on_record_coderef
# descr = connect to a listening socket as a client; same callback
#         shape for inbound records
```

### `base.stdio.transport.emit`

```
# name  = base.stdio.transport.emit
# param = $conn_handle, $tag, $encoding, $payload, $header_fields
# descr = emit one typed run on $conn_handle's writer; wraps
#         base.stdio.frame.encode with non-blocking write discipline
```

implementation notes:

- IO::Async event-loop integration, matching the existing P7 socket
  plumbing patterns [ see modules under `src/base.net.*` and
  `src/base.stream.*` for the existing IO::Async idioms in this
  codebase ]
- per-connection inbound byte buffer feeds `base.stdio.frame.decode`
  on every readable event; the decoder's output records are
  delivered to the per-connection `$on_record_coderef`
- outbound write discipline is non-blocking; on EAGAIN the encoder's
  output is queued in the connection state and drained on the next
  writable event — same shape as the existing `base.stream.push`
  flow
- one socket carries **both** directions [ inbound SIN/RIN, outbound
  EOUT/TOUT/NUM/STR/ERR/META ] — the codec is direction-agnostic;
  the transport just opens a bidirectional unix socket and runs the
  read-loop + write-queue on each end
- socket path lives under `/dev/shm/.7/STDIO/<zenka>` [ parallel to
  the existing `/dev/shm/.7/STDOUT/<sock>` ring ]; the existing
  STDOUT socket and ring stay untouched — this is the *new*
  multiplexed transport path, opt-in per zenka
- per-zenka access gating rides through the existing
  `cube/access.zenki` mechanism — no new access primitive

## acceptance

- two-process round-trip: a test client connects to a test server,
  emits one of each of the 8 tags, server delivers exactly 8 records
  in arrival order to its callback.
- non-blocking: emitting a 1 MiB EOUT run while the receiver is
  paused does not block the sender's event loop; the run completes
  when the receiver resumes.
- detach/reattach: closing the client connection mid-run causes the
  server to surface a clean `scope-leave` synthesised record
  [ unmatched scope-enter cleanup ] rather than a partial record;
  reconnecting opens a fresh scope tree.
- coexistence: a zenka simultaneously running the existing
  `/dev/shm/.7/STDOUT/<sock>` line-relay AND a new
  `/dev/shm/.7/STDIO/<zenka>` multiplexed transport produces
  equivalent EOUT content on both paths, byte-for-byte after
  framing decode on the new path.

## non-goals

- no demultiplexer / slot routing — that is
  `v7-console-stdio-multiplex-demux.md`.
- no zenka-side adoption — zenki opt into the new transport by
  loading it in their start file; this task only ships the carrier,
  not its callers.
- no TCP variant in this tranche; unix-domain only. the codec is
  transport-agnostic so a TCP variant lands trivially later.

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

## syntax checks

```
perl -c src/base.stdio.transport.listen
perl -c src/base.stdio.transport.connect
perl -c src/base.stdio.transport.emit
```

#,,,,,.,.,,,.,...,,,.,.,,,..,,,,,,,.,,,..,,,.,..,,...,...,,..,.,,,.,,,..,,.,,,
#HX5C4YFZ6XUSORMHTE63UYC42WKO72ECARGGUXRPEI6L2FT2UMOG3TQX33LSNOWZ5ZYLINVH3IS4Y
#\\\|WEMCVVYR6SJ4FB4D6B45LBDAYLINO43ZQXOOX3ESII54QMPZFSE \ / AMOS7 \ YOURUM ::
#\[7]TILTFUPFPWI4FPSYICCELS7Q6DWHQV4LWY246QNYK5N45KV524DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
