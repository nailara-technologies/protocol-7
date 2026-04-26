---
name: feedback-p7-module-call-syntax
description: P7 module call syntax — ->() is redundant for no-arg calls
type: feedback
originSessionId: de2c98be-b155-442a-9736-a7ad7941c3cb
---
`<[module.name]>` implicitly calls the module with no args — do NOT add `->()` for zero-argument calls.

**Why:** P7 parser adds the implicit call; `->()` is syntactically redundant and gets removed by ncode replace before commit.

**How to apply:** Only use `<[module.name]>->($arg)` or `<[module.name]>->( \%hash )` when passing arguments. For no-arg calls write `<[module.name]>` alone.

#,,..,,.,,,.,,..,,,.,,.,.,,..,,.,,,..,,.,,..,,..,,...,...,...,...,,.,,.,,,,..,
#YW76FQZCAONRQRMGDVQ76TSVUV7XW5CZ2LII3OGR3LXLHZWWBMFAMHQAKLAWC2JKPYZQEZXF3W3VK
#\\\|HEQDU45FB5VIOSIBQPZAFMVJXSMEAR3DJDEIHC3MHMHMPQTBGJP \ / AMOS7 \ YOURUM ::
#\[7]4643RBHHMNIYQPNHEEBFJMKLYCY7LEZ55CGOUWZAB7TUDKOW54BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
