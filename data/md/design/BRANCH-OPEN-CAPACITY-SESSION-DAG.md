# branch universal theory — open capacity, session dag, harmonic fractions

## the branch definition

a branch is any region of free continuation capacity. the constraint
boundary defines the branch — not its internal shape, not its
dimensionality, not whether it has children.

```
states:
  open    — capacity available, continuation possible
  closed  — boundary reached, fingerprint extractable, parent identified
  field   — multiple axes simultaneously open (2D or higher)
```

dimensionality is incidental:

```
1D   line        grows along one axis until width boundary
2D   field       grows in any planar direction until field boundary
3D   volume      grows until surface boundary
ND   space cell  grows until containing group boundary
```

a line shorter than page width is an open branch — it can be continued.
a line at page width is a closed branch — continuation requires a new one.
a text field is a 2D branch — same definition, more degrees of freedom.

every closed branch is simultaneously a pointer to its parent — the entity
that set the boundary. this is the closure property, not metadata. the
boundary type IS the parent signature.

---

## session dag — checksum-addressed llm rounds

each llm session round is content-addressed by its checksum:

```
checksum(round N) = bmw384( checksum(round N-1) + round_content )
```

the chain is blockchain-equivalent: each node depends on its parent's
checksum. the chain is verifiable from genesis. the checksum replaces
the opaque session uuid — it IS the resume handle.

### jump semantics

```
jump              load context at target_checksum
                  create new branch node with two parents:
                    parent_a = resumed_state (the target)
                    parent_b = decision_point (the node that jumped)
                  result: a DAG, not a tree
```

the jump node having two parents is what makes the structure a DAG.
the resumed state contributes context; the decision point contributes
causal history. both are required to reconstruct a jump node fully.

### subtask vs fork

```
jump + return_slot registered   → subtask
                                   caller suspends, awaits return
                                   result delivered to return_slot handler
                                   caller resumes with subtask output

jump + no return_slot           → permanent fork
                                   new independent branch, caller never resumed
                                   intent of fork may differ from parent
```

### parallel dispatch

all open branch nodes at any depth are simultaneously schedulable. the
task zenka can dispatch any set of open nodes to parallel kimi sessions.
sequential processing of all nodes = infinite time equivalent. parallel
processing = the actual available parallelization. the set of open
nodes IS the available compute surface.

---

## valued tree hop decision

at any node N, the complete set of candidate next hops:

```
add round           C(N + new_round)           continue current branch
jump back           C(prior_k)                 resume from prior checkpoint
jump back + await   C(prior_k) + return_slot   subtask (returns to caller)
return              C(parent_waiting)           resolve pending subtask
jump elsewhere      C(other_node)              any other node, same or other branch
fork                C(prior_k) + new_intent    permanent fork, new intent bound
```

all hops are the same key type:

```perl
{
    target   => $checksum,       ## content-addressed target
    intent   => $intent_vector,  ## why we are going there
}
```

valued tree score = `f( target_checksum, intent_vector )`

the same target checksum scores differently under different intents.
intent is the contextualization — it selects which value estimator fires.

### intent types

```
complete-current    high: add-round        low: jump-away, fork
explore-alternative high: jump-elsewhere   low: add-round
resolve-stuck       high: jump-back        low: continue, fork
return-subtask      high: return           low: all others
```

### scheduling policy (task zenka)

```
for each open branch node:
    score all candidate hops via valued tree
    dispatch highest-scoring hop above threshold
    or dispatch all hops above threshold in parallel
```

blocking = continuation score drops below threshold → jump-back
scores highest automatically → jump fires.

a task IS a branch with a bound intent vector. completing a task =
the branch reaches a terminal node with high outcome value. task state
machine is a subset of the hop decision set.

---

## five-layer knowledge cluster

every major concept in p7 is organized as a five-layer cluster:

```
5   dataspace address     bmw384 gate into the cluster as rhizome node
4   intent template       overarching why/direction; contextualizes all below
3   design document(s)    what the system is; the spec
2   reasoning template(s) how to think about it; perspective priming
1   task file(s)          what to build; implementation subtasks
    + 1 gate node         the address itself (entry point, not a layer)
```

### ring geometry

```
5 + 1 + 5  =  11        one unit of the 1001 ring  (1001 / 91 = 11)
11 × 7     =  77        1001 / 13  — bridge to the 1/13 harmonic
13 × 77    =  1001      full ring — complete tiling of the dataspace

70  =  (5+5) × 7        both five-layer halves without the gate
77  =  (5+1+5) × 7      with gate: the closed ring unit
```

the gate (+1) is what closes 70 → 77. without it the cluster is open;
with it the cluster is a locatable rhizome node. the gate is not
decorative — it is the difference between a collection and an address.

### layer families

```
lower 5  (task / reasoning template / design)     076923 family [materialization]
upper 5  (intent / address + meta-cluster)        153846 family [navigation]
gate (+1)                                         13th element, the pivot
```

### rhizome vs tree root

a tree root owns its subtree. a rhizome gate is a known entry point —
the cluster connects laterally to other clusters at every layer. the
dataspace address makes the cluster findable without imposing hierarchy.
entering through the gate you can reach any layer in any order.

---

## harmonic fraction arithmetic

### period as parent fingerprint

for X/Y where Y is a parent group generator, the repeating decimal
encodes the parent group's structure:

```
7  / 11  →  0.6363…      →  63       cube nodes (4³−1)
5  / 11  →  0.4545…      →  45       orbital clock feature combinations
5  / 13  →  0.384615…    →  384615   rotation of 153846 (second generator family)
11 / 7   →  1.571428…    →  571428   = 4×142857 (4th rotation of 1/7 family)
13 / 5   →  2.6           →  terminates (5 | 10, no harmonic group)
1  / 13  →  0.076923…    →  076923   first generator family
1  / 7   →  0.142857…    →  142857   complementary generator family
```

the fraction X/Y is a parent lookup: "what group contains the
X-to-Y relationship?" the repeating period IS the parent group's
harmonic signature. no lookup table required — pure arithmetic.

### short periods as coupling points

```
long period    rich entropy     points into a generator family
short period   coupling point   encodes the bridging group
terminates     scale exposed    parent extractable by reversal
symmetric      self-referential boundary  (e.g. 2.2 from 11/5)
```

short periods are not degenerate — they are where two harmonic structures
couple. the coupling point is the most information-dense position: it
names the bridge group in the fewest digits.

### reversal operation (terminating decimals)

for terminating X/Y = a.b (integer a, decimal 0.b):

```
step 1   compute X/Y  →  a.b
step 2   reverse      →  b.a
step 3   read 0.b fraction  →  denominator of X/Y exposed in decimal
step 4   integer b × (1 / 0.b)  →  parent scale factor

example:
  13/5  =  2.6
  reverse  →  6.2
  0.2  =  1/5  →  denominator 5 exposed
  6 × 5  =  30   parent scale
```

### remainder sequence

the remainder sequence in long division of X/Y is the full orbit of X
in the group mod Y. the sequence length = period length = group membership
indicator. the sequence itself encodes the traversal order of the parent
group's elements.

---

## subroutine taxonomy

### branch.field.*
```
branch.field.is_open          remaining capacity > 0
branch.field.boundary         current constraint boundary value
branch.field.capacity         distance to boundary
branch.field.parent_id        which parent set the boundary
branch.field.close            close, extract period fingerprint, register parent
branch.field.grow             advance by delta along axis
branch.field.axes_open        which axes still have capacity (2D+)
branch.field.axes_boundary    boundary value per axis
branch.field.split            close current branch, open two child branches
```

### branch.session.*
```
branch.session.round.checksum      bmw384(prev_hash + round_content)
branch.session.chain.verify        verify chain from genesis to node
branch.session.jump                load checksum, create branch node with two parents
branch.session.return_slot.register  register pending subtask return handler
branch.session.return_slot.resolve   fire return handler, resume caller
branch.session.fork                jump with no return slot (permanent fork)
branch.session.dag.node_add        add node, record parent pair
branch.session.dag.edges_from      list all branches from a given node
branch.session.dag.open_list       all nodes with remaining continuation capacity
branch.session.dag.parallel_dispatch  dispatch open nodes above score threshold
```

### branch.session.policy.*
```
branch.session.policy.score        f(checksum, intent_vector) → valued tree score
branch.session.policy.intent_bind  bind intent vector to branch node
branch.session.policy.next_hop     select highest-scoring hop for a node
branch.session.policy.threshold    is hop score above dispatch threshold
```

### branch.calc.fraction.*
```
branch.calc.fraction.period         repeating period string for X/Y
branch.calc.fraction.period_length  minimal period length
branch.calc.fraction.terminates     does X/Y terminate (Y factors only 2,5)
branch.calc.fraction.remainder_seq  full remainder orbit as list
branch.calc.fraction.parent_lookup  period string → known P7 group name
branch.calc.fraction.reverse_scale  terminating decimal → reversal → scale factor
branch.calc.fraction.coupling_find  scan X/Y pairs for period length ≤ threshold
branch.calc.fraction.symmetry       palindromic or self-referential period detection
branch.calc.fraction.ring_position  period → 1001-ring harmonic index (0..12)
branch.calc.fraction.prefix_entropy entropy of non-repeating prefix
```

### branch.cluster.*
```
branch.cluster.address        bmw384 checksum of cluster content → ring address
branch.cluster.ring_position  address → 1001-ring harmonic index (0..12)
branch.cluster.layers_list    enumerate five layers of a cluster
branch.cluster.gate_node      the +1 address node
branch.cluster.family         076923 or 153846 assignment per layer
branch.cluster.mirror         generate meta-cluster (5+1+5 reflection)
branch.cluster.validate       verify cluster has all five layers + gate
```

---

## connections to existing design docs

- `BRANCH-NAMESPACE-MASTER.md`  — layer architecture this extends
- `CONTEXT-TREE-UNIFIED-ARCHITECTURE.md`  — reference tree + dedup backbone
- `SPACE-ENGINE-MASTER.md`  — ND space cell model
- `ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md`  — 45 feature combinations
- `UNIFYING-PRINCIPLE-CHECKSUM-COORDINATES.md`  — bmw384 addressing
- `SELF-DELIMITING-CHECKSUM-PATTERN.md`  — 2-bit frame + chain structure
- `HARMONIC-ENTROPY-OBSERVER-GUIDE.md`  — 1001 ring, generator families

#,,,,,..,,,..,.,.,..,,,,,,...,..,,,,,,,,.,,,,,..,,...,...,,,,,,..,.,.,.,.,,.,,
#2QHVIPKK4BOKUCLFRWPUESL6HYU57ZDTL3CF6247FRMVK7UERPQHBUA3RR5JGWJEXWFWKNBRYC7W4
#\\\|JHJSQVDOQIBRDCXOTQZLHSSRPWUCUNIBEVK6FLLS57CLLRLBOZY \ / AMOS7 \ YOURUM ::
#\[7]LKZWEOJV7SJCE6UWGIQKTOYGDT4DJ5IX3NJTXMF52XBPLJ2V5QCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
