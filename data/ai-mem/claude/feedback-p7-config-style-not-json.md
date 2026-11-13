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

**How to apply:** for any NEW file a human may open or edit, propose p7 config style first.
machine-only data inside sealed blobs [ map, receipts ] is a separate question -- ask before
changing those.
[[session-handover-n7fs-review-findings]]

#,,,.,,,.,.,,,,.,,..,,..,,,,.,,,.,.,,,,,,,..,,..,,...,...,.,.,,,.,,..,...,,,,,
#Z4F5A4C3EL3VOWR4W7XQJ5FERRUCCENXAFS54G3DEAGOR3YHYBGRJ5SK2EBMXDE3NBEV54FFAOFLU
#\\\|2SQW4EEXMFTVWJF4RJSLTEJQUJZQ52ZKFLLJTNVMIGHUGOD4XOH \ / AMOS7 \ YOURUM ::
#\[7]72BB3MYO6HY66PSMIAUPHJ5WIPNGFW3O3RGIW2GLN6JG4OKHUQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
