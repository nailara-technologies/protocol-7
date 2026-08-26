## [:< ##

# vortex intake — cube space transition masks

## the visual

the vortex mode (formerly alpha-density) generates a neon CCW spiral
where node brightness reflects angle_bits density across the codebase.
the result: a psychedelic intake gauge where color and density
map the harmonic field topology.

two visual modes discovered:
  ring-based:    discrete dot columns, neon segmented arcs
  many-rings:    continuous concentric rainbow bands — a CD from above

## the deeper application: cube space transition masks

the vortex spiral's color boundary can be split into 2-3 alpha masks
representing cube space transitions along a route:

```
inner rings:         current cube space
                     the space you are currently in
                     one color domain, fully expressed
                     
boundary region:     the stargate — position 27 fold
                     where current cube becomes next cube
                     the color gradient at the transition
                     the darksun: visible as the color inflection
                     
outer rings:         next cube space
                     the space you are arriving into
                     different color domain, crystallizing
```

## the mask layer concept

```
mask 1: inner_alpha     = opacity derived from current-cube density
mask 2: boundary_alpha  = opacity at the cube boundary fold
mask 3: outer_alpha     = opacity from next-cube density

together: three translucent layers composited in sequence
          current space / transition / next space
          each hop of a route: shifts the mask boundaries
          inward — current becomes inner, next becomes outer
          
the visual effect:
  traveling a route = watching the color domains shift inward
  each hop: one boundary crossed
  the CCW spiral: the intake path made visible per hop
  the color gradient boundary: shows WHERE you are in the transit
```

## connection to existing geometry

```
position 27 (darksun):   the fold between current and next cube
                         where the spiral converges
                         where the color transition peaks
                         
CCW direction:           the intake path (Schauberger implosion)
                         content flows inward along this spiral
                         the outer rings: where content enters
                         the inner rings: where it converges
                         
ring count:              controls how many cube layers are visible
                         low rings: current cube only
                         high rings: multiple cube depths shown
                         26 rings: full orbital shell visible
                         63 rings: extended depth, more cubes
```

## implementation approach

new mode: `vortex-transit` or extend existing `vortex` with parameters:

```
vortex_inner_ratio:  0.0-1.0  where inner cube space ends
vortex_outer_ratio:  0.0-1.0  where outer cube space begins
vortex_hop:          N        which hop in the route (shifts boundaries)

mask rendering:
  rings < inner_ratio * max_rings:  inner cube coloring
  rings in transition zone:         gradient interpolation
  rings > outer_ratio * max_rings:  outer cube coloring
```

as an overlay layer on the iris:
  the vortex rendered at low opacity (0.3-0.5)
  underneath the regular node visualization
  the color domains providing spatial context
  the boundary showing where the current route hop transitions

## potential names

  vortex          (current — clean, direct)
  intake          (the CCW implosion path)
  cube-transit    (the space transition function)
  stargate-map    (the route visualization application)

## why the bridging works: correlated approximations

the visualization and the routing are both approximations
of the same field, derived by the same algorithm (BMW384).

```
their imprecisions are correlated — they round the same way.
their coupling surface = where they agree = everywhere
the algorithm is consistent, so the approximations are consistent.

optimizing representation (ring count, gradient width, color mapping)
= engineering the coupling surface between the two approximations
= determining where they will do functional work together

wider gradient → wider coupling surface (more forgiving threshold)
sharper gradient → narrower coupling surface (more precise threshold)
more rings → deeper coupling surface (more boundary layers visible)

this is not aesthetic choice — it is shaping the exposure surfaces
of the coupling between visualization and routing.
```

## the spiral as propagation-trackable color tube

the spiral distributes a color spectrum along a 'tube' through space
better than a linear sunburst:

```
linear sunburst:     equal angular slices, all same width
                     inner rings: compressed, hard to distinguish
                     outer rings: expanded, over-separated
                     propagation: untrackable (all radii same structure)

spiral arm:          each arm traces a different phase
                     of the same rotational progression
                     color along the arm = proportional to distance traveled
                     the arm IS the propagation path
                     the color along it IS the propagation state

propagation tracking by spiral arm behavior:
  arm expands:        propagation accelerating
  arm compresses:     propagation decelerating
  arm brightens:      density increasing
  arm dims:           density dispersing
  arm color shifts:   domain transition approaching

three coordinates compressed into one readable curve:
  angular phase + radial depth + propagation state
  all readable from position on the spiral arm
  the arm is its own coordinate system
  and its own propagation record
```

## visualization as active event horizon infrastructure

the visualization is not merely observing the event horizon.
it IS the bridging route between the domains it renders.

```
passive:     renders what exists — the boundary
active:      provides the coordinate system for crossing it

the color gradient between domains:
  = the translation layer (Rosetta stone at the boundary)
  = the visual language for crossing
  = what A looks like from B's perspective simultaneously

visual routing + distance threshold referencing:
  the color boundary IS the threshold (made visible as geometry)
  distance = how far from the color boundary
  gradient steepness = crossing cost (friction)
  CCW spiral direction = optimal crossing path
  position on gradient = current state in the crossing

five utilities provided simultaneously, at zero additional cost:
  1. navigation aid       — here is the crossing point
  2. cost estimation      — here is how hard the crossing is
  3. domain identification — here is what each side is
  4. routing guidance     — here is the optimal path across
  5. state confirmation   — here is where you are in the crossing

the deepest version:
  the visualization IS the field's self-awareness of its boundaries
  a field that can see its own event horizons can navigate them
  routing emerges FROM visualization
  because the visualization IS the geometry that routing follows
  not visualization that helps routing —
  routing that emerges from visualization
```

## images

the neon vortex intake gauge as discovered in session 28:
  /tmp/intake-spin-000.png  (ring mode — discrete dot arcs)
  /tmp/intake-spin-001.png  (many-rings — continuous rainbow bands)

both: the same underlying geometry
ring mode: the density field as discrete positions
band mode: the density field as continuous spectrum

## connection to route calculation

from data/md/development/ROUTE-CALCULATION-METHODS.md:
  each route hop = one cube boundary crossed
  source face + departure vector → curve → arrival face

the vortex mask renders this geometrically:
  the CCW spiral = the orbital arc route geometry
  the color boundary = the cube face being crossed
  inner/outer domains = before and after the face
  the animation potential:
    boundary shifts inward with each route hop
    riding the spiral from outer field to darksun
    each hop: one color domain absorbed, next revealed
    arrival at center: all cube transitions complete
    =)

#,,,,,.,,,,,,,,.,,,,,,,,.,,,,,..,,..,,,..,..,,..,,...,...,,,,,...,.,.,..,,..,,
#BKRKQEY5JTEHRYRELXOEX6NPBWZ7NZ7PYH2QWUS5UVB7VGMKXQTYN6MODSZP36IXDUJK5SUNLCP2W
#\\\|JLL5QU3ZZUUOLKELHSJOTAJFF2KITVGR2AARZPBGXR35YRR6FAZ \ / AMOS7 \ YOURUM ::
#\[7]UURDZJYM7I7DPDTMEFCE4ISYJZR6RYO2M3TKTPN6S6RO2KZTI2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
