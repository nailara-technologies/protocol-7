## [:< ##

# name  = task: iris alpha-density visualization mode
# descr = new wheel mode where node opacity = normalized bit coverage density
#         across all indexed modules' angle_bits fields

## concept

currently: each module's angle_bits has bits set to 1 at certain degree positions.
the visualization renders nodes at fixed opacity — losing the information of HOW MANY
modules share each angular position.

new mode: for each of 360 degree positions, count how many modules have that bit
set in their angle_bits. normalize by max count. use as node opacity (alpha).

result: angular positions resonant across many modules → bright
        rare angular positions → dim
        the true density distribution of the BMW384 field made visible as luminance.

## changes to route.bmw384.index.init

add a 360-element density array to the index structure:

```perl
# add to existing init:
<bmw384.index>->{'degree_density'} = [ (0) x 360 ];
<bmw384.index>->{'degree_density_max'} = 0;
```

## changes to route.bmw384.index.from-file

after registering a module's coordinate, accumulate its angle_bits into the
degree_density array:

```perl
# after: <bmw384.index>->{'by_name'}{$name} = $coord;
# add:

if ( defined $coord->{'angle_bits'} and length $coord->{'angle_bits'} == 360 ) {
    my $density = <bmw384.index>->{'degree_density'};
    my $max     = <bmw384.index>->{'degree_density_max'} // 0;
    for my $d ( 0 .. 359 ) {
        if ( substr( $coord->{'angle_bits'}, $d, 1 ) eq '1' ) {
            $density->[$d]++;
            $max = $density->[$d] if $density->[$d] > $max;
        }
    }
    <bmw384.index>->{'degree_density_max'} = $max;
}
```

## new module: route.bmw384.visual.wheel.alpha-density

a new wheel mode that renders nodes with opacity derived from degree_density.

base the module on route.bmw384.visual.wheel but replace the opacity calculation:

```perl
# name  = route.bmw384.visual.wheel.alpha-density
# descr = BMW384 wheel — node opacity proportional to angle_bits density
#         across all indexed modules. bright = many modules share this degree.

return undef if not defined <bmw384.index>;

my $by_name      = <bmw384.index>->{'by_name'};
my @sorted_names = @{ <bmw384.index>->{'sorted_names'} // [ sort keys %$by_name ] };

# [ namespace filter — same as other modes ]
my $ns_filter = <route.bmw384.cfg.namespace_filter> // '';
if ( length $ns_filter ) {
    my $prefix_only = substr( $ns_filter, 0, 1 ) eq '^';
    my $ns_pat      = $prefix_only ? substr( $ns_filter, 1 ) : $ns_filter;
    my $anywhere    = not $prefix_only;
    my @ns_f;
    for my $ARG (@sorted_names) {
        push @ns_f, $ARG
            if $anywhere
            ? index( $ARG, $ns_filter ) != -1
            : index( $ARG, $ns_pat ) == 0;
    }
    @sorted_names = @ns_f;
}

# [ density array from index ]
my $density     = <bmw384.index>->{'degree_density'} // [];
my $density_max = <bmw384.index>->{'degree_density_max'} // 1;
$density_max = 1 if $density_max < 1;

# [ parameters ]
my $rings            = <route.bmw384.cfg.rings>            // 1;
my $ring_radius_step = <route.bmw384.cfg.ring_radius_step> // 11;
my $outer_radius     = <route.bmw384.cfg.outer_radius>     // 320;

my $PI            = 3.14159265358979;
my $segment_deg   = 360 / 26;
my $segment_width = 16777216 / 26;

# [ SVG setup — spokes, labels same as wheel ]
# ...

# [ node rendering with density-derived alpha ]
for my $ring ( 0 .. $rings - 1 ) {
    my $radius = $outer_radius - $ring * $ring_radius_step;

    for my $ARG (@sorted_names) {
        my $coord = $by_name->{$ARG};

        my $arc_start_deg   = -$coord->{'arc'} * $segment_deg;
        my $within_arc_frac = ( $coord->{'color'} / $segment_width )
            - int( $coord->{'color'} / $segment_width );
        my $angle_deg = $arc_start_deg - $within_arc_frac * $segment_deg;

        # [ map angle_deg to 0..359 ]
        my $d = int( $angle_deg ) % 360;
        $d += 360 if $d < 0;

        # [ derive alpha from density at this degree position ]
        my $raw_density = $density->[$d] // 0;
        my $alpha = sprintf '%.2f',
            0.15 + 0.85 * ( $raw_density / $density_max );
        # floor of 0.15: nodes always minimally visible
        # ceiling of 1.0: densest positions fully opaque

        my $rad = $angle_deg * $PI / 180;
        my $x   = 400 + $radius * sin($rad);
        my $y   = 400 - $radius * cos($rad);

        # [ hue from color — same as ring mode ]
        my $hue = ( 180 - int( $coord->{'color'} / 16777216 * 360 ) ) % 360;
        my $color_hex = sprintf 'hsl(%d,90%%,60%%)', $hue;

        $svg .= sprintf
            '  <circle cx="%.2f" cy="%.2f" r="3" fill="%s" opacity="%s">'
            . "\n", $x, $y, $color_hex, $alpha;
        $svg .= sprintf '    <title>%s density=%d/%.0f%%</title>' . "\n",
            $ARG, $raw_density,
            100 * $raw_density / $density_max;
        $svg .= '  </circle>' . "\n";
    }
}
```

the tooltip shows density count and percentage for each node.

## wire into wheel-mode dispatcher

in src/route.bmw384.visual.wheel-mode, add:

```perl
elsif ( $mode eq 'alpha-density' ) {
    return <[route.bmw384.visual.wheel.alpha-density]>
}
```

## wire into cmd.visual-wheel

the existing arg parsing already handles unknown mode names by returning
a usage error. 'alpha-density' is a valid mode string — no changes needed
beyond the wheel-mode dispatcher above.

## iris UI

in data/web-root/vhosts/iris.v7.ax/index.html, add button to mode row:

```html
<button class="mode-btn" data-mode="alpha-density">α-density</button>
```

## overlay-search.html

no change needed (uses overlay mode only).

## notes on density accumulation

- density is accumulated per-module at index time (from-file)
- if index is cleared and re-populated, density resets correctly (init zeroes it)
- density reflects ALL indexed modules regardless of namespace filter
- namespace filter only affects WHICH nodes are rendered, not their density values
  (this is intentional: density = global field property, not per-namespace)

## signatures note

existing modules: re-signed on commit.
new module route.bmw384.visual.wheel.alpha-density: leave clean, no stub footer.

## style

$ARG not $_ in loops (use for my $ARG)
lowercase comments, [ word ] bracket annotations
copy SVG structure from route.bmw384.visual.wheel as base

#,,,.,,.,,...,.,.,,..,,,.,.,,,.,,,,,.,...,...,..,,...,...,.,.,,,,,,..,,,,,,..,
#HUCFQBL5OAIADHUCDRFKUMVUVCQ7KEX4DDURPLVXFPSHYGP5MICHMQC2OUFXN72ZPO35E5SKHO6FK
#\\\|APBKYMGVZ2WGYKSOZHTCFD4U47PBSXS6GMO7KHI4GD2HD4D7OAU \ / AMOS7 \ YOURUM ::
#\[7]VTN2GQWDZQM2MDFDMXWIKCYCJEUFM7TKH4JEG5BWUTGRQOOVFWDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
