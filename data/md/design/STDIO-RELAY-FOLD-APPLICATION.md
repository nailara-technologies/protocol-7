# stdio relay fold application — base.log, v7 stdout relay, configure, installer

[ origin: 2026-06-10 — second application doc on top of
  `CONSOLE-FOLD-TREE-PHILOSOPHY.md`. where the philosophy doc names the
  generic primitives [ fold-back-as-presence, branch-as-complete-tree ]
  and `data/tasks/console-{fold-primitive,foldable-render-baseline,
  stdio-slot-addressing}.md` ship the generic verbs, *this* doc names
  the first concrete surfaces those verbs are aimed at: the existing
  `base.log` / `base.logs` family, the v7 zenka-stdout relay, and two
  starting-point zenki [ `configure`, future `installer` ] that prove
  the layering by being its first generic consumers. ]

related primary sources [ read in order if new to this thread ]:
- `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` — first-principles
  parent doc
- `data/tasks/console-fold-primitive.md`,
  `data/tasks/console-foldable-render-baseline.md`,
  `data/tasks/console-stdio-slot-addressing.md` — the three generic
  primitive tasks this doc consumes
- memory note `topic-global-ui-menu-tree` — origin vision; the
  configure / set-up starting-point framing, the credential_fabric
  tri-layer pattern this doc generalises further
- `data/md/design/VTERM-BUFFER-SPECIFICATION.md` — existing layered
  buffer infrastructure [ vterm.* ] available as the rendering substrate
- `data/md/design/DECODER-VTERM-ARCHITECTURE.md` — vterm context
- `data/md/design/9P-AMOS-TERM-VISION.md` — host-side terminal /
  nesting context
- `data/md/design/LAYER-MATRIX-STATE-TRANSFER.md` — the layered overlay
  / reversible-state-transfer primitive a filter overlay actually rides
- existing v7 plumbing this doc applies the philosophy to:
  `modules/v7.handler.output_zenka_stdout`,
  `modules/v7.handler.zenka_output`,
  `modules/v7.handler.process_output_line`,
  `modules/v7.setup_stdout_redir`,
  `modules/v7.stdout_log.write`,
  `modules/v7.callback.stdout_log_rotate`,
  `modules/v7.init_zenka_output_patterns`,
  `modules/v7.load_zenka_output_patterns`,
  `modules/base.log`, `modules/base.logs`, `modules/base.log.format_entry`,
  `modules/base.log-delayed`, `modules/base.log.send-buffer.*`

## the framing in one paragraph

the user's articulation [ 2026-06-10 ]: *stdio is what makes a zenka a
**forward operating base** — a remote front whose presence in the
network is anchored, but whose stdio is fully reconfigurable and
de-/re-attachable.* a zenka's stdout stream is therefore not a
fire-and-forget mirror into v7's console; it is an **addressable
foldable element** under the same console-fold algebra as everything
else, with vterm nesting toward the user's host machine carrying its
unfolded form whenever attention requests it. the existing v7 relay
[ `v7.setup_stdout_redir` → `v7.handler.process_output_line` →
`v7.handler.output_zenka_stdout` → `v7.stdout_log.write` ] *already
does most of this in fragments*; this doc names the seam where the
fragments line up under the fold primitives.

## the principles, localised onto stdio

### fold-back-as-presence applied to a zenka's stdout

a zenka's stdout stream is a **foldable element** with a stable
address. its forms:

- **folded** — `.:[ stdout ]:[ <zenka>.stdout ]:[ <N> lines / <r> rate ]:.`
  no rendered output reaches the v7 console; the line in the v7
  surface IS the folded handle, updating the rate cell only
- **unfolded raw** — the existing v7 console line-relay behaviour
  [ `say $line` in `v7.handler.output_zenka_stdout` ] is *one
  particular* unfold mode, equivalent to "render this address as one
  line per buffered entry, no filter, no grouping"
- **unfolded filtered** — same address, different render-side filter
  [ regex / level / pattern-table ] applied; the unfiltered stream is
  *still flowing into the address*, the filter sits **behind** the
  rendered slot per the philosophy doc's "search/filter behind a log"
  point, never destroying state
- **unfolded grouped** — same address, render-side grouping by zenka
  or topic; the per-zenka tree-grouped log view of the user's usage
  example is one concrete instance of this mode

the *fact* of presence — that lines keep arriving, that the address
remains resolvable — is invariant under fold/filter/group. these are
all **render-side operations against one address**, never
buffer-routing decisions that mutate or lose state.

### branch-as-complete-tree applied to log namespaces

`base.log` writes today are addressed by a `log_buffer` string plus
implicit per-zenka context. the philosophy doc's branch principle says:
every node is a complete tree. so:

- `<zenka>.stdout` is a complete tree — its sub-tree is the
  zenka's currently-buffered lines, each addressable as
  `<zenka>.stdout.line.<ntime_b32>` [ see [[topic-stream-framing-protocol]]
  and `base.ntime_BASE32_to_numerical` per [[feedback-ntime]] for the
  sortable timestamp address ]
- `<zenka>.stdout.pattern` is a complete sub-tree of registered
  pattern handlers [ matches `v7.init_zenka_output_patterns` ]
- `<zenka>.stdout.filter` is a complete sub-tree of currently-attached
  filter overlays [ named, foldable, removable ]
- `<zenka>.stdout.view` is a complete sub-tree of currently-bound
  *renderings* of the stream into stdio slots [ one slot per attached
  view; same `base.slot.*` machinery from `console-stdio-slot-
  addressing.md` ]

the user can `p7c base.ui.show <zenka>.stdout` and get exactly the
default rendering [ the existing single-line relay form ]. they can
`p7c base.ui.show <zenka>.stdout.filter` and see the currently
attached filters as a foldable list. they can attach a new filter at
`<zenka>.stdout.filter.<name>` and `base.ui.show <zenka>.stdout` now
re-renders with that filter behind it — no special wiring per zenka,
because the *namespace* declared the structure and
`base.ui.render.tree` did the rest.

## de- and re-attachable stdio — the layering

the user's framing demands the stdio *itself* be detachable, not just
its rendered form. four layers, named, each composable independently:

```
  [ source ]    a zenka's actual STDOUT/STDERR fds [ unchanged ]
       |
  [ ingest ]   line-extraction + per-zenka buffer + pattern dispatch
       |        [ existing: v7.handler.process_output_line,
       |          v7.handler.zenka_output, v7.init_zenka_output_patterns ]
       |
  [ store  ]   ring-buffer storage + ntime address + retention policy
       |        [ existing: v7.stdout_log.write,
       |          v7.callback.stdout_log_rotate, /dev/shm/.7/STDOUT/<sock> ]
       |
  [ filter ]   render-side filter/group/decorate chain [ NEW; can be
       |        empty, single, or stacked; bound to <zenka>.stdout.filter ]
       |
  [ render ]   binding into a stdio slot + actual painting via
       |        ascii.frame / vterm / raw say [ NEW: per
                console-stdio-slot-addressing.md the slot is what
                makes this de-/re-attachable ]
```

the existing fragments map cleanly onto **source → ingest → store**.
the philosophy is *almost* satisfied by what's there; the gap is the
*later* two layers. concretely:

1. **ingest+store stays where it is** — no zenka rewrite, no relay
   topology change. lines keep flowing into the per-socket ring buffer
   at `/dev/shm/.7/STDOUT/<sock>` and through `base.log`.
2. **filter and render become addressable layers** — new
   `<zenka>.stdout.filter.*` sub-namespace + `<zenka>.stdout.view.*`
   sub-namespace, both consumed by `base.ui.render.tree` for the
   address `<zenka>.stdout`. the v7 console line that `say`s every
   relayed line is recharacterised as *one default view bound to one
   default slot*, not as the relay itself.
3. **`v7.handler.output_zenka_stdout` shrinks** — instead of "always
   `say $line`," it routes lines into the store layer and notifies any
   currently-bound views via the slot's refresh hook
   [ `base.slot.refresh` from `console-stdio-slot-addressing.md` ].
   the default view's refresh is "print one line"; richer views
   [ filter overlay, tree-grouped ] are other slots bound to the same
   address.
4. **detach** = unbind the view's slot. the stream keeps storing; just
   nothing renders that view. **re-attach** = bind a new slot to the
   address; the next line refreshes it. the store layer is the
   continuity that makes "presence undisturbed" literally true.

this is *generalisation*, not replacement: today's `say $line` becomes
the default-view refresh; today's `v7.stdout_log.write` ring buffer
becomes the store layer; today's pattern-table dispatch becomes the
ingest layer's hook surface. the only genuinely new code is the
filter chain and the slot-binding seam, both of which are local
additions, not re-plumbing.

## vterm nesting toward the user's host

`VTERM-BUFFER-SPECIFICATION.md` already provides the layered buffer
substrate. unfolded views of `<zenka>.stdout` that are richer than
"one line per write" [ filter overlays, tree-grouped views, fullscreen
expansions ] render into `vterm.*` layers, not into raw stdout. that
keeps the existing `v7.handler.output_zenka_stdout` raw-`say` path
untouched while richer views compose against the layered buffer.

the "vterm nesting toward the user's host" the user mentioned is the
chain:

```
  zenka --(line)--> v7 ingest --(store)--> slot --(render)--> vterm
                                                                |
                                                              host tty
```

each arrow is locally addressable. the host tty is the outermost vterm
in this nesting; any inner vterm is just another surface in the
namespace and any slot can be moved into it [ per `base.slot.move` from
`console-stdio-slot-addressing.md` ]. the existing
[[topic-nshell-terminal-rendering]] / terminal-buffer / vterm work
already buffers enough margin to make this practical — what's missing
isn't buffer depth, it's *addressing* of the points along the chain,
which the three primitive tasks provide.

[[topic-layer-matrix-convergence]] and `LAYER-MATRIX-STATE-TRANSFER.md`
describe a reversible *between-layer* operation algebra. that's the
substrate a filter overlay actually rides — a filtered view is a
reversible diff from the raw view, with one button [ or fold ]
restoring the raw view at the same address. the filter overlay task
below explicitly relies on this rather than re-inventing it.

## worked usage examples [ as concrete tasks ]

### example A — pattern-matching filter overlay on the v7 console

today: `v7.init_zenka_output_patterns` already matches patterns
against zenka output to trigger commands. it does NOT filter the
rendered view — every line still reaches the v7 console verbatim. the
user wants a one-key toggle that hides everything *but* matched lines
[ or, the inverse — hide all matched lines as noise ] without losing
the unfiltered stream.

with the fold primitives + slot addressing:

1. user issues `p7c v7.console.filter.add name=errors-only re='\b(ERR|FATAL)\b' mode=keep` [ or hotkey ]
2. a new filter node lands at `v7.console.filter.errors-only`
3. `base.ui.render.tree` re-renders the v7 console slot, now driven
   through the filter chain → only matching lines paint
4. unmatched lines still arrive at the store layer; they are present,
   addressable as `v7.console.unfiltered`, and a *second* slot bound
   to that address can be unfolded alongside [ or under, or fullscreen ]
   at any time
5. one-key toggle [ globally-reserved hotkey per philosophy doc ]
   folds/unfolds the filter node — flipping filter on/off is the same
   operation as flipping any other foldable element's visibility

the *button toggle / one-keypress* is literally `base.ui.fold` /
`base.ui.unfold` against `v7.console.filter.errors-only` — no
filter-specific UI machinery. detailed task: `v7-console-log-filter-
overlay.md` below.

### example B — alternate tree-grouped view of v7 console

today: the v7 console is line-time-ordered, all zenki interleaved.
the user wants an alternate view that groups lines into per-zenka
sub-trees, each foldable independently, with one keypress to switch
between the time-ordered and tree-grouped renderings.

with the fold primitives:

1. the time-ordered view is the default render of `v7.console`
2. a sibling render is registered at `v7.console.view.by-zenka` that
   groups by `instance_id` → zenka_name [ data already extracted in
   `v7.handler.process_output_line` ]
3. each per-zenka group is a foldable child node at
   `v7.console.view.by-zenka.<zenka>` — `base.ui.render.tree` handles
   recursion automatically [ branch-as-complete-tree ]
4. a globally-reserved hotkey moves the currently-bound slot's
   *content_address* between `v7.console` and `v7.console.view.by-
   zenka` via `base.slot.bind_content` — the *slot* doesn't move, the
   *address it points at* does. zero re-layout, zero re-paint outside
   the slot

note the elegance: the same `v7.console` store layer feeds *both*
renderings. no separate per-zenka log files, no duplicated state, no
view-specific filtering at ingest. fold-back-as-presence in full
force. detailed task: `v7-console-per-zenka-tree-view.md` below.

## the configure zenka — generic fallback console

per `topic-global-ui-menu-tree`, `configure` is the planned generic
fallback / decision-surface zenka. its current state
[ `configuration/zenki/configure/` plus `modules/configure.init_code`
returning 0 ] is a stub.

the proof-by-being-its-own-first-customer claim: **if the fold
primitives + slot addressing + render-tree baseline are right,
`configure` becomes a very thin zenka** — its modules are mostly the
tri-layer `configure.ui.query.* / configure.ui.render.* /
configure.cmd.ui-show`, each delegating to the base fallbacks when no
zenka-specific override is registered. its actual work is
*navigation* over the global namespace, deciding where to land the
user's attention next [ "we have ambiguity, here are the choices, you
pick" ] — exactly the credential_fabric pattern, generalised one level.

what `configure` provides on top of the base render-tree:

- a default landing address [ e.g. `system.configure.root` ] that
  unfolds the top-level reachable namespace as foldable children
- a decision-prompt sub-namespace `configure.decision.<id>` for
  "logical choice options grouped" — each decision is itself a
  foldable address, each option is a foldable child, selection is
  `base.ui.unfold` of the chosen option
- *no custom rendering per zenka* — every node uses the base render-
  tree by default; a zenka may register an override at
  `<zenka>.ui.render.default` if and when it wants one

detailed task: `configure-zenka-fallback-ui.md` below.

## the installer zenka — greenfield template-driven flow

a new zenka [ `configuration/zenki/installer/`,
`modules/installer.*` ] for guided template-driven install flows
[ profile installation, dependency provisioning, key generation,
zenka registration ]. the design move: **the installer is configure
with a sequence policy** — it walks a template tree of nodes in a
defined order, presenting each as a foldable decision via the same
`configure.decision.*` machinery. each step is a foldable address;
"back" is fold; "forward" is unfold of the next step.

this is *deliberately* the smallest possible scope: no installer-
specific UI primitives, no installer-specific state machine [ the
namespace is the state machine ], no template DSL [ templates are
just nested addressable nodes under `installer.template.<name>` ].

if the boundary between configure and installer turns out to be
artificial when implementing, fold installer's task back into
configure's. the two are listed separately because the *flow ordering*
is a distinct policy worth naming, not because the implementations
must be separate. detailed task: `installer-zenka-template-flow.md`
below.

## task tree [ rooted here ]

this doc is the second-level root under
`CONSOLE-FOLD-TREE-PHILOSOPHY.md`. the queue:

```
CONSOLE-FOLD-TREE-PHILOSOPHY.md  [ first principles ]
├── console-fold-primitive.md             [ generic verbs ]
├── console-foldable-render-baseline.md   [ generic policy ]
├── console-stdio-slot-addressing.md      [ generic addresses ]
└── STDIO-RELAY-FOLD-APPLICATION.md       [ this doc — first surfaces ]
    ├── v7-stdout-foldable-relay.md       [ generalise v7's relay ]
    ├── v7-console-log-filter-overlay.md  [ usage example A ]
    ├── v7-console-per-zenka-tree-view.md [ usage example B ]
    ├── configure-zenka-fallback-ui.md    [ first generic consumer ]
    └── installer-zenka-template-flow.md  [ second generic consumer ]
```

dependency order [ smallest-first ]:

1. the three generic primitives [ console-fold-primitive,
   console-foldable-render-baseline, console-stdio-slot-addressing ]
   land first — every subsequent task in this doc's queue depends on
   their verbs and policies existing
2. `v7-stdout-foldable-relay.md` — extends the existing v7 relay to
   expose `<zenka>.stdout` as an addressable foldable element;
   prerequisite for the two usage-example tasks
3. `v7-console-log-filter-overlay.md` and
   `v7-console-per-zenka-tree-view.md` — can land in either order
   after [2]; either proves the framework end-to-end
4. `configure-zenka-fallback-ui.md` — independent of v7-stdout work;
   could land in parallel after the three generic primitives. listed
   after [3] because the user's framing prioritises the v7 console
   usage examples as the immediate win
5. `installer-zenka-template-flow.md` — depends on
   `configure-zenka-fallback-ui.md`'s decision-prompt machinery being
   in place; lowest priority in this tranche, may be folded back in

## non-goals [ for this document ]

- not a re-implementation of `base.log` / `base.logs` / v7-relay
  internals — only an addressing/render layering on top of them.
- not a new IPC mechanism — slots reuse the existing
  `/dev/shm/.7/STDOUT/<sock>` ring + the cube routing layer.
- not a vterm rewrite — vterm.* is the substrate for richer views,
  not a target of new work in this doc's queue.
- not a hotkey assignment plan — concrete keystrokes belong to the
  individual task files [ and to a later UX pass ].
- not a discussion of the harmonic-score authorization branch from
  `topic-global-ui-menu-tree` — orthogonal axis, not in this doc's
  scope.

## final note

the user's framing said this in one sentence and it bears repeating:
**"having stdio makes the zenka a forward operating base, and its
current stdio usage fully reconfigurable."** that *exists today* in
fragments — v7 already relays, stores, and pattern-matches zenka
stdout — and the fold primitives + slot addressing don't add new
plumbing so much as let the existing plumbing be *spoken about*
[ folded, moved, filtered, grouped ] in one addressable language. the
two starting-point zenki [ configure, installer ] then prove the
framing by being the smallest possible consumers of that language —
they have almost no zenka-specific code because, per the philosophy
doc, *they don't need any*.

#,,..,,,.,...,,,.,,,.,,,.,.,,,.,.,,..,,..,,.,,..,,...,..,,,..,,,.,,,.,,,,,,,,,
#7RA5Z3RJJ3X3KHQ5SDDVTYW5VX6YT6U7B2FOOL4Q4ULHJEBYCMILADVIMARJBZFQQKP6AQKY2RFVC
#\\\|5DZ5NOXJLY3AB6T6ZKOPZUI6U2FIF4YRB6ZAU2ICTEGYKSQM7EX \ / AMOS7 \ YOURUM ::
#\[7]4AQPDQX3GOMBRHIK2M56GPJKZ2ETNDHQ22T7SC65PHLSGSWLH2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
