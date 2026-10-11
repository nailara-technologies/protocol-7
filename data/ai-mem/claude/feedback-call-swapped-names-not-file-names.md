---
name: call-swapped-names-not-file-names
description: modules that base.swap_subs themselves [ base.chk-sum.{jha,amos,bmw,bmw384,elf,profile}.* -> chk-sum.* ] must be CALLED by the target name -- <[base.chk-sum.bmw...]> is the most common cause of undefined subroutine errors
metadata:
  type: feedback
---

2026-10-11 : kimi's nameserv.zone.checksum called `<[base.chk-sum.bmw.512.B32]>` [ the file name ] ; the module renames itself to chk-sum.bmw.* in base.chk-sum.bmw.pre_init, so after load the base. name is gone -> 'undefined value as subroutine reference' on every fresh start. I first "fixed" it by adding chk-sum to modules.load [ wrong, not needed ]. the user : omitting the base. prefix is the correct form, and the redundant prefix is the most common reason for undefined subroutine errors. same session fixed 8 more such calls in 7 files.

**Why:** file names keep `base.` so the modules load early with base in every zenka ; the swap moves them. calls by file name only work by accident [ before the swap, or via a deferred-stub alias ].

**How to apply:** before calling a `base.*` module, check whether its family swaps [ `grep -rn swap_subs src/*init_code src/*pre_init` ] and call the target name : `<[chk-sum.bmw.ctx]>`, `<[chk-sum.elf]>`. NOT swapped, stay `base.` : base.chk-sum.reference, base.chk-sum.from_substr. `subroutines.load-early` lists FILE names [ base.chk-sum.* is right there ]. tell kimi this in every dispatch touching checksums. an 'undefined value as subroutine reference' -> check for a swapped-prefix call first. SINCE 2026-10-11 `bin/format-code -c` flags these [ 'swapped name [ line N ] : <[old]> -> <[new]>' ; pairs from AMOS7::Protocol::P7Syntax p7_syntax__swap_pairs, shared with bin/dev/dep-graph ] -- the first full scan found 10 such calls in 9 files. related : [[use-format-code-not-perl-c]].

#,,..,,.,,,,,,.,,,.,.,,..,.,,,,,.,,..,,,,,...,..,,...,...,...,,,.,,,.,,,,,.,.,
#GLPZHFS4JGIDZNS4YV3I5RYAJKI7FI2YB226JQB3XYDJ6UV4VDY6L2OYQV7SWU4K2SD64JN2WV2NY
#\\\|NXJRXXXFFB7XKYY6KOXOG4MZOOXB4RIVEWDGFQZEJCBCWHLQNXT \ / AMOS7 \ YOURUM ::
#\[7]2FXKSM2RCV6EOEUNTPGTF6ERQVI7UQA3E7T2GR4UUXTPMKLFXWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
