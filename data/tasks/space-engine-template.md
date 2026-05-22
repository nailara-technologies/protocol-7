# task: space engine — template + search + register

## context

this task implements the template layer (ancestry rules, auto-parenting,
checksum chain computation), the search interface, and the registration
layer that wires entities into the space engine.

see `data/md/design/SPACE-ENGINE-MASTER.md` for full architecture.
see `data/md/design/ZERO.md` (1001 section) for chain model.

## namespace: space.template.*

the template layer defines ancestry rules for auto-parenting. new elements
don't declare their parent explicitly — the template provides it. the
structure IS the ancestry. the checksum chain IS the address.

```
space.template.define  { name, chain_format, branch_format }
  →  chain_format:   'header:row_data'  (colon-separated field names)
  →  branch_format:  'parent:next:branch_data'
  →  store in $data{'space.templates'}{$name}
  →  return { mode => 'true', data => $name }

space.template.root    { template, header_params }
  →  amos_chksum( header_params )
  →  the root address of a list/structure (no parent)
  →  return { mode => 'true', data => $root_checksum }

space.template.apply   { template, params }
  →  resolve template chain_format against params hashref
  →  build chain string: join ':' of param values in format order
  →  compute: amos_chksum( chain_string )
  →  return { checksum, parent, coordinate, chain_string }

space.template.chain   { parent_checksum, data }
  →  next link: amos_chksum( parent_checksum . ':' . $data )
  →  return next checksum in chain

space.template.branch  { parent_checksum, next, branch_data }
  →  amos_chksum( parent_checksum . ':' . $next . ':' . $branch_data )
  →  creates branch while preserving ancestry
  →  return branch checksum

space.template.verify  { checksum, template, params }
  →  recompute chain from params using template
  →  compare to given checksum
  →  return { mode => 'true', data => 'verified' }
         or { mode => 'false', data => 'mismatch' }

space.template.list    {}
  →  list all registered templates with chain_format
  →  return [ { name, chain_format, branch_format }, ... ]
```

**list element addressing** — practical example:

```perl
## define a list template ##
space.template.define({ name => 'bandwidth-list',
    chain_format  => 'header:row_data',
    branch_format => 'parent:next:branch_data' });

## root of a bandwidth list ##
my $root = space.template.root({ template => 'bandwidth-list',
    header_params => 'scope:local:ntime:' . $ntime });
## $root = amos_chksum('scope:local:ntime:XXXXX') = KQQ6E7A

## row 2 ##
my $row2 = space.template.chain({ parent => $root,
    data => 'face:1:slots:6:pct:46' });
## $row2 = amos_chksum('KQQ6E7A:face:1:slots:6:pct:46')

## branch from row 2 ##
my $branch = space.template.branch({ parent => $row2,
    next => 'face:3', branch_data => 'variant:compressed' });
```

## namespace: space.search

find nodes by any combination of coordinate, harmonic, type, group, aura.

```
space.search  { query }

query fields (all optional, combined AND):
  coord:      { z, y, x }  or  { shell_min, shell_max }
  harmonic:   TRUE | FALSE | UNKNOWN
  type:       P7REF TYPE prefix string
  group:      group name
  aura:       { entropy_signature, confidence_min }
  refcount:   { min, max }
  character:  single BASE32 char at coordinate

algorithm:
  start from all branch nodes (or scope-filtered subset)
  apply each filter in sequence (cheapest first)
  coord filter: use shell range to quickly prune
  harmonic filter: call is_true on node_id checksum
  group filter: use branch.group.members
  aura filter: check $data{'space.orbit.auras'}
  sort result by space.route.resonance descending
  cap at 100, log warning if capped

return [ { node_id, coord, shell, character, aura_confidence }, ... ]
```

## namespace: space.register

entity registration, aura pre-registration, @INDEXCUBE integration.

```
space.register.node    { node_id, type, pubkey }
  →  assign initial coordinate: outer shell ±n/2 (all axes)
  →  store in $data{'space.grid.nodes'}{$node_id}
  →  push P7REF onto @INDEXCUBE:
       sprintf '%s:%s:%s', uc($type), $node_id, $coord_b32
  →  create empty aura in $data{'space.orbit.auras'}
  →  return { mode => 'true', data => { node_id, coord } }

space.register.aura    { node_id, aura }
  →  pre-register burst capacity before traffic arrives
  →  merge with existing if confidence > 0:
       weighted average by confidence
  →  return { mode => 'true', data => $node_id }

space.register.passage { node_id, checksum }
  →  record a reference event (inhabitant passing through)
  →  push to $data{'space.orbit.passages'}{$node_id}
  →  extract characters from checksum, vote on coordinates:
       for each char in checksum: space.grid.vote at node's coord
  →  if passage count >= aura_build_threshold (default: 13):
       call space.orbit.aura.build
  →  return { mode => 'true', data => $passage_count }

space.register.self    {}
  →  engine registers itself as @INDEXCUBE[0]
  →  create branch node for the engine
  →  push 'SPACE:' . $engine_checksum . ':' . $coord_b32 as @INDEXCUBE[0]
  →  log at level 1: 'space: engine registered at [coord]'
  →  return { mode => 'true', data => $engine_node_id }
```

## state keys

```perl
$data{'space.templates'}           ## name → { chain_format, branch_format }
$data{'space.grid.nodes'}          ## node_id → { z, y, x, shell }
$data{'space.orbit.passages'}      ## node_id → [ { checksum, ntime }, ... ]
@INDEXCUBE                         ## per-zenka routing stack (global array)
```

## connections

- `branch.group.members` for group-filtered search
- `branch.node.create` for the engine's own node (space.register.self)
- `base.chk-sum.amos` for template chain checksum computation
- `@INDEXCUBE` global array declared in `bin/Protocol-7` line 13-14

## code style

$ARG not $_, TRUE/FALSE, lowercase comments, [ word ] annotations.
AMOS swap-boundary for checksum calls.
no signature stubs.

## success criteria

- [ ] space.template.define/root/chain/branch produce consistent checksums
- [ ] space.template.verify recomputes and matches correctly
- [ ] space.search applies coord/harmonic/group filters correctly
- [ ] space.search caps at 100, sorted by resonance
- [ ] space.register.node assigns outer shell coordinate
- [ ] space.register.passage votes characters onto coordinates
- [ ] space.register.self pushes to @INDEXCUBE[0]
- [ ] all pass ptd, no signature stubs

## dispatch note

parallel-safe with space-engine-grid-orbit.md, space-engine-route-travel-jump.md,
base-callback-data-tree-modes.md.

#,,.,,,..,,,,,,.,,,,,,.,.,...,,..,...,.,.,,..,..,,...,...,,.,,.,.,,.,,,.,,..,,
#DWL753PD7SC5EMJNLNRMHVYD3Z2DQPSOF3IPNVHXHY6PDL2A5BWWZWWXYKEGO2WTBPZRTQVOMGGOG
#\\\|6FJBDV3CFO4AFVNY2VCTZ64Y774FZQSD6VUMXQ4477DDBNYC2PY \ / AMOS7 \ YOURUM ::
#\[7]TA5YL2USG3RJCECGPT24F2K63VLQYNEBAMORZ7K535JLRDI4IYCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
