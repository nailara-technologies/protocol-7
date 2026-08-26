# task: orbital visualization enhancements

## context

the space.v7.ax visualization (`data/web-root/vhosts/space.v7.ax/visualization.html`)
currently renders orbital nodes with glow radius modulation and channel palette trails.
with a single node running, the self + echo node overlap at the same coordinates.
this task is for enhancements once the data layer is confirmed working.

## enhancements

### 1. node label display
when hovering over a node, show a tooltip with:
- hostname (from known[].hostname or "self")
- p7ref (abbreviated NODE:CHKSUM7:ADDR first 8 chars)
- age (from known[].age)
- connection type (self/connected/discovered/nameserv)

### 2. orbital trail CCW direction indicator
the CCW trail system represents the orbital direction of travel.
add a small arrowhead at the tail of each trail to indicate rotation direction.
use the last two history points to compute the tangent direction.

### 3. glow pulse animation
self node glow_shells[0] = 1.0 when cells are placed.
animate the glow as a slow pulse (sin wave, period ~7s) rather than static.
multiply computed radius by `(1 + 0.3 * sin(time * 0.9))`.

### 4. connection tentacle type indicator
encrypted connections (status=encrypted in connections[]) already render as dashed cyan.
plain connections render as static white.
add a subtle color shift: encrypted = cyan (#00ffdd), plain = warm white (#fff0d0).

### 5. orbital.json freshness indicator
`cache_age` in orbital.json tells how old the data is.
if cache_age > 30s, show a subtle "stale data" indicator in the info panel.
if cache_age > 120s, dim all node renders to 50% opacity.

### 6. zoom-to-node on click
clicking a node should smoothly zoom the camera to center on that node's
theta/phi/psi position in the 3D grid coordinate space.
use the existing manualZoom + camera offset system.

## implementation notes

- all enhancements should be additive — preserve all existing rendering logic
- use requestAnimationFrame timestamp for animations (already available as `now`)
- the info panel already has `.sel` class for selected node display
- orbital.json is fetched every 13s — animations should interpolate between fetches

## signatures note

this task modifies `data/web-root/vhosts/space.v7.ax/visualization.html` only.
no P7 module signatures involved.

#,,,.,,,,,.,,,...,,,.,,..,.,.,,,,,.,,,...,,,.,..,,...,..,,,,.,,..,,..,,,.,,,.,
#2LVKN7PHKGBYQ6NJV5A34Y2UJQZAJ3CICC2TXIGE6Y77B7STE4SPW2MKGJPRIXK5N6CFRTBSPY7OQ
#\\\|YFMO35RGMQPIEKDXBVKBTJMTUDGYKMQLRVUX2WIGHIXT6XA46ND \ / AMOS7 \ YOURUM ::
#\[7]INOCDZWK3ZM42A5JXLNTM7OAY5PXIGWKKO2JRIKCJNRXCDIPSADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
