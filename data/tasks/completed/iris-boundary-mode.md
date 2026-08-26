## [:< ##

# name  = task: iris boundary mode — event horizon pure visualization
# descr = render only the color gradient boundaries between BMW384 arc clusters
#         no individual nodes — just the domain transitions (stained glass)

## concept

instead of rendering nodes: render only where the field CHANGES.
the sharp color transitions between arc clusters = event horizons.
the result: stained glass pattern showing domain structure without content noise.

two boundary types:
  arc boundaries:   between arc segments (the spoke lines, enhanced)
  color boundaries: within arcs, where color values cluster/change sharply

## arc boundary rendering

for each arc boundary (spoke line):
  compute the color density on both sides
  if the hue difference > threshold: draw a glowing boundary line
  intensity = hue difference magnitude
  color = blend of the two adjacent arc colors

## color clustering within arcs

within each arc, the color field (0-16M) has clusters where
many modules share similar color values.
boundaries between clusters = event horizons within the arc.

```
for each arc:
  sort modules by color value
  find gaps in the color distribution (large jumps)
  each gap = a boundary
  render as a bright dot/line at that radial position
```

## new module: route.bmw384.visual.wheel.boundary

```perl
# name  = route.bmw384.visual.wheel.boundary
# descr = event horizon pure visualization — domain boundaries as stained glass

return undef if not defined <bmw384.index>;

my $by_name = <bmw384.index>->{'by_name'};
my @names   = keys %$by_name;

# [ optional namespace filter ]
# ... same pattern as other modes

my $PI            = 3.14159265358979;
my $segment_deg   = 360 / 26;
my $segment_width = 16777216 / 26;
my $outer_radius  = <route.bmw384.cfg.outer_radius> // 320;

my $svg = '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
$svg .= '<svg xmlns="http://www.w3.org/2000/svg"'
    . ' viewBox="0 0 800 800" width="800" height="800">' . "\n";
$svg .= '  <rect width="800" height="800" fill="#0a0a0f"/>' . "\n";

# [ build per-arc color distribution ]
my %arc_colors;
for my $ARG (@names) {
    my $coord = $by_name->{$ARG};
    my $arc   = $coord->{'arc'};
    push @{ $arc_colors{$arc} }, $coord->{'color'};
}

# [ find boundaries within each arc ]
for my $arc ( 0 .. 25 ) {
    my @colors = sort { $a <=> $b } @{ $arc_colors{$arc} // [] };
    next unless @colors > 1;
    
    # [ find large gaps = boundaries ]
    my $prev = $colors[0];
    for my $i ( 1 .. $#colors ) {
        my $gap = $colors[$i] - $prev;
        if ( $gap > $segment_width * 0.1 ) {  # 10% of arc width = boundary
            # [ boundary midpoint ]
            my $boundary_color = ( $prev + $colors[$i] ) / 2;
            my $frac = ( $boundary_color / $segment_width )
                - int( $boundary_color / $segment_width );
            
            my $arc_start = -$arc * $segment_deg;
            my $angle_deg = $arc_start - $frac * $segment_deg;
            my $rad       = $angle_deg * $PI / 180;
            
            # [ boundary as a radial line segment ]
            my $r_inner = 30;
            my $r_outer = $outer_radius;
            my $x1 = 400 + $r_inner * sin($rad);
            my $y1 = 400 - $r_inner * cos($rad);
            my $x2 = 400 + $r_outer * sin($rad);
            my $y2 = 400 - $r_outer * cos($rad);
            
            # [ boundary brightness from gap size ]
            my $gap_ratio = $gap / $segment_width;
            my $op = sprintf '%.2f', 0.1 + $gap_ratio * 0.8;
            
            # [ hue from arc position ]
            my $hue = ( 180 - int( $boundary_color / 16777216 * 360 ) ) % 360;
            
            $svg .= sprintf
                '  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f"'
                . ' stroke="hsl(%d,90%%,70%%)" stroke-width="1.5"'
                . ' opacity="%s"/>' . "\n",
                $x1, $y1, $x2, $y2, $hue, $op;
        }
        $prev = $colors[$i];
    }
}

# [ arc spoke boundaries — enhanced glowing spokes ]
for my $arc ( 0 .. 25 ) {
    my $angle_deg = -$arc * $segment_deg;
    my $rad       = $angle_deg * $PI / 180;
    my $x2        = 400 + ( $outer_radius + 5 ) * sin($rad);
    my $y2        = 400 - ( $outer_radius + 5 ) * cos($rad);
    
    # [ hue from arc color distribution midpoint ]
    my @colors = @{ $arc_colors{$arc} // [] };
    my $mid_hue = 180;
    if (@colors) {
        my $mid = $colors[ int(@colors/2) ];
        $mid_hue = ( 180 - int($mid / 16777216 * 360) ) % 360;
    }
    
    $svg .= sprintf
        '  <line x1="400" y1="400" x2="%.2f" y2="%.2f"'
        . ' stroke="hsl(%d,70%%,50%%)" stroke-width="1.5"'
        . ' opacity="0.6"/>' . "\n",
        $x2, $y2, $mid_hue;
}

# [ center void + logo ]
# ...

$svg .= '</svg>' . "\n";
return $svg;
```

## threshold config

<route.bmw384.cfg.boundary_threshold>  // 0.1
(fraction of arc width that counts as a boundary gap)

lower threshold = more boundaries visible (finer grain)
higher threshold = only major domain transitions shown

## iris UI

```html
<button class="mode-btn" data-mode="boundary">boundary</button>
```

add threshold slider in param row when boundary mode active.

## signatures note

new module: leave clean. existing: re-signed on commit.

#,,..,.,,,...,..,,.,.,,,,,.,,,.,,,,..,,..,..,,..,,...,...,,..,...,.,,,.,.,,,,,
#5QQF4TZCQH3Q4NH42RPXTAIPBNEYVCV7SFVFZ4GGHVP2NWFX7M4A6QG2WIYL5EHF4HXIUYFAYQUV4
#\\\|INUX7NW3RI3S2GY42TYGQYRMBS62B3B5BQVCFEXYTO7YUP7IJ6G \ / AMOS7 \ YOURUM ::
#\[7]Y35AOIHORO36JAFDL6ITMMO4QLZGZEOH4AZNSBPMOSZ6326WEODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
