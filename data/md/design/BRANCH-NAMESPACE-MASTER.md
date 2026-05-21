# branch.* namespace — master design and task tracker

## vision

`branch.*` is the unifying addressable layer for the Protocol-7 network.
every resource — context buffers, tasks, streams, files, zenki, external nodes,
storage volumes, key material — can be attached to a branch node and addressed
uniformly. the tree is a navigation structure; node identity is permanent and
cryptographic; attachment is fluid.

```
                    [ branch root ]
                    /       |       \
              users       services    external
              /   \          |           |
           taeki  guest    httpd      wsl-host
              |             |
           context        9p-mount
           tasks
           streams
```

the same node can also appear in any number of reference groups, orthogonal
to its tree position. groups propagate interest counts toward observers.

## layer architecture

```
layer 7 : application        tasks, chat, visualization, coding zenka
layer 6 : file abstraction   branch.file.* (local / 9P / storage adapters)
layer 5 : 9P bridge          branch.9p.* (serve branch as 9P, mount into branch)
layer 4 : storage + data     branch.storage.* + branch.data.* (persist, bind)
layer 3 : route + keys       branch.route.* (interest routes, auto-key-propagation)
layer 2 : discover + groups  branch.discover.* + branch.group.*
layer 1 : core identity      branch.node.* + branch.attach + branch.detach
                             branch.resolve + branch.list  [DONE]
```

layers build upward. a layer only depends on layers below it.
each layer can be dispatched and implemented independently.

## layer 1 — core identity [DONE]

modules implemented and ptd-verified:

| module | purpose |
|---|---|
| `branch.init_code` | per-zenka state init |
| `branch.node.create` | AMOS-checksum node commit: ntime+pubkey+parent+name |
| `branch.attach` | attach node to parent (auto-detaches from previous) |
| `branch.detach` | detach node; identity + subtree preserved |
| `branch.resolve` | walk dotted address → node id |
| `branch.list` | enumerate children with face / child_count / groups |
| `branch.node.path` | walk parents upward → dot-joined address |
| `branch.node.info` | node metadata + derived path + child_count |
| `branch.group.add` | add node to reference group (non-exclusive, idempotent) |
| `branch.group.members` | list group members with current path |

**node identity** = AMOS-chksum( ntime :: pubkey :: parent :: name )
**face** [ 0–7 ] : cube face of origin; face 0 [ 000 bits ] = network / branch / parent orientation

## layer 2 — discover + extended groups

**task file**: `data/tasks/branch-layer2-discover-groups.md`

| module | purpose |
|---|---|
| `branch.group.remove` | remove node from reference group |
| `branch.group.list` | list all groups with member counts |
| `branch.group.propagate` | propagate interest count toward named observer |
| `branch.discover.register` | register branch subtree with discover zenka |
| `branch.discover.resolve` | query discover for a node by name / group |
| `branch.discover.announce` | announce node availability / change |
| `branch.discover.watch` | subscribe to discover events for a subtree |

## layer 3 — route + key propagation

**task file**: `data/tasks/branch-layer3-routes-keys.md`

interest routes establish on-demand paths from an observer to a target node.
keys are auto-propagated along the route so routing is transparent.

| module | purpose |
|---|---|
| `branch.route.establish` | open interest route: observer → target node |
| `branch.route.release` | release route (tear down on-demand path) |
| `branch.route.list` | list active routes with hop counts |
| `branch.route.key.propagate` | auto-propagate public keys along route |
| `branch.route.key.request` | request missing key for a route segment |
| `branch.route.key.verify` | verify key material for a hop |

## layer 4 — storage + data persistence

**task file**: `data/tasks/branch-layer4-storage-data.md`

| module | purpose |
|---|---|
| `branch.storage.persist` | persist node + subtree to storage zenka |
| `branch.storage.restore` | restore subtree from storage |
| `branch.storage.sync` | incremental sync (only changed nodes) |
| `branch.storage.list` | list persisted snapshots for a node |
| `branch.data.bind` | bind data zenka namespace subtree to branch node |
| `branch.data.unbind` | unbind data zenka namespace |
| `branch.data.query` | query bound data zenka through branch interface |

## layer 5 — 9P bridge

**task file**: `data/tasks/branch-layer5-9p-bridge.md`

builds on existing `plan-9.client.*` modules (see `data/md/design/9P-CLIENT.md`).
exposes a branch subtree as a 9P server; mounts remote 9P namespaces into branch.

| module | purpose |
|---|---|
| `branch.9p.server.init_code` | serve branch subtree as 9P filesystem |
| `branch.9p.server.stat` | stat a branch node via 9P |
| `branch.9p.server.walk` | walk address path via 9P |
| `branch.9p.server.read` | read node content via 9P |
| `branch.9p.server.write` | write to node via 9P |
| `branch.9p.client.mount` | mount remote 9P server into branch subtree |
| `branch.9p.client.sync` | sync mounted subtree on inotify / timer |

## layer 6 — file access abstraction

**task file**: `data/tasks/branch-layer6-file-abstraction.md`

uniform file API regardless of backend: local fs, 9P mount, storage zenka.
adapters are registered per-node; callers use `branch.file.*` only.

| module | purpose |
|---|---|
| `branch.file.open` | abstract open: local / 9P / storage |
| `branch.file.read` | abstract read |
| `branch.file.write` | abstract write |
| `branch.file.stat` | abstract stat |
| `branch.file.list` | abstract directory listing |
| `branch.file.close` | abstract close |
| `branch.file.adapter.local` | local filesystem adapter |
| `branch.file.adapter.9p` | 9P protocol adapter |
| `branch.file.adapter.storage` | storage zenka adapter |

## layer 7 — resource attachment API

**task file**: `data/tasks/branch-layer7-resource-attach.md`

anything can be attached to a node: context buffers, task refs, streams, files.
resources have types; multiple resources of the same type can coexist.
intended to be the primary integration surface for other zenki.

| module | purpose |
|---|---|
| `branch.resource.attach` | attach typed resource to node |
| `branch.resource.detach` | detach resource from node |
| `branch.resource.list` | list all resources on a node |
| `branch.resource.find` | find nodes that have a resource matching filter |
| `branch.resource.context` | attach / retrieve context buffer |
| `branch.resource.task` | attach / retrieve task reference |
| `branch.resource.stream` | attach / retrieve STRM stream handle |

## dependency graph layer

**task file**: `data/tasks/branch-dep-graph.md`

parallel to the address tree: a directed dependency graph across nodes.
used by zenka dependency tracking, task orchestration, capability gating.

| module | purpose |
|---|---|
| `branch.dep.declare` | declare directed dependency edge between nodes |
| `branch.dep.remove` | remove dependency edge |
| `branch.dep.check` | check whether all declared deps of a node are satisfied |
| `branch.dep.resolve` | topological sort across reachable dep graph |
| `branch.dep.cycle` | detect dependency cycles |
| `branch.dep.graph` | emit ASCII / DOT dependency graph |
| `branch.dep.propagate` | propagate satisfaction state upstream |

## zenka integration

the `branch` zenka will load `branch.*` modules and expose them as p7 commands.
other zenki (task, coding, discover, storage) load branch modules directly and
call `branch.init_code` in their own init sequence.

**on-demand zenka config** (branch zenka, not yet created):

```
start.on-demand = 1
restart.disabled = 1
heartbeat.disabled = 1
```

## integration notes

- **cube access**: `branch.*` commands will need entries in `cube/access.zenki`
  once the branch zenka is created
- **no cross-zenka file access**: resource attachments reference zenka-local
  handles only; cross-zenka resource sharing goes through route-send / SHM
- **key management**: layer-3 key propagation uses `%keys` not `%data` for key
  material; derivation follows existing `crypt.C25519.*` patterns
- **9P bridge**: must coordinate with plan-9.* modules for protocol framing;
  do not reimplement — wrap and adapt
- **storage persistence**: storage zenka is currently stub — layer-4 modules
  should function against local YAML fallback when storage zenka unavailable

## dispatch order and parallelism

groups with no shared state can be dispatched simultaneously:

```
round 1 [ parallel ]:
  A  branch-layer2-discover-groups.md    [ extends layer 1 only ]
  B  branch-layer3-routes-keys.md        [ extends layer 1 only ]
  C  branch-dep-graph.md                 [ extends layer 1 only ]

round 2 [ parallel, after A+B+C ]:
  D  branch-layer4-storage-data.md       [ needs route layer ]
  E  branch-layer7-resource-attach.md    [ needs discover + groups ]

round 3 [ parallel, after D+E ]:
  F  branch-layer5-9p-bridge.md          [ needs storage + resource ]
  G  branch-layer6-file-abstraction.md   [ needs 9P + storage adapters ]
```

## subtask status

| task file | layer | status | notes |
|---|---|---|---|
| (core — session 43) | 1 | DONE | 10 modules, ptd-verified |
| branch-layer2-discover-groups.md | 2 | DONE | 9 modules incl. reply handlers |
| branch-layer3-routes-keys.md | 3 | DONE | 9 modules incl. timer + wave cache |
| branch-dep-graph.md | dep | DONE | 8 modules, Kahn + DFS cycle detect |
| branch-layer7-resource-attach.md | 7 | DONE | 8 modules, group-filter stub removed |
| branch-layer4-storage-data.md | 4 | pending | dispatch round 2 |
| branch-layer5-9p-bridge.md | 5 | pending | needs round 2 |
| branch-layer6-file-abstraction.md | 6 | pending | needs round 2 |

#,,.,,,..,,.,,,.,,,,.,..,,,..,,,,,.,.,,,,,.,,,..,,...,...,...,.,,,,.,,.,.,,..,
#A4IPGRATPRHEABXBAYDLPGRVKWPVFAKAJ3GJUCUCEFT65FPHDCGX3LLXKT5QW74MTGIJA5VINVXGG
#\\\|VIRTENKRLVHS467PSUH5IKEV3SOXLS7LT3PNU4CMNES3XMIYDB2 \ / AMOS7 \ YOURUM ::
#\[7]35ISG37FZAIJGNNCCUFVNTE7UGL5ZWXH72F4FNNZHWV4KOK3COBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
