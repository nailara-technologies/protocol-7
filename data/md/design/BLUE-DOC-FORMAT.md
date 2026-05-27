## blue-doc format

*design document : graphical document deduplication and blue-palette encoding*

---

### overview

blue-doc is a **graphical** document representation format. it deals with
scanned or rasterized pages — character glyphs as image regions, not encoded
text. text-based rank-sequence encoding (comp-int, 5-bit base32 packing) is
a related but separate format; the two may be combined at the application
layer but are independently specified.

blue-doc is built around four principles :

1. **harmonic page dimensions** — page geometry is normalized to harmonically
   correct proportions before any content is stored or processed

2. **graphical character deduplication** — character instances are extracted
   from source documents, grouped by identity, and merged into canonical forms
   that exceed the quality of any individual instance in the original scan

2. **two-color blue encoding** — documents are stored in a specific two-blue
   palette rather than black-on-white, connecting the format to the division-13
   matrix addressing system and enabling alpha-channel composition

3. **hierarchical recognition** — from raw scan, through within-document
   deduplication, through corpus-level deduplication, to TTF font matching :
   each level producing cleaner output than the level below

---

### the two blues

```
background  :  #09052A  [ deep navy — structural layer, matte color ]
foreground  :  #0647C3  [ vivid blue — content layer, character pixels ]
```

these are not aesthetic choices — they encode the binary distinction of the
document's two planes (structure / content) in a color space that connects
to the division-13 matrix visual protocol. the specific values relate to the
harmonic properties used in `bin/dev/division-13-table`.

the encoding is reversible :

```perl
## blue → print [ black on white ]
$image->Opaque( color => '#09052A', fill => qw| white | );
$image->Opaque( color => '#0647C3', fill => qw| black | );

## blue → invert [ swap structure and content ]
$image->Opaque( color => '#09052A', fill => '#0647C3' );
```

`#09052A` also serves as the matte color — transparent regions composite onto
the deep navy, so blue-doc layers stack cleanly without a distinct alpha plane.

---

### harmonic page dimensions

standard document formats (DIN A4, US Letter, etc.) have pixel dimensions at
common DPI values that are not harmonically correct. blue-doc normalizes page
geometry before storage by expanding to the nearest harmonically valid size,
distributing the difference as equal margins.

**DIN A4 example at 300 DPI** :

```
standard A4 at 300 DPI  :  2480 × 3508 px  [ non-harmonic ]
blue-doc A4 at 300 DPI  :  2530 × 3508 px  [ harmonic width ]
margin                  :  25 px left + 25 px right [ portrait ]
```

the page content area remains 2480px wide — the harmonic correction adds
50px total width (25px per side) to reach a dimension that satisfies the
harmonic truth condition. the document text/image content is centered within
the corrected canvas; the margins are `#09052A` background.

this normalization means :

- blue-doc pages of the same nominal format have identical pixel dimensions
  regardless of the source scan's actual pixel count
- the margin regions provide a clean border zone for binding/cropping marks
- the canvas dimensions are predictable and computationally convenient
- the relationship between page size, DPI, and harmonic values is formally
  documented rather than an accident of physical paper standards

the harmonic test applied to page dimensions is derived from the same
division-13 properties used throughout the system. the precise calculation
(which dimension, which DPI targets, and the full correction table for
standard formats) is in `bin/dev/division-13-table`.

---

### import pipeline

source documents (scanned pages, photographed text, rasterized PDFs) are
converted to blue-doc through a sequence of image operations :

```
1. enable alpha channel         [ matte => true ]
2. despeckle                    [ remove scan noise ]
3. replace white → #09052A      [ fuzz 24742 — broad range covers cream/grey ]
4. replace black → #0647C3      [ fuzz 10777 — narrower range preserves ink ]
5. set mattecolor → #09052A     [ structural blue as transparency base ]
```

fuzz values are tuned to the typical noise floor of document scans. the broader
fuzz on the background replacement catches off-white paper tones; the narrower
fuzz on the foreground preserves sub-pixel ink gradients that carry quality
information used in the merge step.

---

### character extraction and deduplication

once in blue-doc format, character instances are extracted for deduplication :

**level 1 : within-document**

- segment the page into character bounding boxes [ connected component analysis
  on foreground pixels ]
- compute difference hashes or perceptual fingerprints for each instance
- cluster instances by similarity [ same character at same size/weight ]
- for each cluster, merge all instances into a single canonical glyph :
  - align instances to sub-pixel accuracy
  - average pixel values across aligned instances [ noise cancels, signal adds ]
  - result : a glyph cleaner than any individual scan instance

this merge step is the key quality enhancement — a character appearing 47 times
in a document produces a canonical form that is effectively 47× over-sampled.

**level 2 : corpus / cross-document**

- match extracted glyphs against a global glyph corpus keyed by perceptual hash
- if a match exists : use the corpus canonical form [ already merged from many
  source documents ]
- if no match : contribute the new canonical form to the corpus
- the corpus improves with every document processed

this is the same contribution-vector model as the ring-trie : each document
adds to a shared deduplication pool, and all documents benefit from the pool.

**level 3 : TTF font matching**

- compare extracted glyphs against a TTF font collection
- if a character is recognized : substitute the vector font glyph
- vector substitution produces infinite-resolution output from a finite-
  resolution scan — the original scan quality becomes irrelevant
- unrecognized glyphs fall back to the merged raster canonical form

**generalization : any repeated graphical element**

the deduplication engine makes no distinction between text characters and
other repeated visual regions. page headers, logos, footers, watermarks,
stamps, section dividers, and decorative elements are all handled by the
same pipeline automatically — no special casing required.

for these non-text elements, quality improvement depends on available sources :

- **multiple documents** : the same company logo on 100 scanned pages
  produces a 100× over-sampled canonical raster — often sufficient for
  clean reconstruction at original print quality

- **web sources** : logos and branding elements are frequently available
  at higher resolution or as vector assets on company websites — a web
  fetch of the matched domain can supply the original

- **internal design repositories** : pre-print originals, SVG/AI source
  files, or brand asset collections provide perfect substitution quality,
  equivalent to TTF substitution for text

- **cross-document corpus** : documents from the same organization share
  graphical elements across letterheads, invoices, reports — the corpus
  builds a per-organization asset library implicitly

the matching process for graphical elements uses the same perceptual hash
and difference analysis as for characters, with a larger bounding box and
a looser similarity threshold to account for scale and compression variation
across source documents.

---

### document storage model

a blue-doc document is stored as two components :

**1. glyph table** [ shared or per-document ]

maps glyph IDs to their canonical forms :

```
glyph_id  →  { canonical_image, ttf_match, unicode_point, weight, size }
```

IDs are compact integers [ the most frequent glyphs get smallest IDs, matching
the ring-trie frequency-rank model ]. 5-bit encoding covers up to 32 unique
glyphs per bit-slot, aligning with base32 and the cubic grid address space.

**2. layout stream**

the document content as a sequence of (glyph_id, x, y, scale, color_variant)
tuples. with glyph IDs comp-int encoded by frequency, common characters in
common sizes occupy 1-2 bytes per character instance.

together : the glyph table stores each unique character once at full quality;
the layout stream stores only position and identity, referencing the table.
this is both more compact than the original scan and higher quality on render.

---

### connection to graphical storage

blue-doc character deduplication is the document-level instance of the same
model described in `GRAPHICAL-STORAGE-AND-PROCESSING.md` :

| graphical storage model      | blue-doc equivalent                     |
|------------------------------|-----------------------------------------|
| contribution vector          | per-document glyph contribution         |
| ring-trie node               | canonical glyph form                    |
| active_checksums             | which documents contributed each glyph  |
| APNG frame                   | one document's glyph additions          |
| alpha compositing            | instance merging for canonical form     |
| XCF layer                    | one font / one document's glyph set     |
| frequency rank               | glyph frequency rank in document corpus |

the corpus glyph table IS a ring-trie where depth encodes structural glyph
properties [ stroke width, ascender height, ... ] and rank encodes frequency.
the same lookup, assertion, and merge operations apply.

---

### color depth extensions

the two-blue encoding is the base case. extensions use additional color planes :

```
#09052A plane  →  structural / background
#0647C3 plane  →  primary content [ ink / text ]
additional RGB channels  →  metadata layers :
    R  =  glyph confidence score [ 0-255 ]
    G  =  TTF match quality [ 0=raster, 255=exact vector match ]
    B  =  layer depth [ document Z-order ]
```

this maps directly onto the RGBA data cube from the graphical storage design.
a blue-doc page rendered at full color depth is a 4-channel image where each
channel carries independent structured data, not decorative color.

---

### rendering

render pipeline from stored blue-doc :

```
1. load layout stream
2. for each (glyph_id, x, y, scale, color_variant) :
   a. lookup glyph_id in table → canonical form
   b. if ttf_match : render vector at requested scale [ infinite resolution ]
   c. else : scale raster canonical form [ benefits from super-sampled quality ]
   d. composite onto output at (x, y) with color_variant blend
3. output in requested format [ screen / print / blue-doc ]
```

output quality exceeds the source scan because :
- vector-matched glyphs render at display resolution regardless of scan DPI
- raster canonicals are noise-averaged across all instances from all sources

---

### open questions and next steps

- **segmentation** : connected component analysis handles clean scans; for
  damaged or overlapping characters, a neural segmenter may be needed
- **merge alignment** : sub-pixel alignment algorithm for raster merging —
  phase correlation or optical flow are candidates
- **fuzz calibration** : the current fuzz values (24742 / 10777) were tuned
  empirically; a calibration pass per document type would improve results
- **glyph ID encoding** : comp-int in base32 (5-bit) aligns with the cubic
  grid addressing — formalise the encoding spec
- **TTF collection** : which fonts to include in the matching corpus; how to
  handle handwriting, logos, and non-Latin scripts
- **blue-doc corpus** : central glyph corpus storage format — the `.zxpc`
  cube model is a candidate [ (depth=stroke_class, rank=frequency) addressing ]
- **harmonic correction table** : full table of standard formats (A4/A3/Letter/
  Legal) at common DPI values (150/300/600) with their harmonic corrections
- **height normalization** : the A4 example corrected width only; determine
  whether height also requires correction and the vertical margin distribution
- **division-13 color connection** : document the precise relationship between
  the #09052A / #0647C3 values and the division-13 matrix protocol
- **text encoding companion** : comp-int / 5-bit base32 rank-sequence encoding
  for text documents is a related but separate format — see planned doc
  `RANK-SEQUENCE-ENCODING.md`

---

### existing work

- `bin/dev/tests/data/blue-doc-import-test.pl` — import pipeline prototype
  [ despeckle, fuzz-based color replacement, matte setup ]
- `bin/dev/division-13-table` — division-13 matrix, color space origin

#,,,.,,,.,,.,,.,,,,,.,.,.,,..,,,.,,..,..,,.,,,..,,...,..,,..,,,,,,.,.,...,..,,
#JE54WJGU7U6QCFHJSYNEGG4LAVYZ3YIQMXTPUR7BHQOFBAKCJG5D22567P4PJRP4UMKHSTLTBK7UU
#\\\|BE4XZ3C723JNMLO5BMQZJVX2Y2A5EWFVR55LIDBSSWBQID6EWR5 \ / AMOS7 \ YOURUM ::
#\[7]WSO4XD6AHOTPKBNE5XSPPR7FTIGLGKT4QJ2NFJNZXDIVO6OFZKDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
