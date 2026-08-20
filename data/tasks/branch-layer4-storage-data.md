# task: branch layer 4 — storage persistence + data zenka binding

## context

`branch.*` is Protocol-7's unifying addressable layer. this task implements
layer 4: persisting branch subtrees to the storage zenka, restoring them,
and binding data zenka namespaces as branch subtrees.

prerequisite: `branch-layer3-routes-keys.md` (routes used to reach storage zenka).

see `data/md/design/BRANCH-NAMESPACE-MASTER.md` for the full architecture.
see `data/md/design/CONCEPT-DATA-ZENKA-ARCHITECTURE.md` for data zenka context.

## important constraint

the storage zenka is currently a stub. all storage modules must gracefully fall
back to local YAML persistence when the storage zenka is unavailable.
use `$data{'branch.storage.backend'}` to track 'storage-zenka' | 'local-yaml'.

local YAML path: `cfg/data/branch/nodes/` (one file per node_id).

## what to implement

**`branch.storage.persist`**
```
# param = { id, subtree, snapshot_name }
# id           = root node_id of subtree to persist
# subtree       = TRUE to include all descendants (default: TRUE)
# snapshot_name = optional label (else AMOS-chksum of id::ntime)

collect nodes to persist: [ root + all descendants if subtree=TRUE ]
for each node: serialize to YAML structure including:
  node record, children index, resource list (if branch.resources loaded)

if backend = 'storage-zenka':
  route-send 'storage.branch.persist' with YAML payload
  on reply: store snapshot_id in $data{'branch.storage.snapshots'}{$id}

if backend = 'local-yaml':
  write to cfg/data/branch/nodes/<snapshot_name>.yaml
  create path if missing

return { mode => 'true', data => $snapshot_id }
```

**`branch.storage.restore`**
```
# param = { snapshot_id, parent, name, merge }
# parent  = node_id to attach restored subtree under
# name    = attachment name (default: snapshot_id)
# merge   = TRUE to merge into existing nodes by checksum (default: FALSE)

load snapshot (from storage zenka or local YAML)
recreate nodes via branch.node.create with original id_payload
re-attach child relationships
if merge=TRUE: skip nodes whose id already exists in branch.nodes
return { mode => 'true', data => { root_id, nodes_restored, nodes_merged } }
```

**`branch.storage.sync`**
```
# param = { id, snapshot_id }
incremental sync: compare current subtree to last snapshot
find nodes added, changed, removed since snapshot
persist only the delta
update snapshot record with new ntime and delta count
return { mode => 'true', data => { added, changed, removed } }
```

**`branch.storage.list`**
```
# param = { id }  or  {} for all snapshots
list persisted snapshots with: snapshot_id, node_id, created, node_count, backend
return { mode => 'true', data => [ { snapshot_id, ... }, ... ] }
sorted by created descending
```

**`branch.data.bind`**
```
# param = { node, namespace, zenka }
# node      = branch node_id to bind under
# namespace = data zenka namespace (e.g. 'files.music')
# zenka     = zenka name (default: 'data')

send route-send to data zenka: 'data.branch.bind'
args: YAML { node_id, namespace }
on reply: store binding in $data{'branch.data.bindings'}{$node} = { namespace, zenka }
the data zenka will populate the branch subtree with its namespace entries
return { mode => 'true', data => $node }
```

**`branch.data.unbind`**
```
# param = { node }
send route-send 'data.branch.unbind' to data zenka
clear $data{'branch.data.bindings'}{$node}
optionally prune branch subtree that was populated by the binding
return { mode => 'true', data => $node }
```

**`branch.data.query`**
```
# param = { node, query }
send query through the branch node to its bound data zenka namespace
route-send 'data.branch.query' with { node_id, query }
return query_id (async; result arrives via reply handler)
```

## local YAML fallback structure

```yaml
## cfg/data/branch/nodes/<snapshot_name>.yaml
snapshot_id: ABCDEFG
created: <ntime>
root_id: HIJKLMN
nodes:
  HIJKLMN:
    name: users
    parent: ~
    face: 0
    created: <ntime>
    pubkey: ''
    groups: []
    meta: {}
  ...
children:
  HIJKLMN:
    taeki: OPQRSTU
  ...
```

## patterns to follow

- existing `branch.*` modules for style
- `route-send` for storage/data zenka calls
- YAML::XS for serialization
- swap-boundary checksum for snapshot_id generation
- graceful degradation to local YAML

## code style

lowercase comments, `[ word ]` annotations, `$ARG`, no signature stubs.

## success criteria

- [ ] `branch.storage.persist` writes YAML when storage zenka unavailable
- [ ] `branch.storage.restore` recreates subtree from YAML correctly
- [ ] `branch.storage.sync` correctly identifies delta (added/changed/removed)
- [ ] `branch.data.bind` sends route-send and stores binding
- [ ] `branch.data.query` routes query through bound zenka
- [ ] all modules pass `ptd`
- [ ] no signature stubs

## dispatch note

depends on round 1 complete. parallel-safe with `branch-layer7-resource-attach.md`.

#,,,,,,,.,,.,,..,,,..,,,.,,.,,.,,,.,,,.,,,,,.,..,,...,...,,,,,,..,,,,,,..,,,.,
#LKYQGX7RPWJ4RKDIYDLF66KFY43TEQFOWTN6PTKLZWAAID7YFRE6TEJUWZVLVVGE5JZ2ICHGR6K4M
#\\\|LDQI2IOPLWG6TSYNGYUQE5QUFFAVBL4BJCGN4SACXAPM6MCIGAY \ / AMOS7 \ YOURUM ::
#\[7]CXGO7I4UMQLEZXP52UIQW5VEHOHDCETD5D7AW3AYYVYKL7GVN4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
