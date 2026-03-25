---
name: ptd-as-post-generation-step
description: use ptd (not ptd -c) after writing modules — formats code and checks syntax in one step
type: feedback
---

Use `ptd` (not `ptd -c`) as a regular step after generating P7 modules. It formats the code AND does syntax check implicitly. The user runs ptd before signing anyway, so a separate `ptd -c` step is redundant.

**Why:** saves a step in the workflow — ptd already covers syntax checking.
**How to apply:** after writing a new module, run `ptd modules/name` instead of `ptd -c modules/name`. Skip the separate syntax check.

#,,,.,..,,,..,.,,,.,.,,.,,,,.,,,.,,..,,,.,.,.,..,,...,...,,,.,.,,,,,.,...,,,.,
#B5PUI7UZUUZR6CSRVNUPZDC6EL7NCHGL63GRQUQLFQEZVSQY3L4XWJJFGOG5GGR6TXXW54K2UTXTA
#\\\|FKCL2MZUKP3TMY3YIDCVJXWG2TAJLHCCYHU5GO3GCGWZYMNCKFD \ / AMOS7 \ YOURUM ::
#\[7]JRSKYRDR6RUTDQTLZZSY35M3HIDXHED45ZLSF275BC2KMRQNAOAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
