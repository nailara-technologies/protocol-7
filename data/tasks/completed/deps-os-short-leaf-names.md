# task: shorten deps/os/debian and deps/os/binary to deps/os/deb, deps/os/bin

## archive: DONE ✓ — 2026-08-21
## commit: c65b8cbc2 — rename per-zenka source/pm-dep/os-dep dep-tracking dirs to deps/{src-used,p-mod,os/{deb,bin}}
## notes: landed same commit as the wider deps/ rename it was scoped out of; see below for how the mapping-table approach avoided the originally-estimated 9-file rewrite

## status: DONE (2026-08-21)

landed via a mapping-table approach that turned out much smaller than
the full rewrite originally scoped below: only 3 files needed changes,
not 9, because it turns out only one site reads a directory name into
a type string (`scan_zenki_os_deps`) and only two sites write a path
from a type string (`sys-deps.cmd.promote`, `bin/os-pkg`'s `declare`).
Everything else — `sys-deps.cmd.missing/install/check/state/undeclared`,
`v7.check_zenka_deps`, `bin/p7-deps` — only ever *consumes* the type
string that already came out of `scan_zenki_os_deps`, so none of them
needed touching at all.

**implementation** (`data/lib-path/pm/AMOS7/deps/os_package.pm`):
```perl
my %TYPE_TO_DIR = ( debian => 'deb', binary => 'bin' );
my %DIR_TO_TYPE = reverse %TYPE_TO_DIR;

sub dep_type_to_dir { my ($type) = @_; return $TYPE_TO_DIR{$type} // $type; }
sub dep_dir_to_type { my ($dir)  = @_; return $DIR_TO_TYPE{$dir}  // $dir; }
```
- `scan_zenki_os_deps`: maps the raw `readdir` name through
  `dep_dir_to_type` right after reading it, before it becomes a hash
  key or hits the `eq 'binary'` special-case check — both keep working
  unmodified since they now see the canonical long-form string.
- `sys-deps.cmd.promote` and `bin/os-pkg`'s `declare`: map `'debian'`
  through `dep_type_to_dir` when building the on-disk path.
- `base.check_dependency_dirs` (provisions the dirs) and
  `base.register_bin_deps` (registers binary deps) hardcode the short
  literals directly (`deps/os/deb`, `deps/os/bin`) rather than calling
  the mapping function — they don't reason about the type-string data
  model at all, just create/touch paths, so adding a dependency on
  `AMOS7::deps::os_package` there would be unnecessary coupling.

on-disk: all `cfg/zenki/*/deps/os/{debian,binary}` renamed to
`{deb,bin}` via `git mv` (236 files across ~118 zenki).

fallback behavior: `// $type` / `// $dir` in both helpers means an
unmapped/future third dep type (if one is ever added) falls through
using its own name unchanged in both directions — no code changes
needed to add a new type, only a `%TYPE_TO_DIR` entry if it should
also get a shortened on-disk form.

---

## original scoping (superseded by the above — kept for context)

deferred, undecided as of first landing the `deps/` rename (source ->
deps/src-used, pm-dep -> deps/p-mod, os-dep/{debian,binary} ->
deps/os/{debian,binary}) on 2026-08-21. the os/debian and os/binary
leaf names were initially kept at their original length instead of
shortened to `deb`/`bin`, because of the following concern — which the
mapping-table approach above resolved without needing the 9-file
rewrite it assumed was necessary:

in `scan_zenki_os_deps`, the directory *leaf name itself* becomes the
runtime dependency "type" string — it opendirs `deps/os/`, reads
whatever subdirectory names exist, and uses them directly as hash keys
(`$os_deps{$type}`), with `binary` getting an explicit special-case
branch and everything else (currently just `debian`) falling through
generically. that type string is then compared literally
(`eq 'binary'`, `eq 'debian'`) across sys-deps.cmd.*, v7.check_zenka_deps,
bin/p7-deps, bin/os-pkg — the initial assumption was that renaming the
leaf dirs would require updating all of those comparison sites too.

#,,.,,..,,.,,,,.,,.,.,..,,.,,,...,,,.,,.,,...,..,,...,...,,,,,.,,,...,,,.,..,,
#ATIZZM7GKQYNYB2DACJHSS5WYOO7H25KK7RQ2TPE5CKG47RM6OFXD2QH7MYTJCLVLDE6DRBYX4ICU
#\\\|57GH4ZGS5CEZCWV7YMGIHYAQJOHK4CMUV2AJGEVJH5D2XR76SDS \ / AMOS7 \ YOURUM ::
#\[7]N2RTSYJDXLS52VWJKW74PXTX6XGD7YXZUBX75B6NBSQDCBERFQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
