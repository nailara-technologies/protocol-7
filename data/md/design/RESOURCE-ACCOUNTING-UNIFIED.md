# resource accounting, unified : one ledger shape behind NRT \ NRD

status : design only [ 2026-11-16, revised the same day after the K3.1 review,
the owner position on pool authorization, and the owner's answers to questions
15, 16, 19, 22 and 23 ; revised again after the K3.1 review of
`SUBSTRATE-SYNTHESIS.md` and the owner's answers on `N7FS-FORMAT-4.md` ].
nothing here is built. stage 1 at the end is the first buildable piece ;
everything marked `owner` waits for a decision.

what the last revision changed [ details in section 14 ] : the journal is
written in the **canon form** of `N7FS-FORMAT-4.md` section 2, this document
defines no bytes of its own any more ; a transaction with several parties is
one record with a body of rows ; `recover` appends a record and never
removes one ; proof bytes are evidence bound by the journal, not a cache ;
the AMOS 7 checksum is 32 bits wide ; stage 1a waits for the shared canon
parser [ format 4 stage 1 ] ; receipts are in the canon form before stage 2,
so the ledger never reads json.

sources read : `read-me/documentation/dev/NRT.NRD.asc`,
`RESOURCE-ECONOMY-DEMYSTIFICATION.md`, `NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md`,
`TASK-CUBE-CONSENSUS-ARCHITECTURE.md`, `N7FS-SEALED-REPLICAS.md`,
`N7FS-PLACEMENT.md`, `CODING-CHANGE-ACCOUNTING-ARCHITECTURE.md`,
`WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md`, `OSF-CACHE-ZENKA.md`,
`data/md/protocol-7-knowledge/08_NETWORK_INTELLIGENCE/LOVES_IT_RESOURCE_ALLOCATION.md`
[ added in the revision ], `read-me/project-identity/philosophical-foundation.md`
[ "Resource Distribution as Water Irrigation" ], the memory notes `n7fs-host-migration-goal`
[ resource economy paragraph ], `topic-latency-algorithmic-authority-entropy-toll`,
`topic-network-as-computer`, and the code those name [ `AMOS7::N7FS::Placement`,
`::Sign`, `::Record`, `::Sum`, `AMOS7::NTIME`, `src/crypt.C25519.*`,
`src/models.handler.llm_response`, `src/httpd.route.handler.iris-ledger` ].

words used throughout [ the chosen names of section 11 ] : a **transaction**
is the one record that changes balances, a **usage** is a statement of metered
work, a **proof** is what shows the usage happened, an **issue** creates
drops, a **share** is an agreed spending proportion, a **slot** is a
requirement waiting to be filled.

words shared with `N7FS-FORMAT-4.md` and `SUBSTRATE-SYNTHESIS.md` : the
**canon form** is the one record form [ format 4 section 2 ], a **kind
table** the fixed key list of one kind and version ; a **frame** is an index
on the exact Y grid of `AMOS7::cell::time` ; a **cell** is the shape of the
synthesis, of which a pool is one. three roles are kept apart : the
**witness** orders and replays a ledger domain and sees its records ; an
**accounting parent** is told amounts and nothing else ; n7fs **home** holds
keys and maps.

## 1. the one shape

every thread describes the same things with different words :

| thread | what is provided | what proves it today | who pays whom |
|---|---|---|---|
| n7fs | sealed bytes kept over time | root-signed receipt, nonce scrub | owner -> holder |
| osf-cache | bytes served | checksum of the received file | receiver -> server |
| opaque transport | bytes relayed | nothing yet [ vision ] | unknown sender -> relay |
| task cube | a computed result | 5 of 7 agreement on the result | submitter -> workers |
| coding \ llm | inference tokens, gpu time | the server's own usage report | task -> inference host |

the shape behind all of them :

    share  ->  slot  ->  reserve  ->  saturation  ->  usage  ->  proof  ->  transaction

- a **share** is a standing agreement : which proportion of its resources an
  account or a pool spends on which category
- a **slot** signals a requirement : this much work of this category, at this
  rate, costs this many drops
- **reservations** cover the slot, from the shares that match its category,
  from several accounts together where they want the same thing. a
  reservation is local : the drops stay where they are, earmarked
- **saturation** is the agreement. once a slot is covered, the reserved drops
  move into it and nothing further has to be authorized
- the **usage** states what was done under the slot, the **proof** shows it
- the **transaction** pays the provider out of what the slot already holds

two properties carry most of the design :

- **authorization is the agreed proportion, not a signature per use** [ owner
  2026-11-16 ]. a usage is authorized when it matches a category whose share
  still has room in the frame. the same proportions bound how fast an account
  or a pool can be emptied
- **everything is prepaid at the moment of the transaction** [ owner, same
  day ]. what is not covered waits until the pool's value covers it. waiting
  time, never overdraft, never debt

a consumer does not pay a provider directly for network work. drops go into a
pool, the pool's slot pays the provider. a relay is paid without learning for
whom it relayed, and several users fill one slot and share what it buys.

**the guiding picture is irrigation** [ `philosophical-foundation.md` ] :
resources flow like water, every field of interest gets its proportional
nourishment, the network first meets its core needs [ saturation threshold ],
what a field cannot take flows on [ overflow ], and public pools keep the
barrier low for newcomers. a share is the channel, a pool is the field, its
capacity is what the field can take, and water that is not taken is not
lost : it flows on or back, and the next cycle distributes again.

## 2. units

- **drop** [ NRD ] : the only ledger quantity, a whole number. 4200 drops are
  one token [ NRT ]. no fractions exist anywhere in the ledger
- **balance** : NRT.NRD gives "[signed] 13 digit numbers". signed means the
  numeric sign, not a signature. here every account holds 0 to
  9 999 999 999 999 drops ; the one negative balance is the network account
  [ section 3 ], with the same 13 digit limit, so the supply of one ledger
  domain is capped at 9 999 999 999 999 drops [ about 2.38e9 NRT ]
- **amounts** : a transaction carries a whole number of drops from 1 to
  9 999 999 999 999, written without sign, without leading zeros. zero and
  negative amounts do not exist
- **arithmetic** : all multiplication, division and summing is exact whole
  number arithmetic [ `Math::BigInt` ], never native floats, never a native
  integer that can wrap. a result outside 13 digits is refused, not clipped
- **classes** and their native units [ measured, never drops ] :

| class | native unit | state of its proof |
|---|---|---|
| `store` | sealed byte kept for one frame | ready : two n7fs full receipts bound the interval |
| `transport` | byte transported | open : matching counters do not prove delivery |
| `work` | one task item at a price agreed in its slot | open : needs a quorum with a membership model |
| `ltok` | llm token in + out [ `ltok`, so "token" stays the NRT ] | open : only the server counts today |
| `ext` | outside provider usage | report only, never drops |

- **rate** : drops per native units for one class, a whole number pair
  `drops : units`, both above zero. every rate record is a new **rate
  version**, active from a stated later frame. a slot fixes the rate version
  it was priced with ; a later rate never changes a slot
- **carry** : whole number division leaves a remainder of units. the remainder
  is kept per stream [ pool, provider, class, rate version ] and derived from
  the journal on replay, never stored beside it. a stream ends with its rate
  version or its pool ; its remainder is then closed by a record that states
  it [ always worth less than one drop ]
- **frame** : the settlement interval on the ntime Y grid, proposed Y3 [ about
  4 h ]. the ntime year is 4200 x 86400 x 365 = 132 451 200 000 units, which
  13 does not divide, so a frame boundary is not a whole ntime. the frame of
  an ntime is `floor( ntime x 13^level / 132451200000 )` in exact arithmetic.
  that function exists : `AMOS7::cell::time::frame` [ 2b87fcc73 ], and the
  ledger calls it instead of computing an index of its own. a frame index is
  absolute and never wraps. the float helpers of `AMOS7::NTIME` and the n7fs
  `epoch_int` are not used : the latter is off by one at 10082 level 1
  boundaries [ `N7FS-FORMAT-4.md` section 4.6 ]
- **the NRT index** : `value of proven offered resources at current rates /
  weighted accounts`, a reported statistic. it mints nothing by itself and
  never divides by a raw head count. what it may bound is an owner question

## 3. accounts

an account is an address with a balance. four kinds, one record form :

- **key account** : `<AMOS7 checksum, 7 chars><public key base32>` as NRT.NRD
  defines it, the checksum over name, name creation ntime, account creation
  ntime and public key, with a signature of the key over those values. the
  key is the identity ; the 7 characters are a routing prefix and nothing
  is authorized by them. they carry **32 bits**, not 35 : the checksum is a
  32 bit number, four bytes written as seven base32 characters, the last of
  which holds two bits. under an even spread two of about 77 000 entries
  share a prefix with a chance of one half, and a chosen prefix is ground in
  about 4.3e9 tries. held by a person, a zenka or a host
- **pool** : an account with no secret key and, if nobody wants one, no owner.
  its address is the checksum of its own definition [ categories and their
  shares ], so nobody grants it, anybody can fill it, and its rules cannot be
  changed : a changed definition is another pool. a pool's categories come
  from **task template requirements**, or from the occurrence of a **workload
  that matches** the category [ owner ]. what sits in a pool is work that was
  already translated into drops, and it is translated back by spending on the
  pool's categories
- **slot** : the account of one requirement inside a pool. its address is the
  checksum of the slot record. a pool is also a slot : a pool with a single
  category and a single work item is exactly "ordering a pizza". several
  users fill it together and share what it buys
- **network account** : one per ledger domain, the counter of supply. it is
  the only negative balance, it changes only by an `issue`, and it is not a
  debt of anybody

**a transaction is itself a small pool** [ owner ] : by default one benefactor
and one supplier of tokens, any number of either. a transfer between two
accounts is the smallest case of the same thing, so "do drops only move
through pools" is a matter of perspective, not a rule to enforce. what a slot
pays towards may be another pool, an account, a network task or a single
work item.

pools may name one accounting parent, so that what a narrow or unlisted pool
uses is still represented at a wider one [ network-as-computer ]. the parent
is a key of the `pool` record and so already part of the pool's address ;
what is open is only whether every pool must name one [ synthesis question
4 ]. categories are not exclusive : a pool can belong to several contexts by
reference, as the coding design's groups do. pools are not a strict tree :
at most one accounting edge, any number of references.

**what an accounting parent is told** : amounts per class per frame, one
aggregate that `settle` writes for it. no records, no accounts, no proof
ids. it cannot replay the child and is not its witness ; the witness of a
domain sees every record of that domain, and no arrangement in this document
lets one party be both blind and able to verify [ synthesis contradiction
15 ].

**generic template user** : not an account kind. the token architecture says
"the template IS the credential, the proportion IS the authorization". that is
literally the model : a usage that matches a pool category is authorized by
the pool's share, with no identity shown.

## 4. authorization : shares, slots, saturation

**shares.** a `share` record is the standing agreement of an account or a
pool, signed once :

- it is a **local reservation** : it earmarks a part of what the account holds
  and moves nothing. the part can be split, for example 11 % = 10 % for the
  network core + 1 % for public resource pools, and each part divides over
  categories [ work, transport, storage contexts ]
- by default the division inside a category follows the **loves_it
  proportions** of what is asking [ `LOVES_IT_RESOURCE_ALLOCATION.md` : the
  0, 4, 7, 11, 13 scale ]. the scale enters as weights normalised over one
  budget : a 13 gets a larger part of the SAME budget, never additional drops
  [ contradiction 15 ; water is not multiplied by being loved ]
- a pool's share is part of its definition : each category and its weight

per cycle [ one frame, unless the owner sets another length ], for every
share, in exact arithmetic :

    budget of a category  =  held at cycle open  x  part  x  weight / sum of weights

**capacity and overflow.** every pool has a capacity per category : its
expected regular usage plus a comfortable burst margin, and no more. that
makes pools non-greedy. dissemination in one cycle :

1. core first : the core part of a share is offered to the network core's
   pools until each is at capacity [ the saturation threshold ]
2. the public part is offered to public pools, each up to its capacity
3. what a pool cannot take overflows : onward to the network core, or back
   to the giver, as the share says
4. what is left after all overflow is offered again over all of them, in
   equal parts [ "excess resources distributed equally" ], until nothing can
   be taken or nothing is left
5. what is still left expires with the cycle. since a reservation is local,
   expiring means the earmark ends and the drops are simply free again. the
   next cycle disseminates anew

capped proportional filling with the excess passed on is water-filling : small
needs are met in full before large ones get more.

**slots.** a slot is a requirement inside a pool, and a waiting dependency for
whatever needs its result. reservations are made towards it, by a key
signature or by a share with room left in the cycle. each slot states two
choices [ owner ] :

- `buy = complete` : nothing is paid and nothing is triggered until the whole
  requirement is covered. for all-or-nothing work, and it keeps every
  reserved drop free to be redirected until the end, instead of half the
  parts of a device whose best design changed meanwhile
- `buy = as-filled` : for an order-free list of items ; each item is bought as
  soon as its own price is reserved
- `split = equal` [ default ] or `split = fill` : those who filled it share
  what it buys equally, or in proportion to what each put in

    open        less is reserved than is required
    saturated   the requirement [ or one item's price ] is reserved in full
    at saturation the reserved drops move into the slot as `fill` transactions
    work counts only under a saturated slot, from then on
    not saturated : the usage waits. no partial start, no credit

**saturation is the agreement.** no further authorization is needed after it :
whoever serves the slot may act. overfill is allowed, overpay is not defined :
when more is reserved than required, only the requirement is taken. the
surplus stays with the givers, reduced in proportion by default, or exactly
per channel where the reservations can be told apart.

a slot is paid out to the provider on proof, up to what it holds, at the rate
version fixed in the slot. what an ended slot still holds returns the same
way a surplus does.

**work in kind** [ owner ] : an account that gives work instead of drops is
paid normally from the slot. the payment is then directed to the task it gave
the work to, and recorded as a completed donation. two transactions, no new
drops, and the giver's history shows a donation that was really made.

**outside vendors** [ owner ] : for the vendor a slot is a hard dependency that
never involves NRT. a zenka converts to the vendor's currency or payment
method and places the order. this is an edge to the outside and has its own
threats [ section 10 ].

continuous resources [ storage, a running relay ] use one slot per frame,
opened ahead : frame N covers frame N+1.

## 5. ledger shape and conservation rules

one **ledger domain** = one witness, one append-only journal, one signed head.
stage 1 has exactly one domain on one host.

**the journal is the only state.** balances, the set of used proofs, carries,
share budgets and slot states are all derived by replaying it. what is kept
beside it is one of two things, and neither is state :

- a **cache** [ balances, indexes ] : deleted without loss
- **evidence** [ the archived proof bytes of section 7 ] : the journal binds
  each proof by the BMW384 of its bytes, in the `proof-sum` of its `usage`
  record. deleting evidence changes no balance and no answer of a replay ;
  it ends the possibility of checking that proof a second time. so there are
  two depths of checking, and each says which it is : `nrt verify` replays
  the journal and takes a proof as checked when its usage was admitted ;
  `nrt verify -proofs` checks every bound proof again and names each one
  whose bytes are gone

the head is a signed pointer to the last whole record.

record kinds :

| kind | meaning | signed by | body |
|---|---|---|---|
| `init` | ledger id, witness public key, frame level | witness | |
| `account` | opens a key account | that account's key | |
| `pool` | a pool definition : capacity rule, core \ public, optional parent | the account that wrote it [ it keeps no rights ] | table : category, class, weight, capacity |
| `share` | an account's standing proportions : overflow direction, parking rule | that account's key | table : part or category, weight |
| `reserve` | earmarks drops of an account or pool for a slot ; moves nothing | the key, or the witness naming a share | |
| `rate` | drops : units for a class, active from a later frame | witness | |
| `slot` | a requirement : pool, category, class, units, rate version, drops, `buy`, `split`, optional provider | the account that signals it | table : items, where it has any |
| `usage` | work done under a saturated slot : slot, provider, units, proof id, `proof-sum`, interval, `confirms` | provider ; a countersigner writes a second `usage` whose `confirms` is the address of the first | |
| `transaction` | the giving and the receiving accounts, drops, reason, authority | from key, or witness naming a share \ slot \ issue rule | operations : one row per account |
| `close` | ends a slot, a usage or a carry stream, with the reason | witness, or the signer of the closed record | |
| `settle` | closes the settle pass of one frame : the pass, the count of its records | witness | |
| `void` | ends an interrupted settle pass : the pass ; none of its records ever counts | witness | |

every record is in the canon form. a transaction :

    p7 nrt transaction v1
    ledger = <ledger id>
    seq    = 1042
    prev   = <address of record 1041>
    ntime  = 00031703855078
    frame  = <frame index>
    reason = fill
    by     = <address of the share, slot or issue rule, or 0 for a key signature>
    drops  = 4200
    pass   = <seq of the first record of its settle pass, or 0>
    rows   = 3
    body   = <BMW384 of the body bytes>
    pub    = <signer key>
    sig    = <signature>

    - <account address> 17 3000
    - <account address> 4 1200
    + <slot address> 4200

**the rows of a transaction** [ an operations body, its order fixed by the
kind ] :

- a `-` row is a giving account : address, its `from-count`, drops. a `+`
  row is a receiving account : address, drops
- `-` rows stand before `+` rows, each group sorted by bytes. an account
  stands once in a record, on one side only
- the drops of the `-` rows and the drops of the `+` rows each add up to the
  `drops` of the head. the smallest transaction is one `-` and one `+` row :
  a transfer
- **a key signs for one giver.** a transaction signed by an account key has
  exactly one `-` row, the account of `pub`, and any number of `+` rows.
  several givers never sign one record together : each reserves towards a
  slot, and the saturated slot is the one authority that moves all their
  rows at once. that is "a transaction is itself a small pool" [ owner ]
  written down : one benefactor and one supplier by default, any number of
  either through a slot
- an `issue` has one `-` row, the network account

reasons : `transfer` [ key to accounts ], `fill` [ reserved drops into a
saturated slot ], `earn` [ slot to providers ], `donate` [ a provider's earn
on to the task it gave work to ], `return` [ an ended slot back to those who
filled it ], `issue` [ network account to an account ], `park` and `thaw`
[ section 6 ].

**canon form.** the ledger defines no bytes of its own. every record is in
the canon form of `N7FS-FORMAT-4.md` section 2 [ owner, 2026-11-16 : the
format 4 canon form is the ledger journal form, unless a better matching one
is found ]. what that fixes, in short, and where to read the exact rule :

- a **stored label line** `p7 nrt <kind> v1` is the first line of every
  record : magic, domain and version in one. there is no `kind = ` line
  [ format 4 sections 2.1, 2.2 ]
- field lines `key = value`, the keys of a kind in one fixed order, all
  required, **padded** with spaces to the longest key of that kind and
  version, so the `=` stand in one column. the padding is part of the signed
  bytes ; a record with other padding is refused [ 2.2 ]
- **`pub` stands before `sig`**, both in every ledger record. the signed
  bytes are the label line and every line before `sig`, so the key is
  inside. `pub` says who signed and authorizes nothing : replay compares it
  with the key the kind's signer rule names [ the table above ] and refuses
  another [ 2.4 ]
- an optional **body** of rows after the head's empty line, bound by `rows`
  and `body`. flat kinds have neither key [ 2.3 ]
- the address of a record is BMW384 base32 over the stored head from the
  label line through the `sig` line ; `prev` is the address of the record
  before, `0` for the first [ 2.4 ]
- a signature is checked over stored bytes only. a head is checked by
  parsing it and packing it again : the bytes must be equal [ 2.2 ]

what the ledger adds, and all it adds :

- its **kind tables** : per kind and version the keys, their order and their
  types. every ledger kind begins with `ledger`, `seq`, `prev`, `ntime`,
  `frame` and ends with `pass`, then `rows` and `body` where it has a body,
  then `pub`, `sig`
- types : `ntime` is a `stamp` [ a whole ntime as 14 digits ] ; `seq`,
  `frame`, `drops`, `from-count` are `count` ; names are a `word` of
  `[a-z0-9._-]+`, never the bare `-`
- the head file : one record `p7 nrt head v1` with `ledger`, `seq`, `last`
  [ address ], `ntime`, `pub`, `sig`, signed by the witness
- the parser is not the ledger's. it is the shared one of format 4 stage 1 ;
  where it lives is format 4 question 2, recommended `AMOS7::cell::canon`
  [ section 11 ]

conservation rules :

1. **zero sum** : the balances of a domain add up to zero after every record
2. **one balance change, one record** : only a transaction changes balances.
   it names every side in its rows, giving and receiving add up to the same
   `drops`, and no account stands on both sides
3. **never below zero** : no key account, pool or slot ever holds less than
   zero. there are no floors to set, no credit lines, no overdraft
4. **whole, positive amounts** : section 2
5. **one authority per transaction** : a key signature, or a saturated slot
   [ fill, earn, return ], or a share [ donate ], or the issue rule. the
   authority covers every row : a key covers its own account as the one
   giver, a slot covers the reservations made towards it. replay refuses a
   transaction with a row its authority does not cover
6. **proportion budgets** : per cycle, a category of a share reserves at most
   its part of what is held at cycle open, and a pool takes at most its
   capacity. reserved drops cannot be spent or reserved a second time
7. **prepaid** : an `earn` is paid from a slot that was saturated before the
   work it pays for. nothing is paid from a later fill
8. **a proof is used once, forever** : a proof is identified by class, a work
   id and an interval [ section 7 ], not by the address of some file. the
   same work in the same interval is refused in every later frame, for every
   payer
9. **order** : `seq`, `prev` and `from-count` only grow. two records with one
   `seq`, or two rows of one account with one `from-count`, are a fork, and
   a fork is its own proof of fraud. a count is never used again, also not
   one that stood in a void pass
10. **what a slot fixed, it pays** : the provider receives exactly the drops
    the slot holds for the proven units at the slot's rate version. there is
    no second rate and no spread ; paying yourself through a pool returns
    your own drops and nothing more
11. **supply** : only an `issue` changes the network account. supply is the
    sum of all issues, checked on replay separately from the zero sum, and
    never above 13 digits
12. **nothing is forgotten** : an open slot and an unproven usage stay in the
    journal until a `close` record names them and says why
13. **depth changes latency, never amount** : section 6
14. **append only** : no whole record ever leaves the journal, by any
    command. what an interrupted pass wrote stays, and a `void` record says
    that it does not count

**settle** runs once per frame and is deterministic : the same journal gives
the same records. every record of a pass carries `pass`, the `seq` of the
first record of that pass [ known when the first is written, unique for
ever ]. the pass ends with a `settle` record that names the pass and the
count of its records. a frame that has a `settle` record is never settled
again.

**committed, pending, void, torn.** the journal only grows, and these four
words say exactly what counts :

- a **record** is whole : it parses in the canon form, its signature
  verifies, its `seq` and `prev` continue the chain. a whole record is never
  removed
- a record with `pass = 0` is **committed** as soon as it is whole
- a record that names a pass is **pending** until the `settle` record of
  that pass is whole. then the whole pass is committed at once. every fold
  [ balances, zero sum, supply, used proofs, carry ] reads committed records
  only. so a pass counts whole or not at all, and the zero sum holds after
  every committed step
- an interrupted pass is ended by `recover`. it **appends** one `void` record
  that names the pass. the records of a void pass never count and stay where
  they are. the frame has no `settle` record, so it is settled again, as a
  new pass with a new number. a pass is closed by exactly one of `settle`
  and `void` ; a second closing record is refused
- while a pass is pending, every command that would write refuses and names
  `recover`
- **torn bytes** are what follows the last whole record and is not a whole
  record : a write cut by a crash. a fragment was never a record, it has no
  address and no head ever named it. `recover` moves the fragment to
  `torn/<ntime>` beside the journal, and writing goes on after the last
  whole record. this is the only case in which the journal file gets
  shorter, and no record leaves it

**late proofs** : a slot keeps what it holds until its usage is proven or the
slot is ended. a proof arriving late is paid from its own slot, so no settled
frame is reopened and no division is redone. how long a saturated, unproven
slot holds its drops is proposed in question 18.

**clock** : a record's ntime is never below the record before it. when the
local clock is behind the last record by more than a small tolerance, writing
stops and says so ; `-accept-clock` continues deliberately. the ledger does
not reuse the n7fs floor behaviour, which keeps running on a stuck clock.

## 6. cold balances [ owner 2026-11-08 : tokens follow the same logic as data ]

a balance has a **depth**. warm drops sit in the key account. cold drops are
parked in a pool further away and reach the account again after a delay that
grows with depth [ `thaw` carries a `ready` frame ].

- **park** needs the account's consent : an explicit signed transaction, or a
  parking rule the account signed in its `share` record. without either,
  nothing sinks. a key account moves only by its own key or its own share
- **warmed by activity** : under a signed parking rule, what an account did
  not use for a ladder step sinks one level
- **spending returns** : drops paid to a provider arrive warm
- **swap** : a cold holder that needs drops now may take warm drops from a
  pool whose definition has a category for exactly that, and gives the pool
  the same amount of its cold balance. the pool's share and capacity bound it
  per cycle like any other spending. no such category, no swap
- **net unwinding** : opposing park \ thaw requests of one frame are netted
  first, only the difference passes through the delay
- **reparenting** : when funding is in shared interest, a wider pool has a
  category for it and fills the slot. nothing is switched afterwards ; the
  wider pool's definition is the agreement
- **fairness per frame** : section 4

sinking, thawing, swapping and reparenting are all transactions ; the sum
never changes. that is the one difference to data.

## 7. how each resource maps onto it

a proof is identified by `class : work id : interval`. the class reader that
checks it also decides whether two proofs overlap.

**storage [ n7fs ]** — ready. `holder-check` writes a root-signed receipt
with holder, root id, time, head version, coverage and a digest of the covered
entries. one receipt shows the bytes were there at check time ; it says
nothing about the time after it. n7fs "fresh for 3Y2" is a deadline for the
next check, not a proof of the frames in between.

- work id = holder + blob address ; interval = frames
- a frame of storage is proven for an entry only when a `full` receipt before
  it and a `full` receipt after it both cover the entry, unchanged. payment
  for a span is released when the closing receipt arrives ; the frames after
  the newest receipt stay unproven
- a byte-frame is paid once : overlapping receipts prove the same frames, not
  more of them
- `sampled` and `sizes-only` receipts close nothing
- a single holder's nonce scrub proves it held the bytes at that moment,
  because a blob's name is the checksum of its own ciphertext. comparing two
  holders' answers is needed only where home keeps no copy to compare with
- `quota` is the holder's offer, `reserve` is never offered ; the unit is the
  sealed byte on the holder
- the ledger only reads receipts. n7fs overwrites a receipt on the next check,
  so the reader keeps its own copy of every receipt it used, named by its
  BMW384, and the `usage` record carries that BMW384 as `proof-sum`. the
  copies are **evidence**, not state [ section 5 ] : `verify -proofs` needs
  them, a replay of balances does not. it never writes into an n7fs tree
- receipts are in the canon form when the reader is built : format 4 stage 3
  lands before ledger stage 2 [ owner ]. the reader checks a receipt's
  signature over its stored bytes with the same parser that reads the
  journal, and no json reader exists in the ledger at any stage

**work** — not ready. a 5 of 7 agreement shows the RESULT is right ; it does
not show how many cpu seconds it took. so `work` is not metered in seconds :
the slot states a price for the item before it starts, and the proof is the
accepted result. work id = task address. what is missing is who the seven are
[ section 10 ]. until then a `work` usage is countersigned by whoever signalled
the slot, which proves agreement between two parties and nothing more.

**transport** — not ready. osf-cache, the n7fs relay and the per-holder token
bucket count bytes, and two link ends can sign matching counters. matching
counters show that both ends agree, not that anything was delivered ; two
ends that collude can invent traffic. inside one owner's hosts that is
harmless. between strangers it needs a proof of delivery that does not exist
yet. an opaque relay being paid by a pool is the right shape, and it is still
vision.

**llm tokens** — not ready, and less far than the first pass said. the code
reads `completion_tokens` \ `total_tokens` from the reply
[ `models.handler.llm_response`, `models.handler.process_response` ] ;
`prompt_tokens` is not read anywhere, `coding.async.http_client` only
estimates it from the body length. the requester could count both sides
itself ; that counting does not exist. usage of outside providers
[ `plugin.usage.claude`, `plugin.usage.kimi` ] is bought with outside money :
class `ext`, reported, never drops.

**change accounting** — not a resource class. it contributes rule 12 and the
non-exclusive groups of section 3.

## 8. reuse, nothing new

| need | existing piece | limit found |
|---|---|---|
| record and proof addresses | BMW384 base32 [ `AMOS7::N7FS::Sum::bmw384_bytes`, `bmw_b32` ] | |
| account checksum, prefixes | AMOS7 7 char checksum [ `amos_of_bmw`, `bin/amos-chksum` ] | |
| signatures | the project's C25519 keys sign with `Crypt::Ed25519` [ `crypt.C25519.sign_data` \ `verify_sign` ] ; `AMOS7::N7FS::Sign::key_file_signer` signs any bytes with the same primitive | `command_signer` reads an n7fs binary header at fixed offsets and cannot sign these records without an adapter |
| account consent | `crypt.C25519.create_signature_request` signs `<ntime:subject-chksum:signer-chksum>` | |
| time, ages | `AMOS7::NTIME` [ `ntime_now`, `parse_y_age` ] ; frames and windows from `AMOS7::cell::time` [ `frame`, `window`, `path` ; exact, built ] | the float `epoch_int` \ `epoch_window` of `AMOS7::N7FS::Sum` are not used |
| record form | the canon form and its shared parser [ `N7FS-FORMAT-4.md` section 2, stage 1 ] | the parser must exist first : stage 1a waits for it |
| replay refusal | the n7fs pattern : counter + nonce, last counter kept by the receiver | |
| atomic head | `_replace_file` [ write, sync, rename, sync dir ] | one file only ; the journal append is the atomic step |
| storage proof | n7fs receipts and `n7fs-receive scrub -nonce` | receipts are overwritten : archived by the reader as evidence. they are in the canon form before stage 2 |
| hand-editable settings | the p7 config readers of `Placement::holders_parse` \ `Cycle::config_read` | |
| curves, hysteresis | `base.curve.*`, the "internal curves" rules of the n7fs open section | |
| loves_it weights | the 0 \ 4 \ 7 \ 11 \ 13 scale of `LOVES_IT_RESOURCE_ALLOCATION.md` | its score as coded in `lm-vision.handler.http_analyze` is true for nearly any input [ demystification, open item ] |
| a view | the iris ring ledger [ one counter per arc ] | a display, the journal stays the truth |
| pin of a remote witness | `crypt.C25519.store_remote_key` [ `ntime:pubkey` pins ] | |

## 9. contradictions between the sources, with a proposed resolution

1. **unit : statistic or balance.** NRT.NRD defines the token value as total
   resources / total accounts ; the 2026-11-08 note says tokens are conserved.
   -> the drop is the conserved quantity ; the statistic is the NRT index,
   reported, over weighted accounts.
2. **issuance : proof of work, earned work, or none.** NRT.NRD mints a token as
   a new account by proof of work ; task cube, osf-cache and the transport
   note pay for useful work ; the owner position says work put into a pool is
   translated into drops. -> not resolved here. one `issue` record kind, one
   supply counter ; what may trigger an issue is owner question 2 [ work in kind
   does not : answer 15 ]. the
   NRT.NRD proof of work derives its key from the last valid state of a
   global chain, which this design does not have ; kept as an account cost it
   needs another input, for example the domain's signed head.
3. **a token is an account, and an account has a balance.** both stand in
   NRT.NRD. -> one record : an account with a balance. a "token" is an account
   opened with 4200 drops.
4. **identity.** NRT.NRD accounts carry a signed username and dates ; the
   token architecture wants a template user whose proportion is the
   authorization. -> with the owner position both hold : keys where a balance
   is kept, and the pool's share as the authorization everywhere else.
5. **money or not.** NRT.NRD : a currency with free transfer, tradable
   outside. token architecture : "untakeable, not claimable", "not payment".
   osf-cache : "not money". -> answered by the owner as a matter of
   perspective : a transaction is itself a small pool, a transfer its
   smallest case. inside, drops are resource accounting ; a vendor outside
   never sees them. loves_it stays a weight, never a balance.
6. **who agrees on state.** NRT.NRD : blockchain state and mass consensus ;
   task cube : 5 of 7 ; n7fs as built : one root signer ; the time consensus
   note : computed, not held. -> domains with one witness now. several
   domains and witness sets are not designed yet [ section 10 ].
7. **pricing.** numeraire without clearing [ demystification ], AMM-style
   pool balancing [ task cube ], scarcity curves [ osf-cache ], "balances
   itself" [ NRT.NRD ]. -> one rate per class and version now ; rate curves
   per pool later, published as quotes.
8. **the 5x replication multiplier.** task cube layer 3 multiplies the value of
   a contribution ; tokens are conserved. -> the multiplier is about copies of
   the result, which are data. each proven unit is paid once.
9. **accumulation.** osf-cache : max-min fairness, no node accumulates
   disproportionately ; the foundation : "no individual accumulates
   disproportionate resources, continuous redistribution prevents
   stagnation". NRT.NRD : free transfer of whole balances. -> the irrigation
   rules answer it : pools take no more than their capacity, the excess flows
   on and is offered again in equal parts each cycle [ section 4 ], which is
   max-min in effect. unused balances become slow [ section 6 ], nothing is
   taken away. inside one slot the owner makes it a choice : `buy = complete`
   or `buy = as-filled`.
10. **opaque transport "solved".** the demystification [ objection 4 ] calls
    relay payment solved and cites the latency note ; that note calls itself
    pure vision. -> not solved [ section 7 ].
11. **which clock orders things.** task cube : logical clock. n7fs : ntime
    with a floor. time consensus : weighted network time, not built. -> order
    from `seq` and `from-count` ; ntime places a record in a frame.
12. **formats.** the rule is no json and no sha for internal data ; n7fs
    receipts and signed requests are canonical JSON as built. -> closed by
    the owner's two answers on `N7FS-FORMAT-4.md` : its canon form is the
    ledger journal form, and receipts move to it before ledger stage 2.
    ledger records are canon form records ; hand-editable settings stay p7
    config style ; the ledger parses json nowhere.
13. **which bytes count.** n7fs sizes a node by local content size ; a holder
    provides sealed bytes. -> the usage counts sealed bytes on the holder.
14. **"accounting" in the coding design.** it tracks changed statements, not
    resources, and its groups are non-exclusive. -> take rule 12 and the
    non-exclusive membership ; no resource class comes from it.
15. **loves_it bonus and conservation.** `LOVES_IT_RESOURCE_ALLOCATION.md`
    turns 1000 tokens into 4 746 000 drops at score 13 [ x 1.13 ], more than
    the 4 200 000 they are. -> the scale is a weight inside a fixed budget.
16. **loves_it scale, inside its own document.** the table gives 75 % for
    score 11, the token flow example uses 0.85 ; the test module adds 4 + 7 +
    2 where the table reaches 13 by passing all three modes. -> the ledger
    takes the five scores as given weights and does not compute them. which
    numbers are meant is the owner's.

## 10. threats

- **sybil** : nothing is divided by a head count ; an account without proven
  work receives nothing ; a share can only give what the account holds
- **pool draining** : a pool pays only through slots of its own categories,
  per frame only up to each category's part of its value, and its definition
  cannot be changed. a pair that invents usage under a category empties at
  most that category's frame budget, and only where the class proof lets
  invented usage pass. for `store` it does not. for `transport`, `work` and
  `ltok` it still does ; those classes stay off for strangers' pools
- **the conversion edge** : a zenka that turns a saturated slot into an
  outside payment is an outside bridge, in the outward direction, from the
  first pizza on. question 12 put the bridge last ; this edge exists earlier
  and is narrower [ per slot, outward only, no way to buy drops ]. what it
  opens : the zenka holds outside money and receives drops, so it is trusted
  with both ; an outside payment cannot be undone while the slot's payout
  waits for a proof ; each order states a price in both units and so
  publishes an exchange rate ; drops that buy outside goods are worth
  farming, which puts pressure on every weak class proof and on public
  pools. limits proposed : the zenka is paid from the slot only on proof of
  the order like any provider, the slot names the converting zenka before
  saturation, public-pool drops cannot fund outside slots, and there is no
  inward direction until question 12 is decided
- **equal split and the smallest fill** : with `split = equal` an account that
  reserves one drop gets the same part as one that reserved half. a slot can
  state a smallest fill ; where it does not, equal split is a gift the
  fillers agreed to by joining
- **capacity as a claim** : a pool that states a large capacity takes more
  water. capacity has to follow measured usage of earlier cycles plus the
  margin, not a number somebody wrote ; a new pool starts small
- **public pools** : the low barrier is also the cheapest thing to farm with
  many new accounts. the public part is small by design [ 1 % in the owner's
  example ], capped by capacity, and a newcomer's draw is bounded per account
  and cycle
- **reservations as a block** : reserving towards slots that never saturate
  ties up drops for a cycle. it costs the reserver only, and ends with the
  cycle
- **traced returns** : returning a surplus exactly per channel needs to know
  who gave ; the proportional default needs only amounts. the exact form is
  for slots whose fillers chose to be known to each other
- **slot spam** : anybody may signal a slot, and slots of a category divide
  one budget by weight. many false slots thin out real ones. open : a slot's
  weight has to come from something that costs [ its own fills, loves_it
  history ]. in stage 1 the weight is a given number and trusted
- **replay** : every record binds kind, ledger id, `seq` and `prev`. a proof
  is used once forever [ rule 8 ]
- **double spend** : inside a domain the single journal orders everything and
  rule 3 refuses what is not there
- **forged usage** : section 7, per class. only `store` has a proof of amount
- **witness key theft** : the thief can write `rate`, `issue` and settle
  records. what holds : pool definitions are content addressed and cannot be
  altered ; share budgets and slot rules are checked by everyone who replays ;
  a rate becomes active only in a later frame. what does not hold : `issue`
  is unbounded in stage 1, and an offline head anchor shows a rollback but
  stops nothing. a separate key for `rate` \ `issue` is owner question 25
- **clock** : section 5, fail closed
- **address grinding** : prefixes authorize nothing. a 7 character AMOS
  prefix is 32 bits, cheap to grind and expected to repeat among some tens
  of thousands of accounts ; an account is always looked up and checked by
  its whole address
- **a cut journal** : nothing shortens the record sequence [ rule 14 ], so a
  journal with fewer whole records than its head names is damage or fraud,
  never the trace of a recovery
- **privacy** : slots and pool definitions are public by nature, they are
  signals. fills are what reveal a person. a journal is not published whole.
  an account can show its own records together with the signed heads that
  contain them ; weights that need history [ section 13, question 3 ] are
  computed by the witness and checkable by the account they concern, not by
  everybody. the witness of a domain sees all of it ; an accounting parent
  is told amounts per class and frame and nothing else [ section 3 ]. a
  parent that is blind and a party that verifies are two different parties

**not designed, and not to be built from this document** :

- **several domains.** a transaction between two domains needs a settlement
  id both sides record, one posting in each domain against an account that
  stands for the other domain, a proof consumed for good on both sides, and a
  rule for when a credit is final. a signed head is not finality : a witness
  can sign two heads with one seq, and showing the fork afterwards returns
  nothing. stage 6 needs its own design first
- **5 of 7.** the threshold assumes seven participants under independent
  control. age and history do not stop one operator from holding five keys.
  it needs an admission rule and independent control domains [ the n7fs
  failure domain label is the existing notion ] before it is a proof of
  anything, for workers and for witnesses alike

## 11. stage 1 : a local-only ledger

scope : one host, one domain, one witness key, no zenka, no network. the
review found the first cut too large and unsafe for one task ; it is two
tasks now.

names follow the owner's rule [ 2026-11-16 ] : lowercase and nested,
`AMOS7::NRT` as a namespace root only, no `NRT.pm`. NRT names the whole, NRD
stays the unit inside `drops = ` lines. each name was checked with
`bin/harmony <full name>` as a hint, not a rule.

| module | holds | harmony | stage |
|---|---|---|---|
| `AMOS7::NRT::journal` | append, `seq` \ `prev`, head, replay, verify, recover | TRUE | 1a |
| `AMOS7::NRT::journal::canon` | the ledger kind tables [ label, keys, order, types of every kind ] handed to the shared canon parser. no parse or pack of its own | TRUE | 1a |
| `AMOS7::NRT::drops` | exact arithmetic, amount syntax, `drops : units`, carry, 13 digit bound | TRUE | 1a |
| `AMOS7::NRT::transaction` | the one record that changes balances, its authority check | TRUE | 1a |
| `AMOS7::NRT::user::account` | key accounts : id, checksum, balance by fold | TRUE | 1a |
| `AMOS7::NRT::user::account::transaction` | an account's own side : signing, `from-count` | TRUE | 1a |
| `AMOS7::NRT::market::network` | the network account, the supply counter | TRUE | 1a |
| `AMOS7::NRT::market::issue` | issue records ; in stage 1 only the test issue | TRUE | 1a |
| `AMOS7::NRT::frame` | the settle pass, pending and void. the frame index is `AMOS7::cell::time::frame`, called, not copied | TRUE | 1b |
| `AMOS7::NRT::frame::clock` | the fail-closed clock rule | TRUE | 1a |
| `AMOS7::NRT::market` | namespace only | TRUE | |
| `AMOS7::NRT::market::rate` | rate versions | TRUE | 1b |
| `AMOS7::NRT::market::pool` | pool definitions and addresses | TRUE | 1b |
| `AMOS7::NRT::market::pool::share` | a pool's proportions, frame budgets | TRUE | 1b |
| `AMOS7::NRT::market::pool::slot` | slots : requirement, open \ covered, payout, return | TRUE | 1b |
| `AMOS7::NRT::user::account::share` | an account's proportions and parking rule | TRUE | 1b |
| `AMOS7::NRT::usage` | usage records, their state | TRUE | 1b |
| `AMOS7::NRT::usage::proof` | proof identity, used once forever ; readers later, first `usage::proof::n7fs` [ TRUE ] | TRUE | 1b |

name notes :

- **`transaction`, not `move`** : `user::account::transaction` was agreed, so
  one word names the record at both levels ; `user::account::move` is FALSE.
  the transport class is `transport`, so "move" names nothing any more
- **kept out by a FALSE result, with the TRUE choice** : `pool` \
  `pool::account` -> `market::pool` ; `meter` -> `usage` ; `receipt` ->
  `usage::proof` ; `grant` -> `market::issue` ; `market::slot` ->
  `market::pool::slot` ; `user::share`, `market::share`, `market::proportion`
  -> `user::account::share` and `market::pool::share` ; `market::supply` ->
  `market::network` ; `journal::format` -> `journal::canon`
- **also TRUE, not chosen** : `issuance` [ flat, clearer than "issue", which
  can read as "problem" ], `evidence`, `proof`, `measure`, `gauge`,
  `network::account`, `market::pool::proportion`, `market::pool::requirement`,
  `journal::clock`, `journal::init`, `journal::witness`
- **not modules** : balance, settle, head, verify, close [ every nested name
  tried for them is FALSE ; they live in `user::account`, `frame`, `journal`,
  `usage` ]
- **no FALSE name is kept** in the module tree
- tool `bin/nrt` [ `bin/nrt` TRUE, the bare word `nrt` FALSE, kept : no TRUE
  alternative names the whole ; `nrt-journal` bare TRUE, `bin/p7-nrt` TRUE ]
- test `bin/test-scripts/test-nrt-journal.pl` [ TRUE ]
- state `~/.n/nrt/<ledger id>/`, 0700, files 0600, outside the repo and apart
  from any n7fs directory [ `.n/nrt` TRUE ] : `journal` and `head` are the
  state. beside them `torn/` [ fragments moved aside by `recover` ] and
  later `proof/` [ archived receipts : evidence ]

**what stage 1a waits for** : the shared canon parser, which is stage 1 of
`N7FS-FORMAT-4.md` and is built there, once, for both users. the ledger
builds no parser. where it lives is format 4 question 2 ; the recommendation
of both documents is a home that belongs to neither user :

| module | holds | built by |
|---|---|---|
| `AMOS7::cell::canon` [ TRUE ] | parse and pack a head, signed bytes, address, strictness | format 4 stage 1 |
| `AMOS7::cell::canon::list` [ TRUE ] | the body : rows, both body shapes | format 4 stage 1 |
| `AMOS7::NRT::journal::canon` [ TRUE ] | the ledger kind tables | ledger stage 1a |
| `AMOS7::N7FS::Canon` [ TRUE ] | the n7fs kind tables | format 4 stage 2 |

why there : the owner accepted `AMOS7::cell` as a namespace root, the canon
form is the journal part of every cell, the ledger must not load n7fs code
and n7fs must not load the ledger. if the owner places the parser elsewhere,
only the name in `use` lines changes.

**stage 1a : the conserved core** [ one kimi task, after format 4 stage 1 is
accepted ]

    nrt init <dir> -witness <keyfile> [ -frame-level <n> ]
    nrt account add <name> -key <keyfile>
    nrt issue <account> <drops> -witness <keyfile> -test
    nrt transaction <from> <to> <drops> [ <to> <drops> .. ] -key <keyfile>
    nrt balance [ <account> ]
    nrt journal [ -account <a> ]
    nrt verify
    nrt recover

- `-key` \ `-witness` name a key file read through
  `AMOS7::N7FS::Sign::key_file_signer`. no key is ever taken from argv, and no
  record is written without the signature its kind requires
- `account add` signs with the account's own key : a public key alone opens
  nothing
- **the stage 1 issue is a test issue** : unbounded except by the 13 digit
  supply cap, trusted, and marked `basis = test` in its record. `-test` is
  required so nobody mistakes it for the real rule. `verify` reports supply
  on its own line

acceptance checks, 1a :

1. after `init` and after every command `nrt verify` exits 0 and reports a
   zero sum and the supply ; supply equals the sum of all issues
2. refused, exit != 0, journal and head byte-identical before and after : a
   transaction over the balance ; drops written as `0`, `-1`, `+1`, `01`,
   `1.0`, `1e3`, with spaces, or with 14 digits ; the giver also as a receiver ; an
   unknown account ; a signature by another key
3. an issue that would take supply above 9 999 999 999 999 is refused and the
   message names the bound ; so is a transaction that would take a balance
   above it ; sums and products of 13 digit numbers come out exact
4. every kind is checked for its signature : each record kind signed by a
   wrong key makes `verify` fail and name the `seq`
5. format : a repeated key, an unknown key, a missing key, swapped key order,
   padding with one space too few or one too many, a trailing space, a CR, a
   missing final LF, a missing or changed label line, a `kind = ` line, each
   in a hand-edited copy, make `verify` fail and name the `seq`. a record
   set by hand to exactly one space on each side of `=` is refused where its
   kind pads wider, although it means the same
6. tamper : a changed digit, a removed record, two swapped records, a copied
   record appended again, a record taken from another ledger, each fail
7. a signature made for one kind is refused when pasted under another label.
   a record whose stored `pub` is not the key its kind's signer rule names
   is refused, also when the signature under that `pub` verifies
8. a head with a lower `seq` than the journal, and a head for another
   ledger, are refused ; a missing head is rebuilt only with the witness key
9. a clock set behind the last record refuses to write ; `-accept-clock`
   writes, and the record's ntime is not below the one before
10. two processes running `transaction` at once leave a journal that verifies
    [ one lock, one append ]
11. deleting everything but `journal` and `head` loses nothing : `verify` and
    `balance` give the same answers
12. no JSON and no SHA in the implementation : a small scanner in the test
    looks at the tokens of the new module and cli files [ module loads,
    function names ] and lists the files it checks by name ; it does not grep
    itself
13. the test runs in a scratch directory, leaves nothing behind, and runs
    under the floor perl ; `bin/format-code -c` is clean

added with the canon form, still 1a [ numbered on, so that the numbers above
keep their meaning ] :

27. a transaction with one giver and three receivers is one record ; its
    balances are those of three transfers. refused, journal unchanged : rows
    in another order, an account twice, an account on both sides, row sums
    that differ from `drops`, a changed body byte, a wrong `rows`, and a
    key-signed transaction with two `-` rows
28. append only : after a crash that leaves torn bytes, `recover` moves the
    fragment to `torn/` ; every whole record of before is still there, byte
    for byte, and no command of the cli ever lowers the count of whole
    records. a journal with fewer whole records than its head names is
    refused
29. one parser : every record the cli writes is read back by the shared
    canon parser with the ledger kind tables and packs to the same bytes ;
    the scanner of check 12 also shows that the ledger files hold no parse
    or pack of the form of their own
30. the address of a record is stable : computed twice, on both perls, and
    equal to the `prev` of the record after it and to `last` of the head

**stage 1b : shares, slots, settle** [ a second task, after 1a is accepted ]

    nrt rate set <class> <drops> : <units> -witness <keyfile> -from-frame <n>
    nrt pool add <name> -category <word>:<class>:<weight>:<capacity> .. [ -public ]
                 -key <keyfile>
    nrt share set <account> -part <name>=<n>:<d> .. -category <word>=<weight> ..
                 [ -overflow core|return ] -key <keyfile>
    nrt slot add <pool> <category> <units> [ -item <id> .. ] [ -provider <account> ]
                 [ -buy complete|as-filled ] [ -split equal|fill ]
                 [ -weight 0|4|7|11|13 ] -key <keyfile>
    nrt reserve <account> <slot> <drops> -key <keyfile>
    nrt usage <slot> <units> -proof <work id> -interval <from>-<to> -key <provider keyfile>
                 [ -countersign <keyfile> ]
    nrt close <slot|usage> -key <keyfile> | -witness <keyfile>
    nrt settle -witness <keyfile> [ -frame <n> ]

- proofs in 1b are **test proofs** : the work id is an opaque word, unique
  forever in the ledger per class, checked by no reader, and marked so
- weights are given numbers ; loves_it is not computed
- capacity is a given number in 1b ; measuring it from earlier cycles comes
  with the curves
- no outside vendor, no conversion, no work in kind beyond the `donate`
  transaction itself

acceptance checks, 1b :

14. a `buy = complete` slot moves and pays nothing while less than its
    requirement is reserved : balances are unchanged, the usage waits and
    `verify` lists it ; it is paid in the first settle after saturation, once.
    a `buy = as-filled` slot with three items buys each as its price is
    reserved, in any order. reserved drops cannot be spent or reserved again
15. a share never reserves more than its part : with a part of `1:10` and two
    categories of weight 1 and 3, a balance of 4000 reserves at most 100 and
    300 in one cycle, whatever the slots ask ; with parts `core=1:10` and
    `public=1:100` the two budgets are kept apart
16. dissemination : three pools of weight 4, 7, 13 with capacities, on a
    budget larger than the smallest capacity : no pool gets more than its
    capacity, the excess is offered again in equal parts, what nobody can
    take stays with the giver, and reserved + left = budget exactly, in whole
    numbers ; the order in which pools and slots were written changes nothing
17. `settle` twice for one frame : the second is refused. `settle` killed
    between any two records : every writing command refuses and names
    `recover` ; `recover` appends one `void` record and removes nothing ;
    `settle` again gives the balances, carries and used proofs of an
    uninterrupted run, exactly. the records of the void pass are still in
    the journal and change no fold ; a second `void` or a `settle` for the
    void pass is refused ; no `from-count` is used twice
18. a proof used in frame N is refused in frame N+1, under another slot, for
    another pool, and with another payer
19. carry : rate `1 : 1000`, one stream with usages of 1500 then 300 units
    pays 1 then 0 drops and leaves 800 ; a second stream with 700 leaves 700
    and pays 0 ; over 1000 random usages in one stream, drops paid x 1000 +
    carry = units, exactly
20. a rate change : a slot priced under version 1 pays under version 1 after
    version 2 is active ; the ended stream's remainder is closed by a record
    that states it ; a rate with a zero or a `-from-frame` not in the future
    is refused
21. overfill : reservations of 60, 30 and 30 on a requirement of 100 take
    50, 25 and 25 ; nothing above the requirement ever enters the slot. an
    ended slot returns what it holds the same way, nothing left in it.
    `split = equal` and `split = fill` report the parts they give
22. a late proof is paid from its own slot and no earlier `settle` record
    changes ; a proof for a closed slot is refused and listed
23. frame boundaries : an ntime one unit before and one unit after a computed
    boundary land in different frames, for levels 0 to 7, and the index is
    the one `AMOS7::cell::time::frame` gives ; the ledger files hold no
    frame arithmetic of their own. a frame index past the 385280 epoch wrap
    keeps counting
24. a pool's definition cannot be altered : a `pool` record with one changed
    weight has another address and holds nothing
25. work in kind : the provider's `earn` and the `donate` that follows it
    leave the provider's balance unchanged, add the amount to the task, and
    supply is unchanged
26. zero sum, supply and "nothing below zero" hold after every record of
    every check above

rules for both tasks : BMW \ AMOS checksums only, no sha ; no json in any new
code or state ; records in the canon form, hand-editable settings in p7
config style ; lowercase comments, `[ word ]` annotations ; perl 5.32 floor ;
touch no file outside the modules, the cli and the test script named above,
and not the shared parser ; never write into an n7fs tree.

not in stage 1 : real proofs, real issuance, cold depth, curves, measured
capacity, computed loves_it, outside vendors, any zenka command, more than one
domain.

following stages : 2 the `store` proof reader over n7fs receipts in the
canon form [ after format 4 stage 3 ; read-only, evidence archive,
`verify -proofs`, dry run first ] ; 3 depth and thaw ; 4 rate curves and
quotes ;
5 `ltok` once both ends count ; 6 several domains, after its own design ;
7 witness and worker sets, after a membership design ; 8 real issuance ;
9 the bridge.

## 12. owner questions

status marks : **answered** = by the owner ; **proposed** = this document
offers an answer from the owner's rules or the irrigation principle, the
owner has not confirmed it ; **narrowed** ; **open**.

1. **answered** [ naming rule ] : lowercase, nested, `AMOS7::NRT` as a
   namespace root. open only : the picks for the new pieces in section 11.
2. **narrowed** : issuance. work in kind creates no drops [ answer 15 ], so
   translation of work is not the issue. open : what does create drops, and
   does the NRT.NRD proof of work remain, as an account cost or as a mint ?
3. **open** : the weight behind the NRT index. direction given by the owner
   [ a long-existing account with good values ] ; conditions in section 13.
   answer 15 adds a second good value : completed donations.
4. **open** : frame level, Y3 or Y4 ; and is the dissemination cycle one
   frame ?
5. **open** : do cold balances only slow down, or also shrink ? [ the
   foundation's "continuous redistribution prevents stagnation" speaks of
   flow, not of taking ]
6. **open** : depth numbers.
7. **proposed** : idle offers. a pool's capacity is "expected usage plus a
   comfortable burst margin", so readiness is what the margin pays for,
   prepaid, without any issue.
8. **open** : account keys, and whether the passphrase + PIN derivation is the
   `keys` zenka seed mode.
9. **open, probable typo** : the doubled date in the account checksum input.
10. **narrowed** : sampled receipts close no span. open only : must both ends
    of a span be `full` receipts ?
11. **open** : outside llm providers as report-only `ext`.
12. **narrowed** : the outside bridge. the owner's pizza answer creates an
    outward edge per slot [ a zenka converts and orders, the vendor never
    sees NRT ]. open : the inward direction [ buying drops with outside
    money ], and whether the outward edge is allowed before the limits of
    section 10 exist.
13. **answered** [ on `N7FS-FORMAT-4.md`, questions 1 and 17 ] : the format 4
    canon form is the ledger journal form, and receipts move to it before
    stage 2. the ledger never reads json.
14. **narrowed** : slots and pool definitions are public signals. open only :
    may a provider see who filled a slot [ proposed : no, unless the slot
    uses traced returns ] ?
15. **answered** : work in kind is paid normally, the value directed to the
    task and recorded as a completed donation. conserved, no issue.
16. **answered** : a share is a local reservation, may be split [ e.g. 10 %
    core + 1 % public ] ; pools have a capacity of expected usage plus a
    burst margin and overflow toward the network ; the rest is disseminated
    again, or expires with the cycle.
17. **proposed** : waiting and storage that is already kept. the saturation
    threshold says the network meets its core needs first ; keeping existing
    copies is a core need, so storage slots are served from the core part
    before anything else. if a frame still stays uncovered, the holder keeps
    the bytes unpaid for one receipt age [ 3Y2 ] and may drop them after.
    n7fs placement never relies on a paid holder alone.
18. **proposed** : a reservation lives one cycle [ the owner : "unless it
    expires ; a new cycle with a new dissemination usually started by then" ].
    a saturated slot whose proof is missing holds its drops for one check
    interval of its class [ storage : 3Y2 ], then returns them.
19. **answered** : equal share by default, proportional allowed ; overfill
    allowed, the surplus returns in proportion or exactly per channel ;
    saturation is the agreement.
20. **proposed** : nobody closes an ownerless pool. its capacity follows its
    expected usage ; a pool nobody uses has a capacity near zero, takes no
    new water, and what it holds overflows back in the next cycles.
21. **half proposed** : loves_it as weights inside a fixed budget follows from
    the picture [ water is shared out, not multiplied ]. still open : 75 % or
    0.85 for score 11, and a score that is selective.
22. **answered** : a perspective, not a rule. a transaction is itself a small
    pool ; a target can be a pool, an account, a network task or a work item.
23. **answered** : per slot. `buy = complete` for all-or-nothing work,
    `buy = as-filled` for order-free lists. between pools : capacity and
    overflow.
24. **open** : is 9 999 999 999 999 drops per domain the intended meaning of
    "13 digit numbers", including for the network account ? the irrigation
    principle says nothing about how much water there is.
25. **open** : a second key for `rate` and `issue`. not touched by the
    irrigation principle.

new, from these answers :

26. **the converting zenka** : who may be one, when does it receive the
    slot's drops [ proposed : on proof of the order, never at saturation ],
    and what counts as that proof for an outside purchase ?
27. **a smallest fill** : with equal split by default, may a slot state a
    smallest fill, or is equal sharing after any fill intended ?
28. **capacity** : who determines "expected regular usage" and the burst
    margin — measured from earlier cycles [ proposed ], or stated by whoever
    defines the pool ?
29. **the network core** : which pools are "core" [ one core pool per domain,
    or every pool that serves a topological need such as redundancy, routing,
    time ], and who says so ?
30. **public pools and outside slots** : may drops from a public pool fund a
    slot that ends in an outside purchase [ proposed : no ] ?

new, from the second review and the canon form :

31. **the parser's home** : this is `N7FS-FORMAT-4.md` question 2. both
    documents recommend `AMOS7::cell::canon`, built by format 4 stage 1.
32. **`void`** : is an appended `void` record with pending passes the wanted
    reading of "the journal only grows" [ proposed ], and is `void` the
    word ? [ it is written into every journal that had an interrupted pass ]
33. **evidence** : how long are archived proof bytes kept, and is a ledger
    whose `verify -proofs` can no longer check an old proof still whole
    [ proposed : yes, it says so per proof ] ?
34. **several givers by key** : one key signs for one giver, several givers
    go through a slot [ proposed ]. or is a record with several signatures
    wanted, which the canon form does not carry ?

## 13. recommendations [ second pass, revised with the review ]

proposals only. stage 1a needs none of them.

### 1. names — set

the rule is the owner's. the tree is section 11. a later swap of a name is
mechanical, but the kind and reason words [ `usage`, `transaction`, `issue`,
`share`, `slot` ] are written into every journal, so they should be final
before the first ledger that is meant to last.

### 2. issuance

- **recommend** : keep exactly one way for drops to appear, the `issue`
  record against the network account. the owner's answer 15 rules out work
  in kind as its trigger ; what remains is question 2. keep the NRT.NRD proof
  of work, if at all, as the cost of opening an account
- **reasoning** : NRT.NRD's proof of work creates "an account of its own" ;
  the owner position describes drops as translated work. both fit one record
  kind and one supply counter
- **trade-off** : proof of work as written derives its signing key from the
  last state of a global chain. this design has no global chain, so the
  construction cannot be taken over as it is ; it needs a per-domain input
  [ the signed head ] and that is a new design, not reuse
- **blocks \ unlocks** : blocks stage 8 only. stage 1 has the test issue

### 3. the weight behind the NRT index

owner input : the natural incentive is a long-existing account with good
values on the network side. it is already written in several places :

- `N7FS-SEALED-REPLICAS.md` [ open, derived placement, ~ line 527 ] : "a new
  key's weight grows with proven, checked holding time [ history is not
  cheap, keys are ]"
- `WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md` : historical precision is
  the weight ; "glitchless honesty x time *is* the value being accounted"
- `topic-network-as-computer` [ ~ line 383 ] : "earned history, not grindable"
- `topic-checksum-parenting-namespace-trees` [ ~ line 436 ] : "earned, not
  claimed, so not grindable"
- `vision-2026-10-05-generic-trust-chain` [ ~ line 468 ] : build standing then
  strike, whitewashing ; standing decays, weighted to recent behaviour
- `ZENKA-IDENTITY-COMPONENT.md` : a rotated key does not inherit standing
- `zenka-key-identity-infrastructure.md` : signed task completions become a
  verifiable capability reputation
- `TASK-CUBE-CONSENSUS-ARCHITECTURE.md` : routing prefers better statistics

- **recommend** : the same direction, with the conditions the review showed
  are needed. weight = age x good values, where
  - only usage paid by pools the account did not fill counts [ work for
    oneself builds nothing ]
  - usage counts by the drops it earned, not by the number of records
    [ a thousand tiny usages weigh what one of their sum weighs ]
  - the weight of several accounts together is never more than that of one
    account with their combined history [ so splitting gains nothing ]
  - offered but unused capacity does not count
- **reasoning** : the sources agree on time and proven behaviour ; the review
  is right that both can be produced by an account trading with itself
  unless the counterpart is independent and the measure is value
- **trade-offs** : incumbents weigh more ; standing has to decay to stay
  earned. "independent payer" is itself only as strong as the pools are
  diverse. the weight is computed by the witness from the journal and can be
  checked by the account it concerns ; it is not publicly replayable, because
  the journal is not public
- **blocks \ unlocks** : needed before any issue is bounded by the index
  [ stage 8 ]. not adopted until the four conditions are specified

### 4. frame length

- **recommend** : Y3, the level a field of the `init` record
- **reasoning** : long enough for proofs to arrive, short enough to feel a
  thaw as a delay. storage proofs arrive far more slowly than either level
- **trade-off** : Y4 is closer in feel and multiplies the journal by 13
- **blocks \ unlocks** : fixes the depth ladder. stage 1 takes the level as a
  parameter. late proofs no longer depend on it [ section 5 ]

### 5. do cold balances shrink

- **recommend** : delay only ; shrinking, if ever, as a rule an account signs
- **reasoning** : conservation, "untakeable", and no change of a default
  without consent
- **trade-off** : parked drops stay a claim for ever
- **blocks \ unlocks** : "delay only" keeps stage 3 a pure transaction
  mechanism

### 6. depth numbers

- **recommend** : sink after 13 unused frames, 13 x delay per level, as a
  named curve, numbers from a local ledger
- **trade-off** : level 3 from a Y3 frame is about a year
- **blocks \ unlocks** : needs question 4 ; blocks only stage 3

### 7. standby for idle offers — proposed answer

- **recommend** : no payment by issue. a pool's capacity already contains a
  burst margin by the owner's definition ; that margin is the standby, held
  prepaid in the pool and paid to whoever keeps capacity ready under a slot
- **reasoning** : one way for drops to appear, and readiness is paid by those
  whose field needs it
- **trade-off** : readiness is paid only where a pool's usage justifies a
  margin
- **blocks \ unlocks** : needs a proof of readiness per class ; storage has
  one [ `free` plus scrub ], the others do not

### 8. account keys

- **recommend** : any existing C25519 key ; passphrase + PIN as a later way to
  produce one
- **trade-off** : reusing a zenka key links ledger and routing identity
- **blocks \ unlocks** : nothing before the bridge

### 9. the account checksum input

- **status** : a probable typo in NRT.NRD, not confirmed by the owner
- **recommend the fixed input**, each as bytes joined by `:` :

      <username> : <username creation ntime> : <account creation ntime>
          : <public key base32> : <signature of the key over the four values>

- **trade-off** : if the doubled date was meant, checksums differ ; so the
  input carries a version tag and stage 1 computes under `v0`
- **blocks \ unlocks** : only the final account id form

### 10. sampled receipts

- **recommend** : a span of storage is paid when a `full` receipt stands at
  both of its ends ; a sampled receipt closes nothing
- **reasoning** : review finding 9. a receipt proves a moment. the first pass
  would have paid 39 frames after one check, and the whole span as soon as
  any later full receipt arrived ; both paid for bytes nobody had seen
- **trade-off** : a holder is paid one check interval late, and full scrubs
  have to happen often enough to be worth it
- **blocks \ unlocks** : defines the stage 2 reader

### 11. outside llm providers

- **recommend** : report-only `ext`
- **reasoning** : nobody on the network provided it ; pricing it in drops is
  the bridge by another door
- **blocks \ unlocks** : nothing

### 12. the outside currency bridge

- **recommend** : treat the two directions apart. outward, per slot, through
  a converting zenka : possible early, with the limits of section 10. inward
  [ drops for outside money ] : last, after several domains are designed
- **reasoning** : the owner's pizza answer needs only the outward edge. it is
  bounded by one slot's requirement and by saturation. the inward edge is the
  one that lets outside money buy standing, and it makes questions 3 and 26
  preconditions
- **trade-off** : even an outward edge publishes a rate and makes drops worth
  farming ; it should not open before `store` is the only class paid between
  strangers, or before the other classes have real proofs
- **blocks \ unlocks** : the outward edge needs question 26 answered

### 13. n7fs records in canonical JSON — answered

- **decided by the owner** on `N7FS-FORMAT-4.md` : its canon form is the
  ledger journal form [ question 1 there ], and receipts move to it before
  the ledger's stage 2 [ question 17 there ]
- **what follows here** : the first text kept one place that parses a json
  receipt. that place is gone. stage 2 reads canon form receipts with the
  shared parser and archives their bytes as evidence
- **trade-off** : stage 1a waits for format 4 stage 1, and stage 2 for
  format 4 stage 3. neither is a live step ; both are new files and tests
- **blocks \ unlocks** : orders the stages of the two documents. nothing in
  the conserved core changes its meaning

### 14. what a provider sees

- **recommend** : slots, pool definitions and rate quotes are public ; who
  filled a slot is not shown to the provider
- **reasoning** : review finding 24. a provider needs the price and the
  requirement to plan, not the payer. a slot is a signal and has to be seen
- **trade-off** : in a small pool the fillers are few and guessable
- **blocks \ unlocks** : must be settled before several domains

## 14. review response [ K3.1, 25 findings ]

verdict per finding : **accept** = the finding stands and the design is
changed as it asks ; **modify** = the problem stands, the remedy is another
one ; **reject** = not followed. nothing was rejected whole ; two proposed
remedies were [ in 2 and 13 ].

| # | finding | verdict | what changed, and why |
|---|---|---|---|
| 1 | amounts may be negative or zero | accept | amounts are 1 to 13 digits, no sign, no leading zero, `from` differs from `to`, rates above zero [ section 2, rule 4, checks 2 and 20 ] |
| 2 | any pool can be named as payer | modify | the hole is real. the remedy is the owner's, not a draw permit per usage : shares, slots, prepaid fills [ section 4 ]. a per-usage authorization would put a signature back on every use ; the frame cap survives as the share budget |
| 3 | double spend and replay between domains | accept | stage 6 is withdrawn as buildable ; what it needs is listed in section 10. proofs are used once for ever |
| 4 | settle is not atomic over four files | accept | the journal is the only state ; used proofs and carry are derived ; one append per pass, `recover` for a cut pass [ section 5, checks 11 and 17 ] |
| 5 | zero sum does not bound issuance | accept | supply is its own invariant on the network account ; "open grants" is gone ; the stage 1 issue is named a trusted test issue [ rule 11, check 1 ]. the claim that an index ceiling makes drops resource-backed is dropped |
| 6 | 13 digits against an unbounded root, native arithmetic | accept | the network account has the same bound, which caps supply ; exact arithmetic everywhere [ section 2, check 3 ] |
| 7 | rate and carry cannot express the rules | modify | the spread and the second rate are removed instead of specified : a slot pays what it fixed [ rule 10 ]. rates are versions, a slot keeps its version, carry is per stream and closed with it [ checks 19, 20 ]. rates per pool wait for curves |
| 8 | evidence once per frame is replayable | accept | proof identity is class, work id and interval, unique for ever, for every payer ; stage 1 proofs are named test proofs [ rule 8, check 18 ] |
| 9 | n7fs freshness is not continuous storage | accept | a span is paid between two full receipts that both cover the entry ; a byte-frame once ; single scrub against two-holder compare reconciled [ section 7 ] |
| 10 | proofs show a result, not an amount | accept | `work` is priced per item in its slot, not in seconds ; `transport` and `ltok` are marked not ready ; the llm claim is corrected, `prompt_tokens` is not read by the code [ sections 2, 7 ] |
| 11 | 5 of 7 has no membership model | accept | stated as not designed, for workers and witnesses [ section 10 ] |
| 12 | witness theft is not bounded | modify | pool rules are content addressed and share budgets are checked on replay, so those cannot be rewritten ; rates act only from a later frame. an independently held key for `rate` \ `issue` is not adopted without the owner [ question 25 ]. stage 1 says plainly that its witness is trusted |
| 13 | credit lines and cold moves lack authority | modify | there are no credit lines and no floors : prepaid, wait otherwise. parking needs a signature or a signed rule ; reparenting is a pool category. the proposed debt and correction rule is not taken, because nothing is paid before its proof |
| 14 | late claims against frame fairness | accept | division happens when slots are covered, before the work ; a late proof is paid from its own slot ; frame boundaries in exact arithmetic [ sections 2, 5, checks 22, 23 ] |
| 15 | the cli cannot make its own records | accept | every command names the key it signs with ; `init` record with the frame level ; `close` and `recover` exist [ section 11 ] |
| 16 | canonical bytes underspecified | accept | section 5, canonical form ; checks 5 to 7 |
| 17 | weight and idle rules can be farmed | modify | the owner's direction is kept, four conditions added, idle capacity removed from weight and index ; not adopted until they are specified [ section 13, 3 and 7 ] |
| 18 | four resolutions change the sources | accept | 4 now follows the source through the owner position ; 5 is returned to the owner [ question 22 ] ; 9 no longer claims max-min [ question 23 ] ; 14 takes the non-exclusive groups, pools are not a strict tree ; "[signed]" is read as the numeric sign |
| 19 | proof of work needs the removed chain | accept | "keeps the whole construction" is withdrawn ; a per-domain input is needed [ contradiction 2, section 13, 2 ] |
| 20 | reuse needs an adapter and an archive | accept | `key_file_signer` only ; receipts are archived by the reader ; JSON at that one boundary [ sections 7, 8 ] |
| 21 | vocabulary and schema inconsistent | accept | one vocabulary in all sections ; `init`, `close`, `settle` kinds, `park`, `ready`, class `ext` ; the transport class is `transport` |
| 22 | acceptance checks miss the hard cases | accept | 26 checks in two stages |
| 23 | the clock floor can keep receipts fresh | accept | the ledger fails closed on a clock behind its last record and does not reuse `n7fs_now` [ section 5, check 9 ] |
| 24 | privacy against public replay ; rates tied to payer | modify | weights are computed by the witness and checkable by the account concerned ; quotes and slots are public, fills are not [ section 10, section 13, 14 ]. a full selective-disclosure proof system is not designed here |
| 25 | the grep check defeats itself | accept | a token scanner over named files [ check 12 ] |

count : 19 accepted, 6 modified [ 2, 7, 12, 13, 17, 24 ], 0 rejected.

what the review asked for and stage 1 still does not have, on purpose : real
proofs, a bounded issue, more than one key role. each is named as trusted or
test in the records themselves, so a stage 1 ledger cannot be taken for more
than it is.


**after the owner's answers to 15, 16, 19, 22, 23** [ same day ] :

- finding 2 is closed further : a share is a local reservation, so drops do
  not sit in a pool waiting to be drawn ; they enter a slot only at
  saturation, and a pool takes no more than its capacity
- finding 18, source 5 [ transferable balances ] and source 9 [ max-min ] are
  no longer open : the owner answered both [ contradictions 5 and 9 ]
- finding 13 : returns after a slot ends are defined [ in proportion, or
  exactly per channel ] ; still no debt anywhere
- finding 14 : division is now capacity and overflow between pools, and a
  per-slot choice inside one ; both happen before work starts
- finding 17 : completed donations are a second, harder to farm good value,
  since the giver ends with nothing from them
- new exposure the review did not see, because the rule is new : the
  converting zenka is an outward bridge [ section 10, questions 12, 26, 30 ]


**after the K3.1 review of `SUBSTRATE-SYNTHESIS.md` and the owner's answers
on `N7FS-FORMAT-4.md`** [ same day ]. the verdicts stand in the synthesis,
section 10 ; these are the findings that changed this document :

| synthesis finding | what changed here |
|---|---|
| 2 : the AMOS 7 checksum carries 32 bits, not 35 | section 3 and the threats : 32 bits, one half chance of a shared prefix near 77 000 entries |
| 15 : an amounts-only parent cannot be the witness | witness, accounting parent and n7fs home are three roles [ words, section 3, threats ] |
| 16 : the owner's form decision supersedes the canonical form here | section 5 defines no bytes any more ; stored label line, aligned padding, `pub` before `sig`, optional body. check 5 is turned around, checks 7 and 27 to 30 added |
| 19 : `recover` shortened the journal | `recover` appends a `void` record ; committed, pending, void and torn are defined ; rule 14 ; checks 17 and 28 |
| 20 : no `pub`, and a flat record for a transaction with several parties | `pub` in every record, checked against the signer rule ; a transaction is an operations body of `-` and `+` rows ; one key signs for one giver |
| 21 : "the journal is the only state" against archived proofs | modified : archived proof bytes are evidence bound by `proof-sum`, not a cache ; `verify` and `verify -proofs` are two named depths |
| 5, 22 : one exact grid | the ledger calls `AMOS7::cell::time::frame` ; check 23 covers levels 0 to 7 and the wrap |

and by the owner : contradiction 12, question 13 and recommendation 13 are
closed ; stage 1a waits for format 4 stage 1, stage 2 for format 4 stage 3.

#,,,,,,.,,...,.,,,.,.,..,,,,.,,,.,.,.,...,.,.,..,,...,..,,...,,..,,,.,,.,,,.,,
#QSNFLBMJ2TOYYVXNYCEI4YCCBK6D4TKRDFTSLDNA6QLTVI6TBFR7YTPA6GOPOGXHXRSR6S2GT7AG4
#\\\|Y4RNMUTTQ5CQZIMDWN4C2F2UUKIHEFBW2ZPQMYTYBFTI4WM5WIS \ / AMOS7 \ YOURUM ::
#\[7]2VK7OKYFCH2OE7EFGTHLC35PEJ7K6FNCJV3X7A6CKXGWAALZVAAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
