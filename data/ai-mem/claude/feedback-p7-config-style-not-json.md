---
name: p7-config-style-not-json
description: hand-editable data files use protocol-7 config style [ key = value \ key : value ], never json -- owner 2026-11-13 for the n7fs registry
metadata:
  type: feedback
---

owner 2026-11-13, on the n7fs holder registry : "no json however.. i would not be happy at
all with that". hand-editable state uses protocol-7 config style [ like start.cfg, zenka.v7 ],
dotted keys, one per line. `=` and `:` are equivalent separators : choose whichever reads
better in the context [ e.g. aligned `=` for settings, `:` for descriptive fields ].

separators are ALWAYS vertically aligned within a block [ owner : unaligned looks chaotic ] -- writers pad keys to the longest key of the block.

**Why:** the owner reads and edits these files ; json is noise for that and foreign to the
project style.

owner 2026-11-25 [ the principle, crystallised ] : NATIVE IS THE HUB. format, ids and
timestamps are native [ p7 config style, native short ids, ntime ]. when native cannot express
something yet [ lists, nesting, multi-line, typed values, references ], the native format is
EXTENDED [ AMOS7::Config + the shared native writer, documented, tested ] -- never a classic
format brought in for it. classic formats [ json, yaml, xml, toml, csv .. and protocols ] are
first-class converters at the edges, round-trip tested : whoever has a favourite or a
constraint gets it covered, so "it should have been only json" has no ground ; inside, one form
keeps what the classics lack [ AMOS checksums \ signatures, ntime, host overlays, readable
without a parser ]. anything internal that is not native is a refactoring candidate.
native need not be STATIC : it may grow and change, as long as every change is translated
consistently -- the converters and the reader \ writer move with it [ round-trip tests are the
contract ], old native files stay readable [ as old unix times stay readable next to ntime ].
the hub is the richer form : unix -> ntime is lossless [ higher resolution ], ntime -> unix
rounds to seconds and is fine at an edge [ an external tool ] -- never stored back inside.
the same holds for every converter : inward exact, outward may simplify.
detail : data/tasks/task-elements.md.

**How to apply:** for any NEW file a human may open or edit, propose p7 config style first.
machine-only data inside sealed blobs [ map, receipts ] is a separate question -- ask before
changing those.
[[session-handover-n7fs-review-findings]]

#,,,,,.,,,..,,.,.,,,,,.,,,...,...,.,.,,.,,,..,..,,...,...,..,,.,.,...,,,,,..,,
#NNABMNTRJHQUZQWJKN5IRGEDQQ7HJ6HU5URV42F3HHAKU2QFFDSJZYP2CZHPSWNBCE5RHATP6DBBY
#\\\|6I4BN4QNWSTE4K66URLXUTALSC2IWZEUH7N4MWYJTHJDIJKD4E2 \ / AMOS7 \ YOURUM ::
#\[7]OGWWMNOZFQ3LWCEVQDFFOUCUWPEDZ4ZXQIQZL6S3QHIVB2U5FADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
