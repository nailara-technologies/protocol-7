# task: stdio slot addressing scheme + move/render/fold against it

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

closes the "slot/address equivalence" implication from
`data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` — gives stdio slots
ID addresses so that "moving a slot" and "addressing a node" become
the same operation against the same address space. the philosophy
treats this equivalence as already-true conceptually; this task makes
it true mechanically.

depends on `console-fold-primitive.md` (the verbs) and
`console-foldable-render-baseline.md` (the layout policy).

## context

design doc [ read first ]:
- `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`
- memory note `topic-global-ui-menu-tree` — the stdio-slot-addressing
  thread originates here
- memory note `topic-addressing-trinity` — named tree + checksums +
  timestamps; this task extends it to stdio slots
- `base.p7refs.gen_template_chksum` for the P7REF reference layer
- `topic-stream-transport-layer`, `topic-stream-reply-modes`,
  `topic-stream-framing-protocol` (memory) for how streams already
  carry addresses elsewhere in P7

## signatures note

do NOT add stub signatures. do NOT modify whitelists. lowercase
comments, `[ word ]`, `$ARG`.

## addressing scheme

a stdio slot is an *address inside a parent surface* [ tty session,
log buffer, fullscreen view ]. the address format mirrors P7REF:

```
SLOT:<chksum7>:<surface>.<row>.<col>+<cols>x<rows>
```

- `<chksum7>` — AMOS-checksum of the slot's stable identity tuple
  `( surface_address, name )` — survives geometry changes
- `<surface>` — dot-path to the parent surface in the namespace
  [ e.g. `nshell.session.42`, `view.fullscreen.0` ]
- `<row>.<col>` — origin within the surface
- `<cols>x<rows>` — current dimensions

the *stable* part is `SLOT:<chksum7>:<surface>` — geometry trails are
mutable. operations refer to slots by the stable prefix; geometry
joins the address on render/move.

## modules to implement

### base.slot.register

```perl
## [:< ##
# name  = base.slot.register
# descr = register a new stdio slot, returning its address
# param = { surface, name, content_address?, geometry? }
```

- writes a registry entry under `<base.slots>{<chksum7>} = {
  surface, name, content_address, geometry }`
- returns the full slot address (SLOT:...) as a string

if a slot with the same `( surface, name )` tuple already exists,
returns its existing address [ idempotent registration ].

### base.slot.resolve

```perl
## [:< ##
# name  = base.slot.resolve
# descr = resolve a slot address to its current registry entry
# param = { address }
```

accepts either the stable prefix or full geometry-suffixed form.
returns `undef` if the chksum7 isn't registered.

### base.slot.move

```perl
## [:< ##
# name  = base.slot.move
# descr = move a slot to a new surface and/or geometry
# param = { address, surface?, geometry? }
```

- looks up the slot by chksum7
- updates surface/geometry in the registry
- if `content_address` is set, calls
  `base.ui.unfold(content_address, slot_budget=new_geometry)` and
  blits the result into the new slot
- returns the slot's updated full address

per the philosophy: moving a slot is one address-space op. the
slot's *identity* (chksum7) is invariant under the move; the
*location* changes. this is the same identity/location split that
P7REF performs for arbitrary references.

### base.slot.fold

```perl
## [:< ##
# name  = base.slot.fold
# descr = fold a slot to its handle form (slot disappears from surface)
# param = { address }
```

- looks up slot, clears `geometry` to `undef`
- removes from the surface's render set but KEEPS the registry entry
  [ this is the "presence is undisturbed" guarantee — the slot still
  exists at its address ]
- returns the fold handle line via `base.ui.fold`

### base.slot.unfold

```perl
## [:< ##
# name  = base.slot.unfold
# descr = unfold a slot back into a surface
# param = { address, surface?, geometry? }
```

- if surface/geometry omitted → re-uses the last known values from
  the registry
- if no last-known values → caller error [ slot has never been placed ]
- otherwise → equivalent to `base.slot.move` with the unfolded geometry

### base.slot.bind_content

```perl
## [:< ##
# name  = base.slot.bind_content
# descr = bind a content address into a slot
# param = { slot_address, content_address }
```

stores the content_address on the slot entry. subsequent
folds/unfolds/moves use it for rendering. *changes in the bound
content_address auto-render to the slot* via a watch-channel
[ implementation may defer the auto-render to a follow-on task; for
this task, manual re-render via `base.slot.refresh` is acceptable ].

### base.slot.refresh

```perl
## [:< ##
# name  = base.slot.refresh
# descr = re-render a slot's bound content into its current geometry
# param = { address }
```

idempotent; no-op if the slot is folded.

## acceptance

- registering a slot returns a stable address; registering the same
  `( surface, name )` again returns the same chksum7.
- binding `credential_fabric.registry` into a 60x10 slot and calling
  refresh produces a fitted render per
  `console-foldable-render-baseline.md`.
- moving that same slot to a different surface (e.g. nshell session
  → fullscreen view) preserves the chksum7 in the new address.
- folding the slot removes it from the surface's render but
  `base.slot.resolve` against its stable address still returns the
  registry entry — i.e. *presence in the network is undisturbed*.
- unfolding without explicit geometry restores the last-known
  geometry — round-trip is lossless.

## non-goals

- no UI for slot manipulation [ the verbs first; UI later ]
- no cross-surface auto-relocation policy [ moves are explicit ]
- no priority/z-order between overlapping slots — assume disjoint
  geometries within a surface; conflict resolution is future work.
- no persistence to disk across restarts [ per philosophy: the
  network *is* the persistence; restart re-registration is the
  expected idiom; persistent slot identity across full restarts is
  a downstream concern bound to the larger zero-travel migration
  thread, see `topic-layer-matrix-convergence` ].

## harmony checks

```
harmony base.slot.register
harmony base.slot.resolve
harmony base.slot.move
harmony base.slot.fold
harmony base.slot.unfold
harmony base.slot.bind_content
harmony base.slot.refresh
```

#,,.,,,.,,,.,,..,,,..,,,,,.,,,,..,,,,,,,.,,,,,..,,...,...,.,.,.,.,.,.,...,..,,
#FXRFII7MEZWE7OIP634YXZM7TDF7TSON7BGP5JT7YMEMYK7PTQ5PSBWC42H7NPXJP5SKLHVBMXFHK
#\\\|HJFOHOMJ4LMOYYYDGR7CXMV43SAVKL6MPEZZ3DGNDR4PSA4QTM4 \ / AMOS7 \ YOURUM ::
#\[7]P2CRHWMUUYNZGILRXCZYXY2EUM2SXRC2VT3KGN43YFUFTOQHCYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
