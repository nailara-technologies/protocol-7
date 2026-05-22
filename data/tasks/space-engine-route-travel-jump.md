# task: space engine — route + travel + jump

## context

this task implements the navigation sub-namespaces of the space engine:
route encoding/decoding, hop traversal, 1001 tunnel mechanics, harmonic
frame expansion, and hyperspace jump shortcuts.

see `data/md/design/SPACE-ENGINE-MASTER.md` for full architecture.
see `data/md/design/DANCING-ZENKI-RHIZOME-STATE.md` for route direction encoding.
see `data/ai-mem/claude/topic-1001.md` for tunnel model.
see `data/ai-mem/claude/topic-checksum-tree-wire.md` for 01/10/11 encoding.

## namespace: space.route.*

```
space.route.encode     { hops }
  →  hops = [ { type => 'straight', distance => N }
               { type => 'turn' }
               { type => 'landmark', address => 'ABCDE7F' } ]
  →  '.' × N for straight, ',' for turn, address for landmark
  →  return dot/comma string

space.route.decode     { route }
  →  parse dot/comma string into hop sequence
  →  '.' = straight, ',' = turn 90° CCW, [A-Z2-7]{7} = landmark
  →  return [ { type, distance|address }, ... ]

space.route.shape      { route }
  →  count turns and straight distances
  →  4 equal turns = 'square', 3 = 'triangle', N = 'N-gon'
  →  no turns = 'line', mixed distances = 'spiral'
  →  return { shape, sides, side_length, encloses_void }
  →  encloses_void = TRUE if closed ring with interior

space.route.lca        { node_a, node_b }
  →  walk parent chains upward to find LCA
  →  return { lca_node, distance_a, distance_b,
               route_notation => '01' × N + '11' + '10' × M }

space.route.polarity   { depth }
  →  depth mod 13 = 0  →  polarity '/' closed, CW-aligned
  →  depth mod 13 != 0 →  polarity '\' open, CCW-aligned
  →  depth mod 13 = 7  →  maximum inversion
  →  return { polarity, depth_in_cycle, hops_to_correlation, glyph }

space.route.resonance  { node_id }
  →  resonance = ref_count × harmonic_truth × shell_bonus
  →  harmonic_truth: call base.chk-sum.amos on node_id, check TRUE/FALSE
  →  shell_bonus = 1 / max(1, shell_number)
  →  return { resonance, harmonic, shell_bonus }

space.route.inversion_points { max_depth }
  →  return [ 0, 13, 26, 39, ... ] up to max_depth
```

## namespace: space.travel.*

```
space.travel.hop       { from, direction }
  →  direction = '+z' | '-z' | '+y' | '-y' | '+x' | '-x'
  →  apply to current coordinate, return next { z, y, x }

space.travel.tunnel    { from, to }
  →  verify both nodes exist
  →  compute ntime delta between creation stamps
  →  expected duration = 2 (invariant 00 tunnel)
  →  variance = duration - 2 (0 = grid-aligned)
  →  return { duration, expected => 2, variance, grid_aligned }

space.travel.direction { from, to }
  →  determine 01 (inward/source) | 10 (outward/leaf) | 11 (pivot/LCA)
  →  compare shell depths: to < from = 01, to > from = 10, equal = 11
  →  return '01' | '10' | '11'

space.travel.path      { from, to }
  →  compute full route: 01 × N hops up to LCA, 11 at LCA, 10 × M down
  →  return { route_notation, hops, lca_node }

space.travel.frame.expand { sequence }
  →  the is_true frame expansion mechanism
  →  sequence = string or scalar ref of content
  →  start at aura.typical_frame_scale (or 1 if no aura)
  →  call AMOS7::Assert::Truth or base.chk-sum.amos truth check
  →  if FALSE: widen by 1 zero in the separator, try again
  →  stop when TRUE fires — minimum enclosure found
  →  no boundary corruption: boundary IS the harmonic closure
  →  auto-encapsulation: failing frames become content for wider frame
  →  return { scale, content, checksum, iterations }
```

## namespace: space.jump.*

hyperspace shortcuts via body diagonal routes. these bypass face-by-face
traversal. the reference bubble travels on these routes. jumps are
instantaneous because proportions are invariant (1001 = always exactly 2).

```
space.jump.diagonal    { from, to }
  →  check if a body diagonal path exists between from and to
  →  body diagonal = path where all three coordinates change simultaneously
  →  return { available, path, hops } or { available => FALSE }

space.jump.available   { from, to }
  →  TRUE if body diagonal shortcut exists
  →  simplified check: coordinate distance ratio matches diagonal geometry

space.jump.bubble      { formation }
  →  dispatch a reference bubble (dancing zenki formation) on jump route
  →  formation = { setup, ground => [...], collector, target }
  →  push formation to $data{'space.jump.active'}{$formation_id}
  →  return { formation_id, route, estimated_hops }

space.jump.cache.read  { hop, target }
  →  read $data{'branch.route.cache'}{$hop}{$target}
  →  return cached { next_hop, ntime } or undef

space.jump.cache.write { hop, target, next_hop }
  →  write to $data{'branch.route.cache'}{$hop}{$target}
  →  ntime = <[base.time]>->(4)
  →  return TRUE
```

## the 1001 tunnel model

```
1001 = inter-cube tunnel structure:
  1   = departure gate (node group A, face-000 aperture)
  00  = invariant 2-hop CCW tunnel (grid-aligned, always exactly 2)
  1   = arrival gate (node group B, face-000 aperture)

space.travel.tunnel variance check:
  grid-aligned travel: variance = 0 (duration = 2 exactly)
  non-aligned: variance > 0 (route not through gate)
```

## state keys

```perl
$data{'space.jump.active'}     ## formation_id → formation state
$data{'branch.route.cache'}    ## hop → target → { next_hop, ntime }
                               ## (shared with branch.route.establish)
```

## code style

$ARG not $_, TRUE/FALSE, lowercase comments, [ word ] annotations.
use <[base.ntime_BASE32_to_numerical]> for all ntime comparisons.
AMOS swap-boundary for checksum calls.
no signature stubs.

## success criteria

- [ ] space.route.encode/decode round-trips correctly
- [ ] space.route.shape detects ',...,...,...,...' as square with void
- [ ] space.route.polarity returns '/' at depth 0, 13, 26
- [ ] space.travel.tunnel returns variance=0 for invariant 2-hop
- [ ] space.travel.frame.expand finds minimum enclosure, stops at TRUE
- [ ] space.travel.direction returns 01/10/11 correctly
- [ ] space.jump.cache.read/write operate on branch.route.cache
- [ ] all pass ptd, no signature stubs

## dispatch note

parallel-safe with space-engine-grid-orbit.md, space-engine-template.md,
base-callback-data-tree-modes.md.

#,,.,,,,.,...,..,,.,,,...,,,.,,..,.,.,...,,,,,..,,...,...,...,...,,,.,,..,..,,
#XBXLLJ6B2D2FZGZGBWAG25PFRU5NJH6D3UDTG6SI4DJEZGPB3IAKGYQ42ROPFC3ZUECFRB2PXM7WY
#\\\|JRLMOL5UCGR5IJ3QSF7T7GCP5UFSJOOZGCZ5FCHAPM5BU6A6CRD \ / AMOS7 \ YOURUM ::
#\[7]QMHMT32QPE3NFB7SW62IY5XI6EAFKJQV36TTPNXUVQGGAQHYAGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
