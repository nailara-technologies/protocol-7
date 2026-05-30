---
name: topic-stream-reply-modes
description: "STRM reply modes: bounded scalar, scalar-ref, filehandle, unbounded live; design for scalar-ref optimization"
metadata:
  node_type: memory
  type: project
  originSessionId: session-63
---

## current reply modes (session 63 analysis)

### mode 1: bounded scalar (current, implemented)
handler returns `{ mode => 'strm', data => $json }`.
base.handler.command copies scalar, optionally utf8::encodes, computes total,
calls base.stream.open(total=N), streams in 8192-byte chunks, closes.
works. **problem**: large data (e.g. 4.6MB jobs JSON) causes 2+ full copies in
memory before chunking starts. `$data_to_send` + `$chunk_data` + the original.

### mode 2: unbounded live stream (current, implemented differently)
handler does NOT return a data reply. instead it opens the stream itself via
`base.stream.open` (unbounded, no total), calls `base.stream.push` in a
timer/event loop, calls `base.stream.close` when done.
examples: radio relay, kimi-web dispatch stream.
total is unknown at open time → `STRM open\n` (no size).
consumer closes on STRM close, not on byte count.

### mode 3: scalar reference (planned, NOT YET IMPLEMENTED)
handler returns `{ mode => 'strm', data => \$large_string }`.
avoids extra copies — base.handler.command holds the ref in stream metadata
to keep the string alive, reads directly via `substr $$ref, $offset, $chunk_len`.
requires ref to be stored in stream state for duration of streaming.

### mode 4: filehandle / IO source (planned, NOT YET IMPLEMENTED)
handler returns `{ mode => 'strm', data => $fh }` or similar.
for data larger than available memory (large files, log tails, etc.).
base.handler.command reads in chunks from the handle, pushes each chunk.
total may be known (file size) or unknown (pipe/socket).
need: open(total=N) if known, open(unbounded) if not.

## key design constraints

- scalar-ref must be held in stream metadata (`$session->{'streams'}{$cmd_id}`)
  for the full duration of streaming or Perl GC may free it if the caller's
  lexical goes out of scope.
- utf8::encode on scalar-ref: modifies in place, would mutate the caller's
  string. copy-on-write semantics needed: only copy+encode if utf8 flag is set,
  otherwise stream directly from ref.
- for filehandle mode: chunk loop reads from handle, total may be undef
  (unbounded) — on_eof fires on STRM close, not byte count. already works.
- current handlers that stream manually (radio, kimi-web) remain valid and
  are the right pattern for truly live/unbounded data sources.

### mode 5: coderef / generator (planned, NOT YET IMPLEMENTED)
handler returns `{ mode => 'strm', data => sub { ... } }` or
`{ mode => 'strm', data => $code{'zenka.handler.strm.chunk'} }`.
using a %code ref makes the generator a first-class P7 module: hot-reloadable,
nameable, reusable across handlers.
base.handler.command calls the coderef repeatedly; each call returns the next
chunk, or undef/'' to signal end-of-stream.
return value of the coderef follows the same mode hierarchy:
  - scalar       → buffered chunk
  - scalar ref   → zero-copy chunk
  - undef/''     → end of stream
total is usually unknown → unbounded open. coderef could signal total on first
call e.g. `return ($chunk, $total)` if size is knowable upfront.
a `full_reply_data` variant (returns entire payload at once as scalar-ref) is
valid and gets zero-copy streaming transparently — infrastructure handles chunking.
cleanest pull model: lazy, composable, hot-reloadable.

## what to do next

- implement mode 3 (scalar-ref) in base.handler.command STRM send path:
  - detect `ref($reply->{'data'}) eq 'SCALAR'`
  - store ref in stream state so it stays alive
  - deref only at substr time
  - copy+encode only if utf8::is_utf8($$ref), else stream directly
- implement mode 4 (filehandle) similarly: detect IO ref, read in chunks
- both modes share the same while-loop structure, just different data sources
- keep existing scalar mode for small replies (no regression)

## related

- [[session-62]] — STRM refactor history, bytes::length fix
- [[stream-transport-layer]] — STRM stack overview

#,,..,..,,.,,,,..,,..,,,,,..,,,.,,..,,,,,,,,.,..,,...,...,..,,.,,,...,...,.,,,
#4APYDRXHICGNG7X35Y55JIJ5CT6JIOPMP5QGCMRURRTCYZWVKJYZGPMR7IRY4EL7G5W65GV6U6UXM
#\\\|LLTC3BYQOPHOIWXKJ6T6OBG6U22RYUDBHC2YNC6FPO7A7L7GJ4F \ / AMOS7 \ YOURUM ::
#\[7]ZELD5D6SC4FVC7XQMAWOCD74KYU55DFOBIOXYILVDOWYW2QVJ4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
