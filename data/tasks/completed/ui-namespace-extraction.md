# task: extract base.ui.* into its own ui.* namespace

## relation

`console-foldable-render-baseline` (`2560c5499`) and the `base.cmd.ui-show`
follow-up (`1cf36cb34`) landed the fold/unfold render stack under
`base.ui.*`:

```
base.ui.fold
base.ui.unfold
base.ui.render.fallback
base.ui.render.tree
base.ui.render.tree.invalidate
base.ui.summarise
base.ui.layout.fit
base.ui.budget.tty
base.ui.estimate.cost
base.cmd.ui-show
data/yaml/ascii-frames/ui-show-fallback-header.yaml
```

`base.ui.render.tree` and `base.cmd.ui-show` call into `ascii.frame.*`
(`ascii.frame.render`, `ascii.frame.compose`, `ascii.frame.load` —
a separate, opt-in namespace, NOT part of `base.*`). taeki's concern
(2026-06-10/11): `base.*` is supposed to be the dependency-light layer
loaded by essentially every zenka, so having `base.ui.*` transitively
depend on `ascii.frame.*` quietly couples every `base.*`-loading zenka
to ascii rendering, even zenki that never use it.

## scope

### rename `base.ui.*` -> `ui.*`

drop the `base.` prefix entirely (do NOT introduce a `ui.base.*`
sub-namespace — there is nothing for it to be "base" relative to once
it's its own top-level namespace):

```
base.ui.fold                  -> ui.fold
base.ui.unfold                -> ui.unfold
base.ui.render.fallback        -> ui.render.fallback
base.ui.render.tree            -> ui.render.tree
base.ui.render.tree.invalidate -> ui.render.tree.invalidate
base.ui.summarise               -> ui.summarise
base.ui.layout.fit              -> ui.layout.fit
base.ui.budget.tty              -> ui.budget.tty
base.ui.estimate.cost           -> ui.estimate.cost
base.cmd.ui-show                -> ui.cmd.ui-show   [ see below ]
```

use `git mv`. update `# name = ...` headers and all internal
`<[base.ui....]>` call sites (`grep -rn 'base\.ui\.' src/` to find
all of them — includes cross-references between these modules
themselves, plus `src/base.slot.*`, see below).

### `base.cmd.ui-show` placement — DECIDE, don't assume

`base.cmd.ui-show` is the thing the loader auto-registers under
`$data{'base'}{'cmd'}{'ui-show'}` via the `\.(cmd|console)\.(.+)$`
pattern (see `bin/Protocol-7` ~line 1519) — that auto-registration is
keyed on the **filename's `cmd.` segment**, not its leading namespace,
so `ui.cmd.ui-show` would register the same way. confirm this before
moving it; if moving it breaks the auto-registration contract that
`console-fold-primitive-ui-show-fallback.md` / `1cf36cb34` just
established, leave `base.cmd.ui-show` where it is (it's a thin shell —
its `ascii.frame.render` call is wrapped in `eval` and degrades to
plain `base.ui.unfold`/`ui.unfold` output if `ascii.frame.*` isn't
loaded, so the coupling concern is weaker for this one file than for
`base.ui.render.tree`).

### `base.slot.*` — open question, do not move without confirming

`console-stdio-slot-addressing` (`e5c6692c2`) added 8 `base.slot.*`
modules (`register/resolve/bind_content/init_code/move/fold/unfold/
refresh`) which call into `base.ui.fold`/`base.ui.unfold` (see
`base.slot.fold`, `base.slot.move`, `base.slot.refresh`). if
`base.ui.*` moves to `ui.*`, `base.slot.*` becomes a `base.*` module
that depends on `ui.*` — the same category of coupling this task is
trying to remove, just one level removed.

options (pick one, document the reasoning in the completion report):
1. leave `base.slot.*` in `base.*`, update its `<[base.ui....]>` calls
   to `<[ui....]>` — accepts a thinner `base.* -> ui.*` dependency for
   the slot-addressing layer specifically (slot registration/resolution
   itself has no ascii dependency; only the fold/unfold calls do)
2. also rename `base.slot.*` -> `ui.slot.*`, moving slot-addressing
   into the new namespace wholesale

recommendation (non-binding): option 1. slot addressing is generic
addressing infrastructure (register/resolve/move), independent of
rendering; only `fold`/`unfold`/`refresh` touch `ui.*`. splitting slot
across two namespaces (some in `base.*`, some in `ui.*`) to chase
purity would be worse than one `<[ui.fold]>` call site.

### `<zenka>.ui.*` per-zenka extension pattern [ document only, no impl ]

add a short note to `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` (or
a new doc if that one is the wrong home — check) describing the
intended pattern for zenka-specific UI:

- a zenka may define `<namespace>.ui.*` modules (e.g.
  `cred-mesh.ui.render.tree`) that call `ui.*` primitives
  directly (`<[ui.fold]>`, `<[ui.unfold]>`, etc — no `base.` prefix,
  no `swap_subs` aliasing needed, since `ui.*` was never under `base.*`)
- resolution order for `base.ui.unfold`/`ui.unfold` (whatever it's
  called post-rename) already checks `<address>.ui.render.default` /
  `<address>.cmd.ui-show` before falling back — confirm the renamed
  module's resolution-order logic still reads `<address>.ui.*` (zenka
  namespace) vs `ui.*` (shared primitives) correctly; these are
  different things and must not collide
- this is the same override relationship `<namespace>.cmd.ui-show`
  already has with `base.cmd.ui-show` / `ui.cmd.ui-show`

### `modules.load` / whitelist updates

`grep -rl base.ui. cfg/zenki/*/subroutine.white-list` (104
files as of 2026-06-11) — these entries were added by
`console-foldable-render-baseline`'s kimi run as part of the
`subroutine.white-list` deferred-compile mechanism, NOT
`modules.load`. update each matching whitelist entry from
`base.ui.*`/`base.cmd.ui-show` to the new `ui.*` names. `base.*` is
compiled for every zenka regardless of whitelist (loader scans
`src/` unconditionally — see `bin/Protocol-7`); confirm whether
`ui.*` modules need the same blanket compilation or whether they should
ONLY be compiled for zenki that reference them (this is the actual
"gradual loading" taeki asked about — find where the loader decides
which top-level namespaces get compiled per-zenka, likely tied to
`modules.load` in each zenka's `start` file, and report what you find
before assuming either way).

## acceptance

- `grep -rn 'base\.ui\.' src/` returns nothing (all renamed/updated)
- `harmony ui.fold ui.unfold ui.render.fallback ui.render.tree
  ui.render.tree.invalidate ui.summarise ui.layout.fit ui.budget.tty
  ui.estimate.cost` all pass
- `p7c <some-zenka>.cmd.ui-show` (whichever zenka was used to verify
  `1cf36cb34`) still produces the same output as before the rename
- `base.slot.*` modules still compile and `harmony base.slot.fold
  base.slot.unfold base.slot.move base.slot.refresh` pass, using
  whichever option (1 or 2 above) was chosen
- report which top-level-namespace-compilation question (last bullet
  of "modules.load / whitelist updates") resolved to, and whether any
  follow-up task is needed for "gradual loading into zenki that can use
  it" — that may be its own task depending on what's found

## non-goals

- no behavioral change to fold/unfold/render logic itself — pure
  rename + call-site update + namespace placement decisions
- no change to `ascii.frame.*` itself
- do not implement `<zenka>.ui.*` modules for any specific zenka in
  this task — design-doc note only

## signatures note

no `#,,..` stubs. do NOT run update-signatures (pre-commit hook
re-signs on commit). lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

## harmony checks

```
harmony ui.fold ui.unfold ui.render.fallback ui.render.tree
harmony ui.render.tree.invalidate ui.summarise ui.layout.fit
harmony ui.budget.tty ui.estimate.cost
harmony base.slot.fold base.slot.unfold base.slot.move base.slot.refresh
```

#,,..,...,..,,.,.,.,.,,,.,,,,,.,.,,,.,,..,,,.,..,,...,...,,..,..,,..,,,,,,,.,,
#USVCOTZIIN7CXL3C4H57JQKDITLKV7C6TV4345GIZQAM54ENHXKDPE4SJV2GVFISSX47B55U5LATS
#\\\|MOCRTI3XI3SALCRUP3BA256ECTVCV2YRNEZ45LMFPHSCZIEFEUB \ / AMOS7 \ YOURUM ::
#\[7]3NETSSYPBDEF4J5IL42VOANWQJSP2J5TDBNVEB5HEX5LRLPD24DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
