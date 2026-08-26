## graphical storage and processing

*design document : protocol-7 index and corpus layer operations*

---

### core insight

rectangular image formats are coordinate systems, not shape constraints.
any geometry — disk, cylinder, sphere, torus — can be stored in a grid
and asserted in constant time using distance and angle arithmetic on
every pixel simultaneously, with no branching, fully parallelisable on
gpu or simd.

the ring-trie IS a disk. the contribution model IS a cylinder. the
frequency distribution IS a sphere. these are not metaphors — they are
the natural coordinate mappings of structures already in the system.

---

### the ring-trie as a disk

map the trie onto polar coordinates within a square canvas :

```
center          = root [ empty string, depth 0 ]
radius          = ring depth [ 0 = innermost, 7 = outermost ]
angle [ 0..2π ] = rank within ring [ frequency-ordered ]
pixel data      = node content [ frequency, terminal, child_count, ... ]
```

ring assertions become radial band tests :

```
in ring N  :  abs( r - N ) < ring_width
```

computed identically for every pixel, zero branching.

parent-child relationship : a node at (depth D, rank R) and its parent
at (depth D-1) occupy adjacent radii at the same angle neighborhood.
a radial ray from center passes through the full ancestry chain of any
node — one ray = one token prefix path through the trie.

subtree assertion : an arc segment at radius D, angular width proportional
to the subtree's frequency share. constant arithmetic, no traversal needed.

---

### ray-from-center as trie traversal

following a token character by character through the trie IS tracing a
ray outward from the center of the disk :

```
'l'           → ring 0, angle of 'l'
'lo'          → ring 1, same angular neighborhood
'lov'         → ring 2, narrowing angle toward rank of 'lov'
'love'        → ring 3, terminal node at final angle
```

each character step = one ring outward, same angular band. the trie
structure and the geometric structure are identical. traversal = ray
casting, lookup = nearest-pixel sampling.

---

### frequency as sphere depth

mapping frequency onto a third axis (Z) transforms the disk into a sphere :

```
high-frequency nodes  → small radius [ hot core ]
low-frequency nodes   → large radius [ cold outer shell ]
ring depth            → latitude
```

a frequency-band assertion = a spherical shell at radius R :

```
abs( freq_radius - R ) < shell_width
```

still one distance comparison per voxel. the galaxy accretion disk
visualization from brief 2 is this sphere projected onto a 2D plane,
where color encodes the Z dimension that image depth would carry.

---

### color depth as data cube

a single pixel with RGBA channels already encodes 4 independent data
dimensions. for ring-trie nodes :

```
R = frequency [ normalized to 0-255 or 0-65535 for 16-bit ]
G = child_count
B = depth [ redundant with radius, useful as direct channel ]
A = active [ 255 = live contribution, 0 = deactivated ]
```

with 16-bit channels per component, a single pixel holds 64 bits of
structured node data. the full 8-ring trie at 2.3M nodes fits in a
canvas of roughly 1520 × 1520 pixels in 16-bit RGBA — under 15MB
uncompressed, cache-friendly, directly addressable by (ring, rank).

---

### APNG as contribution stream

APNG extends PNG with animation frames. properties that map directly
onto the contribution vector model :

**append-only** : frames are appended to the file without rewriting
previous content. a new corpus contribution = a new frame. the file
IS the ordered log of contributions.

**partial frame regions** : each frame specifies its own (x, y, w, h)
sub-rectangle. a contribution affecting only rings 3-5 writes only
that annular band — unaffected rings are not touched. delta storage
with no overhead for unchanged positions.

**blend operations** :
```
APNG_BLEND_OP_OVER    → composite new data onto accumulated state
APNG_BLEND_OP_SOURCE  → replace region [ full source rewrite ]
```
frequency merge = OVER. source replacement = SOURCE. built into format.

**fallback** : frame 0 is a valid static PNG — the base corpus state
is always readable by anything that does not understand animation.

**deactivation** : a contribution frame with A=0 across its region
composites to transparent, zeroing out that source's influence without
rewriting the base layer. `index.deactivate` becomes an alpha-zero frame.

---

### XCF as layered corpus

GIMP's native format supports full layer compositing with blend modes,
per-layer opacity, and visibility toggles — a direct match for the
contribution layer model :

```
layer           = one contribution source [ keyed by AMOS checksum ]
visibility      = active_checksums membership
opacity         = contribution weight
blend mode      = frequency merge strategy [ normal, screen, multiply ]
layer order     = contribution chain / chain_policy
```

merging two corpora = flattening two XCF documents with layer compositing.
the resulting flat image = the current trie state. undo = hide a layer.
diff = compare layer contents before and after.

the main constraint is format stability — the XCF format has evolved
across GIMP versions, and the perl library for it has had compatibility
issues with recent high-bit-depth and tile-compression changes. a minimal
XCF writer for just the features the system needs is likely more reliable
than a full-featured library.

---

### assertions as image operations

the value of geometric storage is that data assertions become image
processing operations with known constant-time complexity :

| assertion                        | image operation                        |
|----------------------------------|----------------------------------------|
| node in ring N                   | radial band mask                       |
| subtree of node (D, R)           | arc segment mask at depth D+           |
| frequency above threshold        | channel threshold [ R channel ]        |
| active contribution              | alpha channel mask [ A > 0 ]           |
| parent of node (D, R)            | pixel at (D-1, parent_rank)            |
| all children of node             | arc at D+1 within angle neighborhood   |
| corpus diff between sources      | frame subtraction [ APNG Z-delta ]     |
| merge two contributions          | alpha compositing [ OVER blend ]       |
| deactivate source                | set A=0 on source layer [ XCF / APNG ] |

all of these process every pixel uniformly — no tree traversal, no
hash lookup, no branching. the gpu does not distinguish meaningful from
irrelevant positions; it applies the operation everywhere and the
geometry selects the result.

---

### connection to the cube format

the existing `.zxpc` binary cube format is already shaped toward this :

- contiguous compartments per ring [ radial bands ]
- fixed-stride directory entries [ constant spatial addressing ]
- depth-indexed rings [ radial layers ]

the natural evolution is regularising compartment sizes to fixed bytes
per node regardless of child count, making the spatial addressing true
image coordinates and enabling direct mmap-as-texture loading for gpu
query operations.

the thermocam magic-byte coincidence [ file(1) identifying `.zxpc` as
thermal imaging data ] is the format hinting at its own geometry.

---

### open questions

- optimal canvas dimensions for 8-ring trie at varying corpus sizes
- 16-bit vs 32-bit channel depth tradeoff [ precision vs memory ]
- APNG frame rate / timing metadata as corpus ingestion timestamps
- whether the ring-arc spatial layout or a linear rank layout is better
  for cache locality during sequential ring processing
- XCF minimal writer scope : layers + opacity + blend mode is sufficient
  for the contribution model; high-bit-depth and tile compression can
  come later

#,,.,,...,..,,,..,,..,,,.,,..,,.,,,,,,,,,,.,,,..,,...,...,,,.,,.,,,..,..,,.,,,
#5A23Y44WZONFBJOKA6NPI4ALPFECAOEJBRINEVR4IYQY5DVOA3AAMVQQ7QH62SUJZIICA7R77BO5E
#\\\|DREEB4PEJWFMQCVVZKBVPQZDMOHFY6IIELZIS2VAJYQAPW7QDTJ \ / AMOS7 \ YOURUM ::
#\[7]3JKLOPJPCBIUSXQJUAGQ66YFWZSSIIHGVSZ6GGRWHHEAGLPVF2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
