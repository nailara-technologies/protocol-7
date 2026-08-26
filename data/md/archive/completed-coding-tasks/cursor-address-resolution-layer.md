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
  by checking src/graphics-matrix.cmd.cursor before writing the POST handler
- keep the POST handler lightweight — no auth needed for local loopback vhost
- debounce is important: arrow key held down fires many moveSelection calls per second

#,,,,,,,.,,,.,.,.,.,,,.,.,.,.,,,.,.,.,,..,,..,..,,...,...,..,,...,.,,,.,,,,.,,
#5D26EBSM2LZF6P4R7GFCG662WZSUIWMT3B7L3DKL4GG3HKXKQWMJK6CP57ZJBJ4TOD565DGDUQ2ZM
#\\\|UJQLLGPNTQ5B6JK2YVSYA6S53BVQ3GTLGOGGGJSDH7WR6M2GBLU \ / AMOS7 \ YOURUM ::
#\[7]G35GMP7NQO7DZO635ULK5TGS3EHLRWIK4YLXRPZNWHNWUEOIPKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
