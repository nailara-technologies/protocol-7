# transport design : lanes, local steering, trunks, leases, the three spare bits [ 2026-11-17 ]

design only, nothing here is built. sources read : `TRANSPORT-MARK-BITS.md` [ whole ],
the route decoder of `bin/dev/division-13-table`, `RING-ROUTING-PROTOCOL.md`,
`RESOURCE-ACCOUNTING-UNIFIED.md` sections 17 and 18 and its `transport` class mentions,
the ring contradiction of `SUBSTRATE-SYNTHESIS.md`, the encoding line of `AMOS7::CHKSUM`.
everything else is not read and not claimed [ section 11 ].

second pass, the same day, for the lattice : `data/md/coding-tasks/indexcube-routing-stack.md`
and the five built modules `src/base.indexcube.{push,pop,here,depth,reset}`, the pointer
list of `AMOS-SIGNATURE-FOOTER-BIT-FRAME-HIERARCHY.md` [ the amos-chksum offset as axis
selector ] with `entropy-at-deduplication-root.md` line 82, and the channel list `f0` ..
`f4` of `ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md`. it adds section 3.5, rewrites
conflicts 11 and 12 and the link key lines of section 6, and records the owner's answers
in section 10.

owner decisions taken as fixed : the 3 bits are transient ; the octal mark [ 0 at rest,
1 .. 6 = `+x -x +y -y +z -z`, 7 = up, one way ] ; set = departed, cleared at the
destination = arrived, loss returns by timeout ; the same bit is a lease ; transport is a
workload ; chaining competes for the same bits ; every crossing should look alike.

## 1. the one shape

**an item is at rest in exactly one place. a move is a hold on a link. the three bits name
the link the hold went out through.**

- a **place** is a position in a cell. it has at most seven **links** : six faces
  `+x -x +y -y +z -z` and one way up. there is no link "down" : coming down is always an
  arrival [ the mark 7 is one way ]
- a **hold** is the one mechanism for move, lease and retry. it is opened by `depart`,
  and closed by exactly one of `arrive` and `return` ; a second closing fact is refused
  [ the shape of `settle` \ `void` closing a ledger pass ]. every hold names a **deadline
  frame**, never a duration
- the **mark** is the holder's statement "this item is out through link d". mark 0 =
  no hold : here, free, matching. mark 1 .. 7 = an open hold through that link : not
  here, not free, not matching
- a **carrier** takes a hold as a workload : offer, claim, complete. a taker of any other
  offered workload does the same, so a lease and a move are one state [ section 5 ]

three link classes, one hold rule, three ways to choose the link :

| class | where | how the next link is chosen | traffic shape | hold level [ section 4 ] |
|---|---|---|---|---|
| **step** | inside one cell [ one compartment, one witness ] | relative : forward or a turn U L R D from the heading, with a hop count | unshaped | Y6 |
| **lane** | across a face, between two cells of one scale [ a compartment edge ] | absolute : one octal digit per crossing | one unit size, sent on the tick | Y5 |
| **gate** | upward : to the parent scale, or into a trunk | the digit 7 | constant : one unit per tick per direction, always | Y4 for items, the gate's ledger frame for value |

- a **lane** is the "hyperspace lane" : absolute, between cells and layers
- **local steering** is the step class : the last steps inside a cell, and the first ones
  towards its face
- a **trunk** is a standing pair of gates between two regions that are not parent and
  child [ ledger section 17 ]. for an item it is one gate crossing : it enters with the
  mark 7 and comes to rest, cleared, at the far gate. up, across and down inside the trunk
  are the trunk's own business and are not seen
- a **lease** is a hold whose link leads to a taker [ section 5 ]

the mark is always absolute, the route is what differs. a step route is relative, and the
holder turns it into an absolute face ; the heading it needs is the mark the item came in
with. so one small rule covers both forms :

    exit face = f( incoming mark, first route symbol )        the mark = the exit face

what moves where :

| thing | moves by | truth |
|---|---|---|
| a content addressed item [ data, a task, a record ] | a hold, this document | the hold table ; a copy is harmless |
| value [ drops ] | a ledger transaction through gates, in whole units | the journal [ ledger 17, 18 ] |
| an offer [ a workload waiting for a taker ] | a hold = a lease | the slot of the ledger where it is paid |

value never moves by a mark. the mark is the transport layer's view ; where a ledger slot
exists, the slot is the truth and the mark shows its state.

## 2. the three bits

### 2.1 where they sit [ checked ]

`AMOS7::CHKSUM` encodes `encode_b32r( pack( 'V', $num ) )` : four octets, least
significant first, read as a bit string from the top, 5 bits per character. 32 bits fill
six characters and 2 bits of the seventh. the seventh character is

    value of character 7  =  ( bits 25 and 24 of the checksum ) x 8  +  the three spare bits

bit 25 has the weight 16, bit 24 the weight 8 [ `0x01000000` encodes as `AAAAAAI` ]. the
spare bits are the three lowest bits of the last character and of nothing else. so a mark
changes only the last character, inside its own row :

| stored | 0 | 1 `+x` | 2 `-x` | 3 `+y` | 4 `-y` | 5 `+z` | 6 `-z` | 7 up |
|---|---|---|---|---|---|---|---|---|
| `A` | A | B | C | D | E | F | G | H |
| `I` | I | J | K | L | M | N | O | P |
| `Q` | Q | R | S | T | U | V | W | X |
| `Y` | Y | Z | 2 | 3 | 4 | 5 | 6 | 7 |

a mark is set, read and cleared on the STRING, by this table. no arithmetic on the
checksum value is needed and none is allowed [ conflict 2 ].

### 2.2 the allocation : by the kind of field, never by the bits

the bits do not say how to read themselves. the **kind of the field** that holds the
address says it, and the kind comes from the record or header definition :

| field kind | where | bit 4 | bits 2 1 | values |
|---|---|---|---|---|
| **plain** | every stored record, key, comparison, nesting, log | 0 | 0 0 | 0 only : last character `A I Q Y`, else refused |
| **hold** | the item field of a transport unit ; the in-memory view of a held item or a leased offer | octal mark | | 0 at rest, 1 .. 6 face, 7 up |
| **chain** | a member of an address list : a multi-part item, packed references, a token being filled | continuation : 1 = another address follows, 0 = the last one | member state | 0 member, 1 held for the chain being filled, 2 and 3 refused |

- **plain** is the only kind that may be written to disk or compared. reaching it from
  the other two is one operation, `clear` : the last character back to its row's first
- **hold** uses all eight values, so it has no continuation bit. it needs none : a route
  is not chained in the spare bits [ 2.3 ]
- **chain** follows BER : the continuation is the top bit of the three. two bits remain,
  of which one state is defined. `held` is the fill lease of `TRANSPORT-MARK-BITS` 3.4 :
  drops marked "belong to the token being filled" ; complete = one token, and clearing
  releases them as units. a chain is a body, its members are not looked up one by one
  while it stands, so a direction would mean nothing there
- a hold field and a chain field share values 4 .. 7 with different meanings. they never
  meet : a list member that travels is taken out of the chain [ cleared ] and put in a
  hold field. a parser clears by kind and refuses what its kind does not allow

per layer \ transport type, the same table read the other way :

| layer \ type | field kind | which values occur |
|---|---|---|
| at rest, any layer | plain | 0 |
| step inside a cell | hold | 1 .. 6, the face computed from the relative route |
| lane across a face | hold | 1 .. 6, copied from the route's lane digit |
| gate upward, trunk entry | hold | 7 |
| lease of an offer | hold | 1 .. 6 or 7 : the link towards the taker |
| list \ multi-part \ token fill | chain | continuation + `member` \ `held` |

### 2.3 where the other two uses went

- **continuation of a route** rides the top bit of the route octet, not a spare bit
  [ section 3 : a 7 bit symbol + 1 continuation bit is exactly the BER octet ]
- **the routing digit** is the lane symbol of the route [ section 3.1 ] ; its three bits
  are copied into the mark at the crossing

so the competition for the three bits is settled without a shared meaning : mark in a
hold field, continuation + state in a chain field, digits and route chaining outside.

## 3. the route : how it is expressed and rewritten per hop

### 3.1 one symbol stream, three forms

a route is a stream of 7 bit symbols of the type `00` of the `division-13-table` alphabet,
one symbol per octet, the octet's top bit the continuation [ 1 = another symbol follows ].
the five bits after `00` :

| symbol | meaning | count |
|---|---|---|
| `00 0 0 hhh` | **forward** : keep the heading | 1 + hhh hops [ 1 .. 8 ] |
| `00 1 dd hh` | **turn** `dd`, then go on in the new heading | 1 + hh hops [ 1 .. 4 ], the turn hop is the first |
| `00 0 1 ooo` | **lane** : cross with the octal mark `ooo` | one crossing ; `ooo` = 0 : come to rest here, and what follows is read one scale down, inside this place |

`dd` as in the tool : `00` U, `10` L, `01` R, `11` D. all 32 values are used, none is
free. the form in the tool is not this one : its comment, its code and the notation
`00 <f> <dd> <hhh>` disagree with each other [ conflict 1, question 1 ].

- a longer straight run is two forward symbols ; a turn with more than 4 hops is a turn
  and a forward
- "back" cannot be written. a route cannot bounce between two places, and a step route
  says nothing about where in the lattice it runs : the same symbols are valid in any
  cell, from any entry face
- a lane digit is one crossing and has no hop count. a long way between regions is what
  the gate [ 7 ] and trunks are for
- after a `7` the symbols that follow are read at the scale the item came to : a lane
  digit there is a lane between cells of the parent scale

- `lane 0` is the only way down, and it is an arrival : the item comes to rest in the place
  it reached. symbols after it start a new move inside that place, one scale down. as the
  last symbol it only ends the route, the same as an empty route

a typical route : steps to the face, lane digits, steps in the destination cell. over a
trunk : steps to the gate, `7`, [ the trunk ], steps at the far side. every part may be
missing.

### 3.2 the heading and the turn table

the heading is the last mark in 1 .. 6 the item travelled with. where there is none yet
[ fresh from rest, or just after a `7` ] it is `+x`. a holder so needs no state of the
route : the incoming mark and the first symbol are enough.

the four turns are fixed per heading, with no carried up-vector [ question 2 ]. up is
`+z`, for the headings `+z` and `-z` it is `+x` ; left = up x heading, right handed :

| heading | U | D | L | R |
|---|---|---|---|---|
| `+x` | `+z` | `-z` | `+y` | `-y` |
| `-x` | `+z` | `-z` | `-y` | `+y` |
| `+y` | `+z` | `-z` | `-x` | `+x` |
| `-y` | `+z` | `-z` | `+x` | `-x` |
| `+z` | `+x` | `-x` | `-y` | `+y` |
| `-z` | `+x` | `-x` | `+y` | `-y` |

every row holds the four faces at a right angle to the heading, each once ; the heading
itself is forward, its opposite is never reached.

### 3.3 the rewrite, at every holder

    1  read the first symbol s and the heading h [ the incoming mark, or +x ]
    2  exit face d :   forward -> h     turn -> table[ h ][ dd ]     lane -> ooo
    3  lane 0 : clear the mark : ARRIVED. no symbol behind it : stop. else drop
       it and go on from 1, one scale down, as a new move with the heading +x
    4  count down :
         forward n  ->  n > 1 : forward n - 1        n = 1 : drop the symbol
         turn    n  ->  n > 1 : forward n - 1        n = 1 : drop the symbol
         lane       ->  drop the symbol
    5  no symbol left and d is a face : the next holder is the destination.
       it finds an empty route, and clears
    6  shift the stream to the front, fill the freed octets with fresh random
       octets : the route field keeps its width
    7  open a hold through link d [ section 4 ], set the mark to d, seal the unit
       for that link, send it on the link's tick

- the route only gets shorter in meaning. it names what is still ahead and nothing that
  is behind : no origin, no path taken. its width never changes
- the way back is not in the unit. each holder keeps its hold : the link the item came in
  on, the link it went out on, and two hold ids that are unrelated numbers [ the cube's
  route primitive, `RING-ROUTING-PROTOCOL.md` "the primitive already exists" ]. `arrive`
  and `return` travel back hold by hold
- an empty route in a unit means "you are the destination"

### 3.4 the unit

what travels on a link, sealed whole under the key of that link and direction :

    hold      = <hold id of this link : random, unrelated to every other hop>
    item      = <the 7 character address, marked>      [ a hold field ]
    deadline  = <frame index> : <level>
    route     = <fixed width, section 3.3>
    body      = <the item, filled to the unit size of the link class>

a larger item is a chain [ section 2.2 ] of units : its members travel as separate holds
and the chain record itself is one more item.

### 3.5 the lattice : @INDEXCUBE [ answers question 8 ]

the lattice is the one that exists : `@INDEXCUBE`. nothing new is defined.

- a **place** is a P7REF `TYPE:CHKSUM7:ADDR_B32`. `ADDR_B32` is three octets `X Y Z`,
  each 0 .. 255 : one cube has 256 x 256 x 256 coordinates
- a **scale** is a depth of the stack. `push` descends into the sub-cube of the place on
  top, `pop` returns to the parent. every place is itself a cube one scale down : the
  recursion is the scale, no second structure
- a zenka's own `@INDEXCUBE` is **where it stands** : entry 0 the anchor, the last entry
  `here`. `neighbour` reads it and never writes it

`neighbour( place, mark )`, complete :

| mark | axis [ octet of ADDR ] | step | stack |
|---|---|---|---|
| 1 `+x` \ 2 `-x` | 0 = X | + 1 \ - 1 | unchanged |
| 3 `+y` \ 4 `-y` | 1 = Y | + 1 \ - 1 | unchanged |
| 5 `+z` \ 6 `-z` | 2 = Z | + 1 \ - 1 | unchanged |
| 7 up | none | none | `pop` : the place one entry below |
| 0, as `lane 0` | none | none | `push` : into the place the item rests in |

    axis = ( mark - 1 ) >> 1          0 = X  1 = Y  2 = Z
    sign = mark odd : + 1   even : - 1

the axis number is the offset selector of amos-chksum, "0=X, 1=Y, 2=Z"
[ `entropy-at-deduplication-root.md` line 82 ] : one numbering for the mark, the octet of
the address and the checksum projection. a mark is so `1 + 2 x axis + direction`.

**the axis edge [ 0 \ 255 ].** three ways were weighed :

| way | what a `+ 1` at 255 does | cost |
|---|---|---|
| wrap | goes to 0 of the same cube | no coordinate is a face : a lane has no place, and the only way out is 7. 0 and 255 become neighbours inside one witness, with two shortest ways |
| a silent step up | the step itself crosses into the next cube | the crossing changes the witness domain, the timeout level [ step \ lane ], the link key and the unit shape, and the sender never wrote it |
| **refuse the step, cross by the lane symbol** | a step symbol is returned at once ; the lane digit `d` crosses | the route writer must know where the edge is. it does : it knows the place it starts from |

recommended : **no wrap, and no silent crossing. the edge is the face, and the face is
crossed by the lane symbol only.** this is the shape section 3.1 already has [ "steps to
the face, lane digits, steps in the destination cell" ] ; the lattice only says where
the face is : the coordinates with the octet of that axis at 0 or 255.

- a **lane crossing with the mark `d`** is a carry, one scale up : the parent place moves
  one step on the same axis, the item enters the sibling cube at the opposite edge
  [ 255 -> 0, 0 -> 255 ], the other two octets unchanged. on the stack : `pop`, step,
  `push`, as one crossing with one hold, done by the pair of gates of that face
- if the parent stands at its own edge on that axis, the carry runs on up the stack to
  the first scale where the octet does not overflow. the crossing settles at that
  layer : the nearest layer both sides share, the trunk rule of section 6 and the
  ledger's edge. the mark stays `d`, it is still one crossing
- the carry reaches the anchor [ entry 0 ] and still overflows : refused, the sender gets
  no `depart`. the top scale does not wrap either ; what lies outside is the outside
  bridge [ ledger stage 9 ]
- a step symbol that would leave 0 .. 255 : `return`, reason `edge`, before any hold is
  opened through that link. the walker of acceptance check 10 so runs on plain whole
  numbers with a bound, no modulo

**empty coordinates.** `ADDR_B32` is derived from the identity key [ the task file,
"deterministic from identity key" ], so a cube is sparse : the coordinate one step on is
almost never a zenka. -> the cube's router [ the holder of the parent place ] holds every
coordinate of its cube that no place occupies. all of them are in its one witness
domain, where section 4.3 already allows one deadline for the whole way : a straight run
through empty coordinates is one hold of the router, not one per coordinate. a step
arrives only at an occupied coordinate or at a face [ question 13 ].

**the stack as the hold chain.** a hold is an `@INDEXCUBE` entry, kept by its holder :

| stack | hold |
|---|---|
| `push`, signed at push time | `depart` : the holder signs the hop it opens |
| `pop`, signature verified | the closing fact comes back : `arrive` or `return` |
| the order of the entries is the proof | a hold never outlives the hold that feeds it [ section 4.3 ] |
| one summary signature for n pushes [ "hybrid" ] | one deadline and one journal inside a witness domain |

- the chain of one move is a stack laid over its holders : each keeps **one** entry, with
  the hold id of the hop before it and the one after it [ section 3.3 ]. closing runs in
  reverse order, hold by hold. this is `pop`
- the stack never travels in the unit. the route names nothing that is behind
  [ section 3.3, section 7 ] ; a unit that carried the stack would carry the path taken
- it is one stack **per move**, not the zenka's own `@INDEXCUBE` : a holder has many
  moves open and they close in any order among each other. the entry format and the two
  primitives are shared, the array is not
- **as built this is not yet a signature.** `base.indexcube.push` stores
  `chk-sum.amos( p7ref : timestamp : depth )` : no key, so anyone can compute it, and no
  link to the entry before, so an entry can be put in or taken out below the top and
  `pop` still reads `valid`. for the hold chain an entry is signed with the holder's
  C25519 key over `BMW384( the entry . the signature of the entry below )`
  [ BMW384 for identity, per the synthesis ; the 7 character AMOS value stays the
  address ] [ question 14 ]

**the body diagonal.** the canvas names five channels : `f0` the base grid, `f1` .. `f3`
one 45 degree rotation per plane [ XY, XZ, YZ ], and `f4` the body diagonal, "the one
that bridges rather than occupies", and its source calls the collector on the body
diagonal "the hyperspace trunk". it fits, as a reading and not as a derivation :

| channel | transport |
|---|---|
| `f0` | the six face marks 1 .. 6 : moves inside the base grid |
| `f4` | the mark 7 : the one way that follows no axis. it leaves the grid for the parent grid [ the cube grid mounted at 45 degrees, one scale up ] or runs as a trunk |
| `f4` renders as alpha, not as a colour | a trunk shows a constant stream and nothing of what crosses [ section 7 ] |

`f1` .. `f3` get no transport meaning here. one use follows if it is wanted : a gate that
needs a place by rule and not by choice stands on the diagonal `( n n n )`, the only
coordinates no axis prefers [ question 16 ].

## 4. holds : loss and timeout, on the ledger's frames

### 4.1 the three facts

| fact | written by | says |
|---|---|---|
| `depart` | the holder that sends | item [ plain ], link, hold ids in and out, level, frame, deadline |
| `arrive` | the holder where the route ended, passed back hold by hold | hold id, the frame it was whole in |
| `return` | a holder whose deadline passed with no `arrive`, passed back hold by hold | hold id, the frame of the return |

- a hold is closed by exactly one of `arrive` and `return`. the second one is refused and
  kept as a finding
- **the mark is never stored.** the fact `depart` holds the plain address and the link as
  two fields. a lookup of an address that has an open hold answers "departed through d"
  and does not match ; rendering it gives the marked form. so "set = departed by
  mismatch" holds, and "cleared before any storage" holds too [ conflict 4 ]
- `return` at the origin ends the hold : the item matches there again, with no copy made.
  the marked form named its link all along, so nothing has to be searched

### 4.2 frames, not seconds

every deadline is a frame index of `AMOS7::cell::time::frame` at a stated level : exact,
absolute, never wrapping, no float. the rule is the ledger's "frame N covers frame N + 1"
with one guard frame :

    departed in frame N [ of the hold's level ]
    arrive    valid while whole in frame N or N + 1          deadline = N + 1
    guard     frame N + 2 : nobody closes by return
    return    from frame N + 3 on, by the holder itself

the guard frame carries a clock that is off by less than one frame and an `arrive` that is
still on its way back. a holder whose clock is behind its last fact refuses to write, as
the ledger does.

| class | level | one frame about | a move lives at most | returned after at most |
|---|---|---|---|---|
| step | Y6 | 6.5 s | 13 s | 26 s |
| lane | Y5 | 85 s | 170 s | 5.7 min |
| gate \ trunk, items | Y4 | 18.4 min | 37 min | 74 min |
| gate \ trunk, value | the gate's frame [ Y3, about 4 h ] | | ledger sections 17, 18 | |
| lease of an offer | the cycle of its pool [ one ledger frame ] | | one cycle [ ledger question 18 ] | |

the level of a unit is the coarsest level of the links its route still has to cross, and
the holder that forwards it writes the deadline at that level [ question 4 ].

### 4.3 a chain of holds

- **inside one witness domain** every fact is in one journal, in one order. one deadline
  serves the whole way ; exactly one closing fact exists per hold ; "never in two places"
  is exact there
- **across a domain edge** [ a lane, a gate ] no shared order exists. the rule is : a hold
  never outlives the hold that feeds it. the holder behind the edge gets a deadline at
  least one guard frame of the edge's level before the deadline of the holder in front
  of it, so a `return` reaches the earlier holder before that one acts on its own. the
  far side of a gate writes a fresh deadline in its own domain
- what is left is the two generals case : the far side arrives in time, its `arrive` is
  lost for longer than the guard, the near side returns. then the item is at rest on both
  sides. for a content addressed item that is a copy with one address, harmless, and the
  later `arrive` is the finding that shows it. what must not double [ value, a paid
  lease ] does not rely on the mark : it runs through a slot with cover, and the journal
  pays once [ ledger 18 : done \ the user's side failed \ the service's side failed, and
  "a proof used is refused in every later frame" ]
- a filler unit [ section 7 ] has no hold and no facts

### 4.4 what is proven

an `arrive` fact signed by the holder at the route's end shows that this holder agrees.
it is the ledger's "two signed records that state the same" and no more : two ends that
collude can invent a move. inside one owner's hosts that is harmless. between strangers
the proof of the class `transport` stays open, as the ledger says ; this design does not
close it.

## 5. leases : the same hold

an offer is an item at rest : mark 0, matching, open to every taker that may see it.

| step | fact | mark at the offer's holder |
|---|---|---|
| open | the offer exists | 0 |
| claim | `depart` towards the taker : link, deadline = the end of the cycle that follows | the link towards the taker : 1 .. 6, or 7 for a taker beyond a gate |
| complete | `arrive` : the taker's result, or its proof, came back before the deadline | the hold ends ; the offer is done and leaves the list |
| timed out | `return` from frame deadline + 2 | 0 again : open for a retry or another taker |

- set = dedicated to one taker ; a second claim finds a marked offer and does not match
- **transport is the workload "move this item"** : the carrier's claim is the hold of the
  move itself. so a move needs no lease beside its hold, they are one fact
- a taker that is itself reached over several hops : the offer travels as an item, and the
  hold chain of section 4 is the lease chain. the last holder is the taker
- where the offer is paid, its ledger slot is opened ahead for the same frames
  [ "frame N covers frame N + 1" ] and the cover of both sides is earmarked [ ledger 18 ].
  the mark then only shows what the slot states. a lease without a slot [ our own zenki
  on one host, stage 2 ] has the hold alone
- the fill lease of a chain [ member state `held`, section 2.2 ] is the same rule one
  level down : held members return to `member` when the fill's deadline passes

## 6. gates and trunks

the ledger defines the gate and the trunk for value [ section 17 ]. transport adds the
item side to the same definition, it does not add a second object.

- a **gate** stands at each end of every compartment edge. its definition is its address,
  so its rule cannot be changed. beside the ledger's fields [ the edge, the transmission
  unit `U` in parent drops, the frame, the caps, the cover ] it states for items : the
  **unit size** in octets, the **tick** [ a Y level ], the units per tick and direction
- a **lane** is the pair of gates of one face. a **trunk** is a standing pair of gates
  between two regions that are not parent and child, over the nearest layer both share ;
  with no shared layer there is no trunk [ the outside bridge, ledger stage 9 ]
- **entry** : the item reaches the gate by steps, the route's next symbol is `7`, the gate
  opens a hold with the mark 7. **exit** : the far gate clears it. the item is at rest
  in the far region and its remaining route starts a new move there
- **two rhythms on one trunk**, both constant :

| what crosses | when | as what |
|---|---|---|
| value | the gate's ledger frame [ Y3 ] | `k x U`, netted, one aggregate [ ledger 17, unchanged ] |
| items, sealed instructions, `arrive` and `return` facts | every tick [ proposed Y6 ] | exactly the stated units per direction, filler where nothing waits |

- the sealed instruction "pay this account that much" of ledger 17 is an item. it gets
  its delivery proof from the hold : the `arrive` of the far gate
- what does not fit a tick **waits at the near gate**, in order, as the ledger's amount
  below one unit waits. a full queue refuses new holds at once : the sender gets no
  `depart`, so nothing is in flight that cannot cross [ fail fast ]
- **cover** : a gate that passes an item on before the hold behind it is closed acts
  ahead, as a far gate that pays out ahead does. for paid moves it draws on the gate's
  shadow, held at the layer the edge settles on [ ledger 18 ]
- **a trunk is a workload of the class `transport`** : one slot per frame, opened ahead,
  paid on the two matching signed records of its ends. what is paid is the tick kept
  [ a unit sent, filler or not ], not the octets carried [ conflict 7, question 6 ]
- link keys : one key per link and direction, by domain separation, never one key cut in
  parts : `key = BMW384( word . the link's secret )`. the word is no new label : it is one
  octet, the mark the sender sets on that link, 1 .. 7. the far end of an up link sends
  with the word 0, the one digit that is never a mark in flight ; there is still no mark
  for down. the names `+x` .. `-z` of `TRANSPORT-MARK-BITS` 3.5 are these digits 1 .. 6
  spelled out
- what the offset selector does and does not replace [ section 3.5 : axis = offset ] :

| derived value | by | why |
|---|---|---|
| the octet of a place on one axis, a per axis projection of an address | the amos-chksum offset 0 \ 1 \ 2, no label | public, address sized, and the axis numbering already exists |
| a link key | BMW384 with the mark digit as the word | a key needs 256 bits and more, an amos value has 32 ; it must come from a secret, the offset projects a public value ; and an offset names an axis, of which there are three, while a link has two directions per axis and the gate two more : eight words. one key for both directions of an axis is the link-upgrade fault |

  the digit is the offset and one direction bit [ `1 + 2 x axis + direction` ], so the
  two derivations still share the one axis numbering

## 7. indistinguishable : the traffic shape

the aim : an observer of an edge learns that the edge exists and how wide it is, nothing
else. what each rule removes :

| rule | removes |
|---|---|
| one unit size per link class ; every body filled to it | the size of an item |
| gates and trunks send exactly the stated units on every tick, in both directions, filler units where nothing waits | volume, direction, timing, idle and busy |
| a filler unit is sealed random octets with a valid seal : only the far gate can tell it, and drops it | which units are real |
| the whole unit is sealed per link and direction ; mark, route and deadline are never in the clear | the route, the mark, the item address |
| the hold id is new and unrelated on every hop | following one item over two links |
| the route field keeps its width ; freed octets are filled anew | how far the item still has to go, to anyone without the key |
| the route names only what is ahead ; step symbols are relative | the origin, the path taken, the place in the lattice |
| `arrive` and `return` facts are units of the reverse stream | that something arrived or failed |
| crossings happen on the tick only | the moment an item was handed in |
| marks are never stored or logged | a trace of where an item went, after the hold is closed |

the dial is the ledger's table of section 17, read for items : any size at any time leaks
most ; whole units less ; a cap per tick less again ; one unit every tick always leaks
nothing and costs the idle width. proposed : the last row for trunks and the up gate,
whole units on the tick for face lanes, nothing for steps.

what stays visible, stated plainly :

| party | sees | does not see |
|---|---|---|
| a holder inside a cell | the item address, the link in, the link out, the route still ahead, the deadline | the origin, the path so far |
| the cell [ its witness ] | every step inside it | what happens beyond its gates |
| a gate | what enters and leaves on its own side ; the frames left until the deadline | the other side's steps |
| an observer of a shaped edge | units per tick as defined | everything else |
| the two gates of one edge together | the same item on both sides | |

limits :

- inside a cell nothing is shaped. a cell is one compartment with one witness, which sees
  its payers anyway [ ledger 17 ] ; hiding from the own witness is not claimed
- the deadline tells a holder how many guard frames are left, an upper bound on the edges
  still ahead. the far side of every gate writes a fresh one, so the bound never reaches
  across a gate
- two colluding ends match an item, as two witnesses match an amount. a sender who wants
  more splits the item over chains and ticks
- a thin edge with real units only would leak by timing. that is why the constant unit is
  the proposal for trunks and not the cap
- the mark itself is three bits about the next link. the holder that sets it chose that
  link, the next holder received through it : neither learns anything new from it

## 8. conflicts with existing designs, and their resolution

1. **the route symbol has three readings.** `TRANSPORT-MARK-BITS` 3.1 writes
   `00 <f> <dd> <hhh>` : 8 bits, the symbol has 7. the comment in
   `bin/dev/division-13-table` describes a forward flag with a hop count or a turn with a
   direction. the code [ `decoded_bits_route` ] reads `00 dd hhh` : four turns, no
   forward at all, and prints `=` for a count of 0. -> the three forms of section 3.1 :
   they fit 7 bits, keep the comment's forward \ turn split and the tool's `dd` codes, and
   use the one value left over for the lane digit. the tool's decoder then needs the
   same reading [ question 1, question 11 ]

2. **a decoder drops the mark without a word.** `decode_b32r( 'AAAAAAB' )` gives the same
   four octets as `AAAAAAA` [ checked ]. so "departed by mismatch" is true for a string
   comparison only ; every path that decodes, or cuts a substring short of character 7,
   matches a departed item. -> the mark lives on the string [ section 2.1 ]. every at
   rest lookup first checks the plain shape `^[A-Z2-7]{6}[AIQY]$`, as
   `AMOS7::CHKSUM::Nested` already does, and refuses the rest ; only the mark functions
   may touch a marked form ; a marked form is never passed to a decoder

3. **the octal mark uses all eight values, a continuation bit wants one.** -> not one
   field : the kind of the field decides [ section 2.2 ]. a hold field is octal, a chain
   field is continuation + two bits, and the chaining of a route left the spare bits for
   the octet's top bit [ section 3.1 ]

4. **"setting the mark = departed locally" against "cleared before any storage".** an
   origin that must show the item as departed after a restart would have to store the
   marked form. -> it stores the fact `depart` with the plain address and the link as
   separate fields ; the marked form is a rendering of an open hold, in memory and on the
   wire only [ section 4.1 ]

5. **"never in two places" against "loss returns by timeout".** both together are the two
   generals problem ; no bit flip is atomic across two hosts. -> exact inside one witness
   domain [ one journal, exactly one closing fact ]. across an edge : a guard frame, the
   earlier deadline behind the edge, and the stated rest case of a harmless copy. value
   and paid leases do not rely on the mark [ section 4.3 ]

6. **ring routing.** three points.
   - its header gets "smaller than what arrived" at every ring ; a crossing that looks
     alike needs a constant width. -> smaller in meaning, constant in width
     [ section 3.3 ]
   - its return needs a reversible wrap under a shared ring key `K_R`. the hold chain
     already returns hop by hop on the cube's two unrelated numbers, which is the ring
     source's own "primitive". -> transport needs no ring up to stage 4. a routing ring
     is added where a hold reference must cross a boundary whose holders may change :
     the wrap `T_R` is applied to the hold reference at the gate, and "ring boundary
     timeout-and-purge" of the source is the `return` of section 4
   - the "center" is a mandatory single waypoint ; a trunk is a pair of gates and a route
     here has no waypoint. -> the center of a route is its end : the holder that clears.
     no other center is required by transport
   - `SUBSTRATE-SYNTHESIS` contradiction 10 and question 10 stay as they are : transport
     uses the **routing ring** kind only [ shared key, cheap ], as a group of its own
     beside the tree. it does not need a ring to be a cell, and does not make it one
     [ question 9 ]

7. **the unit of the class `transport`.** ledger section 2 : "byte transported". ledger
   section 17 : a trunk is paid for clean, constant traffic. octets actually carried are
   exactly the load a constant stream hides, and paying per octet would publish it in the
   journal. -> a shaped link is paid per tick kept, an unshaped move per hold closed by
   `arrive` [ question 6 ]. the proof stays open either way [ section 4.4 ]

8. **a gate crosses "only at a frame boundary", and the frame is about 4 h.** right for
   value, useless for items. -> two rhythms in one gate definition : value on the ledger
   frame, items on the tick [ section 6 ]. the rule "only whole units, only on the
   boundary" is kept for both

9. **the lease bit against the ledger's slot hold and the shadow's `reserve`.** three
   things with one shape could become three truths. -> one truth per case : with a slot,
   the slot ; without one, the hold. the mark is a view in both [ section 5 ]. the lease
   length is the reservation length of ledger question 18, one cycle

10. **the mark 7 "up to the parent" against trunks "between regions that are not parent
    and child".** -> 7 means "through the gate that leads out of this scale" : the parent
    or a trunk, which runs over the nearest shared layer anyway. no mark for down : the
    far end arrives, and `lane 0` reads on one scale down [ section 3.1 ]

11. **six faces need a lattice.** the first pass found none : the substrate's cell is a
    base32 prefix with an epoch, a Y level and a phase ; a prefix has 32 children and no
    `+x`. -> resolved : the lattice is `@INDEXCUBE` [ section 3.5 ]. a place is a P7REF,
    its `ADDR_B32` the three octets `X Y Z` ; a face neighbour is one step on the axis the
    mark names, the mark 7 is `pop`, `lane 0` is `push`, the edge 0 \ 255 is the face and
    is crossed by the lane symbol as a carry one scale up. the geometry still sits behind
    the one function `neighbour( place, mark )`, and stages 1 and 2 never call it. what
    stays open is how the substrate's prefix cell and the P7REF place name one thing
    [ question 15, section 11 ]

12. **entropy labels and marks.** `TRANSPORT-MARK-BITS` 3.5 derives six values by the
    labels `+x` .. `-z`, or three by `x` `y` `z`. -> the three axis values need no label :
    the amos-chksum offset 0 \ 1 \ 2 selects the axis. the per direction values are the
    link keys of section 6, BMW384 with the mark digit as the word, and the digits 7 and
    0 serve the gate in place of two more labels. why a key cannot come from the offset
    is in the table of section 6

## 9. stages

| stage | what | needs |
|---|---|---|
| 1 | the codec : marks, chains, route symbols, the turn table, the per hop rewrite. pure functions | nothing |
| 1b | the five copies of the route decoder call `AMOS7::cell::route` [ question 11 ] | stage 1, the consumer check of question 11 |
| 2 | the hold table : `depart` \ `arrive` \ `return`, frames of `AMOS7::cell::time`, the guard rule ; leases among zenki of one host | stage 1, question 4 |
| 3 | steps inside one host : the cube's route handler opens and closes holds, `neighbour` on `@INDEXCUBE`, the router holds empty coordinates | stage 2, questions 13 14 |
| 4 | lanes between hosts : sealed units on a tick over the existing links, the carry at the edge | stage 3, questions 15 17 18 |
| 5 | gates and trunks : constant units, filler, the item side of the gate definition | ledger stage 6, questions 5 6 7 |
| 6 | routing rings on gates | ring phases 1 and 2, question 9 |

### stage 1, sized for one kimi run

new files only : `data/lib-path/pm/AMOS7/cell/mark.pm`, `data/lib-path/pm/AMOS7/cell/route.pm`,
`bin/test-scripts/test-cell-mark.pl`, `bin/test-scripts/test-cell-route.pl`. no other file
is touched, nothing is restored, staged, signed or committed. no sha, no json, BMW \ AMOS
only ; lowercase comments, `[ word ]` annotations ; no copyright \ author header ; the
floor perl 5.32.

`AMOS7::cell::mark` :

    is_plain( $c )            ^[A-Z2-7]{6}[AIQY]$
    mark_get( $c )            0 .. 7, undef for a malformed string
    mark_set( $c, $m )        $c must be plain, $m 1 .. 7
    mark_swap( $c, $m )       $c must be marked, $m 1 .. 7       [ the hop rewrite ]
    mark_clear( $c )          any well formed string -> plain
    mark_name( $m )           rest +x -x +y -y +z -z up
    chain_pack( \@members )   members [ $plain, $state ] -> one string, continuation set on all but the last
    chain_unpack( $string )   -> \@members, or undef

`AMOS7::cell::route` :

    symbol_encode( $kind, $arg, $count )      kind forward \ turn \ lane
    symbol_decode( $bits7 )
    route_pack( \@symbols, $width, $fill )    one octet per symbol, top bit = continuation, the rest from $fill
    route_unpack( $octets )
    turn( $heading, $dd )                     the table of section 3.2
    route_step( $octets, $mark_in, $fill )    -> ( $mark_out, $octets_out, $state )   state : go \ rest \ down

every function is pure : fill octets come from the caller, nothing reads a clock, a file
or a random source. every refusal is `undef`, never `die`.

acceptance checks :

1. `bin/format-code -c` is clean for all four files, with the floor perl too
2. the table of section 2.1, all 32 cells : `mark_set` then `mark_get` then `mark_clear`
3. 10 000 checksums from `amos_chksum` of random input : `is_plain` is true for each ;
   set \ swap \ clear never change characters 1 to 6 ; clear gives the input back
4. `mark_clear( $c )` equals `encode_b32r( decode_b32r( $c ) )` for every mark of 1 000
   checksums ; the module itself calls no decoder
5. refused with `undef` : a wrong length, a character outside the alphabet, `mark_set` on
   a marked string, `mark_swap` on a plain one, a mark of 0 or above 7 in set \ swap
6. `chain_pack` \ `chain_unpack` round trip for 1 to 64 members ; refused : a last member
   with the continuation set, an inner member without it, member states 2 and 3, a
   member that is not plain on input
7. `symbol_decode( symbol_encode( .. ) )` is the identity over all 32 values of the five
   bits ; counts read forward 1 .. 8, turn 1 .. 4 ; a 7 bit value whose type is not `00`
   is refused
8. `turn` : the 24 cells of section 3.2 exactly ; per heading four distinct results ;
   never the heading, never its opposite
9. `route_step` keeps the width for every input ; the octets behind the last symbol of
   the result are the given fill
10. the walk : 10 000 random step routes, each walked by `route_step` until `rest`, and
    by a second, plain walker written in the test on whole number coordinates. the same
    end point, and the number of steps equals the sum of the counts
11. lane symbols : `mark_out` is the digit for 1 .. 7 ; after a `7` the heading of the
    next step symbol is `+x` ; `lane 0` as the last symbol gives `rest`, with symbols
    behind it gives `down` and leaves them in place
12. an empty route gives `rest` and the mark 0 ; a route longer than the width is refused
    by `route_pack`
13. `git status` shows the four new files and nothing else

stage 1 decides nothing that is open : questions 1 [ the symbol form ], 2 [ the turn
table ] and 3 [ the chain reading ] are accepted as recommended [ section 10 ]. the edge
rule of section 3.5 changes nothing in it : `route_step` knows no coordinates, the bound
is the caller's, in `neighbour`.

## 10. owner questions

**owner decisions [ 2026-11-17 ] : questions 1 to 12 are ACCEPTED as recommended**, with
these notes :

| question | decision |
|---|---|
| 1 2 3 6 7 9 10 12 | accepted as written |
| 4 | accepted. the levels and frame counts [ step Y6, lane Y5, gate items Y4 ; arrive N or N + 1, guard N + 2, return from N + 3 ] are STARTING values, to tune by measurement. they stay parameters, never constants in code |
| 5 | accepted. the tick Y6 and one unit per tick and direction are STARTING values, to tune by measurement ; both stay fields of the gate definition |
| 8 | answered : the lattice is `@INDEXCUBE` [ section 3.5 ]. the recommendation "leave it open until stage 4" is void |
| 11 | accepted, with the scope set to five code copies, all to call `AMOS7::cell::route` [ below ] |

questions 13 to 18 are new, from the lattice, and open.

1. **the route symbol.** `00 0 0 hhh` forward, `00 1 dd hh` turn, `00 0 1 ooo` lane, one
   per octet with the top bit as continuation ? recommend yes -- because it is the only
   reading that fits 7 bits, keeps forward, and takes the route chaining off the spare
   bits
2. **the turn frame.** a fixed table per heading, or an up-vector carried with the item ?
   recommend the fixed table -- because a holder then needs the incoming mark and one
   symbol, and no state travels
3. **the chain reading.** continuation = the top spare bit, two bits of member state with
   only `member` and `held` defined ? recommend yes -- because it is the BER position and
   the two unused states stay refusable until a use is real
4. **timeout levels.** step Y6, lane Y5, gate items Y4, lease = the pool's cycle ; arrive
   in N or N + 1, guard N + 2, return from N + 3 ? recommend yes -- because it is the
   ledger's "N covers N + 1" plus the one frame a late fact and a slow clock need
5. **the trunk's item rhythm.** one unit per tick and direction, always, tick and unit
   size in the gate definition, tick Y6 by default ? recommend yes -- because it is the
   only row of the ledger's table that leaks nothing, and the cost is a known idle width
6. **the unit of the class `transport`.** per tick kept on shaped links and per closed
   hold elsewhere, in place of "byte transported" ? recommend yes -- because a count of
   octets in the journal publishes the load the constant stream hides
7. **the mark 7.** also the entry into a trunk, with no mark for down ? recommend yes --
   because a trunk runs over the shared layer anyway and an eighth meaning has no bit
8. **the lattice.** how does a cell get six face neighbours ? answered by the owner :
   `@INDEXCUBE`. a face neighbour is + 1 \ - 1 on the octet of `ADDR_B32` the mark names,
   7 is `pop`, the signed stack is the hold chain [ section 3.5 ]. what it leaves open
   is questions 13 to 18
9. **rings.** does transport take the routing ring as a group of its own beside the tree,
   first use the key set of a gate pair ? recommend yes -- because the ring source says
   no more than that, and the hold chain already gives the way back
10. **copies across an edge.** accept a rare address equal copy of a data item after a
    lost `arrive`, and send everything that must not double through a slot with cover ?
    recommend yes -- because no bit can be flipped on two hosts at once, and a copy with
    one address harms nothing
11. **the tool.** bring `decoded_bits_route` of `bin/dev/division-13-table` to the form of
    question 1 ? recommend yes, after question 1 -- because code, comment and design
    should read one symbol the same way. accepted, scope : the decoder exists in five
    copies, and all five call `AMOS7::cell::route` in place of their own table
    [ stage 1b ] :
    - `bin/dev/division-13-table`, `bin/dev/display-D13-collection`, `bin/dev/bit-desc`,
      `bin/dev/tests/compression/comp-test` [ the path as found ; it is not
      `tests/compression/` at the top ]
    - `src/decoder.base.decode_d13_bits`. its `RT[..]` output has two callers, check
      them first : `decoder.cmd.D13-collection` prints the string ;
      `decoder.zenka.receive_entropy` takes the tag in front of `[` as a counter key in
      `decoder.d13_types`, writes the string to the buffer `level-7-D13` and returns it
      as `d13_decoded`. so the tag `RT` must stay, what stands inside the brackets is
      free to change in `src/`. not checked : readers of that buffer and of the reply
      outside `src/`
12. **where a hold is kept.** in memory only for steps, as journal facts from lanes on ?
    recommend yes -- because a step lives 13 s inside one witness and a restart may
    return it, while a crossing must survive the restart of either end

13. **empty coordinates.** addresses come from identity keys, so nearly every coordinate
    of a cube is empty. does the cube's router hold all of them, with a straight run
    through them as one hold ? recommend yes -- because they are all in its one witness
    domain, which sees every step there anyway, and a dense assignment would need the
    registry the address rule avoids
14. **the stack signature.** make the entry of `base.indexcube.push` a real one : the
    holder's C25519 key over `BMW384( entry . signature of the entry below )`, in place
    of the plain `chk-sum.amos` of today ? recommend yes, before stage 3 -- because
    today anyone can compute it and an entry can be put in below the top unseen, which
    is not what "signed at push time" promises
15. **cell and place.** the substrate's cell is a base32 prefix, the lattice's place a
    P7REF. recommend : the P7REF is the place, its `CHKSUM7` is the cell's address, and
    scale is the stack depth only, never also the prefix length -- because two measures
    of scale are two truths. decide before stage 4
16. **the gate's place.** a rule that puts the gate to the parent on the body diagonal
    `( n n n )` ? recommend no rule now : the gate definition states its place, and the
    diagonal is the default only where a default is needed -- because the `f4` fit is a
    reading, and no stage depends on it
17. **the width and source of `ADDR_B32`.** the task file says three octets, its rule
    takes the first 6 characters of the AMOS value [ 30 bits ], its examples show 7.
    recommend three octets exactly, octet `a` = the first octet of the amos checksum of
    the identity key at the offset `a` -- because it is the axis selector that exists.
    first check that an offset is an own computation and not a cut of one value
    [ cited, not tested here ] ; if it is a cut, take the first three octets of the one
    value, which is harmless for a public coordinate
18. **the axis edge.** no wrap and no silent crossing : a step into the edge is returned,
    the lane symbol crosses as a carry one scale up, the top scale refuses ? recommend
    yes -- because a wrap leaves the lane without a place, and a silent crossing changes
    the witness, the timeout level and the key without the sender having written it

## 11. not claimed

- that the proof of the class `transport` is closed. an `arrive` shows agreement of two
  ends [ section 4.4 ]
- that anything is hidden from a cell's own witness, or from two gates of one edge that
  work together [ section 7 ]
- geometry beyond section 3.5. which places are neighbours and how a scale is entered
  and left is now defined ; how a scale maps onto prefix length or Y level is not
  [ question 15 ], and no cube has been walked : `neighbour` is not built
- that the amos-chksum offset gives independent values per axis. it is stated by
  `entropy-at-deduplication-root.md` and cited from there, not tested in this pass
  [ question 17 ]
- that the `@INDEXCUBE` stack is a proof as built : its entry is an unkeyed checksum
  with no link to the entry below [ section 3.5, question 14 ]
- the `f4` reading as more than a fit of names
- that the frame levels fit real link latencies. they are the Y grid's steps, chosen by
  order of size, not measured
- that the canon kind tables of n7fs format 4 and the ledger journal can carry the three
  facts as they stand. they were not read ; stage 2 starts by reading them
- sizes : the unit size, the route width, the queue length of a gate are parameters of a
  definition, no value is proposed here

#,,,.,...,,..,,,.,.,.,,,,,..,,,.,,...,.,.,.,,,..,,...,...,...,,,.,..,,.,.,.,.,
#3OH6C5VEOHET3KNZ6D7CRISIBPUCAHFMAOXD5V4IXDRTGUONJRAHZUXWKYURFEFKFVPMTUZM4XMEM
#\\\|7JRGPUJJ7632EHPM3GJLHVQJZNTUAT46HT3ZNYBPQ4YDOP23DKV \ / AMOS7 \ YOURUM ::
#\[7]GISML67OA2Z746T3UIZFPCPEGTFVUUD5BHPDKJ3GYQCQPXOH6YDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
