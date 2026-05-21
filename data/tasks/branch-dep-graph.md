# task: branch dependency graph

## context

`branch.*` is Protocol-7's unifying addressable layer. this task implements the
dependency graph layer: directed dependency edges between branch nodes, used by
task orchestration, capability gating, zenka lifecycle management, and any system
that needs to express "X depends on Y being ready."

this is orthogonal to both the tree address structure and the reference groups —
a third dimension of relationship.

see `data/md/design/BRANCH-NAMESPACE-MASTER.md` for the full architecture.

## what to implement

**`branch.dep.declare`**
```
# param = { from, to, type }
# from = dependent node_id
# to   = dependency node_id
# type = 'required' | 'soft' | 'order'  (default: required)
#
# 'required': from cannot be satisfied unless to is satisfied
# 'soft':     from prefers to be satisfied, but can proceed without
# 'order':    from must start after to, no satisfaction gate

create edge in $data{'branch.deps'}{$from}{$to} = { type, declared_at }
create reverse index in $data{'branch.dep.reverse'}{$to}{$from} = TRUE
reject if edge already exists (idempotent call returns true)
return { mode => 'true', data => "$from -> $to [$type]" }
```

**`branch.dep.remove`**
```
# param = { from, to }  or  { from }  (remove all deps of a node)
remove edge(s), clean up reverse index
return { mode => 'true', data => $edges_removed }
```

**`branch.dep.check`**
```
# param = node_id [ string or { id => ... } ]
check whether all 'required' deps of a node are satisfied.
a dep is satisfied when $data{'branch.nodes'}{$dep_id}{'satisfied'} == TRUE
return { mode => 'true',  data => 'satisfied' }
     or { mode => 'false', data => [ $unsatisfied_dep_id, ... ] }
```

**`branch.dep.mark`**
```
# param = { id, state }  state = 'satisfied' | 'unsatisfied' | 'failed'
mark a node's satisfaction state
store in $data{'branch.nodes'}{$node_id}{'satisfied'} = $state
call branch.dep.propagate to update upstream dependents
return { mode => 'true', data => $state }
```

**`branch.dep.propagate`**
```
# param = node_id  (the node whose state just changed)
walk reverse dep index upward:
  for each node that depends on this node:
    call branch.dep.check
    if now satisfied and was not before: call branch.dep.mark satisfied
    continue propagating upward
use a visited-set to stop cycles
return { mode => 'true', data => $nodes_updated }
```

**`branch.dep.resolve`**
```
# param = node_id [ string or { id } or { address } ]
return topological sort of all transitive deps of a node
Kahn's algorithm: BFS from leaves toward the root
return { mode => 'true',  data => [ $node_id, ... ] }  # leaves first
     or { mode => 'false', data => 'cycle detected' }
```

**`branch.dep.cycle`**
```
# param = node_id or {} for global check
detect cycles in dep graph reachable from node (or globally)
DFS with gray/black coloring
return { mode => 'false', data => [ cycle path as node_ids ] }  if cycle found
     or { mode => 'true',  data => 'no cycles' }
```

**`branch.dep.graph`**
```
# param = { root, format, depth }
# format = 'ascii' | 'dot'  (default: ascii)
# depth  = max depth to show (default: 5)
emit dependency graph as ASCII tree or DOT notation
ASCII format example:
  ABCDEFG  (root node)
  ├── HIJKLMN  [required]
  │   └── OPQRSTU  [required]
  └── VWXYZA2  [soft]
DOT format:
  digraph branch_deps {
    "ABCDEFG" -> "HIJKLMN" [label="required"]
    ...
  }
return { mode => 'true', data => $output_string }
```

## state storage

```perl
$data{'branch.deps'}         ## from_id → { to_id → { type, declared_at } }
$data{'branch.dep.reverse'}  ## to_id → { from_id → TRUE }
## satisfaction state stored on node itself:
$data{'branch.nodes'}{$id}{'satisfied'}  ## undef | 'satisfied' | 'unsatisfied' | 'failed'
```

## patterns to follow

- existing `branch.*` modules for style
- swap-boundary checksum pattern if node IDs need to be generated
- Kahn's algorithm for topological sort
- DFS with three-color marking (white/gray/black) for cycle detection

## code style

- lowercase comments, `[ word ]` annotations
- `$ARG` not `$_`; TRUE/FALSE/UNKNOWN constants
- no signature stubs — run `bin/Protocol-7 sourcecode update-signatures` when done

## success criteria

- [ ] `branch.dep.declare` creates bidirectional edge correctly
- [ ] `branch.dep.remove { from }` removes all edges for a node
- [ ] `branch.dep.check` returns list of unsatisfied required deps
- [ ] `branch.dep.mark` updates state and triggers propagation
- [ ] `branch.dep.propagate` walks reverse index without infinite loops
- [ ] `branch.dep.resolve` returns topological order, detects cycles
- [ ] `branch.dep.cycle` correctly identifies cycle paths
- [ ] `branch.dep.graph` ascii mode outputs readable tree
- [ ] all modules pass `ptd`
- [ ] no signature stubs

## dispatch note

parallel-safe with `branch-layer2-discover-groups.md` and `branch-layer3-routes-keys.md`.
uses `$data{'branch.deps'}` and `$data{'branch.dep.reverse'}` — no overlap.

#,,,,,,.,,,..,...,,..,,..,.,,,,..,...,.,.,,..,..,,...,..,,...,.,,,,,.,..,,,.,,
#PI7AL7G5LSV322JAF6A67VH6CC2V2N2MUGPXIWFPQSSL6XD53MAFXF7QSVCS2NONXR7MLCAFQMKI4
#\\\|JISFLPNUYX2STTJ3V3V4K5KJFTWGALDFPOJGXOCPSLMMK3S32Y5 \ / AMOS7 \ YOURUM ::
#\[7]KQLUN2JHQWAWJGFHBC4G3G2KZFWWWWCKC3FGHYBOFDH62UNK6UCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
