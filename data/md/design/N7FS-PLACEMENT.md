# N7FS stage 5 : placement, receipts, under-replicated list

2026-11-10. follows `N7FS-SEALED-REPLICAS.md` section 5 and `N7FS-SEALING.md`.
this note fixes the first, integer-target part. calculated placement, erasure
coding and holder-to-holder relays stay later.

## what exists

- `seal` writes one root's nodes to one holder, `holder-check` samples one
  holder, `seal-recover` reads one holder
- categories carry `copies`, `priority`, `want` and `foreign-work`, stored
  but not acted on
- nothing knows how many holders keep a node

## holders

a holder is registered on the home host, never in the repo, because entries
name real hosts :

```
n7fs holder add <name> <spec> -role durable|intake -domain <label>
    [ -owned ] [ -quota <size> ] [ -reserve <size> ]
n7fs holder list
n7fs holder remove <name>
```

- stored as one signed record per change under `<host-dir>/holders/`, signed
  by the host key, latest wins, history kept
- `domain` is a failure domain label. hosts at one provider share one, and
  an owned machine has its own
- `-owned` marks hardware the owner controls. it is the only thing that
  allows a category with `foreign-work no` to send node keys there later ;
  sealed blobs may go anywhere
- `quota` caps what n7fs places there, `reserve` is space it never touches

## what counts as a copy

a node counts on a holder only when that holder's current head maps it, its
blob exists with the right size, and a receipt for that holder is fresh :

- **receipt** : the result of a `holder-check`, signed by the host key, with
  time, holder, head version, blob count and sampled chunks. fresh means
  younger than a set age [ default 7 days ]
- an intake holder counts zero, as the design's safety rule 1 says
- several holders in one failure domain count as one copy toward the target

## commands

```
n7fs placement <disk> -root-key <key>        report only
n7fs place <disk> -root-key <key> [ -dry-run ]  seal what is missing
```

`placement` opens every registered holder's head and map with the root, joins
them with the disk's categories and prints, per category : target copies,
nodes and bytes at each count, and the under-replicated list with the bytes
missing. it never changes anything. `status` shows the under-replicated total.

`place` seals each under-replicated node to holders chosen in this order :
a domain not yet holding it, then owned before foreign, then most free quota.
it never goes below another node's target to make room, and what cannot be
placed stays listed. it uses packs and the existing commit rules.

## draining and moving [ stage 5 part 2, first part ]

`holder-drain <disk> <name>` removes from one holder's map every node whose
counted copies in other failure domains still meet its target without it, in
one commit, together with every tree that named a removed node. nothing that
would fall below its target is touched ; the rest is reported as kept. a copy
counts only with a fresh receipt, so a holder that was just filled does not
yet allow a drain. bytes stay until `holder-gc`.

each map entry carries the ids of the disks it was sealed from [ `disks` ;
seal adds the id when a node is already mapped from another disk, relay
copies the set and merges it into an entry the target already holds ]. a drain
looks only at nodes of the named disk : a node that other disks still name
loses this disk's id and stays mapped, an entry with no disk ids [ maps from
before disk ids ] counts as the disk's only while it is live there, otherwise
it is kept and reported. a wrong disk argument so leaves the holder as it was.

`holder-prune <holder> -root-key <key> [ -dry-run ]` is the explicit cleanup
for orphaned map entries. it reads every disk attached on this host under the
disk root and drops an entry only when none lists it as live and its disk ids
are all confirmed stale. an entry without disk ids may belong to a detached
disk or to another host's disk : it goes only with `-legacy`. an entry tagged for a detached disk stays,
because that disk's live set cannot be checked. the dry run prints every
address it would drop. pruning uses the same map commit and holder-writer lock
as draining ; bytes stay until `holder-gc`.

`place -exclude <name>` and `placement -exclude <name>` read that holder but
do not count it, so a move is :

```
holder add <new> ... ; place -exclude <old> ; holder-check <new>
holder-drain <old> ; holder-gc <old> [-only-root] -delete
```

## trash, grace and the per-root layout [ 2026-11-13, review finding 2 ]

`holder-gc` never deletes and never touches a blob younger than a grace age
[ default 1 day, `-grace <age>`, the holder-side mtime in one batched
listing ]. with `-delete` it moves each old unreferenced blob to
`.trash/<YYYY-MM-DD>/<name>` inside the holder directory, local and ssh alike.
`holder-trash-restore` moves blobs back [ by name or `-all-since <date>` ],
`holder-trash-purge` removes trash day dirs older than the receipt age
[ `-older <age>`, dry run unless `-delete` ]. a blob present only in trash
counts as missing everywhere : placement reads maps, holder-check and scrub
never look into `.trash/`.

a holder in the new layout keeps each root's head, map, journal and blobs in
`<holder>/r-<tag>/` [ seven characters of the root id ]. gc then lists only
that root's subdirectory : `-only-root` is structural and redundant there,
while the old flat layout keeps requiring it. `holder-migrate` moves a flat
holder into the layout, rename-only, idempotent, resumable, dry run by
default ; detection is by existence [ subdirectory present, no flat head ].
gc, purge, restore and migrate take the same host lock as every
holder-writing command.

**finding 2 is fully addressed**. an `ssh-receiver:` registration uses only
`bin/n7fs-receive` through ssh `command=`. gc and restore carry root-signed
`move` records ; flat migration uses the narrower signed `migrate` request ;
purge and direct deletion require signed `purge-day` and `delete` records.
records bind root, holder, exact arguments, counter and nonce, and holder-side
last-counter storage refuses replay. heads and relay lists are replaceable
only with signatures. `N7FS-SEALING.md` specifies the complete request set,
outer head signature, migration steps and stolen-key threat model.

## not in this part

moving between holders, eviction from intake, holder-to-holder copying,
calculated placement, erasure coding.

## as built [ 2026-11-10 ]

- the registry is the vault note `n7fs holders`, json, one entry per holder
  with spec, role, domain, owned, quota and reserve. the vault keeps earlier
  versions. one vault unlock per command serves the root and the registry
- `holder-check` writes a receipt to `<host-dir>/receipts/`, named by a
  checksum of the holder, signed by the host key. it counts for 7 days and
  only for the same root
- `placement` opens each holder's head and map with the root. a holder
  counts when it is durable, reachable, has a head and a fresh receipt ;
  copies count once per failure domain. it updates a holder's pin as any
  read does, and changes nothing else
- `place` plans per node : domains not yet holding it, owned holders first,
  then most quota left, never past a quota. it seals each holder's share
  with packs, and a holder that receives any file of a tree also receives
  that tree, so it can recover it by name. it ends with a `holder-check` of
  every holder it wrote, so new copies count at once [ `-no-check` defers
  that to a later `holder-check` ]
- `reserve` is enforced : `place` reads free space with one `df` on the
  holder and never fills past the reserve ; unknown free space places
  nothing there. the size of a node is its local content size, not its
  sealed size
- `-bwlimit <size>` caps uploads to ssh holders per second, for links that
  fail under sustained load

## holder filters [ 2026-11-11 ]

```
holder add <name> <spec> ... [ -categories <a,b> ] [ -min-priority <n> ]
```

`place` puts a node on a holder only when one of the node's categories is in
the holder's list [ when it has one ] and its priority is at least the
holder's lowest. a holder without either takes every category. for small
off-site holders that should carry only what matters most, while the large
ones take everything. what the filters exclude stays in the under-replicated
list, never dropped. `holder list` shows them.

## receipts bind a head version [ 2026-11-11 ]

a receipt counts only while the holder's head is the version it checked, so
copies committed after it [ place, relay ] wait for the next `holder-check`,
as described above. relays and intake draining : `N7FS-INTAKE.md`.

## incremental receipts, place-then-check, unreachable grace
## [ 2026-11-13, review finding 3 ]

review finding 3 : the version rule above voided a receipt for ALL of a
holder's nodes after ANY commit -- an hourly `place` committing to holder A
left every node on A uncounted until the next `holder-check`, and one
unreachable run did the same. addressed since :

- every map entry carries the head version that **added** it [ `added`,
  stamped in `seal` and `relay` when the entry is created ; old entries
  without the field read as 0 ]. a receipt for version V vouches for every
  entry with `added <= V`, as long as the covered part **only grew** since
  the receipt : no covered entry removed or changed [ blob, offset, length,
  chunks, pack ].
- "only grew" is proved cheaply : the receipt stores a **covered digest**
  over the sorted covered entries' placement fields, and the reader
  recomputes that digest over the current map's entries with `added <= V`.
  an equal digest proves the covered part unchanged ; a changed or dropped
  covered entry voids the receipt for the whole holder, and entries added
  after V stay **pending** [ mapped but never counted, never proven ] until
  a newer receipt covers them.
- **coverage applies to the covered part only** : a `full` receipt for V
  proves exactly the covered entries. `place` planning counts any fresh
  receipt's covered entries ; `holder-drain` relies only on covered entries
  proven by `full`-coverage receipts and never on anything a partially
  covered or unreachable holder maps outside its covered set.
- receipts written before the digest keep the exact-version rule, so old
  receipts verify unchanged.
- `place` ends with a `holder-check` of **every holder it wrote to** in that
  run [ sampled by default ; `-check-full` authenticates every chunk,
  `-no-check` skips, leaving the new copies pending for a later
  `holder-check` ]. a failing check is reported and makes `place` exit
  non-zero, never undoing the placement.
- an **unreachable holder** with a fresh receipt keeps counting its covered
  entries in place planning for an **unreachable grace** [ default 2 days,
  `-unreachable-grace <age>` on `place` and `placement` ] : no re-placement
  elsewhere during that time, reported as `unreachable, counted
  [ receipt <age> ]`. the covered addresses come from a cache written beside
  the receipt, bound to it by the digest. it **never** counts for drain, and
  after the grace it counts zero again.
- the reports state per holder : receipt version, covered nodes, pending
  nodes and coverage.

**finding 3 is addressed** : a commit no longer voids what it did not
touch, `place` leaves a fresh receipt on every holder it wrote, and an
unreachable holder keeps counting its proven covered entries for a bounded
grace instead of silently dropping to zero.

## receipt coverage and keyless scrub [ 2026-11-13, review finding 4 ]

review finding 4 : `holder-check` verified all blob sizes but authenticated
only 16 random nodes — one chunk each, uniform by node — and the receipt it
wrote then vouched for everything for 7 days ; drain and gc relied on it.
a zero-filled or bit-rotted pack of the right size was missed with high
probability [ at 24k nodes, 1 % damage was found in ~15 % of checks ].

what changed :

- every receipt now carries a **coverage** field : `sizes-only`,
  `sampled` or `full`. `holder-check` writes `sampled` by default and
  gains `-full` [ authenticate every chunk, slow ], `-scrub` and
  `-sizes-only`. receipts written before the field read as `sampled`.
- sampling draws chunk positions **by bytes**, weighted by node length, so
  a large pack is sampled proportionally more often than a small one.
- **keyless scrub** : a blob's name is the checksum of its own ciphertext,
  so a holder verifies every byte it keeps without any key. the restricted
  receiver answers `n7fs-receive <dir> scrub [ -nonce <b32> ] [ <name> .. ]`
  read-only, streamed ; `n7fs holder-scrub <holder> -root-key <key>` names
  the mapped blobs from the holder's own map and reports bad and missing.
  with `-nonce` the digest runs over nonce-bytes + blob-bytes, so home
  compares two holders' answers to one challenge without reading the
  blobs. a passing scrub plus the size check is `full` coverage of
  ciphertext integrity — it says nothing about the map's key material,
  which only the chunked checks authenticate. the head is never named by
  its checksum : a list-less scrub reports it as bad by design.
- `holder-drain` [ and the gc that follows it ] relies **only** on copies
  proven by `full`-coverage receipts. `place` planning still counts
  `sampled` receipts. reports state the coverage : the placement report
  shows `counted [ sampled receipt ]`, drain reports
  `kept N nodes : copies elsewhere hold only a sampled receipt`.
- a remote publish syncs the directory after the rename, so the new blob
  name survives a crash [ local publish too ].

## a service root for the unattended hourly job [ 2026-11-13, review finding 6 ]

review finding 6 : `place`, `relay -adopt` and `holder-check` all need the
root. an hourly timer means the vault passphrase and the full-shell ssh key
sit usable on an online machine around the clock — and the root opens
EVERYTHING.

what already existed : independent sealing roots need no new command —
`n7fs root init <file>` [ or `vault:<name>` ] creates a fully independent
root [ its own 96 bytes of entropy, its own root id, map and head ], and a
passphrase file root needs only its own passphrase, never the main vault
passphrase. the per-root holder layout [ finding 2 ] already keeps each
root's blobs in its own `r-<tag>/`, and `bin/n7fs-receive` already accepts
repeated `-root-pub` \ `-head-name` pairs. the gaps were binding and the
multi-root receiver line :

- **disk seal binding** : the first `seal` of a disk writes
  `<disk>/.n7fs/seal-root` — canonical JSON `{ v, disk, root_id, pub, sig }`
  where the signature is the sealing root's ed25519 signature over
  `disk \0 root_id`. every later `seal`, `place` [ same code path ] and
  tree `unseal` of that disk refuses any other root
  [ `disk is sealed under another root [ tag .. ]` ], and a binding that
  does not verify is refused outright. disks sealed before this change
  bind at their next seal. the binding is self-certifying : it guards
  against MISTAKES [ the wrong root key on a command line ], not against
  someone who can write the disk -- deleting `seal-root` lets the next
  seal bind afresh. the security boundary is the crypto on the holders
  and the plaintext itself : keep the main root's disks off the online
  machine, then its key has nothing of theirs to seal or read.
- **category binding** : `n7fs category <disk> set <name> -seal-root
  <root-id>` binds a category to one root ; `seal` \ `place` refuse the
  category under any other root. within a disk already bound to one root
  this is the finer scoping ; across roots it makes the refusal explicit
  per category.
- **multi-root receiver line** : `n7fs holder-receiver-line <holder>
  -root-key <key> [ -also-root-key <key> ]..` prints one
  `-root-pub`/`-head-name` pair per distinct root [ one passphrase line per
  root, in listing order ] ; the receiver keeps serving each root only in
  its own `r-<tag>/` — a signed request from one root naming another
  root's tag is refused [ `request path belongs to another root` ].

setup for the hourly job :

1. `n7fs root init /path/service.root` — its own passphrase, 0600, kept
   out of the main vault ; the main root's secrets are never involved.
   seal the service disks under it once by hand [ that writes the disk
   bindings and the categories ].
2. the holder's authorized_keys line comes from `holder-receiver-line`
   with `-root-key vault:main -also-root-key /path/service.root` — ONE
   forced command serving both roots, each boxed in its own `r-<tag>/`.
3. the timer [ systemd unit or cron ] runs only
   `n7fs place <service-disk> -root-key /path/service.root`,
   `n7fs relay <a> <b> -root-key /path/service.root -adopt` and
   `n7fs holder-check <holder> -root-key /path/service.root`, with
   `-pass-fd` reading the service passphrase from a 0600 file or an
   askpass helper — never argv.

what the job can and cannot do : with only the service root it can seal,
place, relay [ adopt ] and holder-check the service root's own disks,
categories and holders. it cannot read, seal, place, relay, check, shred
or unmap the main root's data — the disk \ category bindings refuse the
attempts at home, and on holders the main root's head has another locator,
another root id and another `r-<tag>/`, which the receiver enforces on
every signed request. `unseal` \ `seal-recover` of a node address without
a disk read are refused by the crypto itself [ wrong head locator, wrong
root id, wrap domains ].

threat model : a compromised online machine exposes the service root only.
the service root's passphrase file opens the service root's data — one
compartment, not the vault ; the main vault passphrase and root never sit
on that machine. on the holder the forced command boxes the service key
into the service `r-<tag>/` : it can add valid blobs [ bounded by quota ]
and sign changes only inside its own subdirectory, never touch the main
root's head, blobs or trash. the honest limit stays : the compromise of
the machine that holds a root defeats anything that root could do anyway,
so the main root simply is not kept there.

**finding 6 is addressed**. the longer-term **add-only writer** — the hub
seals to a category public key and home never pulls plaintext — stays open
[ `N7FS-SEALED-REPLICAS.md` ].

## owner decisions [ 2026-11-10 ]

1. the holder registry lives in the vault, as a note entry titled
   `n7fs holders`, so it survives a total loss together with the root
2. a receipt counts for 7 days ; lower later with better connectivity
3. targets stay `default` 1 and `incoming` 2 for now, likely higher once the
   laptops join
4. rented servers can sit at more than one provider and region. a provider
   is one control domain, a region its own failure domain. which hosts are
   where stays in the vault registry, never in this repository

#,,,.,,,,,,..,,,.,,.,,.,,,,.,,.,.,,.,,,,.,..,,..,,...,...,,..,,.,,.,.,..,,.,.,
#LYMQUBCQ2INTOG2ZJGJE4UKYBGI2NWG43RXYPSDR6EQ2O4NZ4DSBBXJDKUQNZZFPBV5DNBBALN3VQ
#\\\|L2ITEO6JDILO5AEWQ4KUBNE7OBUQR72X2DBL662SRT3Z445SXY4 \ / AMOS7 \ YOURUM ::
#\[7]GBXZKB6V6K7YNLPHYDW5VHBMCKUE2RDF22V2GTJFHHQEDQAQ42CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
