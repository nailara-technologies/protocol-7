# task: 3D grid cursor for visualization

## context

`data/web-root/vhosts/space.v7.ax/visualization.html` has a selection cursor
at `{selX, selY, selZ}` (integer grid coordinates) which the camera lazily
follows via `camX/Y/Z` lerping toward `selX/Y/Z`. arrow keys currently do
camera rotation (a temporary workaround). this task restores and improves the
cursor to be a visible, interactive 3D element.

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of any new files.
leave new files clean for the signing system.

## current state

- `selX/Y/Z` declared at line ~205, integer grid coords
- `moveSelection(dx,dy,dz)` increments them (line ~1725)
- camera lerp toward sel at `CAM_FOLLOW_SPEED = 0.06` (line ~211)
- arrow keys currently bound to `rotY/rotX += 5` (temporary)
- `FORMATION_SPACING = 420`, `CUBE_SIZE = 140` — 1 grid unit = 420 world units

## task

### 1. restore arrow key cursor movement

restore arrow keys to call `moveSelection(±1, 0, 0)` / `moveSelection(0, 0, ±1)`.
PageUp/PageDown keep `moveSelection(0, ±1, 0)`.
camera lazy-follows as before.

### 2. visible 3D cursor glyph

draw a visible cursor at the projected position of `{selX, selY, selZ}` in
world space. use `FORMATION_SPACING` to convert grid coords to world coords
(same as the edge indicator uses: `selPos * FORMATION_SPACING`).

glyph: a wireframe cube outline at the cursor position, size ~`CUBE_SIZE * 0.4`.
use `createCube()` or draw 12 edges directly via `project()` calls.
color: `rgba(80, 180, 255, 0.6)` with a soft glow halo.
pulse: animate opacity with `0.5 + 0.5 * sin(now * 2.1)`.

draw the cursor in the main `draw()` loop after the grid, before nodes.

### 3. magnetic snap to nearby nodes

when the cursor comes within 1 grid unit of a node's harmonic grid address,
snap `selX/Y/Z` to the nearest integer coordinates of that node.

node positions are at radius 140 in world space via `p7refToCoords()`.
convert back to grid coords: `nodeGridX = Math.round(nodeWorldX / FORMATION_SPACING)`.

snap condition: `Math.abs(selX - nodeGridX) <= 1 && ...` for all axes.
on snap: set `selX/Y/Z = nodeGridX/Y/Z`, highlight cursor glyph gold
`rgba(255, 200, 50, 0.9)` and set `selectedNodeP7ref` to that node.

### 4. cursor HUD readout

update the existing `selD` display (line ~1715) to also show the world-space
distance from cursor to nearest node:
`Selection: ${selX}, ${selY}, ${selZ} | nearest: ${dist.toFixed(0)}u`

## acceptance

- arrow keys move cursor, camera lazily follows
- cursor glyph visible as wireframe cube, pulses
- approaching a node snaps cursor and highlights it gold
- cursor readout shows nearest node distance

#,,,,,,..,..,,..,,,,.,.,.,...,...,,..,,.,,.,,,..,,...,...,,,.,.,,,,,.,...,,,,,
#FPU6D3BLS6JR43QIGCZT5ENWAFWDSY26WUYG7LN53G7Q2IIISGTGBD6J36J2EYWZMI4X3R2LOGWB4
#\\\|NK37JQH2MXYUC26M53Q4MUBJCPIII6ZY2I5MIXAX2ST66RULBQM \ / AMOS7 \ YOURUM ::
#\[7]J24KQUQEIC2IT5IR6VJNGYP2XZVCHGOLAHMAD7VM6VF4UK4UQ6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
