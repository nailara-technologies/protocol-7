# task: base.ui.fold / unfold / cmd.ui-show fallback primitives

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

implements the *smallest first step* of the
`data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` design — the generic
fold/unfold verbs against an address, plus the fallback ui-show that
every zenka inherits by being addressable. realises the "fold-back as
the resting state of presence" principle as concrete primitives, and
makes the "branch node = complete tree" principle live by giving every
namespace node a default rendering without per-zenka boilerplate.

## context

design doc [ read first ]:
- `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`
- memory note `topic-global-ui-menu-tree` for the stdio-slot vision
- `modules/cred-mesh.ui.show` (and `.ui.query.*`, `.ui.render.*`)
  — the concrete proven pattern this generalises
- `modules/ascii.frame.compose`, `modules/ascii.frame.load`
- `data/yaml/ascii-frames/cred-mesh/*` for the frame idiom

the cred-mesh tri-layer (query / render / dispatch) is proven
working. this task lifts it from per-zenka boilerplate to a primitive
every node gets *by default*, so the next twenty zenki don't reinvent
it.

## signatures note

do NOT add `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

## modules to implement

### base.ui.fold

```perl
## [:< ##
# name  = base.ui.fold
# descr = fold an addressable element into a one-line handle
# param = { address, summary?, kind? }
```

returns a single rendered line of the form:

```
.:[ <kind> ]:[ <short-address> ]:[ <one-line summary> ]:.
```

- `kind` defaults to the namespace tail's first segment classification
  [ `zenka`, `slot`, `task`, `log`, `result`, `view`, `node` ]
- `summary` defaults to the result of `<[base.ui.summarise:<address>]>`
  (see fallback below) — never longer than the available horizontal
  budget minus the kind/address frame overhead
- `short-address` is the *terminal* segment of the address [ never the
  full path ]; the parent's frame supplies surrounding context

returns `{ mode => 'true', data => $line }`.

### base.ui.unfold

```perl
## [:< ##
# name  = base.ui.unfold
# descr = render an address in its expanded form for the given slot budget
# param = { address, slot_budget => { cols, rows } }
```

resolution order:
1. if `<address>.ui.render.default` exists → call it with `slot_budget`
2. else if `<address>.cmd.ui-show` exists → call it [ implicit budget ]
3. else → call `<[base.ui.render.fallback]>->({ address, slot_budget })`

returns `{ mode => 'true', data => $rendered_block }` where `data` is
a multi-line string sized to the budget.

### base.ui.render.fallback

```perl
## [:< ##
# name  = base.ui.render.fallback
# descr = generic rendering of an address as foldable children
# param = { address, slot_budget }
```

walks the namespace under `address` [ via existing `<address>.list-subs`
introspection when available; falls back to scanning `%data` /
`%code` keys with prefix match ]. for each child:
1. if it fits in the remaining budget AND has its own renderer → unfold
   it inline
2. else → fold it via `base.ui.fold`

if all children are folded and there are still uncalled children,
append a trailing folded handle:

```
.:[ +<N> more ]:[ <address>.<...> ]:[ ... ]:.
```

this trailing handle is itself a real address [ `<address>.__more__`
or similar canonical suffix ] resolvable on subsequent unfold.

### base.ui.summarise

```perl
## [:< ##
# name  = base.ui.summarise
# descr = produce a one-line summary cell for an address
# param = { address }
```

resolution order, first hit wins:
1. `<address>.ui.summary` if defined
2. heuristic: address points at a hash → `<count> entries`
3. heuristic: address points at a scalar shorter than 32 chars → the
   scalar itself
4. heuristic: address points at a code-ref → `callable`
5. fallback → `available`

`available` is the explicit "presence without further info" cell — per
the design philosophy, the *fact* of foldability already conveys "this
remains reachable," so an empty summary is acceptable, not an error.

### base.cmd.ui-show.fallback

```perl
## [:< ##
# name  = base.cmd.ui-show.fallback
# descr = generic ui-show used when a node has no specific handler
# param = { address?, view? }
```

if no specific `<address>.cmd.ui-show` exists, this is what is
invoked. composes:
- a one-line header frame using the `.:[ ]:.` idiom with the address
  as title
- the result of `base.ui.unfold` for the address against the current
  tty's `cols`/`rows`

returns the concatenated multi-line string.

## wiring

in `modules/base.init_code` [ at the appropriate late-init stage so
fallbacks are present before any zenka's first ui-show call ]:

- register `base.cmd.ui-show.fallback` as the default dispatch for any
  `<zenka>.cmd.ui-show` call whose specific handler is absent. the
  cube routing layer should already strip the `<zenka>.` prefix; this
  task only needs to ensure the fallback is registered in the global
  command table.

do NOT add it as a per-zenka access entry — that would defeat the
"inherits by being addressable" property. it lives at the base layer.

## acceptance

- `p7c base.ui.fold address=cred-mesh.registry summary='5 slots'`
  produces a single line that visually parses as a fold handle.
- `p7c base.ui.unfold address=cred-mesh.registry slot_budget='{cols:80,rows:10}'`
  produces a rendered block of at most 10 rows, all foldable handles
  fitting in 80 cols, with a trailing `[ +N more ]` handle iff there
  are uncalled children.
- `p7c some-zenka-without-ui.cmd.ui-show` succeeds and produces a
  reasonable default rendering [ proves the fallback works zero-config ].
- calling the fallback on a zenka that DOES have `.ui.show` defined
  must NOT shadow it — the specific implementation wins.
- visual idiom matches existing ascii.frame output [ same single
  border style, same `.:[ ]:.` corner idiom ].

## non-goals

- no interactive selection — that's a follow-on task.
- no fold/unfold *triggers* [ time-based, structural ] — those live in
  the per-zenka layer or in a later orchestrator task. this task ships
  the verbs, not the policy.
- no slot-move operation — `console-stdio-slot-addressing.md` owns
  slot addressing; this task assumes the slot budget is given.

## harmony checks

```
harmony base.ui.fold
harmony base.ui.unfold
harmony base.ui.render.fallback
harmony base.ui.summarise
harmony base.cmd.ui-show.fallback
```

#,,..,,,.,,..,,..,.,,,,.,,,.,,,..,,,.,.,,,,,,,..,,...,...,,,.,,,.,..,,,.,,,..,
#BNNTR64WGF7VLEZZFDMUT34KQDHFJHIRUV2LXOWB5WY3PRZF3KQN4N2A4P22TVFIS674PYJLXVA6M
#\\\|SBC43FRHK2PYMQAK5X7PLYSZEXIGFTTLEQQRUREDZXNVE623IPP \ / AMOS7 \ YOURUM ::
#\[7]SWZM3NYHO3YMEIF3EFK653XP7A7OQ2TZ3ULUMLFZKFIFJMESX6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
