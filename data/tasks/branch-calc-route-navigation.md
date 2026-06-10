# task: branch route navigation + harmonic calculation utilities

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

dot/comma route encoding here is the **addressing-layer counterpart**
of the console fold handle described in
`data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` — both compress a
path through a recursive tree into a compact, resolvable string. the
short-address segment in a fold handle is exactly the kind of route
this module encodes; the two layers compose without translation.

## context

the routing crystal (ROUTING-CRYSTAL-HARMONIC-INFERENCE.md) and checksum
tree wire format (topic-checksum-tree-wire.md) define routes as dot/comma
sequences, with polarity determined by tree depth mod 13, and inversion
cross-correlation at multiples of 13. this task implements those calculations.

see also: data/md/design/ZERO.md, data/md/design/DANCING-ZENKI-RHIZOME-STATE.md

## namespace: branch.route.calc.*

**`branch.route.calc.encode`**
```
# param = { hops }
# hops = [ { direction => 'straight'|'turn', distance => N }, ... ]

encode a hop sequence as dot/comma route notation:
  'straight' hop of distance N  →  '.' × N
  'turn' (90° CCW)              →  ','
  node address landmark         →  node's AMOS checksum (7 chars)

example: [ {turn}, {straight,3}, {turn}, {straight,2} ]
       → ',...,..,'

return { mode => 'true', data => $dot_comma_string }
```

**`branch.route.calc.decode`**
```
# param = { route }
# route = dot/comma string like ',...,..,.,0'

parse dot/comma string into hop sequence:
  '.' = straight (one hop, current direction, cumulative count)
  ',' = turn 90° CCW
  BASE32 chars (2-9A-Z) = node address landmark, 7 chars

return { mode => 'true', data => [
    { type => 'straight', distance => N },
    { type => 'turn' },
    { type => 'landmark', address => 'ABCDEFG' },
    ...
] }
```

**`branch.route.calc.shape`**
```
# param = { route }
# returns the geometric shape traced by the route seen from above

count turns and straight distances:
  4 turns of equal distance  →  'square'
  3 turns                    →  'triangle'  (if equal sides)
  N turns, equal sides       →  'N-gon'
  no turns                   →  'line'
  mixed distances            →  'spiral' or 'irregular'

return { mode => 'true', data => { shape => $name,
                                   sides => $count,
                                   side_length => $hops,
                                   encloses_void => TRUE|FALSE } }
```

**`branch.route.calc.polarity`**
```
# param = { depth }
# depth = tree depth of a node (0 = root/darksun)

polarity at depth N:
  N mod 13 = 0   →  same as root (/) — closed, CW-aligned
  N mod 13 != 0  →  inverted (\) — open, CCW-aligned
                     distance from last correlation = N mod 13
  N mod 13 = 7   →  maximum inversion (furthest from cross-correlation)

return { mode => 'true', data => { polarity => '/' | '\\',
                                   depth_in_cycle => N mod 13,
                                   hops_to_correlation => 13 - (N mod 13),
                                   glyph => 'open' | 'closed' } }
```

**`branch.route.calc.inversion_points`**
```
# param = { max_depth }

return all depths up to max_depth where inversions cross-correlate:
  cross-correlation depths = multiples of 13: 0, 13, 26, 39...
  at these depths: all accumulated inversions cancel
  polarity is readable without counting

return { mode => 'true', data => [ 0, 13, 26, 39, ... ] }
```

**`branch.route.calc.lca_depth`**
```
# param = { node_a, node_b }

find the lowest common ancestor depth and distance:
  walk parent chains of both nodes upward
  find first common ancestor
  lca_depth = depth of common ancestor
  distance_a = depth_a - lca_depth
  distance_b = depth_b - lca_depth
  route = '01' × distance_a + '11' + '10' × distance_b

return { mode => 'true', data => { lca_node => $id,
                                   distance_a => $n,
                                   distance_b => $m,
                                   route_notation => $string } }
```

**`branch.route.calc.resonance`**
```
# param = { node_id }

compute resonance score of a node in the routing crystal:
  resonance = reference_count × harmonic_truth_value
  harmonic_truth = 1 if AMOS checksum of node_id is TRUE else 0.5
  shell_bonus = 1 / shell_number  (inner shells resonate more)

return { mode => 'true', data => { resonance => $score,
                                   harmonic => TRUE|FALSE,
                                   shell_bonus => $n } }
```

## code style

$ARG not $_, TRUE/FALSE, lowercase comments, [ word ] annotations.
AMOS checksum swap-boundary: $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'}
no signature stubs.

## success criteria

- [ ] encode produces correct ., strings for hop sequences
- [ ] decode correctly parses ., with embedded BASE32 landmarks
- [ ] shape detects ',...,...,...,...' as square, encloses_void = TRUE
- [ ] polarity returns '/' at depth 0, 13, 26 and '\' at depth 1-12
- [ ] inversion_points returns exact multiples of 13
- [ ] lca_depth correctly produces 01×N + 11 + 10×M notation
- [ ] resonance combines reference count × harmonic × shell correctly
- [ ] all pass ptd, no signature stubs

#,,.,,.,,,,.,,,,,,.,.,..,,.,.,...,..,,.,.,...,..,,...,...,..,,...,.,.,,,,,.,,,
#P3EMY4UM3OV32XEA6LS65QNCFPLMAAMJRCUXQKAIBLOKVT5ZVONH4MMYO6D3UBB67CYQQKMJVELBI
#\\\|KQBYPXCPFMQKDNFIHTHQYVOTITHBQZ34XQ5P7JCMYJ3L7JJO2GE \ / AMOS7 \ YOURUM ::
#\[7]K6T2CBN2XZCGUTLU6I4WEL5WLKMXPGBJDKVKQJFI4WLPLQ4T4EAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
