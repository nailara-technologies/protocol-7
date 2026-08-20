# task: base.cmd.ui-show + wiring (console-fold-primitive remainder)

## relation

`console-fold-primitive.md` has been mostly implemented by
`console-foldable-render-baseline` (commit `2560c5499`):
`base.ui.fold`, `base.ui.unfold`, `base.ui.render.fallback`,
`base.ui.summarise`, `base.ui.render.tree(.invalidate)`,
`base.ui.layout.fit`, `base.ui.budget.tty`, `base.ui.estimate.cost` all
exist and match the contracts in `console-fold-primitive.md`.

the ONE piece from `console-fold-primitive.md` that was explicitly
skipped is `base.cmd.ui-show.fallback` plus its wiring. this task
implements just that remainder.

read first:
- `data/tasks/console-fold-primitive.md` (section "base.cmd.ui-show.fallback"
  and "wiring", near the end of the file)
- `src/base.ui.unfold`, `src/base.ui.render.fallback`,
  `src/base.ui.budget.tty` (existing, to call from the fallback)
- `src/credential_fabric.ui.show` for the proven `.cmd.ui-show`
  pattern this generalises
- `src/ascii.frame.compose` / `ascii.frame.load` for the `.:[ ]:.`
  header idiom

## scope

### `base.cmd.ui-show`

```perl
## [:< ##
# name  = base.cmd.ui-show
# descr = base-layer default ui-show command, superseded by any zenka-specific
#         <namespace>.cmd.ui-show module of the same loaded zenka
# param = { address?, view? }
```

- default handler for the `ui-show` command. the cube strips the
  `<zenka>.` prefix before dispatch; the zenka receives `ui-show` and
  looks it up in `$data{'base'}{'cmd'}{'ui-show'}`. any zenka-specific
  `<namespace>.cmd.ui-show` module auto-registers via the loader in
  `bin/Protocol-7` (line ~1519) using `//=` against the same key, so
  the base handler only fires for zenki without a specific handler.
- composes:
  1. a one-line header frame using the `.:[ ]:.` idiom with the
     address as title (reuse `ascii.frame.compose`/`ascii.frame.load`
     — same single border style as existing frame output)
  2. the result of `<[base.ui.unfold]>->({ address, slot_budget })`
     for the address, with `slot_budget` taken from
     `<[base.ui.budget.tty]>` (existing module — check its contract,
     it likely already returns `{ cols, rows }` for the calling tty)
- returns the concatenated multi-line string (check existing
  `cmd.ui-show` implementations for the expected return shape —
  `{ mode => 'size', data => $string }`, matching the SIZE-mode
  reply convention used by `credential_fabric.cmd.ui-show`)

### wiring

no manual wiring is required. `src/base.cmd.ui-show` is
auto-registered by the loader in `bin/Protocol-7` (line ~1519) under
`$data{'base'}{'cmd'}{'ui-show'}` because its filename matches the
`\.(cmd|console)\.(.+)$` pattern.

- the cube routing layer strips the `<zenka>.` prefix before dispatch,
  so the target zenka receives the literal command `ui-show`. that
  command is looked up in `$data{'base'}{'cmd'}{'ui-show'}` by
  `src/base.handler.command`.
- zenki-specific `<namespace>.cmd.ui-show` modules are also
  auto-registered by the same loader using `//=` against the same key,
  so whichever loads first wins and the base handler only fires for
  zenki without a specific handler.
- do NOT add per-zenka `access.zenki` entries for this — it must work
  for every zenka by virtue of being addressable, per the design
  philosophy in `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`.

## acceptance

- `p7c some-zenka-without-ui.cmd.ui-show` succeeds and produces a
  reasonable default rendering (header frame + `base.ui.unfold` output)
  — proves zero-config fallback works via cube prefix strip + loader
  auto-registration
- `p7c credential_fabric.cmd.ui-show` (or `.ui.show`, whichever is the
  live entry point) still uses the credential_fabric-specific handler
  — NOT the fallback
- visual idiom matches existing ascii.frame output (same single border
  style, same `.:[ ]:.` corner idiom)
- no behavioral change for any zenka that already has its own
  `<namespace>.cmd.ui-show` / `ui.show`

## non-goals

- no interactive selection, no fold/unfold triggers, no slot-move —
  same non-goals as `console-fold-primitive.md`
- no changes to `base.ui.fold` / `base.ui.unfold` / `base.ui.render.*`
  / `base.ui.summarise` / `base.ui.budget.tty` — these are done and
  should not be modified unless you find an actual bug blocking this
  task, in which case fix minimally and note it in your report

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists (add `base.cmd.ui-show` to
`cfg/zenki/v7/subroutine.white-list` and any other zenki
whitelist that already contains `base.ui.fold`/`base.ui.unfold`,
following the exact pattern used when those were added — check with
`grep -rl base.ui.unfold cfg/zenki/*/subroutine.white-list`).
lowercase comments, `[ word ]` annotations, `$ARG` not `$_`.

## harmony checks

```
harmony base.cmd.ui-show
```

#,,..,.,.,.,.,,,.,..,,..,,,.,,.,,,,,.,...,,,.,..,,...,..,,...,,,,,,..,,,.,,,,,
#U73ITNXVRTY2ORV6MJPUX52D54DAGMMNO667IA3NUMBPXQVA2JDOZZZ5XNNDSGWNVCNDAFAUOHFYS
#\\\|Q5EQ3XYF7CCF43DKOPLMTFOF4H365KUENTH5ZOF6EAKTQQTZLP3 \ / AMOS7 \ YOURUM ::
#\[7]25CRGXV4CDVPNGFRAPQMAGE2BAFMJHZQMW53CPW75YRJPDZ5CICA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
