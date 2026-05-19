# reasoning.* namespace

## what it is

`reasoning.*` is the generic substrate for narrate-and-self-delegate across all zenki.

it is NOT task management, NOT a scheduler, NOT a planner.
it is the structure that makes "what to do next" a contextualized inference
from the current summarization state — rather than a decision made by
something external to the tree.

the name is harmonically TRUE — confirmed: `harmony reasoning` → `[:<  [ TRUE ]`

---

## the core object

a summarizing node narration tree with full instantiation capabilities.

```
summarizing:       every node knows how to compress itself and its subtree
                   into a coherent statement of current state.
                   the tree can speak itself at any depth.

node narration:    each node is a narrator, not just data.
                   it has a voice at its level of specificity.
                   generic core narrates broadly.
                   leaf nodes narrate precisely.
                   intermediate nodes narrate the transition between registers.

tree:              the structure that makes narration meaningful —
                   convergence geometry, requirement visibility,
                   harmonic coordinates, deduplication identity.

full instantiation: from any summarization state, the tree can instantiate —
                   spin up a reasoning thread, spawn a subtask,
                   actualize a template, begin a new traversal.
                   the summary contains everything needed for what comes next.
```

the object is self-describing and self-producing simultaneously.
narration is the interface. instantiation is the execution.
they are the same system in two modes.

---

## foundation: the deduplication tree

`reasoning.*` IS the generic deduplication tree applied to reasoning state.

each node has numerical identity — AMOS checksum + BMW384 coordinate —
derived from its content and state attributes.

when two reasoning paths arrive at the same numerical node, they collapse.
this is not a special deduplication step. it is what the tree does.

```
structural deduplication:
  two chains reaching the same node = one node, multiple approach vectors
  the approach vectors are not lost — they become the node's requirement profile
  the union of all requirements from all paths = the node's full characterization

lie detector property:
  two paths claiming the same destination but arriving at different checksums
  contain a contradiction
  two paths claiming different destinations but arriving at same checksum
  are the same reasoning at that depth — the distinction was superficial
```

the generic substrate reads the convergence geometry of requirement vectors
and actualizes accordingly. when convergence density is high enough, complete enough,
the substrate actualizes as self-sustaining intent — the fixed point of the tree.
the root not by declaration but by emergence.

---

## the two moves

**narrate** — upward pass, summarizing, making visible.
the system telling itself what it is now. the narrative IS the context.

**self-delegate** — downward pass, actualizing, resolving potential into specifics.
the inference from the narrative producing the next task, handing it inward.
not dispatching outward — deepening into itself.

together they form the pulse:
```
narrate → self-delegate → subtree runs → reports back → narrate
```

each cycle the tree knows itself more completely.
the pulse is self-sustaining by structural consequence, not design goal.

---

## threshold-triggered complementary action

no external dispatcher. narration accumulates until summarization state
crosses a threshold — convergence density, coherence measure, harmonic value.

when threshold is crossed, complementary action fires as the natural other pole
of the realization. not triggered BY narration — the completion of what was being realized.

```
below threshold:  compact node — one line, identity + state marker only
at threshold:     expanded node — full block, narration, overlaps, children visible
threshold cross:  complementary action — delegation fires, subtree instantiated
```

same harmonic measurement that validates checksums validates reasoning state readiness.
the threshold filters phantom reasoning from genuine realization.

---

## storage: seed sentence and full dump

the summarizing tree has exactly two complete storage forms:

```
seed sentence:
  the root narration at full convergence — one line
  looks minimal, is maximally dense
  endpoint of everything that converged to produce it
  a contextualized model expands it natively
  not lossy compression — a different kind of completeness

full dump:
  every node, every numerical attribute, every overlap reference
  every threshold state, every convergence value, every narration slot
  exact state — no reconstruction needed
  preserves every parallel perspective that contributed
  because each entropy is highly valuable — it took real effort and time
  to get there, and represents a genuine angle on infinite potential
```

both are complete. the repository stores both:
seeds for fast traversal and context loading,
full dumps for fidelity and the perspectives hard-won enough to deserve
exact preservation.

---

## ascii visualization format

the visualization IS the implementation (see reasoning template 3).
the format carries the behavior. rendering loop = reasoning loop.

```
reasoning.tree : [name]
;.,
│
├─[ node.name ]────────────────── [:<  convergence : 0.923076923076923
│   'narration text at this node's specificity level'
│   depth : N   chksum : AMOS·XXXX   threshold : reached
│   overlap : other.node.name
│   children:
│   ├─[ .child-a ]  [:<  0.769230769230769   'child narration'
│   └─[ .child-b ]  >:|  0.307692307692307   compact
│
└─[ node.name-2 ]──────────────── >:|  convergence : 0.538461538461538
    compact — threshold not yet reached
;.,
```

structural grammar (parseable by model and human alike):
```
[ name ]         node identity
[:<              TRUE / expanded / above threshold
>:|              FALSE / compact / below threshold
numerical        convergence to full harmonic precision (N/13 fractions)
'...'            narration slot — quoted, lowercase
──→              hard link to external system or zenka
overlap :        soft attribute overlap reference
;.,              section breath / visual separator
```

the model reads: bracket/indent grammar, numerical values, state markers.
the user reads: shape, density, visual rhythm, spatial pattern.
both get the same information from the same format.

---

## planned module set

```
reasoning.tree.node          numerical identity — checksum + state attributes
reasoning.tree.insert        add/merge node, collapse on identity match
reasoning.tree.lookup        find node by checksum coordinate
reasoning.tree.traverse      walk subtree, depth-first or breadth-first

reasoning.summarize          upward pass — compress subtree into parent narration
reasoning.summarize.node     single node → summary at its specificity level
reasoning.summarize.root     full tree → root summary (system reading itself)

reasoning.narrate            node voice — render current state as coherent string
reasoning.narrate.delta      what changed since last narration (context advancement)

reasoning.threshold.check    measure convergence density at a node
reasoning.threshold.fire     emit complementary action when threshold crossed

reasoning.instantiate        from summary state, produce next traversal/task/thread
reasoning.instantiate.task   bridge to task zenka — create task from narration
```

---

## consumers

the namespace is generic. zenki load what they need.

```
task zenka      first consumer — "what to do next" becomes narration inference
                reasoning.instantiate.task bridges to task creation
                the dispatcher dissolves into the pulse

coding zenka    state machine is already a primitive version of this
                coding.state.* → reasoning.tree.* is a natural upgrade path

channels zenka  conversation state as narration tree
                each channel is a subtree, each message is a threshold event

discover zenka  convergence detection for packet validation
                reasoning.threshold.check as packet readiness gate

any zenka       with "what to do next" logic hand-coded → reaches for reasoning.*
```

---

## the reasoning chain repository

naturally homes in `reasoning.tree.*` with persistence.
traversal history lives in the native reference dataspace when ready.

```
each entry:      a threshold crossing event — node expanded, delegation fired
replaying:       reconstructs the full reasoning arc
dedup:           two trees with identical threshold profiles = one entry
                 regardless of words used — convergence geometry is the identity

self-improvement: finding shorter traversal paths to nodes already in the tree
contradiction:    two paths claiming same destination at different checksums
```

the repository is the system's memory of its own actualization history.
not logs — the living record of a system that has been narrating and
self-delegating long enough to know where it is going.

---

## relation to existing topology

```
harmonic-mathematics:   076923, division by 13 — the measurement used by
                        reasoning.threshold.check is the same harmonic assertion
                        that validates checksums and routing coordinates

BMW384-geometry:        reasoning.tree.node coordinates in BMW384 space
                        route.bmw384.* and reasoning.tree.* share address space

namespace-tree-intelligence: the tree IS the intelligence — reasoning.* is the
                        operational form of that principle

task-tree-design:       task zenka's subtask hierarchy becomes a reasoning subtree
                        multi-parent groups = multi-path convergence

punctuation-topology:   `:` as group boundary, `.` as element separator
                        both apply in the ascii format and the module namespace
```

---

## when to load reasoning.*

load `reasoning.*` modules when a zenka needs to answer "what next"
from internal state rather than from an external command.

any zenka that currently has hand-coded "what should i do now" logic
is a candidate for loading from `reasoning.*` instead.

the test: can you describe what the zenka is currently doing in one sentence?
if yes: that sentence is the narration. the next step is the delegation.
if no: the zenka needs `reasoning.summarize.*` before it can self-delegate.

#,,..,,,,,...,,,,,..,,...,,,,,..,,,,,,..,,,..,.,.,...,..,,..,,...,...,,..,..,,
#XQ6TX6VAH7Y33MEVHJNBIJEV4GMKFJPE6MT2JVBXJMD5T2IDPTMSL5FFSNICDUYYFO3LC3HI7S3E6
#\\\|OHW7JVCILIPNYEGAF4EAQDDLDBQOPWFT63IVBUEOT3B4WXXYRKJ \ / AMOS7 \ YOURUM ::
#\[7]3JYBCGXWQTZEOH33F7DCZ5Z7EKUP3KPAMDNMBPD4FEJPCJKXVYAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
