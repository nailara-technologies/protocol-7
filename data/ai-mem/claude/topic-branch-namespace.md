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
`cfg/zenki/branch/start` + `zenka-startup.v7` (on-demand, no idle timeout)
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

## branch universal theory cluster (session 49)

new namespaces implementing the branch unified theory:

| modules | count | status |
|---|---|---|
| branch.field.* (open/close/grow/split/capacity/boundary/axes/parent_id) | 9 | DONE |
| branch.calc.fraction.* (period/length/terminates/remainder_seq/parent_lookup/reverse_scale/coupling_find/symmetry/ring_position/prefix_entropy) | 10 | DONE |
| branch.cluster.* (address/ring_position/layers_list/gate_node/family/mirror/validate/register) | 8 | DONE |
| branch.session.* (round.checksum/chain.verify/jump/return_slot.*/fork/dag.*/policy.*) | 14 | DONE |
| tree.sort.trunk.* (project/cancel_symmetric/remainder/halve_frequency/field_self) | 5 | DONE |
| tree.route.page.* (word_type/word_route/word_graphical/encode_56/decode_56/bit_direction/read/rollover/extract/suction/attach/navigate) | 12 | DONE |

design doc: `data/md/design/BRANCH-OPEN-CAPACITY-SESSION-DAG.md`
reasoning template: `data/yaml/reasoning-templates/branch-open-field-hop.yaml`
harmonic registry: `data/yaml/harmonic/fraction-period-groups.yaml`
cluster registry: `data/yaml/cluster-registry/_index.yaml`

key theory additions this session:
- Z.Y.X depth-first coordinate ordering (segment→row→col = most-established→frontier)
- three Z-states as character rotation: in-transit(0)/paused(1)/edge-on(absent)
- rollover dual semantics: bi-location collapse OR absence propagation (same gate, opposite reasons)
- chained usefulness as hop selector: harmonic truth density × remaining capacity across chain
- mask/canvas orthogonality: structural mask (sparse 1-bits) + content canvas (zero-background)
- type prefix → ASCII control hierarchy: 00=nav, 010=US, 0110=GS, 1=RS
- element-efficient holographic devices: functional overlap reveals latent functions in existing elements

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

#,,..,,,,,..,,...,,..,..,,,,.,.,.,.,,,,,,,..,,..,,...,...,..,,,,.,,,,,.,,,...,
#YZ3U2LY22ID3M5ZN4GER2TOZDDZ4DIG7AFWCJWUKC7BGC627WNOKEOFNYGA4776KAH4YSEMUI4B2Y
#\\\|XCB6TNFV2LHLTSIZLCS4UYTJ2C3OQUYYB6SU6AFML2GFOIDJM25 \ / AMOS7 \ YOURUM ::
#\[7]REMSDEMLUQ5PEQ46K63C2OEJPRTOYBVB7N2GMWBWWE6F6RQ3NECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
