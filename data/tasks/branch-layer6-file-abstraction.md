# task: branch layer 6 — file access abstraction

## context

`branch.*` is Protocol-7's unifying addressable layer. this task implements
layer 6: a uniform file access API (branch.file.*) that is backend-agnostic.
callers use `branch.file.open/read/write/stat/list/close` regardless of whether
the file lives on local fs, behind a 9P mount, or in the storage zenka.

prerequisites: layers 4 (storage) + 5 (9P bridge).

see `data/md/design/BRANCH-NAMESPACE-MASTER.md` for the full architecture.

## concept

each branch node can have a file adapter registered on it. the adapter handles
all file operations for that node and its children. adapters are registered at
mount/attach time; callers never need to know which backend is active.

```
branch.file.open({ node, path, mode })
  → look up adapter for node
  → delegate to adapter.local / adapter.9p / adapter.storage
  → return file handle
```

## what to implement

**`branch.file.adapter.register`**
```
# param = { node, adapter, config }
# adapter = 'local' | '9p' | 'storage'
# config  = adapter-specific config hash
store adapter in $data{'branch.file.adapters'}{$node_id} = { adapter, config }
return { mode => 'true', data => $node_id }
```

**`branch.file.adapter.resolve`**
```
# param = node_id
walk node's parent chain to find nearest registered adapter
return { adapter_name, node_id_where_registered, config }
used internally by all branch.file.* operations
```

**`branch.file.open`**
```
# param = { node, path, mode }
# node = branch node_id (adapter lookup from here)
# path = relative path within the adapter's namespace
# mode = 'r' | 'w' | 'rw' | 'a'
resolve adapter, delegate to branch.file.adapter.<name>.open
generate file handle id: AMOS chksum of node::path::ntime
store in $data{'branch.file.handles'}{$fh_id} = { adapter, path, mode, pos }
return { mode => 'true', data => $fh_id }
```

**`branch.file.read`**
```
# param = { fh, length, offset }  or  { fh, length }
read from file handle; delegate to adapter
return { mode => 'true', data => \$bytes }  (scalar ref)
```

**`branch.file.write`**
```
# param = { fh, data }
write to file handle; delegate to adapter
return { mode => 'true', data => $bytes_written }
```

**`branch.file.stat`**
```
# param = { node, path }  or  { fh }
stat a path or open file handle
return { mode => 'true', data => { size, mtime, type, name } }
type = 'file' | 'dir' | 'link'
```

**`branch.file.list`**
```
# param = { node, path }
list directory contents at path under node's adapter
return { mode => 'true', data => [ { name, type, size, mtime }, ... ] }
```

**`branch.file.close`**
```
# param = { fh }
flush and close, remove from $data{'branch.file.handles'}
return { mode => 'true', data => 'closed' }
```

### adapter modules

**`branch.file.adapter.local`**
```
implements: open, read, write, stat, list, close
using sysopen/sysread/syswrite/stat/opendir
path is an absolute local filesystem path
config: { root => '/absolute/base/path' }
all paths are joined under root (no path traversal: reject '..' components)
```

**`branch.file.adapter.9p`**
```
implements: open, read, write, stat, list, close
delegates to branch.9p.client.* operations
uses the mount_id stored in the adapter config
config: { mount_id => $id, root_fid => $fid }
```

**`branch.file.adapter.storage`**
```
implements: open, read, write, stat, list, close
delegates to branch.storage.* for content-addressed retrieval
config: { zenka => 'storage', namespace => $ns }
```

## security note

`branch.file.adapter.local` MUST reject any path component that is `..` or
contains a NUL byte. validate before any filesystem call.

## patterns to follow

- existing `branch.*` modules for style
- File::stat::stat() for stat (not builtin — see critical-patterns.md)
- `\$content` scalar ref return from read (matches base.file.slurp pattern)
- adapter resolution walks parent chain — cache result in handle

## code style

lowercase comments, `[ word ]` annotations, `$ARG`, no signature stubs.

## success criteria

- [ ] `branch.file.adapter.register` stores adapter config
- [ ] `branch.file.adapter.resolve` walks parent chain for nearest adapter
- [ ] `branch.file.open` returns unique handle id, stores in handle table
- [ ] `branch.file.read` returns scalar ref content
- [ ] `branch.file.stat` returns { size, mtime, type, name }
- [ ] `branch.file.list` returns sorted entries with type
- [ ] `branch.file.adapter.local` rejects `..` and NUL in paths
- [ ] `branch.file.adapter.9p` delegates to branch.9p.client correctly
- [ ] `branch.file.close` removes handle from table cleanly
- [ ] all modules pass `ptd`
- [ ] no signature stubs

## dispatch note

round 3 task. depends on layer 5 (9P bridge) being complete.
parallel-safe with `branch-layer5-9p-bridge.md` if 9P bridge is written first
and this task references its interface.

#,,,,,,,.,..,,.,,,.,.,...,,..,.,.,.,,,.,,,,,,,..,,...,...,.,.,,,.,,..,,.,,,..,
#NSJYQZFS2T7X3ANBME2AP7IPDRJQDLOJ6VD6XCFLP5VLLYK2ESJ2R2G3HSBVH7H4VSK7G4FX72GNY
#\\\|FUW4BYHYHOKYAI2R6IKIQ22SH6VJJWCULIQ3BY5BOLR62663SOZ \ / AMOS7 \ YOURUM ::
#\[7]GDJJOIAIE7S5DP7E6SMWJHWYZ6SCOUJMWBIQARLFXOLB4OAMK2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
