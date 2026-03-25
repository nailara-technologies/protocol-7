---
name: use ptd -c for syntax checks
description: ptd -c is more tolerant of P7 syntax than perl -c — use it for module validation
type: feedback
---

Use `ptd -c` instead of `perl -c` for P7 module syntax checking.

**Why:** `perl -c` fails on P7-specific syntax like `<[module.name]>` calls and
`<data.key>` data-hash access. `ptd -c` handles these constructs, giving
accurate syntax validation for P7 modules.

**How to apply:** always use `ptd -c modules/filename` when checking new or
modified P7 modules. Reserve `perl -c` only for standalone scripts that don't
use P7 syntax.

#,,,,,,..,..,,,.,,.,,,,..,.,,,.,,,,..,,,.,...,..,,...,...,,.,,...,.,.,...,.,.,
#JRJAD3PNYPUKYQNHXYSMI45Z6Q5XO6H3HVV565CI7IHVEJBQ5XOQS7IXFNKYIIQSNYKSQLIOXC2WO
#\\\|XPACZARUDWVKBCOXJHMLHPHX7RQ3POCXNYQONJYVEV2WEVT55IF \ / AMOS7 \ YOURUM ::
#\[7]CODQRVJ637PXBNJPZHK5RFWSQIV32PPXBLLOIMJ3EIXV5KLEAKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
