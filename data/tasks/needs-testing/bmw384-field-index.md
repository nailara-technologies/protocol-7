## [:< ##

# name  = task: implement bmw384 field index — register, query, discover by proximity
# descr = in-memory index of BMW384 node coordinates; register nodes by name,
#         query by arc segment, color proximity radius, or angle proximity.
#         the discovery primitive: "what is near me in the field?"

## depends on

task: bmw384-node-coordinate.md — coordinate hashref structure must exist.
task: bmw384-color-extract.md — bmw384_color_dist must exist.

## background

the field index is a lightweight in-memory structure held in the zenka namespace
at <bmw384.index>. it maps node names to their coordinates and provides fast
lookup by arc segment (coarse) and color distance (fine). no disk persistence
needed at this stage — the index is rebuilt from registered nodes on startup.

the index enables field-native discovery: a node does not need to know the address
of another node explicitly — it queries the field for nodes within a color radius
and finds candidates by geometric proximity alone.

## data structure

<bmw384.index> is a hashref:

  {
    by_name => {
      $node_name => $coordinate_hashref,   ## full coordinate per node
      ...
    },
    by_arc => {
      0 => [ $node_name, ... ],            ## arc 0 = segment 'A'
      1 => [ $node_name, ... ],            ## arc 1 = segment 'B'
      ...
      25 => [ $node_name, ... ],
    },
  }

## modules to create

### src/base.bmw384.index.init

initialize <bmw384.index> to empty structure if not already present.
called once from zenka init_code or on first use.

  <bmw384.index> //= { 'by_name' => {}, 'by_arc' => {} };
  for my $arc ( 0 .. 25 ) {
      <bmw384.index>->{'by_arc'}{$arc} //= [];
  }

### src/base.bmw384.index.register

register a node by name. params: ( $name, $input )
$input is the scalar to hash (may equal $name, or be a checksum, IP, etc.)

  1. call <[base.chk-sum.bmw384.coordinate]>->( $input ) → $coord
  2. store in <bmw384.index>{'by_name'}{$name} = $coord
  3. push $name onto <bmw384.index>{'by_arc'}{ $coord->{'arc'} }
     [ avoid duplicates: skip if already present ]
  4. log at level 2: 'bmw384: registered %s at arc %s [%s]',
     $name, $coord->{'arc'}, $coord->{'segment_label'}
  5. return $coord

### src/base.bmw384.index.lookup

exact lookup by name. param: ( $name )
returns coordinate hashref or undef if not found.

### src/base.bmw384.index.query-arc

return all nodes in a given arc segment. param: ( $arc )
returns arrayref of { name => $name, coord => $coord } sorted by color ascending.

### src/base.bmw384.index.query-radius

return all nodes within color distance $radius of a center coordinate.
params: ( $center_coord, $radius )

  1. iterate all nodes in <bmw384.index>{'by_name'}
  2. compute bmw384_color_dist( $center_coord->{'color'}, $node_coord->{'color'} )
  3. collect nodes where dist <= $radius
  4. return arrayref of { name, coord, dist } sorted by dist ascending

### src/base.bmw384.index.query-neighbors

convenience wrapper: given a node name and radius, look up its coordinate
and call query-radius. params: ( $name, $radius )
returns same format as query-radius, excluding the named node itself.

### src/base.bmw384.index.stats

return a summary hashref:
  {
    total    => scalar keys %{ <bmw384.index>{'by_name'} },
    by_arc   => { 0 => count, 1 => count, ... 25 => count },
    arc_labels => { 'A' => count, 'B' => count, ... },
  }

## zenka command module to create

### src/base.bmw384.cmd.index-stats

command handler: p7c <zenka>.index-stats
calls base.bmw384.index.stats and returns formatted table:
  arc A: N nodes
  arc B: N nodes
  ...
  total: N nodes
returns { mode => 'size', data => $table }

## notes on signatures

- new files: leave clean, no stub footer
- <bmw384.index> lives in the zenka namespace of whichever zenka loads these modules
- autoload AMOS7::CHKSUM::BMW384 via <[base.perlmod.autoload]> in modules that need it

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas in zenka modules

#,,..,,,,,,,.,.,,,..,,.,.,.,.,...,.,,,,.,,..,,..,,...,...,.,,,,.,,...,,,.,,.,,
#RCZN6VNSLSRTRMGBJU56ZZ6VYU3OP5NOUOQKEW2K4XK6LMK3NPKVNBNII2LS6MW2FE4FYF74LGWVE
#\\\|6SZW5EDESP6Z7BILXOQJDWCKOIAJTAEQ57KZH7XPMVEJFEIPSRM \ / AMOS7 \ YOURUM ::
#\[7]FN5WQCYOM3KO6QEN2RPLWDS3DDKFA2ODCNKAORCVPEAPSRYOZOBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
