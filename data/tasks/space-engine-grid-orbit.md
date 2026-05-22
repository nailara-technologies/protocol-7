# task: space engine — grid + orbit + aura

## context

the space engine is the unifying computation layer for the observer-centric
reference space. this task implements the grid (3D signature space) and orbit
(reference-count gravity, aura profiles) sub-namespaces.

see `data/md/design/SPACE-ENGINE-MASTER.md` for full architecture.
see `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md` for the model.
see `data/md/design/ROUTING-CRYSTAL-HARMONIC-INFERENCE.md` for harmonic memory.

## namespace: space.grid.*

each position (z, y, x) in the 3D signature space holds one BASE32 character
[2-9A-Z] — statistically derived from proportional checksum character votes
across all reference events passing through that coordinate.

AMOS 7-char checksum = 3D plus sign: 1 center + 6 arms = 7 unique positions.
two adjacent nodes share one arm character — adjacency encoded in identity.

```
space.grid.position    { node_id }
  →  resolve coordinate from $data{'space.grid.nodes'}{$node_id}
  →  return { z, y, x, shell, character }

space.grid.neighbors   { node_id }
  →  return 6 adjacent coordinates: ±z, ±y, ±x
  →  [ { z, y, x, node_id_if_occupied }, ... ]

space.grid.character   { z, y, x }
  →  return dominant character at coordinate
  →  from $data{'space.grid.votes'}{z}{y}{x} vote histogram
  →  highest vote count wins; undef if no votes

space.grid.shell       { z, y, x }  or  { node_id }
  →  shell = max( abs(z), abs(y), abs(x) )
  →  shell 0 = darksun (0,0,0)

space.grid.visible     { focal_length, observer_node, scope }
  →  focal_length = 0 or 'omni': return all nodes
  →  else: max_shell = ceil( 63 / focal_length )  [ 63 = 4×4×4-1 ]
  →  return nodes with shell <= max_shell
  →  sorted by shell ascending (darksun first)

space.grid.vote        { z, y, x, character }
  →  increment vote for character at coordinate
  →  $data{'space.grid.votes'}{z}{y}{x}{$character}++
  →  called on every reference event passing through
  →  return { dominant, confidence }  where confidence = top_votes / total_votes
```

## namespace: space.orbit.*

nodes orbit the darksun at orbital distance proportional to reference count.
EM base field (from grid position) + magnetic group forces (from memberships).

```
space.orbit.rank       { node_id, scope }
  →  scope = 'local' | 'global' (which nodes to rank against)
  →  collect ref counts for all nodes in scope
  →  sort descending; assign signed rank ±1..±n/2
  →  highest ref_count → position ±1 (closest to darksun)
  →  store in $data{'space.orbit.positions'}{$scope}{$node_id}
  →  return { position, shell, n }

space.orbit.distance   { node_id }
  →  orbital distance = abs( signed rank )
  →  or Euclidean distance from (0,0,0) if 3D coords assigned
  →  return scalar distance

space.orbit.magnetic   { node_id }
  →  for each group this node belongs to:
       for each other group member:
         force_vector += (other_position - this_position) / distance²
  →  return { vector => { z, y, x }, magnitude, dominant_group }

space.orbit.effective  { node_id, scope }
  →  grid_position + magnetic_force, normalized to ±n/2
  →  return { grid, magnetic, effective, shell }

space.orbit.balance    { scope }
  →  sum all signed positions
  →  return { mode => 'true', data => { sum, balanced => TRUE } }
  →  or { mode => 'false', ... } if |sum| > tolerance

space.orbit.aura.build  { node_id }
  →  analyze $data{'space.orbit.passages'}{$node_id} history
  →  compute: typical_frame_scale, burst_profile, entropy_signature, confidence
  →  store in $data{'space.orbit.auras'}{$node_id}
  →  return the aura hashref

space.orbit.aura.register { node_id, aura }
  →  pre-register burst capacity profile before traffic arrives
  →  merge with existing aura if present (weight by confidence)
  →  return { mode => 'true', data => $node_id }

space.orbit.aura.query  { node_id }
  →  return $data{'space.orbit.auras'}{$node_id}
  →  or { typical_frame_scale => 13, confidence => 0 } if none yet
```

## aura profile structure

```perl
{
    typical_frame_scale => 13,    ## median harmonic closing scale
    burst_profile       => [13, 14, 15, 16],  ## 95th percentile range
    entropy_signature   => 'AMOS7',  ## AMOS checksum of content fingerprint
    buffer_reserve      => 13,    ## pre-allocate at typical_scale
    confidence          => 0.73,  ## 0..1, how many passages trained this
}
```

## state keys

```perl
$data{'space.grid.nodes'}            ## node_id → { z, y, x, shell }
$data{'space.grid.votes'}            ## z → y → x → { char → count }
$data{'space.orbit.positions'}       ## scope → node_id → { position, shell, n }
$data{'space.orbit.auras'}           ## node_id → aura hashref
$data{'space.orbit.passages'}        ## node_id → [ { checksum, ntime }, ... ]
```

## init_code

create `space.init_code` that initializes all space.* state keys to {} and
registers the space engine's own node via `space.register.self` (stub call —
`space.register` will be implemented in a separate task).

## connections

- `branch.space.*` calc utilities (branch-calc-reference-space.md) share
  similar logic — implement independently but note the overlap; space.* is
  the running engine layer, branch.space.* is the utility/query layer
- `branch.group.members` — used by space.orbit.magnetic for group queries
- `AMOS7::Assert::Truth` or `base.chk-sum.amos` — for entropy_signature

## code style

$ARG not $_, TRUE/FALSE, lowercase comments, [ word ] annotations.
AMOS swap-boundary: $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'}
no signature stubs.

## success criteria

- [ ] space.grid.position returns { z, y, x, shell, character }
- [ ] space.grid.vote updates histogram correctly
- [ ] space.grid.visible returns empty at high focal_length, all at omni
- [ ] space.orbit.rank assigns ±1 to highest ref_count
- [ ] space.orbit.balance detects nonzero sums correctly
- [ ] space.orbit.aura.build computes from passage history
- [ ] space.init_code initializes all state keys
- [ ] all pass ptd, no signature stubs

## dispatch note

parallel-safe with space-engine-route-travel-jump.md, space-engine-template.md,
base-callback-data-tree-modes.md — all use disjoint $data key namespaces.

#,,,,,,.,,..,,,..,,..,,.,,,..,,..,.,,,.,.,,.,,..,,...,...,..,,...,..,,,..,,..,
#ZGK3FEG3ZASBW7LECNZE6LSN5JYL7XUQM4QPTA4U4X4QPYWX53SRDGT2SEXTEWYB6GWOO7UMJ3BRM
#\\\|2MVBEJLZFA3KGBTUFCTKCZ3H6HGF2Y2PH3BK5GG5U2PGTDRCSLT \ / AMOS7 \ YOURUM ::
#\[7]W3DUZDMJLNAJG2CBBXJGEN6PVSDMIIS55YGRCPITPQXXK3IOHSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
