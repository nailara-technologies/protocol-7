# DATA reply type — bi-directional transparent sync protocol

## existing reply modes (reference)

```
TRUE  <data>\n          single-line positive reply
FALSE <data>\n          single-line negative reply
WAIT  <data>\n          deferred — more to follow
SIZE  <N>\n<data>       byte-counted block, N bytes follow
CHRSIZE <N>\n<data>     char-counted block (UTF-8 aware), N chars follow
TERM  <data>\n          terminate session
```

all are request→reply (unidirectional). none support streaming, chunking,
or acknowledgment. `SIZE` requires knowing total size upfront.

## DATA reply type — design

`DATA` is a base32-encoded, line-based, streamable reply mode.
each line is a self-contained unit — safe for line-buffered transports,
logging, and branch node attachment. total size need not be known upfront.

### wire format

```
<cmd_id>DATA <stream_id> <B32_total_or_STREAM>\n   ← open frame
<B32_CHUNK>\n                                       ← data line (repeating)
<B32_CHUNK>\n
...
<cmd_id>DATA END <stream_id> <AMOS_CHECKSUM>\n     ← close frame
```

- `stream_id` = branch node checksum of the data source or session anchor
- `B32_total` = base32-encoded total byte count, or literal `STREAM` if unknown
- each `B32_CHUNK` line = base32-encoded chunk of content
- `AMOS_CHECKSUM` = 7-char AMOS checksum of all decoded content — verifies
  the complete stream without buffering the whole thing

### chunk line format

```
<B32_CHUNK> = base32r encoding of raw bytes, fixed max line width
```

max line width: 76 base32 chars = 47 raw bytes per line (fits terminal,
log lines, protocol framing without wrapping).

### opening variants

```
DATA <stream_id> STREAM\n         unknown size — open-ended stream
DATA <stream_id> <B32_SIZE>\n     known size — receiver can pre-allocate
DATA <stream_id> DELTA <B32_BASE_CHECKSUM>\n   sync delta from known base
```

`DELTA` mode: receiver declares its current state checksum; sender transmits
only what has changed since that checksum. the base checksum IS the sync
point — no separate negotiation needed.

## bi-directional extension

for sync and file access, both sides need to send DATA frames on the
same session. the `stream_id` disambiguates direction:

```
→  DATA <stream_id_A> STREAM\n    sender opens outbound stream
   <B32_CHUNK>\n
←  DATA ACK <stream_id_A> <B32_SEQ>\n   receiver acknowledges sequence
   <B32_CHUNK>\n
→  DATA END <stream_id_A> <AMOS>\n
←  DATA DONE <stream_id_A>\n

←  DATA <stream_id_B> DELTA <B32_BASE>\n    receiver opens return stream
   <B32_CHUNK>\n                             (delta from declared base)
→  DATA ACK <stream_id_B> <B32_SEQ>\n
←  DATA END <stream_id_B> <AMOS>\n
→  DATA DONE <stream_id_B>\n
```

the two streams are independent — interleaving is safe because each line
carries its `stream_id`. no locking required on the transport layer.

## transparent sync protocol

sync is transparent because the checksum IS the state declaration:

```
1. A sends:  DATA <node_id> DELTA <B32_CHECKSUM_OF_A_STATE>\n
2. B computes diff against its own state at node_id
3. B sends only the delta chunks back
4. A applies delta, verifies with AMOS close checksum
5. both sides now share state — verified without full retransmit
```

no manifest exchange, no epoch negotiation, no lock files.
the checksum tree (see DANCING-ZENKI-RHIZOME-STATE.md) IS the manifest —
`1[zeros]1` separators with bit-length annotations already encode what
was transmitted and in what order.

### incremental multi-hop sync

the rhizome state (reference bubble) carries the running checksum tree
through the network. each hop node that processes the bubble updates its
local cache and the bubble's checksum tree grows by one entry. when the
bubble returns (01 direction), the tree IS the complete sync record —
every hop has already verified its segment.

## branch node + buffer chain file access protocol

a branch node with a file resource (see branch.file.*) is a DATA session
anchor. the session lifecycle maps to the reference bubble formation:

```
setup zenka    →  branch.file.open + DATA session open
                  stream_id = branch node checksum of file resource
                  direction: 01 (resolving to source)

ground zenki   →  DATA chunk exchange
                  each chunk line = one read/write unit
                  workers pipeline chunks — no head-of-line blocking

collector      →  DATA END + branch.file.close
                  AMOS checksum verifies complete transfer
                  direction: 10 (result propagates outward)
                  updates branch.route.cache for next access
```

### file access wire sequence

```
→ branch.file.open { node, path, mode }
← TRUE <file_handle_id>

→ branch.file.read { fh, length }
← DATA <fh_id> <B32_LENGTH>\n
  <B32_CHUNK>\n
  <B32_CHUNK>\n
  DATA END <fh_id> <AMOS_CHECKSUM>\n

→ branch.file.write { fh }
  DATA <fh_id> STREAM\n
  <B32_CHUNK>\n
  DATA END <fh_id> <AMOS_CHECKSUM>\n
← TRUE <bytes_written_B32>

→ branch.file.close { fh }
← TRUE closed
```

### adapter transparency

`branch.file.adapter.local`, `branch.file.adapter.9p`,
`branch.file.adapter.storage` all speak DATA on the protocol side.
callers never see the adapter — they see DATA lines. the adapter choice
is resolved once (by `branch.file.adapter.resolve`) and cached in the
file handle. subsequent DATA exchange goes direct.

## adding DATA to base.callback.cmd_reply

extension to `base.callback.cmd_reply` (after CHRSIZE branch):

```perl
} elsif ( uc($reply_mode) eq qw| DATA | ) {

    my $stream_id  = $reply->{'stream_id'} // '';
    my $total      = $reply->{'total'}     // qw| STREAM |;
    my $total_b32  = ref \$total ? <[base.encode_b32r]>->(\$total) : $total;

    ## open frame ##
    $output->$* .= sprintf "%sDATA %s %s\n",
        $_cmd_id, $stream_id, $total_b32;

    ## chunk lines ##
    my $data   = $reply->{'data'} // '';
    my $chunk  = 47;    ## 47 bytes = 76 base32 chars per line ##
    while ( length $data ) {
        my $slice = substr( $data, 0, $chunk, '' );
        $output->$* .= <[base.encode_b32r]>->( \$slice ) . "\n";
    }

    ## close frame with AMOS checksum ##
    my $chksum_fn = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'};
    my $checksum  = $chksum_fn->( \$reply->{'data'} );
    $output->$* .= sprintf "%sDATA END %s %s\n",
        $_cmd_id, $stream_id, $checksum;
```

## prior art and related docs

the sync fabric vision is described at a high level in several existing docs —
this document defines the concrete wire protocol and reply-mode implementation:

- `data/md/vision/VISION-DATA-SYNCHRONIZATION-FABRIC.md` — three pillars:
  hash watchers, timestamp indexing, remote branch mounting. DATA protocol
  is the transport layer that makes remote branch mounting concrete.
- `data/md/research/GENERIC-DATA-SYNCHRONIZATION-FABRIC.md` — event
  propagation primitives. DATA DELTA mode is the wire expression of this.
- `data/md/design/CONCEPT-DATA-ZENKA-ARCHITECTURE.md` — data zenka fabric.
  DATA sessions are how zenki expose their namespaces as mountable streams.
- `data/md/protocol-7-knowledge/04_DATA_ENCODING/dual_encoding.md` — 9-bit
  background / 7-bit foreground dual encoding. DATA chunks carry this
  naturally — base32 is the neutral transport; interpretation layer is above.
- `data/md/protocol-7-knowledge/03_NETWORK_PROTOCOLS/3D_BUFFER_DATA_ZENKA_DECODER_INTEGRATION.md`
  — 3D buffer + data zenka decoder. DATA streams are the feed into this.
- `DANCING-ZENKI-RHIZOME-STATE.md` — reference bubble travel and checksum
  tree. DATA END checksum IS a checksum tree leaf; bubble carries the tree.

## connection to existing systems

- `base.callback.cmd_reply` — DATA branch to add alongside SIZE/CHRSIZE
- `branch.file.*` — file access protocol lives here
- STRM transport layer — DATA is the reply-mode complement; STRM handles
  persistent named streams, DATA handles request-scoped transfers
- checksum tree (`DANCING-ZENKI-RHIZOME-STATE.md`) — the DATA close
  checksum IS a checksum tree leaf; multi-hop sessions build the tree
- `branch.storage.persist` — uses DATA DELTA mode for incremental sync
- `plugin.web.*` — DATA mode replaces ad-hoc SIZE-based file transfers
- `SELF-DELIMITING-CHECKSUM-PATTERN.md` — the generic pattern behind all
  inline checksums and anchors in DATA/DATA-PAGES/DATA-CHANNELS

## DATA-PAGES — multiplexing container (session 45)

DATA-PAGES is a bulk and multiplexing extension of the DATA line format.
each line inside a page drops the redundant `DATA ` prefix — the page header
carries stream context once, amortizing metadata cost across all contained lines:

```
DATA-PAGE <stream_id> <page_seq> <line_count>\n   ← page open
<B32_CHUNK>\n                                      ← pure payload, no prefix
<B32_CHUNK>\n
...
DATA-PAGE END <stream_id> <page_seq> <AMOS_CHECKSUM>\n   ← page close
```

- `page_seq` = monotonic sequence number per stream_id
- `line_count` = lines in this page (receiver knows when page is complete)
- `AMOS_CHECKSUM` = checksum of all decoded chunks in this page

### properties

- **prefix savings**: at 64 lines/page, one header/footer replaces 64 `DATA `
  prefixes — pure payload density increase
- **multiplexing**: interleaved pages from different streams disambiguated by
  `stream_id` + `page_seq`; reassembly trivial, no full-stream buffering needed
- **flow control**: ACK at page close rather than stream close; backpressure
  per page, fine-grained without per-line ACK overhead
- **UDT alignment**: page boundary maps cleanly to UDT packet semantics —
  per-stream transport behavior (ordered, loss-tolerant, etc.) declared once
  per stream, honored across all its pages
- **format continuity**: same base32 payload as DATA lines — ASCII-clean,
  log-safe, terminal-safe, branch-attachable without transcoding

### mode selection

```
DATA lines      — single small transfers, request-scoped, existing reply mode
DATA-PAGES      — bulk transfers, multiplexed streams, UDT native transport
```

same base32 payload, clean upgrade path. DATA-PAGES is the trunk-level
container; DATA lines remain valid for all current reply-mode uses.

### connection to UDT transport

UDT decouples from TCP's sealed congestion model, making transport semantics
per-stream programmable. DATA-PAGES maps onto this cleanly:

- heartbeat stream: small pages, latency-sensitive, loss-tolerant
- DATA transfer: larger pages, ordered, verified by AMOS at page close
- control messages: single-line pages, must-arrive, immediate ACK

the page close AMOS checksum becomes the natural ACK signal — received AND
verified, not just received.

## open items

- `DATA ACK` parsing in the receiver (base.protocol-7.receive or equivalent)
- `DATA DELTA` diff computation module (`branch.storage.sync` candidate)
- max chunk size tuning (47 bytes / 76 b32 chars is conservative — can
  increase for non-terminal transports)
- `DATA STREAM` backpressure: if receiver buffer fills, ACK withheld until
  drained — sender must respect missing ACK as pause signal
- `DATA-PAGES` receiver implementation and page reassembly
- per-stream UDT transport attribute declaration format

#,,.,,...,.,.,,.,,,,,,..,,,,,,...,,,.,,..,,,.,..,,...,...,,.,,...,,..,..,,,.,,
#WMD2WL3HSS7BCBLIMLZY23UHVDMBA47PANEO2HXAQ3WYDXJT7BBLVYVQ7IYEZ6TVCMZWVNZGU57LU
#\\\|K77GV2SDP2LEDI5JOEA6RSXNK7DOZQG4TXRBJNMHZXHRMMPL7W7 \ / AMOS7 \ YOURUM ::
#\[7]ISIQOV2P67SWW7RAHKK3ISF7WEBIYIYW3UOIIAI7WLX7BJJT26CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
