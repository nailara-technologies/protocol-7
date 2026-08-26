# task: branch bandwidth + temporal clock calculation utilities

## context

the observer-centric reference space defines temporal bandwidth as the same
mechanism as spatial position: reference count drives both where a node sits
AND how many slots it receives in the 13-slot routing clock cycle.
relative ntime is observer-centric — each node measures from its own creation.

see also: data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md (temporal bandwidth section)
          data/md/design/ZERO.md (the number section)

## namespace: branch.clock.*

**`branch.clock.allocate`**
```
# param = { nodes, total_slots }
# nodes      = [ { id, ref_count }, ... ]  (e.g. face view nodes)
# total_slots = 13 (default, natural harmonic)

allocate slots proportionally by reference count:
  total_refs = sum of all ref_counts
  for each node: slots = round(ref_count / total_refs × total_slots)
  adjust rounding to ensure sum = total_slots exactly
  nodes with ref_count = 0 get 0 slots (removed from sequence)

return { mode => 'true', data => { allocations => { node_id => slot_count },
                                   sequence => [ node_id, node_id, ... ],
                                   total => $total_slots } }
```

**`branch.clock.sequence`**
```
# param = { allocations }
# allocations = { node_id => slot_count } from branch.clock.allocate

build the slot sequence distributing slots as evenly as possible:
  use Bresenham-style distribution (avoid clustering same node together)
  highest-allocated nodes appear most frequently, spread evenly
  [ this is the serialization order IS the relevance ranking ]

example: { A=>6, B=>3, C=>2, D=>1, E=>1 } with 13 slots →
  A B A C A B A D A B A C A  (evenly distributed, A=6, B=3, C=2, D+E=2)

return { mode => 'true', data => [ node_id, ... ] }  (13 elements)
```

**`branch.clock.position`**
```
# param = { ntime }
# ntime = current network timestamp (B32)

compute current position in the 13-slot clock cycle:
  convert ntime to numerical: <[base.ntime_BASE32_to_numerical]>
  position = numerical_ntime mod 13  (0-12)
  next_correlation = 13 - position   (hops until next cross-correlation)

return { mode => 'true', data => { position => $n,
                                   next_correlation => $hops,
                                   is_correlation => $position == 0 } }
```

**`branch.clock.bandwidth`**
```
# param = { node_id, total_slots }

compute effective bandwidth for one node in the clock:
  slots = branch.clock.allocate result for this node
  bandwidth_ratio = slots / total_slots
  bandwidth_pct   = bandwidth_ratio × 100

return { mode => 'true', data => { slots => $n,
                                   ratio => $r,
                                   percent => $pct,
                                   dominant => $slots > (total_slots / 2) } }
```

## namespace: branch.ntime.*

**`branch.ntime.relative`**
```
# param = { ntime_a, ntime_b }
# both are B32 ntime stamps from two different observer nodes

compute relative temporal distance:
  a_num = <[base.ntime_BASE32_to_numerical]>->($ntime_a)
  b_num = <[base.ntime_BASE32_to_numerical]>->($ntime_b)
  delta = abs(a_num - b_num)
  clock_periods = delta / 13   (how many clock cycles apart)
  tunnel_units  = delta / 2    (in 1001-tunnel units: always 2 per hop)

return { mode => 'true', data => { delta => $delta,
                                   clock_periods => $clock_periods,
                                   tunnel_units => $tunnel_units,
                                   direction => 'a_before_b' | 'b_before_a' } }
```

**`branch.ntime.clock_sync`**
```
# param = { ntime_a, ntime_b }

determine if two nodes are clock-synchronized:
  synced if: (a_num - b_num) mod 13 == 0
  offset = (a_num - b_num) mod 13  (0 = synced, 1-12 = offset)
  a synced pair sees the same slot allocation simultaneously

return { mode => 'true', data => { synced => TRUE|FALSE,
                                   offset => $n,
                                   hops_to_sync => 13 - $offset } }
```

**`branch.ntime.tunnel_duration`**
```
# param = { entry_ntime, exit_ntime }

compute tunnel traversal duration in 1001-units:
  duration = abs(exit_num - entry_num)
  expected = 2   (the invariant 00 tunnel = always exactly 2 time units)
  variance  = duration - 2   (should be 0 for grid-aligned travel)

return { mode => 'true', data => { duration => $n,
                                   expected => 2,
                                   variance => $v,
                                   grid_aligned => $v == 0 } }
```

## code style

$ARG not $_, TRUE/FALSE, lowercase comments, [ word ] annotations.
use <[base.ntime_BASE32_to_numerical]> for all ntime comparisons.
never use gt/lt string comparison on B32 ntime values (see critical-patterns.md).
no signature stubs.

## success criteria

- [ ] branch.clock.allocate sums to exactly total_slots with proportional distribution
- [ ] branch.clock.sequence distributes evenly (no clustering)
- [ ] branch.clock.position correctly returns 0-12 and flags correlation points
- [ ] branch.ntime.relative uses numerical comparison, not string
- [ ] branch.ntime.tunnel_duration detects variance from invariant 2
- [ ] branch.ntime.clock_sync detects (a-b) mod 13 == 0 correctly
- [ ] all pass ptd, no signature stubs

## dispatch note

parallel-safe with branch-calc-reference-space.md and branch-calc-route-navigation.md.
all three use separate $data key namespaces.

#,,,.,,..,..,,,,,,,.,,...,...,,,,,...,...,,.,,..,,...,.,.,..,,..,,,,.,...,...,
#2U5XBEXIECT3BOTIO2PFM4C7J7MXOEXZLDTGAJVGJSCCJZ2GW4O6VC2ZKDRM5HW32DLPQXRDGLBAC
#\\\|6DZNZKUIZWFSJAB2MOSUZ7IKFP56FFLXRVRI6G5GQXB44VMCPM7 \ / AMOS7 \ YOURUM ::
#\[7]K3BLUWBV6E3GQF7W5GQPEXIPJUB4WWQ7VADACBXV366473UUBYAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
