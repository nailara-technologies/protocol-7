---
name: feedback-p7-data-nesting
description: "<a.b.c> in P7 = $data{a}{b}{c} nested hash — NOT flat dotted keys; designing sibling metadata requires underscore separator"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f5b14fde-ecec-4f58-b7f2-95aaab875b62
---

`<a.b.c>` compiles to `$data{'a'}{'b'}{'c'}` — every dot is a nesting level.

**Why:** `bin/Protocol-7` lines 1720-1722 transform angle-bracket accessors with full nesting. Discovered when `<memory.focus.floor>` stored metadata INSIDE the focus topics hash, causing the decay loop to iterate metadata as topics.

**How to apply:** When designing sibling keys (metadata alongside data), use underscore not dot: `<memory.focus_floor>` (sibling of `<memory.focus>`) vs `<memory.focus.floor>` (child inside focus hash). Dot = nesting, underscore = same level. Critical rule: **never store an index or back-reference inside the data structure it indexes** — `<memory.tree.index>` inside the tree root creates a circular reference that causes deep recursion in `base.dump.data_key_list`. Use `<memory.tree_index>` instead.

#,,.,,.,.,,.,,.,.,,,.,..,,..,,,,,,...,.,,,...,..,,...,...,,,,,.,,,,.,,,.,,..,,
#W2BTUCMN6SAYPTQ3DAAQA54EFQZ52FMU24PO34U4SD5OIH4654SUWRXJMQH2I53NZKTBMJGXLX5E2
#\\\|V4LXMVY22A47KMRHS4CTZYJTM7EVV55OZJOVWZ3EP6KWAQCAAFE \ / AMOS7 \ YOURUM ::
#\[7]7KCQIDFXC6LH3XVWDBRK6YS3FDGHOTAPX6V4ZIVRGXBZ7DELAQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
