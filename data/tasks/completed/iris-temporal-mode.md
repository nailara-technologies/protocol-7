## [:< ##

# name  = task: iris temporal mode — time axis visualization
# descr = radial axis = time since last modification, angular = BMW384 arc
#         the iris as a git log organized by field topology

## concept

instead of spatial depth on the radial axis: use TIME.
modules modified recently: near center (hot, active)
modules unchanged for a long time: outer rings (stable, crystallized)
angular position: BMW384 arc as usual (field direction preserved)
color: time-since-modification (hot=red/orange, old=cool blue)

the iris becomes: a temporal heat map of development activity
                  organized by the field geometry
                  not a linear git log
                  but git blame as orbital topology

## data source

for each module: read mtime from the file on disk.
the time range: from oldest module to newest.
normalize: 0.0 (newest) to 1.0 (oldest).

## new module: route.bmw384.visual.wheel.temporal

```perl
# name  = route.bmw384.visual.wheel.temporal
# descr = radial position = time since modification, color = age

return undef if not defined <bmw384.index>;

my $by_name      = <bmw384.index>->{'by_name'};
my @sorted_names = @{ <bmw384.index>->{'sorted_names'}
    // [ sort keys %$by_name ] };

# [ namespace filter — same pattern as other modes ]
my $ns_filter = <route.bmw384.cfg.namespace_filter> // '';
if ( length $ns_filter ) {
    my $prefix_only = substr($ns_filter,0,1) eq '^';
    my $ns_pat      = $prefix_only ? substr($ns_filter,1) : $ns_filter;
    my $anywhere    = not $prefix_only;
    my @ns_f;
    for my $ARG (@sorted_names) {
        push @ns_f, $ARG if $anywhere
            ? index($ARG,$ns_filter) != -1
            : index($ARG,$ns_pat)    == 0;
    }
    @sorted_names = @ns_f;
}

# [ collect mtimes ]
my $code_path = <system.code_path> // '';
my %mtime;
my $min_t = time();
my $max_t = 0;

for my $ARG (@sorted_names) {
    my $path = "$code_path/$ARG";
    my $t    = (stat $path)[9] // 0;
    $mtime{$ARG} = $t;
    $min_t = $t if $t < $min_t and $t > 0;
    $max_t = $t if $t > $max_t;
}

my $range = ( $max_t - $min_t ) || 1;

my $PI            = 3.14159265358979;
my $segment_deg   = 360 / 26;
my $segment_width = 16777216 / 26;
my $outer_radius  = <route.bmw384.cfg.outer_radius> // 320;
my $inner_radius  = 30;

my $svg = '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
$svg .= '<svg xmlns="http://www.w3.org/2000/svg"'
    . ' viewBox="0 0 800 800" width="800" height="800">' . "\n";
$svg .= '  <rect width="800" height="800" fill="#0a0a0f"/>' . "\n";

# [ spokes + labels same as ring mode ]
# ...

for my $ARG (@sorted_names) {
    my $coord = $by_name->{$ARG};
    my $t     = $mtime{$ARG} // $min_t;
    
    # [ age: 0.0 = newest, 1.0 = oldest ]
    my $age = 1 - ( $t - $min_t ) / $range;
    
    # [ radial: newer = inner, older = outer ]
    my $radius = $inner_radius + $age * ( $outer_radius - $inner_radius );
    
    my $arc_start_deg   = -$coord->{'arc'} * $segment_deg;
    my $within_arc_frac = ( $coord->{'color'} / $segment_width )
        - int( $coord->{'color'} / $segment_width );
    my $angle_deg = $arc_start_deg - $within_arc_frac * $segment_deg;
    my $rad       = $angle_deg * $PI / 180;
    
    my $x = 400 + $radius * sin($rad);
    my $y = 400 - $radius * cos($rad);
    
    # [ color: hot (red/orange) = recent, cool (blue) = old ]
    my $hue = int( $age * 240 );  # 0=red(new) → 240=blue(old)
    my $color_hex = sprintf 'hsl(%d,85%%,55%%)', $hue;
    
    $svg .= sprintf
        '  <circle cx="%.2f" cy="%.2f" r="3" fill="%s" opacity="0.75">'
        . '<title>%s — %s</title></circle>' . "\n",
        $x, $y, $color_hex, $ARG,
        scalar localtime($t);
}

# [ center logo ]
# ...

$svg .= '</svg>' . "\n";
return $svg;
```

## iris UI

add temporal button:
```html
<button class="mode-btn" data-mode="temporal">time</button>
```

## time legend

add to SVG bottom:
  inner circle = newest (red dot)
  outer circle = oldest (blue dot)
  with approximate time ranges

## whitelist + wheel-mode

add to:
  cfg/zenki/httpd/subroutine.white-list
  modules/route.bmw384.visual.wheel-mode

## signatures note

new module: leave clean. existing: re-signed on commit.

#,,,.,.,,,,,,,...,.,,,,,,,,,.,.,.,,,.,,..,,,,,..,,...,..,,..,,,,.,,.,,,.,,,,,,
#DFY2WVH6IFBBCUPDP4KJE6YEPPDV7KVD3UCC5SNUDQWPM2UHQFTUJZHERLV5IUQP2EBUSGMSGAKP6
#\\\|MMURK65PZM4BIMGNQ76QHEAONSVCUJKPGKVYUPJ5AH5S27T2KKE \ / AMOS7 \ YOURUM ::
#\[7]5QPBLQ6B2WCCOUWYIXEFXR2ZOSJ4REIMMQQI2I3HW2ZJVC6TASDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
