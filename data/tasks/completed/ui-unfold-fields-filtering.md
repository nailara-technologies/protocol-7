# task: ui.unfold / ui.render.fallback — field-map driven, level-filtered

## relation

`data/md/design/UI-SHOW-SECURITY-LEVELS.md` step (2) of the
implementation queue. teaches the existing render path to walk a
declared field map instead of raw `%data`, and to drop any field whose
`level` exceeds the caller's effective security level.

depends on:
- [[ui-fields-fallback]] — produces the universal level-0 map used when
  a zenka has no `<namespace>.ui.fields` of its own. landed first; this
  task consumes it.
- [[ui-caller-security-level]] — resolves the caller's effective
  security level. this task's filter step calls into that resolver.
  if its sibling task lands first, use the real resolver; if not, gate
  on a temporary `<[ui.caller.security-level]>` call that returns `0`
  by default — the right shape, just a stub value — and replace the
  stub on integration.

read first:
- `data/md/design/UI-SHOW-SECURITY-LEVELS.md` (whole doc, especially
  "per-zenka interesting base values map" and the field-shape
  `{ value => sub|address, level => N }`)
- `src/ui.unfold` (current implementation — three-tier custom /
  specific-cmd / fallback dispatch; the fallback path is what this task
  changes)
- `src/ui.render.fallback` (current implementation — delegates to
  `<[ui.render.tree]>` over raw `%data`; this task replaces that with
  field-map iteration)
- `src/ui.render.tree` (kept as the renderer for individual field
  values, not for whole subtrees of `%data` anymore)
- `src/ui.fields.fallback` from [[ui-fields-fallback]] (the shape
  this task consumes)

## scope

### `src/ui.unfold`

current tier 3 [ fallback renderer ] passes `address` straight to
`<[ui.render.fallback]>` and leaks whatever is under
`$data{...address...}` verbatim. change tier 3 to:

1. resolve the field map for `address` — try `$code{"$address.ui.fields"}`
   first [ per-zenka declared map ]; if absent, fall back to
   `<[ui.fields.fallback]>->()` [ universal level-0 map ]
2. resolve the caller's effective level via
   `<[ui.caller.security-level]>->()` [ see [[ui-caller-security-level]];
   integers, default `0` ]
3. filter the field map to entries with `level <= caller_level`
4. pass the filtered map plus `slot_budget` to `<[ui.render.fallback]>`
   under a new key `fields` — `ui.render.fallback` becomes a map-driven
   renderer, not an address-driven one

tiers 1 [ custom renderer ] and 2 [ specific cmd.ui-show ] are
unchanged — zenki that opt into a fully custom renderer or a specific
ui-show command are trusted to do their own filtering. only the
generic fallback path needs this gate.

### `src/ui.render.fallback`

current implementation calls `<[ui.render.tree]>->({ address,
slot_budget })`. change to accept `{ address, fields, slot_budget }`:

- if `fields` is given [ the new path ], iterate the field map in a
  stable order [ sorted keys, or insertion order if the producer
  guarantees one — pick one and stick to it ], evaluating each
  entry's `value`:
  - `value` is a coderef -> call it [ wrapped in `eval` ], stringify the
    result; on exception, render an empty value, do not propagate
  - `value` is a string [ address ] -> resolve via the existing
    `<[ui.render.tree]>` for just that leaf, or a small leaf-only
    renderer if `ui.render.tree` is whole-subtree — check its contract
    before deciding
  - render each field as a labelled line [ `field-name: value` ], with
    line wrapping respecting `slot_budget.cols`
- if `fields` is absent [ legacy callers, if any remain after this
  task ] -> retain the existing `<[ui.render.tree]>` path as a
  deprecated tail. flag with a one-line `[ deprecated ]` comment, do
  not remove yet — separate cleanup task once all callers migrate.
- return the concatenated multi-line string [ scalar ], same shape as
  before; the SIZE-mode wrapping is still `ui.cmd.ui-show`'s job

### no changes to `ui.cmd.ui-show`

it already calls `<[ui.unfold]>` and treats the return as opaque
`{ mode, data }`. the filtering happens transparently underneath it.

## acceptance

- `perl -c src/ui.unfold src/ui.render.fallback` clean
- for a zenka with NO declared `<namespace>.ui.fields`,
  `ui.unfold->({ address => '<zenka>' })` returns a rendering composed
  only of `ui.fields.fallback` level-0 fields — no raw `%data` leakage
- for a zenka WITH a declared `<namespace>.ui.fields` containing a
  mix of level-0 and level-1 fields, a caller resolving to level 0
  sees only level-0 entries; a caller resolving to a level >= the
  highest declared level sees all entries
- a coderef `value` that throws is rendered as an empty value, not an
  exception bubbling out [ `eval`-wrapped ]
- no field in the filtered output exposes file contents — values are
  scalars produced by the field map, not subtrees of `%data`

## non-goals

- no changes to `ui.cmd.ui-show` itself — the filtering is internal to
  `ui.unfold` / `ui.render.fallback`
- no per-zenka `<namespace>.ui.fields` map authoring — that's step (5)
  of the design doc, deferred. this task only consumes whatever map is
  present, falling back to the universal one
- no caller identity resolution implementation — that's
  [[ui-caller-security-level]]. this task calls the resolver and
  trusts its answer
- do NOT add `*.ui-show` to `cube/access.zenki` — explicitly deferred
  to step (4) of the design doc, out of scope here
- no changes to tier 1 / tier 2 dispatch in `ui.unfold` — only the
  fallback tier is gated. trusted custom renderers stay trusted

## signatures note

no `#,,..` stubs. do NOT run update-signatures (pre-commit hook
re-signs on commit). lowercase comments, `[ word ]` annotations, `$ARG`
not `$_`. both modules already exist on disk — edit in place, do not
rewrite from scratch [ preserve the existing header comment block and
signature footer; the pre-commit hook will refresh the footer ].

## checks

```
perl -c src/ui.unfold src/ui.render.fallback
```

#,,.,,..,,..,,,,,,,,.,,,.,...,...,..,,,,.,,..,..,,...,...,..,,..,,,.,,.,,,.,.,
#FB3AWUBF6F766N5CIMB7NKGP3HBWYXE43E7ZMGOFGCYVCE7PPJUJWKVMPPQJYX55YOR26IXODZPF4
#\\\|DUNLKRT5CVE24O5UBFO2U6TVEFI62LLXUX7F52OC33MGZTCW7HY \ / AMOS7 \ YOURUM ::
#\[7]MXGG7AO5V6WDMWBRN3QKQN63TOKKR5OSXPLI6WKUEM6VN74ACIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
