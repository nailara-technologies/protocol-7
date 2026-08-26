## [:< ##

# name  = task: iris dimension rotator — H/V view toggle
# descr = toggle between horizontal (CCW plane) and vertical (floor depth) views
#         same data, orthogonal projection — reveals latency topology

## concept

normal iris: horizontal view
  angular axis = BMW384 arc (direction)
  radial axis  = ring depth (color density)
  
rotated 90°: vertical view
  angular axis = BMW384 arc (direction, same)
  radial axis  = floor depth / logical hop latency
  
in the vertical view:
  nodes near center: low latency routes (fast hops, few floors consumed)
  nodes at outer rings: high latency (many floors consumed waiting)
  color: the arc color as usual (direction preserved)
  
use case: which arcs have deep vertical stacks?
          = which directions have high latency
          = where negotiations are taking longest

## new config key

<route.bmw384.cfg.dimension_view>  // 'horizontal'  (or 'vertical')

## new module: route.bmw384.visual.wheel.vertical

based on route.bmw384.visual.wheel but radial position = floor depth
instead of ring index from color value.

floor depth source: <bmw384.route.floor_depth> hashref
  { "module_name" => floor_count }
  populated by the route execution layer as routes traverse modules.

if no floor depth data: fall back to co-location count as proxy.

```perl
# name  = route.bmw384.visual.wheel.vertical
# descr = vertical dimension view: radial = floor depth, angular = arc

my $floor_data = <bmw384.route.floor_depth> // {};
my $max_floor  = 1;
for my $ARG ( values %$floor_data ) {
    $max_floor = $ARG if $ARG > $max_floor;
}

# [ for each module: radial position from floor depth ]
for my $ARG (@sorted_names) {
    my $coord  = $by_name->{$ARG};
    my $floors = $floor_data->{$ARG} // 1;
    
    # [ outer = deep (high latency), inner = shallow (fast) ]
    my $radius = 30 + ( $floors / $max_floor ) * ( $outer_radius - 30 );
    
    # [ angular position = arc (same as horizontal view) ]
    my $arc_start_deg   = -$coord->{'arc'} * $segment_deg;
    my $within_arc_frac = ( $coord->{'color'} / $segment_width )
        - int( $coord->{'color'} / $segment_width );
    my $angle_deg = $arc_start_deg - $within_arc_frac * $segment_deg;
    my $rad       = $angle_deg * $PI / 180;
    
    my $x = 400 + $radius * sin($rad);
    my $y = 400 - $radius * cos($rad);
    
    # [ color: hue from arc (direction), brightness from depth ]
    my $hue       = ( $coord->{'arc'} * 360 / 26 ) % 360;
    my $lightness = int( 30 + ( 1 - $floors / $max_floor ) * 40 );
    my $color_hex = sprintf 'hsl(%d,80%%,%d%%)', $hue, $lightness;
    
    $svg .= sprintf '  <circle cx="%.2f" cy="%.2f" r="3"'
        . ' fill="%s" opacity="0.75"><title>%s floors=%d</title></circle>' . "\n",
        $x, $y, $color_hex, $ARG, $floors;
}
```

## iris UI

add H/V toggle button near mode buttons:
```html
<button class="mode-btn" id="dim-h" data-dim="horizontal">H</button>
<button class="mode-btn active" id="dim-v" data-dim="vertical">V</button>
```

when dim=vertical: use mode 'vertical' instead of current mode
when dim=horizontal: use current mode as normal

pass as &dim=vertical in render URL.
in iris-svg handler: if dim=vertical, call wheel.vertical regardless of mode.

## floor depth stub data for testing

if no actual floor depth available, generate synthetic data:
  floor_depth = BMW384 arc value mod 7 + 1
  (gives 1-7 floors per module, spreads across the vertical range)

## signatures note

new module: leave clean. existing: re-signed on commit.

#,,.,,..,,,,,,,,.,...,.,,,,,.,,.,,,,,,.,,,.,.,..,,...,...,.,.,,,.,,,,,.,.,...,
#5WM76B76ZVET63WW2CRAY7Y6Q7VN67HUI3IR4RP4J2IPZ3EERWMMWUCJQDUNS5EL5XXZPO3ZQGP5W
#\\\|KZ65YFFA4ERTRENLWDSBHNNT3J64TOIMMLWY3KCCV2QVXBT63C7 \ / AMOS7 \ YOURUM ::
#\[7]CRJAJYQVYYEYQ72JE75CKJBHAYL5DU3JOAONQ7UOGLARQWOFXYDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
