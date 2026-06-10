# console fold tree — design philosophy

[ origin: 2026-06-10 — user-articulated capping principles on top of the
  global-ui-menu-tree vision; this document promotes those principles to
  a first-class design axis for protocol-7's console/UI layer and to a
  root index for the related task queue. ]

related primary sources [ read in order if new to this thread ]:
- memory note `topic-global-ui-menu-tree` — full origin, stdio-slot
  addressing, P7REF, namespace-commitment, set-up/configure starting
  points, omnipresence/eternality closure
- `data/md/design/HARMONIC-TREE-ADDRESSING.md`
- `data/md/design/TREE-PROTOCOL.md`
- `data/md/design/CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md`
  [ the proven query/render/dispatch layering this doc generalises ]
- `data/md/design/SPAWNABLE-PERSPECTIVE-LAYERS.md`
- memory notes: `topic-addressing-trinity`, `topic-perspective-layers`,
  `topic-namespace-tree-intelligence`, `topic-ascii-desktop-domains`,
  `topic-frame-plugin-slots`

## the two principles

### 1. fold-back as the resting state of presence

> "when you see your data getting folded back into the tree, you already
>  know its presence in the network it is folding into is, by definition,
>  undisturbed — and the presence of the network practically symbolises
>  availability in terms of short-path contextualised reachability."
>                                                          — user, 2026-06-10

a protocol-7 console element [ a zenka panel, a result table, a task
listing, a log slice, a settings sub-tree ] is never *gone* when it
disappears from the screen. it is **folded** — collapsed into a single
addressable handle that still names the thing, still routes to the thing,
still represents the thing's presence in the network. unfolding it is a
local operation against an addressable reference, not a re-creation.

the visual disappearance of detail is therefore a *correctness claim*:
"this remains available at this address." that claim is precisely what
[[topic-addressing-trinity]] (named tree + checksums + timestamps) and
P7REF (`TYPE:CHKSUM7:ADDR_B32` — see `base.p7refs.gen_template_chksum`,
`plugin.storage.p7ref.init_code`, `discover.orbital.get_local_p7ref`)
already underwrite for data in motion. the design move is to **let the
console rely on it** — to treat *fold* as the default, *expand* as the
exception requested by attention.

corollaries that follow immediately from this:
- there is no "close button." closing is folding, which is reversible by
  address. the icon that folds is the icon that unfolds.
- there is no separate "minimised state list." the parent node in the
  tree IS the minimised state list — anything folded *into* a node is
  reachable *via* the node, by definition.
- a search/filter handler can sit **behind** a log without removing the
  log. the unfiltered stream is folded at its own address; the filtered
  view is unfolded as a sibling at a related address. toggling between
  them is *moving the rendered slot*, not destroying state.
- *every visible element is implicitly an unfolded reference* — its
  rendered form is one expansion of a foldable handle, never the only
  form it can take.

### 2. a branch node is already a complete tree

> "seeing a branch node AS a complete tree already — pluggable, fully
>  expandable, always category-complete. recursive namespacing: the
>  intent to universally enable a typing-and-subtyping-based
>  functionality, instead of [dimensionally] flat reference pools."
>                                                          — user, 2026-06-10

every node in the menu/console tree must be addressable *as if it were
the whole tree*. its sub-namespace is the analogue of the root's
sub-namespace; the same primitives work on it; the same render layer
draws it; the same fold/unfold dance applies. there is no
"leaf-vs-branch" axis. there is only `node`, which may currently happen
to expand into zero, one, or many further nodes — none of which changes
what kind of thing it is.

this is the recursion underwriting protocol-7's existing module
namespacing already: `credential_fabric.ui.query.slots` is *not* a
flat triple-segmented label — it is `credential_fabric → ui → query →
slots`, every prefix of which is itself a complete tree of further
function. the design move is to **let the console see what the
namespace already is**, instead of treating namespaces as flat strings
that happen to contain dots.

this directly contradicts the "dimensionally flat reference pool"
shape that creeps into UIs by default — sidebars of unrelated items,
flat result tables, "tag clouds," registries-as-lists. those are
*projections* of a tree under a poor view; they should never be the
underlying model.

the related claim about code:

> "clean function is the source of truth — especially when self-evident
>  and error-free because it's small enough as an element [group], yet
>  perfectly smoothly fits into the parent structure, becoming improved
>  (or more cleanly defined) because of it."         — user, 2026-06-10

this is the *coding-style* analogue: a module that fits its parent
namespace cleanly is improved *by virtue of* the fit. the parent
namespace is a structural truth the module aligns with; alignment is
the improvement. the same shape applies to console nodes: a node that
fits the address it occupies *is improved by occupying it well*. fit is
not cosmetic.

## why these two principles are one principle

both principles are forms of the same generative claim from
[[topic-namespace-tree-intelligence]] — *the tree is the mechanism, not
the diagram of the mechanism*.

- fold-back works *because* presence is already established by the
  address; nothing further must be done to "keep" the folded element
  alive.
- branch-as-complete-tree works *because* every address is a root of
  the same recursive structure; nothing further must be done to "make"
  a sub-namespace tree-shaped.

both are consequences of namespace commitment being enough — the same
move that closes the bootstrap list in [[topic-global-ui-menu-tree]]
("once you commit to the namespace, the rest falls out").

## relation to the existing menu-tree vision

this document does not replace `topic-global-ui-menu-tree`. it
*localises* its closing principles into the console layer specifically:

| menu-tree vision                       | console fold-tree principle    |
|----------------------------------------|--------------------------------|
| stdio slots as addressable IDs         | folded element = address; unfolded = render of address |
| `ui.query.* / ui.render.* / cmd.ui-show` (credential_fabric) | becomes the default tri-layer for *every* foldable console element |
| set-up / configure as starting points  | both are root nodes whose entire sub-tree is foldable per the same rules |
| zero-travel migration                  | unfolding a folded handle elsewhere is the same operation as migrating its presence — no new mechanism |
| namespace-commitment ⇒ everything      | both principles in this doc are the *console-layer instances* of "everything" |

## implications for implementation

### concrete representation of a folded element

a folded element on a protocol-7 console renders as exactly one line of
the form:

```
.:[ <kind> ]:[ <short-address> ]:[ <one-line summary> ]:.
```

where:
- `<kind>` — namespace-derived type [ `zenka`, `slot`, `task`, `log`,
  `result`, `view`, ... ] — the *type* part of P7REF, no `TYPE:` prefix
  necessary in display since the bracket position is canonical
- `<short-address>` — abbreviated dot-path to the node within its
  parent's namespace [ never the full path; the parent is already
  visible above ]
- `<one-line summary>` — the smallest cell of state that names this
  element to a human reader; for variable content, time-folded
  [ "5 results" / "2m idle" / "running" / "23 entries since 10:14" ]

the visual idiom `.:[ ]:.` matches the existing
[[topic-frame-idiom-convergence]] ascii.frame work — a folded element
is a degenerate frame, exactly one row tall. this is intentional:
*folding is the limit case of framing*, not a different category.

### what triggers fold

four orthogonal triggers, in priority order:
1. **explicit** — user issues fold on a specific address [ keystroke,
   `p7c <zenka>.ui.fold <address>`, click ]
2. **time-based** — an element more than N seconds without state change
   AND not currently selected AND parent frame approaching width/height
   limits → auto-fold [ the "fold once there's more data to manage"
   already mentioned in topic-global-ui-menu-tree ]
3. **structural** — when the rendering width/height budget is exceeded
   for the current parent frame, fold the lowest-priority children
   first [ priority = recency × interaction-affinity ]
4. **routing** — when a previously unfolded element is moved to a slot
   smaller than its expanded form would fit, it folds automatically;
   the move is not refused

### what triggers unfold

three triggers, all reversible:
1. explicit user request against an address
2. an incoming state change whose *importance score* (per the parent
   zenka's metric) exceeds an unfold threshold — equivalent to "this
   wants attention"
3. arrival in a slot whose budget can accommodate the expanded form

### the always-working hotkey

per the user's note: a hotkey "represents presence" of contextualised
functionality. the menu invocation key should:
- be globally reserved [ never overridden by any subview ]
- on press, unfold the *nearest enclosing menu node* of the currently
  focused element [ never the root; always the local-context menu ]
- on second press, unfold its parent, walking up; the menu *grows
  outward* rather than appearing from a single root

this matches the [[topic-perspective-layers]] state-persists-behind-a-
swappable-view mechanism: pressing the hotkey doesn't *open* a menu,
it *unfolds* one that was always there at the address.

### branch-as-complete-tree → module namespacing maps directly

a console node at address `set-up.profile.network` must behave as if
it has its own:
- `set-up.profile.network.ui.query.*`
- `set-up.profile.network.ui.render.*`
- `set-up.profile.network.cmd.ui-show`
- foldable child nodes of the same shape

if any of those don't exist *yet*, the default behaviour is a generic
fallback: `base.ui.query.fallback`, `base.ui.render.fallback`,
`base.cmd.ui-show.fallback`. **a node never needs to declare itself a
node** — its presence in the namespace is the declaration. zenki
acquire UI by being addressable, not by implementing a UI interface.

this is the concrete reason `configure` (the planned generic
fallback zenka, see topic-global-ui-menu-tree) is small to build:
it's the *fallback* end of the same tri-layer that
credential_fabric proved at the *specific* end. it doesn't need
custom rendering per zenka; it needs the base node-renders-as-tree
behaviour, configurable per parent.

### terminal-width-aware baseline

the raw default render of any address must be terminal-width-aware
and fold-friendly *before* any frame template is applied. concretely:
- given a width budget, render children as one-line folded handles
  until the budget is exhausted, then fold the rest into a trailing
  `[ +N more ]` handle that is itself an address
- given a height budget, prefer folding leaf-level state cells before
  folding entire sub-trees [ shallow folds before deep folds ]
- the `[ +N more ]` handle is itself a folded node, addressable, and
  unfoldable like any other — it is not a special widget

frames per [[topic-frame-plugin-slots]] are *enhancements* over this
baseline, never preconditions for correctness.

### slot/address equivalence (carry-over from menu-tree vision)

once stdio slots have IDs, "moving a slot" and "addressing a node"
are the same operation against the same address space. fold/unfold,
move-between-slots, expand-fullscreen, fold-back-into-log-stream all
reduce to:

```
resolve(address) -> handle
render(handle, slot_address)            ## unfold/move-into
fold(handle) -> address_alone           ## back to a one-liner
```

one verb set, applied at one address space.

### the network IS the persistence

per the user's principle: "the presence of the network practically
symbolises availability in terms of short-path contextualised
reachability." folded elements do not need to be persisted to disk by
the console layer. their presence is already underwritten by:
- namespace commitment of the owning zenka [ the address exists ]
- P7REF resolvability [ the reference is real ]
- the existing crypto/routing closure ([[topic-checksum-addressing]],
  C25519 keys ↔ checksums ↔ BASE32 — already live)

the console's job is *to fold confidently* — to let the network do
what the network already does, instead of trying to keep state itself.

## implementation queue [ rooted here ]

new tasks generated from this document [ see `data/tasks/` ]:
- `console-fold-primitive.md` — the generic `base.ui.fold.*` /
  `base.ui.unfold.*` / `base.cmd.ui-show.fallback` primitives that any
  zenka inherits by being addressable. this is the smallest first step.
- `console-foldable-render-baseline.md` — width/height-aware default
  rendering of an address as foldable children, including the `[ +N
  more ]` trailing handle as a real address.
- `console-stdio-slot-addressing.md` — concrete addressing scheme for
  stdio slots (extension of [[topic-addressing-trinity]]) plus the
  move/render/fold operation against it.

existing tasks rerooted under this doc [ see their headers for the
specific relation note ]:
- `credential-fabric-ui-frames.md`
- `credential-fabric-ui-interactive.md`
- `context-aware-scale-navigation.md`
- `reasoning-branch-orchestration.md`
- `valued-tree-task-zenka-integration.md`
- `tree-sort-trunk-route-page.md`
- `branch-calc-route-navigation.md`

each carries a `## relation to CONSOLE-FOLD-TREE-PHILOSOPHY` note
identifying which principle [ fold-back / branch-as-complete-tree /
both ] it concretely implements or feeds.

## non-goals [ for this document ]

- this doc does **not** propose new module code; it proposes the
  *interpretive frame* that makes the existing menu-tree vision
  immediately implementable on top of the already-live primitives
  (ascii.frame.*, credential_fabric's tri-layer, P7REF, addressing
  trinity).
- it does **not** dictate keystrokes or widget chrome; concrete
  hotkey/colour/border choices belong to the task files.
- it does **not** redesign authorization; the same "verification by
  default, preference only as an exception channel" bound from
  topic-global-ui-menu-tree's final section applies unchanged.

## final note

the two principles in this document are not new mechanism. they are a
**license to act on what the system already supports** — to treat
folded as the default state of presence, and to treat every node as a
complete tree, *because both are already true* of the protocol-7
namespace, P7REF, and the addressing trinity. the console layer's job
is to stop denying it.

#,,,,,,,.,.,.,,,.,..,,..,,..,,,.,,.,.,,..,.,,,..,,...,...,...,.,.,,.,,,,,,..,,
#2ETKNPGE5DR4VG7JO253JUCJT7TEOIBXAAC75XRGUZBQC6DFHKMTWJK2KHHRLLM7JNZA5QLCJT3CM
#\\\|K4NDISZZ7ZQ7GACECOAXPU53HTWN5IFNDQBU7JYC5INCVYWJ4BH \ / AMOS7 \ YOURUM ::
#\[7]ADABHCCLMWP327EXODQEWX4BXFLQJN7LW7FU7VPMB735NZDUTCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
