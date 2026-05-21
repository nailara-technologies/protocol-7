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

## open items

- DATA ACK parsing in receiver (base.protocol-7.receive or equivalent)
- DATA DELTA diff computation module
- backpressure: missing ACK = pause signal for sender
- max chunk size tuning for non-terminal transports

#,,..,..,,,..,..,,,,,,,,,,.,.,.,,,.,,,..,,.,,,..,,...,...,,..,.,,,,..,..,,,,.,
#Z2EOZKFNUOHW667KPEJ4X4XTIINRWR6BYRRE2PA3IOWAOBFPDFCH745UFSXOA2MMWPPS5CJRMYNUQ
#\\\|7YOTBZ6AM6PXXKY3ZVZHP72QF6NPRMPXOICL7KOCSGOYGGB3PGF \ / AMOS7 \ YOURUM ::
#\[7]CD4ZTASLM3UDM32MGU2CEP67MXRJL4GMKOSTBUQIKHVTUWM2KUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
