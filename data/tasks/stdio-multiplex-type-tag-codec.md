# task: stdio multiplex type-tag codec [ encoder + decoder ]

## relation

implements the type-tag frame-layer specified in
`data/md/design/STDIO-MULTIPLEX-PROTOCOL.md`. prerequisite for
`stdio-multiplex-unix-socket-transport.md` and
`v7-console-stdio-multiplex-demux.md`. builds on
[[topic-stream-framing-protocol]] [ the 3+1 bit payload/separator
framing already in the network ] and does NOT change it.

## scope

a pair of modules implementing the wire-grammar conversion between
typed-run records and the 3+1 bit frame stream.

### `base.stdio.frame.encode`

```
# name  = base.stdio.frame.encode
# param = $type_tag, $content_encoding, $payload, $header_fields_hashref
# descr = emit a typed-run frame sequence onto the caller's writer
```

contract:

- `$type_tag` is one of the 8 named constants
  `META | SIN | RIN | EOUT | TOUT | NUM | STR | ERR` — define them as
  constants in a small package [ `AMOS7::STDIO::Tags` or similar,
  exported ], with values matching the 3-bit bit-patterns from the
  design doc
- `$content_encoding` is one of `b32 | nibble | byte-pack`, matching
  the design doc's encoding flag
- `$payload` is the data to ship; encoder handles the splitting into
  3-bit payload groups and packs into the framing stream
- `$header_fields_hashref` carries tag-specific META header values
  [ fd-index for EOUT/ERR, scope id + slot_addr + origin for
  scope-enter, etc. ]
- caller supplies the writer via a coderef or a filehandle held in
  module state — keep this seam thin; transport details live in the
  unix-socket-transport task, not here

the encoder is purely the bytes-out side. it does not buffer typed
runs across calls beyond what one run needs; each call emits one
complete typed run [ open META + N data frames + close ].

### `base.stdio.frame.decode`

```
# name  = base.stdio.frame.decode
# param = $byte_buf_sref
# descr = consume framed bytes, return list of typed-run records
```

contract:

- input is a scalar-ref to a byte buffer the caller fills [ from a
  socket read in the transport layer ]
- output is a list of typed-run records, each a hashref:
  `{ tag, encoding, header, payload_sref }`
- decoder consumes complete runs only; unconsumed bytes [ partial
  trailing run ] stay in the buffer for the next call. caller does
  the read-loop
- decoder is the *only* place the inversion rule and sliding-window
  separator-lock from [[topic-stream-framing-protocol]] are
  implemented — re-use the existing P7 implementation of that
  framing if one exists; otherwise this task ships the first
  conformant decoder
- META scope-enter / scope-leave records are surfaced as records
  with `tag => META, header => { subtype => 'scope-enter', ... }`;
  callers walk the scope tree by inspecting `header.subtype`

## acceptance

- round-trip property:
  `decode( encode( $tag, $enc, $payload, $hdr ) )` reproduces
  exactly one record with the same tag, encoding, payload, and
  header — verified for each of the 8 tags and each of the 3
  encodings.
- inversion rule conformance: a `META` frame's payload `000` is
  paired with separator `,` in the encoder output; the decoder
  rejects any `000 .` pair as a framing error.
- partial-buffer safety: feeding the decoder one byte at a time
  produces exactly the same record list as feeding the full
  buffer.
- META scope nesting: encoding `scope-enter, EOUT-run, scope-leave`
  and decoding yields three records in that order, with the
  scope-enter header carrying its full `origin` + `slot_addr`
  payload.
- no behavioural change to any existing module — codec is new code,
  not a rewrite.

## non-goals

- no socket I/O [ that is the transport task ].
- no demultiplexing / slot routing [ that is the v7 demux task ].
- no changes to the existing 3+1 bit framing primitive itself;
  this task implements the type-tag layer **on top of** that
  framing, re-using whatever conformant framing-frame
  encoder/decoder already exists in the codebase.

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

## harmony checks

```
harmony base.stdio.frame.encode
harmony base.stdio.frame.decode
```

#,,..,..,,.,.,,,,,,,.,,,,,,,,,..,,...,,,.,,..,..,,...,...,...,.,.,,.,,,..,..,,
#LBAZYMPHGFPGBMRNKCYJ5LHGPOKICZJ5FDBMHPQMERY46ZUNUIB6EZZFZRT2TIU53Q4VFCMH4TUTM
#\\\|BTLGHNPWA7SYGRWJOMWXH4ETN32FTZL2O5TNAFWE4ELX5G6FXHL \ / AMOS7 \ YOURUM ::
#\[7]ELOL6RJ2NTBBNLBZVNTB4W6KHA3INJH6JROIZFKJZRVSG236YUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
