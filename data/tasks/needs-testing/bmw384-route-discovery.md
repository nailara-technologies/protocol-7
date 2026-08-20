## [:< ##

# name  = task: implement bmw384 route discovery — geometric path finding in the field
# descr = given source and destination coordinates, find a resonant path through the
#         field index using coarse arc matching first, then angular refinement.
#         no routing table — pure geometry. returns ordered list of hop coordinates.

## depends on

task: bmw384-field-index.md — field index with query-arc and query-radius must exist.
task: bmw384-node-coordinate.md — coordinate structure must exist.
task: bmw384-color-extract.md — bmw384_color_dist must exist.

## background

route discovery in the BMW384 field works in two passes:

  pass 1 [ coarse ]: find nodes sharing the destination's arc segment — these are
  in the same 1/26th of the color wheel as the destination, naturally resonant with it.

  pass 2 [ fine ]: within the coarse candidates, rank by combined color+angle proximity
  to the destination coordinate. the closest node that is also reachable from the source
  (within a configurable hop radius) becomes the next hop.

  the path is built greedily: source → nearest resonant intermediate → destination.
  for short paths (source and destination in same arc) direct routing is used.

this is vortex routing — each hop is a Tau-fraction step along the spiral toward
the destination's angular position, narrowing both color and angle distance per hop.

## modules to create

### src/base.bmw384.route.find

main entry point. params: ( $src_name, $dst_name )
both must be registered in the field index.

  1. look up source coord: <[base.bmw384.index.lookup]>->( $src_name )
  2. look up dest coord:   <[base.bmw384.index.lookup]>->( $dst_name )
  3. if same arc: call base.bmw384.route.direct → return result
  4. otherwise: call base.bmw384.route.vortex → return result
  5. return {
       path    => [ $src_name, @hop_names, $dst_name ],
       arcs    => [ arc per node in path ],
       hops    => scalar @hop_names,
       resonant => $bool,   ## true if all hops share arc with destination
     }

### src/base.bmw384.route.direct

same-arc routing. params: ( $src_coord, $dst_coord, $src_name, $dst_name )
nodes are in the same arc — check angular proximity:

  1. compute angular distance as hamming distance between angle_bits strings
     [ count differing bit positions — simpler than full BigInt subtraction ]
  2. if hamming_dist < threshold (default 90 bits = 25% of 360):
       direct route: path = [ src, dst ], hops = 0, resonant = true
  3. otherwise: fall through to vortex with hint that arc is already matched

### src/base.bmw384.route.vortex

cross-arc routing. params: ( $src_coord, $dst_coord, $src_name, $dst_name )

  1. get candidates from destination arc:
       <[base.bmw384.index.query-arc]>->( $dst_coord->{'arc'} )
  2. for each candidate compute composite proximity score:
       $color_dist = bmw384_color_dist( $candidate_coord->{'color'}, $dst_coord->{'color'} )
       $angle_dist = hamming_dist( $candidate_coord->{'angle_bits'}, $dst_coord->{'angle_bits'} )
       $score = $color_dist / 16777216 + $angle_dist / 360   ## normalized 0..2
  3. sort candidates by score ascending — lowest score = most resonant with destination
  4. pick best candidate as the single intermediate hop
  5. return path: [ src_name, best_candidate_name, dst_name ]

### src/base.bmw384.route.hamming-dist

utility: count differing bits between two 360-char '0'/'1' strings.
params: ( $bits_a, $bits_b )

  my $dist = 0;
  for my $i ( 0 .. 359 ) {
      $dist++ if substr($bits_a, $i, 1) ne substr($bits_b, $i, 1);
  }
  return $dist;

## zenka command module to create

### src/base.bmw384.cmd.find-route

command handler: p7c <zenka>.find-route <src_name> <dst_name>
parses two space-separated names from $call->{'args'}.
calls base.bmw384.route.find and returns formatted output:

  route: src_name → [hop_name] → dst_name
  hops: N  |  arcs: A → C → C  |  resonant: yes/no

returns { mode => 'size', data => $output }

## notes on signatures

- new files: leave clean, no stub footer
- hamming distance is intentionally simple — sufficient for arc-level routing
- the threshold of 90 bits for direct routing is a starting value, make it
  configurable via <bmw384.cfg.direct_threshold> defaulting to 90

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas in zenka modules

#,,.,,.,.,.,,,...,.,.,..,,..,,.,.,,.,,...,,..,..,,...,...,..,,,,,,,.,,.,,,,,,,
#56GWN5K2B6AOMS64XJXHMGFJ2VNECLONCQ5SGGW34IGWWESOENSEMOJZ3GYK6PMU73J4G3U2JCYAW
#\\\|USJPQ3WGX5M653DMNA46DQDBWEPDULHK7UKK4GN7CYDQGDSCKML \ / AMOS7 \ YOURUM ::
#\[7]R57IWMG7HUFAP6KKT7676KPMQW6K5XXCPNHRQWEB3RVYZUVQGMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
