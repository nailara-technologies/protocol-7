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

## open items

- DATA ACK parsing in receiver (base.protocol-7.receive or equivalent)
- DATA DELTA diff computation module
- backpressure: missing ACK = pause signal for sender
- max chunk size tuning for non-terminal transports
- write spec doc for `0`-prefixed self-delimiting checksum format

#,,.,,.,,,,.,,,,.,.,.,.,,,...,,..,,,.,.,.,...,..,,...,...,.,,,.,,,.,,,.,,,,..,
#KM3HCV6ZTBPJOFLQKZKMBCDLHFCQ6A5TLI3OAYTHANVOINQESFUURFVLAZ3D5KTRA4EJL7MCJKAC2
#\\\|H5BWSHRFCK5TS3V53SCVTZ2UEUC7L5YMM52L3JU4MUHPUQURGIW \ / AMOS7 \ YOURUM ::
#\[7]35TBBWYVKOV4YH67G7EKF2A5ZCSJL5JLT3ADTI55UK75QBZEGKAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
