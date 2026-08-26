## [:< ##

# name  = task: implement bmw384 visual wheel — SVG field visualization
# descr = render registered field index nodes as colored points on a 360-degree wheel,
#         arc segment boundaries marked A-Z, cluster density visible.
#         the holographic console starting point — topology directly observable.

## depends on

task: bmw384-field-index.md — field index with stats and query-arc must exist.
task: bmw384-node-coordinate.md — coordinate structure must exist.

## background

the BMW384 wheel visualization plots each registered node as a colored dot on a
circular field. the 24-bit color value maps to an HTML color (via the color field
directly as an RGB value). the angular position within the arc maps to the radial
angle on the SVG circle. arc segment boundaries (A-Z) are drawn as faint spokes.

the result is a self-representing field map — cluster density, color gradients,
and arc distribution are immediately visible without any external legend or metadata.
nodes that are routing neighbors appear visually close. co-located nodes (same
coordinate) stack as concentric rings.

## output format

SVG — self-contained, no external dependencies, renderable in any browser or
embedded in the jobs vhost or space.v7.ax dashboard.

## modules to create

### src/base.bmw384.visual.wheel

generates the full SVG string. no params — reads from <bmw384.index> directly.
returns a scalar containing the complete SVG document.

SVG structure:
  - viewBox: "0 0 800 800", centered at 400,400, radius 360px
  - background: #0a0a0f (near-black, consistent with P7 dark theme)
  - arc segment spokes: 26 lines from center to edge, 1px, rgba(255,255,255,0.08)
  - arc labels: A-Z at the outer edge of each spoke, 10px, rgba(255,255,255,0.3)
  - for each node in index:
      angle_deg = ( $arc * (360/26) ) + ( $within_arc_offset * (360/26/16777216) )
      where within_arc_offset = color mod (16777216/26)
      x = 400 + 320 * sin( angle_deg * PI / 180 )
      y = 400 - 320 * cos( angle_deg * PI / 180 )
      color_hex = sprintf '#%06X', $coord->{'color'}
      draw circle: cx=$x cy=$y r=4 fill=$color_hex opacity=0.85
      draw title element (SVG tooltip): node name + coordinate_str
  - center void: circle r=24, fill=none, stroke=rgba(255,255,255,0.15), stroke-width=1

### src/base.bmw384.visual.wheel-html

wraps the SVG in a minimal HTML page for standalone browser viewing.
adds: dark background body, centered SVG, title "BMW384 Field — [node count] nodes".
returns complete HTML string.

### src/base.bmw384.cmd.visual-wheel

command handler: p7c <zenka>.visual-wheel [html]

  - no arg or 'svg': return raw SVG via { mode => 'size', data => $svg }
  - arg 'html': return full HTML page
  - arg 'file': write to /tmp/bmw384-wheel.html and return the path

## arc angle calculation details

the full circle = 360 degrees, divided into 26 arc segments.
each arc segment spans 360/26 ≈ 13.846 degrees.
within an arc, the color remainder (color mod segment_width) maps linearly
to position within that arc's angular range.

  my $segment_width  = 16_777_216 / 26;
  my $arc_start_deg  = $coord->{'arc'} * ( 360 / 26 );
  my $within_arc_frac = ( $coord->{'color'} % $segment_width ) / $segment_width;
  my $angle_deg      = $arc_start_deg + $within_arc_frac * ( 360 / 26 );

## co-located nodes (same coordinate)

if multiple nodes share the same coordinate, draw them as concentric rings:
  r = 4 + ( $colocated_index * 3 )
this makes redundancy visually apparent — a thick ring = multiple co-located nodes.

## notes on signatures

- new files: leave clean, no stub footer
- use sprintf for all numeric formatting — no external modules needed for SVG generation
- PI constant: use POSIX::acos(-1) or hardcode 3.14159265358979
- the visual output should be usable immediately from nshell:
    p7c <zenka>.visual-wheel file  →  firefox /tmp/bmw384-wheel.html

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas in zenka modules
- SVG/HTML strings: use heredoc or concatenation, keep readable

#,,.,,,,,,,,.,,..,,.,,,.,,..,,,,,,,,.,,..,,..,..,,...,...,.,,,,,.,.,,,,,,,,,,,
#NEOIGTB3NUF2SOW6IMFDBRELRZJKUMY6Q3GKLTMU3TDOH2QRYRQCIXBLGFRGMU5NOBNLWI7ZHWK22
#\\\|5TZ7XNPHEG5UFYN2NS4XH6KST5KVBGH6Q5RS4C7XO5GFJ7O37GU \ / AMOS7 \ YOURUM ::
#\[7]QNWYLDUWSVAFXEI5WKMY5ZA3XSS4UMZ3522J4COS5FWDOML5FCDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
