---
name: topic-branch-namespace
description: branch.* namespace — unifying addressable layer; layers 1-3 + dep + resource API DONE; layer 4 dispatched
metadata: 
  node_type: memory
  type: project
  originSessionId: 4b3850d2-8acb-4166-bbdf-ddf52d8182ba
---

`branch.*` is the unifying addressable layer for Protocol-7. every resource
(context buffers, tasks, streams, files, zenki, storage, keys) can be attached to
a branch node and addressed uniformly. node identity is a permanent AMOS checksum
derived at creation; tree position is secondary.

## completed modules (session 43)

### layer 1 — core identity (10 modules)
`branch.init_code`, `branch.node.create`, `branch.attach`, `branch.detach`,
`branch.resolve`, `branch.list`, `branch.node.path`, `branch.node.info`,
`branch.group.add`, `branch.group.members`

node identity = AMOS-chksum( ntime :: pubkey :: parent :: name )
face field (0–7): cube face of origin; face 0 = 000 bits = network/branch/parent orientation

### layer 2 — discover + extended groups (9 modules)
`branch.group.remove`, `branch.group.list`, `branch.group.propagate`,
`branch.discover.register`, `branch.discover.resolve`, `branch.discover.announce`,
`branch.discover.watch`, `branch.discover.handler.register_reply`,
`branch.discover.handler.resolve_reply`

### layer 3 — routes + key propagation (9 modules)
`branch.route.establish`, `branch.route.release`, `branch.route.list`,
`branch.route.key.propagate`, `branch.route.key.request`,
`branch.route.key.handler.reply`, `branch.route.key.verify`,
`branch.route.timer.cleanup` + wave cache in init_code
wave cache: `$data{'branch.route.cache'}{$hop}{$target} = { next_hop, ntime }`

### dep graph layer (8 modules)
`branch.dep.declare`, `branch.dep.remove`, `branch.dep.check`, `branch.dep.mark`,
`branch.dep.propagate`, `branch.dep.resolve`, `branch.dep.cycle`, `branch.dep.graph`

### layer 7 — resource attachment API (8 modules)
`branch.resource.attach`, `branch.resource.detach`, `branch.resource.list`,
`branch.resource.get`, `branch.resource.find`, `branch.resource.context`,
`branch.resource.task`, `branch.resource.stream`
group-filter in branch.resource.find is LIVE (uses branch.group.members)

## zenka config — DONE
`configuration/zenki/branch/start` + `zenka-startup.v7` (on-demand, no idle timeout)
`cube/auth.zenki`: `auth.setup.usr.branch = :zenka:`
`cube/access.zenki`: wildcard routing for all `branch.*` namespaces

## design doc
`data/md/design/BRANCH-NAMESPACE-MASTER.md`

## task dispatch status

| task file | layer | status |
|---|---|---|
| core (session 43) | 1 | DONE |
| branch-layer2-discover-groups.md | 2 | DONE |
| branch-layer3-routes-keys.md | 3 | DONE |
| branch-dep-graph.md | dep | DONE |
| branch-layer7-resource-attach.md | 7 | DONE |
| branch-layer4-storage-data.md | 4 | DONE |
| branch-layer5-9p-bridge.md | 5 | dispatched round 3 |
| branch-layer6-file-abstraction.md | 6 | dispatched round 3 |

## wave routing + virtual zenka position (session 43)

route propagation = concentric waves; relationship window propagates as wave front,
leaves cached route state improvement behind each wave. implemented in
branch.route.establish with wave cache; future waves improve cached state further.

node as virtual zenka position: every node IS a zenka seat — checksum identity,
key, resources, group membership. only the occupied bit differs. zenka becomes
the position while there; node persists after.

## also this session (session 43)

- `devmod.cmd.dump-keys` — key tree from %data without values; base.sort (shortest
  keys land at bottom of listing)
- `base.dump_data` — added reverse_sort flag (default 0)
- `devmod.cmd.dump` — sets reverse_sort=TRUE so structural keys visible at scroll end

#,,..,..,,,..,.,,,.,,,.,,,..,,..,,.,.,,.,,...,..,,...,...,...,...,,..,,..,...,
#O7MUGRXDNDA7QMYCJ3FUB54K3BBP5L6Y7NU2BJXHJQ2A3X7663ZTK2Z467FC3RPM7RNK2FP2PPXEA
#\\\|HXHUFGZHZ5Q6EVTEG55Q4CSCH2IYAN7RV6ITTLU2LMCTAK5UCYX \ / AMOS7 \ YOURUM ::
#\[7]37QWIBJINTS6L5HNGXVAD6YYGW4HIHOUCOUZBXNPKJXRQDFIJ2CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
