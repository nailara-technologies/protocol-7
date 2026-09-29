# task: pattern-matching log filter overlay for the v7 console

## relation to STDIO-RELAY-FOLD-APPLICATION

implements "worked usage example A — pattern-matching filter overlay
on the v7 console" from
`data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`. depends on
`v7-stdout-foldable-relay.md` for the filter primitives and on the
three generic primitive tasks for fold/unfold + slot addressing.
demonstrates fold-back-as-presence concretely: the unfiltered stream
remains an addressable folded sibling at all times.

## context

design docs:
- `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`
- `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`
- `data/md/design/LAYER-MATRIX-STATE-TRANSFER.md` — the reversible
  layer-diff substrate a filter overlay rides

existing fragments to integrate with:
- `src/v7-zenki.init_zenka_output_patterns`,
  `src/v7-zenki.load_zenka_output_patterns` — proven regex compilation
  + per-zenka match dispatch idioms; reuse, do not re-implement
- `src/v7-zenki.handler.output_zenka_stdout` — adjusted by
  `v7-stdout-foldable-relay.md` task; this task assumes those changes
  are present

## signatures note

no `#,,..` stubs. no `update-signatures`. no whitelist edits.
lowercase comments, `[ word ]`, `$ARG`.

## scope

a **v7-console-wide** filter chain that overlays the aggregated
console view [ across all zenki ], plus the per-zenka filter chain
[ which `v7-stdout-foldable-relay.md` already covers ]. this task is
mostly about the *console-aggregate* address and its overlay.

### addresses

- `v7-zenki.console`              — aggregate-all-zenki stream [ default view ]
- `v7-zenki.console.unfiltered`   — alias to the raw underlying address,
  guaranteed-filterless for the always-available "see everything"
  fallback
- `v7-zenki.console.filter.<name>` — registered filter nodes
- `v7-zenki.console.view.default` — default rendered view's address [ what
  binds into the v7 process's own terminal slot ]

## modules to implement

### v7-zenki.console.filter.add

```perl
## [:< ##
# name  = v7-zenki.console.filter.add
# descr = register a console-aggregate filter on v7-zenki.console
# param = { name, re, mode = 'keep' | 'drop' }
```

- compiles `re` once [ reuse `v7-zenki.init_zenka_output_patterns`'s
  compilation idiom ]
- stores under `<v7-zenki.console.filter>{<name>} = { re, mode, added_b32 }`
- invalidates `v7-zenki.console.view.*`
- returns the filter's full address

### v7-zenki.console.filter.remove

```perl
## [:< ##
# name  = v7-zenki.console.filter.remove
# descr = remove a console-aggregate filter
# param = { name }
```

idempotent.

### v7-zenki.console.filter.toggle

```perl
## [:< ##
# name  = v7-zenki.console.filter.toggle
# descr = fold/unfold a filter node — the one-keystroke gesture
# param = { name }
```

- if filter's *active* flag is set → set it false [ acts as fold ]
- else → set it true [ acts as unfold ]
- invalidates `v7-zenki.console.view.*`

the inactive-but-present state is the philosophy-doc-correct "folded"
state: the filter still exists at its address, the regex is still
compiled, only the apply step is skipped. zero-cost reactivation.

### v7-zenki.console.view.default.render

```perl
## [:< ##
# name  = v7-zenki.console.view.default.render
# descr = render the current v7-zenki.console view through the active filter chain
# param = { slot_budget, since_b32? }
```

- enumerates active filters under `<v7-zenki.console.filter>` in add-time
  order
- streams lines from the store layer [ via `v7-zenki.stdout.line.iter` over
  every zenka in `v7-zenki.zenka.setup`, merged by ntime ]
- applies the filter chain; keeps the matching subset
- emits via `base.ui.render.tree` against the budget; lines that
  don't fit fold into a trailing `[ +N more ]` handle resolving back
  to a paged unfold of the same address

### v7-zenki.console.filter.list

```perl
## [:< ##
# name  = v7-zenki.console.filter.list
# descr = list active and inactive filters with one-line summaries
# param = {}
```

returns a list rendered as foldable handles per
`console-fold-primitive.md` — each filter is a node, each is foldable,
each unfolds into `{ re, mode, added_b32, hit_count, last_hit_b32 }`.

### v7-zenki.console.cmd.ui-show

```perl
## [:< ##
# name  = v7-zenki.console.cmd.ui-show
```

composes:
1. one-line header indicating active-filter set [ "errors-only |
   no-debug" ] or "unfiltered" if none active
2. `v7-zenki.console.view.default.render` against the current tty budget
3. a footer hint line listing toggle addresses [ `v7-zenki.console.filter.
   toggle name=…` ] as foldable handles

## hotkey wiring

per `CONSOLE-FOLD-TREE-PHILOSOPHY.md`, the always-working menu hotkey
unfolds the *nearest enclosing menu node* of the focused element.
when focus is the v7 console:

- one keypress → unfold `v7-zenki.console.filter` as a foldable list
- selecting a filter name → toggles its active flag via
  `v7-zenki.console.filter.toggle`
- escape / repeat-fold → folds the filter list back

actual keystroke bindings are NOT in this task — the address-level
verbs and the bindings hook are. concrete bindings belong to a
follow-on UX pass.

## acceptance

- `p7c v7-zenki.console.filter.add name=errors-only re='\b(ERR|FATAL)\b' mode=keep`
  followed by `p7c v7-zenki.console.cmd.ui-show` renders only lines matching
  the regex.
- `p7c v7-zenki.console.filter.toggle name=errors-only` → next ui-show
  reverts to unfiltered; toggle again → filter back on. **filter
  persists across toggles** [ regex re-compiled exactly zero times ].
- `p7c v7-zenki.console.unfiltered` always shows the raw stream regardless
  of how many filters are active [ proves fold-back-as-presence ].
- with two filters active [ one keep, one drop ], the final rendered
  subset is correctly the chained application in add-time order.
- removing a filter that isn't there is a no-op, not an error.

## non-goals

- no per-zenka filter overlays in this task — covered by
  `v7-stdout-foldable-relay.md`'s `v7-zenki.stdout.filter.*`
- no decorations [ colour, highlighting matched substrings, etc. ] —
  separate concern, follow-on cosmetic task
- no persistence of filter sets across v7 restarts — restart re-adds
  the wanted filters; persistence is a downstream concern bound to
  the zero-travel migration thread
- no filter-composition language richer than keep/drop regex —
  expressly bounded; richer composition is a separate proposal

## harmony checks

```
harmony v7-zenki.console.filter.add
harmony v7-zenki.console.filter.remove
harmony v7-zenki.console.filter.toggle
harmony v7-zenki.console.filter.list
harmony v7-zenki.console.view.default.render
harmony v7-zenki.console.cmd.ui-show
```

#,,,.,.,,,..,,,,.,,,,,,,,,,,.,,.,,.,,,.,.,.,,,..,,...,...,.,,,,..,,,.,...,,,,,
#SOTNNTCWXCN37RYSR77ZZMZUUAQQESIDVTX6Z7EIELA243IWPGYYF5AI3O64WFHGPCBMFL3WMQ3ZK
#\\\|3FT6PGECYEYOVQJ5DXXXB2GCP6V4YXIE7APCVYVJDDULDLDDYSV \ / AMOS7 \ YOURUM ::
#\[7]S32ADQFLRP76PSEUDPGZID2J6M6VVIWG6H6V2UIZKX4YCZR2D4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
