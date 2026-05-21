---
name: topic-checksum-tree-wire
description: "checksum tree wire format — 1[zeros]1 bit-length separators, 01/10 direction encoding, append-only, type-free, BASE32 compatible"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4b3850d2-8acb-4166-bbdf-ddf52d8182ba
---

design doc: `data/md/design/DANCING-ZENKI-RHIZOME-STATE.md` (section: checksum tree)
related: [[topic-reference-bubble]], [[topic-data-protocol]], [[topic-branch-namespace]]

## the format

BASE32 alphabet is [2-9A-Z] — both 0 and 1 are excluded, making them
unambiguous structural characters that can never appear in data.

```
structural vocabulary:

1 [000...N] 1   separator frame
              N zeros = bit-length of the checksummed content
              bit precision (not byte) — sub-byte granularity

01              toward source / parent direction  [ collapsing ]
10              toward leaves / sub-branch direction  [ expanding ]
11              pivot point — direction reversal, LCA marker, root anchor
00              reserved

2-9A-Z          checksum characters (algorithm identified by length)
```

## properties

- **append-only**: just concatenate `1[zeros]1 [CHECKSUM]` to extend
- **type-free**: checksum length reveals algorithm (AMOS=7 chars, BMW384=longer, ELF=different)
- **self-delimiting**: `1...1` frame parseable without fixed-width assumption
- **direction-declaring**: `01`/`10` encode travel direction INTO the address
- **security**: forging a separator requires knowing exact bit-length of content
- **zero-length separator**: `11` = valid empty boundary (pivot / root anchor)

## route topology in the stream

a route through a branch tree writes its own topology:

```
[node-A chksum]  01 01 01  [LCA chksum]  10 10  [node-B chksum]
                 ^^^^^^^^                 ^^^^^
                 3 hops up                2 hops down
```

the `01`→`10` inversion point IS the LCA. no routing table needed.

## direction as eternal travel

`01` and `10` are not counts or indexes — they are **direction of travel**
encoded into the address itself. a path carrying `10` markers is inherently
an expanding/outward path. `01` is collapsing/inward. permanent, not
computed at traversal time.

## connection to DATA protocol

DATA END checksum (`DATA END <stream_id> <AMOS_CHECKSUM>`) is a leaf in
this tree. multi-hop DATA sessions accumulate into a growing checksum tree
carried by the reference bubble.

## connection to stream framing protocol

`dot=0 comma=1` from stream framing protocol maps directly:
- dot-comma (`01`) = toward source
- comma-dot (`10`) = toward leaves
- separator inversion on `000` = the zero-padding within `1[zeros]1`

#,,,.,...,.,,,.,.,.,.,,.,,..,,,,,,,,,,.,,,,.,,..,,...,...,,,.,.,.,,..,,,.,,,,,
#6QZRMGG2FQQWKXQZX7UKVDCO6V7D4CFLU7VP2CSZM63SCP56WQU4F2PCJY6XIVL5IBHRLO35DXJ6U
#\\\|33SBIXLYJN5CP2OPVQZWYV7VLKOF3JX3KIGR7QCAJDTR2KK65SW \ / AMOS7 \ YOURUM ::
#\[7]HSUP5JZ5LZXZENW25DL6HLYXPLGUBHW5M5C3UR3MNVSMQIEMYCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
