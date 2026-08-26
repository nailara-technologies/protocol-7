# task: terminal-width-aware foldable render baseline

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

operationalises the "terminal-width-aware baseline, frames as
enhancement" point from `CONSOLE-FOLD-TREE-PHILOSOPHY.md` and the
matching paragraph in `topic-global-ui-menu-tree`. depends on
`console-fold-primitive.md` for the fold/unfold verbs and adds the
*policy layer* that decides what folds when, given a width/height
budget.

implements both first-principles together: fold-back-as-default-state
[ overflow folds rather than truncates ] and branch-node-as-complete-
tree [ overflow folds children of any depth without special-casing
"leaves" vs "branches" ].

## context

design doc [ read first ]:
- `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` — esp. the
  "terminal-width-aware baseline" section
- `console-fold-primitive.md` — this task depends on `base.ui.fold` /
  `base.ui.unfold` existing

related existing work:
- `topic-nshell-terminal-rendering` (memory) — terminal buffer
  conventions, overflow path, color reset
- `topic-frame-plugin-slots` (memory), `topic-frame-idiom-convergence`
- `src/base.parser.list` — existing width-aware column rendering
  patterns

## signatures note

do NOT add stub signatures. do NOT modify whitelists. lowercase
comments, `[ word ]`, `$ARG`.

## modules to implement

### base.ui.budget.tty

```perl
## [:< ##
# name  = base.ui.budget.tty
# descr = derive a slot budget from the current tty
# param = { reserve_rows? = 2 }
```

returns `{ cols => N, rows => M }` taken from the current terminal
size [ tput-equivalent or whatever the existing terminal modules use ],
minus a reserved bottom band for a prompt/status line.

### base.ui.layout.fit

```perl
## [:< ##
# name  = base.ui.layout.fit
# descr = decide which children unfold and which fold, for a budget
# param = { address, slot_budget, priority? }
```

returns an ordered list `[ { child_address, mode }, ... ]` where mode
is `unfold` or `fold`. algorithm:

1. enumerate children of `address` [ same mechanism as
   `base.ui.render.fallback` uses ]
2. compute each child's *unfolded cost* — call
   `<[base.ui.estimate.cost]>` (see below)
3. compute priority per child [ default: `recency * affinity` where
   recency = inverse seconds-since-state-change, affinity = boolean
   currently-focused multiplier ]
4. greedy fill: highest-priority children unfold until remaining
   budget < next child's unfolded cost; the rest fold
5. if any children were folded AND budget rows remain, ensure the
   trailing `[ +N more ]` handle fits; if not, fold one more
   highest-cost unfolded child until it does

### base.ui.estimate.cost

```perl
## [:< ##
# name  = base.ui.estimate.cost
# descr = cheap estimate of an address's rendered cost
# param = { address }
```

returns `{ cols => N, rows => M }`. cheap heuristics, NO actual
rendering:
- if `<address>.ui.cost` exists → call it
- else if address is a hash → `rows = min(5, child_count)`,
  `cols = 60`
- else if address is a scalar → `rows = 1`, `cols = min(80, length)`
- fallback → `rows = 1`, `cols = 40` [ matches fold handle cost ]

cheap estimation matters because layout.fit may need to consult it
for many children quickly.

### base.ui.render.tree

```perl
## [:< ##
# name  = base.ui.render.tree
# descr = render a node as a fitted, foldable tree against a budget
# param = { address, slot_budget?, depth? = 0 }
```

the user-facing entry point. if `slot_budget` is omitted, calls
`base.ui.budget.tty`. composition:

1. call `base.ui.layout.fit` → ordered child list
2. for each `unfold` child: recursively call `base.ui.render.tree`
   against its sub-budget [ proportional or first-fit, see below ]
3. for each `fold` child: call `base.ui.fold`
4. if any children folded, append `[ +N more ]` handle [ as a real
   address per `console-fold-primitive.md` ]
5. concatenate; wrap in the parent's frame idiom if `depth == 0` OR
   if the parent has a registered `.ui.frame` template; else render
   un-framed for nested depth

sub-budget allocation between unfolded children:
- start with proportional split by estimated cost
- after a child renders, return unused rows to a pool
- next children may take from the pool

### base.ui.render.tree.invalidate

```perl
## [:< ##
# name  = base.ui.render.tree.invalidate
# descr = mark an address's rendered cache stale
# param = { address }
```

if a render cache is kept [ per topic-frame-idiom-convergence's
self-invalidating-cache thread ], this is the invalidation hook. for
this task's MVP, may be a no-op stub registered for future use.

## acceptance

- given a tty of 80x24 and `address=cred-mesh.registry`
  containing 30 slots, `base.ui.render.tree` returns ≤ 22 rows, ≤ 80
  cols, where the first ~N highest-priority slots are unfolded and
  the rest are represented by one trailing `[ +M more ]` handle that
  is itself a fold handle of the form defined in
  `console-fold-primitive.md`.
- shrinking the tty re-fits without errors [ no stale unfolded
  children clipping past the new budget ].
- `p7c <zenka>.ui.show` on a zenka with no custom rendering produces
  meaningful, fitted output — proves the baseline is sufficient
  before frames are added.
- nesting works: an unfolded child that is itself a sub-tree renders
  with its own fitted layout, recursively, without special-casing.

## non-goals

- no animation, no transitions [ fold/unfold here is a discrete
  render decision ]
- no scroll-back / scroll-forward [ the trailing `[ +N more ]` handle
  IS the pagination, by being a real address ]
- no custom priority schemes per zenka — default heuristic only; the
  priority param is an injection point future work can use.

## harmony checks

```
harmony base.ui.budget.tty
harmony base.ui.layout.fit
harmony base.ui.estimate.cost
harmony base.ui.render.tree
harmony base.ui.render.tree.invalidate
```

#,,.,,,..,,..,.,,,..,,,,,,,..,..,,,.,,,..,,.,,..,,...,..,,...,,.,,,,.,,,.,,,.,
#K2452XUMTKL6WCNN2BAXWSVCKLUQFVX7MFXWBJ62LKUL3NQWZ74YKXIID5XGZ7B56JELZI5DC4OAI
#\\\|HFABS4LKHQMGCIBJA4PCU33GR4DSC2HXAMROJIAF3MHD5KSF5FO \ / AMOS7 \ YOURUM ::
#\[7]5NUKX5GHLR32CG6EO6P4Y4OB3RC6AWSCZLSQPBUAYC5AZYY7YCDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
