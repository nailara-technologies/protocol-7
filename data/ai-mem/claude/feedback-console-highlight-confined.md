---
name: console-highlight-confined
description: console listings : a background highlight covers only its element, reset right after, plain space around it ; same look on every row of a column
metadata:
  type: feedback
---

a background colour in console output covers exactly the highlighted element [ a name, a separator mark ], reset right after it, with plain spaces around it. never let it run to the end of the line, and never merge it with a neighbouring highlight.

**Why:** owner 2026-11-18 on `p7-keys list` : leaks tinted .secret \ .public but not .private, which read as meaning. highlights guide attention : header user name -> separator column, the line of relevance.

**How to apply:** select a column by position before any escapes are added [ placeholder, style last ], not by spacing patterns that only match some rows. check with `script -qc '<cmd>' file ; cat -v file`.

#,,.,,,..,.,,,.,.,,..,.,,,..,,,,.,...,,,,,,,,,..,,...,...,...,,..,,.,,,..,,..,
#7SGHX4FQL5RWJ5GNSXPU2M2SGJ25N47PSUCSCXQR5FAOYWGIXP4XZLWYTRHBXZN53FA7NZAQFKRTI
#\\\|IV22E7WQITNLDADER2BRT35ARITNQ6JVWMPZGKXE6ILDZITSOY7 \ / AMOS7 \ YOURUM ::
#\[7]OFG7YI2KEVZJAH7SPH2654LITMPVQ75XLFKQPMRMTJIURSXM64BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
