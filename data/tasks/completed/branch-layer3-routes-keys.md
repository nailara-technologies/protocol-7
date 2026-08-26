# task: branch layer 3 — interest routes + key propagation

## context

`branch.*` is Protocol-7's unifying addressable layer. layer 1 is implemented.
this task implements layer 3: on-demand interest routes from an observer to a
target branch node, with automatic key propagation along established routes.

see `data/md/design/BRANCH-NAMESPACE-MASTER.md` for the full architecture.

## concept

an interest route is an on-demand path between an observer node and a target node.
when the route is established, public keys are propagated along each hop so that
forwarding zenki can validate and route messages without a central authority.
when the observer disconnects or calls branch.route.release, the path tears down.

```
observer → hop-A → hop-B → target
              ↑ key for hop-A propagated
                       ↑ key for hop-B propagated
```

## what to implement

**`branch.route.establish`**
```
# param = { observer, target, ttl }
# observer = node_id or local session id
# target   = node_id
# ttl      = seconds before auto-release (default: 3600)

compute path from observer to target by walking branch tree
[ simplest: find LCA, then target's path from LCA ]
store route in $data{'branch.routes'}{$route_id} = {
    id        => $route_id,   ## AMOS chksum of observer::target::ntime
    observer  => $observer,
    target    => $target,
    hops      => [ $node_id, ... ],   ## ordered hop list
    created   => $ntime,
    ttl       => $ttl,
    keys      => {},   ## hop_id => propagated_pubkey
    state     => 'pending',   ## pending | active | released
}
trigger branch.route.key.propagate for each hop
return { mode => 'true', data => $route_id }
```

**`branch.route.release`**
```
# param = route_id [ string or { id => ... } ]
mark route state = 'released'
clean up $data{'branch.routes.by_observer'}{$observer}{$route_id}
clean up $data{'branch.routes.by_target'}{$target}{$route_id}
log at level 2
return { mode => 'true', data => $route_id }
```

**`branch.route.list`**
```
# param = { observer } or { target } or {} for all routes
list active routes filtered by observer or target
return [ { id, observer, target, hop_count, state, age_seconds }, ... ]
age_seconds = base.time - created (numerical ntime subtraction)
```

**`branch.route.key.propagate`**
```
# param = { route_id }
for each hop in route, retrieve or request pubkey:
  if $data{'branch.nodes'}{$hop_id}{'pubkey'} is set: use it
  else: call branch.route.key.request for that hop

store collected keys in route's 'keys' hash
when all hops have keys: set route state = 'active'
trigger branch.discover.announce with event = 'route-ready' if discover loaded
return { mode => 'true', data => $keys_collected }
```

**`branch.route.key.request`**
```
# param = { node_id, route_id }
send route-send to discover zenka: 'discover.key.request'
args: YAML { node_id, route_id, requestor_pubkey }
reply handler: store key in
  $data{'branch.nodes'}{$node_id}{'pubkey'} and
  $data{'branch.routes'}{$route_id}{'keys'}{$node_id}
then call branch.route.key.propagate to re-check if route is now complete
return { mode => 'true', data => 'requested' }
```

**`branch.route.key.verify`**
```
# param = { route_id, hop_id, pubkey }
verify that pubkey matches expected key for hop in route
compare against $data{'branch.routes'}{$route_id}{'keys'}{$hop_id}
return { mode => 'true', data => 'verified' }
     or { mode => 'false', data => 'mismatch' }
```

## wave propagation model

routes do not compute the full path upfront. instead, `branch.route.establish`
emits a **relationship window** — a small bubble carrying observer context and
partial key material. the wave:

1. advances one hop at a time through the branch tree
2. improves cached route state at each hop node:
   `$data{'branch.route.cache'}{$hop_id}{$target_id} = { next_hop, key, ntime }`
3. re-emits from the improved hop toward target
4. when it reaches target: route is live

a later, better wave (shorter path, fresher keys) overwrites the cached state
along the same hop nodes. each node is simultaneously a position and a router.

implementation note: the initial version may use a simple recursive call rather
than a full async wave emit — that is acceptable. the cache structure should be
written to support wave-style updates regardless of how the wave is driven.

node as virtual zenka position: a branch node holds everything a zenka needs
(checksum id, key, resources, group membership). the 'occupied' bit is the
only difference. zenka doesn't carry position — it becomes the position.
the node persists; the zenka is what is currently sitting in the seat.

## TTL / cleanup timer

in `branch.init_code` or a separate `branch.route.init` module:
register a repeating timer (interval 60, repeat => TRUE) that:
  - sweeps expired routes (age > ttl)
  - calls branch.route.release on each expired route
  - logs count at level 2

## patterns to follow

- existing `branch.*` modules for style
- `route-send` for cross-zenka calls; args as YAML string (no multiline)
- AMOS checksum for route_id: swap-boundary pattern
- `$data{'branch.routes'}` and `$data{'branch.routes.by_observer'}` for indexes

## code style

- lowercase comments, `[ word ]` annotations
- `$ARG` not `$_`; TRUE/FALSE constants
- no signature stubs

## success criteria

- [ ] `branch.route.establish` creates route with hop list from tree traversal
- [ ] `branch.route.release` cleans up both observer + target indexes
- [ ] `branch.route.list` filters correctly by observer or target
- [ ] `branch.route.key.propagate` collects keys, sets state = 'active'
- [ ] `branch.route.key.request` sends discover query, reply handler stores key
- [ ] `branch.route.key.verify` compares and returns true/false
- [ ] TTL cleanup timer correctly expires stale routes
- [ ] all modules pass `ptd`
- [ ] no signature stubs

## dispatch note

parallel-safe with `branch-layer2-discover-groups.md` and `branch-dep-graph.md`.

#,,..,,,,,,,.,,.,,,.,,.,,,..,,,.,,,..,,.,,.,.,..,,...,...,.,.,.,.,..,,.,,,...,
#GJP7Y3FUKCIHVAFXCT7S6ZB63V52DW7IGQOZUGTXH5B7KLQKORQGT2P7ZKIA2Z3QTEX7XOLF2C6KQ
#\\\|SSADXGOI4Z46KPCM6OIWGP7FXDA2UH2HZODLSR7VHMZE62WIJEX \ / AMOS7 \ YOURUM ::
#\[7]PKKHAVFN55M2ER32ITYECQRLFBEOZBAI75GQQ4ZO4EK3URWSBSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
