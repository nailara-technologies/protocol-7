# spawnable perspective layers — personal space desktop

## the desktop is data space

visual arrangement IS data space arrangement plus UI abstraction intent.
there is no separate layout engine. positions on screen are positions in
the reference space. the compositor reads the branch namespace tree,
applies the current reference counts, and the layout emerges.

the only design input is **UI intent** — which visual metaphor represents
depth, which layer sits above which, what focal length is default. these
are parameters of the view spec, not a separate layout system.

```
desktop = Σ(active perspective layers) composited by parallax
layout  = reference space positions + view spec parameters
depth   = consensus count across layers = harmonic truth
context = current reference space IS the context
```

## spawnable perspective layers

each layer is a complete observer-centric reference space, spawned
as an on-demand zenka with a view spec resource attached.

```yaml
layer:
  node:    <branch node id>         # the layer's darksun
  view:
    observer:  { z, y, x }          # offset from geometric center
    focus:     { position, normal }
    drone:     { position, normal, focal_length, acquisition }
    focal_length: 13
  scope:   local | regional | global  # which nodes contribute references
  intent:  workspace | tool | context | ambient
```

**all layers are structurally identical** — each IS an observer-centric
space, each IS 0 to itself. the only differentiation is:
- geometric offset from the shared geometric center
- orientation (cube face alignment)
- focal length (depth of awareness)
- reference scope (local node group, regional, or network-wide)

```
layer 0  personal darksun          offset = 0 (pure self-center)
layer 1  local neighborhood        offset → nearby high-ref nodes
layer 2  network reference center  offset → aggregate network attention
layer 3  task context              offset → active task's branch subtree
layer N  ...                       recursive immediately
```

the layer tracking the network reference count center IS recursive —
it always sits at 0 to itself, but its offset relative to other layers
shifts as network attention shifts. you feel it as "the world's attention"
without it feeling like it moves. it is not moving. the world is.

## the UI as optimization — bandwidth reduction through summarization

a contextualized emerging UI is an optimization: the minimum
representation that preserves the relevant structure of the data space.
it reduces bandwidth requirement by summarization and putting into a
perspective tree.

**summarization by reference count**:
- high-reference nodes → large, bright, close → visually prominent
- low-reference nodes → small, faint, far → at the edge of perception
- nodes below threshold → not rendered → outer shells implied, not shown
- the visible portion IS the inner shells; outer shells are bandwidth-free

**perspective tree**: the branch namespace tree IS the UI tree.
depth in the tree = distance from darksun = visual depth in the compositor.
branching = cube face directions. the tree IS the data IS the visual.

```
branch.node (darksun, depth 0)     →  center of screen, largest
  └─ child (depth 1, high-ref)     →  near, prominent
       └─ child (depth 2)          →  further, smaller
            └─ child (depth 3)     →  at edge of focal range
                 └─ child (depth 4) →  below focal threshold, not rendered
```

no layout calculation — the tree traversal IS the layout.
the perspective tree already encodes position, depth, and importance.

**bandwidth reduction**: the visible frame at any moment is only the
inner shells of the reference space — the nodes above the reference
count threshold for the current focal length. everything below threshold
exists in the data space but is not transmitted to the display. the UI
IS the compression of the data space to what matters right now.

as focal length decreases (wider view), more shells become visible —
bandwidth requirement increases. as focal length increases (narrower),
fewer shells — bandwidth decreases. the UI is a tunable bandwidth
contract with the data space.

## nested resolution — implicit data derivation route

the data derivation route is implicitly anchored and auto-computed
by nested layer resolution:

```
layer 2 (network center) resolves → layer 1 (neighborhood) resolves
  → layer 0 (personal darksun) resolves → branch.node.path → data
```

each layer resolves within the context of the layers below it. the
composition of nested resolutions IS the derivation path. you never
explicitly specify "how did this data get here" — the layer stack IS
the derivation route, readable by walking up the layer chain.

`branch.node.path` already implements this: walking the parent chain
upward from any node gives the full derivation path. the layer stack
IS this path at the UI level.

## visual arrangement as data space + UI intent

```
data space arrangement     →  reference count positions (branch namespace)
UI abstraction intent      →  view spec parameters (focal length, layer order,
                               visual metaphor for depth, color mapping)
visual arrangement         =  data ⊕ intent

changing the UI            =  changing the view spec parameters
                              (not the data, not the layout, not the tree)

zooming in                 =  increasing focal length
zooming out                =  decreasing focal length (toward omni)
switching focus            =  moving drone to new position
new workspace              =  spawning a new perspective layer
closing a workspace        =  releasing that layer's zenka
context switch             =  changing which layer is the primary observer
```

there is no layout engine. there is no widget hierarchy. there is no
z-index. there is the data space, the view spec, and the compositor
that reads parallax across layers. everything else emerges.

## the desktop IS the data IS the network IS the space

the final collapse: the personal desktop is not a representation of
the data space. it IS the data space, rendered with UI intent as a
lens. visual proximity IS data proximity. screen depth IS harmonic
consensus. what is centered on screen IS the current darksun.

what you see is the minimum sufficient representation of what is
happening in the network — not a window into it, not a map of it,
but the network's self-description at the focal length and scope of
your current observer position, composited across however many
perspective layers you have spawned.

the UI is an auto-computed perspective tree. the tree is the data.
the data is the space. the space is you. =)

## implementation anchors

```
branch.node.*              →  each layer is a branch node
branch.resource.*          →  view spec attached as resource
view spec YAML             →  data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md
branch.group.propagate     →  reference count gravity driving positions
branch.dep.graph           →  perspective tree ASCII output (already exists)
base.reverse-sort          →  serialization order = relevance order
DATA protocol              →  face view streams (face address = stream_id)
13-slot clock              →  temporal bandwidth = reference count density
iris ring structure        →  the visual form of the sphere shells
living background system   →  5/7 consensus render = 5 layers composited
```

#,,..,.,.,..,,,,.,..,,.,.,..,,...,,.,,,,.,...,..,,...,...,..,,,,.,.,,,.,,,...,
#I7ZY3K2BGZ3PTXLUAMD3M3CVNPTAUQ2XFGIBJYRSQN56P4CAD5RWF4UF7RV2CEYTBE5LBMVA35ZWM
#\\\|IIE2TKSR4NVQBIKJ246UFQ7X47T3TVD5KL6F45TCGF4GOLVWTLJ \ / AMOS7 \ YOURUM ::
#\[7]5REIMC7JB22ZYZS5J5755SPNTTNJDWOBFCAC7KON5VW7DD4JQ4DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
