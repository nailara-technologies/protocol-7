---
name: feedback-nested-data-read-autovivifies-before-defaults
description: a nested <a.b.c> READ autovivifies <a.b> as {} -- run before init, it silently cancels a later '<a.b> //= {defaults}'. read early through ( <a.b> // {} )->{c} ; fill defaults per key
metadata:
  type: feedback
---

2026-10-15 : v7-zenki ran from 2026-10-11 with EVERY `system.path.zenka-dirs`
entry undef. `[base.host.detect]` [ zenka.v7, before `[init_modules]` ] read
`<system.path.zenka-dirs.var_P7>` -> perl created `zenka-dirs` as {} ->
`base.path-set-up.zenka-directories`' `<system.path.zenka-dirs> //= {...}`
in base.pre_init skipped all defaults. only symptom : 'undef value in sprintf
[base.config.load_proto_7_version:12 \ 18]' at cfg statement 004 [ most
callers fall back with `// '/var/protocol-7'` ]. the user's first guess
[ commit count reached 10K ] was wrong : the error predates commit 10000 by a
day -- correlating the first journal occurrence with git history settled it.

**Why:** `<a.b.c>` is a plain nested hash access ; a read creates every
intermediate level. a whole-hash `//=` default then sees a defined [ empty ]
hash.

**How to apply:** code that can run before init_modules reads through
`( <a.b> // {} )->{'c'}` [ as base.load_host_config does ] ; default blocks
fill per key [ `<a.b>->{$ARG} //= $default{$ARG}` ], never `<a.b> //= {...}`.
fixed in base.host.detect + base.path-set-up.zenka-directories, live start
confirmed clean.

#,,..,...,,,,,,.,,,,,,.,,,,,,,,,,,,,.,.,.,,,.,..,,...,..,,..,,..,,,,,,...,.,.,
#N52OQG7TCXKN4BNHVS6LPAPMF7DZC45G2NNVLL4NAAXPFUR7GFVAQYYWI6CE3OUJ6EHLQKXD2LKOO
#\\\|A3Z76M74DOB6Y5I7IZKW3HLQU3XLD53A4ZAIIAZGL5JLPEOFFT3 \ / AMOS7 \ YOURUM ::
#\[7]JOYVYVDRJWYJBCE5QHEKJR4DUEEO2CGEFWICWDQZIEBNSJ5OT6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
