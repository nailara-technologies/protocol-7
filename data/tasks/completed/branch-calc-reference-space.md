# task: branch reference space calculation utilities

## context

the observer-centric reference space (OBSERVER-CENTRIC-REFERENCE-SPACE.md)
defines nodes as having signed positions -n/2..0..+n/2 driven by reference
counts. this task implements the calculation layer: given reference counts,
compute positions, shells, visibility, and magnetic group forces.

see also: data/md/design/ZERO.md, data/md/design/ROUTING-CRYSTAL-HARMONIC-INFERENCE.md

## namespace: branch.space.*

**`branch.space.rank`**
```
# param = { node_id, scope }
# scope = 'local' | 'regional' | 'global' (which nodes to rank against)

compute signed position for node_id:
  collect reference counts for all nodes in scope
  sort descending by reference count
  assign ranks: highest = position ±1, lowest = ±n/2
  n = ceil(total_nodes / 2)
  position = signed rank: positive for odd index, negative for even
             (interleaved: ±1, ±2, ±3... so highest-ref gets ±1)
  ties: same reference count = same shell, different angular position

store result in $data{'branch.space.positions'}{$scope}{$node_id}
return { mode => 'true', data => { position => $signed_rank, shell => abs($signed_rank), n => $n } }
```

**`branch.space.shell`**
```
# param = { position }  or  { node_id, scope }
# position = { z, y, x } vector or scalar signed rank

shell number = max(abs(z), abs(y), abs(x))  for vector positions
             = abs(signed_rank)              for 1D rank
shell 0 = the darksun (observer itself)
shell 1 = innermost ring (closest, highest reference)
shell N = outermost currently populated ring

return { mode => 'true', data => $shell_number }
```

**`branch.space.visible`**
```
# param = { focal_length, observer_node, scope }
# focal_length: 0='omni' (all), 13=natural harmonic, higher=fewer shells

if focal_length == 0 or 'omni': return all nodes in scope
else: max_visible_shell = ceil(63 / focal_length)
      [ 63 = 4×4×4-1, the cube group size ]
      return nodes with shell <= max_visible_shell
      sorted by shell ascending (darksun first)

return { mode => 'true', data => [ { node_id, shell, position }, ... ] }
```

**`branch.space.magnetic_force`**
```
# param = { node_id }

compute the additional magnetic force on node_id from its group memberships:
  for each group this node belongs to:
    for each other member of that group:
      force_vector += (other_member_position - this_position) / distance²
      [ pulls toward group companions ]
  total_magnetic = sum of all group force vectors

return { mode => 'true', data => { magnetic_vector => { z, y, x },
                                   magnitude => $scalar,
                                   dominant_group => $group_name } }
```

**`branch.space.effective_position`**
```
# param = { node_id, scope }

combined position = grid_position (from branch.space.rank) +
                    magnetic_force (from branch.space.magnetic_force)
                    normalized to still fall within ±n/2

the effective position is what determines actual sorting on display.
the grid is the EM base; the magnetic adjusts within it.

return { mode => 'true', data => { grid => $rank, magnetic => $delta,
                                   effective => $combined, shell => $shell } }
```

**`branch.space.balance`**
```
# param = { scope }

verify ∑ = 0 across all positions in scope:
  sum all signed positions
  sum all reference count deltas (in - out)
  both should be zero or within float tolerance

return { mode => 'true',  data => { sum => 0, balanced => TRUE } }
     or { mode => 'false', data => { sum => $delta, imbalanced_nodes => [...] } }
```

## state keys used

```
$data{'branch.space.positions'}{$scope}{$node_id}  = { position, shell, n }
$data{'branch.space.magnetic'}{$node_id}           = { vector, magnitude }
```

## code style

$ARG not $_, TRUE/FALSE, lowercase comments, [ word ] annotations.
no signature stubs.

## success criteria

- [ ] branch.space.rank assigns ±1 to highest-ref, ±n/2 to lowest
- [ ] branch.space.shell correctly handles both vector and scalar input
- [ ] branch.space.visible returns empty at high focal_length, all at omni
- [ ] branch.space.magnetic_force sums group pull vectors correctly
- [ ] branch.space.effective_position combines grid + magnetic within bounds
- [ ] branch.space.balance detects imbalanced sums correctly
- [ ] all pass ptd, no signature stubs

## dispatch note

parallel-safe with branch-calc-route-navigation.md and branch-calc-bandwidth-temporal.md.

#,,..,..,,.,.,..,,...,,,,,...,..,,.,,,,.,,..,,..,,...,...,..,,,,,,.,,,,..,.,.,
#6FIUHL3BBZKM6VBVR3THRJVXN5SUT5WMUPDDEMOKQS4DN2S5SOHYOPJKB6RGFZXATNSIPO3RCWRJM
#\\\|TUMHXT74T26KNYMUYM4XWV7A2KX47SQV7UVFG3XXQG2T5KSCDE7 \ / AMOS7 \ YOURUM ::
#\[7]VQQY6ACGMQG6K72RIHAFSTIXIA2GTXNHKGPGY5K246XU3UJRZKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
