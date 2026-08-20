# task: graphics-matrix — harmonic voxel space research

## context

see `data/md/documentation/harmonic-storage-architecture.md` and
`data/md/documentation/entropy-at-deduplication-root.md`.

the graphics-matrix zenka is the visual research layer for the harmonic
storage architecture. this task adds voxel coordinate derivation from
AMOS checksum offsets and visualization tooling to explore semantic
density, attractor patterns, and cross-language correlations spatially.

## what already exists — do not re-implement

- `index.gen_path` — AMOS path generation using modes 5,7 across offsets 0-6
  with truth filtering. the path generation logic is already there.
- `src/graphics-matrix.*` — existing cells, graph, glow, channels,
  cursor, address modules from the Apr 16 session.
- `visualization.html` — orbital visualization with recursive nav, layer
  weights, template resolver. the rendering target is already built.
- `storage.map-dirs.init_code` — XFS mmap'd store with depth 7 tree.

## what to build

### phase 1 — 3D voxel coordinate derivation

add `graphics-matrix.harmonic.coords` — computes 3D voxel position from
AMOS checksum offsets 0, 1, 2 of the same input:

the `-L offset,length` parameter of amos-chksum gives independent harmonic
projections. use `<[chk-sum.amos]>->(\$input, mode)` at different offsets
to get X, Y, Z coordinates.

note from experiments:
- LOVES: Y and Z collide (`HXODOCQ` for both) — harmonic symmetry in those
  axes for this input. this is correct, not a bug.
- the collision depth reveals structural relationships between axes.

add `graphics-matrix.cmd.harmonic-coords`:
```bash
p7c graphics-matrix.harmonic-coords "LOVES"
# → x: IRGMQ5Y  y: HXODOCQ  z: HXODOCQ
```

### phase 2 — ray table generation

add `graphics-matrix.cmd.ray-table` — generates the full 7-level tree
address table for a list of space-separated inputs:

```bash
p7c graphics-matrix.ray-table "TRUTH LOVES AWARENESS EXISTENCE SILENCE"
```

output: tab-separated table showing L1..L7 for each input, showing where
rays converge and diverge through the 7-level space.

known reference values from experiments (verify these):
```
empty:   A   . AA  . AAA  . RSHI  . AAABS  . TCNAB6  . AAABSHI
space:   F   . ET  . ETD  . KUE3  . ETDIE  . Z6FBBA  . KUE3Q4Q
dot:     F   . OR  . 5M5  . SC4O  . F4VWJ  . SC4O6W  . EEM3L3I
comma:   N   . PZ  . NWX  . PZZZ  . BDML6  . NWXJWC  . PZZZISA
?:       H   . XC  . XC7  . ZNDF  . ZKRGZ  . ZKRGZO  . ZNDFIGY
```

### phase 3 — in-memory voxel density grid

add `graphics-matrix.harmonic.density` — maintains a voxel density grid:

```perl
<graphics-matrix.harmonic.voxels> = {};
## key: "X:Y:Z" (first 3 chars of each offset checksum) → { count, inputs }
```

add `graphics-matrix.cmd.voxel-add` and `graphics-matrix.cmd.voxel-density`.

density queries:
- top N most dense voxels
- voxels above threshold (attractor candidates)
- voxels where multiple offset dimensions agree (deep harmonic equivalence)

### phase 4 — orbital visualization integration

extend `orbital.json` or add `harmonic.json` endpoint with:
```json
{
  "harmonic_attractors": [
    { "x": "HXO", "y": "HXO", "z": "HXO", "density": 4,
      "inputs": ["LOVES", "AMOR", "LIEBE", "AMOUR"],
      "axis_agreement": 2 }
  ]
}
```

in `visualization.html` add `harmonic-voxel` layer:
- attractor voxels as glowing blue spheres at orbital coordinates
  (X/Y/Z checksum prefix → theta/phi angle via the existing
  `p7refToCoords` / `decodeB32` machinery already in the JS)
- sphere size = log(density)
- blue channel intensity = axis agreement count (how many of X/Y/Z agree)
- alpha = sparsity inverse

integrates with existing `active_layers` / template resolver system —
weight increases as content density grows in the voxel space.

### phase 5 — character ray visualization mode

in `visualization.html`, "Rays" toggle button:
- for each printable ASCII character, compute its 7-level tree address
- each address level → spherical coordinate → point in orbital sphere
- connect 7 points as a line = the character's harmonic ray
- color by class: punctuation (cyan), alpha (green), digit (yellow)
- rays that converge at level N share that scale level's address bucket

### phase 6 — wordlist cross-language analysis

add `graphics-matrix.cmd.analyze-wordlist`:
1. reads wordlist file (one word per line)
2. computes ray table (gen_path) for each word
3. groups by address prefix at depth 1, 2, 3
4. reports which groups contain words from multiple languages
5. identifies attractor voxels — groups reached from multiple sources

bridges to the index zenka's `index.correlate` command — graphics-matrix
makes the correlations visually navigable, index zenka stores them.

## research questions to answer

- do cross-language synonyms share voxel coordinates? at which offset?
- does the Y=Z collision pattern for LOVES repeat for semantically related
  words in other languages?
- where do the semantic triangle constants land relative to each other in
  3D voxel space?
- what is the voxel distance between AAABSHI (empty) and CLRUZJQ (EXISTENCE)?
- do the gen_path modes (5,7 in index.gen_path) produce the same clustering
  as the offset-based 3D coordinates?

## testing

```bash
p7c graphics-matrix.harmonic-coords "LOVES"
p7c graphics-matrix.harmonic-coords "AMOR"
# verify Y=Z collision for LOVES

p7c graphics-matrix.ray-table "TRUTH LOVES AWARENESS EXISTENCE SILENCE"
# observe where semantic triangle constants diverge

p7c graphics-matrix.voxel-add "LOVES"
p7c graphics-matrix.voxel-add "AMOR"
p7c graphics-matrix.voxel-add "LIEBE"
p7c graphics-matrix.voxel-density
# observe whether synonyms cluster
```

## signatures note

do NOT add stub signature line to new files.

## reference

- `src/index.gen_path` — existing path generation to understand the
  checksum matrix construction (modes 5,7, offsets 0-6, truth filter 7,9)
- `src/graphics-matrix.*` — existing graphics-matrix modules
- `data/web-root/vhosts/space.v7.ax/visualization.html` — rendering target
- `bin/amos-chksum -q -L offset,length` — offset checksum experiments
- `data/md/documentation/entropy-at-deduplication-root.md` — character ray
  table and semantic constants reference

#,,,,,,..,,,.,,,.,.,,,,.,,..,,..,,,..,...,.,.,..,,...,...,..,,.,,,,,,,,.,,,.,,
#WFQ6UCTI5MZSRZMXWHE4PLU5Y3777DMBD5LHY2J5G2NR3B6FNPIFMBCUE5LMDMXPNRDZ7NCY5PPSG
#\\\|LEGSBPKHUBER7T6SGULYBUGZJZ74H3VBORSOHQC5WFLAVM4EJQF \ / AMOS7 \ YOURUM ::
#\[7]Q2KD2XJJ2JH4KWA54H43W7A37Y4GSINSECUCTMKVYDDYS7QLMUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
