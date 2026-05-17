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

#,,,,,,..,,,.,..,,.,.,,,.,,..,...,.,.,.,.,,,.,..,,...,...,,,,,..,,,.,,,.,,.,.,
#7Z32I34WOOVIJ6H7LJO5XYVJJEYB6H76FN274GKVITH5B2CXCKKHVRSMQDLGOD2DMYUQYLEMFQGF2
#\\\|3ZQ5D6DGNCJZAXKAWROUQ2CNH55QYWXV2ACJMOG3P4F5CLSV6FK \ / AMOS7 \ YOURUM ::
#\[7]FQJH6TBSQER4RRETPMJWVEK7GKGHFS5FOH4EJXPPPGAON55GNIDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
