---
name: perl-loader-gotchas-require-path-inline-c-qw
description: three loader bugs of 2026-10-28 : a STRING require needs 'Foo/Bar.pm' [ 'Foo::Bar' is a file name ] ; Inline::C dies on import -> base.perlmod.load, never autoload ; a '##' comment inside a multi-line qw| | becomes list words [ p7-install asked apt for '##' 'XS' 'build' ]
metadata:
  type: feedback
---

- **`require $var`** with `$var = 'Digest::BMW'` looks for a FILE named
  `Digest::BMW` and always fails -- convert first : `s|::|/|g` and append
  `.pm` [ the user found this in p7_soft_require ; the same bug sat in the
  new pm-src reload check of base.perlmod.install until review ]. the %INC
  key to clean after a failure is that `.pm` path too.
- **Inline::C** cannot be imported : 'It is invalid to use Inline::C
  directly'. `base.perlmod.autoload` imports -> the install succeeds and
  the reload still fails. presence checks use `base.perlmod.load`.
- **comments inside `qw| |`** are list words [ perl warns 'Possible
  attempt to put comments in qw() list' at compile time only ]. put the
  comment above the list. I passed such a list in review [ 53edb5f2c ].

**Why:** each one looked fine in a diff and failed only on a real host.
**How to apply:** when reviewing a staged diff, check string requires for
the `.pm` form, autoload vs load for modules without import, and multi-line
qw lists for '#' -- `perl -c` on the touched bin/ scripts shows the qw case.

#,,.,,,,.,..,,,..,,..,,,.,,.,,,.,,.,.,...,,..,..,,...,...,.,,,.,,,.,,,.,,,.,,,
#72KYFRG4HOMMLKNBQUZWIFIEG7U4OQ6K6HUTCTIRPSXPE6SQCLLSNVQ5G6RFGNEPD5GNT5YSCLLQE
#\\\|OZUK5LQ7NCHQRJ3QGCJ3VY6PE33RMFTZKM3EWGNME7DO2TYN4NM \ / AMOS7 \ YOURUM ::
#\[7]CNEBE7WVGOS4HZJ6PHMZIYVIBBNNRWQYSXP67FXRYYFVTIZQSSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
