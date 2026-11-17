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

added 2026-11-17 : the owner's idea set of 2026-11-16 as sections 15 to 22
[ remainders, nested units, clean units and trunks, shadow accounts, buffer
pools, fairness curves, the design test ; section 22 is the map and the
conflicts ], questions 35 to 47. stage 1a is built [ b41ef81db ] and
unchanged ; the status line above predates it.

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
  it [ always worth less than one drop ]. the same pattern one step up, for
  drops divided among parties, is section 15
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
per channel where the reservations can be told apart. a division that does
not come out even is never settled by a tie-break : the leftover stays in
the slot and flows to its pool at the close [ section 15 ].

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

17 to 29 : what the owner idea set of 2026-11-16 met in this document
itself, with a proposed resolution each, stand in section 22.

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

the owner idea set of 2026-11-16 adds to this list without renumbering it
[ section 22 ] : the remainder rule and the design test join 1b, with the
checks 31 to 35 of section 21 ; buffer pools, fairness curves and shadow
accounts join 4 ; layers, gates, clean units and trunks join 6.

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

new, from the owner idea set of 2026-11-16 [ sections 15 to 22 ] :

every question below carries a recommendation ; a plain "yes" takes it.

35. **the root pool** : where does the leftover chain end, and must every
    pool name a parent for it ?
    recommend : the first core pool of a domain that names no parent is the
    root pool, and a pool without an accounting parent hands it its
    leftover only [ no aggregate, no accounting edge ] -- because the
    network account may change only by an `issue` [ rule 11 ], and this
    leaves synthesis question 4 and question 29 open instead of forcing
    them.
36. **the unit carry at a stream's end** : taken over by the successor
    stream, or closed and stated as now ?
    recommend : taken over by the successor stream of the next rate
    version, stated in the `close` record as before -- because it is the
    owner's one pattern, costs no drop, and check 20 keeps its wording.
37. **nested units** : wanted as a direction, and with which numbers ?
    recommend : yes as the direction for stage 6, with a fixed 4200 per
    layer, one Y level coarser per layer up, and supply lent downward by
    lock and issue -- because 4200 is already the ntime second, a parent
    at its 13 digits then fills exactly 4200 children, and a child's fault
    stays bounded by its own lock. nothing is built before stage 6.
38. **what may cross a boundary** : whole units or primes, who sets the
    unit, is the constant unit wanted ?
    recommend : whole transmission units with a cap per frame, both stated
    in the gate's definition by whoever writes the gate ; the constant
    unit per frame as an option a trunk may choose, not the default --
    because primes leak almost as much as any amount and cannot be netted,
    and the constant unit costs a buffer not every edge can hold.
    **decided [ owner 2026-11-17 ]** : the constant unit is the DEFAULT for
    trunks [ a trunk buffers at both ends by its nature, and the privacy aim
    wants every crossing alike ] ; capped whole units stay the default for
    every other gate.
39. **refunds** : exactly what is owed, or with a penalty ?
    recommend : exactly what is owed, no penalty -- because a penalty moves
    value between groups on a failure, which the fairness aim rules out ;
    a service may still state a higher required cover.
40. **the first fill of a buffer** : intent and share part, or a margin on
    the price ?
    recommend : by intent or a `buffer` part of a share, then by its own
    gains ; no margin -- because a margin is a second price beside the
    rate version and would have to pass the design test as one more curve.
41. **the earmark of a promise** : the worst case per order, or a
    statistical bound ?
    recommend : the worst case, added up per order, for stage 4 ; a
    statistical bound only after the simulation has shown one that never
    fails the buffer -- because the worst case is exact, replayable and
    cannot over-promise, at the price of shorter horizons.
42. **the entry curve** : its numbers, the account that signs less, and
    what age is.
    recommend : a factor of 2 on the public part that sinks to 1 in even
    steps over 13 frames of the next coarser Y level ; an account that
    signs a lower part is warned and draws at ordinary terms, not newcomer
    terms ; age in frames now, by the weight of question 3 once it exists
    -- because the numbers are small, on the grid and easy to change in
    the simulation, and the condition keeps the commons from being drawn
    on for nothing.
43. **shadow accounts** : who may require cover, the default, the delay for
    taking cover out.
    recommend : any workload may state a required cover in its pool
    definition, value-moving ones must ; 1 : 1 by default ; free cover is
    returned at the next settle, one frame late -- because a cover below
    the amount in flight covers no full refund, and the one frame is what
    stops cover being pulled from under a running operation.
44. **buffer overflow** : the split and who states the numbers.
    recommend : `vendor : customer` 1 : 1 by default, and band, step and
    window stated by the service in the pool's definition -- because the
    definition is the address, so every customer sees the rule before it
    fills and nobody can change it afterwards.
45. **the cap on a return** : the largest part of its own spending in the
    window an account may receive back.
    recommend : one half -- because it keeps every return a lower price
    and never an income, makes self-payment through a pool lose at least
    half of what it puts through, and still empties an overfill within a
    few windows.
    **decided [ owner 2026-11-17 ]** : questions 35 to 47 as recommended,
    with 38 changed as stated there. the numbers of 42 [ factor 2 over 13
    frames ], 44 [ 1 : 1 ] and 45 [ one half ] are STARTING values, tuned by
    the design-test simulation [ section 21 ], not fixed constants.
46. **the aggregate across a domain edge** : whole units, or exact ?
    recommend : whole units with a carry, one unit late at most ; exact
    inside one domain -- because an exact aggregate hands every
    fingerprint to the parent, and nothing is lost by the carry.
47. **the design test as a gate**, and where the view is built.
    recommend : a rule that fails a property blocks its stage, and the
    view is a task of its own after 1b -- because the test is only worth
    its name if it can stop a rule, and the view needs nothing but the
    series file.

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

## 15. remainders of proportional splits [ owner 2026-11-16, for stage 1b ]

sections 15 to 21 fold the owner's idea set of 2026-11-16 into the design ;
section 22 maps each idea to its place and lists the conflicts. stage 1a
[ `AMOS7::NRT`, `bin/nrt`, b41ef81db ] is built and not changed by any of
it : every rule below lands in 1b or a later stage.

**the rule.** whenever drops are divided by weights, every party receives the
floor of its exact part, and what the floors leave over is handed to nobody :

    part of party i  =  floor( amount x weight i / sum of weights )
    leftover         =  amount - sum of parts          0 <= leftover < parties

- **no tie-break** : no leftover drop ever goes to one party by a rule of
  order, size or address. "largest remainder, ties by address" is out
- **the leftover stays in its channel**, the account that did the dividing,
  and is part of the amount of that channel's next division. it accumulates
  with future inflow until it fits a dissemination
- **when the channel closes, the leftover flows to its parent** : a slot's to
  its pool, a pool's to its accounting parent, a channel that belongs to one
  account back to that account
- **at the top it joins the network's own proportions** : the domain's
  **root pool**, a core pool with no parent, whose definition is what the
  network spends on all accounts [ the template user ]. never one user. the
  root pool never closes, so the chain ends there
- finer units only move the leftover ; accumulation and the parent flow
  resolve it

this is the carry of section 2, one step up. it is one pattern at every
scale [ owner ] :

| scale | what is divided | what is left | where it waits | when it moves on |
|---|---|---|---|---|
| units -> drops | measured units by a rate | units worth less than one drop | the carry stream | with the next usage of the stream |
| drops -> parties | drops by weights | fewer drops than parties | the dividing channel | with the channel's next division |
| channel -> parent | a closing channel's leftover | the same drops | the parent channel | with the parent's next division |
| drops -> token | 4200 drops | fewer than 4200 | the layer [ section 16 ] | when a whole token is reached |

**the invariant**, checked on replay for every channel :

    entered  =  given out + leftover held          leftover held < parties of the last division

the leftover is derived from the journal like the unit carry, never stored
beside it. it is drops in the balance of the channel account, earmarked for
that channel's next division : it is not free balance, not spent on a
category, and it does not count against a pool's capacity.

**where divisions occur**, and which channel keeps the leftover :

| division | channel | note |
|---|---|---|
| a share's budget per category [ section 4 ] | the giving account | a reservation is local : the leftover was never earmarked and is simply free |
| dissemination, the re-offer in equal parts [ step 4 ] | the giving account | same : it "stays with the giver" already |
| overfill, the surplus given back in proportion | the slot | see below |
| `earn` to several providers by proven units | the slot | |
| `return` of an ended slot to those who filled it | the slot, then its pool at the `close` | |
| overflow and fairness returns [ sections 19, 20 ] | the pool | joins the release of the next frame |
| a gate's crossing in whole units [ section 17 ] | the gate | the buffered amount below one unit |

**overfill without a tie-break.** three reservations of 40 on a requirement
of 100 cannot take 33 + 33 + 33 : the slot would hold 99 and never
saturate. so the division is made on what flows **out**, never on what must
be complete : the surplus of 20 is divided, each giver keeps 6 of it, and
the slot takes 100 + 2. the 2 are the slot's leftover. the slot is
saturated at 100, pays at most 100, and at its `close` the 2 flow to the
pool. so the sentence of section 4, "only the requirement is taken", reads :
the requirement, and a leftover of fewer drops than there are givers.

**the record.** a leftover moves only at a `close`, as one transaction of
the new reason `remainder` : one `-` row, the closing channel, one `+` row,
its parent, by the authority of the closed record. a leftover of zero
writes nothing. inside a living channel nothing moves at all, so no record
is needed.

**the root pool.** the network account cannot be the top of the chain : it
is the counter of supply and changes only by an `issue` [ rule 11 ]. the top
is a pool : the first `pool` record of a domain that is marked core and
names no parent. a pool without an accounting parent has the root pool as
the parent of its leftover and of nothing else : no aggregate is told, no
accounting edge follows from it [ question 35 ]. until a root pool exists,
a closing pool's leftover waits in the closed pool's account and is listed
by `verify` [ rule 12 ].

**the unit carry at a stream's end.** section 2 closes an ended stream's unit
remainder by a record that states it. units are measured work, not drops,
so there is nothing to move ; under the pattern the stated remainder is
taken over by the successor stream [ same pool, provider and class, the
next rate version ] and counts there. where no successor exists it stays
stated in the `close` record and is named to the accounting parent as
units. proposed, question 36.

**the token question** [ owner : does a pool that reaches 4200 drops become a
token record ? ]. inside one layer : no, the token stays the counting unit
and no record is written at 4200. the place where 4200 drops do become one
thing is the layer boundary of section 16.

## 16. nested units [ owner idea, not decided ; stage 6 ]

**the idea.** the token of a layer is the drop of its parent layer :

    1 drop of layer n+1  =  1 token of layer n  =  R drops of layer n          R = 4200 [ proposed ]

a **layer** is a ledger domain : one witness, one journal, one supply
counter, its own 13 digits. nothing in a domain is ever written in another
layer's unit. what follows shows that the idea holds together ; it is not
built before stage 6 [ several domains ], and stage 1b needs nothing from
it.

**conservation across layers : lock above, issue below.** supply exists at
the top and is lent downward, never created at the bottom :

- the parent keeps one **layer account** per child domain : a pool whose
  definition names the child's ledger id, so its address follows from it
- **lowering** : `k` parent drops move into the child's layer account [ a
  transaction of the parent ]. that record is the basis of one `issue` of
  `k x R` drops in the child, to the child's **gate** [ below ]. a lock
  record is used once, forever, like a proof [ rule 8 ]
- **lifting** : `k x R` child drops move into the child's gate and stay
  there ; that record is the basis on which the parent releases `k` drops
  from the layer account. used once, forever
- the child never un-issues. rule 11 stays as it is : only an `issue`
  changes a network account, and amounts are positive. what came up waits in
  the gate and goes out again with the next lowering ; the child issues
  only when its gate is empty

the invariant that ties two layers, checked by whoever holds both heads :

    R x locked in the layer account  =  supply of the child - held in the child's gate

every domain keeps its own zero sum and supply check unchanged. the sum
total over all layers, counted in drops of the lowest layer, is the top
layer's supply times R per step down, and no lock or lift changes it.

**what a parent risks.** the layer account never goes below zero [ rule 3 ],
so a child whose witness lies can take out of the parent at most what was
locked for that child. a compartment's fault is bounded by its own lock :
localization is also the safety property.

**the 13 digit bound per layer.** each layer holds at most
9 999 999 999 999 of its own drops. a child at its bound has locked
floor( 9 999 999 999 999 / 4200 ) = 2 380 952 380 parent drops, and
4200 x 2 380 952 380 = 9 999 999 996 000 : with R = 4200 a parent at its
bound fills exactly R children to theirs. the bound is never widened, the
tree grows instead : `n` layers above the lowest count up to
9 999 999 999 999 x 4200^n lowest drops without any number of more than 13
digits in any record. a child at its bound takes no more ; what is offered
to it overflows to its siblings or stays above [ section 4, the same
water-filling ].

**the carry between layers.** fewer than R child drops cannot cross : they
are the remainder of the layer and wait in the gate until a whole parent
drop is reached. the stream invariant is the one of the unit carry :

    lifted x R + waiting in the gate  =  entered for lifting

so the last row of the table in section 15 is this section : drops are the
remainder of tokens, and a whole token is one thing again, one level up.
that also answers the owner's open point : the "token that is also an
account" of NRT.NRD is the layer account entry, and inside one layer the
token stays a counting unit.

**fixed 4200 or a ratio per layer.** proposed : fixed.

- 4200 is already in the grid : one second is 4200 ntime units, the year is
  4200 x 86400 x 365 [ `AMOS7::cell::time`, `NTIME_YEAR` ]. the same number
  steps value that steps the second
- one rule for every edge : the fan-out identity above, one carry bound,
  and an amount converts between any two layers by a power of one number
- a ratio per layer would have to stand in a record both layers verify and
  makes every crossing a lookup. 13^3 = 2197 or 13^4 = 28561 would line the
  value step up with the Y grid, at the price of leaving the 4200 of
  NRT.NRD ; the two axes do not need the same number [ next paragraph ]

**fit with `AMOS7::cell::time` and the cell tree.** value and time nest on
separate axes, and both are exact :

- **time** steps by 13 : a frame of level `l` is 13 frames of level `l+1`
  [ `frame`, `window`, `path` ]. proposed : a layer up settles one Y level
  coarser [ level - 1 ], so one parent frame is 13 child frames
- **value** steps by 4200
- a crossing happens **once per parent frame**, as one aggregate of whole
  parent drops. the child's 13 frames in between collect ; that is the
  batch per frame the clean units of section 17 want
- in the cell tree a pool is a cell and a slot a child cell [ synthesis ].
  a layer is a cell whose journal is a whole domain ; its layer account is
  the downward channel, the gate the gated transaction state. the parent
  learns whole parent drops per parent frame and nothing else, which is
  the **accounting parent** role exactly [ section 3 ]. the child's witness
  stays the only party that replays the child
- `path` gives the frame of every level for one ntime, so a record of a
  child states its place in the parent's frame without arithmetic of its
  own

**what it brings** [ owner ] : efficiency [ most records never leave their
layer ; a parent holds one row per child per frame ], portability [ a child
runs on its lock while it is cut off and reconciles at the gate ],
localization [ spatial and temporal compartments are domains with a bound
fault ].

**what it needs that does not exist** : a record kind that binds a child to
its parent [ ledger id, R, the level difference ], an `issue` basis other
than `test` [ the lock record ], an `issue` to a pool [ 1a issues to a key
account only ], and a reader of the other layer's signed head. all of it
is stage 6 and needs its own design ; the `init` record of 1a is not
changed.

## 17. clean units across compartment boundaries, and trunks [ stage 6 ]

**why.** an odd amount is a fingerprint : 17 351 drops seen on two sides of a
boundary are the same payment with near certainty. kept local, the
remainders buffer that entropy out, and only clean values cross [ owner ].
a **compartment** is a ledger domain ; a boundary is every edge between two
domains, up the tree or to a parallel branch.

**the gate.** every edge has a **gate** at each end : a pool with no key,
whose definition states the edge [ the two ledger ids ], the **transmission
unit** `U` [ a whole number of parent drops ], the frame it crosses on and
its caps. the definition is its address, so the rule of a gate cannot be
changed.

- inside, an account pays into the gate with an ordinary transaction, any
  amount. only the local witness sees it
- the gate crosses **only whole units, only at a frame boundary, only as
  one aggregate** : `k x U`, with no payer, no payee and no single amount
- opposing directions of one frame are **netted first** ; only the
  difference crosses [ the net unwinding of section 6, on an edge ]
- what is below one unit **waits at both ends** and joins the next frame.
  it is the gate's leftover [ section 15 ] :

      crossed x U + waiting  =  net entered          waiting < U

- the far gate pays the receivers inside its own compartment, in exact
  amounts, **from what it holds**. where it holds too little the payment
  waits [ prepaid, rule 7 ; waiting time, never debt ]. how much a gate
  holds ahead is a buffer pool [ section 19 ], and what stands in for a
  payment that is still on its way is a shadow account [ section 18 ]
- the instruction "pay this account that much" travels sealed to the far
  gate. it is not part of what crosses in the ledger

**who learns what**, stated plainly, because no arrangement hides everything
from everybody :

| party | sees | does not see |
|---|---|---|
| the near witness | the payer, the amount, "into the gate" | the receiver |
| the parent, every observer of the edge | `k` units per frame | payers, receivers, single amounts, the count of payments |
| the far witness | the receiver, the amount, "from the gate" | the payer |

the two witnesses together can match an amount of one frame on both sides.
the gate removes the fingerprint for the edge and for everything above it,
not for two colluding ends. a sender who wants more splits the amount over
frames, or pays in units itself.

**how clean is clean.** what an edge leaks per frame is the choice among the
values it may carry : about `log2( number of allowed values )` bits.

| rule for what may cross | allowed values up to N | leak per frame |
|---|---|---|
| any amount | N | about log2 N |
| prime amounts only [ owner, hypothetical ] | about N / ln N | about log2 N - log2 ln N : little less |
| whole units, `k x U` | N / U | log2( N / U ) |
| whole units, `k` capped at `c` per frame | c + 1 | log2( c + 1 ) |
| one unit every frame, or none | 2 | 1 bit |
| one unit every frame, always | 1 | nothing |

proposed : whole units with a cap per frame, both in the gate's definition.
primes still leave many distinct values and cannot be netted or summed [ a
sum of primes is rarely prime ], so they fit a crossing that is added up
badly. the strongest form is the last row : a gate that always sends
exactly one unit per frame and buffers the difference in both directions
carries no information at all, and is the entropy-free base workload of
`topic-latency-algorithmic-authority-entropy-toll`. it needs a buffer of
the size of its traffic's swing ; the cap `c` is the dial between the two.

**what an accounting parent is told** changes with this. section 3 gives it
exact amounts per class per frame, which hands every odd amount upward.
under clean units the aggregate is stated in whole units of the edge, and
the report keeps its own carry : `told x U + carried = actual`. nothing is
lost to the parent, it arrives one unit late at most. within one domain
[ stage 1b ] the parent and the child share a witness and the exact
aggregate stays.

**a layer edge is the smallest gate** : `U` is one parent drop, that is `R`
child drops, and the gate of section 16 is this gate.

**trunks** [ owner : "wormholes" ]. a **trunk** is a standing pair of gates
between two regions that are not parent and child :

- value moves on the nearest layer both regions share : a transaction of
  that ancestor between the two layer accounts, in whole drops of the
  ancestor. the trunk's unit is therefore a whole number of ancestor drops,
  and each end collects until one unit is reached, buffered below that at
  both ends
- between regions with no common ancestor nothing native moves. that is
  the outside bridge [ stage 9 ], not a trunk
- a trunk's definition states both gates, `U`, the frame, a cap per frame
  and per direction, and the cover it requires [ section 18 ]
- **a trunk is a native workload** : keeping the two gates, sealing and
  delivering the instructions and holding the buffer is work of the class
  `transport`, signalled as a slot per frame and paid on proof. its proof
  is of the ready kind : the crossing stands in two signed records, one of
  each end, that state the same units for the same frame, as two n7fs
  receipts bound an interval. a trunk that is paid for clean, constant
  traffic is paid for exactly the property the latency note asks of a
  relay

**threats that come with it** [ to section 10 when this is designed ] : a far
gate that pays out ahead of the crossing lends ; it may do so only from
what it holds, and the cover of section 18 is what it draws on if the near
side never crosses. a thin trunk leaks by timing : few payers per frame
make the aggregate one payment again, so a gate states a smallest crowd or
keeps the constant unit. the sealed instruction is outside the ledger and
needs its own delivery proof.

## 18. shadow accounts [ owner 2026-11-16 ; local form stage 4, across domains stage 6 ]

**what it is.** a **shadow account** is the network-side shadow of one
account : a cover the network holds for it. it covers the refund of a
failed transaction, in both directions the same way, and it replaces trust
in the user plus a handshake per transaction by trust in the network, which
checks that the transacted amount is covered. workloads that transport or
translate value [ trunks, the converting zenka ] may require it as their
handshake.

**its form : a pool, no new account kind.** the shadow of account `A` is a
pool whose definition names `A` as the one it stands for, its **target**
[ the capacity ] and its cover rule. so :

- its address follows from its definition ; nobody grants it and its rule
  cannot be changed
- it has no secret key. it moves only by the witness, under its own
  definition, and every such move is replayed and refused when the
  definition does not carry it
- what it holds are `A`'s own drops, earmarked. the sum total does not
  change : a shadow is a place, not a source

**filling.** by intent : a transaction of `A`'s key into the shadow, reason
`cover`. automatically : a part of `A`'s share named `cover` fills it per
cycle like any pool, up to the target ; at the target it takes no more and
the part stays with `A` [ capacity and overflow, section 4 ].

**"covered" replaces the handshake.** a workload that moves value states in
its pool definition `cover = <n> : <d>`, the cover it requires per drop in
flight [ proposed default 1 : 1 ]. then, per operation of amount `a` :

1. the witness checks that the free cover of the shadow is at least the
   required cover, and earmarks it : a `reserve` on the shadow towards the
   operation's slot. reserved cover cannot be reserved again [ rule 6 ]
2. the operation runs with no further signature of the user. the agreed
   proportion authorized it [ section 1 ], the cover makes it safe to act
   on before the user's own drops have arrived
3. the slot closes, and exactly one of three things happens

| outcome | fact in the journal | what moves |
|---|---|---|
| done | the usage is proven before the slot's deadline frame | the earmark ends ; the user's payment settles through the slot as usual |
| the user's side failed | the slot was acted on, and at the deadline it holds less than was acted on | the missing amount, from the user's shadow to the party owed |
| the service's side failed | drops left the slot towards the service, and no proof stands at the deadline | the slot returns what it still holds ; what had left comes from the service's shadow to those who filled |

**symmetric.** both sides of a value-moving operation hold a shadow, and the
same rule draws on either : the same record kinds, the same deadline, the
amount that is owed and not one drop more. the refund is a transaction of
the new reason `refund`, from a shadow, by the authority of the closed slot.
no penalty is added by default : a refund makes the owed party whole and
moves nothing else, so no group gains from another's failure [ question
39 ].

**what a failure is.** only what the journal itself shows : a deadline frame
that passed without the record that was due. the ledger does not judge
whether a pizza arrived ; what counts as proof of an outside delivery is
question 26 and stays open. so a shadow covers every failure that shows as
a missing record, and an outside fact only through the proof its slot
names.

**it does not bend the prepaid rule.** cover is prepayment made earlier and
held network-side. a draw is bounded by what the shadow holds [ rule 3 ],
so there is still no debt ; an operation whose cover cannot be earmarked is
not started, and says so at once [ section 19, fail fast ].

**no key account is ever drawn on.** section 6 states that a key account
moves only by its own key or its own share. the shadow keeps that true : the
account moved its drops into the shadow itself, and from there on the
network draws on a pool.

**release.** an earmark ends with its slot. free cover above the target
flows back to `A` at the next settle [ overflow ]. `A` takes free cover out
by a signed `close` naming the amount ; it is returned at the next settle,
after every earmark of that frame, so cover cannot be pulled from under an
operation that already counts on it.

**size.** the cover per drop in flight comes from the workload's definition ;
the target is `A`'s choice. the most that can be in flight for `A` at once
is its free cover divided by the required cover : the shadow is also the
per-account cap of value-moving work, beside the share budget.

**across compartments and layers.** a cover is of use only where the party
that relies on it can check it. so cover for a trunk or a layer edge is
held **at the layer the edge settles on**, in that layer's whole drops, and
it is the **gate's** shadow, not a user's : the user's shadow covers the
gate inside the compartment, the gate's shadow covers the trunk one level
up. cover nests like the units, each layer covers the next, and no user is
named above its own compartment [ section 17 ].

**who is trusted.** "the network validates" means the witness of the domain
replays the rule ; with one witness per domain that is one party
[ contradiction 6 ]. the shadow moves the trust from every counterparty to
that witness, it does not remove it. a shadow's definition names its
account and so links the two for everyone who sees the domain's pools
[ question 14 ].

## 19. buffer pools [ owner 2026-11-16 ; stage 4 ]

**what it is for.** between the moment an order is committed and the moment
it completes, its cost can move : a conversion rate swings, a vendor
re-prices, the proven units differ from the estimate. a user cannot
influence that and suffers when a tiny underrun forces a re-price it may
never see. a **buffer pool** stands between : the customer pays what was
promised, the service receives what it cost, and the pool takes or gives
the difference. that makes promises on completion reliable and decouples
the inside from outside spikes and manipulation.

**generic, and no new mechanism.** any service runs its own, the network
needs none natively : a buffer is a pool with one category of the rule
`buffer`, whose definition names the service pool it serves and carries
the numbers below. address by definition, no key, capacity, overflow and
the per-frame proportion budget are those of every pool.

**symmetric fill and drain.** for an order promised at `p` drops that
completes at a proven cost of `c` drops :

    c <= p    the slot pays the service c, and p - c goes from the slot into the buffer
    c >  p    the slot pays the service p, and c - p goes from the buffer to the service

both are transactions of the new reason `buffer`. the customer pays exactly
`p`, the service receives exactly `c`, the buffer moves by `p - c`, and the
three add up in every case. a gain in the network's favour fills the
buffer and stays local to the intent it came from [ owner ]. only a slot
and a pool are ever debited, never a key account.

`c` is a **proven** number : the proven units at the slot's rate version
for native work, or, for an outside purchase, the proven outside price at
the rate version active at completion [ the proof of question 26 ]. a
service that may state its own cost empties the buffer ; without a proof
of `c` there is no buffer, only the fixed slot.

**noise, not drift.** a buffer is a low-pass filter : it turns steps into
ramps. it can absorb what averages out and nothing else, so the
**reference rate**, the rate promises are priced with, must follow
sustained trends :

- the reference is an ordinary rate version, written by the witness for the
  next frame from the journal alone : the proven costs of the last `W`
  frames as one ratio of sums, `sum of drops : sum of units`. whole
  numbers, no division, no float, the same on every replay
- under a steady trend of `s` per unit and frame the reference lags by
  about `( W + 1 ) / 2` frames, and the buffer loses about
  `s x ( W + 1 ) / 2` per unit. it is drained at a known pace : the buffer
  divided by that pace is the **warning time**
- a short `W` follows fast and filters little, a long `W` filters well and
  is drained by arbitrage against its lag. `W` stands in the definition

**promises sized to capacity.** the definition states a **band** `b`, the
largest adverse move per unit the buffer covers, taken from the spread of
the same `W` frames. a promise is a **reservation in the buffer** :

- an order of `u` units is committed only when `u x b` can be earmarked in
  the buffer towards its slot. earmarked drops are not promised twice
  [ rule 6 ]
- so what can be promised is exact at every moment :
  `floor( free buffer / b )` units, and with a volume of `v` units per frame
  the firm **horizon** is `floor( free buffer / ( v x b ) )` frames
- parallel orders add their exposure, so the size of the buffer bounds how
  far ahead agreements can go [ owner ]. the earmark is the worst case and
  adds up linearly ; many independent orders vary less than that, and a
  statistical earmark is a later curve [ question 41 ]
- the horizon shrinks smoothly with the fill level and reaches zero with
  the buffer. that is the warning : every settle states the fill level and
  the horizon, and a strategy sees its room shrink long before an order
  fails
- band, reference and horizon are recalculated every frame from the
  journal : the short, statistics-based agreement of the owner's note

**committed orders only.** a buffer serves saturated slots and nothing else.
a quote is no promise ; a reservation that can still be redirected
[ `buy = complete`, before saturation ] holds no earmark. once committed, an
order is not withdrawn to pick the better side of a move : a promise that
can be cancelled for free is an option, and the buffer would pay for it.

**caps per frame.** two, both existing rules : an account converts at most
the budget of the matching category of its share per frame, and the buffer
gives out at most its own proportion budget per frame. the proportions
bound how fast a pool can be drained [ section 1 ] ; for a buffer that
bound is the worst case of one frame.

**fail fast, with a refund, never a silent stall.** an order is in one of
three states and says which :

- **refused at once** : the earmark does not fit. the order may still be
  placed unbuffered, and is then marked as one that can be re-priced [ a
  warning, not a refusal ]
- **cleared** : the proof stands before the deadline frame and the move was
  within the band
- **failed** : the move exceeded the earmark, or the deadline frame passed
  without proof. in the same settle the slot is closed with that reason,
  what it holds returns in full to those who filled it, and what had
  already left is covered by the service's shadow [ section 18 ]. a
  buffered slot always carries a deadline, never beyond the horizon it was
  promised under, so "open and waiting" does not exist past it [ rule 12 ]

**overflow lowers the price, with hysteresis.** a buffer above its capacity
gives the excess back through the price [ owner ] : the irrigation
overflow, applied to a rate. the definition states a band around the
capacity, `low < high`, and a **step** :

    above high        the discount rises by one step per frame
    low to high       the discount stays what it was
    below low         the discount falls by one step per frame, down to zero

the discount is the next rate version, so its state is in the journal. the
dead band is the hysteresis : the price does not chatter around the
capacity. the step is the largest change per frame : the price moves in
ramps and never jumps, which a plain on \ off switch would [ the design
test, section 21 ].

**split between vendor and customer.** the excess released per frame is
divided by a share rule of the pool's definition, `vendor : customer`
[ proposed default 1 : 1 ]. the customers' part is the discount ; the
vendor's part is paid to the service over the same window, by its proven
units. both go by use over a window and never to whoever comes first
[ section 20 ]. floors leave a leftover, which stays in the buffer
[ section 15 ].

**the two ends.** empty : no promise, every order unbuffered and marked,
gains refill. full : the price sinks until inflow and outflow meet. in
between every readout [ horizon, discount, fill level ] moves by bounded
steps. an empty buffer starts by intent or by a `buffer` part of a share,
and from the first favourable move by itself [ question 40 ].

**where it sits.** the converting zenka and a trunk's gates [ section 17 ]
are the first users ; the bridge questions 12, 26 and 30 decide the
outside edge. a public pool's drops do not fill a buffer of an outside
edge [ the proposed answer to 30, unchanged ].

## 20. fairness curves [ owner 2026-11-16 ; stage 4 ]

**the aim.** curves for pricing, overflow return, latency and priority that
balance incentives and keep the sum total : they move when and to whom
drops flow, they never create or remove one, and they never siphon value
from one group to another [ owner ].

**two overflows, kept apart.** section 4 describes a pool that **refuses**
what is offered above its capacity : the offer is a local reservation, so
the refused part never left the giver and nothing has to be returned. this
section is about a pool that already **holds** more than its capacity,
because of buffer gains, returned fills, leftovers, or a capacity that
shrank. those drops are in the pool and have to flow back.

**overflow returns over a window, pro rata to use, never first-come.**

- the excess of a frame is released over the next `W` frames, per frame
  `floor( excess still held / frames left )`. no rush to empty an overfill
- each release is divided over the accounts **by their use of the pool in
  the window** : the drops each paid through it in the last `W` frames.
  the moment of an order has no weight at all, so there is nothing for a
  prediction model to be first at
- what the floors leave stays in the pool and joins the next release
  [ section 15 ]
- the release is a transaction of the new reason `overflow`, written by
  the witness in the settle pass, by the authority of the pool's
  definition. `W` and the use rule are part of that definition
- an account receives per window at most a stated fraction of what it
  spent through the pool in that window, below the whole. so a return is
  always a lower price for real use and never an income, and the rest
  stays for the following windows. this cap is what stops use that is
  inflated by paying oneself through the pool [ rule 10 makes that free ]
  from farming the return

**what it does over time.** when the network's resources rise against the
outside, buffers overflow, prices sink, and those who use the network are
rewarded through cheaper workloads, in proportion to their use. that is
one way long-term users and new accounts are balanced without a transfer
between them.

**public pools overflow back to the users** [ owner ], never a permanent
drain. a public pool at capacity refuses further fills [ section 4 ], and
what it holds above capacity returns by the rule above. new accounts
profit too, most when many join quickly while the commons is full.

**new accounts fill public pools proportionally higher** [ owner idea ]. an
**entry curve** : the public part of a share is multiplied by a factor that
starts above one for a new account and sinks to one over a stated number
of frames, in even steps.

- it is **sum-neutral** : a larger local reservation of the account's own
  drops towards the commons, nothing issued, nothing taken by anyone
- it is a **proportion, not a fee** : an account that holds nothing fills
  nothing. the barrier to enter stays where the irrigation principle puts
  it, at zero, and a newcomer's net position at entry stays positive : it
  draws from the public pools from its first frame and fills them only out
  of what it later holds
- it is **self-limiting** : once the commons is at capacity the higher part
  is refused like any other and stays with the newcomer. the entry
  contribution bites only while the commons is actually short
- it raises the price of many fresh accounts, each of which pays in more
- **where the curve stands** : in the share of the generic template user,
  the default a new account starts under, and in a public pool's
  definition as the condition of its newcomer category. an account's own
  signed share still states its part : the owner's rule that a user
  defines exactly what it gives is kept. an account that signs a lower
  part is warned and not refused ; whether it then still draws at newcomer
  terms is question 42
- **age** is counted in frames since the `account` record. age alone is
  cheap to fake by opening accounts early and leaving them idle, so the
  factor should follow the same weight as the NRT index [ question 3 : a
  long-existing account with good values ] once that exists

**the form of every curve.** a curve is a short table of points in a pool's
definition [ input -> value, whole numbers ], read by exact interpolation
with the floor, the leftover handled by section 15. changing a curve gives
another pool. every curve states its largest change per frame. the curves
of this design :

| curve | input | value | section |
|---|---|---|---|
| price | fill level of a buffer | discount, as the next rate version | 19 |
| horizon | free buffer | frames a promise is firm | 19 |
| return | frames since the overflow | part released | 20 |
| entry | age \ weight of an account | factor on its public part | 20 |
| latency | depth of a balance | delay of a `thaw` | 6 |
| priority | loves_it weight | part of one budget | 4 |

latency and priority exist already ; they are listed because the same test
applies to them [ section 21 ]. rate curves per pool were stage 4 before
this section ; these are those curves.

**what a curve may never do** : pay a group out of another group's balance.
every curve above either moves an account's own drops later or elsewhere
[ entry, latency ], divides one fixed budget [ priority ], or returns to
users what a pool holds above its need, by use [ price, return ]. a curve
that needs a source of its own is refused by the zero sum.

## 21. the design test : from empty to saturated, smooth in time [ owner ; stage 1b on ]

**the test.** a clean design looks good starting at zero and saturated, and
proportionally smooth in between, with time as the horizontal axis
[ owner ]. it becomes an **acceptance property** of every stage from 1b on :
a rule that moves drops is not accepted until a simulation has run it from
empty to saturated and back, and the properties below held in every frame.

**one simulation, the real code.** the simulation is a driver, not a model :
it writes a journal with the ledger's own modules [ a scratch ledger, test
issue, test proofs ], settles frame after frame, and reads every value
back by replay. there is no second implementation of a rule that could
agree with itself. per frame it writes one row of a **series** : fill
level, held, reserved, given out, leftover, horizon and price per pool,
and the checked sums. the series is a plain column file with a p7 config
style head [ no json ].

**scenarios**, each a fixed, seeded script of inflow per frame :

| scenario | what it shows |
|---|---|
| ramp : constant inflow into an empty system until nothing more is taken | the empty end, the way up, the saturated end |
| drain : inflow stops at saturation | the way down, nothing stuck |
| step : inflow jumps once | how a step is turned into a ramp |
| noise : inflow and cost vary around a fixed mean | a buffer holds its level |
| drift : cost rises steadily | the reference follows, the warning time is the predicted one |
| wave : many new accounts in few frames | entry curve, public pools, overflow back |
| overfill : more is offered than every capacity | refusals, returns, leftovers |

**properties**, asserted on the series in every frame of every scenario :

1. **the sum** : zero sum and supply hold after every record ; over the
   whole run, entered = held + given out + leftover, per pool and in total
2. **no step without a cause** : every readout changes per frame by no more
   than its stated largest change, or by no more than its input changed in
   that frame. an output that jumps while its inputs moved smoothly fails
3. **the empty end** : the first drop into an empty system has a defined
   result. no division by zero, no refused first order for lack of a
   history, no value undefined at fill level zero
4. **the saturated end** : under constant inflow every pool reaches a level
   where what enters equals what leaves, and stays there. nothing grows
   without bound
5. **no hoarding** : no pool holds more than its capacity for longer than
   its return window, and no leftover reaches the number of its parties
6. **monotone where the rule says so** : under constant inflow a fill level
   never falls, under none it never rises ; a discount moves towards its
   band and not away from it
7. **order and time of arrival mean nothing** : the same inflow written in
   another order inside a frame gives the same series. the first of a
   frame receives what the last receives for the same use
8. **nobody pays for another group** : per group of accounts [ new, long
   existing, heavy, light ], what a curve returned never exceeds what a
   pool held above its need, and no group's total falls by a curve alone
9. **nothing waits silently** : no order is open past its deadline frame ;
   every refusal and every failure stands in a record with its reason

a property that cannot hold for a rule is a finding about the rule, not
about the test.

**the same simulation drives the picture** [ owner ]. every series can be
drawn and animated in true proportions : the curves that balance each
other are the picture, so clean and self-sustaining is visible at a
glance. the view reads the series the tests assert on and computes nothing
of its own : a view is a checked readout [ synthesis contradiction 13 ],
and a picture that looks wrong is a failed property or a missing one. by
default a dark violet \ blue theme and a slow, calm animation whose speed
is easily lowered ; print stays light. later the same views become
perspectives and layers of the live network state, as a basic workload
[ background images, dashboard content ] ; that is a readout of real
journals in place of scratch ones, and not part of this design.

**what 1b takes from sections 15 to 21.** the remainder rule and this test.
everything else waits for its stage. added to the 1b task, after the
checks of section 11 :

31. no tie-break : three reservations of 40 on a requirement of 100 leave
    each giver 6 of the surplus, the slot holds 102, pays at most 100, and
    its `close` writes one `remainder` transaction of 2 to its pool. the
    same case with the givers written in every order gives the same
    records. the ledger files hold no comparison of addresses or amounts
    that decides who receives a drop
32. the leftover accumulates : a channel dividing 10 drops by three equal
    weights three times gives out 9, then 9, then 12, and holds 1, 2, 0 ;
    entered = given out + leftover after every division
33. a closing pool's leftover flows to its accounting parent, or to the
    root pool where it names none ; with no root pool it stays and `verify`
    lists it. a leftover of zero writes no record
34. the design test, scenarios ramp, drain, step and overfill, on the
    dissemination and slot rules of 1b : properties 1 to 7 and 9 hold in
    every frame
35. the series of check 34 is written twice from the same seed and is equal
    byte for byte, on both perls

the simulation's home [ a module beside the test script, its name with the
1b task ] and the view are new files of their own ; no file of 1a changes.

## 22. owner idea set 2026-11-16 : where each idea landed, and what it met

source : the owner's notes of 2026-11-16 late [ remainders downward ]. decided
direction unless marked idea.

| idea | status | landed in | stage |
|---|---|---|---|
| remainders : accumulate in the channel, close -> parent -> network proportions, no tie-break | decided | section 15 ; reason `remainder` ; the root pool ; checks 31 to 33 | 1b |
| one pattern at every scale ; is a token a record | decided \ answered | section 15 table ; section 16 : counting unit inside a layer, a thing at the layer edge | 1b \ 6 |
| nested units : a layer's token is the parent's drop | idea | section 16 : lock above, issue below ; fixed 4200 proposed ; 13 digits per layer ; carry in the gate | 6 |
| clean units cross boundaries [ anonymization ] ; primes | decided \ hypothetical | section 17 : gates, whole units with a cap, the leak table | 6 |
| transaction trunks to other regions | idea | section 17 : a pair of gates over the nearest shared layer ; a `transport` workload | 6 |
| shadow accounts | decided | section 18 : a pool that stands for one account ; `cover`, `refund` ; cover in place of the handshake | 4 \ 6 |
| buffer pools : generic, sized promises, symmetric, noise not drift, committed only, caps, overflow price with hysteresis, vendor \ customer split, fail fast | decided | section 19 ; reason `buffer` | 4 |
| fairness curves : return over a window by use ; new accounts fill higher ; public pools overflow back ; sum-neutral | decided \ idea | section 20 ; reason `overflow` ; the entry curve | 4 |
| the design test ; the simulation is the visualization | decided | section 21 ; checks 34, 35 | 1b on |
| irrigation as the guiding picture | decided earlier | section 1 ; used by 15, 19, 20 | |

**new words** : `remainder`, `cover`, `refund`, `buffer`, `overflow` as
transaction reasons ; **root pool**, **layer**, **layer account**, **gate**,
**transmission unit**, **trunk**, **shadow**, **band**, **horizon**, **entry
curve**, **series**. no new account kind and no new record kind inside one
domain : every new thing is a pool with a rule in its definition. stage 6
needs one record kind that binds a child domain to its parent.

**the stages after this**, in place of the list at the end of section 11 :
1b + the remainder rule and the design test ; 2 and 3 unchanged ; 4 rate
curves and quotes + buffer pools, fairness curves, shadow accounts inside
one domain ; 5 unchanged ; 6 several domains + layers, gates, clean units,
trunks, cover across layers ; 7 and 8 unchanged ; 9 the bridge, which needs
the shadows and buffers of stage 4.

**conflicts with existing rules, and the proposed resolution.** numbered on
from the contradictions of section 9.

17. **the network as the last parent, against rule 11.** the owner's chain
    ends "at the network" ; the network account is the supply counter and
    changes only by an `issue`. a leftover paid into it would un-issue.
    -> the chain ends at the **root pool**, a core pool holding the
    network's own proportions [ section 15 ]. rule 11 is untouched.
18. **no tie-break, against "only the requirement is taken".** section 4 and
    check 21 let nothing above the requirement into a slot ; dividing what
    is taken can leave the slot one drop short for ever. -> divide the
    surplus that flows back, not the requirement ; the slot takes the
    requirement and a leftover of fewer drops than givers, pays at most
    the requirement, and passes the leftover to its pool at the `close`.
    the numbers of check 21 are unchanged, its sentence is widened by
    check 31.
19. **the unit carry is closed and stated, against "the leftover flows
    on".** section 2 ends a stream's unit remainder with a record. -> units
    are not drops and nothing moves ; the stated remainder is taken over
    by the successor stream. check 20 keeps its wording [ the record still
    states it ]. question 36.
20. **a buffer, against rule 10** [ "what a slot fixed, it pays ; no second
    rate and no spread" ] **and against the return of an ended slot.** a
    buffered slot pays its service the proven cost, not the promised
    amount, and gives the difference to the buffer instead of back to
    those who filled it. -> rule 10 holds for every slot that names no
    buffer. a slot that names one says so in its record : the givers
    agreed to pay exactly the promise, the difference is one stated
    transaction of the reason `buffer`, bounded by the earmark, and no
    party receives more than a proven cost. the spread rule 10 forbids
    went to somebody ; this one stays in a pool with no key and flows back
    by section 20.
21. **refunds and network draws, against "a key account moves only by its
    own key or its own share"** [ section 6 ]. -> nothing is ever drawn
    from a key account. the account moves cover into its shadow itself ;
    the network draws on that pool. in a buffer the gain is taken from the
    slot before it reaches the service, never back out of the service.
22. **acting before the user has paid, against prepaid** [ rule 7 ]. a far
    gate that pays out before the crossing, a workload that starts on
    cover alone. -> cover is prepayment held network-side ; a gate pays
    only from what it holds ; the draw is bounded by the shadow. where
    neither holds enough, the operation waits or is refused at once.
    still no debt anywhere.
23. **lifting between layers, against positive amounts and rule 11.** value
    going up a layer looks like supply leaving the child. -> the child
    never un-issues : what goes up waits in its gate, the parent releases
    from the layer account, and the child issues only against a lock when
    its gate is empty [ section 16 ].
24. **clean units, against the exact aggregate an accounting parent is
    told** [ section 3 ]. exact amounts per class per frame carry every
    fingerprint upward. -> across a domain edge the aggregate is told in
    whole units with a carry of its own ; inside one domain, where parent
    and child share a witness, it stays exact [ section 17 ].
25. **hysteresis, against the design test.** a switch between "lower the
    price" and "stop" is a step with no step in its input. -> a dead band
    plus a largest change per frame : the price ramps, holds, ramps
    [ section 19 ].
26. **a higher fill for new accounts, against "a user defines exactly which
    share it gives".** -> the entry curve is the default of the template
    user and a condition of a public pool's newcomer category, never a
    change to a share an account signed. a proportion of what is held, so
    the barrier to enter stays zero [ section 20, question 42 ].
27. **return by use, against free self-payment** [ rule 10 : "paying
    yourself through a pool returns your own drops" ]. use that costs
    nothing could farm a return that follows use. -> a return per window
    is capped below what the account spent through the pool in it, and
    only proven usage counts as use. to section 10 as a threat.
28. **committed orders only, against the freedom of `buy = complete`.** no
    conflict : that freedom ends at saturation, and a buffer promises
    nothing before it.
29. **the two overflows.** section 4 says overflow goes on or back "as the
    share says", section 20 says by use over a window. -> different
    things : what a pool refuses never left the giver ; what a pool holds
    above its capacity returns by use.

#,,.,,.,.,,,.,..,,..,,,,.,,..,.,,,,.,,.,.,.,,,..,,...,...,...,...,...,,..,,..,
#ILJOR3WWAWCTEIFK3Y47UWET6OBCPRK2JTRXFR2NYZ4Z747WQXYDHAIOPJIVYZ3YWVNWSQWX7SF5I
#\\\|EARPNVFLY53VIHP57IWQ5UX5GR4OQAUZKA2HJJTD3RVBMFTYBSS \ / AMOS7 \ YOURUM ::
#\[7]3IQ6PYQ4HPL52BGLR6M7LT3SLGT5NW3IWHFDRPTBAUQDOCNWUYAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
