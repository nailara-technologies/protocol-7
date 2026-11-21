# document scanning and archiving : paper into n7fs, blue-doc as a derived layer

status : brief, not dispatched [ owner 2026-11-21 ]. builds on
data/md/design/BLUE-DOC-FORMAT.md [ import pipeline, glyph table + layout stream ],
HARMONIC-PAGE-DIMENSIONS.md, N7FS-INCOMING.md, N7FS-TREE-CATEGORIES.md,
N7FS-SEARCH-INDEX.md, data/tasks/n7fs-logical-trees-and-mount.md.

## problem

- paper documents need backups as much as digital data : a lost folder is lost data
- blue-doc is specified [ two-blue palette, harmonic page geometry, glyph dedup ] but
  not tied to any storage : scans would live wherever the scanner left them
- blue-doc merges character instances into canonical glyphs -- better to read, but by
  design NOT the original. an archive needs the original

## principle : two layers

1. the archive master : the scan as taken [ lossless, 300 dpi for text, 600 for fine
   print and photos, every page, front and back where printed ] -- stored once in n7fs,
   never modified, never replaced by a derived form
2. derived layers, rebuildable from the master at any time : blue-doc [ harmonic page,
   two blues, glyph table + layout stream ], ocr text, thumbnails. a better blue-doc
   pipeline later re-derives from the same masters

## part 1 : scan intake

- scanning through sane [ scanimage ; adf and duplex where the scanner has them ] into
  the n7fs incoming pool [ N7FS-INCOMING.md ] -- one incoming item per document, not
  per page
- a document = its pages in order + a small p7 config record : date on the document,
  date scanned, sender \ issuer, category, tags, language, physical location of the
  paper [ folder \ box ], retention [ keep paper | may shred after n copies ]
- the record is filled with as little typing as possible : suggestions from the ocr
  text [ dates, sender lines ] by a local model, confirmed by the owner

## part 2 : n7fs placement

- one logical tree per archive area [ e.g. documents-<category> ], category
  'documents' : private layer, high copies [ like tier a of the disk rescues ], local
  encryption cascade once enforced
- masters and derived files in separate trees : the derived ones can have fewer
  copies, they are rebuildable
- the paper may be shredded only after its master is placed with the wanted copies
  [ receipts, N7FS-PLACEMENT.md ] -- the tool says when that is true, the owner decides

## part 3 : search

- ocr text per page [ tesseract or similar, local ] as a derived file ; indexed by the
  n7fs search index [ N7FS-SEARCH-INDEX.md ] together with the record fields
- find by text, date range, sender, category ; results open the blue-doc view, the
  master is one step away

## part 4 : blue-doc derivation

- the existing import pipeline [ bin/dev/tests/data/blue-doc-import-test.pl ] becomes
  the first derive step : despeckle, two-blue replacement, harmonic canvas
- the glyph table is a SHARED corpus tree across documents [ the dedup gains grow with
  the corpus ] ; per-document layout streams reference it
- open questions stay in BLUE-DOC-FORMAT.md [ segmentation, merge alignment, fuzz
  calibration ] -- this brief only needs the derive step to be repeatable

## stages

1. scan intake to the incoming pool + document record [ no blue-doc yet ]
2. documents category + trees, placement, the 'may shred' report
3. ocr + search index
4. blue-doc derive step from the masters ; the shared glyph tree
5. record suggestions by a local model

## rules

- documents are personal data : nothing of their content, names or numbers in repo
  files, tests use generated pages only
- p7 config style, no json ; BMW \ AMOS checksums, no sha ; perl floor 5.32
- never touch a live n7fs tree in place during development

#,,,,,,,.,..,,.,,,,,,,,,.,,..,,,.,,..,,.,,.,,,..,,...,...,.,.,.,,,..,,...,.,.,
#YJXUPIQL6UL4U4IDR44RNWGCCBJNTFMZOOZQNLNOJAIEQXKTF5YC3IKTRSOZCRQ6IMS4YNEYWAIGO
#\\\|7XYO32ULLRUX3XO6X4ELOHVMUC7IKYICZA4MBXTTHUGKKNEYINH \ / AMOS7 \ YOURUM ::
#\[7]M5W7RNASA4ORVNIFCYFQLHAIJANZJO4H7XFNNJNPRFUFL7B7KYAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
