## [:< ##

# name  = task: implement BMW384 visual disc — multi-ring CCW spiral visualization
# descr = extend route.bmw384.visual.wheel to support multiple concentric rings,
#         each with CCW hue drift and arc label advance, creating a CD/vinyl disc
#         structure with a depth-encoded alphabet and color vortex spiral

## background

the current wheel renders one ring of nodes at radius 320. this task adds optional
concentric inner rings, each:
- at a smaller radius (outer - ring_index * ring_radius_step)
- with hue rotated CCW by ring_hue_drift degrees per ring
- with arc labels advanced by ring_label_advance positions per ring

result: viewed radially (spoke direction), each position reads A, B, C... inward
— the alphabet becomes a depth coordinate. the hue drift creates a CCW color
vortex spiraling toward the center void. the full structure resembles a CD or
vinyl disc with data encoded in concentric tracks.

## parameters (read from zenka config with defaults)

  <route.bmw384.cfg.rings>             -- number of rings (default: 1)
  <route.bmw384.cfg.ring_hue_drift>    -- CCW hue degrees per ring (default: 14)
                                          [ 360/26 ≈ 13.846 = one arc segment ]
  <route.bmw384.cfg.ring_label_advance> -- arc label offset per ring (default: 1)
  <route.bmw384.cfg.ring_radius_step>  -- pixels between rings (default: 40)
  <route.bmw384.cfg.outer_radius>      -- outermost ring radius (default: 320)

with rings=1 the output is identical to the current single-ring wheel.
with rings=26 the full alphabet cycle completes both around and inward.

## what to modify

### modules/route.bmw384.visual.wheel

extend to support multiple rings. the index is re-used for all rings — same 3873
nodes, plotted at different radii with different hue and label offsets.

structure:

  my $rings            = <route.bmw384.cfg.rings>              // 1;
  my $ring_hue_drift   = <route.bmw384.cfg.ring_hue_drift>     // 14;
  my $ring_label_adv   = <route.bmw384.cfg.ring_label_advance> // 1;
  my $ring_radius_step = <route.bmw384.cfg.ring_radius_step>   // 40;
  my $outer_radius     = <route.bmw384.cfg.outer_radius>       // 320;

for each ring index $ring ( 0 .. $rings - 1 ):
  - radius = $outer_radius - $ring * $ring_radius_step
  - hue_offset = $ring * $ring_hue_drift  [ CCW = subtract from hue ]
  - label_offset = $ring * $ring_label_adv [ mod 26 ]
  - plot all nodes at this radius with adjusted hue and label

hue adjustment per ring:
  $hue = ( 180 - int( $coord->{'color'} / 16777216 * 360 ) - $hue_offset ) % 360;

arc label adjustment per ring (for spokes and labels):
  the spoke positions stay fixed (geometry doesn't change)
  but the label shown at each spoke position advances by label_offset:
  $label = chr( ord('A') + ( $ARG + $label_offset ) % 26 )

node opacity: exponential falloff per ring to suggest axial depth:
  opacity = 0.85 * (0.75 ** $ring)
  [ ring 0: 0.85, ring 1: 0.64, ring 2: 0.48, ring 3: 0.36 ... ]
  [ formula can be fine-tuned later — use sprintf '%.2f' for SVG ]

node radius: reduce slightly per ring:
  $r = max(2, 4 - int($ring / 3)) + ($colocated_index * 2)

## spoke and label rendering

spokes are drawn once (geometry is ring-independent).
labels: draw one set of labels per ring at the appropriate radius,
advancing the letter by label_offset. label opacity also reduces inward matching the depth falloff:
  label opacity = 0.3 * (0.75 ** $ring)  [ minimum 0.05 ]
  label font-size = max(7, 10 - $ring)
  label radius = $radius + 12  [ just outside the ring ]

## cmd.visual-wheel changes

add support for ring count in the command arg:
  p7c index.visual-wheel file 3   -- generates 3-ring disc
  p7c index.visual-wheel html 5   -- 5-ring disc as HTML page

parse: if args contain a number after svg/html/file, use it as rings override.
set <route.bmw384.cfg.rings> temporarily for the render call.

## read first

- modules/route.bmw384.visual.wheel  -- current implementation to extend
- modules/route.bmw384.cmd.visual-wheel  -- command handler to update

## notes on signatures

- modifying existing files: signing system re-signs on commit
- no new files needed

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas in zenka modules

#,,..,..,,,,,,..,,,.,,,,.,,..,,,,,..,,...,,,.,..,,...,...,..,,..,,,,,,..,,.,,,
#PF6JSUKEIIR3AOFWKPXI7PL6ZWEYQHL62KM2PZYGFRRUVVP2N2SIKN7SQB75N34PKKUAX6NY7NSUK
#\\\|57IO3Y7ADEN5NSBHX72667E3EGUIFEOK53GKSK7K53TZP6RXYNB \ / AMOS7 \ YOURUM ::
#\[7]ATOYHXKMS3S2KHNMQ77SD7F7FT66TT64WMTKA74M6NRKNPRHBEBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
