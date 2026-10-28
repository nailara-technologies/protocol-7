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
  comment above the list. I passed such a list in review [ cf534de4a ].

**Why:** each one looked fine in a diff and failed only on a real host.
**How to apply:** when reviewing a staged diff, check string requires for
the `.pm` form, autoload vs load for modules without import, and multi-line
qw lists for '#' -- `perl -c` on the touched bin/ scripts shows the qw case.

#,,..,.,,,,..,,.,,...,.,,,,,,,.,.,.,,,,,,,,..,..,,...,..,,.,.,,,.,..,,...,...,
#MMW2BART2ZG2FZY4GN7ZX4Q5HH57HG5WSEBWAC4HGEVCRIVKEIJBKMIL2RIMOSAJTPVYOEL4GVH26
#\\\|AFYOWMRBQOFNLARTGNMD4EEO4VIBCRMOFFA2I5SGALOQDXAHGOS \ / AMOS7 \ YOURUM ::
#\[7]VWD7Z3VGVIKG2KGADTSXLCIUX5TGZXDDLOEBSZWQII7HZ57PZYDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
