## [:< ##

# route calculation methods — cubic grid transit geometry

## the route as a complete geometric object

a route is not just source → destination.
it is a fully specified cubic transit with:

```
source cube:        BMW384 coordinate of departure
source face:        which of 6 cube faces you leave from
departure vector:   direction leaving that face
                    (face normal ± angular deviation)
                    
curve:              the transit path between vectors
                    arbitrary precision (continuous)
                    rasterized onto traversed grid cubes
                    
destination cube:   BMW384 coordinate of arrival
destination face:   which of 6 cube faces you enter
arrival vector:     direction entering that face
                    (face normal ± angular deviation)
```

the route has arbitrary precision but is rasterized into
the traversed grid — continuous in mathematics,
grid-native in traversal. both simultaneously.

---

## cube face addressing

each cube has 6 faces, each face has an angular position:

```
face index (3 bits):
  0: +X face (right)
  1: -X face (left)
  2: +Y face (top)
  3: -Y face (bottom)
  4: +Z face (front)
  5: -Z face (back)

angular position on face (uses angle_bits):
  angle_bits[0..2]:   face index (0-5)
  angle_bits[3..12]:  angular deviation from face normal
                      (10 bits = 1024 positions on the face)
  angle_bits[13..]:   additional precision if needed
```

the departure/arrival specification:

```
departure:    source_face + departure_angle
              = where on the source cube you exit
              = in what direction you leave
              
arrival:      destination_face + arrival_angle
              = which face of destination you enter
              = from what direction you arrive
```

---

## route specification structure

```perl
my $route = {
    source => {
        coord   => $bmw384_coord,        # BMW384 coordinate
        face    => $face_index,           # 0-5
        angle   => $departure_angle,      # angle on face
        vector  => $departure_vector,     # 3D unit vector
    },
    destination => {
        coord   => $bmw384_coord,
        face    => $face_index,
        angle   => $arrival_angle,
        vector  => $arrival_vector,
    },
    curve => {
        type    => 'orbital_arc',         # arc | bezier | geodesic
        params  => \@curve_parameters,
        hops    => \@traversed_cubes,     # rasterized grid hops
    },
};
```

---

## method 1: orbital arc route

the natural route between two cube faces following
the BMW384 orbital geometry — a CCW arc through the field.

```
given:    source face + departure vector
          destination face + arrival vector
          
compute:  the minimum-curvature orbital arc
          connecting departure to arrival vector
          
          arc parameters:
            center:    the point equidistant from both vectors
                       in the orbital plane
            radius:    distance from center to the arc
            plane:     defined by the two vectors
            direction: CCW (always — implosion geometry)
            angle:     total arc angle swept
            
rasterize: march along the arc
           at each step: which grid cube contains this point?
           add to hop sequence if new
           
result:   ordered list of traversed cubes
          each cube: entry face + exit face + arc segment
```

### module: route.bmw384.route.orbital-arc

```perl
# name  = route.bmw384.route.orbital-arc
# args  = \%source_spec, \%destination_spec
# descr = compute CCW orbital arc route between two cube face specs

my $src  = shift;
my $dst  = shift;

# [ compute arc parameters from departure and arrival vectors ]
# [ find orbital plane: cross product of vectors ]
# [ find arc center: intersection of bisector planes ]
# [ compute arc angle and direction (always CCW) ]
# [ rasterize: march along arc, collect traversed cubes ]
# [ return route spec with hop sequence ]
```

---

## method 2: vortex spiral route

the intake spiral route — from outer field inward to center.
follows the CCW implosion geometry naturally.

```
given:    source cube in outer rings
          destination: the darksun (position 27)
          
compute:  the spiral that:
            maintains constant angular velocity (CCW)
            decreases radius at the harmonic rate
            (radius reduction: div-13 based)
            arrives at destination face orthogonally
            (the event horizon face — the vortex entry)
            
parameters:
  ω:      angular velocity (constant, CCW)
  dr/dθ:  radial decrease per radian
           = source_radius × (1 - 1/13) per full rotation
           = harmonic implosion rate
           
rasterize: spiral march at uniform angular steps
           collect traversed ring cubes
           
result:   the intake spiral path
          the magenta arm geometry
          each ring cube: knows its segment of the spiral
```

### module: route.bmw384.route.vortex

```perl
# name  = route.bmw384.route.vortex
# args  = $source_coord, [$destination_coord]
# descr = compute CCW implosion spiral route to darksun

my $src  = shift;
my $dst  = shift // { arc => 0, color => 0 };  # darksun default

# [ compute spiral parameters ]
# [ ω: angular velocity from source BMW384 color coordinate ]
# [ dr/dθ: harmonic rate from division by 13 ]
# [ march spiral: angular steps, decreasing radius ]
# [ collect ring cubes in sequence ]
# [ final hop: event horizon face (orthogonal entry) ]
```

---

## method 3: face-to-face direct route

minimum-hop route between two specific cube faces,
respecting the face normal alignment constraint.

```
given:    source face (exit direction known)
          destination face (entry direction required)
          
compute:  the minimum number of cube hops
          where each hop:
            enters through the face aligned with
            the previous cube's exit direction
            exits through a face whose normal
            points toward the destination
            
constraint: no teleportation
            each cube's entry face must be
            geometrically consistent with
            the previous cube's exit face
            (the route is continuous)
            
result:   hop sequence with face-to-face alignment
          at every transition
          the grid verifies each hop independently
```

### module: route.bmw384.route.face-direct

```perl
# name  = route.bmw384.route.face-direct
# args  = \%source_spec, \%destination_spec
# descr = minimum-hop route respecting face alignment

my $src = shift;
my $dst = shift;

# [ A* or Dijkstra through cubic grid ]
# [ heuristic: BMW384 coordinate distance ]
# [ constraint: face alignment at each hop ]
# [ result: hop sequence with face transitions ]
```

---

## method 4: curve rasterization

given any curve (arc, bezier, geodesic):
determine which grid cubes it traverses.

```
algorithm:  ray-march along the curve
            parametric steps: t = 0 → 1
            at each t: compute 3D position on curve
            convert position to BMW384 coordinate
            if new cube: add to hop sequence
            
precision:  step size = minimum cube dimension / 2
            (Nyquist for the grid — no cube skipped)
            
result:     ordered hop sequence
            each hop: entry face + exit face
            determined by which face the curve
            crossed to enter/exit the cube
```

### module: route.bmw384.route.rasterize

```perl
# name  = route.bmw384.route.rasterize
# args  = \&curve_fn, $t_start, $t_end, $steps
# descr = rasterize any parametric curve onto the BMW384 grid

my $curve = shift;   # fn: t → { x, y, z }
my $t0    = shift // 0;
my $t1    = shift // 1;
my $steps = shift // 1000;

my @hops;
my $prev_coord;

for my $i ( 0 .. $steps ) {
    my $t   = $t0 + ( $t1 - $t0 ) * $i / $steps;
    my $pos = $curve->($t);
    my $coord = <[chk-sum.bmw384.coordinate]>->(
        pack 'f*', $pos->{x}, $pos->{y}, $pos->{z}
    );
    if ( not defined $prev_coord
        or $coord->{'arc'}   != $prev_coord->{'arc'}
        or $coord->{'color'} != $prev_coord->{'color'} ) {
        push @hops, $coord;
        $prev_coord = $coord;
    }
}

return \@hops;
```

---

## grid acceptance protocol

each cube independently verifies its segment of the route:

```
cube receives:    incoming face + arrival vector
                  outgoing face + departure vector
                  curve segment through it
                  
verifies:
  1. incoming face is a valid entry face
     (not blocked, not restricted)
     
  2. outgoing face is a valid exit face
     (not blocked, not restricted)
     
  3. the curve segment is geometrically consistent
     (entry point on incoming face ≈ curve start)
     (exit point on outgoing face ≈ curve end)
     (no discontinuity within the cube)
     
  4. face alignment with neighbors:
     incoming face normal ≈ previous cube exit direction
     outgoing face normal ≈ next cube entry direction
     
accepts:          all four pass → route segment valid
rejects:          any fail → route invalid at this cube
                  (the route is self-validating
                   distributed by the traversed grid)
```

---

## the intake spiral route — complete example

the magenta arm: from outer field to darksun

```
source:       arc = 13, color = 0xC00000
              (outer ring, right-side intake position)
source face:  face 0 (+X, pointing inward toward center)
departure:    vector = (-1, 0, 0) rotated CCW by 15°
              (slight tangential component = spiral entry)

destination:  arc = 0, color = 0  (darksun, position 27)
dest face:    face 2 (+Y, the event horizon face)
arrival:      vector = (0, 1, 0)  (orthogonal to disc plane)
              (the vortex entry — straight through)

curve type:   vortex spiral
              ω = CCW, dr/dθ = harmonic rate (div-13)
              
hops:         every ring cube from arc 13 to arc 0
              traversed in CCW spiral order
              each verifying its own segment
              
result:       the complete intake path
              from outer field
              through every ring
              to the event horizon
              orthogonal entry confirmed
              the magenta arm: geometrically specified
              =)
```

---

## connection to existing route modules

```
route.bmw384.route.find:        finds any route (existing)
                                extend with face specification
                                
route.bmw384.route.vortex:      vortex geometry (existing)
                                extend with face-to-face spec
                                
route.bmw384.route.direct:      direct route (existing)
                                extend with curve rasterization
                                
route.bmw384.route.hamming-dist: distance metric (existing)
                                 use for face-direct heuristic
                                 
new modules needed:
  route.bmw384.route.orbital-arc   (method 1)
  route.bmw384.route.face-direct   (method 3 — extends existing)
  route.bmw384.route.rasterize     (method 4 — utility)
```

---

## future methods (pending)

```
method 5:  resonance route
           finds path through cubes sharing harmonic resonance
           with source and destination
           (Haramein resonance scale alignment)
           
method 6:  orbital coupling route
           phase-locks to an existing orbital stream
           rides it to the nearest point to destination
           then transfers
           (Tesla coupling geometry)
           
method 7:  implosion cascade route
           each hop: chooses the cube with highest
           implosion affinity toward destination
           (Schauberger vortex following)
```

#,,,,,,..,,.,,,.,,...,...,,..,.,.,,..,,,.,..,,..,,...,...,..,,,,,,,,.,,,,,,,,,
#CHVXEN5ZUFLQTLVE3TDYREP4EYVXU4E3GLAN25TV2KDK3VKLTZQ65TZLYQ6R3KRQJONHS66Z5OJS4
#\\\|HHOH62KOL57SSMD4THUIQJL6U6E6JJFPKX5TXIQDKZFGUDI5BEF \ / AMOS7 \ YOURUM ::
#\[7]WENBX2LWMRFZEU4XJAQEZ4P2WPYQWJWHCOKHMHPL4CXD7N4HBKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
