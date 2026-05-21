---
name: topic-reference-bubble
description: dancing zenki rhizome state as generic reference bubble — self-updating processing template traveling hyperspace routes
metadata: 
  node_type: memory
  type: project
  originSessionId: 4b3850d2-8acb-4166-bbdf-ddf52d8182ba
---

design doc: `data/md/design/DANCING-ZENKI-RHIZOME-STATE.md`

## core concept

the traveling rhizome state is simultaneously:
- template of how to process incoming information
- record of how past information was processed
- self-updating via non-destructive relevance deduplication

generalizes to: any zenka group doing any work carries this as a
**reference bubble** — self-contained, self-verifying, direction-declaring.

## formation

setup zenka [01 / rhizome in] → 5 ground zenki [process/vote/dedup] → collector [10 / rhizome out]

last wave's `10` output = this wave's `01` input. closed loop.

## checksum tree wire format

- `1 [N zeros] 1` = separator; N = bit-length of checksummed content
- `01` = toward source (collapsing direction)
- `10` = toward leaves (expanding direction)
- `11` = pivot / LCA / direction reversal
- `00` = reserved
- `0` and `1` both excluded from BASE32 [2-9A-Z] — unambiguous structure
- checksum length identifies algorithm (AMOS=7 chars etc); type-free
- a route writes its own topology: `[A] 01 01 [LCA] 10 [B]`

## universal applicability

same bubble structure at every layer: transport, inference, routing,
file access, dedup, branch namespace, consensus voting.

## connections

- `branch.route.cache` = bubble's trail (improved at each hop)
- `llm.service.consensus_vote` = 5-of-7 ground zenki layer
- `reasoning.branch.*` = bubble formation results
- stream framing protocol `dot=0 comma=1` maps to `01`/`10`/`1[zeros]1`

## node as virtual zenka position

every branch node IS a zenka seat. occupied bit = the bubble.
the bubble IS the occupied bit, traveling. positions remember it was there.

#,,.,,...,,.,,...,.,.,..,,,.,,.,,,,,,,...,,,.,..,,...,..,,,.,,,,,,,,.,,,,,.,,,
#OFYYEWYQYYAJQMBRLXCS2OV4YVJ3KKZZJM34JEJCPFVT4TEFMJEZ3JLTKR5DF7RHY7N7KT642NA52
#\\\|CJXUWJBTJQNJNQHUTLJSMXPP6DX5OH73SHUFWKROLSYD2YYIS7D \ / AMOS7 \ YOURUM ::
#\[7]QR22OHZJFI2IGIYVODQHUXYA6WPZKPHSUX6ZINHMBE7RJ3EAZUAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
