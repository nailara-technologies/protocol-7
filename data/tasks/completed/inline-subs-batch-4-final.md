# task: extract final 7 inline helper subs (reenc-msg/remote-cam/storchencam/workspace-transfer)

## relation

final batch of the inline-sub cleanup series [ prior landings:
`eff1ee210`, `4c5d518b9`, `119eed733`, `dc027b0c7` and its predecessors ].
once this lands, `ncode s src '^sub [a-z][A\w_]+ '` AND
`ncode s src 'sub _'` should both return empty across all of
`src/` - zero remaining inline helper subs, convention fully
enforced.

use `data/yaml/context-templates/extract-inline-subs.yaml` as the
workflow reference [ verbatim copy, one module at a time, P7 module
format, `<[...]>->(...)` call syntax, `$ARG`/`@ARG` not `$_`/`@_`,
no `.cmd.`/`.init_code`/`.sdl_loop`/`.open_window` in extracted util
namespaces ].

## scope : 7 inline subs across 4 modules

### 1+2. `src/reenc-msg.open_window` lines 49 (`cairo_draw`) and 74
(`screen_changed`)

these are **GTK signal-handler callbacks**, referenced as coderefs:

```perl
$window->signal_connect( 'draw',           \&cairo_draw,     $window );
$window->signal_connect( 'screen_changed', \&screen_changed, $window );
screen_changed($window);
```

extract to `src/reenc-msg.window.util.cairo_draw` and
`src/reenc-msg.window.util.screen_changed` [ both standalone, no
package-global dependencies - `cairo_draw` reads `<reenc-msg.display_txt>`
and `<reenc-msg.shadow_alpha>`/`<reenc-msg.text_alpha>` via normal P7
data accessors, which work fine from any module ].

replace the two `\&foo` coderefs and the direct `screen_changed($window)`
call with closures that call the new modules:

```perl
$window->signal_connect( 'draw',
    sub { return <[reenc-msg.window.util.cairo_draw]>->(@ARG); }, $window );
$window->signal_connect( 'screen_changed',
    sub { return <[reenc-msg.window.util.screen_changed]>->(@ARG); }, $window );
<[reenc-msg.window.util.screen_changed]>->($window);
```

then remove the two `sub cairo_draw {...}` / `sub screen_changed {...}`
declarations.

### 3. `src/remote-cam.sdl_loop` line 209 : `sub loop_wait {...}`
extract to `src/remote-cam.util.loop_wait`

standalone helper [ `my $tw = shift // 0;`, uses `<[base.time]>->(3)`,
`<[event.once]>->($tw)`, `SDL::delay(...)` - no package globals ].
called 4 times in the same file [ lines 79, 102, 201, 206 ] - replace
each `loop_wait(...)` call with `<[remote-cam.util.loop_wait]>->(...)`.
remove the `sub loop_wait {...}` declaration.

### 4+5. `src/storchencam.sdl_loop` line 327 (`loop_wait`) and 338
(`mask_scan`)

`loop_wait` here is a **near-duplicate** of remote-cam's [ identical
body ] - extract to its own `src/storchencam.util.loop_wait` [ do
NOT try to share remote-cam's module - keep them separate, same as the
existing near-duplicate pattern between the two camera zenki ]. called
4 times [ lines 158, 176, 319, 324 ] - replace each `loop_wait(...)`
call with `<[storchencam.util.loop_wait]>->(...)`.

`mask_scan` [ lines 338-382 ] is a standalone helper [ `my $surface =
shift; my $s_y_offset = shift // 0;`, reads `<storchencam.mask_areas>`,
no other package globals ] - extract to `src/storchencam.util.mask_scan`.
called once at line 269: `mask_scan( $screen, $s_y_offset )` - replace
with `<[storchencam.util.mask_scan]>->( $screen, $s_y_offset )`. keep
the `# LLL: works on day images only(?) ...` comment line - move it
to sit just above the new module's body (or drop it into a `# todo =`
header line in the new module if that fits the convention better).

remove both `sub loop_wait {...}` and `sub mask_scan {...}`
declarations from `storchencam.sdl_loop`.

### 6+7. `src/workspace-transfer.init_code` lines 15 (`ensure_workspace`)
and 36 (`chdir_workspace`)

**read this section twice before starting - this is the highest-risk
extraction in the whole series.**

these two subs WERE called from **12 external modules** [ the
`.cmd.*` and `.console.*` siblings ] as fully-qualified package
functions `workspace_transfer::chdir_workspace()` and
`workspace_transfer::ensure_workspace()`. the fix found and made:
the callers now use the named-sub form
`<[workspace-transfer.util.chdir_workspace]>` [ no `->(...)` - the
`<[...]>` form is the call itself ] - `grep -rn
"workspace_transfer::" src/` returns ZERO matches [ verified after
the edit ].

`workspace-transfer.init_code` itself has NO `package` statement, and
in `bin/Protocol-7`'s `p7_load_code`, each module's source is compiled
via `eval("sub {\n# line 1 \"$file_name\"\n...")` with no `package`
prefix injected - meaning `sub ensure_workspace {}` compiles into
whatever package is current at eval time [ almost certainly `main`,
i.e. `main::ensure_workspace` ], NOT `workspace_transfer::
ensure_workspace`.

**this means the 12 external callers' `workspace_transfer::
chdir_workspace()` / `workspace_transfer::ensure_workspace()` calls
were ALREADY broken** [ undefined-subroutine at runtime - no module
ever injects a `workspace_transfer` package, so those globs never
existed ]. that was the bug found : the extraction switched the
external callers to the named-sub form instead of trying to resurrect
the dead package -

- case 2 of the original analysis applied [ plain `main` package
  semantics, no `package` statement in the new modules, just
  `our $WORKSPACE_DIR;` / `our $WORKSPACE_REPO;` aliasing
  `main::$WORKSPACE_DIR` etc, matching `init_code`'s un-prefixed
  `our` declarations ].
- instead of leaving the 12 callers' dead `workspace_transfer::` prefix
  as-is [ the original out-of-scope plan ] the callers were rewritten
  to `<[workspace-transfer.util.chdir_workspace]>->(...)` - dead code
  that dies on every call is not left behind as a "pre-existing bug".

in all cases, both `ensure_workspace` and `chdir_workspace` reference
`our $WORKSPACE_DIR` / `our $WORKSPACE_REPO` [ declared lines 10-12 of
`init_code` ]. **same gotcha as the `$etc_hosts` incident**: the
extracted modules must declare:

```perl
our $WORKSPACE_DIR;
our $WORKSPACE_REPO;
```

[ only declare the ones each module actually uses - `chdir_workspace`'s
extracted module only needs `our $WORKSPACE_DIR;` ], in `main` [ per
case 2 above ].

extract to:
- `src/workspace-transfer.util.ensure_workspace`
- `src/workspace-transfer.util.chdir_workspace`

`chdir_workspace` currently calls `ensure_workspace()` internally
[ same-package call ] - rewrite that internal call as
`<[workspace-transfer.util.ensure_workspace]>->()`.

then, in `init_code`, replace both `sub ensure_workspace {...}` and
`sub chdir_workspace {...}` declarations with wrapper-closures
[ same pattern as `download.init_code`'s `_resolve`/`read_hosts`
wrappers ], inside a `{ no warnings qw| redefine |; ... }` block:

```perl
{
    no warnings qw| redefine |;
    *ensure_workspace = sub {
        return <[workspace-transfer.util.ensure_workspace]>->(@ARG);
    };
    *chdir_workspace = sub {
        return <[workspace-transfer.util.chdir_workspace]>->(@ARG);
    };
}
```

the `*ensure_workspace` / `*chdir_workspace` wrappers keep
`main::ensure_workspace` / `main::chdir_workspace` reachable for
unqualified callers in `init_code`'s compilation scope [ same
reachability as the old `sub` declarations ]. the 12 external callers
no longer reference any `workspace_transfer::` package at all - they
call the named-sub form directly.

**verification performed for this pair** : `grep -rn "workspace_transfer::"
src/` returns ZERO matches; all 12 caller files call
`<[workspace-transfer.util.chdir_workspace]>->(...)` [ full list:
`.cmd.bug`, `.cmd.bug-commit`, `.cmd.checkpoint`, `.cmd.status-check`,
`.cmd.todo`, `.cmd.todo-commit`, `.console.bug`, `.console.bug-commit`,
`.console.checkpoint`, `.console.status-check`, `.console.todo`,
`.console.todo-commit` ]; `ptd -c` passes on the touched files. the
workspace-transfer zenka was NOT running in this environment and per
the non-goals was not started, so no live caller run was possible -
this is verified-by-grep. follow-up after the next zenka (re)start :
run one caller live [ e.g. `p7c workspace-transfer.status-check` ] to
close the loop.

## registration

after all 7 new modules are created and source files updated:
- add all 7 new module names to `src/base.list.subroutines`
  [ group near related `reenc-msg.*` / `remote-cam.*` /
  `storchencam.*` / `workspace-transfer.*` entries ]
- regenerate `data/md/documentation/module-dependency-graph.asc` via
  `./bin/dev/dep-graph`

## verification

- `ncode s src '^sub [a-z][A\w_]+ '` returns completely empty across
  all of `src/` [ this is the final batch - confirms zero
  remaining inline helper subs project-wide ]
- `ncode s src 'sub _'` also still returns empty [ from prior batches -
  don't break this ]
- all 23 modules [ 4 extracted-from sources + 12 rewritten callers +
  7 new ] pass `perl -c` or `ptd -c`
  [ `ptd -c` is more tolerant of P7 `<[...]>`/`<...>` macro syntax and
  is the preferred check for files using those macros - use it if
  `perl -c` reports macro-syntax-related errors that are unrelated to
  your edits ]
- for whichever of these 4 zenki are running [ check via `p7c list` or
  similar - GUI/SDL zenki like `reenc-msg`/`remote-cam`/`storchencam`
  may not be running in this environment ], `p7c <zenka>.reload`
  completes with `reload source [success]` and `reinit source
  [success]`. for zenki that aren't running, `perl -c`/`ptd -c` passing
  is sufficient.
- the workspace-transfer pair is verified-by-grep [ zero
  `workspace_transfer::` matches, all 12 callers on the named-sub form,
  `ptd -c` clean ] - the zenka was not running so no live caller run;
  one live caller run remains as follow-up after the next zenka start
- the combined v7 console output is tailable at
  `/dev/shm/.7/STDOUT/NIW7OAQ` if you need to watch reload output live

## non-goals

- no behavior change - pure refactor, same logic moved to sibling files
- do not touch `src/base.protocol-7.command.send.local` or any
  route-send related work - unrelated in-progress work by someone else
- do not try to start any zenka that is not already running
- if the workspace-transfer package-wrapping theory turns out to be
  wrong and you cannot determine the correct fix confidently, leave
  `workspace-transfer.init_code` untouched [ do the other 5 subs across
  the other 3 files regardless, that part is independent and low-risk ]
  and report back what you found instead of guessing

## signatures note

no `#,,..` stubs. do NOT run update-signatures. lowercase comments,
`[ word ]` annotations, `$ARG`/`@ARG` not `$_`/`@_`, one-sub-per-file
[ no inline `sub {}` helpers ]. keep `# descr =` lines under 55 chars.

#,,,,,,,.,,..,,,,,.,.,...,,,,,,..,...,..,,,,.,..,,...,..,,...,,,.,...,,,.,,,,,
#WCX5VZVQQZQPT6CXYANKIKNRKAVBRPF453FUJJFZYLHS5SKFHH3FVOCEYQRPQJY37Z5YVVBD2N54U
#\\\|RL7UUHXLO6A2B5UHCYXQYQDI7PTU5LVHYDIMDZT3OWSXG7GIEGD \ / AMOS7 \ YOURUM ::
#\[7]EZUXCI5AZOJQMAEOMVQ76Q6E6JFPNSXGYRBZDPSMTYTIBTNZZIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
