# task: generalise v7's zenka-stdout relay into a foldable addressable stream

## relation to STDIO-RELAY-FOLD-APPLICATION

implements section "de- and re-attachable stdio — the layering" of
`data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`. concretely: extends
v7's existing source → ingest → store path with the **filter** and
**render** layers needed to make `<zenka>.stdout` a first-class
foldable addressable element under the philosophy doc's algebra,
without rewriting any of the existing ingest/store plumbing.

prerequisite: `console-fold-primitive.md`,
`console-foldable-render-baseline.md`,
`console-stdio-slot-addressing.md` must all be landed first — this
task consumes their verbs and never re-implements them.

## context

design docs [ read first, in order ]:
- `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`
- `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md` [ esp. the
  source/ingest/store/filter/render diagram ]

existing v7 relay plumbing to integrate with [ READ-ONLY for this
task — do NOT rewrite ]:
- `modules/v7.handler.output_zenka_stdout` — the `say $line` site
  that becomes the *default-view refresh hook*
- `modules/v7.handler.process_output_line` — ingest entry point
- `modules/v7.handler.zenka_output` — pipe-watcher dispatch
- `modules/v7.setup_stdout_redir` — store-layer init
  [ `/dev/shm/.7/STDOUT/<sock>` ]
- `modules/v7.stdout_log.write` — store-layer write
- `modules/v7.callback.stdout_log_rotate` — store-layer rotation
- `modules/v7.init_zenka_output_patterns`,
  `modules/v7.load_zenka_output_patterns` — the pattern-table dispatch
  this task generalises into a register of ingest-side hooks

## signatures note

do NOT add `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

## the rewiring [ minimal and additive ]

### address space introduced

a stable per-zenka address under `v7.zenka.<zenka_id>.stdout`:

- `v7.zenka.<zenka_id>.stdout`             — the stream itself
- `v7.zenka.<zenka_id>.stdout.line.<b32>`  — individual line, addressed
  by `base.ntime_BASE32_to_numerical`-sortable ntime
- `v7.zenka.<zenka_id>.stdout.pattern.*`   — registered match patterns
  [ existing `v7.patterns.zenka_output` table, repointed ]
- `v7.zenka.<zenka_id>.stdout.filter.*`    — render-side filter chain
- `v7.zenka.<zenka_id>.stdout.view.*`      — currently bound views

and an *alias* under the friendlier `<zenka_name>.stdout` prefix
resolved via `v7.zenka.setup` lookup, so `p7c some-zenka.stdout`
works without the user having to know the instance id.

### modules to implement

#### v7.stdout.address.resolve

```perl
## [:< ##
# name  = v7.stdout.address.resolve
# descr = resolve a zenka-name or instance-id to its stdout address
# param = { zenka_name? | zenka_id? }
```

returns the canonical `v7.zenka.<instance_id>.stdout` address as a
string. if both supplied, `zenka_id` wins. returns `undef` on miss.

#### v7.stdout.view.bind

```perl
## [:< ##
# name  = v7.stdout.view.bind
# descr = bind a stdio slot to a zenka's stdout address
# param = { zenka_name? | zenka_id?, slot_address, view? = 'default' }
```

- resolves the stdout address via `v7.stdout.address.resolve`
- calls `base.slot.bind_content` against `slot_address` with
  `content_address = <stdout_address>.view.<view>`
- registers the slot in `<stdout_address>.view.<view>.slots`
- if `view` is `'default'` and not yet registered, registers it with
  refresh `v7.stdout.view.default.refresh`

#### v7.stdout.view.unbind

```perl
## [:< ##
# name  = v7.stdout.view.unbind
# descr = unbind a slot from a stdout view
# param = { slot_address }
```

idempotent; removes the slot from any `<stdout_address>.view.*.slots`
set. does NOT touch the store layer.

#### v7.stdout.view.default.refresh

```perl
## [:< ##
# name  = v7.stdout.view.default.refresh
# descr = default-view refresh handler — one line per arrived line
# param = { slot_address, line }
```

the *new home* of today's `say $line` behaviour. paints `$line`
into the slot. for slots whose surface is the raw tty, this collapses
to today's `say` semantics; for slots bound to a vterm layer, this
paints into that layer instead.

#### v7.stdout.filter.add

```perl
## [:< ##
# name  = v7.stdout.filter.add
# descr = register a render-side filter on a stdout address
# param = { zenka_name? | zenka_id?, name, re, mode = 'keep' | 'drop' }
```

- compiles `re` once, stores under
  `<stdout_address>.filter.<name> = { re, mode, added_b32 }`
- triggers `base.ui.render.tree.invalidate` on `<stdout_address>` and
  on every `<stdout_address>.view.*` that exists

#### v7.stdout.filter.remove

```perl
## [:< ##
# name  = v7.stdout.filter.remove
# descr = remove a named filter from a stdout address
# param = { zenka_name? | zenka_id?, name }
```

idempotent.

#### v7.stdout.line.iter

```perl
## [:< ##
# name  = v7.stdout.line.iter
# descr = iterate stored lines for an address with optional filter chain
# param = { address, since_b32?, limit?, apply_filters? = TRUE }
```

reads from the existing `/dev/shm/.7/STDOUT/<sock>` ring [ via
existing store-layer accessors; do NOT change the ring layout ] and,
if `apply_filters`, walks every filter under `<address>.filter.*` in
add-time order, applying `keep` / `drop` logic. yields whatever the
project's existing iterator idiom is [ scalar-ref array, callback,
generator ] — match whatever `base.parser.list` consumes.

### tiny edit in v7.handler.output_zenka_stdout

replace the *single* `say $line` with a dispatch over every slot
currently bound to `v7.zenka.<this_instance>.stdout.view.*`. for the
default view's slot, that ends up calling
`v7.stdout.view.default.refresh` which calls `say` — the observable
behaviour is unchanged when no extra view is bound. for any
additional bound view [ filter overlay, tree-grouped view, etc. ],
the same line is delivered to that view's refresh handler too.

if no slots are bound at all [ early boot, slot subsystem not yet
initialised ], fall back to today's `say $line`. this preserves the
boot-time relay path unchanged.

leave `v7.stdout_log.write` *exactly as is* — the store layer is
unchanged. that's the whole point: ingest + store keep working
identically; what's new is the per-line dispatch over a registered
view set.

### ingest-side pattern hooks [ small refactor ]

`v7.init_zenka_output_patterns` currently registers callable handlers
against `v7.patterns.zenka_output`. expose this through the namespace
view by aliasing `v7.zenka.<instance>.stdout.pattern.<name>` to the
same handler entries — read-only addressability, no behaviour change.
this is the branch-as-complete-tree principle applied: pattern
handlers are *already* a sub-tree, they just weren't *named* as one.

## acceptance

- `p7c v7.stdout.address.resolve zenka_name=cube` returns the
  canonical stdout address for the running cube instance.
- with no slots bound, v7's console output is bit-identical to
  pre-task behaviour [ regression-free fallback ].
- `p7c v7.stdout.view.bind zenka_name=cube slot_address=<S>` causes
  subsequent cube stdout lines to paint into slot `<S>` [ raw or
  vterm-backed, depending on slot ].
- `p7c v7.stdout.filter.add zenka_name=cube name=err re='ERR' mode=keep`
  followed by re-rendering the cube stdout slot shows only matching
  lines; `v7.stdout.filter.remove name=err` restores the full view.
- `base.ui.show v7.zenka.<id>.stdout` produces a fitted tree-rendered
  view of the stream and its sub-namespaces [ pattern, filter, view ],
  proving the namespace acquires UI by being addressable [ no extra
  per-zenka render code needed ].
- moving a slot from one surface to another via `base.slot.move`
  carries the stdout view with it — disconnect/reconnect a
  filter-overlay-decorated console with one command, lossless.

## non-goals

- no change to ingest pipe-watching, line statistics, or
  `process_output_line`'s buffering logic.
- no rotation/retention policy changes.
- no new persistence — the store layer is still the in-memory ring.
- no UX for filter/view binding — task ships verbs; one-key toggles
  are a downstream UX pass.
- no per-zenka access-control changes — the new commands inherit the
  same `cube/access.zenki` regime as the existing relay.

## harmony checks

```
harmony v7.stdout.address.resolve
harmony v7.stdout.view.bind
harmony v7.stdout.view.unbind
harmony v7.stdout.view.default.refresh
harmony v7.stdout.filter.add
harmony v7.stdout.filter.remove
harmony v7.stdout.line.iter
```

#,,,.,.,,,,,.,,.,,.,,,,..,..,,..,,,..,.,,,,,.,..,,...,...,...,.,,,,,,,,..,,.,,
#VOTWRHYROVUONIW4QRO6IW6D66ONJNFMD3X3YYN4XBFEQ6GZBNOIKM7QO7OJFVZE3IM2U24HGJFF2
#\\\|AXFL2CNUJ7SWXPAYTXNWCCKZQYZ4GBSYUU57KG5I2W6WV6AAEO4 \ / AMOS7 \ YOURUM ::
#\[7]K73ROLPNLJJTO77F2NDB4M3J465QHTI3GZYT4WPYLRVEPSPHUCAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
