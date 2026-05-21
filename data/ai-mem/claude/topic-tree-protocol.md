---
name: topic-tree-protocol
description: TREE protocol — structural control layer parallel to DATA; node metadata + REF pointers; bi-directional; namespace registry for all DATA streams
metadata: 
  node_type: memory
  type: project
  originSessionId: 4b3850d2-8acb-4166-bbdf-ddf52d8182ba
---

design doc: `data/md/design/TREE-PROTOCOL.md`
related: [[topic-data-protocol]], [[topic-perspective-layers]], [[topic-observer-centric-space]]

## duality

DATA = devmod.cmd.dump (values, bytes, content)
TREE = devmod.cmd.dump-keys (structure, metadata, references to content)
same branch namespace; protocol choice = observer's current intent.

## wire format

```
TREE <tree_id> <B32_root_id>\n              open
<B32_node_id> <B32_parent_id> <B32_meta>\n  node line (ref count desc order)
TREE REF <tree_id> <node_id> <stream_id>\n  content available as DATA stream
TREE END <tree_id> <AMOS_CHECKSUM>\n        close
```

B32_meta = name + ref_count + face(0-7) + child_count + group checksums
AMOS close checksum = checksum of all node IDs (structural integrity)

## control commands

TREE QUERY <tree_id> <root> <depth>   — request subtree
TREE REGISTER <namespace> <root_id>   — register named namespace
TREE LIST                             — list all registered namespaces
TREE DELTA <tree_id> <base_chksum>    — structural delta (mirrors DATA DELTA)
TREE ACK <tree_id> <seq>              — backpressure

## namespace registry

every DATA stream is registered via TREE REF before it opens.
TREE is persistent; DATA is ephemeral.
TREE = the directory. DATA = the files.
TREE is the ultimately controlling layer — no DATA without a TREE REF.

## perspective and choice

node IS simultaneously a TREE position (structure) AND a DATA source (content).
discovery/navigation → TREE QUERY
content consumption → follow TREE REF → open DATA stream
sync → TREE DELTA then DATA DELTA

## to implement

add TREE branch to base.callback.cmd_reply (after DATA branch).
node lines ordered by base.reverse-sort (reference count descending).
stream_id = AMOS_chksum(node_id::face_id::ntime).

#,,..,,,,,..,,,..,,,.,,,,,.,.,,..,...,,.,,.,,,..,,...,...,.,.,.,,,.,.,..,,..,,
#GR3BQX37L72SIBQM6GCDZ5YBEP5HYMG2C7MMEQDMERK2IGXQTH7ITA7AYXRVAEUOYBXYFZ6WEILHK
#\\\|2MKD6XH2FAA5ANBTBYJREBVD7DGMU35TTSQEIHT2SJ5ELXGTUAA \ / AMOS7 \ YOURUM ::
#\[7]JCABCMKZZGWSXRINSDPJ7B64XF4IZQTAO6EMOYAAEW46J6BFVIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
