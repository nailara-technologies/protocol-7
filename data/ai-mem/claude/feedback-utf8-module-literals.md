---
name: utf8-module-literals
description: non-ASCII literals in module format strings cause double-encoding — keep them ASCII-only
metadata:
  node_type: memory
  type: feedback
  originSessionId: 9673d387-d522-4dcb-9938-56cc0137481a
---

Module source files are eval'd without `use utf8`, so non-ASCII literals (—, →, etc.) are raw bytes with no UTF-8 flag. When used as sprintf format strings alongside UTF-8-flagged arguments, Perl promotes the bytes as Latin-1, corrupting the output.

**Why:** `use utf8` in `bin/Protocol-7` does not propagate into eval'd module code. adding it to the eval wrapper makes things worse if network args arrive as bytes (opposite corruption).

**How to apply:** keep all sprintf format strings in modules ASCII-only. the test script at `bin/dev/utf8-sprintf-test` documents all four flag-state combinations and their outcomes. the correct fix (case 4) requires both format AND args to be unicode-flagged — a larger change involving `utf8::decode` at the network receive boundary.

#,,..,.,.,.,.,,..,,,.,,.,,.,,,..,,..,,...,,,,,..,,...,..,,..,,,,.,..,,,..,,.,,
#AN7RRVYVNKODHYSK7CS3VVBDZIAFW2ETC2LP7OVJTHRS2L4NA4UM4YGX2TNCI6RDMK27QKSWCYGUQ
#\\\|YVJCHTPIFJB2LUVGSIG7PDGGII7MA4PLRLCN5LE2JSANNB7W4X4 \ / AMOS7 \ YOURUM ::
#\[7]UGBVJRFCYMDRTY3UCDBVDVPJ4BGHPN23NKMY5KKJXAO2QRR7OYDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
