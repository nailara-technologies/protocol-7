---
name: update-version-reset-amend-stuck-at-revision-1
description: bin/dev/update-version's 'reset amend' mode never advanced past .1 -- root-caused and fixed 2026-08-21, an unconditional reset-clobber ran after the amend increment
metadata:
  type: reference
---

**RESOLVED 2026-08-21.** `bin/dev/update-version reset amend` (see
[[release-versioning-workflow]] for what amend/reset-amend normally do)
never advanced the revision suffix past `.1` on repeated calls,
user-reported same day.

**root cause**, `bin/dev/update-version` around line 84-97:
```perl
$new_minor = $old_minor + $minor if $amend;   # (in the old_version match block)
...
$new_minor = 0 if $reset;                      # unconditional -- the bug
$new_minor = 1 if $amend and !$new_minor;
```
with `reset amend` both `$reset` and `$amend` are true. The amend-branch
correctly computed the incremented `$new_minor` (e.g. `old_minor=1` ->
`2`), but the very next line zeroed it again purely because `$reset`
was set, with no check for `$amend` also being set. The final fallback
line then always re-filled the now-zero value with exactly `1`,
regardless of what the real prior revision was. Every `reset amend`
call landed on `.1` no matter how many times it was called.

**fix**: guard the reset-clobber with `and !$amend`:
```perl
$new_minor = 0 if $reset and !$amend;
$new_minor = 1 if $amend and !$new_minor;
```
now `reset amend` correctly advances `.1` -> `.2` -> `.3` etc., and a
bare `reset` (no amend) still zeros as before.

#,,.,,..,,,,,,.,,,,,.,,,.,...,,,.,,.,,,,,,,.,,..,,...,...,...,,.,,...,...,,..,
#NR2XTB7PHKPDOTPUFDCV6YF5OBUXAU3YCWPED4FQ2G2C3VCU7E6TPLXB3J4BP3TIPRDDCKABOYQDG
#\\\|MAXAMXNCUBTCC2IJBQK5A76CICLJXJR54DQAULDNJLVMTCO67R5 \ / AMOS7 \ YOURUM ::
#\[7]REBUAZRSQ6GH2NI5JPQWRKSNMPZFWIGNUWKLMHXIX6PRVM6PBUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
