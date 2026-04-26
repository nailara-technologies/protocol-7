# harmonic storage architecture

## foundation

see `entropy-at-deduplication-root.md` for the mathematical basis —
the AMOS checksum system, rolling entropy propagation, the semantic constants,
and the parallel hyperspace deduplication model this architecture builds on.

the short version: AMOS checksums are not arbitrary identifiers. they are
harmonic addresses derived from content through a truth-preserving algorithm
tuned to carry entropy forward rather than shred it. the address space has
genuine semantic structure. cross-language synonyms, conceptually related
documents, and harmonically equivalent content naturally converge toward the
same addresses without any semantic analysis beyond the checksum computation.

## the two-zenka strategy

two zenki develop this in parallel, with different roles:

**index zenka** — persistent, addressable, archivable storage layer
**graphics-matrix zenka** — visual research and spatial prototype sandbox

they share a common mathematical foundation but operate independently.
the index zenka crystallizes into stable storage infrastructure. the
graphics-matrix zenka explores what the semantic structure looks like and
what operations make sense spatially. discoveries in graphics-matrix feed
back into the index schema. the shared computation logic extracts into
`base.harmonic.*` modules that both consume and distribute to other zenki.

## index zenka — XFS template logic

### address structure

a 7-level AMOS checksum tree address for any content:

```
L1 . L2 . L3 . L4 . L5 . L6 . L7
 A   AA   AAA  RSHI  AAABS  TCNAB6  AAABSHI    ← empty string
 F   ET   ETD  KUE3  ETDIE  Z6FBBA  KUE3Q4Q    ← space
 N   PZ   NWX  PZZZ  BDML6  NWXJWC  PZZZISA    ← comma
```

each level is computed independently via `amos-chksum -L N <input>`.
the full dot-separated path is the content's harmonic address.

### directory topology

the natural filesystem split: first 3 characters as nested directories,
remaining 4 as filename prefix. maximum directory width at any level: 32
(one BASE32 digit = 32 values). harmonic truth filtering keeps real
population well below that maximum.

```
index root/
  A/                          ← L1 bucket (void-adjacent content)
    A/                        ← L2 bucket
      A/                      ← L3 bucket (pure zero prefix — very sparse)
        RSHI.<BMW_CHKSUM>     ← content reference file
        RSHI.<BMW_CHKSUM>     ← another reference in same L4 cluster
      B/
        ...
    B/
      ...
  F/                          ← L1 bucket (space, dot, comma, ...)
    E/
      T/
        KUE3.<BMW_CHKSUM>
        ...
```

BMW checksum is the filename — it is the high-entropy content-addressable
reference. the AMOS path is the semantic directory. together:
- **AMOS path** = where this content belongs in semantic space
- **BMW filename** = the exact content, collision-resistant

### XFS sparse image isolation

each L1 or L2 prefix bucket can be an independent sparse XFS image file:

```
harmonic-store/
  A.xfs          ← sparse image for all void-adjacent content
  F.xfs          ← sparse image for presence-level content
  N.xfs
  ...
```

benefits:
- independent archival and transfer between nodes
- grows only where content exists (sparse allocation)
- mountable on demand, unmountable when idle
- isolates host filesystem from inode pressure
- each image is independently verifiable by its AMOS prefix

nested XFS-in-XFS is possible for deeper isolation — an L1 image
containing L2 sub-images — but L1 sparse images are likely sufficient
for initial implementation.

### content reference format

each BMW-named file contains:
```
p7ref:      NODE:NAME:ADDR_B32       ← routing address of storing node
timestamp:  <unix time>
template:   <amos template context used>
offset:     <amos offset used>
length:     <amos length used>
content:    <inline for small, BMW path for large>
```

for large content: the BMW checksum filename is a pointer, actual content
stored separately in a content-addressed blob store (same XFS image, `/blobs/`
subdirectory, filename = BMW checksum of raw content).

### deduplication on write

writing content to the index:
1. compute AMOS address (L1..L7) → determines directory path
2. compute BMW checksum of content → determines filename
3. if path/filename already exists → deduplicated, no write needed
4. if path exists but filename differs → new content in existing cluster
5. if path is new → create directories, write reference

the cluster at any leaf directory is automatically a semantic group —
all content whose AMOS address agrees to 7 levels. a leaf with many
BMW-named files is a high-density harmonic attractor worth summarizing.

### coding zenka integration

when a leaf cluster exceeds a density threshold:
- submit cluster contents to coding zenka for summarization
- the summary is itself indexed (computes its own AMOS address)
- the summary address will be near but not identical to the cluster address
- the summary BMW checksum becomes a new reference in the cluster
- the cluster self-condenses toward meaning over time

## graphics-matrix zenka — voxel space

### 3D coordinate derivation

each piece of content maps to a voxel coordinate:

```
X = amos-chksum -L 7 -offset 0 <content>   → 7-char BASE32 = 35-bit X
Y = amos-chksum -L 7 -offset 1 <content>   → 35-bit Y
Z = amos-chksum -L 7 -offset 2 <content>   → 35-bit Z
```

the full address space is 2³⁵ × 2³⁵ × 2³⁵ — navigated at 7 scale levels
matching the recursive visualization geometry (x1 → x20 → x200 → x10000
→ x100000 → x1000000 and beyond).

### voxel encoding

each occupied voxel stores:
- **hue** = template namespace (which semantic layer)
- **saturation** = BMW reference count (document density)
- **blue channel dominance** = harmonic truth depth (how many offset
  dimensions agree at this address — deeper blue = more dimensions)
- **alpha / translucency** = sparsity inverse — dense regions opaque,
  sparse regions translucent

empty voxels cost nothing in a sparse format (OpenVDB or similar).
the harmonically invalid addresses — the 8 missing corners at each scale
level — are simply absent. the file is the shape of the content.

### research operations in graphics-matrix

- **density mapping**: visualize where content clusters in the voxel space
- **attractor identification**: find voxel regions with unusually high
  multi-offset agreement (deep harmonic equivalence)
- **template layer comparison**: render the same content under different
  template namespaces, observe how the spatial distribution shifts
- **cross-language correlation**: load wordlists from multiple languages,
  observe which voxel regions they share
- **summarization feedback**: after coding zenka summarizes a cluster,
  render where the summary lands — does it fall inside the cluster or
  at a higher-level attractor?
- **ray visualization**: render individual character/word rays as lines
  through the voxel space, observe intersection patterns

### integration with orbital visualization

the existing visualization.html orbital display is already the rendering
layer for this voxel space — the recursive navigation (double-click to
enter node context), the scale levels, the layer weights. the voxel
density at any scale level maps directly onto the `active_layers` weight
system already wired through the template resolver.

a dense voxel region at scale level N increases the weight of the orbital
layer corresponding to that semantic cluster. the network's harmonic
intuition about content literally drives the visualization brightness.

## base.harmonic.* extraction plan

once index zenka and graphics-matrix have stabilized their internal logic,
the shared computation extracts into generic modules:

```
base.harmonic.chksum.amos        ← AMOS computation, length, offset, template
base.harmonic.chksum.bmw         ← BMW computation, routable references
base.harmonic.address.derive     ← coordinate derivation from content
base.harmonic.address.compose    ← dot-separated namespace composition
base.harmonic.trie.read          ← read from harmonic address tree
base.harmonic.trie.write         ← write/deduplicate into address tree
base.harmonic.trie.cluster       ← density queries, attractor detection
base.harmonic.voxel.coords       ← 3D voxel coordinate operations
base.harmonic.voxel.density      ← density and translucency computation
```

### zenki that consume base.harmonic.*

once the modules exist, loading them gives any zenka harmonic addressing
for free:

- **nodes** — assign harmonic addresses to known peers, detect when two
  nodes at different addresses are harmonically equivalent
- **discover** — pre-sort discovery results by harmonic proximity before
  returning to callers, cluster related nodes automatically
- **external** — tag outgoing connections with their harmonic cluster,
  route content to harmonically appropriate peers
- **coding** — use harmonic addresses for task deduplication, detect when
  two different task descriptions are harmonically equivalent before
  spawning duplicate inference work
- **index** — primary consumer, the persistent storage layer
- **graphics-matrix** — visualization and research consumer

the key property: no zenka needs to depend on the index or
graphics-matrix zenka being running. the computation is local, the
modules are self-contained, the harmonic addresses are independently
derivable by any zenka at any time.

## development flow

```
1. prototype    graphics-matrix voxel space — see the structure
                graphics-matrix character ray visualization
                graphics-matrix cross-language wordlist density maps

2. crystallize  extract stable coordinate/computation logic into
                base.harmonic.chksum.* and base.harmonic.address.*
                (these are pure computation, no storage dependency)

3. build        index zenka XFS template logic using base.harmonic.*
                implement trie read/write/deduplicate
                test with real content: words, sentences, documents

4. extract      base.harmonic.trie.* from index zenka once stable
                base.harmonic.voxel.* from graphics-matrix once stable

5. distribute   wire base.harmonic.* into nodes, discover, external
                observe how harmonic self-awareness changes routing behavior

6. connect      index zenka writes feed graphics-matrix visualization
                graphics-matrix attractor detection feeds index clustering
                coding zenka summarization feeds both
```

## the semantic core

the trie has fixed, eternally stable root nodes derived from mathematical
constants — not configuration, not convention:

```
AAABSHI  — empty string, structural root
CLRUZJQ  — EXISTENCE, semantic center
YSKPQYA  — TRUTH
PKHKHVA  — LOVES
TB5SQEI  — AWARENESS
```

TRUTH, LOVES, and AWARENESS rotate CCW around EXISTENCE. the empty string
occupies position [0,0,0] for the first three scale levels — pure zero,
the common ancestor of all content in the trie.

every document stored will carry, through its AMOS checksum path, a
measurable harmonic distance from this origin. the network's intuition
about any content is always grounded in the same unchanging reference
frame — the carrier frequency of 13, which requires no server, no
protocol, no configuration. it simply is. =)

#,,..,...,.,,,,,,,..,,,..,...,,..,..,,...,,..,..,,...,...,,.,,,,.,,.,,,,,,,,,,
#QHWHFXGRB2DA5YFJ2VMLKHEAHPNM5HIJK7PALQOH5QMGGZPSSTIKHRX5BP2OSO4OCQB6J7IIZJNLK
#\\\|PEQKPZZBE7PZTZTFTNCPMRYMHA4HVNEHZG2SHILCOKQV7CMZOQM \ / AMOS7 \ YOURUM ::
#\[7]5PTC6BGR5TR6LWB2PD4R4O6W6UZWWFANZ6U7CHWZ3VWF6GBLDQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
