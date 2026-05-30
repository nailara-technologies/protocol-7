## task: fix double plugin load during base.cmd.reload

### symptoms

`web.reload` (which calls `base.cmd.reload` with `arg=all`) loads `plugin.web`
twice per run:

1. during **reload source** stage — via `base.load_modules`
2. during **reload plugins** stage — via `base.reload_plugins`

observed in reload log:
```
< reload source code >
  . loading p7-source : base
  . loading p7-source : web
  ...
  . loading : plugin.web          ← first load
  . loading p7-source : jobsite.job
  ...
< reload plugins >
  . loading : plugin.web          ← second load (redundant)
```

the double load does not cause a functional error now (the inline sub that was
producing the 'redefined' warning has been extracted), but it is wasteful and
could cause redefinition warnings for any future inline subs or module-level
code with side effects.

---

### root cause hypothesis

in `base.cmd.reload` (modules/base.cmd.reload), the reload sequence for `arg=all`:

1. **reload source** (line 55–125):
   ```perl
   my @reload_modules = <[base.clear_p7_mods]>;
   ...
   my $load_success = <[base.load_modules]>->(@reload_modules);
   ```
   `base.clear_p7_mods` returns ALL currently loaded modules, which includes
   `plugin.*` modules. `base.load_modules` then loads them all — plugins included.

2. **reload plugins** (line 126–140):
   ```perl
   <[base.reload_plugins]>
   ```
   this loads all plugins again from the registry.

the fix should ensure plugins are loaded exactly once per reload cycle.

---

### investigation steps

1. read `modules/base.clear_p7_mods` to confirm it returns `plugin.*` entries
2. read `modules/base.load_modules` to confirm it loads plugin modules when
   they appear in its argument list
3. read `modules/base.reload_plugins` to understand its loading path
4. determine the correct fix — likely one of:
   - **option A**: filter `plugin.*` out of `@reload_modules` in `base.cmd.reload`
     before passing to `base.load_modules` (source reload skips plugins; plugins
     handled exclusively by `base.reload_plugins`)
   - **option B**: skip already-loaded plugins in `base.reload_plugins` if they
     were loaded during the source pass
   - **option C**: fix in `base.clear_p7_mods` or `base.load_modules` to exclude
     plugin modules from the source module set

   prefer option A if it is clean — it is the most explicit separation.

5. implement the chosen fix. keep it minimal; do not refactor surrounding code.

---

### prior context

a previous fix (commit 12CB2CAA, March 2026) resolved a related but distinct
issue: `base.load_plugins` was not writing loaded plugins into `<plugins.status>`
(data hash), so `base.reload_plugins` could not find them. that is resolved.
the current bug is that plugins are loaded by BOTH passes, not that plugins
fail to reload.

the file `data/md/code-reviews/plugin-reload-findings.md` has the prior
investigation notes.

---

## signatures note

this codebase uses AMOS7 data signatures at the end of each module file
(4-line footer starting with `#,,.,,,...`). do NOT manually write or edit
signature lines. existing signatures on modified files will be regenerated
by the signing system. do not add fake/stub signatures to new files.

## dispatch

#,,.,,.,,,..,,.,,,,..,..,,..,,.,,,..,,.,.,..,,..,,...,...,...,,,.,,,.,.,,,..,,
#P2BCSH74Q7Y2UIPZKI23WIIKSYVZZU7XXGFGWHWHD7P2KII77RC2SPEKBHKB5WHH7L5GG2S6XUPEG
#\\\|C4P6YY6TZGOV677M4VJRNNVSHW5OV2MLSOE6UROKS4BY2PY7M5L \ / AMOS7 \ YOURUM ::
#\[7]JAQRX5VHCHNPZOLOAUGTFIEVTQHVU3HXEKH5UE7BCMVPE6GYCUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
