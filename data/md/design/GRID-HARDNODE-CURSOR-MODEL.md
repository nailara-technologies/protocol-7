## [:< ##

# name  = GRID-HARDNODE-CURSOR-MODEL
# descr = grid-hardnode as cursor, addressing model, and visual interface

> screenshots: `data/gfx/cubic-space-topology/` — reference renders pending


---

## the cursor is not the node-group

the grid-hardnode cursor is **not** the 8-node formation at its center. it is the
**lit grid layers surrounding it** — the illuminated reach of the node-group into
the network at first iteration. the formation is the dark center; the cursor is
what it makes visible.

this distinction matters architecturally: the cursor represents an **immediate local
addressing space** — what the node-group sees of the network at hop distance 1. it
is not a static marker but a live visibility sphere, rendered as glow.


---

## zoom-level semantics

```
zoom level        visual                   functional meaning
──────────────────────────────────────────────────────────────────────────────
zoomed in         8-node formation         3D sub-cursor — fine data addressing
                  (cube edges, vertices)   each node = addressable data position

mid               block cursor             immediate local addressing space
                  (lit grid layers)        hop-1 visibility sphere, 63 neighbors

zoomed out        holographic pixel        point in meta-grid
                  (uniform glow block)     itself a block cursor at next scale up

further out       pixel cluster            second recursion — same topology,
                                           different scale, same addressing rules
```

the transition between levels is continuous — the block cursor doesn't switch
modes, it is the same object seen at different resolutions. zoom is the only
parameter that changes which functional layer is active.


---

## vision propagates in waves

each network cycle expands the visible radius by one hop:

```
cycle 0  →  node-group only (8 positions, internal state)
cycle 1  →  hop-1 shell: 63 overlapping neighboring subcubes (the block cursor)
cycle 2  →  hop-2 shell: neighbors of neighbors (cursor glow radius expands)
cycle N  →  N-hop visibility sphere, glow intensity = 1/distance
```

**closer = brighter = lower hop count = stronger influence**. the glow gradient
IS the influence gradient, rendered live from reference counts at each distance
shell. the balance engine's expansion/implosion dynamic becomes directly visible:
influence concentrating = glow brightening; eviction = glow contracting.

the 8×63 structure is hop-0 + hop-1: the node-group (8) surrounded by all
overlapping subcubes that share at least one position (63). this is the cursor's
minimum footprint — the lit block at mid zoom.


---

## the 2D terminal bridge

the zoomed-out block cursor is already a rectangular block of uniform luminosity.
projected onto a flat plane it IS a terminal block cursor — same semantics:

- position in a matrix
- moves through the space
- sub-addresses into regions
- represents the "active" location

the terminal matrix (nshell, any 2D interface) is the **2D shadow** of the 3D
holographic cursor. not a separate representation — the same object from a
perpendicular viewing angle. the bridge is not designed, it is geometric.

```
3D holographic view    →  grid-hardnode cursor (lit layers, depth visible)
2D terminal projection →  block cursor in character matrix (same position, flat)
```

both views are live and consistent. moving the cursor in either view moves it
in both.


---

## sub-addressing duality

the cursor operates in two directions simultaneously:

**zoom out → navigate**: block cursor as pointer in macro space.
which region of the network? which cluster? which scale?
the cursor selects a region; the lit layers show what that region contains.

**zoom in → address**: node-group as 3D sub-cursor within the selected region.
which element? which lattice position? which style layer?
the formation's 8 positions address specific data within the block.

both operations use the same object — direction of zoom selects which
addressing mode is active. no mode switch, no different interface.


---

## checksum wiring

the hardnode is a named, routable, checksum-addressable cursor instance:

```
P7REF:  HARDNODE:CHKSUM7:ADDR_B32
```

- **CHKSUM7** — content-address of the current position state
  (selX, selY, selZ, zoom level, visibility radius)
- **ADDR_B32** — base32-encoded grid coordinates for routing
- multiple hardnodes at different offsets = multiple simultaneous cursors
- each cursor is independently routable — `graphics-matrix.cursor.move CHKSUM7 dx=1`
- cursor state is content-addressed: same position = same checksum = instant dedup

the 5 recursive scales in the visualization (×20 → ×200 → ×10000 → ×100000 → ×1000000)
map to 5 bits of BASE32 addressing per scale level, giving
5 × 5 = 25 bits of hierarchical address space from a single cursor position.


---

## aesthetic convergence — structural, not stylistic

the grid-hardnode visual language merges four aesthetics that each independently
discovered the same underlying truth:

**vector graphics / early 3D games**
wireframe rendering because the geometry IS the data. no texture needed when
the structure is the message. the glow-on-black is not nostalgia — it is the
honest rendering of a sparse luminous graph on an empty field.

**matrix movie visual language**
cascading, layered, code-as-space because data IS the reality being navigated.
the cursor moves through information the way a physical cursor moves through space.
no metaphor — the data space is the space.

**psychedelic harmonic rendering**
harmonic mathematics at realtime scale generates visual complexity that is not
random but structured — recognizable patterns at every zoom level, colors derived
from ÷13 remainder positions, wave propagation matching the network's own cycle
rhythm. the visual IS the computation.

**distributed terminal interface**
the block cursor has been the primary navigation primitive since the first
character-matrix displays. it maps to the 3D holographic cursor without loss
because both are the same primitive — a position with a local addressing space —
at different dimensionalities.

these aesthetics converge here not because they were combined but because they
all emerged from the same geometric truth: **a cursor is a position with reach,
rendered honestly**.


---

## reference implementation

`data/html/visual.v7.ax/grid-v14-layered.refactored.html`

already implements:
- 8-node formation with precomputed outer + sub templates
- unlimited integer grid coordinates (selX, selY, selZ) — arbitrary offset
- 5 recursive hyperspace scales with harmonic plane count (21 ÷ 7 = 3)
- camera lazily following selection — view coupled to hardnode
- zoom range 7×10⁻¹¹ to 20 (covers all scales continuously)
- alpha-fade by zoom level (all 5 scales visible simultaneously at transitions)

next step: wire selX/selY/selZ as a live P7 command target through the
graphics-matrix zenka — cursor position becomes a routed namespace address,
grid responds to live namespace state, glow intensity driven by actual
reference counts from the checksum cluster index.

#,,.,,...,,..,..,,,.,,.,,,..,,,..,,..,.,,,,,,,.,.,...,...,,,,,,..,,,.,,.,,,.,,
#HFWWT4GF776N762IL54IB2XZXC5C376ZN2F3TBAAMW4VK2ZPMC5QZBI2AQW4GEGSNQOQVUEYJIJOY
#\\\|FZSZTRP7TRKKS5Q2I5TNZM4TXTD6W3MGWJ2KQBMXXZX2XIED4EH \ / AMOS7 \ YOURUM ::
#\[7]EAHF2YFEPR7DHRLEVU675TEVOCILEXLT4UNWANS2NIR32NGMFMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
