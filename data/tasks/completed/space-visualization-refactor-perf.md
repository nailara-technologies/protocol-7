# space.v7.ax visualization: refactor + performance pass

## what this is

A quality-baseline comparison task. This same file (or its lineage) has
previously been refactored/perf-improved by Claude Opus in one pass, with
no introduced bugs, exceeding the target quality bar — notable because
equivalent work done in Sonnet sessions on code of this complexity
typically took many iterations with minor bugs along the way. This pass
is being run to establish a comparable quality baseline against that
prior result. Aim for the same standard: a single pass, no regressions,
no visual/behavioral changes unless explicitly a bug fix.

## file

`data/web-root/vhosts/space.v7.ax/visualization.html` — standalone
HTML/CSS/JS file (single `<script>` block, lines 191-2089). This is a
plain web file, NOT a protocol-7 module — no `<[...]>` module-call
syntax, no AMOS7 signature footer, none of the P7 module conventions
apply here. Treat it as ordinary HTML/JS.

## what it does (context, not instruction)

A manual (non-WebGL) 3D→2D canvas projection of protocol-7's node-group
geometry — nested cubes (`createCube`, `createSubCubes`,
`createOuterCubeEdges`), a hyperspace grid, and live orbital node data
fetched from `/orbital.json` (self/known/connections/nameserv nodes
identified by `p7ref`, i.e. the project's `TYPE:CHKSUM7:ADDR_B32`
checksum-addressing format — decoded via `decodeB32`/`p7refToCoords` in
this same file). Renders resonance tentacles, orbital trails, harmonic
voxels, char rays, and a breadcrumb/navigation system for drilling into
node context. `draw()` (lines ~1390-1785) is the main per-frame render
function called from `animate()` (the requestAnimationFrame loop) —
almost 400 lines, the obvious hot path and refactor target.

## what to do

1. **Refactor for maintainability**: `draw()` in particular is a large
   monolithic function — break it into clearly-named sub-functions where
   that improves readability without changing render order or introducing
   any behavior change. Look for duplicated logic across the various
   `draw*`/`get*` functions (e.g. color/alpha computation, coordinate
   projection calls) that could be consolidated. Use your judgment on
   scope — this is about improving an already-substantial, working file,
   not a rewrite.
2. **Performance pass**: this runs every animation frame via
   `requestAnimationFrame`. Look specifically for: redundant recomputation
   inside the per-frame path that could be cached/memoized between frames
   (e.g. anything not dependent on camera/rotation state that gets
   recalculated anyway), unnecessary object allocation inside hot loops,
   and any O(n²) or worse patterns in the node/connection iteration that
   could scale poorly as `orbitalData.known`/`orbitalData.connections`
   grow. Canvas API calls that could be batched (e.g. repeated
   `ctx.beginPath()`/`ctx.stroke()` pairs for similar strokes) are a
   common win in this kind of code — check for that pattern specifically.
3. **Do not change**: the visual appearance/behavior in normal operation,
   the `/orbital.json`/`/attention.json`/`/templates.json` fetch contract
   (request format, expected response shape), the `p7ref`/checksum
   decoding logic (`decodeB32`, `p7refToCoords`, `encodeB32Bytes`) — these
   must stay byte-compatible with the rest of the protocol-7 addressing
   scheme, not be "improved" independently.
4. If you find an actual bug (not just a style/perf issue) fix it and
   note it clearly and separately from the refactor/perf changes in your
   summary — don't silently bundle a behavior change into a "refactor."

## verification

There's no automated test harness for this file. At minimum, after your
changes: re-read the full modified file once end-to-end and confirm
every function you touched is still called the same way by its callers
(same signature, same call sites), and that you haven't left any
duplicate function definitions or dangling references to removed code.
If you have a way to actually load/render the page and sanity-check it
visually, do that; if not, say explicitly in your summary that this was
not visually verified and should be checked by the human before relying
on it.

## output

Edit `data/web-root/vhosts/space.v7.ax/visualization.html` in place.
Summarize: what was refactored and why, what performance changes were
made and their expected impact, any bugs found/fixed (separately called
out), and whether visual verification was possible. No signing, staging,
or commit commands — the human handles that.

#,,,,,,,,,,..,,.,,...,,.,,,,,,,,.,.,,,,,.,,,.,..,,...,...,..,,...,.,.,.,.,,,,,
#4TZYUH3LDUWA4AHPR3XKB7VJPLTYU2SGKF6UHZHP6JO46XWM5PSYAYHD77VPRUBBXDYBWNSSTQHNK
#\\\|AJYBZJUMBKA6ALIGEIQEOIWXT6RLRFDSRIQXUI44Y227FYXEP7D \ / AMOS7 \ YOURUM ::
#\[7]IZZBCXY34YOCPBCBFTBHPGZVVZPQJPPKF4VZGAKWOTDAINQFTQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
