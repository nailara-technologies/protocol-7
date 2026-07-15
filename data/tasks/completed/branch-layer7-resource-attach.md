# task: branch layer 7 — resource attachment API

## context

`branch.*` is Protocol-7's unifying addressable layer. this task implements the
resource attachment API: the primary integration surface for other zenki.
context buffers, tasks, STRM streams, file handles, and arbitrary typed resources
are all attached and retrieved through this layer.

prerequisite: `branch-layer2-discover-groups.md` (groups needed for resource discovery).

see `data/md/design/BRANCH-NAMESPACE-MASTER.md` for the full architecture.

## concept

a resource is any typed reference attached to a branch node. resources are
indexed by type. multiple resources of the same type can coexist on one node.
resource data is zenka-local (handle, ref, or small payload) — cross-zenka
sharing uses route-send, never direct reference.

```perl
$data{'branch.resources'}{$node_id}{$type} = [
    { id => $res_id, data => $resource_data, attached_at => $ntime },
    ...
]
```

## what to implement

**`branch.resource.attach`**
```
# param = { node, type, data, id }
# node = node_id
# type = 'context' | 'task' | 'stream' | 'file' | any string
# data = resource payload (handle, path, id ref, etc.)
# id   = optional explicit resource id (else AMOS-chksum generated)

validate node exists
generate res_id from AMOS chksum of node::type::ntime if not given
push resource record into $data{'branch.resources'}{$node}{$type}
return { mode => 'true', data => $res_id }
```

**`branch.resource.detach`**
```
# param = { node, type, id }  or  { node, type }  to remove all of type
# or     { node }  to remove all resources
remove matching resource records
return { mode => 'true', data => $removed_count }
```

**`branch.resource.list`**
```
# param = node_id or { node }
list all resources on a node grouped by type:
  { type => [ { id, data_summary, attached_at }, ... ], ... }
data_summary = first 40 chars of stringified data (for display)
return { mode => 'true', data => \%by_type }
```

**`branch.resource.get`**
```
# param = { node, type, id }
# id is optional — returns first match if omitted
return specific resource data
return { mode => 'true', data => $resource_data }
     or { mode => 'false', data => 'not found' }
```

**`branch.resource.find`**
```
# param = { type, filter }
# filter = sub ref or { key => val } match against resource data
scan all nodes for resources of given type matching filter
return [ { node_id, res_id, data }, ... ]
up to 100 results (log warning if capped)
```

### type-specific convenience modules

these are thin wrappers over branch.resource.attach/get with validation:

**`branch.resource.context`**
```
# param = { node, op, data }  op = 'attach' | 'get' | 'detach'
context buffer: data is a string (context text) or handle
attach: validate data is scalar or ref, call branch.resource.attach
get:    call branch.resource.get, return context data directly
detach: call branch.resource.detach
```

**`branch.resource.task`**
```
# param = { node, op, task_id }  op = 'attach' | 'get' | 'detach'
task reference: data is a task_id string
attach: validate task_id is non-empty, call branch.resource.attach
get:    return task_id
detach: remove task resource by id
```

**`branch.resource.stream`**
```
# param = { node, op, stream_handle }  op = 'attach' | 'get' | 'detach'
STRM stream handle attachment
attach: store stream handle ref
get:    retrieve handle
detach: release handle
```

## patterns to follow

- existing `branch.*` modules for style
- AMOS swap-boundary checksum for res_id generation
- `$data{'branch.resources'}` for resource storage

## code style

- lowercase comments, `[ word ]` annotations
- `$ARG` not `$_`; TRUE/FALSE constants
- no signature stubs

## success criteria

- [ ] `branch.resource.attach` generates unique res_id per attachment
- [ ] `branch.resource.detach { node }` removes all resources cleanly
- [ ] `branch.resource.list` returns grouped-by-type with data_summary
- [ ] `branch.resource.find` scans correctly, caps at 100
- [ ] convenience modules (context/task/stream) delegate correctly
- [ ] all modules pass `ptd`
- [ ] no signature stubs

## dispatch note

depends on round 1 being complete (layer 2 specifically for group-aware find).
parallel-safe with `branch-layer4-storage-data.md` in round 2.

#,,,.,.,.,,..,.,,,,.,,,,.,,,.,..,,,,.,..,,.,,,..,,...,...,..,,,..,...,,.,,.,.,
#ZSWPUHTIP7ATNSSMK2AIFV5SS2SBZSOV23JPYQ4SQMT7WCIKQM4HV3NQZHZGHXNW6K5DU42YCZELU
#\\\|DAFBK6DYGL6QETZ5L7KGZIQSTNRUKQZDTKQA4IJ4VJZ2KZCDKSK \ / AMOS7 \ YOURUM ::
#\[7]FJJV4YDKR3QKGE6VMGMBLXKE4Y3ADVVO5IAMNURNYCFAFXJB24DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
