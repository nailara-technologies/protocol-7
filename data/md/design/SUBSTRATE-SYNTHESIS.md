# substrate synthesis : one cell, seen from several sides

status : design only [ 2026-11-16, revised the same day ]. this document
builds nothing and changes nothing outside the three design files of this
revision. it reads the design threads as views of one shape, lists where they
contradict each other, and sorts what can be built now from what waits for
the owner.

the revision follows the K3.1 review [ 24 findings, answered in section 10 ],
the owner's answers, and two commits of the day :

- **weaker claims.** the cell is one **vocabulary**, not one mechanism ; ring
  routing fits it worst ; reduce and irrigate are complementary, not one
  pass ; the journals share one envelope, not one security model
- **decided by the owner** : the word `cell` and `AMOS7::cell::time`
  [ questions 1, 13 ] ; one record form, the canon form of
  `N7FS-FORMAT-4.md`, for n7fs and the ledger [ question 12 ] ; the hashed
  separator form [ question 14, by commit ]
- **built** : the exact Y grid, `AMOS7::cell::time` [ 3bef478fe, section 7 ] ;
  `AMOS7::CHKSUM::Nested` builds the empty-parent root and verifies the
  parent [ b0eaa4732 ]
- **split** : the parent that sees amounts only is not the witness and not
  n7fs home [ section 1, contradiction 15 ]

sources read : `data/ai-mem/claude/topic-network-as-computer.md` [ "space as a
generic computation substrate" ], `topic-checksum-parenting-namespace-trees.md`
[ "implicit anchors" and the rest ], `CHECKSUM-PARENTING-NAMESPACE-TREES.md`,
`N7FS-SEALED-REPLICAS.md` [ "## open", plus time, add-only writers ],
`RESOURCE-ACCOUNTING-UNIFIED.md` [ whole ], `N7FS-FORMAT-4.md` [ whole ],
`philosophical-foundation.md`, `RING-ROUTING-PROTOCOL.md`,
`topic-latency-algorithmic-authority-entropy-toll.md`.

code looked at, to check what the threads claim exists : `AMOS7::CHKSUM::Nested`,
`AMOS7::cell::time`, `AMOS7::N7FS::Sum` [ epochs ], `AMOS7::NTIME` [ Y levels,
base32 form ], `AMOS7::N7FS::Placement` [ sub list, holder fields ],
`AMOS7::N7FS::Journal` [ header ], `src/base.ntime.epoch_dec`,
`src/base.p7refs.gen_template_chksum`, the `src/base.curve.*` module list.
where a line below says **checked**, it was read in that code ; everything
else is taken from the design texts.

words shared with the two other documents : a **cell** is the shape of
section 1 ; the **canon form** is the one record form [ `N7FS-FORMAT-4.md`
section 2 ] ; a **frame** is an index on the exact Y grid, an **epoch** is
the level 1 frame modulo 385280, a **window** is three valid frames ; the
**witness**, the **accounting parent** and n7fs **home** are three roles.

## 1. the one vocabulary

**a tree of cells. every cell can be described by the same five parts, and
its parents.** this is a way to name things alike across the threads. it is
not a mechanism : no code implements "a cell", and section 2 says which
thread the words fit and which they only touch.

| part | what it is | the rule it follows |
|---|---|---|
| **place** | an address : a path in one base32 prefix tree | derived, never assigned : computed from `( parent, name )`, from content, from a key, or from a time. the inputs differ per thread ; what is common is that nobody hands an address out |
| **window** | the time cell it is valid in, on the Y grid | three windows are valid at once [ previous, current, next ], so nothing has a cliff |
| **occupants** | the nodes that currently serve the place | proven, never granted : claimed by a signature or by holding the bytes. how they are chosen is open [ contradiction 8 ] |
| **journal** | an only-growing, signed, replayable record | the only state. no whole record ever leaves it ; balance, count, receipts, torque are folds of it ; anything beside it is a cache or evidence |
| **gate** | a threshold on that fold | the only event. below it things wait ; at it the state moves one step, and nothing else has to be authorized |
| **parents** | the next cells toward the root, in three roles | below |

"parent" was one word for three roles that no single party can hold
together :

| role | what it does | what it sees | today |
|---|---|---|---|
| **anchor** | roots identity, signs what names the child | the child's keys and names | n7fs home [ root signer, holds keys and the sealed map ], a zenka's host |
| **witness** | orders and replays the child's journal | every record of its domain | the ledger witness ; the n7fs store key for its own journal |
| **accounting parent** | keeps the child's totals without reading it | amounts per class per window, nothing else | designed only [ ledger section 3 ] |

"more neutral at every step up" holds for the accounting parent alone. a
party that can verify a journal has read it.

two flows run over the tree. they are **complementary, not one pass in two
directions** :

- **reduce, upward** : a cell folds what it holds [ counts, totals,
  histograms ] and hands its accounting parent one aggregate. it moves
  information, nothing is consumed. boundaries are exact, so aggregates of
  neighbours fit without overlap
- **irrigate, downward** : a cell divides a conserved amount over its
  children by agreed proportion, capped by what each can take ; what is not
  taken flows on or back. it moves the quantity itself, and it needs the
  shares, capacities and overflow rules of the ledger, which a reduction
  does not

and three rules recur at every scale, which is what "exoskeleton" means in
the network-as-computer thread :

1. **derived, not stored** [ the lambda principle ] : who the parent is, who
   should hold, when it expires, are meant to be computed alike by every
   party. where a measured input enters, this is not reached yet
   [ contradiction 8 ]
2. **proven, not granted** : a position, a copy, a usage, a standing are
   shown by signature, possession or history ; keys are cheap, history is not
3. **fuzzy where, exact how much** : reaching a place tolerates [ three
   windows, alternates, follow the prefix while it matches ] ; accounting
   never does [ whole numbers, one record per change, a proof used once ]

the owner named it : "spatial and temporal compartmentalization cut the field
into CELLS ... the place computes, machines are only its current occupants".
the word is **cell** [ decided, question 1 ]. `bin/harmony` as a hint, not a
rule : the bare word `cell` reads FALSE, `AMOS7::cell` reads TRUE.

## 2. each thread seen through it, and how well it fits

| thread | the side it shows | its words for the parts | fit |
|---|---|---|---|
| network as computer | the cell as a unit of computation | cell = ring \ arc \ base32 prefix + epoch \ Y level \ phase ; "gated transaction states" = gate ; accumulated torque = the journal's count ; "parent frame keeps the account" = accounting parent ; tree reduction = reduce | the source of the words |
| checksum parenting, implicit anchors | **place** : how an address is derived and verified | `C0 = chksum( C1 . '.' . name )` ; the empty parent as common root ; the epoch as join string = window ; the rocket = follow the prefix, then look around, with a hop budget | good : place and window |
| n7fs "open" | **occupants** : who holds, and how that is proven | blob address + holder key + epoch = weight ; receipt = the proof, valid until the next pass ; integer floors and control domains = hard gate conditions ; home = anchor | good for occupants and gate. its placement is not irrigation [ section 3 ] |
| resource ledger | **journal + gate + accounting parent**, for a conserved quantity | pool = cell ; slot = child cell ; share = the downward channel ; reserve = a local earmark ; saturation = the gate ; usage \ proof \ transaction = what the journal records ; frame = window | the most complete |
| irrigation principle | the **downward flow** | saturation threshold, overflow, public pools = capped proportional filling | good, for conserved amounts only |
| latency \ entropy toll | where **weights** could come from, and what entry costs | measured latency as a weight nobody can claim ; generic blind work as the price of taking part | vision ; it names an open problem more than a part |
| ring routing | a **boundary** a path passes through | tree = who [ identity path ], ring = through what, center = the target | **the worst fit**, below |

**ring routing fits worst.** a routing ring in its source is an
administrative or session-scoped group that shares one symmetric key. it is
not a base32 prefix cell, its members are not chosen by a weight, it keeps no
journal whose fold opens a gate, and it has no accounting parent. reading a
ring as "the occupant set of a prefix level" is this document's proposal and
nothing in `RING-ROUTING-PROTOCOL.md` says it. what the ring thread shares
with the others is two words, boundary and window. it is listed for
completeness, not as a view that confirms the shape.

the views that are readouts, not parts : the graphical views, colour \
translucency layers, scan masks, the audible channel, the physical layer.
n7fs already states the tie : "optional awareness", attributes a record
carries and the core ignores. they read the cell ; they are not a sixth part.

## 3. what the words cover in existing code and designs

the right column says what is common. it is a common name and a common
discipline, not a shared implementation, unless a line says so.

| part | what exists today | what is common, and what is not |
|---|---|---|
| place | `AMOS7::CHKSUM::Nested::child_chksum` [ **checked**, b0eaa4732 : AMOS checksum over `parent . '.' . name`, true in bracketed and bare form ; the parent is empty for the root or exactly 7 characters, the name nonempty and dot-free ; `verify_nesting` checks the parent too ] ; n7fs content addresses [ BMW384 of content ] ; map shard prefix `depth` [ 1 as built ] ; ledger pool \ slot \ record addresses [ BMW384 over stored bytes ] ; `P7REFS` [ **checked** : AMOS checksum over type, base32 address and optionally the node name ] | all are derived and none is assigned. they are **not** one derivation : only the nested checksum hashes `( parent, name )` ; content addresses hash content, `P7REFS` hashes a type and an address |
| window | `AMOS7::cell::time` [ **checked**, 3bef478fe : exact frames, windows, paths ] ; `epoch_window` in `AMOS7::N7FS::Sum` and `base.ntime.epoch_dec` [ **checked** : floats, one epoch = year \ 13 = Y1 = 28.08 d ] ; the Y levels of `AMOS7::NTIME` ; the n7fs retention ladder ; the ledger frame [ proposed Y3 ] ; receipt age `3Y2` | one grid, and since today one exact function for it. **the epoch is frame level 1** modulo 385280 ; a Y3 ledger frame is one of 169 in an epoch. the float epoch functions are still in use and differ at 10082 boundaries [ contradiction 5 ] |
| occupants | n7fs integer placement with a declared `domain` label per holder [ **checked** ] ; `v7-zenki` managing zenki ; cube session and route ids per hop | "who serves this place now". today a registry or a manager decides everywhere. derived occupancy is a design |
| journal | `AMOS7::N7FS::Journal` [ **checked** : signed, sequence, BMW chain, fork rules ; uses `JSON::PP` ] ; designed : `AMOS7::NRT::journal` ; design only, in the n7fs open section : the add-only writer chain with anchors and a ratchet | **one envelope, decided** : the canon form of `N7FS-FORMAT-4.md` for n7fs and the ledger, one parser, one signature rule. **not one security model** [ contradiction 21 ] : each journal keeps its own order, witness and recovery rules, and the add-only writer needs what no envelope gives |
| gate | n7fs `cycle` states and floors ; ledger saturation ; fair-exchange ring states ; `base.curve.*` thresholds [ **checked** : cancel, compose, eval, eval.position, init, register, tick ] | "a step cannot begin while the previous one is incomplete, and a stuck run names the one gate that did not open". a discipline, in separate code |
| parents | home [ root signer, keys, receipts ] ; the ledger witness ; the accounting parent of a pool ; a zenka's host ; the tree root | three roles [ section 1 ]. home is anchor and reads everything ; only the accounting parent is blind |
| reduce | ledger `settle` and the aggregate it writes for an accounting parent ; drill records | per window, deterministic. n7fs receipts with coverage digests are **holder proofs**, not reductions of a subtree |
| irrigate | ledger dissemination [ section 4 there ] | capped proportional filling of a conserved amount. n7fs calculated placement, "spending the next byte where priority x survival gained is highest" under hard floors, is an **optimization**, not proportional filling ; the two share the picture of a limited supply and nothing in their rule |

routing can be read as three layers of one path [ a proposed reading, the
sources do not state it, and the worst-fitting part of this document ] : the
**address** says where [ prefix descent ] ; the **ring** says through what ;
the **hop program** [ countdown + turn bit ] and the cube's per-hop ids are
the local spelling of one step.

## 4. does the ledger fit, or contradict ?

**it fits, and it is the most complete statement of journal, gate and
accounting parent that exists.** nothing in its shape `share -> slot ->
reserve -> saturation -> usage -> proof -> transaction` is foreign to the
vocabulary :

- a pool's address is the checksum of its own definition : "nobody grants it,
  anybody can fill it" is rule 2 word for word, and the same sentence the
  network-as-computer thread uses for a template's address
- "the journal is the only state" is the journal part ; "saturation is the
  agreement" is the gate part ; "what a narrow or unlisted pool uses is still
  represented at a wider one" is the accounting parent
- prepaid, wait, never debt = "postpone, never degrade" of the latency grid
- a reservation that moves nothing = a booked time cell

it rubbed against the other threads in six places [ contradictions 1, 2, 3,
6, 9, 12 ], and the review found four more inside it or between it and
format 4 [ 18 to 21 ]. those four are settled in the ledger text of this
revision.

## 5. contradictions, each with a proposed resolution

1. **pools : a tree, or not a tree.** the ledger says "pools are not a strict
   tree" [ non-exclusive categories ] ; the aligned pyramid of the
   network-as-computer thread needs every contribution in exactly one
   aggregate, or errors add up upward. -> both, on two different edges : at
   most one **accounting parent** per cell [ strict, it carries
   conservation ] and any number of **references** [ membership, views ;
   counted nowhere ]. a reference is the dated form `<Ca>:<epoch>:<Cb>` of
   the namespace thread, so it expires by itself. the parent is already a key
   of the `pool` record and so already in the pool's address ; the one open
   decision is whether every pool **must** name one [ question 4 ].

2. **how wide is a tree edge.** checksum parenting uses the 7 character AMOS
   checksum and claims "whole-tree collision protection for free". the claim
   holds for one question only : "is this the node, given the name and
   parent i hold ?". it does not hold for lookup or against someone
   searching for a second pair on purpose. **checked** : the checksum is a
   32 bit number written as seven base32 characters, the last holding two
   bits. so 32 bits, not the 35 the first text and the ledger named : under
   an even spread two entries share a value with a chance of one half near
   77 000 entries, and almost surely [ about 98 % ] at 185 000 ; truth
   harmonization may make the spread less even. -> the **identity** edge is
   BMW [ L13 where short, 384 where it signs or pays ] ; the AMOS 7 is the
   **route prefix and the readable form**, the "lower resolution
   perspective" the thread itself describes, never a lookup key that is
   taken as unique. the name constraint stays.

3. **three roots, and what "identity" names.** the design doc roots a tree
   at an empty parent ; implicit anchors make the checksum of the empty
   string the parent of every new file ; the epoch sub-thread makes the root
   the rolling common prefix of three epochs. the first two are different
   values. the code settles which one is built : the root is
   `child_chksum( '', name )`, over `'.' . name` [ **checked**, b0eaa4732 ].
   -> two views over the same nodes : the **identity tree**, timeless, rooted
   at the empty parent [ lineage, version history, attribution ] and the
   **occupancy view**, dated, rooted at the epoch [ who holds now, which
   references are alive ]. and a correction : the identity of an n7fs node
   is its **content part** `<amos>/<bmw>`. the full address
   `<epoch>/<amos>/<bmw>` is not timeless : its epoch part says when it was
   placed, and an upgrade through the epoch window changes it for every node
   [ `N7FS-FORMAT-4.md` section 4.3.2 ; the in-place path keeps it ]. so
   "identity never rolls" is true of the content part and of the nested
   checksum tree, not of an n7fs address as built.

4. **time as an address : three digit systems.** implicit anchors : "a base32
   ntime is itself a prefix address ... the Y levels are its natural steps".
   **checked** : `ntime_to_b32` BER-packs the number, then base32-encodes it,
   so a shorter prefix is a binary window with continuation bits in it, not
   a Y level ; Y levels step by 13 ; and the epoch string packs
   `99999999 - epoch`, running the other way. 13 does not divide the ntime
   year, so a Y boundary is not a whole ntime. each grid is exact, they do
   not nest in each other. -> three spellings with three jobs, never mixed :
   the **Y path** [ the base 13 digits of the exact frame index, one per
   level ; `AMOS7::cell::time::path` ] is the address of a time, thirteen
   children tile one parent ; the **base32 ntime** is the timestamp ; the
   **epoch string** is the directory name of an n7fs epoch. also, a number :
   the memory note calls an epoch "about one week" ; code and the n7fs table
   say 28.08 days.

5. **one grid, three calculations.** `epoch_num` and `y_level_ntime` divide
   in floats [ **checked** ] ; the ledger forbade floats and planned its own
   index. the first text expected no disagreement for whole ntimes. **that
   expectation was wrong, and it is measured now** : the test of
   `AMOS7::cell::time` walks every level 1 boundary of the whole 385280
   wrap, and the float `epoch_int` gives another epoch at 10082 boundary
   instants, off by one [ a quotient of x.9999.. is cut down ]. the first
   lies about 13.5 years ahead, so every n7fs address written so far is
   right under both rules. -> one exact function, `AMOS7::cell::time`,
   called by all : the ledger from its first line of code ; n7fs through a
   versioned step, because a quiet change of the rule would let two hosts
   disagree about one epoch one day [ `N7FS-FORMAT-4.md` section 4.6 ].

6. **which clock.** n7fs keeps running on a clock floor ; the ledger fails
   closed, and continues only on the deliberate `-accept-clock` ; the cell
   text speaks of only-growing integers "like the clock floor". -> the
   ledger's own answer, made general : **order comes from the journal's
   sequence, time only places a record in a window**. a cell that only
   stores may run on a floor ; a cell that pays may not.

7. **history and balance are different integers.** "accumulated torque ...
   released when its threshold is reached", the iris ledger "consumption
   clears bits", against "only-growing" and the ledger's "nothing is
   forgotten". -> two kinds per cell, never mixed : **history** [ sequence,
   count, torque, issued supply ; only grows ] and **balance** [ a fold, can
   reach zero ]. a release at a threshold is a record that moves balance one
   step ; the count it came from stays. the namespace thread says the same
   of love : "the pool can be spent to zero, the COUNT of declarations stays".

8. **who computes the weight.** derived placement needs inputs every party
   computes alike. capacity, reliability, latency are measured, by someone.
   the latency thread wants the grid "opaque from below" so nobody can skew
   it ; derived placement wants it computable by everyone ; n7fs still asks
   "does a holder know a blob's priority at all, or does only home decide".
   -> **not resolved.** the first text proposed two stages : candidates from
   public inputs [ address, holder key, window ], then a choice by measured
   weights that the cell's parent publishes as one signed record per window.
   that makes a ranking reproducible once published. it does not make the
   measurements honest, it moves the authority to whoever signs the weights,
   and "nobody can choose the candidates" is too strong while a holder can
   make keys until one ranks well and while the set of holder keys comes
   from a registry. the two stages stay as a proposal for the form ; where
   the authority sits, and what makes a key costly, is question 7.

9. **5 of 7 is used everywhere and designed nowhere.** portals, recipe
   validation, the home ring, fair exchange and session admission all rest on
   it. the ledger states the gap : seven keys are not seven controllers. -> one
   membership design, before any of them : admission by independent control
   domain. the n7fs `domain` label is the existing notion, and it is a
   **declared** label, not evidence of independent control. until then every
   5 of 7 in these threads is a picture, and the built form is one parent
   [ home, one witness ].

10. **two rings under one name.** ring routing : every member holds `K_R` and
    any member can undo the wrapping. home ring and fair exchange : "the ring
    must NOT be able to read along", key shares, k of n. and a ring routing
    "center" is a single waypoint, while a portal "must not be a single
    ruler". -> name both : a **routing ring** [ shared symmetric key, cheap ]
    and a **custody ring** [ shares, k of n, never the whole ]. what the
    names do not settle : replacing a shared key with the window is rotation,
    not the forward secrecy the routing source asks for, least of all while
    three windows are valid at once and an old key may be kept ; a ring's
    lifetime in its source is administrative or one session, not an epoch ;
    and "a center is a cell with occupants" needs a way to choose those
    occupants and to keep a route consistent while they change, which is the
    source's own open phase 4.

11. **the toll rests on the one class without a proof.** the latency thread :
    access to higher functions is paid with generic blind work, its example a
    relay that cannot know for whom it relays. the ledger : `transport` has no
    proof of delivery, two ends that collude invent traffic ; only `store`
    has a proof of amount. -> the first toll is **storage** : holding sealed
    bytes blind is generic, content-agnostic work, and it is the one that can
    be checked today. one receipt proves a moment ; a span of holding counts
    only between two full receipts, as the ledger pays it. transport joins
    when it has a proof.

12. **a recipe is a copy, and the ledger cannot see it.** n7fs : "a copy may
    be a RECIPE instead of stored bytes". the ledger pays `store` per sealed
    byte on a holder, between two full receipts ; a recipe has no bytes. ->
    a recipe is not `store`. it is a `work` item with a price per recreation,
    and the first `work` proof that needs no quorum for **correctness** : the
    BMW checksum of the result is known before the work starts. a correct
    result does not show that the holder made it itself, can make it again
    offline, or keeps the recipe and every pinned input. so a recipe is no
    durable copy by its result alone, and the integer floors keep counting
    bytes only [ proposed ; owner question 6 ].

13. **the picture is the ledger, or shows it.** "the image IS the ledger ...
    the histogram validates conservation", against the ledger's "a display,
    the journal stays the truth". -> a view is a cache like every other
    derived state. the histogram checks the picture against the fold of the
    journal, never the journal against the picture.

14. **dedup counts once, redundancy is paid every time.** "ten copies count
    once" stands beside placement that wants several copies and a ledger that
    pays each holder. -> they count different things. dedup is about **what**
    a thing is : one identity, however often the bytes exist. redundancy is
    about **held bytes over time** : work, proven per holder and frame. an
    **unattested duplicate of the bytes** adds no standing to the content and
    earns its holder exactly the holding. a reference, a source of its own
    quality or an attested carrying relation is not a duplicate : the
    network-as-computer thread counts those toward relevance, and this
    resolution does not take that away.

15. **present to the parent, private to everyone else.** honest presence :
    even the unlisted "must still be REPRESENTED IN RESOURCES" at a parent.
    the ledger : a journal is not published whole, fills are what reveal a
    person. ring routing : the center learns nothing of the origin. -> they
    agree only when the roles are split [ section 1 ]. the **accounting
    parent** sees amounts per class per window, no content, no names of
    fillers, and cannot verify what it is told beyond the totals fitting.
    the **witness** replays signed records with accounts, providers, slots
    and proof ids, and n7fs **home** holds keys and the sealed map ; neither
    is blind. one party that is both blind and verifying would need a
    selective-disclosure design, which the ledger says is not designed.
    whether size class and change timing may show to the accounting parent
    is owner question 9.

16. **formats.** the rule is no json for internal data ; n7fs journal,
    receipts and signed requests are canonical JSON as built [ **checked**
    for the journal ]. -> **closed by the owner** : `N7FS-FORMAT-4.md`
    replaces every json record with one canon form ; that form is also the
    ledger journal form ; receipts move to it before the ledger's stage 2, so
    the ledger never reads json.

17. **one separator, two spellings.** the design doc hashes `C1:name` and
    writes `<C0>:<C1>` ; the code hashes `parent . '.' . name` and writes
    `[child:parent]`. the `[CHECKSUM:NAME]` of a third doc is only its
    title, its example agrees with the code. -> the code is the truth, and
    since b0eaa4732 it is a complete definition : the empty-parent root, a
    parent of exactly 7 characters, a dot-free name [ so the joined input
    reads one way only ], and a verification that compares the parent. the
    form is frozen by that commit and its fixed test vectors. left to do :
    correct `CHECKSUM-PARENTING-NAMESPACE-TREES.md` to it.

found by the review, between the ledger, format 4 and section 1 :

18. **an only-growing journal that could be shortened.** section 1 says the
    journal only grows ; the ledger's `recover` cut an interrupted settle
    tail. -> settled in the ledger : `recover` appends a `void` record, the
    records of a void pass stay and never count, and committed, pending,
    void and torn are defined [ ledger section 5, rule 14 ].

19. **"the only state", and proof bytes that must be kept.** everything
    beside the journal was called a deletable cache, yet used receipts must
    be archived. -> settled in the ledger : archived proof bytes are
    **evidence**, bound by their BMW384 in the `usage` record. deleting them
    changes no balance and ends the second check of that proof ;
    `nrt verify` and `nrt verify -proofs` name the two depths.

20. **one form, two schemas.** format 4 puts `pub` before `sig` in every
    signed head ; the ledger record had no `pub`, and one flat record for a
    transaction the owner allows any number of parties in. -> settled in the
    ledger : `pub` in every record, checked against the kind's signer rule ;
    a transaction carries a body of `-` and `+` rows.

21. **one envelope is not one journal.** the n7fs journal rests on a store
    key, a sequence and a BMW chain ; the add-only writer needs outside
    anchors and a forward ratchet because a taken-over writer could rewrite
    its past ; the ledger adds a witness, the settle pass and `void`. ->
    what is shared, and decided, is the parser and the signed envelope. the
    rules of each journal stay its own, and the add-only writer is still in
    the n7fs open section, not something that exists.

22. **wrap, path and window.** 385280 = 13 x 29636 + 12 : the epoch wrap is
    not a year boundary. -> settled in `AMOS7::cell::time` [ **checked** ] :
    `frame` and `path` are absolute and never wrap, so the pyramid stays
    aligned across the wrap ; `window` brings its frame into 0 .. 385279
    before it takes the neighbours, where the older `epoch_window` does not
    for an input of 385280. `y_level_ntime` returns a length, not a frame :
    it needs an adapter, not a replacement.

not contradictions, but not reduced to a mechanism either, and not to be
built from this document : the pulse rule and PYTAURAZUMA numerics, the
45 degree transit grid, spheres of cubes, the audible channel. they describe
how the cell tree should feel and look ; no part above depends on them.

## 6. ready to build, and what needs the owner

**built** : the exact Y grid [ section 7 ] ; the nested checksum with root
and parent check [ contradiction 17 ].

**ready** [ no open decision, nothing live is touched ] :

- **a.** the shared canon parser : `N7FS-FORMAT-4.md` stage 1. new files, no
  kind, no domain. its home is recommended there [ `AMOS7::cell::canon` ]
  and is that document's question 2 ; the work does not wait for the name
- **b.** after a : ledger stage 1a as `RESOURCE-ACCOUNTING-UNIFIED.md`
  section 11 specifies it now, in the canon form. it is the first journal
  built to the rules of section 1
- **c.** a read-only audit of the name constraint : does every entity type
  [ models, tasks, dep edges, consensus groups, remote nodes ] have a name,
  never only a checksum, and is every name dot-free as the nested checksum
  now requires
- **d.** a **dry run of derived placement** on the exact grid. pure
  functions `weight( address, key, window )` and a ranking, given holder
  ids as arguments, printing what derived placement would choose next to
  what the integer placement chose. it reads no live n7fs tree and writes
  nothing. it shows a ranking, it answers nothing of contradiction 8

**decided** :

| decision | by | where it stands |
|---|---|---|
| the word `cell`, the root `AMOS7::cell` | owner | section 1 |
| where the grid lives, and who calls whom | owner [ the name ] ; the direction follows from what is built | `AMOS7::cell::time` holds it. `AMOS7::NRT::frame` calls it ; n7fs moves onto it by a versioned step [ format 4 section 4.6 ] |
| one record form | owner | the canon form of format 4, for n7fs and the ledger. an envelope, not a journal mechanism |
| the hashed separator form | owner, by commit b0eaa4732 | `parent . '.' . name`, written `[child:parent]` |
| receipts before ledger stage 2 | owner | format 4 stage 3 |

**needs the owner** :

| decision | blocks |
|---|---|
| identity edge width [ contradiction 2 ] | any stored tree address |
| the two views, and identity as the content part [ 3 ] | the namespace tree implementation, re-creation after a delete |
| must every pool name an accounting parent [ 1 ] | ledger stage 1b pool addresses |
| the Y path as the time address, and its spelling [ 4 ] | time-addressed search, booked time cells |
| who signs weights, what makes a key costly [ 8 ] | calculated and derived placement going live |
| the membership design [ 9 ] | every 5 of 7, several ledger domains, the home ring |
| two ring kinds, and whether a ring is a cell at all [ 10 ] | ring routing phase 1, fair exchange |
| storage as the first toll [ 11 ] | the access model |
| recipes as `work`, floors on bytes [ 12 ] | recipe copies, ledger stage 2 scope |
| what an accounting parent sees [ 15 ] | unlisted categories, several domains |

**not ready, by the sources' own word** : several ledger domains, a transport
proof, the handover state machine of the home ring, mutual harmonization
beyond the flattened single loop, the add-only writer, anything that makes a
live n7fs tree depend on a computed weight.

## 7. the first step : built

**one exact function for the grid every thread stands on**, as
`AMOS7::cell::time` with `bin/test-scripts/test-cell-derive.pl` [ 3bef478fe ;
**checked** ]. no state, no network, no zenka, no live tree.

    frame( ntime, level )   =  floor( ntime x 13^level / 132451200000 )
    window( frame )         =  ( previous, current, next ), each in 0 .. 385279
    path( ntime, level )    =  the base 13 digits of frame( ntime, level ),
                               coarse first

- whole number arithmetic [ `Math::BigInt`, `Math::BigRat` for a fractional
  ntime ], a decimal string in, no float anywhere ; levels 0 to 7 ; a
  malformed ntime or level gives no answer
- `frame` and `path` are **absolute** : they do not wrap at 385280. only
  `window` is taken modulo 385280, which is the n7fs epoch cycle and not a
  boundary of the grid [ contradiction 22 ]
- names, `bin/harmony` as a hint : `AMOS7::cell` as a namespace root only
  [ TRUE ], `AMOS7::cell::time` [ TRUE ], the test [ TRUE ]. for step d :
  `AMOS7::cell::weight` [ TRUE ]. for the canon parser :
  `AMOS7::cell::canon` [ TRUE ]. tried and FALSE : `cell::window`,
  `cell::frame`, `cell::grid`, `cell::path`, `cell::gate`,
  `AMOS7::NTIME::frame`

what the test found, which the first text only expected :

1. the float `epoch_int` \ `epoch_num` differ from the exact frame at 10082
   level 1 boundary instants over the whole wrap, always by one. the list is
   written out by the test as a known defect of the float functions
2. none of them lies in the past. the first is about 13.5 years ahead
3. the test walks levels 0 to 7 and the pyramid : `frame( n, L+1 )` divided
   by 13, rounded down, is `frame( n, L )`

what follows, and is not done :

- **n7fs** still stamps and windows with the float rule. its addresses are
  correct today. the move to the exact rule is a step with a version and a
  way back, folded into the format 4 plan [ `N7FS-FORMAT-4.md` section 4.6,
  stage 9 ]
- **the ledger** calls `AMOS7::cell::time` from the start and has no index
  of its own
- `base.ntime.epoch_dec` and `AMOS7::NTIME::y_level_ntime` are untouched.
  each moves by the owner's word for that caller

## 8. owner questions

1. **decided** : `cell` is the word, `AMOS7::cell` its namespace root.
2. **edge width.** BMW for identity edges and the AMOS 7 as route prefix and
   readable form [ contradiction 2 ; the AMOS 7 is 32 bits ] ? if yes : L13
   or 384 for tree edges ?
3. **decided** [ owner 2026-11-23 ] : yes to both -- the identity tree
   [ timeless, rooted at the empty parent ] and the dated occupancy view
   [ rooted at the epoch ] are the meaning of the two root ideas, and the
   identity of an n7fs node is its content part `<amos>/<bmw>`, the epoch
   part is occupancy. owner : "identity is entropy presence, brought or
   created, while time is environmental position, as space coordinates
   itself, even if relative". the host memory design uses the same split
   [ data/tasks/host-memory.md : identity strand and chain = identity tree ;
   presence signatures, sync receipts, epoch buckets = occupancy view ].
   re-creation after a delete [ owner ] : like text-to-image with a seed --
   both kinds exist and each may be wanted. an EXACT re-creation [ same
   recipe, same seed, bit-identical ] has the same content part : the same
   identity, a new occupancy [ the occupancy view keeps the gap ]. an
   EQUIVALENT re-creation [ same recipe, same quality level, other bytes ]
   is a new identity with a 'recreates' edge to the old one in the identity
   tree. ties into question 6 [ recipes ].
   owner : technically it is always exact -- what differs is whether all of
   the entropy that went in was tracked [ seed, model and tool versions,
   hardware nondeterminism, inputs ], lost track of, or specifically not
   tracked [ on purpose, e.g. for variation or privacy ]. so 'equivalent' is
   a statement about the recipe's record, not about the process : a recipe
   names which entropy it tracks, and its re-creations are exact up to that.
   three views in time [ owner 2026-11-23 ] : the identity tree [ timeless :
   what it is, where it comes from ], the occupancy view [ now : who holds
   it ], the **future cycle agreement view** [ ahead : who was assigned which
   available slot in which cycle ]. a slot is a ledger unit [ storage,
   compute, bandwidth, attention ] on a future cycle ; an agreement is signed
   by both sides, a forward receipt. when the cycle comes it becomes
   occupancy, or it is missed.
   missed, in steps : several thresholds [ late, missed, forfeited ], each
   may reassign the slot -- possibly as another resource type : an idle
   compute slot is better used by a background task or a cold storage
   transport than by nothing, unless a temperature \ utilisation policy for
   that time bucket keeps it idle on purpose. today's instances of the same
   view : system.disk-register, store shares with a ceiling, the timed dns
   trust, base.interval rhythms.
4. **pools.** must every pool name an accounting parent, or may a pool stand
   with none [ contradiction 1 ; the parent is already in the address where
   it is named ] ?
5. **time address.** the Y path as the address of a time, the base32 ntime
   only as the timestamp [ contradiction 4 ] ? how should a digit be
   written : one base32 character per level, or the decimal `d.d.d` ?
6. **recipes.** is a recipe a `work` item whose result is proven by its
   known checksum, and do the integer floors count stored bytes only
   [ contradiction 12 ] ? or may a recipe stand in for one copy above the
   floor, and what would then prove that it can be made again ?
7. **weights.** who may sign the measured weights of a window, and what
   makes a holder key costly enough that candidates cannot be chosen by
   making keys [ contradiction 8 ] ? is one window the right pace ?
8. **the toll.** storage as the first generic work that opens access
   [ contradiction 11 ], transport later ?
9. **what an accounting parent sees** of an unlisted or private child :
   amounts per class per window and nothing else [ contradiction 15 ] ? may
   size class and change timing show as shimmer, or is even that too much
   for some categories ?
10. **rings.** two kinds with two names, routing ring and custody ring
    [ contradiction 10 ] ? and is a routing ring meant to be a cell at all,
    "the occupant set of a prefix level", or a group of its own kind beside
    the tree, as its source reads ?
11. **membership.** is the n7fs `domain` label the right seed for the
    5 of 7 admission rule [ contradiction 9 ], and who may attest that two
    domains are independently controlled ?
12. **decided** : one record form, the canon form of `N7FS-FORMAT-4.md`, for
    n7fs and the ledger ; the parser knows no kind. the home of the parser
    is format 4 question 2.
13. **decided** : the grid lives in `AMOS7::cell::time`. the ledger's
    `AMOS7::NRT::frame` calls it, n7fs moves onto it by a versioned step.
14. **decided** [ by commit b0eaa4732 ] : the hashed form is
    `parent . '.' . name`, written `[child:parent]`.
15. **the epoch length.** the memory note says about one week, code and the
    n7fs table say 28.08 days. is 28 days the intended rolling window for
    placement and reference expiry, or was a finer level meant there ?

## 9. what this document does not claim

- that the mapping proves anything works, or that the threads share a
  mechanism. it shows that several texts can be named with the same parts.
  what is specified to the point of a test is the grid [ built ], the canon
  form [ format 4 ] and ledger stage 1
- that every thread fits. ring routing fits worst, the latency thread names
  a problem more than a part, and n7fs placement is not irrigation
- that derived placement, rings, 5 of 7 or several domains are near. each is
  behind a decision in section 6
- that the routing reading in section 3 and the ring reading in question 10
  are the owner's. they are this document's, offered for a yes or no
- that contradiction 8 is resolved. it is stated
- that one record form makes one journal. it makes one parser

## 10. review response [ K3.1, 24 findings ]

verdict per finding : **accept** = the finding stands and the texts are
changed as it asks, or it confirms a point and nothing has to change ;
**modify** = the problem stands, the remedy is another one ; **reject** = not
followed.

| # | finding | verdict | what changed, and why |
|---|---|---|---|
| 1 | the pool parent is already in the definition | accept | contradiction 1 and question 4 now ask only whether a parent is mandatory ; ledger section 3 says the same |
| 2 | the AMOS 7 is 32 bits, the 185 000 figure is wrong | accept | contradiction 2 ; ledger section 3 and threats : 32 bits, one half near 77 000 entries |
| 3 | "identity never rolls" against the built n7fs address | accept | contradiction 3 : identity is the content part, the epoch part is occupancy ; the root is the one the code builds |
| 4 | the encoding claims are right, the namespaces need telling apart | accept | contradiction 4 names three spellings with three jobs |
| 5 | the formula is right, the compatibility claim and the tests are too weak | accept | measured over the whole wrap, levels 0 to 7 : 10082 float differences [ contradiction 5, section 7 ]. the claim "expected to agree" is withdrawn |
| 6 | the clock resolution is coherent, `-accept-clock` stays explicit | accept | one clause in contradiction 6 |
| 7 | history and balance : confirmed | accept | nothing to change |
| 8 | signed weights move authority, they do not remove it | accept | contradiction 8 is marked not resolved ; rule 1 and question 7 restated |
| 9 | 5 of 7 : confirmed, the `domain` label is declared only | accept | one clause in contradiction 9 |
| 10 | epoch replacement is no forward secrecy ; the center is open | accept | contradiction 10 lists what the two names do not settle |
| 11 | storage first : confirmed, a span needs two receipts | accept | one sentence in contradiction 11 |
| 12 | a correct result is not a durable copy | accept | contradiction 12 and question 6 |
| 13 | the picture as a checked view : confirmed | accept | nothing to change |
| 14 | "a copy adds no standing" overrules the source | accept | contradiction 14 narrowed to unattested duplicate bytes |
| 15 | an amounts-only parent cannot be witness or home | accept | three roles in section 1, contradiction 15, ledger section 3 and threats |
| 16 | the owner's form decision supersedes synthesis and ledger | accept | contradiction 16 closed, question 12 decided, step b changed ; ledger section 5 rewritten ; format 4 section 2.5 and questions 1, 3 marked decided |
| 17 | two spellings, not three ; the code is not a complete definition | modify | two spellings : accepted. the three code gaps it names [ no root, no input rule, parent not compared ] were closed the same day by b0eaa4732, so the remedy is not "settle before freezing" but "frozen by that commit" |
| 18 | useful as a vocabulary ; ring routing fits worst ; the address row is forced | accept | sections 1 to 3 retitled and rewritten ; a fit column ; the place row no longer claims one derivation |
| 19 | the ledger can shorten its journal | accept | `recover` appends `void` ; committed, pending, void, torn defined [ contradiction 18, ledger section 5 ] |
| 20 | `pub`, and a flat record for many parties | accept | ledger section 5 [ contradiction 20 ]. one limit added : one key signs for one giver, several givers go through a slot, since the canon form carries one signature |
| 21 | "only state" against archived proofs | modify | neither of the two offered remedies as given. the proof stays outside the journal as evidence and is bound by its BMW384 inside it ; two named depths of `verify` [ contradiction 19 ]. binding whole receipts into the journal would publish what a journal must not, and plain trust in admission would hide that a second check exists |
| 22 | wrap, path and window must be kept apart | accept | built that way [ contradiction 22, section 7 ] ; `y_level_ntime` gets an adapter |
| 23 | reduce and irrigate are not one pass | accept | section 1, section 3 : complementary ; receipts are holder proofs, n7fs placement is an optimization |
| 24 | one container is not one journal security model | accept | section 3, contradiction 21, format 4 section 2.5 |

count : 22 accepted, 2 modified [ 17, 21 ], 0 rejected. three of the accepted
ones confirm a point and change nothing [ 7, 13, and 9 apart from one
clause ].

what the review asked for and is still open, on purpose : contradiction 8
[ who signs weights ], the ring questions of 10, and membership. each is an
owner question, and none is needed for the two ready steps.

#,,,.,,,.,..,,.,.,...,.,,,,,.,..,,.,,,.,.,...,..,,...,...,,,,,.,,,,,.,,,.,,.,,
#LOAQ4P5T4GME76DSKX7ZGQUYYEQYPTH757HGTAPW2U7B47HCM77V5HLHOT7FYKEEBSAB24CG453XG
#\\\|BJ6M36Q6IOBH6HFZMPXPV4NYRJ7CCAHY6S27Q6ON3KR423H3XES \ / AMOS7 \ YOURUM ::
#\[7]ZGJKYJAWVZQAO773BNKTKBB4576CDZ6SINH5GZGTRVOPFEE7TGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
