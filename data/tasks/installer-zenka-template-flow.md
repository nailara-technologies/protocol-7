# task: greenfield installer zenka — template-driven guided install on the fold primitives

## relation to STDIO-RELAY-FOLD-APPLICATION

implements section "the installer zenka — greenfield template-driven
flow" of `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`. depends on
`configure-zenka-fallback-ui.md`'s decision-prompt machinery
[ `configure.cmd.decide` / `.cmd.pick` ] and on the three generic
primitive tasks. is the **second general-purpose zenka consumer**
proving the fold algebra carries flow-sequenced UX as cleanly as
free-form navigation.

if during implementation the configure/installer boundary turns out
artificial, fold this task back into the configure zenka — the policy
"sequence walk over template-tree" can live as a configure
sub-namespace `configure.flow.*` instead of a separate zenka. that's
not a failure mode, it's the expected branch-as-complete-tree
collapse. document the decision and proceed.

## context

design docs:
- `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`
- `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`

reference patterns:
- `configure-zenka-fallback-ui.md` [ sibling task ] — the
  decision-prompt and navigation primitives this task uses
- `src/set-up.*` — existing `create-profile` / `install-profile`
  / `export-config` / `fetch-zenka-config` surface; the installer
  composes these, does NOT duplicate them
- the existing `bin/p7-deps` profile-based dependency installer is
  the natural action target for an installer step that says
  "install profile X" — installer fires p7-deps via the standard
  callback mechanism

## signatures note

no `#,,..` stubs. no whitelist edits. lowercase comments,
`[ word ]`, `$ARG`. native-style on-disk format for templates
[ section-conf idiom; see [[topic-global-ui-menu-tree]] on the
native-format direction ].

## scope

an installer is **a configure flow over a template tree**. concretely
a template is a nested foldable address tree under
`installer.template.<name>` whose nodes are decision prompts in a
defined walk order. the installer's only job past hosting the tree
is to **walk** it [ next / back / skip / commit ] and to fire the
chosen actions [ e.g. delegate to `set-up.install-profile`,
`bin/p7-deps`, key generation ] at commit boundaries.

### address space

- `installer.template.<name>`           — root of one named template
- `installer.template.<name>.step.<n>.<id>` — ordered steps
- `installer.template.<name>.step.<n>.<id>.option.<name>` — choices
- `installer.run.<id>`                  — an active walk instance
- `installer.run.<id>.cursor`           — current step pointer
- `installer.run.<id>.picks`            — accumulated decisions
- `installer.run.<id>.log`              — per-step action results

## modules to implement

### installer.init_code

initialise:
- `<installer.template>` //= {}
- `<installer.run>` //= {}
- register a deferred callback on `system.callbacks.initialized` to
  load all `data/installer/templates/*.conf` via
  `base.load_section_conf` [ generalised arbitrary-depth nesting per
  [[topic-global-ui-menu-tree]]'s native-format direction-1 — if that
  generalisation isn't landed yet, fall back to the existing 3-level
  loader and document the constraint inline ]

return `TRUE`.

### installer.template.load

```perl
## [:< ##
# name  = installer.template.load
# descr = parse one template config file into the namespace
# param = { path }
```

reads file, populates `<installer.template>{<name>}` with the
ordered step tree. idempotent under re-load.

### installer.cmd.start

```perl
## [:< ##
# name  = installer.cmd.start
# descr = begin a walk of a named template
# param = { template, run_id? = auto }
```

- mints a `run_id` if not given [ ntime_b32 ]
- initialises `<installer.run>{<run_id>}` with cursor at step 0
- delegates the first step to `configure.cmd.decide` with a synthetic
  decision id `installer.<run_id>.step.<n>.<id>` and the template's
  option list
- registers a per-option `action_address` that fires
  `installer.cmd.advance run_id=<run_id> picked=<name>` so that
  picking an option in the decision UI walks the installer forward
- returns the run_id

### installer.cmd.advance

```perl
## [:< ##
# name  = installer.cmd.advance
# descr = record a pick, fire the step's action, move to next step
# param = { run_id, picked }
```

- records `<installer.run>{<run_id>}{picks}{<step_id>} = <picked>`
- if the picked option has a `do` action address, calls it with the
  full pick history as arg [ enables data flowing between steps ]
- records the action result under
  `<installer.run>{<run_id>}{log}{<step_id>}`
- advances cursor; if more steps remain, posts the next decision via
  `configure.cmd.decide`; else marks the run complete and posts a
  summary decision `commit / back-and-edit / discard`

### installer.cmd.back

```perl
## [:< ##
# name  = installer.cmd.back
# descr = step back one in a run, removing the most-recent pick
# param = { run_id }
```

idempotent at step 0. removes the pick, decrements the cursor,
re-posts the previous step's decision pre-populating the previous
pick as the highlighted option.

### installer.cmd.skip

```perl
## [:< ##
# name  = installer.cmd.skip
# descr = skip an optional step
# param = { run_id }
```

only valid for steps flagged `optional = TRUE` in the template;
otherwise rejected.

### installer.cmd.commit

```perl
## [:< ##
# name  = installer.cmd.commit
# descr = finalise a completed run — fire any deferred commit action
# param = { run_id }
```

template root may carry a `commit_address` that fires once at end —
e.g. `set-up.install-profile`, `v7.register_ondemand_zenki`, etc. on
success: archive the run under `installer.archive.<run_id>` and
remove from `<installer.run>`.

### installer.cmd.discard

```perl
## [:< ##
# name  = installer.cmd.discard
# descr = abandon a run, leaving no side effects [ unless a step
#         already fired an irreversible action, in which case log it ]
# param = { run_id }
```

### installer.ui.render.run

```perl
## [:< ##
# name  = installer.ui.render.run
# descr = render a run's progress as foldable tree
# param = { run_id, slot_budget }
```

- header line: template name, step `n/N`
- past steps: foldable handles `.:[ step ]:[ <id> ]:[ <picked> ]:.`
- current step: unfolded; question + options
- future steps: foldable handles with summaries

uses `base.ui.render.tree` for the actual emission; this module only
shapes the children list.

### installer.cmd.ui-show

dispatch:
- if there's at least one active run → render its current state via
  `installer.ui.render.run`
- else → list available templates as foldable children of
  `installer.template`

## template file format [ data/installer/templates/*.conf ]

```
.: template :.
  name = first-boot
  commit_address = installer.action.first_boot.finish
  description = guided first-boot setup

  - step
    : 1 :
      id = profile-choice
      question = which dependency profile?
      options = base, full
      options.base.summary = minimal dependencies
      options.base.do = installer.action.set_profile.base
      options.full.summary = all optional zenki
      options.full.do = installer.action.set_profile.full

    : 2 :
      id = identity-key
      question = generate identity key or use existing?
      options = generate, existing
      options.generate.do = installer.action.identity.generate
      options.existing.do = installer.action.identity.import
```

[ shown with 3-level section-conf depth as a worst-case bound; if
the generalised arbitrary-depth loader is available, deeper nesting
is preferred — see [[topic-global-ui-menu-tree]] direction-1 ]

template parsing is the entire shape contract — no extra DSL.

## acceptance

- `p7c installer.cmd.start template=first-boot` returns a run_id and
  posts the first step as a `configure.cmd.decide` decision visible
  in configure's ui-show.
- selecting an option via `configure.cmd.pick` advances the run;
  next step's decision appears.
- `p7c installer.cmd.back run_id=<id>` undoes one step, removes the
  pick, re-posts the previous decision.
- on the final step's commit-pick, the template's `commit_address`
  fires once, the run archives to `installer.archive.<run_id>`, and
  the run no longer shows in `installer.cmd.ui-show`'s active set.
- `harmony` clean on all installer modules.
- installer can be started on-demand only — no need for v7 to
  manage it as always-on [ flag `start.on-demand = 1` in
  start.cfg ].
- if configure/installer boundary is folded back during impl, the
  installer's `installer.*` namespace becomes `configure.flow.*`
  cleanly with no semantic loss — *verify by trying to do the
  collapse on paper before any actual collapse implementation*.

## non-goals

- no GUI [ purely console / fold-tree ]
- no per-step retry semantics — the picked option's action either
  succeeds or surfaces its error to the run log; the user navigates
  back to try again
- no parallel steps — single-cursor walk in v1
- no template versioning — templates are content-addressed by
  filename + ntime; versioning is downstream
- no remote template fetch — local files only; network sourcing
  follows the same path as the substrate work, not gated on it
- no installer-managed package install logic — delegates to
  `bin/p7-deps`, `set-up.install-profile`, etc.; installer is the
  *flow*, not the *plumbing*

## harmony checks

```
harmony installer.init_code
harmony installer.template.load
harmony installer.cmd.start
harmony installer.cmd.advance
harmony installer.cmd.back
harmony installer.cmd.skip
harmony installer.cmd.commit
harmony installer.cmd.discard
harmony installer.ui.render.run
harmony installer.cmd.ui-show
```

#,,,,,,.,,,,,,,,.,.,,,...,...,...,,.,,,.,,...,..,,...,...,.,.,,.,,...,.,,,..,,
#6IJBUJNDQMBR3AR6YYO4JR22QHDQR6H47VFW5JOUZO64WYMFF6ACFTWBOWPHTDBJCFDHQGTZSTYOO
#\\\|EMQ6UDV4N2IVPYJY7DKPG5ICM2EE5BOMGZD6PGPBEGOHNWU4DDE \ / AMOS7 \ YOURUM ::
#\[7]R6BO7SBBGE7DHS7XSC4HMFMEDI7US4OR2SHVMW2ZUPKMO7GTKMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
