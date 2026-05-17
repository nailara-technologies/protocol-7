## [:< ##

# name  = task: route curve visualization — flying elements on grid paths
# descr = extend base.curve with position curve types, wire BMW384 routes
#         into iris visualization as animated flying elements on curves

## context

the existing base.curve system animates scalar values (from→to over duration).
the route calculation methods (data/md/development/ROUTE-CALCULATION-METHODS.md)
define geometric routes as curves between grid alignments.

this task: bridge them — routes become curves, curves become animations,
animations become flying elements orbiting each other in the iris.

## read first

- modules/base.curve.eval         (scalar curve evaluator)
- modules/base.curve.register     (curve registration/animation)
- modules/base.curve.tick         (animation timer)
- data/md/development/ROUTE-CALCULATION-METHODS.md
- modules/route.bmw384.route.vortex
- modules/route.bmw384.route.find

## what to implement

### 1. new module: base.curve.eval.position

extend base.curve.eval to return 2D SVG coordinates
instead of a scalar value:

```perl
# name  = base.curve.eval.position
# descr = position curve evaluator: type × t × params → {x, y}
#         maps t [0,1] to SVG coordinate on iris (800×800 canvas)

my $type   = shift;   # 'orbital_arc' | 'vortex_spiral' | 'linear_hop'
my $t      = shift;   # progress 0.0 → 1.0
my $params = shift;   # curve-specific parameters

if ( $type eq 'orbital_arc' ) {
    # [ CCW arc between two BMW384 coordinates ]
    # params: center_x, center_y, radius, angle_start, angle_end
    my $angle = $params->{'angle_start'}
        + $t * ( $params->{'angle_end'} - $params->{'angle_start'} );
    return {
        x => 400 + $params->{'radius'} * cos($angle),
        y => 400 - $params->{'radius'} * sin($angle),
    };

} elsif ( $type eq 'vortex_spiral' ) {
    # [ CCW implosion spiral: harmonic radius reduction ]
    # params: radius_start, angle_start, turns
    my $angle  = $params->{'angle_start'} + $t * $params->{'turns'} * τ;
    my $radius = $params->{'radius_start'} * ( 1 - $t * ( 1 - 1/13 ) );
    return {
        x => 400 + $radius * cos($angle),
        y => 400 - $radius * sin($angle),
    };

} elsif ( $type eq 'linear_hop' ) {
    # [ direct hop between two BMW384 positions ]
    # params: from {x,y}, to {x,y}
    # motion profile from base.curve.eval (ease-in-out)
    my $ease = <[base.curve.eval]>->( 'ease-in-out', $t );
    return {
        x => $params->{'from'}{'x'} + $ease * ( $params->{'to'}{'x'} - $params->{'from'}{'x'} ),
        y => $params->{'from'}{'y'} + $ease * ( $params->{'to'}{'y'} - $params->{'from'}{'y'} ),
    };
}
```

### 2. new module: route.bmw384.route.as-curve

converts a route spec (hop sequence) into a base.curve registration:

```perl
# name  = route.bmw384.route.as-curve
# descr = register a BMW384 route as an animated position curve
# args  = $route_spec, $duration_secs, $curve_type, $callback

my $route    = shift;
my $duration = shift // 5;
my $type     = shift // 'vortex_spiral';
my $callback = shift;

# [ compute position curve params from route hops ]
# [ register with base.curve.register ]
# [ each hop: one segment of the curve ]
# [ t=0: source position, t=1: destination position ]
# [ return curve_id ]
```

### 3. new module: route.bmw384.visual.flying-elements

generates SVG `<animateMotion>` elements for active route curves:

```perl
# name  = route.bmw384.visual.flying-elements
# descr = generate SVG path elements for animated route traversal

# [ for each active route curve in <bmw384.route.curves> ]
# [ compute SVG path from hop sequence ]
# [ generate: <circle> with <animateMotion> along path ]
# [ style by curve type: vortex=magenta, arc=cyan, hop=white ]
# [ return SVG fragment to append to iris wheel SVG ]
```

SVG output format per flying element:

```xml
<path id="route_[id]" d="M x0,y0 C cx1,cy1 cx2,cy2 x1,y1 ..." fill="none"/>
<circle r="4" fill="rgba(255,0,255,0.8)">
  <animateMotion dur="[duration]s" repeatCount="indefinite">
    <mpath href="#route_[id]"/>
  </animateMotion>
</circle>
```

### 4. update: httpd.route.handler.iris-svg

add flying elements to the SVG output:

```perl
# after generating the main wheel SVG
# before closing </svg>:
my $flying = <[route.bmw384.visual.flying-elements]>;
$svg =~ s{</svg>}{$flying</svg>} if defined $flying and length $flying;
```

### 5. update: iris.v7.ax/index.html

add route controls to the UI:

```html
<div class="route-controls">
  <button id="add-vortex-btn">+ vortex</button>
  <button id="add-arc-btn">+ arc</button>
  <span class="param-label">from arc</span>
  <input class="rings-input" id="route-from" value="13" min="0" max="25">
  <span class="param-label">to</span>
  <input class="rings-input" id="route-to" value="0" min="0" max="25">
</div>
```

JS: POST to `/iris/route` → registers route curve → re-render shows flying element

### 6. new httpd route: POST /iris/route

```perl
# name  = httpd.route.handler.iris-route
# descr = register a new animated route curve from arc params

# parse: from_arc, to_arc, curve_type, duration
# call: route.bmw384.route.vortex or route.bmw384.route.find
# call: route.bmw384.route.as-curve
# return: { curve_id, hop_count }
```

add to configuration/zenki/httpd/routes:
  POST  /iris/route    httpd.route.handler.iris-route

## the flying elements visualization

what it should look like:

```
iris disc: static (the field)
           with colored module nodes

flying elements: small glowing dots
                 traveling along route curves
                 
vortex route:   magenta dot spiraling CCW inward
                from outer ring → darksun
                the intake arm made kinetic
                
arc route:      cyan dot arcing between two points
                following orbital geometry
                
hop route:      white dot jumping between module positions
                ease-in-out motion between hops
                
multiple active: dots orbiting each other
                 their routes forming a
                 living orbital diagram
                 above the static field map
```

## connection to base.curve motion profiles

the motion profile (HOW fast the element moves along the path)
is separate from the path geometry (WHERE it goes):

```
path:     vortex_spiral (geometric route)
profile:  sine          (breathing speed — faster at equinoxes)

path:     orbital_arc
profile:  ease-in-out   (natural orbital acceleration)

path:     linear_hop
profile:  quantized      (13-step discrete jumps)
profile:  heartbeat      (lub-dub arrival at each hop)
```

use base.curve.eval for the profile, base.curve.eval.position for the path.
compose them: t_profile = base.curve.eval(profile_type, t_raw)
              pos = base.curve.eval.position(path_type, t_profile, params)

## storage

active route curves stored in:
  <bmw384.route.curves>  = { curve_id => { route, params, started } }

persists in httpd memory between requests.
cleared on: httpd restart or explicit DELETE /iris/route/[id]

## signatures note

leave new files clean. no stub footer.
existing modules: re-signed on commit.

## style

$ARG not $_ in loops
lowercase comments, [ word ] bracket annotations
τ = 2π (already available as τ constant)

#,,..,.,.,,..,.,.,...,..,,.,.,.,.,,..,,,.,,.,,..,,...,..,,..,,.,.,,,.,.,,,..,,
#ZGX35UDEL5D7KKZWOYAQWWFNWLFFVLFGG3Z63KGSPPGUH2LFJ7KVQIQARAVVM7XP2QPVGQPSGI75M
#\\\|5EQIHE5UQUH5VSZHL3FS7CEUXXGRIS2TYCM73PADNX6BJ4QQ3KF \ / AMOS7 \ YOURUM ::
#\[7]CQPO2M6B6VNJDIAD4XVSMFKT22KLJ3RTIN2YIZFMS65WVCAT3GCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
