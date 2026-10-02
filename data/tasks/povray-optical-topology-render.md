# povray : rendered optical network topology

brief [ 2026-10-02 ]. a calculated and rendered image of the network's
actual state : routes and streams as light. infrastructure exists :
`povray` zenka [ `povray.cmd.render <template> <yaml|json context>` ->
async render, png path ; `povray.template.resolve` ] and
`data.topology.interference.map.generate_povray_csg` [ topology nodes ->
csg ]. needs a new template + a context builder, not a new system.

## scene conventions [ user ]

- **nodes** on the cube grid or the geodesic sphere [ icosahedron vertices
  on the three orthogonal golden rectangles, see SPACE-ENGINE-MASTER ]
- **tunnels** as round cylinders
- **fibers** as square profiles : they carry two 90° distinctions
  [ horizontal \ vertical ] ; physics match : rectangular waveguides and
  polarization-maintaining fibers keep a fixed polarization axis, round
  ones do not
- **90° swap announcement** on a grid route : rendered as a specific
  oscillation or reflection wave along the fiber before the swap
  [ physics match : polarization rotation by a half-wave plate \ faraday
  rotator ]
- **color by cascade stage** : uv -> blue -> green -> yellow -> orange
  per stage passed [ fluorescence down-conversion, one-way ]
- **decisions** : where paths cross, marked as small bright points
- dark background, blacklight palette, calm defaults

## render physics

povray has photon mapping, dispersion and emitting media -> caustics and
glowing fibers. no true fluorescence : model each cascade stage as an
emitting color.

## work

1. template `optical-topology` for `povray.cmd.render`
2. context builder from live routes \ streams [ node positions, edges with
   type tunnel|fiber, stage per edge, crossing points ]
3. test scene with a handful of nodes before live data
4. later : frame sequence for animation [ lookahead : paths known in
   advance render at higher quality ]

#,,..,,,,,,..,,,,,..,,.,.,,,,,,,.,.,,,,..,..,,..,,...,...,.,,,.,.,...,...,...,
#EA5EQBRN7Z5LLHJWMUI2QRHTJX2HPYJT7TCYV7OPSXEEE2BDHXDMI4OJDIOXCYZBZHLD4ASTX5EYI
#\\\|FY2EK2PRACNCO6B23RYPVUGYETGW4YCWW7BOLUH6GT63KDHXCEM \ / AMOS7 \ YOURUM ::
#\[7]AWZJJAZ2BRTSKT7YVRRAN3OIVMPYR5HKMAUCYQM64OW5MOGCKWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
