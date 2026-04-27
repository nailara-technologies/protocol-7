# cursor address resolution layer

## goal

Wire the visualization selX/Y/Z to the graphics-matrix zenka cursor so that
`p7c graphics-matrix.cursor-state` always reflects the live grid position the
user is navigating in the browser.

## current state

- visualization.html has `let selX = 0, selY = 0, selZ = 0` (line 259)
- `moveSelection(dx, dy, dz)` is the only mutation point (line 1852)
- cursor-state and address modules are working: `p7c graphics-matrix.cursor-state`
  returns selX/Y/Z, checksum, zoom, radius
- graphics-matrix zenka has `cmd.cursor` which accepts set/move/state/checksum subcommands
- the web zenka serves space.v7.ax — it can route commands to graphics-matrix

## what needs to be done

### 1. add a POST endpoint for cursor updates (web/httpd side)

Add a handler for `POST /cursor` (or `POST /api/cursor`) on the space.v7.ax vhost that:
- reads JSON body `{selX, selY, selZ}`
- routes to `graphics-matrix.cursor set <x> <y> <z>` via p7c or protocol-7.route-send
- returns 204 or minimal JSON `{ok:true}`

Check how other POST handlers work in the web/httpd layer first
(look at plugin.web.space.* modules and how httpd handles POST bodies).

### 2. add debounced cursor push to visualization.html

In `moveSelection(dx, dy, dz)` (line ~1852), after updating selX/Y/Z, call a
debounced function `scheduleCursorPush()` that:
- waits 150ms after last move
- POSTs `{selX, selY, selZ}` to `/cursor` (fire-and-forget, no await blocking render)

Also push on page load after fetchTemplateData completes (so zenka starts at 0,0,0 confirmed).

### 3. verify

After wiring:
- navigate in visualization (arrow keys or WASD)
- `p7c graphics-matrix.cursor-state` should reflect the current position
- `p7c graphics-matrix.address` should show all encodings for the live position

## notes

- signatures_note: do not add stub signature lines to new files; leave clean for signing system
- the graphics-matrix zenka cmd.cursor already handles `set <x> <y> <z>` — verify this
  by checking modules/graphics-matrix.cmd.cursor before writing the POST handler
- keep the POST handler lightweight — no auth needed for local loopback vhost
- debounce is important: arrow key held down fires many moveSelection calls per second

#,,..,...,.,,,.,,,,..,,,.,,,.,,..,...,.,.,,,.,..,,...,...,,.,,...,,..,...,.,.,
#D4HZV362CHXOA564VLVW5IOJLRQTI7UXVHP3BF7SVTEIRQXVUIQ4F7YHI5WIWIBX6CZGIAH4IRGYS
#\\\|JPUIUTU6TTGM2B26P7SFDYRRH74D7LOE53TL5CKM7ZX3B5E7RHD \ / AMOS7 \ YOURUM ::
#\[7]WTHF5JRL6IL737C2PFJ4QKE3QF77FUUUXN6DHVJMXLIP7ZK4XMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
