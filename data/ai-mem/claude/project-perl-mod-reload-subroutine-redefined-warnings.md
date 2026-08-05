---
name: project-perl-mod-reload-subroutine-redefined-warnings
description: "cube's 'reload perl-mods' (base.cmd.reload:44, Module::Refresh->refresh) triggers Perl 'Subroutine X redefined' warnings for every sub in a reloaded .pm file (e.g. AMOS7.pm) -- Module::Refresh re-does the file into the existing symbol table with no undef step first. correct fix is undefining stale subs first, not suppressing the warning; mod-test zenka exists to chase this down but it isn't fixed yet"
metadata:
  type: project
---

Observed 2026-07-24 by the user live-testing `cube`'s `reload perl-mods`
after the `base` namespace format-code batch (unrelated to that batch's
content — same warning would fire on any reload of any `.pm` file,
regardless of what changed inside it):

```
:. cube    : [3050747] < reload perl-mods >
:. cube    : : warn : subroutine error_exit redefined
:. cube    : :.    .: [,../lib-path/pm/AMOS7.pm:58]
:. cube    : : warn : subroutine warn_err redefined
:. cube    : :.    .: [,../lib-path/pm/AMOS7.pm:102]
:. cube    : : warn : subroutine format_sprintf redefined
:. cube    : :.    .: [,../lib-path/pm/AMOS7.pm:159]
:. cube    : : warn : subroutine format_error redefined
:. cube    : :.    .: [,../lib-path/pm/AMOS7.pm:185]
```

**Root cause, exact call site**: `modules/base.cmd.reload:44` —
`eval { Module::Refresh->refresh };` — triggered by `reload perl-mods`
(and `reload all`). `Module::Refresh` (CPAN) works by re-`do`-ing any
`.pm` file whose mtime changed since last refresh; that's a straight
re-execution of the file's `sub NAME { ... }` statements into the
package's existing symbol table, with no undef step first. Perl warns
"Subroutine X redefined" whenever the same sub name is defined twice in
a package during one process's lifetime — so every single sub in a
refreshed file warns, every time, regardless of whether its content
actually changed. Also wired up in `base.perlmods.init_code`
(`base.perlmod.autoload('Module::Refresh')` +
`<base.perlmods.refresh> = Module::Refresh->new`) and explicitly
blacklisted from `mod-test`'s own dependency scan at
`mod-test.post_init:80`.

**User's diagnosis, agreed as correct**: the right fix is to explicitly
undefine (clear from the package symbol table) each sub belonging to the
reloaded module *before* re-executing it, not to just suppress the
warning. Suppressing would also hide the warning's legitimate use case —
catching an actually-stale sub left behind after a rename or removal,
which a normal reload cycle should be flagging.

**Not yet fixed in `base.cmd.reload`'s live path, but a candidate
reference pattern already exists**: `mod-test.perlmod.run_reload_test`
(the mechanism `mod-test` zenka runs its reload tests through) already
calls `$mod->unload_module($module_pm_path_rel)` *before*
`$mod->refresh_module($module_pm_path_rel)`, where `$mod` is the same
`<base.perlmods.refresh>` `Module::Refresh` instance — i.e. the
undefine-first approach the user identified as correct is already
implemented there, just not wired into `base.cmd.reload`'s plain
`Module::Refresh->refresh` call.

**Open nuance, not yet explained**: `run_reload_test`'s own warning
collector (`$collect_coderef`, line ~26) explicitly filters OUT any
`subroutine \S+ redefined` message before recording it — meaning even
with `unload_module()` called first, that warning apparently still needs
tolerating rather than being fully eliminated. Worth checking, when this
is picked up, whether `unload_module` genuinely clears the symbol table
and the filter is just defensive leftover noise-suppression, or whether
it has a real gap (e.g. `use constant`-defined subs, which live outside
the normal `sub NAME {}` declaration path, might not get cleared the same
way).

`mod-test` zenka exists specifically to chase this class of bug down (per
the user, verbatim: "the entire mod-test zenka exists for chasing that
down") — this note exists so the observation and the above two concrete
leads aren't lost for months before that work is picked up again, not to
duplicate tracking that already has a home.

**RESOLVED 2026-08-05 (commit 88b45e89f, kimi dispatch)**: `base.cmd.reload`'s
`perl-mods` branch now calls a new `base.perlmods.refresh_stale` instead of
raw `Module::Refresh->refresh` — it walks `%INC`, compares each module's
mtime against `Module::Refresh`'s own cache (so unchanged files are still
skipped, preserving the original no-forced-reload behavior), and for
genuinely stale files calls a new `base.perlmod.wipe_file_subs` to undefine
the file's previous subs first (via `%DB::sub` where populated, falling back
to a source scan for `use constant`-defined subs which never appear in
`%DB::sub`) before `Module::Refresh` re-execs it. Verified via a 3-pass
integration test against a scratch copy of `AMOS7.pm`: touch-only reload
(the original bug) now produces zero warnings, a real content change
reloads correctly with the new sub callable, and a no-change pass is a true
no-op with a stable mtime cache. The "open nuance" above (whether
unload-first alone eliminates the warning) is confirmed yes for both normal
subs and `use constant` subs, once the constant-fallback scan is included —
the dispatch's investigation found `%DB::sub` alone insufficient for
`use constant` since those never get %DB::sub entries.

## related

[[topic-format-code-bugs-fixed]] — unrelated content-correctness work;
this note exists only because the AMOS7 module batch from that work is
what the user happened to be live-testing when this surfaced.

#,,.,,..,,.,,,.,.,.,,,,,,,,..,...,...,.,.,,,.,.,.,...,...,.,.,.,.,..,,..,,.,,,
#DNLVQWAWANMLZBFU5NDIQWG7HLTQTXXMZPDVB2OVIJV6NB23WFA4EZY24VXERZXAHTJKKRGKGLE6I
#\\\|YGERJINPXVQMEC3YUZRV4WA4DRRY7C3ODOP2AKW2UHXAUOMHWTI \ / AMOS7 \ YOURUM ::
#\[7]S4F6LCYW74PA3Q6ZTOZDAV4FQE3DG2UU7AR7XANOOG6UPEWNH6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
