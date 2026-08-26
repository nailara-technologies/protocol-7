# checksum frame container

## prior art — the 1D case

the octal encoding already implements this principle in one dimension.
each unit is 3-bit octal + 1-bit separator = 4 bits. separator positions
are known, so structure is recoverable even with bit flips:

```
separator positions known → structure recoverable
octal payload intact      → content recoverable
flip pattern detected     → signal extractable
```

see `data/asc/what-AI-thinks/markdown-form/protocol7/research/
bmw_1bit_covert_channel_analysis.md` — "the 4-bit reconstruction guarantee".

the checksum frame container is the 2D (and 3D) generalization of the same
recovery property. what is valid for one dimension is valid for a field.

---

## concept

a payload block is surrounded by a frame of AMOS7 checksums — one checksum
per row (left and right sides) and one per column (top and bottom sides).
the frame declares the shape and content of what is inside it, making the
structure recognizable and partially or fully recoverable even when the
payload is incomplete, corrupted, or partially received.

```
[col_0][col_1][col_2]...[col_n]          ← top: column checksums
[row_0][ p  a  y  l  o  a  d  ][row_0'] ← row checksums flank each row
[row_1][ p  a  y  l  o  a  d  ][row_1']
[row_2][ p  a  y  l  o  a  d  ][row_2']
  ...
[col_0'][col_1'][col_2']...[col_n']       ← bottom: column checksums
```

row checksums expand directly outward from the payload rows.
column checksums expand directly outward from the payload columns.
the frame is not a wrapper — it IS the validation structure for what it surrounds.

---

## position-aware checksums as 2D structure

AMOS7 checksums accept length AND offset parameters. the same payload
content at different positions generates completely different checksum values.
position is baked into the checksum output.

this is what makes the frame genuinely 2D rather than independent 1D checksums
arranged in a rectangle:

- a valid row checksum from row 3 cannot be placed at row 7 — it would fail
- a valid column checksum from column 2 cannot be placed at column 5 — fail
- the position is intrinsic to the checksum value, not declared separately

an attacker cannot transplant a valid frame element from one position to another.
the frame self-declares its own geometry.

---

## recovery properties

### partial validation
even with incomplete payload, intact rows and columns can be verified
independently. a partially received frame tells you exactly which regions
are confirmed and which are not.

### damage localization
a corrupted cell fails two checksums simultaneously — its row and its column.
the intersection of the two failing checksums localizes the corruption to
a single cell. no ambiguity about where the damage is.

### brute-force recovery with confidence
for a missing or corrupted block, the valid content is the one that satisfies
all surrounding frame checksums simultaneously:

- 2D frame: must satisfy left row, right row, top column, bottom column (4 constraints)
- 3D frame: must satisfy all 6 face checksums

the intersection of 4 or 6 independent constraints is extremely small.
brute-force search space collapses to near-zero for small block sizes.
when all constraints are satisfied simultaneously, confidence is complete.

### incomplete payload still identified as payload
the frame declares the shape of what should be inside it. even a fully
corrupted or absent interior is unambiguously identified as the payload
region — the frame is the declaration of intent, visible even when the
content is not.

---

## frame thickness

frame thickness = desired recovery depth.

a single-layer frame (one checksum per row/column) provides:
- damage detection at row/column granularity
- localization of corruption to a single cell
- brute-force recovery for small individual cells

a multi-layer frame provides:
- recovery from larger contiguous damage regions
- each additional layer adds another ring of validation
- inner layers validate single rows/columns, outer layers validate blocks

thickness is derived from what is desired to still be recoverable — the
frame is a statement of recovery intent, made precise and verifiable.

---

## payload block expanse alignment

the payload block dimensions can be aligned to the frame's natural units:

- row height aligned to base32 chunk size (47 bytes = 76 chars)
- column width aligned to AMOS7 checksum periodicity
- block size chosen so frame checksums fall on natural boundaries

alignment means the frame and payload are in harmonic relationship — the
structure validates itself most efficiently when dimensions are chosen to
match the checksum's natural periodicity.

---

## duplication detection

duplication attacks fail as cleanly as point corruption:

- **duplicate a row**: every column checksum for that row sees the wrong
  content at the wrong offset — all column checksums fail simultaneously.
  failure pattern: an entire column of failures = duplication signature.

- **duplicate a column**: all row checksums for every row in that column
  fail simultaneously. failure pattern: an entire row of failures.

position-aware checksums make transplantation and duplication the same class
of attack — content moved to a wrong position fails at the new position.
the failure pattern (point vs line vs plane) distinguishes the attack type.

---

## corner spaces — diagonal checksums

the four corners are the natural home for diagonal validation — a third
axis perpendicular to both rows and columns:

```
[TL:diag↘][col_0][col_1]...[col_n][TR:diag↙]
[row_0]   [ p a y l o a d ]       [row_0'  ]
[row_1]   [ p a y l o a d ]       [row_1'  ]
[BL:diag↗][col_0'][col_1']...[col_n'][BR:diag↘]
```

- TL corner: checksum over main diagonal (↘)
- TR corner: checksum over anti-diagonal (↙)
- BL, BR: reverse diagonals or quadrant diagonals

a corrupted cell now fails: row checksum + column checksum + diagonal checksum
— three independent constraints pointing to the same cell. brute-force
recovery space collapses further. same checksum format, no size issue.

---

## outward expansion — adding rings without skewing the existing

the core principle: **expand outward without disturbing the existing structure**.

a completed frame is valid and final. to add frame-level integrity or
signatures, add an outer ring around the existing frame. the inner structure
is never touched:

```
[ outer ring — integrity over everything inside ]
[ outer ][col_0][col_1]...[col_n][ outer ]
[ outer ][row_0][ payload ][row_0'][ outer ]
[ outer ][row_1][ payload ][row_1'][ outer ]
[ outer ][col_0'][col_1']...[col_n'][ outer ]
[ outer ring — integrity over everything inside ]
```

each outward ring is an independent validation claim over all layers it
encloses. the payload is always the center. inner validates payload, outer
validates inner. recursive without limit, each layer clean and complete.

---

## outer ring as signature chain space

the outer ring is a static width space — fixed number of positions around
the perimeter. signature chains (from the discover zenka pattern) fit
naturally here: multiple AMOS7 signatures chained without separators,
each self-delimiting, collectively forming a stronger integrity claim.

the ring width IS the signature capacity declaration — the geometry defines
the signature budget. no variable-length framing needed. a ring of width N
accepts exactly as many chained signatures as fit in N positions,
deterministically. the static space is an advantage: known, stable, and
immune to length ambiguity.

as with the discover zenka: a chain of signatures is stronger than any
single signature, and each element of the chain is independently verifiable.
the outer ring distributes the chain around the perimeter — a signature
that wraps the entire structure.

### provenance — network key + node key chain

the outer ring's primary role is provenance declaration, not just integrity:

```
outer ring = network_sig + node_sig   (chained, self-delimiting)
```

- `network_sig` — produced by the network key, held by the discover zenka.
  all existing nodes know the network key. a valid network signature means
  "this frame was admitted by network authority".

- `node_sig` — produced by the new node's own key, signed by the network key.
  verifies the frame content came from the declared node.

a receiver verifies network_sig first. if valid: the node is admitted, no
separate handshake required. node_sig then validates the frame content.
two layers of provenance in one static-width space, zero extra round-trips.

new nodes are recognizable because their admission signature was produced
by the already-known network key. the outer ring IS the introduction —
not a pointer to credentials stored elsewhere, but the credentials themselves,
self-contained and verifiable by any node that knows the network key. =)

---

## 3D extension

for volumetric data (3D grids, layered structures, network state snapshots):

```
6 faces of checksums, one per face of the payload cube:
  front  / back   — depth slices
  left   / right  — row planes  
  top    / bottom — column planes
```

a corrupted voxel fails three face checksums simultaneously — the intersection
of three planes localizes it to a single point in 3D space.
brute-force recovery requires satisfying all 6 face constraints simultaneously.

---

## connection to infinite-space topology

the checksum frame container is the infinite-space topology principle
expressed in 2D/3D:

- **arbitrary entry point**: any fragment of the frame identifies itself
  as frame (position-aware checksums) and declares what payload it surrounds
- **no escaping**: frame and payload occupy compatible but distinct value spaces
- **truncation legible**: an incomplete frame is visible as incomplete —
  the missing sides are recognizable by their absence
- **parent inferrable from siblings**: a partially received frame reconstructs
  its own geometry from the checksums that did arrive

see `data/md/design/SELF-DELIMITING-CHECKSUM-PATTERN.md` for the 1D token
system this extends into 2D/3D.

---

## connection to ASCII art page framing

in terminal/console contexts, the checksum frame IS the page frame — the
visible border of a data page is simultaneously its integrity structure.
a "clean page frame made of precisely sized AMOS checksums" is not decorative:
every element of the visual border is a verifiable claim about the content
it surrounds.

the frame thickness visible in the ASCII art is the recovery depth. a thicker
border is a stronger integrity guarantee, not just an aesthetic choice.

---

## related documents

- `data/asc/.../bmw_1bit_covert_channel_analysis.md` — 4-bit reconstruction
  guarantee: the 1D case this generalizes
- `data/md/design/SELF-DELIMITING-CHECKSUM-PATTERN.md` — 1D token system,
  2-bit type system, position-aware checksums
- `data/md/design/DATA-PROTOCOL-SYNC.md` — DATA-CHANNELS inline validation
  anchors: checksum frames applied to stream segments
- `data/yaml/reasoning-templates/infinite-space-topology.yaml` — the
  reasoning template this is an existence proof for

#,,,,,,,,,..,,,.,,,..,,.,,...,.,,,.,,,...,.,,,..,,...,...,...,.,.,,..,,,,,.,.,
#CL22OQYJTSPBEYHXDFOY6AEDF2JFMELUGHWSY2N664JPLI62W3XGGJF4BRK473SBC2WIHRCGNF4TO
#\\\|DYTFFCGFWTTBVHRJFLFXDNFGJM7KDWKALIKTPY3PDYZBLCTVGV6 \ / AMOS7 \ YOURUM ::
#\[7]QCNHPZMFK3UHQZ6O2NQG44XLZE2BVIQS45CROG7DPN3NVQ2F6EDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
