## [:< ##

# name  = task: iris route commitment visualization
# descr = show pre-computed route arcs on the iris: future=bright, past=dim,
#         current position=brightest. the modifiable agreement made visible.

## concept

when a route is dispatched, its full arc sequence is pre-computed.
render the route path on the iris as a colored overlay:
  uncrossed future arcs: bright (the open agreement)
  crossed past arcs: dim (the immutable history)
  current arc: maximum brightness (the execution frontier)

as the packet traverses, arcs transition from bright to dim in sequence.
the visual: the pre-computed route consuming itself as it executes.

## data structure

routes registered via POST /iris/route already store hop sequences.
extend to include execution state:

```perl
<bmw384.route.curves>->{$curve_id} = {
    route     => $route,
    hops      => \@hop_coords,      # ordered list of BMW384 coords
    current   => 0,                 # index of current hop
    committed => [],                # indices already crossed (immutable)
    ...
};
```

## new module: route.bmw384.visual.route-commitment

```perl
# name  = route.bmw384.visual.route-commitment
# descr = render active route commitments as bright/dim arc overlays

return '' unless defined <bmw384.route.curves>
    and scalar keys %{ <bmw384.route.curves> };

my $PI          = 3.14159265358979;
my $segment_deg = 360 / 26;
my $segment_width = 16777216 / 26;
my $svg = '';

for my $cid ( keys %{ <bmw384.route.curves> } ) {
    my $curve   = <bmw384.route.curves>->{$cid};
    my $hops    = $curve->{'hops'} // [];
    my $current = $curve->{'current'} // 0;
    my $color   = $curve->{'color'} // 'hsl(180,90%,60%)';
    
    next unless @$hops;
    
    for my $i ( 0 .. $#$hops ) {
        my $coord  = $hops->[$i];
        my $arc    = $coord->{'arc'};
        my $clr    = $coord->{'color'} // 0;
        
        my $arc_start = -$arc * $segment_deg;
        my $frac = ($clr / $segment_width) - int($clr / $segment_width);
        my $angle = ( $arc_start - $frac * $segment_deg ) * $PI / 180;
        
        # [ position on inner ring — route overlay close to center ]
        my $radius = 80 + $i * 8;  # routes spiral outward hop by hop
        my $x = 400 + $radius * sin($angle);
        my $y = 400 - $radius * cos($angle);
        
        # [ state-based opacity ]
        my ( $op, $r, $glow );
        if ( $i < $current ) {
            $op = '0.15'; $r = 3; $glow = '';  # past: dim
        } elsif ( $i == $current ) {
            $op = '1.00'; $r = 6; $glow = ' filter="url(#glow)"';  # current: bright+glow
        } else {
            $op = '0.60'; $r = 4; $glow = '';  # future: visible
        }
        
        $svg .= sprintf
            '  <circle cx="%.2f" cy="%.2f" r="%d"'
            . ' fill="%s" opacity="%s"%s>' . "\n",
            $x, $y, $r, $color, $op, $glow;
        $svg .= sprintf '    <title>route %s hop %d/%d</title>' . "\n",
            $cid, $i+1, scalar @$hops;
        $svg .= '  </circle>' . "\n";
    }
    
    # [ connecting line between hops — the route path drawn ]
    # ... SVG polyline through all hop positions
}

return $svg;
```

## add glow filter to SVG defs

in each wheel module's SVG header, add:
```xml
<defs>
  <filter id="glow">
    <feGaussianBlur stdDeviation="3" result="blur"/>
    <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
```

## route advancement

POST /iris/route/advance:
  curve_id: ID
  steps: N (default 1)
  → increments current index by N
  → moves crossed hops to committed
  → SVG re-render shows updated bright/dim distribution

for animated advancement (auto-play):
  the iris page calls /iris/route/advance every 300ms
  while current < total hops

## integration with iris-svg handler

in httpd.route.handler.iris-svg, call route-commitment module
and append its output before </svg> (same as flying-elements).

## signatures note

new module: leave clean. existing: re-signed on commit.

#,,..,,.,,,..,,,.,,.,,,,.,,,,,,..,,,,,...,,,.,..,,...,...,...,,,.,..,,.,.,...,
#G22424XKVWAIU6IEAOLF56LE55B7JYX3VKNDAKWGMRKTV4Q7EBX47HXEZLPSTJ456J4IFPOHSF6RY
#\\\|5TMMXCDJSVWS2I7CN2YCLTAPKTASWC3TDIBOLVG3BUM7LMPS7YA \ / AMOS7 \ YOURUM ::
#\[7]V7QRUM56ILGRKEKNKWZ773FLAZCXZPPRXJ6AQZWW5BDY64ADQ4AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
