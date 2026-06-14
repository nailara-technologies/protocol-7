# task: flesh out the configure zenka into a generic fallback / decision-surface console

## relation to STDIO-RELAY-FOLD-APPLICATION

implements section "the configure zenka — generic fallback console"
of `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`. depends on the
three generic primitive tasks for fold/unfold + slot addressing +
render-tree baseline. is the **first general-purpose zenka consumer**
of the fold algebra and proves the claim that a zenka built on the
primitives needs almost no zenka-specific code.

## context

design docs:
- `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`
- `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`

existing stub state:
- `configuration/zenki/configure/` — start file invokes
  `[base.call.console_command:<system.args>]` and exits; no real
  console behaviour
- `modules/configure.init_code` — currently returns `0` [ which per
  [[feedback-init-code-return-values]] is *valid* success but
  semantically empty ]

reference patterns to mirror but not duplicate:
- `modules/cred-mesh.ui.query.*`,
  `modules/cred-mesh.ui.render.*`,
  `modules/cred-mesh.cmd.ui-show` — the proven tri-layer
- memory: `topic-global-ui-menu-tree` — configure's planned role as
  generic fallback / decision surface

## signatures note

no `#,,..` stubs. no whitelist edits. lowercase comments, `[ word ]`,
`$ARG`. use the dot-path config idiom for any persistent state
[ `configure.cfg.* = …` ] not a separate JSON/YAML file.

## scope

configure becomes a **thin navigator** over the global namespace plus
a **decision-prompt surface**. all of its rendering work delegates to
`base.ui.render.tree` against addresses the user navigates to. its
distinctively-its-own modules are:

1. landing entry — start at a sensible top-level address
2. navigation history — walk back/forward in the address space
3. decision prompts — register grouped "logical choice options" the
   user picks one from

### address space

- `system.configure.root`      — landing address [ default unfolds to
  the top-level reachable namespace ]
- `configure.history`          — visited-address ring
- `configure.decision.<id>`    — registered decision prompts
- `configure.decision.<id>.option.<name>` — options under each prompt

## modules to implement

### configure.init_code

initialise:
- `<configure.history> = []` [ recent-first ring, bounded ]
- `<configure.cfg.history.max>` //= 64
- `<configure.cfg.landing>` //= `system.configure.root`
- register a callback on `system.callbacks.initialized` to bind a
  default slot to the landing address [ see
  `configure.handler.start-console` below ]

per [[feedback-init-code-return-values]] return `TRUE`.

### configure.handler.start-console

```perl
## [:< ##
# name  = configure.handler.start-console
# descr = bind configure's tty slot to the landing address
```

- registers a slot via `base.slot.register surface=configure.tty
  name=main`
- calls `base.slot.bind_content slot_address=<that> content_address=<configure.cfg.landing>`
- calls `base.slot.refresh` against the slot

### configure.cmd.go

```perl
## [:< ##
# name  = configure.cmd.go
# descr = navigate the bound slot to a given address
# param = { address }
```

- pushes the *current* slot's content_address onto `<configure.history>`
- calls `base.slot.bind_content` with the new address
- calls `base.slot.refresh`

### configure.cmd.back

```perl
## [:< ##
# name  = configure.cmd.back
# descr = pop the history ring, re-bind the previous address
```

idempotent at the start of history.

### configure.cmd.decide

```perl
## [:< ##
# name  = configure.cmd.decide
# descr = register a grouped decision prompt
# param = { id, question, options = [ { name, summary, action_address? } ] }
```

- stores `<configure.decision>{<id>} = { question, options_b32, added_b32 }`
- stores each option under
  `<configure.decision>{<id>}{option}{<name>} = { summary, action_address }`
- triggers `base.ui.render.tree.invalidate configure.decision.<id>`
- returns the decision's full address

decision prompts are the **mechanism behind the "fallback when there's
ambiguity" framing**: any zenka that hits an ambiguous decision routes
through `configure.cmd.decide` rather than coding its own picker.

### configure.cmd.pick

```perl
## [:< ##
# name  = configure.cmd.pick
# descr = select an option from a decision prompt
# param = { id, name }
```

- looks up `<configure.decision>{<id>}{option}{<name>}`
- if it has `action_address` → resolve and call it [ via the standard
  `<[…]>->()` mechanism ]
- removes the decision from `<configure.decision>` [ folded, not
  preserved — picks are one-shot by default ]
- triggers `base.ui.render.tree.invalidate configure.decision.<id>`

### configure.ui.query.landing

```perl
## [:< ##
# name  = configure.ui.query.landing
# descr = the landing-address query — returns top-level zenka set
```

reads `<v7.zenka.setup>` plus statically-configured navigation roots
[ `system.configure.cfg.navigation_roots` ] and returns an ordered
list of addressable children. the *only* configure-specific query;
all other navigation delegates to `base.ui.render.fallback`.

### configure.ui.render.decisions

```perl
## [:< ##
# name  = configure.ui.render.decisions
# descr = render the pending-decisions sub-tree
# param = { slot_budget }
```

walks `<configure.decision>`, renders each as:
- one-line question header
- options as foldable children, each with summary cell
- footer hint: `pick id=<id> name=<name>`

### configure.cmd.ui-show

dispatcher: if `<configure.decision>` is non-empty, render decisions
first [ they're attention-priority by definition ], then the
slot's current content_address via `base.ui.render.tree`. if no
pending decisions, just render the current address.

NO custom per-address rendering — every other address goes through
`base.ui.render.tree` / `base.ui.render.fallback`. this is the
proof-by-thinness claim from the design doc.

### configure start file changes

`configuration/zenki/configure/start`: switch from one-shot
console-command exec to the standard module load + zenka loop
pattern. minimal:

```
modules.load = base.init crypt.C25519 amos7 configure
[load_modules:<modules.load>]
[init_modules]
[root.drop_privs:<user>]
[zenka.loop]
```

add `configuration/zenki/configure/zenka-startup.v7` and
`configuration/zenki/configure/access.zenki` matching the existing
zenka patterns [ e.g. cred-mesh's ]; refer to live zenki for
exact required keys.

## acceptance

- `p7c configure.cmd.ui-show` shows a navigable landing with the
  reachable zenki as foldable children.
- `p7c configure.cmd.go address=cred-mesh.registry` re-binds
  configure's slot to the cred-mesh registry, rendered via
  `base.ui.render.tree` with **zero cred-mesh-specific code**
  in configure.
- `p7c configure.cmd.back` returns to the landing.
- `p7c configure.cmd.decide id=tls-key question='Use existing key or generate?' options='[{name:existing,summary:Use found key},{name:generate,summary:Generate new}]'`
  registers a decision; subsequent `configure.cmd.ui-show` shows it
  first with options as foldable handles. `configure.cmd.pick id=tls-key
  name=existing` fires the option's action [ if any ] and removes the
  decision.
- `harmony configure.cmd.ui-show` etc. clean.
- starts under v7 management at boot when added to
  `configuration/zenki/v7/start-set-up.base` [ or on-demand otherwise ].

## non-goals

- no per-zenka customisation of navigation — that's an override
  registered at `<zenka>.ui.render.default`, not configure's concern
- no styled chrome beyond what `base.ui.render.tree` produces
- no in-decision persistence of partial state — picks are atomic
- no decision-tree branching [ decision-of-decisions ] in this
  task — straightforward to add later, intentionally bounded
- no replacement of `set-up` zenka — configure and set-up are
  complementary surfaces; set-up's wiring into the same fold algebra
  is a sibling task not covered here

## harmony checks

```
harmony configure.init_code
harmony configure.handler.start-console
harmony configure.cmd.go
harmony configure.cmd.back
harmony configure.cmd.decide
harmony configure.cmd.pick
harmony configure.ui.query.landing
harmony configure.ui.render.decisions
harmony configure.cmd.ui-show
```

#,,,.,,.,,..,,.,,,...,,,.,,,.,,.,,,.,,.,.,...,..,,...,...,,..,.,,,.,,,..,,.,.,
#C4ABCAB6ZOZ2RRLIAGYMXZCS2MEY4TFOAFPJC2NBCDGPJRGX6XM7Q63QIWHMDRBZA46WRDJJNMTTE
#\\\|YPTDTMZSIHN534BAAOZ4FQQWXV3FVDDAQFWXXDDMJYIGAM2E2G5 \ / AMOS7 \ YOURUM ::
#\[7]TD263RTWIYZEXCQGO5O5HJQBZQIUY5WBDGCKGV566UGH26UJKGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
