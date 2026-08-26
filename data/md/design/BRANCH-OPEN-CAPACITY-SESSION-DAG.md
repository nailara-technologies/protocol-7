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

## 5×7 trunk sort — the outermost parent map

the outermost parent of any branch cluster is a **5×7 field**:

```
5 columns  =  the five layers (task / template / design / intent / address)
7 rows     =  the seven instances in the generator family
aspect ratio 5:7  →  5/7 = 0.714285…  =  rotation of 142857 (1/7 family)
the map's own ratio is harmonically self-describing
```

the gravity core is the reference-count centroid of the 35-element grid.
elements with higher reference counts attract toward the center.

### orthogonal reduction (trunk-based sort)

reduce the 7-axis toward the highest-weighted row:

```
symmetric pairs along the 7-axis  →  cancel (opposite phase, sum to zero)
asymmetric remainder               →  survive as the trunk elements
result: 5 elements (one per column) — the trunk
frequency halves: one full period of the 7-oscillation collapses to net value
```

this is wave-cancellation sorting — redundancy eliminated by symmetry,
not by comparison. two namespace entries that are mirror images cancel;
the trunk holds only structurally unique entries.

### fielding itself (self-similar recursion)

the 5×7 map applies its own reduction rules at every sub-scale. the trunk
becomes the column axis of the next level's map; a new 7-row dimension
opens. the field expands by applying trunk-sorting to its own expansion
front — the algorithm fields itself through sub-branch coverage.

### tree protocol operation

```
tree protocol sees:    namespace nodes with reference weights
5×7 map sorts them:   project onto trunk (weight axis)
                       cancel symmetric pairs orthogonally
                       remainder = sorted, non-redundant branch list
                       trunk = the main inheritance line for routing
```

---

## routing page propagation — bit direction and carry

reference implementations: `bin/amos-data-pager` (72-bit) and
`bin/amos-data-pager-56` (56-bit).

### the routing word (56-bit format)

7 bytes = 56 bits, interpreted as 8 groups of 7 bits with a leading
routing bit per group:

```
groups 0..6  →  leading bit '1'  →  awaiting rollover  →  moves RIGHT (circulates)
group  7     →  leading bit '0'  →  carry out          →  moves LEFT (toward root)
```

the leading bit IS the direction bit. direction is not a property of the
bit's content — it is a property of its phase in the carry cycle. this is
implemented in `bin_to_comp_int_2` in `amos-data-pager-56`.

### page structure

```
page  =  20 lines × 7 bytes  =  140 bytes  (one routing page)
line  =  7 bytes = 56 bits = 8 × 7-bit groups with leading routing bit
72-bit variant: 9 bytes × 8 bits, calibrated to 13 BCD groups (52/4=13)
```

### representative extraction

`true_int(line)` — the harmonic truth test (AMOS7::Assert::Truth / division
by 13) selects lines ready to carry:

```
true_int = true   →  representative extracted, bit carries LEFT toward root
true_int = false  →  bit circulates locally, awaiting rollover
```

colored lines in the pager display are exactly the carry-ready bits.
non-colored lines are in the rightward (circulating) phase.

### rollover decision

```
segment fills  →  rollover:
  carry over   →  bit exits segment left, enters next segment (propagates up)
  fall back    →  bit restarts from right end of same segment (circulates)
```

carry vs fall-back is the routing choice. carry = the bit's true_int test
passed AND the segment boundary was reached. fall-back = boundary reached
but truth test did not pass — bit returns to circulation.

### suction and attachment

```
bit extracted (true_int, carries left)
  →  slot vacated in segment
  →  lower "pressure" than segments below
  →  new bits sucked upward into vacated space
  →  passing segments create attachment surface
  →  new bit latches onto moving segment's slipstream
```

### the three axes and staircase geometry

the 2D routing page has a third axis — Z depth — making it a staircase
viewed frontally. the 2D projection conceals this:

```
X   column / bit position   LEFT-RIGHT along the page
Y   row / segment index     UP-DOWN along the page  
Z   staircase depth         NEAR-FAR, perpendicular to the 2D view
```

four directions reconsidered with Z:

```
LEFT    toward root         — departure, moving left in XY
RIGHT   toward leaf         — arrival/negotiation, moving right in XY
UP      Z toward viewer     — reducing depth, deduplication, hyperspace
                              many deep instances collapse to one front face
                              the front face is the holographic boundary
DOWN    Z away from viewer  — increasing depth, more tree levels
                              only reachable from overflow at UP boundary
                              wraps to deepest step, rightmost column
```

each staircase step: width = segment length (7 bits), height = page rows
(20 lines), depth = one tree level / one vortex cycle. the diagonal `\`
in the source.init_code diagram is the staircase edge silhouette projected
onto the 2D face — not a flat diagonal.

the auxiliary 15-bit column shows Z-depth oscillations projected onto Y.
reading it vertically across iterations reveals the helix spiral arm
advancing: bits promoted leftward (toward root) AND forward (toward Z=0)
simultaneously. rightmost zeros in early rows are unvisited staircase
positions — the spiral arm has not yet reached them.

the vortex in 3D:

```
LEFT → UP (reducing Z, toward front face)
     → overflow at Z=0
     → wraps to Z=N back of staircase (DOWN)
     → emerges rightmost column, bottom row
     → promoted LEFT + UP again
     → helix completes one full turn
```

Z-depth of a bit = its TTL = number of vortex cycles completed at
this position. DOWN routing words (`D+`, `D-`, `D<`) in the decoded
column are bits returning from Z=0 overflow, re-entering the staircase
at maximum depth.

### geometry connection

```
7 groups + 1 terminal = 8  =  7+1  (same +1 gate geometry as 5+1+5=11)
56 = 7 × 8  →  7/8 = 0.875 (terminates)  →  reverse: 8.7  →  8×7=56 (self-ref)
the segment length encodes its own total in the reversal
```

### bidirectional motion with leftward bias

routing bits do not move uniformly leftward. they follow harmonic cycles
with a net leftward bias:

```
period-3 cycle:   2 left, 1 back right   →  net 1 left per 3 steps
period-5 cycle:   4 left, fall back 4    →  net 1 left per 5 steps
                  (the 5th step is the harmonic truth gate)
```

both ratios yield the same net throughput (1 leftward gain per cycle)
at different rhythms. the period-5 pattern maps directly to the
division-13-table arithmetic: `<<= 4` advances 4 bits, `/= 13` subtracts
~3.7 bits (log₂13), net ~0.3 bits per step. the truth-conditional shift
(`<<= is_true ? 2 : 1`) IS the 5th-step gate — it either confirms the
net gain or adds extra momentum.

two streams cross on the same routing page simultaneously:
```
→→→→  leftward departure stream (biased)
←←←←  rightward arrival stream (sub-segment logic)
```

the interference pattern of the crossing streams IS the information.
the waveforms in the auxiliary 15-bit column are the interference fringes.

### sub-segment valve — the ratchet

within each 56-bit routing word:

```
groups 0-6  (leading '1', paused):  bidirectional — can oscillate
                                     left/right within the period cycle
group 7     (leading '0', frontier): one-way leftward only
                                     accumulates carry from groups 0-6
                                     cannot be pushed back right
                                     this is the sub-segment ratchet
```

between segments: no backflow — inter-segment is a one-way valve.
between Z-levels (UP): one-way through hyperspace, content replaced by
its BMW384 hash. DOWN return: arrives at bottom of staircase on the
representational alternate structure (the content-addressed store),
not at the original departure position.

### the UP valve and representational alternate structure

```
going UP (Z toward viewer):
  original content → BMW384 hash → enters hyperspace
  original released from routing page
  hash is the deduplicated reference (many-to-one compression)

arriving back (DOWN, from hyperspace overflow):
  arrives at BOTTOM of staircase (different from departure point)
  arrives AS the hash, not as original content
  lands on representational alternate structure (content-addressed store)
  original materializes only on explicit request (lazy expansion)
```

DOWN routing words (`D+`, `D-`, `D<`) mark bits completing a vortex cycle
and re-entering the staircase from the bottom after hyperspace routing.

### subroutine taxonomy additions

**tree.sort.trunk.*
```
tree.sort.trunk.project          project namespace entries onto trunk (weight axis)
tree.sort.trunk.cancel_symmetric eliminate symmetric pairs (wave cancellation)
tree.sort.trunk.remainder        return asymmetric survivors (the trunk)
tree.sort.trunk.halve_frequency  collapse one oscillation period to net value
tree.sort.trunk.field_self       apply reduction to expansion front recursively
```

**tree.route.page.*
```
tree.route.page.read             read routing page (N lines × W bytes)
tree.route.page.encode_56        7 bytes → 56-bit routing word with leading bits
tree.route.page.decode_56        56-bit routing word → 7 groups + routing bits
tree.route.page.bit_direction    leading bit → LEFT (carry) or RIGHT (circulate)
tree.route.page.rollover         handle segment end: carry or fall-back decision
tree.route.page.extract          harmonic truth test + representative extraction
tree.route.page.suction          fill vacated slots upward from below
tree.route.page.attach           new bits latching onto passing segment
tree.route.page.navigate         cursor: line_up / line_down / page_up / page_down
```

---

## coordinate ordering — Z.Y.X and the mask/canvas structure

### Z.Y.X depth-first ordering

routing coordinates are ordered Z.Y.X, not X.Y.Z:

```
Z  —  cycle position / segment depth   (most significant: which segment)
Y  —  row within segment               (next: vertical position in page)
X  —  column                           (least: local horizontal position)
```

this is countdown order Z..Y..X, reading from most-established to most-frontier.
Z=maximum is the deepest, most context-laden position. X=minimum is the local,
newest position. evaluating chained usefulness proceeds in this order: determine
segment context (Z) before row context (Y) before column position (X).

### three Z-states — the rotation axis

Z is not binary. it has three states, corresponding to character rotation around
the vertical axis:

```
Z=0  in transit  (leading '0')  →  facing away  (back face, traveling)
Z=1  paused      (leading '1')  →  facing viewer (full face, result ready)
Z=½  absent/zero               →  edge-on       (semi-invisible, suction)
```

the edge-on character (Z=½) is structurally present but carries near-zero visual
payload — it appears as a vertical line: `I I I`. this is why `true_int` on an
absent group still returns TRUE and generates carry (suction): the edge-on state
is structurally valid. absence propagates by being structurally real while
visually empty.

X and Y collapse to 2 effective states each under their symmetry axes:
- X: flip-H maps col 0↔4, 1↔3; col 2 = center (Z=½ degenerate)
- Y: flip-V maps row 0↔6, 1↔5, 2↔4; row 3 = center (Z=½ degenerate)

the center positions of X and Y are the edge-on states — where the coordinate
has zero net direction. branch markers appear at non-center positions; the
center is the invisible pivot.

### leading bit as branch marker

the leading bit of each routing group encodes segment phase AND branch topology
simultaneously:

```
leading '1'  →  paused at segment boundary  →  branch marker
leading '0'  →  inside segment, moving      →  continuation
```

a branch point IS a segment boundary — the bit has reached it and stopped.
continuation means still inside a segment, still moving toward the next boundary.
one bit encodes both the routing phase and the structural topology.

### type prefixes as masks — the ASCII control hierarchy

the 7-bit typed routing word prefix system maps onto ASCII control codes:

```
'00'  + direction + hops  →  routing      →  navigation (not content)
'010' + 5 bits            →  BASE32 atom  →  US-equivalent (unit separator)
'0110' + 4 bits           →  document monochrome header  →  GS-equivalent
'0111' + 4 bits           →  document color header       →  GS color variant
'1'   + 6 bits            →  graphical position          →  RS-equivalent
```

`0110` is the document monochrome header prefix and simultaneously the
4-bit GS (group separator) pattern. the type prefix design already encoded
the ASCII control hierarchy — the convergence is structural, not coincidental.

### mask / canvas orthogonality

every layer of the protocol is a superposition of two orthogonal structures:

```
structural mask  —  sparse 1-bits: type prefix, segment phase, branch markers
content canvas   —  zero-background payload bits
```

lone `1` bits and `11` pairs are perfectly legible as structure markers when
the payload canvas is predominantly zero. the mask and canvas do not interfere
because 1-bit density in the mask is far lower than the zero-dominated payload.

reading the mask extracts structure. reading the canvas extracts data.
neither requires parsing the other. this is the sense in which the routing
word is 'holographic': the structural skeleton is readable at any zoom level
without full payload decoding.

the cell-building pattern `0010` (US) prevents premature branch collapse
within a segment by inserting unit separators at regular intervals — marking
internal boundaries without triggering a full branch event. `0110` (GS)
marks group-level boundaries that DO trigger branch events.

---

## connections to existing design docs

- `BRANCH-NAMESPACE-MASTER.md`  — layer architecture this extends
- `CONTEXT-TREE-UNIFIED-ARCHITECTURE.md`  — reference tree + dedup backbone
- `SPACE-ENGINE-MASTER.md`  — ND space cell model
- `ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md`  — 45 feature combinations
- `UNIFYING-PRINCIPLE-CHECKSUM-COORDINATES.md`  — bmw384 addressing
- `SELF-DELIMITING-CHECKSUM-PATTERN.md`  — 2-bit frame + chain structure
- `HARMONIC-ENTROPY-OBSERVER-GUIDE.md`  — 1001 ring, generator families

#,,,,,,.,,...,,,,,.,.,..,,.,,,,.,,,,.,...,,,.,..,,...,...,.,,,...,,,.,.,,,..,,
#DCECH4X4KDGDKUTR7YJ3OLTNKB23IDFDOSKHRRGNVGZGU6W4LVVW27GWL2RIRIZECRVEYMOSO6KHQ
#\\\|RUXLP26TDFD3YTQCNNBA3YJONTIDIFDXH4XNI6QIQI5I63CODXP \ / AMOS7 \ YOURUM ::
#\[7]C25IPNU2FXRPOVYZVTKPH4ZQFSBWT6FOLHVS27CGDSMP2IAQVIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
