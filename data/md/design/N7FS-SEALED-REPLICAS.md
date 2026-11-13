# N7FS : categories, incoming pool, sealed replicas, placement

status : design, nothing here is built. follows `N7FS-FORMAT-3.md` and builds
on the owner answers of 2026-10-22 in `FILES-ZENKA.md` [ questions 13, 14, 18 ].
this note adds only what those do not settle.

## goal

move everything essential off one host and keep it in sync across the host
group : a full desktop with its files restored from N7FS, later the laptops.
part of the group are machines owned by others. they hold data without being
able to read it, and no mount or content key ever exists on them.

## terms

- **home** : a host holding keys [ owned hardware ]
- **holder** : any host storing blobs. a **blind holder** has no key at all
- **blob** : what a blind holder stores, addressed by the checksum of its
  ciphertext
- **sealed map** : home's mapping from a local address to its blob

## 1. tree layer

assimilate today skips symlinks and keeps size and mtime only, and `get`
returns one file. a desktop needs more :

- a signed tree manifest : paths, symlinks, modes, owners, xattrs, empty
  directories, each regular file by address
- `n7fs restore <disk> <manifest> <target>`, verified, refuses to overwrite
- a filesystem that cannot express a field records that the field is absent,
  never a made-up value [ windows sources ]

## 2. categories

a category is a named policy, set per reference at assimilate
[ `-category <name>` or a path rule ] and changeable later. dedup can hold one
node in several categories : the node's effective policy is the strictest.

| field | values |
|---|---|
| local encryption | none \ cascade |
| target copies | number of durable copies, per failure domain |
| priority | number used when space runs out |
| replica | full bytes \ manifest only [ re-fetchable, source recorded ] |
| layer | private [ default, full price ] \ generic [ not user data, may be shared and deduplicated across owners, each stack separates the two ] |
| want-set | which holders must keep it [ laptops ] |
| foreign work | may a node key reach a host not owned : no [ default ] \ yes. a state-level attack on every hoster at once is assumed possible |

- **leaving owned hardware is always sealed.** a category can add protection
  there, never remove it. a holder not marked as owned refuses plaintext at
  the sender, fail closed
- changing target, priority, replica or want-set is free : a new signed record
- changing local encryption rewrites the node [ `C` is over the ciphertext for
  protected content ]. from plain to encrypted, the old plaintext is released
  and the tool says that bytes on ssd \ journaling media are not proven gone
- protected content keeps the 2026-10-22 rules : a random key, never
  deduplicated, plaintext id never stored
- each category has its own key [ section 4 ], so shredding a category is one
  step, the shape of question 18

## 3. incoming pool

an assimilate target that needs no classification, worked on in batches until
it is empty.

- `assimilate -incoming <paths>` stores into the built-in category `incoming`
- the existing guarantee holds : a source is removed only after its stored
  copy and the source verified again, and only with `-remove`
- `incoming` is treated as if important until someone says otherwise : sealed
  when leaving, a replica target, and counted in the status warnings
- `n7fs incoming [ list | tag | done ]` : browse by original path, apply a
  category to a batch, see what remains. tagging only moves a reference out
  of the pool

## 4. sealing

- **suite** : one suite, recorded in the format byte. twofish in ctr mode
  inside, chacha20-poly1305 outside, independent keys per layer and per node.
  the outer tag rejects tampering before any twofish work
- **no aes** : owner decision 2026-11-08, not offered as an option
- **nonces and counters, content** : derived from the chunk index, the
  final-chunk flag and the layer [ owner rule ] ; unique by construction
  only because the key is per node
- **twofish counter block** [ 128 bits, fixed widths ] : chunk index 56 bits,
  final flag 8 bits, block counter 64 bits, big-endian. the implementation is
  configured so the carry stays inside the low 64 bits, and a known-answer
  test across that rollover pins it
- **nonces under long-lived keys** : a chunk index means nothing here, and
  this is the class of the 2026-10-05 link-upgrade nonce reuse
  - a wrap : from the wrapped key's unique id + a re-wrap counter
  - the head : a monotonic version counter, journaled BEFORE use
  - random nonces are not used for either
  - a test fails if two wraps or two head versions share a nonce
- **key hierarchy** [ envelope ] : node key <- category key <- root key. wraps
  use the same suite. layers wrap keys, never content, so re-wrapping leaves
  blobs and `C` unchanged
- **key material comes straight from os entropy**, with a test that fails
  otherwise. the two layer keys of a node are two independent draws, no kdf
- **derivations** [ the head locator ] use BMW384, no sha-2 kdf
- **a host doing work on content receives node keys per fetch, never a
  category key or the map** [ the 2026-10-22 per-fetch rule ]. a compromise,
  hoster level included, then exposes the nodes it was given while
  compromised and nothing else
- **chunks** : large files split into fixed chunks. fixed chunks round a size
  up, they do not hide it
- **packs** : small files are sealed individually under their own node keys,
  then concatenated into pack blobs. this solves inode cost and keeps
  per-node shredding ; a released entry is dead space until a repack
- proposed size for chunks and packs : 16 MiB [ open ]

### shredding

deleting a node = destroying its wrapped key. the bytes become noise at once
and physical removal is lazy : garbage, no longer counted toward any target,
reclaimed by a home-signed delete when space is wanted. the exception is
someone who already took the unwrapped key.

a holder never could read the blob, so what a shred defends against is a
LATER theft of a parent key. and old sealed map versions still hold the old
wrap, on holders that ignored a delete and on media where overwrite proves
nothing. so the guarantee comes in three steps :

1. **drop the wrap** [ instant, per file ] : journaled, gone from the current
   map. holds against anyone who does not also have an old map + its keys
2. **rotate the category key** [ batched, cheap ] : a new category key, the
   surviving node keys re-wrapped, the old key destroyed. wraps only, no blob
   changes. a later theft of the category key opens nothing shredded before
3. **rotate the root key** [ rare, deliberate ] : also replaces the offline
   copies. needed against old heads retained by a holder + a later root theft

`n7fs status` names which step each shred has reached.

- a shred covers the sealed side only. a plain node at home is released there
  too, and plaintext on ssd \ journaling media is not proven gone. content
  that must be shreddable needs a category with local encryption
- a plain node shared by several references is shredded only when none is
  live. protected content is never shared
- wraps are symmetric : 256-bit symmetric wraps do not add the exposure of a
  public-key wrap to future key-breaking on data held by others for years.
  a C25519 wrap to a category public key stays possible later for one case :
  a device that may add files without being able to read old ones

### add-only writers

a host that produces data it may never read back [ logs on a remote ]. it
holds a category PUBLIC key only.

- each segment is sealed under a fresh node key, the node key wrapped to the
  category public key with an ephemeral C25519 key [ the wrap needs no nonce
  rule ]. the content suite stays the same
- the writer cannot open any closed segment, and has no delete authority
- honest limit : the host sees a line as it is made. add-only protects the
  past, not the present
- integrity : a public key lets anyone seal, so sealing proves nothing about
  who wrote. a hash chain alone [ the log chain of FILES-ZENKA ] does not help
  either : a compromised writer re-encrypts and rebuilds it for everything
  not yet seen outside its control. two measures close that window :
  - **anchors** : the chain position and checksum go out per segment and on a
    short timer, to at least one holder in a different CONTROL domain [ not
    only another failure domain : another admin path, home is best ]. the
    receiver timestamps them, so they cannot be backdated
  - **forward-secure ratchet** : each segment carries a mac under `k[i]`, then
    `k[i+1] = BMW384( k[i] )` and `k[i]` is erased. home alone keeps `k[0]`.
    an attacker arriving at step T holds `k[T]` and cannot forge any earlier
    segment, even one never anchored. the ratchet key lives in locked memory
    only [ overwrite on ssd proves nothing ], and a restart begins a new chain
    seeded from home
  - what remains : everything after T can be forged, the open segment is
    exposed, a tail back to the last anchor can be CUT [ seen as a gap against
    the anchors, not prevented ], and a hypervisor operator reads memory
    directly
- epoch keys : a new keypair per period. retention = destroying a period's
  private key, then nobody can read that period, its owner included
- these wraps are public-key, so the long-term exposure noted under shredding
  applies to them. acceptable for logs, not the default for other categories

### coercion

the aim : a demanded key does not help, and that is visible in advance, so
the attempt is less likely to be made.

- an operator of a blind holder or an add-only writer holds no key that opens
  anything. the design says so publicly
- a destroyed key [ shredding steps 2, 3 ; expired log epochs ] cannot be
  produced by anyone
- **provable beats deniable** : hidden volumes make a demand unable to end,
  since nothing can show that no more exists. this design relies on keys that
  verifiably do not exist or are not held by the person asked
- a single root that opens everything is the one thing worth demanding. so
  compartments [ open, decide before stage 4 ] : independent roots, each with
  its own map and head, none derived from another, and offline shares split
  k-of-n across places or people [ question 18's levels fit on top ]. the
  trade : more shares that can be lost, and the acceptance test must cover
  them. **first compartment landed 2026-11-13 [ review finding 6 ] :
  independent roots already existed ; disks and categories now bind to one
  root on first seal, and a receiver holder serves several roots, each only
  in its own `r-<tag>/` — see `N7FS-PLACEMENT.md`. the add-only writer
  [ below ] stays open**

### comparing parallel work

the same deterministic work on hosts in different control domains, compared.
a compromised host can then only pass by doing the real work and returning
the real result : for the output, a compromise is reduced to a theft of
resources.

- **commit before reveal** : each host first publishes a checksum over its
  result and a host-specific salt, and reveals only after all commitments are
  in. otherwise a host copies the honest answer without doing the work
- two hosts detect a difference, three settle which one is wrong
- **blob storage is the first user** : both holders of a blob answer a random
  challenge `BMW384( challenge : chunk )`. the bytes are identical, so home
  compares them without keeping the data, and answering needs the real bytes.
  this strengthens the spot-checks of safety rule 2. colluding holders can
  still share one copy, hence different control domains
- **logs compare only where two sides saw the same event** : a route or a
  transfer is recorded at both ends. purely local lines have no second witness
- full doubling costs twice the resources ; random audits of a fraction,
  unannounced, keep most of the deterrent
- limits : the work must be deterministic ; identical output says nothing of
  side effects outside the compared result [ exfiltration, abuse of the host's
  credentials ] ; a host working on plaintext has read that plaintext, so
  "theft of resources only" needs input that is sealed, public, or not
  sensitive

### plain nodes leaving home

locally a plain node is addressed by its plaintext `C`. a blind holder must
never see that : it could confirm possession of any known file. so the remote
copy gets a random key, and the sealed map gives `local C -> { blob, offset,
length, wrapped key }`. this is question 13's `plain_bmw` shape, for anything
leaving owned hardware [ owner confirmed 2026-11-08 ].

- dedup happens at home, before sealing, through the map
- **the map is as critical as the keys** : it is itself sealed, journaled and
  placed with the highest target
- two home hosts sealing the same content produce different blobs, so the map
  must be shared between home hosts or uploads duplicate. not designed here

### finding the map from nothing

blobs are opaque, so a clean machine needs a start point : a **head** blob at
a locator derived from the root key, holding the signed journal position and
the map's root. holders see one blob that changes.

- rollback : homes pin the newest head seen. a clean machine has no pin, so it
  takes the newest validly signed head of ALL reachable holders, and can only
  be as current as they are. this limit is stated in the restore output

## 5. holders and placement

- a holder has a role [ intake \ durable ], a quota, a reserve the store never
  touches, and a failure-domain label. hosts at one provider share a domain
- home signs a placement record per blob : blob id, size, target copies,
  priority number. no names, categories appear as numbers only
- holders move ciphertext among themselves from those records, in the
  background, without home being online

- when keys and map are held apart from the blobs, a node needs BOTH sides, so
  the loss risks add up. targets are set per side and the status reports the
  joint result. keys and map are tiny, so they get many holders, as k-of-n
  shares : more copies of a whole key would raise the theft risk, shares
  raise survival and theft resistance together

### safety rules

1. an intake copy counts as zero redundancy
2. intake evicts only after signed receipts from enough durable holders ;
   receipts are checked by random spot-checks from home. a receipt carries
   its coverage [ sizes-only \ sampled \ full ] and eviction relies only on
   full-coverage receipts : a sampled receipt never vouches for bytes
   another holder is about to lose [ review finding 4, addressed :
   N7FS-PLACEMENT.md ]. receipts are **incremental** since 2026-11-13 :
   each map entry records the head version that added it and a receipt
   carries a digest over the entries its version covers, so a commit that
   only added entries no longer voids what the receipt proved ; eviction
   relies on the covered entries of full-coverage receipts only, never on
   anything a partially covered or unreachable holder maps outside them
   [ review finding 3, addressed : N7FS-PLACEMENT.md ]
3. a holder never deletes on its own say. a delete is a home-signed record,
   so one compromised holder cannot wipe others through background sync
4. a blind holder cannot read the journal, so it cannot apply the tombstone
   rule. home drives deletion, and a holder ignoring a delete is what
   crypto-shredding covers
5. a holder verifies ciphertext checksums on its own [ scrubbing ], and holds
   no signing key of the store

### delete path status [ 2026-11-13, review finding 2 ]

deletes were plain `rm` with no grace, and gc kept only what one head
referenced : a second root added later on the same holder would have had its
blobs collected by the first root's gc. addressed since :

- gc has a grace age [ default 1 day ] and never `rm`s : it moves unreferenced
  blobs to `.trash/<YYYY-MM-DD>/` inside the holder dir ; restore and purge
  [ older than the receipt age ] complete it [ N7FS-PLACEMENT.md ]
- one holder subdirectory per root [ `r-<tag>/` ] : gc of one root never
  lists another's blobs ; `-only-root` is structural on the new layout, and
  `holder-migrate` moves a flat holder into it [ N7FS-SEALING.md ]
- **finding 2 is fully addressed** : an `ssh-receiver:` holder reaches
  `bin/n7fs-receive` through ssh `command=`, never a full shell. the request
  set is `list`, `has`, `get-range`, `put`, `put-head`, `put-list`, `move`,
  `migrate`, `purge-day`, `delete`, `free` and `scrub`. directories and sync
  are implicit in authorized writes ; paths and names are fixed-form, and no
  request follows a symlink
- a replacement, move or delete carries canonical JSON signed by the root's
  existing ed25519 key. the record contains the operation, full root id,
  holder id, exact paths or day, a strictly increasing counter and a random
  nonce. the authorized_keys line installs only the public keys and head
  names. home reserves counters under the root state ; the holder locks,
  checks and stores the last accepted counter per root, so an old or replayed
  record is refused
- new heads have a detached outer ed25519 signature over the clear version,
  writer and complete sealed head. the receiver verifies that signature, the
  signed request's byte digest and increasing version before replacement ;
  home still reads the older head form. no symmetric sealing key is needed
  on the holder

threat model : theft of the home ssh key now permits ciphertext listing,
reading, scrubbing and adding valid new blobs, plus filling the holder's
remaining quota. it cannot replace a head or relay list, move or migrate a
blob, purge trash or delete anything. those need the root signing key. a
malicious holder itself can still withhold or destroy its own files and roll
back its own counter storage ; signed requests do not make the holder honest,
and crypto-shredding remains the protection for ignored deletes. legacy
`ssh:` holders retain the old shell transport and warn on every write.

### when data does not fit

- reclaim first from blobs above their target, then the lowest priority
- never take a blob below its target to make room for lower priority
- what cannot be placed goes into an **under-replicated list** with the bytes
  missing. never dropped silently, always shown by `n7fs status`

laptops are holders with a small quota and a want-set. offline changes meeting
each other remain to be designed.

### map growth and retention [ 2026-11-13, review finding 5, decided ]

- **sharded map** : shards keyed by a base32 prefix of the address's bmw
  part [ `V7<epoch>/<amos>/<bmw>` : the header chars are constant, the
  entropy starts in `<bmw>` ; depth 1 = 2 chars = 1024 shards, a deeper
  level appends chars, no rename ], under a small sealed root listing each
  populated shard's checksum [ review R3 : the first key used the constant
  `V`, one shard ]. a commit uploads the changed shards and the root
  only ; `placement` \ `place` \ `drain` fetch the root and only the shards
  they need. the old single-map form is refused [ nothing live holds one ]
- **commit trigger** : 64 MiB or Y5 x 4 [ ~ 5 min ] sealed, whichever comes
  first, and always at the end of a run [ not every 1000 nodes ]
- **chunked manifests** : a tree manifest is split into content-addressed
  chunks per directory ; an unchanged directory reuses the previous tree's
  chunk, so a new snapshot costs only what changed. no delta chains : every
  tree drops on its own. the map keeps only each tree's index descriptor,
  the chunk list lives in the index alone [ review R6 ]
- **retention per tree prefix** [ built ] : rules and pins are kept in the
  sealed map root [ every holder sees the same ]. `retain-set`, `retain-show`,
  `retain-clear`, `tree-pin` and `tree-unpin` maintain them on every registered
  holder with this root's head. a hand-pinned tree always wins. `retain` reads
  the tree record's ntime `created`, computes the drops, then tree-drop ->
  prune -> gc [ trash + grace as before ] ; `-repack` compacts at the end
- **repack** [ built ] : a pack over 30 % dead bytes [ `-threshold` ] has its
  live sealed entries moved byte-for-byte into a new pack, without opening or
  resealing content. after the map commit, a fresh full-coverage receipt must
  cover the new pack before gc can move the old pack to trash. a failed check
  leaves the old pack live. runs in the same cycle as retain, before the
  snapshot job runs for long

#### time : ntime and Y levels, no unix \ base 60

all n7fs times are ntime [ stored, compared, shown ] ; a file mtime is
converted to ntime where it is read, the only unix input. durations use
**Y levels**, the ntime year [ 365 d ] divided by 13 [ YOURUM ] per level :

| level | length | ~ base 60 |
|---|---|---|
| Y0 | year | 365 d |
| Y1 | year / 13 = one epoch | 28.08 d |
| Y2 | year / 169 | 2.16 d |
| Y3 | year / 2197 | 3.99 h |
| Y4 | year / 28561 | 18.4 min |
| Y5 | year / 371293 | 85 s |

ages read `<n>Y<level>` [ `-grace 6Y3` ~ 1 d, `-unreachable-grace 1Y2` ~ 2.2 d,
receipt age `3Y2` ~ 6.5 d ] ; the old `s m h d w` forms are still accepted with
a warning. thirteen of a level span one of the level above, so a retention rule
is a ladder on the ntime grid [ not local midnight ] :

    snap/ : 13 Y4  13 Y3  13 Y2  13 Y1

keeps the newest tree of every Y4 for one Y3, of every Y3 for one Y2, and so on
up to one year. the snapshot job runs every Y4 [ the prefix is `snap/`, not
`hourly/` ].

## 6. acceptance

recovery counts as working only after this : on a clean machine, with only the
offline key copy and ONE holder, restore a tree and verify it. offline key
copies exist in two places before the first upload.

attack on scratch disks at each stage, as for format 3 : crash points during
seal \ upload \ eviction, a holder serving old or wrong blobs, forged receipts,
nonce uniqueness across resumed uploads.

## 7. stages

1. tree layer and categories
2. incoming pool
3. union sync between two local disks [ honors a tombstone only when the
   journal lists its release ]
4. sealing, the map, head, one durable holder over ssh, the acceptance test
5. placement, receipts, under-replicated list
6. intake holders and background relays
7. native signer and n7fs zenka [ todo 6RH ] driving sync
8. laptops : want-sets, offline change merge

stage 4 is the first that gets essential data off the host.

## open

- compartments and k-of-n root shares : one root or several [ before stage 4 ]
- add-only writers : which stage, after sealing and one holder work
- long horizon, kept possible by placement : a "copy" stays abstract so it can
  later be a share ; key and map holders disjoint from blob holders, in other
  control domains ; data always moving, which needs each move to change the
  bits [ share refresh ], otherwise a move only makes more copies
- calculated placement [ stage 5 starts with integer targets, then grows into
  this ] : a category states a durability and an availability goal instead of
  a copy count. home computes copies \ shares from measured holder reliability,
  correlation by domain, capacity and transfer cost, spending the next byte
  where priority x survival gained is highest. integer floors stay as hard
  limits the calculation cannot go below [ at least two control domains, one
  of them owned ], with hysteresis so estimates do not cause constant moves
- derived placement, the lambda principle applied to holders [ "route identity
  = relationship identity", derived, not stored -- see
  `data/ai-mem/claude/topic-checksum-addressing.md`,
  `topic-checksum-parenting-namespace-trees.md` ] : a blob address joined with
  a holder key gives a weight every party computes alike ; a blob goes to the
  holders of highest weight [ rendezvous \ highest-random-weight hashing ]. no
  registry is needed to know who should hold a blob, a joining or leaving
  holder moves only its own share, and capacity or a long reliable history
  [ the purr channel's overtones, `SPATIAL-AUDIO-AND-PURR-CHANNEL.md` ] enter
  as weights. this is an implicit form of discovery : knowing the holder keys
  is enough to find any blob. per base32 prefix level the same calculation
  picks a node field, then a holder inside it, as deep as the namespace grows
  [ the map shards' prefix `depth` is the first instance ]. integer floors
  and control domains stay hard limits on top. a position derived from a
  public key is claimed by a signature over a challenge : nobody without the
  matching private key can take it, everyone who honestly holds one can prove
  it, no authority grants it. caveat, key grinding : anyone can make keys
  until one lands next to a chosen position. against it : an ntime epoch
  joins the weight [ address + holder key + epoch ], so a ground key is
  worthless at the next epoch change ; three epochs are valid at any time
  [ previous, current, next -- the rolling "3 valid" epoch index ], so
  reindexing spreads evenly over time instead of a cliff at each change,
  and happens as part of travel : a blob that moves or is checked anyway
  is placed and validated for the current epoch on the way ; a new key's weight grows with proven,
  checked holding time [ history is not cheap, keys are ] ; the floors keep
  every blob across several control domains whatever the keys. the same
  holds for a content address [ or size plus checksum : a second, free
  constraint, a wrong blob is refused before any hashing ] : whoever has the
  bytes proves it, no authority needed. content can be ground as well [ a few
  varied bytes reach a chosen short prefix, e.g. to load one node field ],
  so the address stays the IDENTITY while the placement weight also joins
  holder key and epoch : grinding content controls its name, never where
  it lands
  [ implicit anchors -- the empty-string parent, ntime as a fuzzy address
  followed while it matches : `data/ai-mem/claude/topic-checksum-parenting-namespace-trees.md` ]
- home as the first instance of the home zenki ring : today one host holds
  the root, decides placement and collects receipts, the only party that can
  anchor identity. at scale home becomes a ring of rotating home zenki [ the
  dancing zenki formation : two at rest, three during a handover ] that keeps
  presence like a radar : one or two rotating points cover the ring because
  the afterglow outlasts a turn -- in n7fs terms a receipt is that afterglow,
  valid until the next pass [ 3Y2 ]. open : the ring's handover state machine,
  shared with `data/tasks/design-open-questions-2026-10-02.md` question 4, so
  home moves without losing the anchor [ heads, peers, offline anchor of
  findings 7 and 10 ]
- erasure coding as the form of a "copy" : k-of-n fragments over sealed chunks.
  a placement rule : at most n-k fragments of a stripe per control domain.
  fragments differ between holders, so the two-holder challenge of identical
  bytes does not apply : needs per-fragment challenge tokens prepared at seal
  time, or sampled recomputation. repair and every read need k holders online
- distribution as a protection layer : holds for secret sharing, and for slices
  of sealed data when the mapping is itself distributed and dynamic. holding
  slices is then not being able to serialize them : the mapping acts as a key
  as large as the slice count. it must survive like a key [ k-of-n ], be
  checkable only keyed or over the whole, since a checksum open per partial
  order is a solving oracle, and slices must change form when they move, or
  traffic links them. on unsealed data slices reassemble statistically, so the
  sealing stays under it. n-of-n across groups, each group replicated inside one
  control domain : one uncompromised group keeps the rest at zero information,
  one failed host does not lose the share. refresh deltas sum to zero
- layout modes beside `complete` [ segment of a parent, catalog of subdisks ],
  catalog nesting and reduced branch counts, 5 of 7 with alternates, trickle
  checks over the whole range, movement as proof, disjoint data and validation
  planes, relative tags, booked time cells, threshold opened neighbours : see
  `data/ai-mem/claude/vision-2026-11-09-n7fs-mapping-features-from-layout-thread.md`
  and the dancing zenki formation [ `DANCING-ZENKI-RHIZOME-STATE.md` ] first
- the default chunk layout [ 16 MiB now, header 0 ] : settle before the first
  real upload
- wire form between holders [ plain ssh first, cube routes later ]
- does a holder know a blob's priority at all, or does only home decide and
  send explicit move orders

#,,,,,,.,,,..,,..,.,,,,.,,.,,,,,.,,.,,...,,,.,..,,...,...,.,,,,,.,,..,.,.,,,,,
#CO5BV635SVC7IQM6ADHB57OXQUXEAVC5NLPADSFFZIYGPEUT2LLUYT2GR26GYFMW6C5VXV3OGIWX4
#\\\|LSW5EZN5XW74AIRDAIIPN6Y4UX56RNFY6ROQGHPSBUDXF7Z337S \ / AMOS7 \ YOURUM ::
#\[7]CLCSGKDAEA2LNJZI7MK3SWBG5R6TDVJW23ROFZ2T5YKEPDSEUGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
