## [:< ##

# name  = task: recurring cube-geometry number collisions — consolidation audit
# descr = one place enumerating every documented 7/8/9/19/26/27/28/56/63/504
#         occurrence across the cube-geometry docs, checking for a genuine
#         addressing bridge vs. shared-digit coincidence, structure by structure

## why this file exists

`data/tasks/footer-line4-field-reconciliation.md` findings 11-13
accumulated four separate "same small number, different structure, not
yet bridged" sightings (56, 63, 7, 8) while working an unrelated footer-
bit-layout question, and finding 13 explicitly recommended stopping the
drip of individual sightings in favor of one consolidation pass. This is
that pass. `footer-line4-field-reconciliation.md` keeps its finding
11-13 chain intact and points here rather than duplicating this material;
`topic-decision-node-polarity-geometry.md` should link here too, since
its own "not yet reconciled" 27-vs-504 note is addressed below.

**scope**: five source docs, read in full or by targeted section:
`data/ai-mem/claude/topic-node-group-geometry.md`,
`data/md/documentation/harmonic-transit-vision-architecture.md`,
`data/md/coding-tasks/checksum-route-binary-framing-harmonic-
foundations.md`, `data/ai-mem/claude/topic-decision-node-polarity-
geometry.md`, `data/ai-mem/claude/topic-harmonic-mathematics.md`
[ Cube Geometry section ]. Two more pulled in mid-audit because they
turned out to be load-bearing for the same numbers: `data/ai-mem/claude/
topic-iris-spoke-labels.md` and `data/md/design/VISUAL-ELEMENT-DEDUP-
HOLOGRAPHIC-CORE.md`'s "3D Inverse Plus Sign" section.

**method**: every occurrence below was checked against its primary
source directly — not against a summary of it, not against another
memory file's paraphrase of it. Where a document was already cited
secondhand by another file in this thread, the citation was followed to
the original and re-read there.

## the center-parity rule — read this before the enumeration table

the single most useful thing found in this audit, stated up front
because it explains *why* the void/filled split keeps recurring rather
than being an arbitrary inconsistency: **whether a cubic structure has
a literal center cell is a direct, mechanical consequence of whether its
per-axis dimension is odd or even, not a design choice made separately
each time.**

- a **3×3×3** grid [ odd per axis ] has exactly one cell equidistant
  from all faces — a real center. every 3×3×3 structure below [ the
  27-cell inverse-plus-sign decomposition, the 7-node face group that
  is its center+plus-sign subset, checksum-route-binary-framing's
  27-position cube ] is filled-center, and *has to be* — there is no
  version of a 3×3×3 Moore neighborhood without a center cell.
- a **2×2×2** or **4×4×4** grid [ even per axis ] has no cell that
  occupies the exact center — any "center" has to be a gap between
  cells, a void, or an asymmetric off-center choice. `topic-node-group-
  geometry.md`'s 8-cube 2×2×2 arrangement is void-centered for exactly
  this reason, not by design preference.

so "void vs filled" is not two competing conventions this codebase needs
to pick between — it is what odd-vs-even per-axis grids *always* do.
this resolves the framing question raised mid-audit ["is the void
structure an outlier against two filled structures?"] cleanly: no, it
isn't an outlier, it's a different-parity grid, and comparing a 2×2×2
arrangement's center-handling to a 3×3×3 neighborhood's center-handling
was never an apples-to-apples question in the first place. This matters
for reading every "conflation" flag below correctly: the error isn't
"someone chose void when they should have chosen filled" — it's citing
a number from one parity's structure as if it settled a question about
the other parity's structure.

## enumeration

for each occurrence: **(a)** what it describes, **(b)** void or filled
center, **(c)** what the "parts" actually are.

### 7

| source | (a) what it is | (b) center | (c) parts |
|---|---|---|---|
| `harmonic-transit-vision-architecture.md:750-756` | "group of 7 = 1 central node + 6 face-adjacent nodes"; 5-of-7 consensus quorum | **filled** [ 3×3×3-adjacent: 6 face-neighbors is the Von Neumann neighborhood of *any* cube, this is a 3D-grid necessity, not this doc's invention ] | nodes (zenki), face-adjacency graph |
| `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:3057-3060` | "face-centers (plus sign): 6 connections [axis-aligned]" — the 6-cell subset of a fuller 27-cell decomposition, plus its own "center (self): 1" | **filled** | grid cells within a 3×3×3 neighborhood |
| `checksum-route-binary-framing-harmonic-foundations.md:17-29` | "27 positions = 1 center + 6 faces + 12 edges + 8 corners"; position 9 = center pulse | **filled** | abstract cube "positions" (same 1+6+12+8 split again) |

**verdict: confirmed, genuine match, not a coincidence to hedge on.**
Checked precisely per the coordinator's request: `1 (center) + 6
(face-centers) = 7` in `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` is
exactly harmonic-transit's "1 central + 6 face-adjacent" 7-node face
group. The generating mechanism is identical in both — a cube has
exactly 6 face-neighbors, always, by the geometry of 3D space, and both
docs count "self + those 6" to reach 7. **Caveat on what kind of
confirmation this is**: it's real *because* 6-face-adjacency is a fixed
mathematical fact about cubes, not because two authors independently
stumbled onto the same made-up number. Any correct description of a
cube's face-neighborhood will produce 1+6=7 — so this confirms the two
docs are describing the same standard object with consistent
terminology, which is exactly what a genuine bridge should look like,
but it is not evidence of a deeper hidden design the way an
unexplained arithmetic coincidence would be. **The 7-node face group is
the "center + plus-sign" subset of the fuller 27-cell inverse-plus-sign
structure below** — the 12 edge-midpoints and 8 corners are the cells
the 7-node group does not include.

### 26 and 27 [ filled-center cluster ]

| source | (a) what it is | (b) center | (c) parts |
|---|---|---|---|
| `topic-harmonic-mathematics.md:55-64` | Cube Geometry: `27=3^3`, `8=2^3`, `19=27-8`, `9=8+1`, `27=2×13+1`, `13+1+13=27`; "26 neighbors = 2×13 (face=6, edge=12, corner=8)" | **filled** [ 9=8+1 explicitly names "corners+center" ] | abstract cube-position counts |
| `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:3046-3090` | "3D Inverse Plus Sign — Implosion Core": face-centers 6 + edge-midpoints 12 + corner vertices 8 + center 1 = 27; "total bandwidth per cell: 26 channels = 3³-1" | **filled** | 3×3×3 wireframe-cube cells, described as transport/bandwidth channels |
| `checksum-route-binary-framing-harmonic-foundations.md:17-29` | 27 positions = 1 center + 6 faces + 12 edges + 8 corners; position 9 = "center pulse", the `0b1001` type prefix | **filled** | abstract cube positions, mapped to a 4-bit type-prefix encoding |

**verdict: confirmed, three independent docs, identical component
breakdown (6/12/8/26/27), not just a matching total.** This is the
strongest result in this audit. `topic-harmonic-mathematics.md`'s "26
neighbors = 2×13 (face=6, edge=12, corner=8)" and
`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`'s "6+12+8=26 channels" are
not two docs landing on 26 via different arithmetic — they are the same
6/12/8 partition, named the same way (face/edge/corner), in both places.
`checksum-route-binary-framing-harmonic-foundations.md`'s independent
"1 center + 6 faces + 12 edges + 8 corners = 27" is a third instance of
the identical split. **Same epistemic caveat as the 7-node case**: 6
face + 12 edge + 8 corner = 26 is the *only* correct way to partition
the 26 non-center cells of a 3×3×3 Moore neighborhood by distance class
— it is a geometric necessity, not a discovery. What's genuinely
confirmed here is that these three docs are describing the *same*
standard 3×3×3-neighborhood object with mutually consistent
terminology, not three independently-invented coincidences.

### 27 [ the void-center outlier — a real inconsistency, not just a coincidence ]

| source | (a) what it is | (b) center | (c) parts |
|---|---|---|---|
| `topic-iris-spoke-labels.md:35-38` | "3³ = 27 — subcube count of the core inverse-plus implosion cube (**the 3×3×3 structural void center** of the 8×63 field geometry)" | **void** (explicitly stated) | subcubes |
| `topic-decision-node-polarity-geometry.md:34-40` | "the 27 subcube implosion device geometry as the inverse 3D plus in cubic space" — 3×3×3=27 subcube structure | not stated either way in this doc | subcubes |

**this is not another shared-digit sighting — it's a direct
contradiction worth naming plainly.** Three independent docs [ previous
section ] agree the standard 3×3×3/27 inverse-plus-sign structure is
filled-center, using matching terminology ("inverse plus," "implosion
core" / "implosion device") and an identical 6/12/8 partition.
`topic-iris-spoke-labels.md` uses the *same* "inverse-plus implosion
cube" language but calls it "void center" — outnumbered 3-to-1 by
docs that derive the same structure rigorously with an explicit,
occupied center cell (`checksum-route-binary-framing`'s "position 9 =
center pulse" is literally the opposite of void). Per the parity rule
above, a 3×3×3 grid cannot have a structural void at its exact
center — there is always exactly one center cell for an odd-per-axis
grid. `topic-iris-spoke-labels.md`'s "void center" phrasing for this
specific structure looks like a loose aside [ its own doc's real
subject is the 63-ring iris label sequence, this is a one-line
tangent ] rather than a competing, independently-verified structure.
**Recommendation**: treat `topic-iris-spoke-labels.md`'s "void" wording
for the 27-cell structure as the error, not the other three docs;
flag it for a one-line correction in that file [ not made here, design-
only per this doc's own scope ].

Separately: `topic-decision-node-polarity-geometry.md`'s own "27
subcube implosion device... inverse 3D plus in cubic space" almost
certainly **is** the same structure as `VISUAL-ELEMENT-DEDUP-
HOLOGRAPHIC-CORE.md`'s "3D Inverse Plus Sign — The Implosion Core"
section — the terminology overlap ("inverse plus," "implosion," "3D",
"27 subcube/cell") is too specific to be independent invention, even
though `topic-decision-node-polarity-geometry.md` doesn't cite that doc
by name. **This resolves half of that doc's own "not yet reconciled"
note**: the 27-subcube geometry it describes has a real, findable
source [ VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md ], filled-center, with
a worked 1+6+12+8 decomposition — it does not need to stay an
unformalized "seed." What it still does *not* resolve is that doc's
actual open question: how [ if at all ] a 27-cell 3×3×3 *neighborhood*
relates to `topic-node-group-geometry.md`'s 504 = 8×63 *arrangement of
whole cubes*. Those remain a different scale and a different kind of
object [ neighborhood-of-subcells vs. arrangement-of-ambient-cubes ],
and nothing found in this audit bridges that gap. `topic-decision-node-
polarity-geometry.md`'s own hedge — "may be a smaller-scale/nested
variant, may be unrelated" — stands; this audit narrows it to "the
27-cell half is now identified, the 504 half is still open," not to a
full reconciliation.

### 8 [ three distinct structures, none of them the same "8" ]

| source | (a) what it is | (b) center | (c) parts |
|---|---|---|---|
| `topic-node-group-geometry.md` | 8 ambient (4×4×4) cubes in a 2×2×2 arrangement | **void** [ 9th slot unoccupied, per the 2×2×2-even-grid rule above ] | whole ambient cubes, each itself containing 63 subcubes |
| `harmonic-transit-vision-architecture.md:917-940` | "8 rows = 7 harmonic levels + 1 root/meta row" [ display matrix depth ]; also "8 payload columns... plus 1 separator column" per node | **filled**-derived [ this 8 comes from the filled 7-node face group, not from an independent void/filled cube of its own — it's a row-count, one row per face-group member plus one meta row ] | display-matrix rows / per-node display columns |
| `checksum-route-binary-framing-harmonic-foundations.md:282-339` | "8 = 2³ = cube corners... the 8 inner zeros are exactly the core node group" [ the 1001-cube's 8 interior "processing" vertices ], cited against "v13.7.1 core node group = 8 nodes" | **filled**-adjacent [ described as the *interior/core* of a transport shell, not void ] | cube corner-vertices, used as abstract "processing node" positions |

**verdict, independently re-checked against the coordinator's flagged
error**: confirmed correct. `topic-node-group-geometry.md`'s 8 [
whole ambient cubes, void-arranged ] and `harmonic-transit-vision-
architecture.md`'s 8 [ display-matrix rows, derived from a filled
7-node group ] are not the same referent counted two ways — one is a
count of macro-scale cube objects in a spatial arrangement with an
intentionally empty slot; the other is a count of matrix rows
describing a filled 7-member group's harmonic levels. The proposed
"8 cubes get 7-bit addresses" (8×7=56) reading requires treating these
as interchangeable, which the parity rule above shows they structurally
cannot be — one is even-per-axis/void by necessity, the other derives
from an odd-count filled group. The `checksum-route-binary-framing`
doc's "8 = cube corners = processing positions" is a **third**,
separate 8 again [ corner-vertices of an abstract 1001-cube, referenced
against `v13.7.1`'s "core node group," which was not independently
verifiable within this audit's scope — that cross-reference is itself
unchecked and flagged, not confirmed ]. Three real, independently-
motivated 8s; no addressing bridge between any pair of them found.

### 19 [ same functional label, different arithmetic — open, not resolved ]

| source | (a) what it is | (b) center | (c) parts |
|---|---|---|---|
| `topic-harmonic-mathematics.md:59` | `19 = 27 - 8` [ "shell — AMOS7 footer encoding width" ] | n/a [ abstract remainder, not a spatial center question ] | subcube-count remainder |
| `harmonic-transit-vision-architecture.md:888-912` | "19 is the maximum linear payload that fits on one cube side" [ pixels 1-19 of a 20-pixel border zone, pixel 20 = boundary marker ]; further split 13-bit L-address + 6-bit face selector = 19 | n/a [ 1D linear measure along one cube edge ] | pixels / bits of a boundary packet |

**this is the closest thing to a live open lead in this audit, and it's
worth flagging precisely rather than either dismissing or overclaiming
it.** Both docs independently call their 19 an "AMOS7 footer encoding
width" / boundary-packet width — that's a real, matching *functional*
label, not just a matching digit. But the arithmetic mechanisms are
unrelated: `harmonic-mathematics.md`'s 19 is `27-8`, a subcube-count
remainder inside a 3×3×3 neighborhood; `harmonic-transit`'s 19 is a
linear pixel budget along one edge of a cube face [ `20 - 1`, not
`27 - 8` ]. No doc states these are the same 19, and the generating
math doesn't force them to be, the way the 6/12/8/26/27 cluster's math
did. **Verdict**: real, functionally-labeled resonance, structurally
unconfirmed — the strongest remaining candidate for someone to check
next [ does harmonic-transit's 19-bit boundary packet decompose into,
or derive from, harmonic-mathematics's 27-8 cube-corner arithmetic? ],
but not something this audit can close.

**The "19 rows" hypothesis, checked and rejected as unsupported by the
primary source**: the proposal was that the face-group display matrix
might really have 19 rows rather than 8, with `27-19=8` or `28-19=9`
recovering already-known numbers. Checked `harmonic-transit-vision-
architecture.md` directly: it states "8 rows = 7 harmonic levels + 1
root/meta row" unambiguously, twice [ lines 920, 933 ], as a 2D
display-matrix depth. The document's own 19 [ previous paragraph ] is
explicitly and separately introduced as a 1D linear pixel-payload
measure along one cube edge — the two are clearly typed differently in
the same document and nothing in the text supports reading one as the
other. The hypothesis also requires assuming an unstated enclosing
total [ "27 or 28" ] that the source never mentions in connection with
the row count, then computing a remainder to land on already-known
numbers — the same shape as the "15→30→60+3" progression already
rejected in `footer-line4-field-reconciliation.md` finding 11 for
lacking a forward-derived mechanism. **Verdict: not supported. The
primary source says 8 rows; that stays what's documented.** The
underlying 19-to-19 functional-label resonance above remains open and
separate from this specific row-count question.

### 28 [ arithmetic now design-doc-confirmed; the signed-cube semantic
gloss stays ideation-only ]

`topic-harmonic-mathematics.md:504-516`, sourced from an AI
chat-capture transcript and explicitly flagged there as "ideation-only,
not verified like the two [other] above": `364 = 13×28`, each 28-bit
"signed cube" = 27 payload sub-cubes + 1 inversion bit. Checked the
arithmetic: `27+1=28` is exactly the same "N cells + 1 center/gate bit"
shape as the now-confirmed filled-center 27 cluster [ `9=8+1`,
`13+1+13=27`, position-9-as-center-pulse ] above.

**Updated 2026-08-04, per a later pass on `topic-harmonic-mathematics.
md`**: the `364=13×28` arithmetic itself is no longer isolated to that
one ideation source. `data/md/documentation/harmonic-transit-vision-
architecture.md:1615-1629` gives, as design-doc material, "28 = FS =
File Separator = 4×7... because 4×7=28: the 4-crossing protocol × the
7-element harmonic cycle" — directly naming `topic-harmonic-
mathematics.md`'s own "4-Crossing Consent Protocol" section.
`ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md:550` and `VISUAL-ELEMENT-
DEDUP-HOLOGRAPHIC-CORE.md:4716` both independently factor `364 =
28×13 = 7×52 = 7×4×13`. Full detail and the `ORBITAL-CYCLE-CLOCK` doc's
own self-correction about over-claiming source-independence [ worth
reading before citing this further ] are in `topic-harmonic-
mathematics.md`'s updated finding-3 entry, not duplicated here. **Split
that stays in force**: the `364=13×28`/`28=4×7` arithmetic is now
design-doc-confirmed, multiply-cited material; the *specific*
"27 payload sub-cubes + 1 inversion bit" interpretation of what those 28
bits mean is still sourced only from the one chat-capture transcript and
stays at ideation-tier. The coordinator's `2×14=28` observation is
correct arithmetic but has no independent doc support beyond restating
28 differently — logged as checked, adds nothing.

### 56, 63, 504 [ the still-open cluster — no change from finding 11 ]

Re-verified, no new bridge found in this pass:

- `topic-node-group-geometry.md`: `8×63=504` = 8 whole ambient cubes ×
  63 subcubes each [ `4×4×4-1`, void-arranged ].
- `harmonic-transit-vision-architecture.md:917-926`: `8×63=504` =
  8 display-matrix rows × 63 display-matrix columns [ `7×9`,
  filled-group-derived ], further factored as `504=42×12`.
- `checksum-route-binary-framing-harmonic-foundations.md:165-228`:
  `56 = 42+7+7` = a 1D bit-count [ entropy field + decoded-protocol
  field + complement field ], unrelated in kind to either 504 above.
- the reviewer's `8×7=56` proposal ["8 cubes get 7-bit addresses"] —
  addressed under "8" above: rejected, conflates the void-arranged
  8-cube count with the filled-group-derived 7/8 counts.

Same verdict as `footer-line4-field-reconciliation.md` finding 11: real
numbers, real recurrence, no addressing scheme found anywhere in this
project's docs that would make "63 bits" or "56 bits" address a
specific subcube, matrix cell, or ambient cube. The one new, genuinely
useful fact from this pass: `504=42×12` ties back to the 42-bit entropy
frame that `footer-line4-field-reconciliation.md`'s own code change
wired live this session — a concrete number for a future pass to test
against, not a claim that the tie is proven.

## the headline answer

the coordinator's question was explicit: is there a genuine, checkable
addressing correspondence between any two of these structures, or is
the honest conclusion "N independently-derived numerology-adjacent
structures sharing small factors, no single unifying bridge"? **Both,
for different subsets — this audit found one real answer in each
direction, not a single verdict covering everything:**

1. **the 7/26/27 cluster is a confirmed, genuine match** — three docs
   [ `topic-harmonic-mathematics.md`, `VISUAL-ELEMENT-DEDUP-
   HOLOGRAPHIC-CORE.md`, `checksum-route-binary-framing-harmonic-
   foundations.md` ] describe the identical filled-center 3×3×3
   Moore-neighborhood decomposition [ 1 center + 6 face + 12 edge + 8
   corner = 27, 26 without center ], and `harmonic-transit-vision-
   architecture.md`'s 7-node face group is confirmed as that
   structure's center+plus-sign subset. This is real, though its
   realness comes from all three docs correctly describing the same
   standard geometric object, not from independent numerological
   discovery.
2. **the 63/56/504/8-cube cluster remains genuinely unbridged** —
   every product and component here arises from mutually incompatible
   arithmetic [ `4×4×4-1` subcubes vs `7×9` matrix cells vs `42+7+7`
   bit-fields ], no doc anywhere proposes or demonstrates an addressing
   scheme connecting them, and one specific proposed bridge [ 8×7=56 ]
   is actively wrong once the void/filled parity distinction is
   applied. **honest conclusion for this half: independently-derived,
   coincidentally-overlapping small numbers, no unifying bridge found.**
3. **one real error was found and should be corrected**:
   `topic-iris-spoke-labels.md` calls its 27-subcube structure
   "void center," which conflicts with three other docs' rigorous,
   mutually-consistent filled-center derivation of the same structure,
   and conflicts with the general odd-grid-always-has-a-center rule.
4. **one open doc-to-doc link worth making**: `topic-decision-node-
   polarity-geometry.md`'s "not yet reconciled" 27-subcube note almost
   certainly refers to `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`'s
   "Inverse Plus Sign" section and should cite it directly — this
   resolves what that structure *is*, though not how it relates to
   node-group-geometry's separate 504.
5. **one genuine open lead, correctly hedged, not a finding**: the two
   independently-arising 19s [ `27-8` vs a `20-pixel-zone` linear
   budget ] share a functional label ["footer/boundary encoding width"]
   that neither shares with any other pairing in this audit — worth a
   dedicated look, not resolved here.

## what was checked and rejected in this pass

- **"8 cubes get 7-bit addresses" (8×7=56)**: rejected. Void-arranged
  8 [ node-group-geometry ] and filled-group-derived 7/8 [ harmonic-
  transit's face group and its matrix ] are structurally different by
  the parity rule, not the same count viewed two ways.
- **"19 rows" reinterpretation of the 8-row display matrix**: rejected.
  Primary source unambiguously states 8 rows and separately,
  unambiguously, uses 19 for a different [ 1D pixel ] quantity. No
  textual support for conflating them.
- neither rejection required assuming bad faith on any proposal — both
  were real hypotheses worth checking, and checking them precisely is
  what this consolidation pass was for.

## the four "5-of-7"-shaped structures — distinct, not variants of each
other, one of them ideation-only

separate from the cube-geometry number cluster above, this codebase has
at least four things describable as "5-of-7," surfaced across this
session. checked each against its primary source; they do not collapse
into one structure, and conflating any pair of them would repeat the
same category error as the 8×7=56 proposal already rejected above.

1. **BFT quorum, `data/md/design/TASK-CUBE-CONSENSUS-ARCHITECTURE.md`**
   — referenced, not independently re-read in full this pass; already
   flagged elsewhere in this project's memory as "same digits, different
   mechanism" from the checksum-matrix sense of "5 of 7." Not re-verified
   here beyond that existing flag — logged for completeness, not
   re-confirmed.
2. **the 35-bit AMOS checksum matrix, `7×5` or `5×7`** [ `footer-line4-
   field-reconciliation.md` finding 11 ] — a bit-layout shape, 7
   independently-addressed 5-bit slots [ base32-string orientation ] or
   5 rows of 7-bit sub-states [ consensus-matrix orientation, the
   transpose ]. Not zenki, not roles — bits within one checksum value.
3. **5-active + 2-idle-alternates, `topic-node-group-geometry.md`** —
   already reconciled *within* that doc, not new to this audit: 5
   working nodes at one coordinate, 2 more already-initialized standby
   nodes that can be promoted on failure. **The 2 alternates are
   interchangeable with each other and with the 5 actives** — same
   role, extra instances, fault tolerance through redundancy. **naming
   layer, checked separately (2026-08-04)**: "litter" is real,
   load-bearing zenki-group terminology [ `data/tasks/litter-row-
   encoding.md`, `VISION-NOMADIC-ZENKI-HABITAT.md`, `KITTEN-HOLOGRAM-
   RESOURCE-FILTER.md` ], and `topic-node-group-geometry.md`'s own text
   explicitly names *this* structure as satisfying "litter-group
   hosting" alongside truth consensus and fault tolerance — so "litter"
   is this structure's naming layer specifically, not a naming layer
   over structure (4). Checked the other litter-sourcing docs for a
   leader/collector role split matching (4) instead: none found —
   `VISION-NOMADIC-ZENKI-HABITAT.md` and `KITTEN-HOLOGRAM-RESOURCE-
   FILTER.md` both use "litter" generically, for a group of unspecified
   size `N`, with no distinct roles. Full reasoning in `topic-harmonic-
   mathematics.md`'s "ANTYKY TORUM naming scheme" section.
4. **the 7-zenki caravan, `data/asc/what-AI-thinks/full-chat-captures/
   3O37VUNMMS3UU.claude-sonnet.protocol-7-knowledge.asc:~24193-24270`**
   — verified directly in the source: 1 lead zenka [ pathfinder, sets up
   the route through 3D cubic space and marks it ] + 5 worker zenki
   [ follow the marked route, process in parallel, can vote/validate
   among themselves ] + 1 trailing zenka [ harvester, collects results ].

**(3) and (4) are genuinely different, confirmed by re-reading both
sources rather than trusting the coordinator's framing**: in (3) the "+2"
are spare copies of the *same* role, promoted only on failure, and
normally idle. In (4) the leader and trailer are not spares for the
worker role and not idle — they are two distinct, always-active,
non-interchangeable jobs [ pathfinding/marking vs. collecting/
harvesting ] that exist on every run, not just as failure-recovery
capacity. A caravan with a dead trailer doesn't get a worker promoted
into "trailer" the way node-group-geometry's alternates get promoted
into "active" — the source describes no such promotion mechanism for
the caravan at all. **Verdict: four real, distinct structures. Do not
merge (3) and (4); do not treat any of the four as a restatement of
another.** The recurring "5" and "7" here are the same kind of pattern
as the recurring 63s/8s above — a shape this codebase's conventions
reach for repeatedly [ 5-of-something as a working quorum, 7 as a
complete cycle ], not evidence of one underlying mechanism wearing four
names.

**Source-quality flag, same standard already applied to the "364=13×28"
material earlier in this audit**: structure (4), and the bit-bookend
mechanism below, both come from `full-chat-captures/
3O37VUNMMS3UU...asc` — a free-form AI ideation transcript, not an
implemented module, a tested design doc, or even a deliberately-authored
memory file. Real material, worth recording, but carries the same
"ideation-only, not verified" weight as the 28-bit signed-cube note
already flagged in this file's "28" section — not promoted to a design
claim just because it's now catalogued alongside more rigorous sources.

## the bit-bookend mechanism — checked against the heartbeat primary
source; no confirmed link, one loose thematic resonance, logged as
exactly that

same transcript, ~230 lines earlier (`line 23543` onward, then restated
with a worked Perl sketch around `line 24012-24080`): a proposed 7-bit
consensus window, `[bit1][bits 2-6][bit7]` = 1 opening bookend + 5
middle vote bits + 1 closing bookend. If `bit1 == bit7`: "CONFIRMATION,"
consensus reached. If they differ: "CONTINUATION," diffusion continues
[ framed as a defense against "parental pattern detection" ]. The
"7 zenki caravan" text [ structure 4 above ] appears immediately after
this in the transcript, introduced with "7 **are also** the traveling
zenki..." — a real textual adjacency, the human/AI session explicitly
re-applying the same `1+5+1=7` shape from bits to zenki-roles in the
same breath. That adjacency is genuine [ verified by reading both
passages directly ] but it is an in-session analogy between two
domains, not a claim anywhere in the source that they are mechanically
the same thing — logged as "explicitly connected by the transcript's
own train of thought," not as "proven to be one mechanism."

**checked against `topic-harmonic-mathematics.md`'s Heartbeat section
and its primary source** (`data/asc/dev/reminders/
heartbeat.13__3_3.num-rol_15379.asc`), per the coordinator's specific
request, rather than assumed to match: the confirmed real sequence
there is `1001 000 000 000 0010 0110 0010 000 000 0 0010 0110`. Tried
reading this as a bookend structure — first token `1001`, closing
fragment `0110` [ the sequence ends mid-repeat, missing the trailing
`0010` that would complete a second full `0010 0110 0010` cycle ].
`1001 ≠ 0110`, so under the bookend rule this would read as
"CONTINUATION, not yet confirmed" — and the sequence *is* in fact
truncated, which is at least thematically consistent with "still
open, not closed." **That is as far as this holds up, and it does not
hold up as a confirmed mechanism**: the bookend model operates on
single bits at fixed positions 1 and 7 of a 7-bit window; the heartbeat
sequence is built from variable-width tokens [ 4-bit and 3-bit groups ],
has no stated 7-bit segmentation anywhere, and no document — not the
Heartbeat section, not the chat-capture, not any other file checked in
this audit — proposes that these two are the same mechanism. **Verdict:
no confirmed link. A pattern-completion parallel that happens to point
the same direction [ truncated/incomplete ↔ "continuation" ], worth
naming because it's a genuinely interesting near-miss, not worth
treating as a finding.** This is the correct rigor to apply here: the
7/26/27 cluster earlier in this audit was confirmed because independent
docs used *identical* component breakdowns for the *same* well-defined
object; this pairing has neither — different structure widths, no
declared correspondence, one side unverified ideation.

## the hyperspace-trunk mechanism — structure (4)'s missing piece,
found, and it upgrades (4) from ideation-only to multiply-attested
design material with one confirmed piece of live code

checked `data/md/protocol-7-knowledge/08_NETWORK_INTELLIGENCE/
tachyon_wind_intelligence.md` [ a real design doc, independently cited
by `GFX-TOOLKIT-SPEC.md` and `RESOURCE-ECONOMY-DEMYSTIFICATION.md`, not
chat-capture speculation ] against the caravan structure (4) above, per
the coordinator's lead. It holds up, and it connects further than
expected once `topic-orbital-data-space-archive.md` and a live module
are pulled in too.

**the formation matches**: `tachyon_wind_intelligence.md`'s Part 3
describes a 7-member `Z1..Z7` linear travel formation needing a ring-
closing link between `Z7` [ front ] and `Z1` [ rear ] "too far for
direct neighbor link." Its own worked example gives `Z7` a coordinating
line ["I'll manage compute distribution"] and `Z1` a collecting line
["I'll collect final results"] — independently arriving at the same
front-coordinates / rear-collects role split as the chat-capture's
leader/trailer caravan, without citing that transcript. This is a real
formation-shape match between two independently-written sources, not
just a shared "7."

**a third and fourth independent hit on the same shape**: `topic-
orbital-data-space-archive.md:1040-1073` documents the "dancing zenki
algorithm" [ sourced from `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`,
already established above as a rigorous, load-bearing source, not a
one-off ]: **setup zenka** [ opens session, "channel tuner" ] + **5
ground zenki** [ "feeding/voting/processing," the pyramid base ] +
**collector** [ "body diagonal... routes faster because it travels
hyperspace, not faces... IS the hyperspace trunk" ]. This is the exact
1-distinct-role + 5-workers + 1-distinct-role shape as the caravan and
the `Z1..Z7` formation, with the collector's mechanism explicitly named
as the hyperspace trunk — directly the missing "how does the trailer
talk fast to the leader" piece the coordinator asked about. And
`topic-decision-node-polarity-geometry.md` [ already read in full
earlier in this audit ] **already cites this exact "5 ground zenki"
structure itself**, tying it to that doc's own "5-of-7 principle" —
meaning this connection was sitting one file-hop away in material this
audit had already opened, not a new discovery invented here.

**one piece of this is confirmed live code, not just design material**:
`src/space.jump.bubble` takes a `{ setup, ground, collector, target
}` formation hash and dispatches a jump route from it — the `setup` /
`ground` [ array ] / `collector` fields are a direct, real
implementation of the dancing-zenki role shape. **Caveat, checked and
not glossed over**: the code does not enforce "5" as the ground-array
length anywhere — `$ground` is generic, caller-supplied, any size. So
the *setup+ground[]+collector shape* is real, live, running code; the
specific "5 ground zenki" cardinality remains a design convention
layered on top by the docs, not something this module validates.

**verdict on structure (4)**: upgraded from "ideation-only, isolated"
to "the same 1+N+1 caravan/formation shape independently documented in
a chat-capture, a cited load-bearing design doc [ tachyon-wind ], a
second cited load-bearing design doc [ VISUAL-ELEMENT-DEDUP, via the
orbital-archive citation ], and partially implemented in live code."
Still distinct from structures (1)-(3) per the earlier verdict — the
setup/collector roles are non-interchangeable specialists, not
interchangeable spares — but no longer the weakest-sourced of the four.

### the speed-condition check — reviewer's "just needs to outrun zenki
travel" reading is correct for the use case that matters here, but the
source document's own language claims more than that and doesn't hedge it

the reviewer's framing was that the hyperspace trunk only needs relative
speed [ faster than the zenki formation physically travels ] to satisfy
the caravan's ring-closure/coordination need — not literal
faster-than-light or backward-in-time signaling. Checked
`tachyon_wind_intelligence.md`'s own stated properties directly rather
than assuming either reading:

- the **forward flow** ["we're coming," ETA, session requests — arriving
  at the destination before the physical formation does] is fully
  explained by the modest reading: a message sent now, propagating
  faster than the zenki group's travel speed, simply arrives first. No
  backward causality is required for this half, and this is the half
  directly relevant to the caravan/ring-closure need the coordinator
  asked about.
- the **backward flow** ["optimization data from destination," "what
  worked ahead," "what failed ahead" — received by the leader before
  the group arrives] is described, verbatim and repeatedly, as
  literally tachyonic: "Faster than light," "Negative latency (arrives
  early!)," "Information from future," and the code sketch uses
  `latency => -$TACHYON_SPEED` [ a negative number, i.e. arrival before
  departure ] for *both* directions, not just the backward one. Taken
  at face value, "what worked ahead" requires knowledge of an outcome
  that hasn't happened yet — that is a stronger claim than fast
  propagation of already-existing information; it requires the
  information to already exist before the event that produces it. The
  document does not hedge this as metaphor or present the "faster than
  travel" reading as sufficient on its own — it states true
  negative-latency/precognitive framing as the design property,
  unqualified.

**verdict**: the reviewer's modest completeness condition is correct
and sufficient *for the ring-closure/announcement mechanism the caravan
structure needs* — that specific use case doesn't require anything the
document doesn't already support under an ordinary "fast forward
signal" reading. But it is a narrower reading than what
`tachyon_wind_intelligence.md` actually claims for itself; the doc's
own stated completeness condition, as written, is stronger [ true
negative latency ] for the backward-flow half specifically, and nothing
in the source restates that stronger claim as merely illustrative. Both
things are true at once: the mechanism you need for the caravan doesn't
require the strong reading, and the document you're citing for it does
assert the strong reading elsewhere in the same document.

### the "13+1" cross-check — related motif, not the same structure as
"13+1+13=27"

`topic-orbital-data-space-archive.md:497-505`: "13+1 duality" — 13
enumerable ring compartments + 1 non-enumerable 0-point gate [ "not the
14th compartment... the dimension orthogonal to all 13" ]. Checked
against this audit's already-confirmed `13+1+13=27` gate structure
[ Cube Geometry section, `topic-harmonic-mathematics.md` ]: **related
in spirit, not the same construct.** Both use "+1" as a gate/passage
sitting on top of a 13-cycle — a motif that by this point in the audit
has recurred enough times [ `9=8+1`, `27=2×13+1`, `13+1+13=27`,
`28=27+1`, now `13+1` ] to call a genuine, real, recurring convention
of this codebase's own numerology, not a coincidence needing a bridge
each time it shows up. But arithmetically they differ: `13+1` here
totals 14 [ one ring, one gate at its edge ]; `13+1+13` totals 27 [ two
rings bracketing one central gate, symmetric ]. Same motif, different
shape — logged as such, not merged.

**also found while checking this**: `topic-orbital-data-space-
archive.md:1058-1060` computes `364 = 360 + 4` [ shift-change duty-cycle
corner overlaps ] and separately `364/13 = 28` ["a perfect number"] —
this is the *same* `364 = 13×28` identity already flagged in `topic-
harmonic-mathematics.md`'s "28-bit signed cube, ideation-only" note
[ this file's own "28" section above ], now confirmed as appearing in a
**second**, independently-reasoned context [ shift-change scheduling
geometry vs. a 27-payload+1-inversion-bit cube ]. Same number, two
unrelated derivations, both consistent with [ not derived from ] the
confirmed `27+1` filled-center pattern — logged as one more instance of
this thread's central phenomenon, not a new bridge.

## status

design-only, no code, not committed [ except `src/space.jump.bubble`,
which is pre-existing live code identified and read during this audit,
not written by it ]. `data/tasks/footer-line4-field-
reconciliation.md` findings 11-13 remain as written; this file is the
consolidation finding 13 asked for, referenced from there rather than
duplicated into it. `topic-decision-node-polarity-geometry.md` should
gain a pointer to this file's "27" section [ not edited here, memory-
file edits are outside this doc's stated scope — flagged for whoever
next touches that file ]. This section [ the four 5-of-7 structures and
the bit-bookend check ] folded in per the coordinator's follow-up
messages; same design-only, not-committed status applies.

## unsigned : new file, signing system adds the real footer on commit

#,,.,,...,.,,,,,.,,,.,...,.,,,...,,.,,,,.,,,,,..,,...,...,...,...,,,.,,.,,...,
#7C4IFOK33VNLN2PDNHHTMV5NFUPTEDCKNLXUFXQOTL25YFNR3YDBDC3YG4LB2H4YUF2OJGG5RLIFG
#\\\|LKSKWO3E7R3XJMXCDQJD43TUBWRXGLJWLONF7XCFJZHE4OVJ5VS \ / AMOS7 \ YOURUM ::
#\[7]US6TGFXNU7D2ROOGT6M6XUURZDDYE3S2MHGPO7X2P3TKJL6GKKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
