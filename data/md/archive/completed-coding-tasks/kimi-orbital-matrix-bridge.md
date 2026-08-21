# task: orbital → graphics-matrix bridge + visualization enrichment

## context

protocol-7 has two untested but fully implemented subsystems that need to be wired together
and validated through the live visualization at space.v7.ax:

1. **orbital stack** (nodes → discover → external): nodes.orbital.* computes a time-derived
   @INDEXCUBE position from local IP + session key, exposes it as a P7REF. discover relays
   P7REFs via mcast. external connects discovered nodes via trunc with grid map sync.
   currently untested with live data.

2. **graphics-matrix zenka**: 44 modules — cursor/glow/channel/address/cell/graph pipeline.
   cells are placed on a 3D lattice, glow intensities computed per hop-shell, channels
   separate frequency bands, graph edges encode similarity clusters.
   currently untested end-to-end.

3. **space.v7.ax visualization**: fetches /orbital.json every 13s. currently renders raw
   orbital node positions (theta/phi/psi/omega coords + p7ref). the viz already has node
   color logic (self=blue, connected=cyan, discovered=fluorescent, nameserv=purple) and
   CCW trail system. it does NOT yet consume graphics-matrix data.

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files. leave new files clean.
real signatures are added by `bin/Protocol-7 sourcecode update-signatures` after the fact.

## what to build

### step 1 — register orbital nodes as graphics-matrix cells

create `plugin.web.space.orbital.to_cells` — a module that:
- reads `web.space.orbital.cache` (same source as plugin.web.space.orbital.json)
- for each known orbital node, derives a cell position from its theta/phi/psi:
  - selX = round(theta * 6 / pi)   (maps -pi..pi → -6..6)
  - selY = round(phi * 3 / pi)     (maps -pi/2..pi/2 → -3..3)
  - selZ = round(psi * 4 / (2*pi)) (maps 0..2pi → 0..4)
- calls graphics-matrix.cell.place for each node with:
  - position: {selX, selY, selZ}
  - refs: 1 (initial weight)
  - meta: {p7ref, type} where type = self|connected|discovered|nameserv
- calls graphics-matrix.cursor.set to place cursor at self node position
- calls graphics-matrix.glow.compute to recompute glow shells after placement

wire this into `plugin.web.space.fetch` — add a call to
`plugin.web.space.orbital.to_cells` after existing cursor-state + graph fetches.

### step 2 — enrich orbital.json with graphics-matrix output

update `plugin.web.space.orbital.json` to:
- after building the existing payload, call graphics-matrix.glow.query for hops 0..5
  to build a glow_shells array: [intensity_0, intensity_1, ..., intensity_5]
- call graphics-matrix.channel.current to get active channel + palette
- call graphics-matrix.graph.survey to get cluster info (counts + total)
- add these to the payload as:
  ```
  glow_shells: [0.0, 0.42, 0.31, ...]   # per-hop glow intensities
  channel: { index: N, name: "...", palette: [...] }
  graph: { counts: {...}, total: N }
  ```
- use route-send pattern to call graphics-matrix commands (graphics-matrix is a separate
  zenka from web space). the calls must be async via protocol-7.route-send with reply
  handler, OR call synchronously via protocol-7.command.send.local if graphics-matrix
  is registered as accessible from web space plugin context.

  **check** `cfg/zenki/cube/access.zenki` to see if graphics-matrix commands
  are accessible from the web/httpd context. if not, add them.

### step 3 — update visualization to consume enriched data

update `data/web-root/vhosts/space.v7.ax/visualization.html`:
- the /orbital.json response now includes glow_shells, channel, graph fields
- use glow_shells to modulate node render radius: node radius *= (1 + glow_shells[0] * 2)
  for self node, glow_shells[1] for hop-1 nodes, etc.
- use channel.palette (array of hex colors) to tint the CCW orbital trails — cycle through
  palette colors based on node index mod palette.length
- use graph.total > 0 to show/hide a "clusters active" indicator in the info panel
- keep all existing rendering logic (zoom layers, calcRangeAlpha, tentacles, toggles) intact

### step 4 — add graphics-matrix.cmd.orbital-sync command

create `graphics-matrix.cmd.orbital-sync` — a command handler that:
- accepts no args
- calls graphics-matrix.cell.list to get current cell count
- calls graphics-matrix.glow.compute to refresh glow
- calls graphics-matrix.graph.survey to get current cluster state
- returns a summary: { cells: N, glow_total: F, clusters: N, channel: {...} }
- register it in the access.cmd.usr.cube line in cfg/zenki/graphics-matrix/zenka.v7

this gives `p7c graphics-matrix.orbital-sync` as a manual test command.

## testing approach

once implemented, test sequence:
1. `p7c graphics-matrix.orbital-sync` — should return cells:0 initially (no nodes placed)
2. `p7c nodes.orbital.current-position` — verify orbital params are live
3. `NO_PROXY=127.0.0.1 curl -s -H "Host: space.v7.ax" http://127.0.0.1/orbital.json` 
   — check glow_shells, channel, graph fields appear in response
4. open visualization in browser, observe glow-modulated node sizes + tinted trails

## files to create/modify

- create: `src/plugin.web.space.orbital.to_cells`
- modify: `src/plugin.web.space.fetch` — add to_cells call
- modify: `src/plugin.web.space.orbital.json` — add glow/channel/graph fields
- modify: `data/web-root/vhosts/space.v7.ax/visualization.html` — consume new fields
- create: `src/graphics-matrix.cmd.orbital-sync`
- possibly modify: `cfg/zenki/cube/access.zenki`

## style

- all comments lowercase, bracket annotations `[ word ]`
- no trailing stub signatures — leave files clean for bin/Protocol-7 sourcecode update-signatures
- use `<[module.name]>->()` syntax for internal calls
- use `$data{'zenka-name'}{'key'}` for zenka data tree access
- use `protocol-7.route-send` for cross-zenka calls, `protocol-7.command.send.local` for same-zenka

#,,,,,,,,,,.,,..,,,.,,...,...,.,.,,,,,.,.,.,.,..,,...,...,,.,,,,.,..,,..,,...,
#CIOENM5YH7ZJLGJDET5THYRM5IV2RKCLMZZP4RA5PQIDW3VK744YNN5Y3G4UKJ2TLWSBATAZKLKAU
#\\\|BHNO7IGGSAWAANHQUG6HVYUY5BXF35MJYOQMIQPT35KDTVOASOQ \ / AMOS7 \ YOURUM ::
#\[7]O3ZYUEVBXAYLW4KNURZIO6Z66MMRXWHHE5NBY44QNGH67ISHVGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
