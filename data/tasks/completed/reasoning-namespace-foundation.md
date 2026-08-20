# task: reasoning.* namespace foundation modules

## context

protocol-7 needs a generic substrate for "what to do next" logic across all zenki.
currently each zenka hand-codes its own scheduling/dispatching. the `reasoning.*`
namespace replaces this with a shared structure: a summarizing node narration tree
with full instantiation capabilities and threshold-triggered complementary action.

the name is harmonically TRUE: `harmony reasoning` → `[:<  [ TRUE ]`

this task implements the foundation layer — `reasoning.tree.*` modules only.
these are the in-memory deduplication tree operations. persistence (reasoning.chain.*)
comes later. all higher reasoning.* modules depend on these.

read before starting:
- `data/md/development/REASONING-NAMESPACE.md` — full namespace design
- `data/md/development/REASONING-CHAIN-REPOSITORY.md` — persistence design (for context only, not implemented here)
- `data/yaml/reasoning-templates/narrate-and-self-delegate.yaml` — the core pulse concept
- `data/yaml/reasoning-templates/reasoning-buffer-architecture.yaml` — the layer stack

## signatures note

files will be signed after implementation. do not add signature stubs.
run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## what to implement

### reasoning.tree.node

the node data structure. each node in the reasoning tree has:

```perl
## [:< ##

# name = reasoning.tree.node
# descr = create a new reasoning tree node with numerical identity

# args: {
#   name       => 'dotted.node.name',
#   narration  => 'current state as coherent string',
#   depth      => N,
#   parent     => 'parent.node.name' or undef (root),
# }
# returns: $node hashref with all fields initialized

my $args = shift // {};

my $name      = $args->{'name'}      // '';
my $narration = $args->{'narration'} // '';
my $depth     = $args->{'depth'}     // 0;
my $parent    = $args->{'parent'};

## compute AMOS checksum as numerical identity
## use AMOS7::Assert::Truth or base.chk-sum modules
my $content   = join( ':', $name, $depth, $narration );
my $chksum    = <[base.chksum.amos]>->( \$content );

my $node = {
    name         => $name,
    chksum       => $chksum,
    depth        => $depth,
    parent       => $parent,
    narration    => $narration,
    convergence  => 0,              ## 0..1 as N/13 fraction
    threshold    => 0.769230769230769,  ## 10/13 default
    state        => 'compact',      ## compact | expanded | narrating
    children     => [],
    overlaps     => [],
    approach_vectors => [],         ## [ { from => name, convergence => N } ]
    up_refs      => 0,
    down_refs    => 0,
    directional  => 0,
    visual_refs  => 0,
    ntime        => <[base.ntime]>->(),
};

return $node;
```

### reasoning.tree.insert

add a node to the tree — collapse on checksum identity (deduplication):

```
args: { tree => \%tree, node => $node }
returns: { status => 'inserted' | 'collapsed', node => $node }

if tree already has entry with same chksum:
  merge approach_vectors (add new vector to existing)
  update convergence (recalculate from vector count)
  return { status => 'collapsed', node => $existing }

if no existing entry:
  add to tree, update parent's children list
  initialize convergence from depth and approach vector count
  return { status => 'inserted', node => $node }
```

convergence calculation:
  convergence = approach_vector_count / 13
  capped at 1.0 (12/13 = 0.923... is practical maximum before threshold)
  threshold crossing: convergence >= node threshold
  on crossing: set state = 'expanded', emit to reasoning.threshold.fire if available

### reasoning.tree.lookup

find a node by checksum or by name:

```
args: { tree => \%tree, chksum => $chk }   # by identity
   or { tree => \%tree, name   => $name }  # by name (slower)
returns: $node or undef
```

checksum lookup is O(1) via hash index.
name lookup is O(n) — use checksum when possible.

### reasoning.tree.traverse

walk a subtree from a given node:

```
args: {
  tree      => \%tree,
  from      => 'node.name',      # start node
  order     => 'depth' | 'breadth',
  on_node   => sub { my ($node) = @_; ... },   # callback per node
  filter    => sub { my ($node) = @_; return 1 | 0 },  # include/exclude
}
returns: list of visited node names in traversal order
```

depth-first by default (narrate pattern — go deep before wide).
breadth-first available (survey pattern — check all children before descending).

### reasoning.tree.narrate

produce the narration string for a node at its current state:

```
args: { tree => \%tree, name => 'node.name', depth => N }
returns: formatted string

compact state (convergence < threshold):
  "[ node.name ]  >:|  0.538461538461538   compact"

expanded state (convergence >= threshold):
  "[ node.name ]  [:<  0.923076923076923\n" .
  "   'narration text'\n" .
  "   depth : N   chksum : AMOS·XXXX   threshold : reached\n" .
  "   overlap : other.node.name\n"

narrating state (convergence = 1 or root):
  expanded format + "   → complementary action ready"
```

### reasoning.tree.summarize

upward pass: compress a subtree into a parent narration string:

```
args: { tree => \%tree, from => 'node.name' }
returns: string — the coherent summary of this subtree's current state

walk all children recursively (depth-first)
collect narration of each expanded node
compact nodes contribute only their identity line
combine into coherent multi-line summary
the summary IS the context for the parent narration
```

### reasoning.tree.render

produce the full ascii blueprint of the tree (layer 5 visualization):

```
args: { tree => \%tree, root => 'node.name' }
returns: multi-line string — the holographic blueprint

format:
  reasoning.tree : [root-name]
  ;.,
  ├─[ child.a ]  [:<  0.923076923076923
  │   'narration text'
  │   overlap : other.node
  │   children:
  │   ├─[ .grandchild-a ]  [:<  0.769   'narration'
  │   └─[ .grandchild-b ]  >:|  0.307   compact
  │
  └─[ child.b ]  >:|  0.538461538461538   compact
  ;.,

rules:
  expanded nodes: full block with narration, overlaps, children
  compact nodes: single line, identity + convergence + state
  convergence values: full harmonic precision (N/13 fractions)
  use box-drawing chars: │ ├─ └─
  indent 4 spaces per depth level
```

---

## module file format

all modules follow the p7 format:

```perl
## [:< ##

# name = reasoning.tree.node
# descr = create reasoning tree node with numerical identity

## implementation here...

## [end of module — no signature stub]
```

files go in `modules/reasoning.tree.node` (no extension — filename IS the sub name).

## zenka configuration

add `reasoning` zenka start file at `cfg/zenki/reasoning/start`:

```
[load_modules:reasoning.tree.node reasoning.tree.insert reasoning.tree.lookup
              reasoning.tree.traverse reasoning.tree.narrate reasoning.tree.summarize
              reasoning.tree.render]
[init_modules]
[zenka.loop]
```

the reasoning zenka should be on-demand:
```
start.on-demand = 1
restart.disabled = 1
heartbeat.disabled = 1
```

## base checksum module

if `base.chksum.amos` does not exist or the checksum API is different,
use whatever base checksum module is available — check `modules/base.chk-sum.*`
for the current API. the important property is determinism: same content → same checksum.

## test the implementation

after implementing, verify:

```bash
# start reasoning zenka
p7 reasoning.tree.node '{"name":"test.node","narration":"the test narration","depth":0}'

# insert a node
p7 reasoning.tree.insert '{"name":"test.node","narration":"...", ...}'

# lookup by name
p7 reasoning.tree.lookup '{"name":"test.node"}'

# render the tree
p7 reasoning.tree.render '{"root":"test.node"}'
```

expected render output for a two-node tree:
```
reasoning.tree : test.node
;.,
│
└─[ test.node ]  [:<  0.153846153846153
    'the test narration'
    depth : 0   chksum : AMOS·XXXX   threshold : not reached
;.,
```

## success criteria

- [ ] reasoning.tree.node creates node with AMOS checksum identity
- [ ] reasoning.tree.insert deduplicates on checksum, merges approach vectors
- [ ] reasoning.tree.insert updates convergence = approach_vector_count / 13
- [ ] reasoning.tree.insert detects threshold crossing, updates state
- [ ] reasoning.tree.lookup finds by checksum in O(1)
- [ ] reasoning.tree.traverse visits all nodes in correct order
- [ ] reasoning.tree.narrate produces correct format for compact/expanded/narrating
- [ ] reasoning.tree.summarize produces coherent upward summary
- [ ] reasoning.tree.render produces valid ascii blueprint with box-drawing chars
- [ ] reasoning zenka starts on-demand cleanly
- [ ] all modules pass p7 invocation without errors

## what comes after

once reasoning.tree.* is working:
1. reasoning.threshold.* — threshold detection and complementary action trigger
2. reasoning.instantiate.task — bridge to task zenka
3. reasoning.chain.* — persistence layer (see REASONING-CHAIN-REPOSITORY.md)
4. task zenka loads reasoning.* — "what to do next" becomes narration inference

#,,.,,,,.,...,,,.,,.,,,,,,,.,,,..,..,,,..,..,,..,,...,.,.,...,...,..,,,,.,,,.,
#KDCIMEDDTCOCXA32VA74ZYH3ZRAWKJ3MCCGT5DPEFBRTSWAESZI7R6UTGUVJ6XYFGZDLTRNJE2Z64
#\\\|4X5JOTYFVVZ6LQQGFR5JFV6PKFP36STFSWWCBGDRAVYZI54RB54 \ / AMOS7 \ YOURUM ::
#\[7]KPLHQRMNRDGDMCT4T356HQFP73EYB6NYI5COTN3F5P3ME6E7G4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
