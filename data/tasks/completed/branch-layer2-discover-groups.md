# task: branch layer 2 — discover integration + extended groups

## context

`branch.*` is Protocol-7's unifying addressable layer. layer 1 (core identity,
attach/detach, resolve, list, groups.add, groups.members) is already implemented
and ptd-verified. this task implements layer 2: group management extensions and
discover zenka integration.

see `data/md/design/BRANCH-NAMESPACE-MASTER.md` for the full architecture.

## what to implement

### group management extensions

these complete the group API alongside the existing `branch.group.add` and
`branch.group.members` modules.

**`branch.group.remove`**
```
# param = { id, group }  or  { id }  to remove from all groups
remove node from one or all reference groups
clean up both directions: groups registry and node's groups list
return { mode => 'true', data => remaining_member_count }
or { mode => 'true', data => 'removed from all groups' }
```

**`branch.group.list`**
```
# param = none or { pattern }  (substring match on group name)
list all groups with member count and first 3 member ids
return { mode => 'true', data => [ { name, count, sample => [...] }, ... ] }
sorted by count descending
```

**`branch.group.propagate`**
```
# param = { group, observer }
# observer = node_id of the observer perspective
propagate interest count: walk each group member's parent chain upward,
increment a transient count on each ancestor node toward the observer.
store in $data{'branch.interest'}{$observer_id}{$ancestor_id} = $count
return { mode => 'true', data => $total_nodes_touched }
this is the 'relevant elements propagate toward the observer' mechanism.
```

### discover zenka integration

the discover zenka maintains a network-wide index of named resources.
branch nodes can register themselves to be findable across zenki.

**`branch.discover.register`**
```
# param = { id, name, groups, meta }
send registration to discover zenka via route-send:
  command: 'discover.branch.register'
  args: YAML { node_id, address (from branch.node.path), groups, meta }
store pending registration in $data{'branch.discover.pending'}{$node_id}
on reply: mark $data{'branch.nodes'}{$node_id}{'discovered'} = TRUE
return { mode => 'true', data => $node_id }
```

**`branch.discover.resolve`**
```
# param = { name }  or  { group }  or  { id }
query discover zenka for nodes matching criteria
send: 'discover.branch.query' with args YAML { name/group/id }
reply handler stores result in $data{'branch.discover.results'}{$query_id}
return query_id immediately (async); caller polls or uses reply.handler
```

**`branch.discover.announce`**
```
# param = { id, event }  event = 'available' | 'changed' | 'removed'
announce a node state change to discover zenka
used after branch.attach / branch.detach to keep discover index current
send: 'discover.branch.announce'
args: YAML { node_id, address, event, ntime }
fire-and-forget (no reply needed)
return { mode => 'true', data => $event }
```

**`branch.discover.watch`**
```
# param = { subtree, handler }
# subtree = node_id or address to watch for discover events under
# handler = local module name to call when event arrives
register a watcher for discover events affecting a subtree
store in $data{'branch.discover.watchers'}{$subtree} = $handler
discover zenka should send 'branch.discover.event' commands to this zenka
when matching events occur
return { mode => 'true', data => $subtree }
```

## patterns to follow

- existing `branch.*` modules for style reference
- `route-send` for all cross-zenka calls (see critical-patterns.md)
- `$data{'branch.*'}` for all state storage
- swap-boundary checksum: `$code{'chk-sum.amos'} // $code{'base.chk-sum.amos'}`
- `<[base.logs]>->( 2, 'branch.X: %s', ... )` for debug logging
- return `{ mode => 'true'/'false', data => ... }` consistently

## code style

- lowercase comments, `[ word ]` annotations
- `$ARG` not `$_`; `TRUE` not 1 for boolean config
- no signature stubs — run `bin/Protocol-7 sourcecode update-signatures` when done

## success criteria

- [ ] `branch.group.remove` removes from one or all groups cleanly
- [ ] `branch.group.list` returns sorted by count with sample members
- [ ] `branch.group.propagate` increments interest counts on ancestor chain
- [ ] `branch.discover.register` sends route-send to discover zenka
- [ ] `branch.discover.announce` fires after attach/detach without blocking
- [ ] `branch.discover.watch` stores watcher and receives events
- [ ] all modules pass `ptd`
- [ ] no signature stubs at end of files

## dispatch note

this task is parallel-safe with `branch-layer3-routes-keys.md` and
`branch-dep-graph.md` — they touch non-overlapping `%data` keys.

#,,..,,,.,,.,,,,,,.,.,,.,,..,,...,.,.,,,,,,..,..,,...,..,,.,.,..,,,,.,.,.,.,.,
#OZZLHFGHZ4JQDSM6C3XLM3AJYSEIZZCT2A7K5DRQ7CVSJGTVESGKYKQMJ47AN7DE3A63QRJS6KHDK
#\\\|ZKACEN6N3NNIBZIICLERDMAF3Q6G3MWDYHQVNIUOJ4UPUQQ4GON \ / AMOS7 \ YOURUM ::
#\[7]YT3ITV4PW6LP4P3Z5H22C62OD57WRHVEXSU7IB6UKUEWSZTRIOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
