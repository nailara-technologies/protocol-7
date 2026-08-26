---
name: topic-data-protocol
description: "DATA reply type + bi-directional transparent sync protocol — base32 line-based, branch node compatible, buffer chain file access"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4b3850d2-8acb-4166-bbdf-ddf52d8182ba
---

design doc: `data/md/design/DATA-PROTOCOL-SYNC.md`

## what's new (not in existing vision docs)

existing docs describe the sync fabric vision (hash watchers, timestamp
indexing, remote branch mounting). this defines the concrete wire protocol:

## DATA reply mode (to add to base.callback.cmd_reply)

```
DATA <stream_id> <B32_SIZE|STREAM|DELTA B32_BASE>\n   ← open
<B32_CHUNK>\n                                          ← data lines
DATA END <stream_id> <AMOS_CHECKSUM>\n                 ← close
```

alongside existing: TRUE / FALSE / WAIT / SIZE / CHRSIZE / TERM

- stream_id = branch node checksum of data source
- base32-encoded, line-based — safe for logging, terminal, branch attachment
- 47 bytes / 76 b32 chars per line (conservative, fits all transports)
- AMOS close checksum verifies whole stream without full buffering

## DATA DELTA mode — transparent sync

```
DATA <node_id> DELTA <B32_CHECKSUM_OF_SENDER_STATE>\n
```

receiver computes diff against own state, sends only delta back.
no manifest exchange, no epoch, no lock files.
the checksum IS the sync point.

## bi-directional

two independent DATA streams on same session, disambiguated by stream_id.
ACK lines for backpressure: `DATA ACK <stream_id> <B32_SEQ>\n`

## branch node + buffer chain file access

setup zenka opens DATA session → ground zenki exchange chunks →
collector closes with AMOS checksum + updates branch.route.cache

branch.file.* adapters (local / 9p / storage) all speak DATA on
the protocol side — caller sees DATA lines, never the adapter.

## connections

- `base.callback.cmd_reply` — DATA branch to implement (after CHRSIZE)
- `branch.file.*` — file access uses DATA read/write sessions
- `branch.storage.sync` — uses DATA DELTA for incremental sync
- STRM transport — complement: STRM = persistent named streams,
  DATA = request-scoped transfers
- checksum tree (DANCING-ZENKI-RHIZOME-STATE.md) — DATA END checksum
  is a checksum tree leaf; bubble carries the growing tree

## wire format clarifications (session 45)

- `B32_SIZE` in open frame IS per spec — but plain decimal may be cleaner
  since the field has space delimiters anyway (no self-delimiting needed)
- chunk lines base32-encoded: size derivable from char count without decoding
  (full 76-char line = 47 bytes; last line n chars = floor(n×5/8) bytes)
  but SIZE field gives it upfront — buffer pre-allocation, size-limit checks
- `DATA END` checksum line IS the right place for the self-delimiting format:
  `0` + zero-padded decimal input length + AMOS checksum (e.g. `01303UGKDZQ`)
  `0`/`1` are outside base32 alphabet → unambiguous separator, chainable
  `1` variant reserved — not yet documented anywhere, needs a spec doc
- `base.callback.cmd_reply` DATA + TREE branches now implemented (session 44/45)
  spec code had bug: `ref \$total` always true — should be `$total =~ m|^\d+$|`

## self-delimiting token pattern — 2-bit type system (session 45)

`0`/`1` outside base32 alphabet → unambiguous sentinels. MSB = domain, LSB = claim level:

```
00  checksum       — data domain, size + AMOS7, passive
01  signature      — data domain, size + stronger claim, passive
10  incomplete ref — reference domain, sticky, cursor/route hop, no invocation
11  complete ref   — reference domain, transparent, invokes + reply expected
```

`10` is sticky — persists as routing context, chains as hops, coordinate transform per hop.
`11` is transparent — collapses on success, demotes to `10` on deferred/failure.
group behavior: `10 10 [keep] 11` = keep-alive (route persists), `10 10 [close] 11` = close (collapses together).
analog: HTTP connection keep-alive vs close, but at routing/reference level.
size in `00`/`01` IS security — wrong size = immediate integrity fail.
design doc: `data/md/design/SELF-DELIMITING-CHECKSUM-PATTERN.md`

## DATA-CHANNELS (session 45)

multiplexing frame carrying N authenticated DATA-CHANNELs:
```
DATA-CHANNELS <chksum_A> <chksum_B>\n   ← channel registry, closed at open
0: <B32_CHUNK>\n    ← channel 0 payload (: = payload)
0| 01303UGKDZQ\n    ← inline validation anchor (| = anchor)
DATA-CHANNELS END <AMOS_CHECKSUM>\n
```
AMOS checksums as parameters = channel authentication, arbitrary introduction impossible.
numeric prefix (0:/1:) = minimal overhead, unambiguous (0/1 outside base32).
inline anchors use self-delimiting checksum — receiver locks validated regions,
releases validation buffer while playback/processing continues at constant speed.
DATA-CHANNEL (singular) = named logical stream identity within the container.

## DATA-PAGES — multiplexing container (session 45)

bulk/multiplexed extension — lines inside drop `DATA ` prefix, page header
carries context once:

```
DATA-PAGE <stream_id> <page_seq> <line_count>\n
<B32_CHUNK>\n   ← pure payload, no per-line prefix
DATA-PAGE END <stream_id> <page_seq> <AMOS_CHECKSUM>\n
```

- prefix savings: 64 lines/page = 64 fewer `DATA ` prefixes
- multiplexing: stream_id + page_seq disambiguate interleaved pages
- flow control: ACK at page close, backpressure per page
- UDT alignment: page boundary = UDT packet boundary; per-stream transport
  semantics declared once, honored across all pages
- mode selection: DATA lines for small/request-scoped, DATA-PAGES for bulk/UDT
- same base32 payload throughout — ASCII-clean, log-safe, branch-attachable

UDT transport (planned): decouples from TCP, makes transport semantics
per-stream programmable. heartbeat/DATA/control each get appropriate behavior.
page close AMOS checksum = natural ACK (received AND verified).

## open items

- DATA ACK parsing in receiver (base.protocol-7.receive or equivalent)
- DATA DELTA diff computation module
- backpressure: missing ACK = pause signal for sender
- max chunk size tuning for non-terminal transports
- write spec doc for `0`-prefixed self-delimiting checksum format

#,,..,.,,,...,,.,,,.,,.,.,,,.,.,,,,,,,,,,,.,.,..,,...,.,.,.,,,...,,,.,,,.,..,,
#CMTQTLE2RX4QO45G66KXD3F2LMFXPJNIG5PSNGKDP2QIUMTWXRPCNH4DK6I3MMZWDHUZ2HOGHOMJ6
#\\\|XVCZ6SKXDQJTHP6RRNIXUDTYII7YRGQXXFLMECXT3IRYOOCEUTB \ / AMOS7 \ YOURUM ::
#\[7]LVF7WPLBD35FI6YCTMGYAD623DZPFKD6NUKBH3GJEXVJMKIQEEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
