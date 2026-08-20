# code review : plugin reload flow

## context

the plugin system provides partial code reloading for optional features via
`reload plugins`. plugins are `plugin.*`-prefixed modules loaded alongside
regular modules but tracked separately so they can be reloaded independently.

this subsystem has not received much attention in recent years and likely has
regressions in flow logic. a recent test confirmed that `reload plugins` and
`reload` [ all ] do not install a rollback watcher after loading — indicating
nothing is actually being loaded.

## starting point

run the following to get a full cross-reference of plugin mentions :

```
ncode -ai-friendly search all plugins
```

total mentions are around 45 lines — a manageable scope. early observations
from running this :

- `bin/Protocol-7` line 1328 initializes `$code{'plugins.status'}->{$ARG}->{'load_errors'}`
  during the compile loop — this is an entry in the **code hash** `%code`
- `bin/Protocol-7` line 1525 increments `$data{'plugins'}{'status'}{$code_name}{'load_errors'}`
  on compile failure — this is the **data hash** `%data`
- `base.reload_plugins` line 16 reads `<plugins.status>` = `$data{'plugins'}{'status'}`
  to get the list of plugins to reload

these three paths may not be in sync — the registry `base.reload_plugins` reads
from (`%data`) may not be populated by the path that tracks successful loads,
which could explain why `reload plugins` loads nothing.

## key files

- `modules/base.load_plugins`    — loads named plugins, filters for `plugin.*` prefix
- `modules/base.reload_plugins`  — purges plugin callbacks, reloads from `<plugins.status>`
- `modules/base.cmd.reload`      — calls `base.reload_plugins` in the `plugins` block
- `modules/plugin.*`             — actual plugin modules [ auth, web, image-resize, etc. ]
- `cfg/zenki/*/start`  — start files use `[load_plugins:<plugins.load>]`

## known issues and questions to investigate

### `<plugins.status>` registry
`base.reload_plugins` reads `<[base.sort]>->(<plugins.status>)` as its source
of plugin names. if this data key is empty or never populated, nothing loads.

**question** : where does `<plugins.status>` get written? trace whether
`[load_plugins:...]` in start files populates it, or whether that step was
lost at some point.

### `base.load_plugins` return value
on no plugins loaded it returns `TRUE` rather than a failure indicator.
`base.cmd.reload` then reports `[ success ]` even when nothing was loaded.

### todo comment in `base.reload_plugins`
```
# todo = implement unload mechanism \ investigate callback order + registry ?
```
this is long-standing and unresolved — note any concrete findings.

### callback purge scope
`base.reload_plugins` purges `plugin.*` entries from `callbacks.end_code`
but it is unclear whether all callback registration points use a `plugin.*`
prefix consistently — inconsistency here would silently skip cleanup.

## expected output

produce a structured findings document in this directory :
`data/md/code-reviews/plugin-reload-findings.md`

cover :
- current flow traced end-to-end [ load + reload paths ]
- where the flow breaks or diverges from expected behavior
- suspected regression points with file and line references
- concrete recommendations for each finding

#,,,.,,..,,,.,...,.,.,,,,,.,,,.,.,.,,,,,.,..,,..,,...,...,...,,.,,,.,,..,,,,,,
#73UQXIIO5PE5UGFJX3UIF2DZ5XSN53LZNUZXR74E7MWLVGL2BVBKMVEFMRA5PEJ2HHO6TNWK63MDQ
#\\\|FMVXAHJHQYLLU33QL7UFODDO4QPCHUPCLNT2CHDKS555TOQUSX3 \ / AMOS7 \ YOURUM ::
#\[7]3NRNW2RI2QXTTEBKW4EJOTII7DSOTCQ5HJOUBF7OGDEBOB7EQCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
