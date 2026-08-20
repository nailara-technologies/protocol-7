# task: extract 3 more inline helper subs (download/graphics-matrix/web-browser)

## relation

continues the inline-sub cleanup series [ prior landings: `eff1ee210`,
`4c5d518b9`, `119eed733`, plus the two just-completed batches for
weather/language and download/letsencr/source/space/work ]. found via
`ncode s src '^sub [a-z][A\w_]+ '` [ non-underscore-prefixed inline subs ].

use `data/yaml/context-templates/extract-inline-subs.yaml` as the
workflow reference [ verbatim copy, one module at a time, P7 module
format, `<[...]>->(...)` call syntax, `$ARG`/`@ARG` not `$_`/`@_`,
no `.cmd.` in extracted util namespaces ].

## scope : 3 inline subs across 3 modules

### 1. `src/download.init_code` line 20 : `sub read_hosts {...}`
extract to `src/download.util.read_hosts`

this is a **package method** on `Download::UserAgent`, called as
`<download.obj.ua>->read_hosts()` at line 58 of the same file [ do
**not** change that call site - method dispatch finds the symbol table
entry installed below ].

**critical**: the sub body reads and writes the package global
`$etc_hosts` [ declared `our $etc_hosts = Config::Hosts->new();` at
line 18 of `download.init_code` ]. the extracted module MUST start
with:

```perl
package Download::UserAgent;

our $etc_hosts;
```

[ this is the exact fix that was required for the sibling
`download.util.resolve` extraction in the previous batch - without
`our $etc_hosts;` in the new file, `strict` throws "Global symbol
$etc_hosts requires explicit package name" and the `download` zenka
enters an endless reload-crash loop. this is not hypothetical - it
happened last batch. do not skip this line. ]

the new module also needs `use English;` [ for `$EVAL_ERROR`, `$ARG` ]
and `<[base.perlmod.runtime_use]>->('IO::Scalar');` [ for
`IO::Scalar->new` ] - copy these requires/uses into the new module as
needed, they may already be satisfied by load order but include them
defensively if the body uses the symbols directly.

after creating the new module, replace the `sub read_hosts {...}`
declaration [ lines 20-39 ] in `download.init_code` with a
wrapper-closure, following the exact pattern already used for
`_resolve` immediately below it [ lines 41-46 ]:

```perl
{
    no warnings qw| redefine |;
    *read_hosts = sub {
        return <[download.util.read_hosts]>->(@ARG);
    };
}
```

[ both wrapper blocks can be merged into one `{ no warnings qw|
redefine |; ... }` block with both `*_resolve = ...` and `*read_hosts
= ...` assignments, or kept as two separate blocks - either is fine,
prefer merging them into the existing block for tidiness. ]

### 2. `src/graphics-matrix.cmd.cell` line 148 : `sub cell_output {...}`
extract to `src/graphics-matrix.cell.util.cell_output`

standalone formatter, `my $cell = shift;`, no package globals, no
closures - straightforward extraction. called at 3 call sites in the
same file [ lines 16, 30, 76 ] - replace each `cell_output($cell)`
with `<[graphics-matrix.cell.util.cell_output]>->($cell)`. remove the
`sub cell_output {...}` declaration and the `## cell output
formatter ##` comment above it.

### 3. `src/web-browser.handler.fade_in_view` line 47 : `sub incr {...}`
extract to `src/web-browser.view.util.fade_increment`

standalone math helper, `my $dt = shift;`, uses
`<web-browser.fg_opacity>` [ P7 data accessor, fine to use directly in
the new module ] and `<[base.calc_gauss]>->(...)`. called once at line
15: `<web-browser.fg_opacity> += incr($delta_t);` - replace with
`<web-browser.fg_opacity> += <[web-browser.view.util.fade_increment]>
->($delta_t);`. remove the `sub incr {...}` declaration.

## registration

after all 3 new modules are created and source files updated:
- add all 3 new module names to `src/base.list.subroutines`
  [ group near related `download.*` / `graphics-matrix.*` /
  `web-browser.*` entries ]
- regenerate `data/md/documentation/module-dependency-graph.asc` via
  `./bin/dev/dep-graph`

## verification

- `ncode s src:download '^sub [a-z]'`,
  `ncode s src:graphics-matrix '^sub [a-z]'`,
  `ncode s src:web-browser '^sub [a-z]'` no longer match these 3 subs
  [ other unrelated inline subs in those namespaces, if any, are out
  of scope - only remove these 3 ]
- all 6 modules [ 3 edited sources + 3 new ] pass `perl -c`
  [ note: `download.init_code` may pre-exist as a `perl -c` failure due
  to `<[...]>`/`<...>` P7 macro syntax - check via `git show
  HEAD:src/download.init_code | perl -c` first; if it already
  failed before your edits, it failing after your edits too is fine as
  long as the failure reason is unchanged ]
- `p7c download.reload`, `p7c graphics-matrix.reload` complete with
  `reload source [success]` and `reinit source [success]`
  [ check `cfg/zenki/*/start` for which zenki load
  `web-browser.*` - it may not be a separate zenka / may not be
  running; if so just confirm `perl -c` passes and skip the reload
  step for it ]
- the combined v7 console output is tailable at
  `/dev/shm/.7/STDOUT/NIW7OAQ` if you need to watch reload output live

## non-goals

- no behavior change - pure refactor, same logic moved to sibling files
- do not touch `src/reenc-msg.*`, `src/remote-cam.*`,
  `src/storchencam.*`, `src/workspace-transfer.*` - those are
  a separate future batch
- do not touch `src/base.protocol-7.command.send.local` or any
  route-send related work - unrelated in-progress work by someone else
- do not try to start any zenka that is not already running

## signatures note

no `#,,..` stubs. do NOT run update-signatures. lowercase comments,
`[ word ]` annotations, `$ARG`/`@ARG` not `$_`/`@_`, one-sub-per-file
[ no inline `sub {}` helpers ]. keep `# descr =` lines under 55 chars.

#,,.,,.,,,,,,,.,.,.,,,.,,,.,,,,,.,,,,,.,.,.,.,.,.,...,...,...,,.,,,,.,,.,,,,,,
</content>

#,,.,,..,,..,,,..,..,,,,,,,.,,,,,,,,,,,,,,.,,,..,,...,..,,,,,,.,.,.,.,,.,,,,,,
#DHZIUNIVHIC6OBVUT3TQDOUBEHALYQX6K24U7QNHA5VE6GMBVQRR67MR2AVVIP6OGNGVIJPXSRYWO
#\\\|6VEEYK33NPTTO6BKVYPSSP467ZJLADLD6VCR62NBCCW2EWJ5MBT \ / AMOS7 \ YOURUM ::
#\[7]75A5CPB547EPXBNKC4U3JNV2OEGBC4USYH7GND7M4REZJI7NW6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
