# task: alternate per-zenka tree-grouped view of the v7 console

## relation to STDIO-RELAY-FOLD-APPLICATION

implements "worked usage example B — alternate tree-grouped view of
v7 console" from `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`.
depends on `v7-stdout-foldable-relay.md` for per-zenka stream
addresses, and on the three generic primitive tasks for foldable
recursive rendering. demonstrates branch-as-complete-tree concretely:
each per-zenka group is a complete tree node folding/unfolding under
the same primitives as everything else.

## context

design docs:
- `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`
- `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`

existing fragments:
- `src/v7.handler.process_output_line` already maintains
  per-zenka `instance_id → zenka_name` mapping in
  `v7.zenka.instance` / `v7.zenka.setup` — the grouping data is
  already extracted; this task only adds a renderer over it
- ascii-frame idiom `.:[ ]:.` per
  [[topic-frame-idiom-convergence]] — used for fold handles

## signatures note

no `#,,..` stubs. no whitelist edits. lowercase comments,
`[ word ]`, `$ARG`.

## scope

a second renderer for `v7.console`, addressed as
`v7.console.view.by-zenka`. binding either address into the v7
process's console slot via `base.slot.bind_content` switches the view.
no second store, no second buffer — one stream, two renderings.

### addresses

- `v7.console.view.by-zenka`            — the grouped view root
- `v7.console.view.by-zenka.<zenka_name>` — per-zenka sub-tree
- `v7.console.view.by-zenka.<zenka_name>.line.<b32>` — addressable
  individual line within the group [ reuse the per-zenka stdout
  line addressing from `v7-stdout-foldable-relay.md` ]

## modules to implement

### v7.console.view.by-zenka.children

```perl
## [:< ##
# name  = v7.console.view.by-zenka.children
# descr = enumerate per-zenka sub-tree children with priority + summaries
# param = { since_b32? }
```

returns an ordered list of `{ zenka_name, priority, summary }`
entries where:
- `priority` = recent-activity score [ inverse seconds-since-last-line
  for that zenka × log10(lines-in-window+1) ]
- `summary` = `"<N> lines, last <Δ>s ago"` or `"idle"` if no recent
  activity

used by `base.ui.layout.fit` to decide which groups unfold inline and
which fold into the `[ +N more ]` handle for shallow tty budgets.

### v7.console.view.by-zenka.render_group

```perl
## [:< ##
# name  = v7.console.view.by-zenka.render_group
# descr = render one per-zenka sub-tree against a sub-budget
# param = { zenka_name, slot_budget, since_b32? }
```

- streams that zenka's lines via `v7.stdout.line.iter`
  [ apply_filters = TRUE so any per-zenka filter still applies ]
- wraps in a one-line group header `.:[ zenka ]:[ <zenka_name> ]:[ <summary> ]:.`
- recursively allows further structural folding [ branch-as-complete-
  tree: a "long burst" of lines may itself fold into a `[ +M more ]`
  handle whose unfold paginates ]

### v7.console.view.by-zenka.render

```perl
## [:< ##
# name  = v7.console.view.by-zenka.render
# descr = render the by-zenka view against a slot_budget
# param = { slot_budget }
```

driver:
1. call `v7.console.view.by-zenka.children` → ordered list
2. delegate to `base.ui.render.tree` with this address; tree-render
   uses `base.ui.estimate.cost` and `base.ui.layout.fit` against the
   children list to decide which groups unfold inline vs fold into
   the trailing `[ +N more ]` handle
3. each unfolded group calls `v7.console.view.by-zenka.render_group`
   against its sub-budget

### v7.console.view.by-zenka.cmd.ui-show

```perl
## [:< ##
# name  = v7.console.view.by-zenka.cmd.ui-show
```

top-level entry; resolves tty budget, calls `…render`, frames in the
ascii-frame idiom if a frame template is registered.

### v7.console.cmd.swap-view

```perl
## [:< ##
# name  = v7.console.cmd.swap-view
# descr = swap the v7 console slot's bound view address
# param = { view_address }
```

- looks up the v7 process's own console slot address from
  `v7.console.view.default.slot` [ initialised when the v7 console
  starts ]
- calls `base.slot.bind_content slot_address=<that> content_address=<view_address>`
- triggers `base.slot.refresh` against the slot

this is the *entire* one-key view-switch implementation: a content-
address rebind. zero re-paint outside the slot, zero state churn.

### default-view slot registration

on v7 startup, register the v7 console's own terminal output slot
[ stable name `v7.console.default.slot` ] via `base.slot.register`
and bind it to `v7.console` initially. this makes the slot a real
addressable thing the swap operation can target.

## hotkey wiring

per the philosophy doc, a globally-reserved hotkey unfolds the
nearest enclosing menu node. when focus is the v7 console:

- a dedicated view-cycle key [ separate from the menu key ] calls
  `v7.console.cmd.swap-view` cycling through registered view
  addresses on `v7.console.view.*`
- the cycle list is the *namespace itself* — discovered by
  enumerating children of `v7.console.view`, not a hardcoded
  registry. adding a new view at `v7.console.view.<name>` makes it
  available to the cycle automatically [ branch-as-complete-tree in
  action ]

actual keystroke binding is a follow-on UX pass; the address-level
machinery is what this task ships.

## acceptance

- with three zenki actively logging, `p7c v7.console.view.by-zenka.cmd.ui-show`
  renders three foldable group headers, the most-recent group's
  lines unfolded inline, less-active groups folded into handles.
- folding one group via `base.ui.fold` against its
  `v7.console.view.by-zenka.<name>` address removes its inline lines
  from the view but leaves its header in place; unfolding restores
  the lines without re-fetching from the store [ store is the source
  of truth; render-cache invalidates per
  `base.ui.render.tree.invalidate` ].
- `p7c v7.console.cmd.swap-view view_address=v7.console.view.by-zenka`
  changes the v7 console output to the grouped form; swap-view back
  to `v7.console` restores the default time-ordered view.
- both views see new lines arrive: same store, two render walks.
- shrinking the tty re-fits: groups with low priority auto-fold to
  fit the new budget without dropping any lines from the store.

## non-goals

- no separate per-zenka log file — store stays unified.
- no zenka grouping by *anything other than zenka_name* in this
  task — by-log-level, by-pattern-tag, etc. are follow-on views in
  the same `v7.console.view.*` slot namespace.
- no animation on view swap.
- no priority-weight tuning UX — heuristic is fixed for v1.

## harmony checks

```
harmony v7.console.view.by-zenka.children
harmony v7.console.view.by-zenka.render_group
harmony v7.console.view.by-zenka.render
harmony v7.console.view.by-zenka.cmd.ui-show
harmony v7.console.cmd.swap-view
```

#,,,,,,.,,.,.,,,.,,,,,,..,,..,,,,,,..,.,.,,,.,..,,...,...,...,,,.,,.,,,..,..,,
#627LJ7AWBVBEDFA4PKYWNKMF6DAKCIFXWTGD2IQXEDU4OEUVFUNJEZWEG5DYOGVOAH52ND72PTZGI
#\\\|DXH6DGCPBS4ZY4YPIZMYTAWPRN4DCZRVNEDRO4R3PQIFAEUC6AU \ / AMOS7 \ YOURUM ::
#\[7]A3N2TIDVZK3P235JE6PW2D5FSZXVE6L7MWBRQVS2BDUI6IBQDWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
