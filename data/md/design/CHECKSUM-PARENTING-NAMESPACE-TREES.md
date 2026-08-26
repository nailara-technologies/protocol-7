## [:< ##

# checksum auto-parenting for namespace trees

## overview

a small algebraic relation between checksums and names that, when
applied consistently across a namespace tree, gives whole-tree
collision protection for free and removes the need to store parent /
child checksum edges as explicit data.

the mechanism is one line:

> **`<C0>:<C1>`**, where `C0 = chksum( <C1>:<name> )`.

every node carries `name` and `C1` [ the checksum of its parent in the
tree ]; its own checksum `C0` is the AMOS checksum of the concatenation
`<C1>:<name>`. nothing more. the parenting edge is derivable on
demand from any node's `(name, C1)` pair — never stored, never sorted,
never indexed separately.

what follows is the unpacking: why the entry-level name constraint is
load-bearing, how the relation composes recursively up a tree, how it
sits relative to the addressing primitives already documented in
`topic-addressing-trinity.md` and `topic-checksum-addressing.md`, and a
much-less-developed open sketch of the user-trunk / transit-ring /
parabolic-mirror routing topology that prompted writing this down.

related material:

- `topic-checksum-addressing.md` [ AMOS checksums as universal routing
  primitive; BMW384 field geometry; the mirror-principle / route-as-
  symmetry-condition section is directly relevant to section 4 here ]
- `topic-addressing-trinity.md` [ name + checksum + timestamp as three
  orthogonal axes on the same node — this doc adds a recursive
  *parenting* relation on the checksum axis specifically, anchored at
  each level by the name axis ]

---

## 1. the auto-parenting mechanism

### the relation

for any node in a namespace tree:

```
C0 = chksum( C1 ':' name )
```

where:

- `name` is the node's own name segment [ the rightmost element of its
  dot-path ; e.g. `c` in `a.b.c` ]
- `C1` is the parent node's checksum
- `C0` is this node's checksum
- `:` is a fixed separator inside the checksum input

a node's identity-on-the-wire is the pair `<C0>:<C1>`. given that pair
plus `name`, anyone can verify `C0 == chksum(C1 ':' name)` and so
verify both the parent linkage and the node's name in one step.

### why it gives collision protection — the entry-level constraint

the standard worry about checksum addressing is collision: two distinct
inputs hashing to the same `C0`. under auto-parenting that worry
collapses to a single, very simple invariant:

> **every entry has a `name`. never just a checksum.**

if that holds, then a `C0` collision would require two inputs of the
form `<C1>:<name>` and `<C1'>:<name'>` to produce the same `C0`. but
the verifier is not asking "does this `C0` exist somewhere" — it is
asking "does `chksum(C1':'name) == C0` for the `(C1, name)` i have in
hand?". the only way another `(C1', name')` could pass the same check
is if `(C1', name') == (C1, name)` — at which point it is **the same
input value, not a collision**.

put differently: `C0` alone is not the addressable identity. the
addressable identity is `<C0>:<C1>` *together with* `name`. the
checksum is a verifier over a known-shape preimage, not a content-
addressed lookup key sitting in a flat space. collision risk reduces
to: "can two different `(C1, name)` pairs produce the same `C0`?" — a
question the AMOS checksum already has to answer for *any* two-input
hash, and which the protocol-level name constraint hardens further by
restricting the input shape.

this is also why it is, in the original phrasing, "perfect... in terms
of sorting work saved":

- no parent-pointer column to store
- no child-list to maintain
- no separate index from `C0` back to `(C1, name)`
- given any node-on-the-wire plus a knowledge of its `name`, the
  parent's checksum `C1` is literally embedded in the node id, and the
  node's correctness as a *child of `C1`* is verifiable in one hash

the storage saving is real but secondary; the real win is that the
parent/child relation is **computable**, not **looked up**.

---

## 2. recursive application up the tree

the same relation composes. if `C1` is itself a node, then it too has
the form

```
C1 = chksum( C2 ':' name1 )
```

where `name1` is `C1`'s own name segment and `C2` is its parent's
checksum. expand recursively all the way to the tree root:

```
C0 = chksum( C1 ':' name_0 )
C1 = chksum( C2 ':' name_1 )
C2 = chksum( C3 ':' name_2 )
...
C_{n-1} = chksum( C_n ':' name_{n-1} )
C_n     = chksum(   ''  ':' name_n )      # root, conventional empty parent
```

a node's full positional identity is therefore the tuple
`(name_0, name_1, ..., name_n)` — its dot-path — together with the
leaf checksum `C0` [ and, if desired for fast verification, the chain
of intermediate checksums `C1..C_n` ].

### tree-wide collision resistance

the entry-level argument from section 1 applies at every level. a
collision at level `k` would require two distinct `(C_{k+1}, name_k)`
pairs to produce the same `C_k`. by induction up the tree, a tree-wide
collision would require simultaneous collisions at every level along
the path — and at each level the name-as-anchor argument applies. the
tree is collision-resistant to exactly the strength the underlying
AMOS checksum provides for a two-input hash, *and no weaker*, despite
its recursive composition. the recursion does not multiply the attack
surface.

### verifying a position from name-path + leaf checksum

given:

- the full dot-path `name_n . name_{n-1} . ... . name_0`
- the leaf checksum `C0`

a verifier can — if it knows the tree's root convention — compute
`C_n` from `name_n` upward, then `C_{n-1}` from `(C_n, name_{n-1})`,
then `C_{n-2}`, and so on down to `C_0`. if the computed `C_0` matches
the supplied one, the node is in the position the name-path claims it
is in. no edges, no parent pointers, no tree walk against stored
state — the verification is pure computation against the supplied
name-path.

this is the property the user phrased as "perfect... sorting saved":
position-in-tree is *evaluated*, not *retrieved*.

### relation to the existing dot-path notation

the `<a.b.c>` data-access notation [
`data/md/design/DOT-PATH-CASE-NOTATION.md` ] gives a textual
addressing surface for the same trees this mechanism gives a checksum
addressing surface for. the two are duals: the dot-path is the name
sequence reading from root toward leaf; the checksum chain is the
verification trail reading the same sequence and proving each step.

---

## 3. relationship to the existing addressing primitives

### the addressing trinity

`topic-addressing-trinity.md` describes three orthogonal axes:

- **name** — semantic, dot-pathed, human-navigable
- **checksum** — content / position identity, AMOS or BMW
- **timestamp** — temporal identity, base32 ntime, sortable

auto-parenting does **not** add a fourth axis. it adds a *recursive
relation along the checksum axis, anchored at each level by the name
axis*. read in trinity terms:

- the name axis supplies the per-level disambiguator
- the checksum axis carries the parent linkage as a derivable property
  of node identity
- the timestamp axis is untouched — `latest` / `current` pointers and
  rolling-epoch behaviour work exactly as before, on top of any node
  whose `(C0, C1, name)` triple has been verified

equivalently: the trinity tells you *what an addressable node is*;
auto-parenting tells you *how those nodes wire into a tree without
storing the wires*.

### the checksum-based universal addressing layer

`topic-checksum-addressing.md` casts AMOS checksums as a universal
routing primitive — every entity addressed by checksum, P7REF format
`TYPE:CHKSUM7:ADDR_B32`. auto-parenting fits naturally into that
universe: the `CHKSUM7` field is exactly `C0`, and the recursive
expansion to `C1..C_n` is exactly the chain of parent checksums up the
tree the entity sits in.

what auto-parenting does *not* obviously map onto is the BMW384
**field-routing** model in the same doc — the "route is not a stored
path, it is a symmetry condition between two field regions; mirror
point in the field between endpoints" section. that model is geometric
and field-resonant; auto-parenting is algebraic and tree-shaped. there
are at least two readings of how they relate, neither yet confirmed:

1. **complementary layers**. AMOS auto-parenting is the tree-internal
   accounting primitive [ "given a name-path, is this the node?" ];
   BMW384 field routing is the inter-tree / inter-node transport
   primitive [ "given a coordinate, where does this packet go?" ]. one
   does verification of *position*; the other does discovery of
   *route*. they coexist without unification.

2. **shared root**. if a tree's root checksum `C_n` is itself given a
   BMW384 coordinate, then the auto-parenting chain inherits a
   geometric position — every node in the tree sits at a BMW384-
   derivable point, and intra-tree routing becomes a field operation
   like inter-tree routing. the "mirror principle" would then apply
   *within* the tree, not just between tree roots.

reading (2) is attractive but not yet justified by anything stronger
than analogy. it is flagged in the open-questions section rather than
asserted here. **no forced unification.**

a smaller tension worth naming: AMOS checksums are 7-char and discrete
[ a tree edge either verifies or it doesn't ]; BMW384 routing trades
in 384-bit geometric proximity [ continuous, fuzzy, threshold-based ].
the algebra of "chain of discrete verifications" does not obviously
embed in the algebra of "field of continuous proximities". section 5
flags this as an explicit open question.

---

## 4. user-trunk / transit-ring / parabolic-mirror topology — open sketch

> **this section is much less developed than sections 1-3. treat it as
> a sketch capturing the original riff verbatim, not a worked-out
> design. it needs more input from the user before it can be designed
> further.**

### the riff, captured

multiple namespace trees coexist. each tree has a designated **user
trunk** — the spine along which a user's own nodes hang [ presumably
the user-owned subtree, in trinity terms; presumably anchored at a
known root checksum, in section 2's terms ].

trunks do not connect directly to each other. they connect to a
**transit ring** — a shared structure into which routing decisions are
fed and from which they are mirrored back out. point-to-point
addressing between two users' trunks goes via the ring, not via a
direct edge.

the ring's reflection behaviour is described as a **parabolic-mirror
arc**: a packet aimed at the ring does not bounce back to its sender,
it reflects *behind* the sender — that is, the return path emerges at
a different point of the trunk than the sending point, governed by the
ring's curvature rather than by source/destination symmetry.

### possible relation to the mirror principle

`topic-checksum-addressing.md` already describes routing as a symmetry
condition with a mirror point "in the field between endpoints, not at
either node". the transit-ring sketch reads as a generalisation of
that: the mirror point is no longer free-floating in field space, it
is *constrained to lie on a designated ring structure*, and the return
geometry is no longer "similar but distinct" — it is a defined arc
reflection rather than a near-symmetric retrace.

if the two are the same mechanism, the transit ring is the **locus**
the mirror point is constrained to live on; the parabolic-mirror
return is the **specific reflection law** that applies on that locus.
that is one plausible unification.

but the riff is too underspecified to commit to it. the questions in
the next section are the ones that need to be answered before this
section can be turned into design rather than sketch.

---

## 5. status and open questions

sections 1 and 2 [ the auto-parenting mechanism and its recursive
application ] are concrete enough to implement against. the relation
is one line of computation, the verification chain is straightforward,
the storage / sorting savings are immediate.

section 3 [ relationship to existing addressing ] is mostly bookkeeping
— it slots auto-parenting into the trinity and the checksum-routing
layer without disturbing either — but it leaves a genuine open
question about how the discrete algebraic chain composes with BMW384's
continuous field geometry.

section 4 is a sketch. it should not be taken as design.

### explicit open questions

- **what is the transit ring, concretely?** a data structure local to
  each tree? a protocol phase between trees? a designated set of
  nodes that volunteer to host ring positions? a geometric construct
  in BMW384 field space [ e.g. the unit-circle wheel of the 24-bit
  color prefix ]? until this is pinned down, the rest of section 4 is
  vocabulary without referent.

- **does the parabolic-mirror reflection law map onto the existing
  mirror-principle field equation, or is it a different reflection?**
  if it's the same, the transit ring is the locus and the principle
  is unchanged. if it's different, the rules of return-path geometry
  need spelling out.

- **does the user have more nodes in this tree?** the source riff
  surfaced auto-parenting, recursive application, and the trunk / ring
  / mirror sketch in one breath, with the user noting it was being
  captured mid-stream. there may be further connected nodes [
  e.g. ring composition rules, multi-trunk handoff, intersection of
  trees at the ring level, role of timestamps in ring traversal ] not
  yet surfaced. flagged for follow-up.

- **does auto-parenting's algebraic chain compose cleanly with BMW384
  field routing, or do they remain two layers?** the two readings in
  section 3 — complementary-layers vs shared-root — are both
  defensible. picking one would constrain a lot of downstream design,
  so this is the largest single open question even though it sits
  inside an otherwise-bookkeeping section.

- **does the entry-level name constraint hold uniformly across all
  current p7 entity types?** the mechanism rests on "every entry has a
  name, never just a checksum". checking that against the existing
  entity catalogue [ models, tasks, dep edges, consensus groups,
  remote nodes — per `topic-checksum-addressing.md` ] before commitment
  is cheap and worth doing.

no task files are being written from this doc. it captures the riff
faithfully enough that further conversation can either confirm the
auto-parenting mechanism for implementation or extend the trunk / ring
/ mirror sketch into something concrete enough to design against.

#,,..,,.,,,..,...,.,,,,.,,.,.,...,,.,,.,.,...,..,,...,..,,..,,,.,,,,.,,,,,...,
#UF3JYZZRSXOOIY7TK55S5BYO42GZ32CIBUVBMT2ATNZ6LMCCD66R6UFRGK3FSGTKD3WNRJCBLBOS6
#\\\|2LSWN7W3P4RKGHWXOJD4ALWVPZCUQL3IEMSUUMRFZ62NC5QQJUW \ / AMOS7 \ YOURUM ::
#\[7]EVU2OJR4P5EZTCL37CTFUCB7XNA3J6NIJY7T26O4UXRW6XAXJCCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
