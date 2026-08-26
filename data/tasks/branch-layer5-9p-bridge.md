# task: branch layer 5 — 9P bridge

## context

`branch.*` is Protocol-7's unifying addressable layer. this task implements
layer 5: exposing a branch subtree as a 9P filesystem server, and mounting
remote 9P namespaces (WSL host, QEMU VirtFS, remote P7 instances) into branch.

prerequisites: layers 2–4 complete (groups, routes, storage).

see `data/md/design/BRANCH-NAMESPACE-MASTER.md` for full architecture.
see `data/md/design/9P-CLIENT.md` for existing `plan-9.client.*` modules.
see `data/md/design/9P-IMPLEMENTATION.md` and `9P-STORAGE-VISION.md` for context.

## important

do NOT reimplement 9P protocol framing. wrap and adapt `plan-9.client.*`.
the server side translates 9P operations into branch.* calls.
the client side translates branch.attach/detach into 9P walk/open/read.

## what to implement

**`branch.9p.server.init_code`**
```
serve a branch subtree as a 9P filesystem.
listen on unix socket or TCP port (configurable).
each 9P fid maps to a branch node_id.
store in $data{'branch.9p.server'} = { fids => {}, socket => ... }
fid table: $data{'branch.9p.server.fids'}{$fid} = { node_id, mode, offset }
register I/O handlers for incoming 9P messages
```

**`branch.9p.server.stat`**
```
# param = { fid }
return 9P Rstat for the branch node at fid
map branch node fields to 9P stat:
  qid.type = QTDIR if has children, else QTFILE
  qid.path = numerical hash of node_id
  qid.vers = 0
  name     = node's 'name' field
  length   = child count if dir, else resource size
  mtime    = ntime converted to unix timestamp
  uid/gid  = 'branch' / 'branch'
```

**`branch.9p.server.walk`**
```
# param = { fid, newfid, names => [ segment, ... ] }
walk address segments from fid's node through branch.resolve
each segment is a child name in branch.children
on success: create newfid entry pointing to final node
on failure: return Rerror with segment that failed
```

**`branch.9p.server.read`**
```
# param = { fid, offset, count }
if node is dir: return Rread with 9P directory entries for children
if node has resource attached: read resource data starting at offset
if node has no readable content: return empty Rread
```

**`branch.9p.server.write`**
```
# param = { fid, offset, data }
if node is writable (has file resource): update resource data
if node is a branch config point: route write to branch.resource.attach
return Rwrite with count of bytes written
```

**`branch.9p.client.mount`**
```
# param = { address, port, aname, node, name }
# address = host IP or unix socket path
# node    = branch node_id to mount under
# name    = mount point name in branch tree
# aname   = 9P attach name (root path on server)

use plan-9.client to connect and attach
create a branch node representing the mount root
store mount state in $data{'branch.9p.mounts'}{$mount_id} = {
    client => $plan9_client_ref,
    root_fid => $fid,
    node_id => $node_id,
    address => $address,
}
populate immediate children via 9P readdir of root
return { mode => 'true', data => $mount_id }
```

**`branch.9p.client.sync`**
```
# param = { mount_id, depth }
for a mounted 9P subtree: refresh branch children from remote 9P readdir
depth = how many levels deep to sync (default: 2, lazy deeper sync on access)
update branch nodes to reflect remote directory state
return { mode => 'true', data => { added, removed, unchanged } }
```

## fid lifecycle

```
Tattach → fid 0 = root node
Twalk   → new fid = walked-to node
Topen   → fid enters open state (mode stored)
Tread   → read content or children
Tclunk  → release fid from table
Tremove → branch.detach the node
```

## patterns to follow

- wrap `plan-9.client.*` for client side — never duplicate protocol framing
- server side: process 9P messages in IO::Async read handler
- fid table as local hash (not cross-session)

## code style

lowercase comments, `[ word ]` annotations, `$ARG`, no signature stubs.

## success criteria

- [ ] `branch.9p.server.walk` resolves multi-segment paths correctly
- [ ] `branch.9p.server.stat` returns correct qid.type for dirs vs files
- [ ] `branch.9p.server.read` returns dir entries in 9P format for dirs
- [ ] `branch.9p.client.mount` creates branch node and populates children
- [ ] `branch.9p.client.sync` adds/removes children to match remote state
- [ ] fid table manages lifecycle cleanly (no dangling fids after clunk)
- [ ] all modules pass `ptd`
- [ ] no signature stubs

## dispatch note

depends on layers 2–4. parallel-safe with `branch-layer6-file-abstraction.md`
once both are in round 3 (file abstraction depends on 9P bridge being defined).

#,,.,,..,,...,,,,,,,.,,,,,,,.,..,,..,,.,,,,..,..,,...,...,,..,...,,,,,,.,,,,.,
#UOJCTYJDH3XMR2A4E442FDVJ7V5J3TNLZRT3IF6M7LBN6KAVNDJ5QYWKFKQBL4CSKFTNFFI6SYN7S
#\\\|LEFACHWZ5HTWLCU2ELMMENXIBUQXMGT4KYVEE7IDL2CJJJVADAS \ / AMOS7 \ YOURUM ::
#\[7]LQ5FNJYDFYVT5W5CJXM5OF7C7N5IP7ASWQDKXK2VSHYQULME3QBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
