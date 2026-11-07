# N7FS format 3 : stages 1 and 2 as built

2026-11-07. the signed journal, references, reference drops, crash repair,
conversion 2 -> 3, release, reclaim, permanent tombstones and early epoch
release implement [ `N7FS-REFERENCES-RELEASE.md` ]. format 1 and 2 readers keep
their existing behavior and warnings. paths, content addressing, immutable
writes, mount records and the epoch conversion window are unchanged.

hard-linked conversion, `-prune`, journal checkpoints and crypto-shredding are
not included. release removes the live node ; it does not prove its old bytes
unrecoverable on copy-on-write or journaling filesystems, in backups or in other
copies. every release and reclaim command says so.

## records

new disks from `init` have `store_format: 3`. state and meta use record format 3
and their existing `:0001` labels. the new kinds are :

| kind      | magic  | record format | label                         | signer   |
|-----------|--------|---------------|-------------------------------|----------|
| state     | `P7FT` | 3             | `p7 n7fs state:0001`          | store key |
| meta      | `P7FN` | 3             | `p7 n7fs meta:0001`           | store key |
| journal   | `P7FJ` | 3             | `p7 n7fs journal:0001`        | store key |
| reference | `P7FR` | 3             | `p7 n7fs reference:0001`      | store key |
| drop      | `P7FD` | 3             | `p7 n7fs reference drop:0001` | store key |
| tombstone | `P7FX` | 3             | `p7 n7fs tombstone:0001`      | store key |

id, mount and use records retain their format-1 containers. a format 3 record
cannot validate as another kind or as format 1 or 2 : magic, format byte and
label are all checked. every signature is verified only against `store_pub`
from the parent-signed id. a valid signature from any other key is refused.
readers need no store secret ; every write loads and checks the delegated store
key before changing anything.

## journal

entries are immutable files at `.n7fs/journal/<ntime14>.journal`. the payload is
:

```
{ seq, prev, disk,
  add  : { nodes, meta, references },
  drop : { nodes, meta, references, releases }
  [, baseline : true ] [, repaired : true ] }
```

- `seq` starts at 1 and is contiguous. `prev` is the base32 BMW384 of the exact
  bytes of the previous entry, and is empty at sequence 1.
- node entries are canonical `<epoch>/<amos>/<bmw>` strings. meta entries are
  `{ node, name }`, where `name` is the actual `<ntime14>.<tail8>.meta` file.
- reference entries are `{ node, path, holder, name }`. `path` is the
  node-relative `<ntime14>/<amos>/<bmw>/addr` path.
- `drop.releases` contains canonical node addresses. a release removes that
  node and its current meta and references from the expected set while replay
  retains their authenticated history and marks that generation `released`.
  releasing an unlisted node refuses, including in `journal_write`'s pre-sign
  check. a later content import may add the same address and new meta and
  references without tripping duplicate-add rules.

replay authenticates every entry, checks its disk binding, contiguous sequence,
previous-entry hash and operation semantics, and requires exactly one successor
per entry. a duplicate sequence or successor is a fork and refuses loudly.
file order must agree with sequence order. a reference drop in the journal must
name a known live reference.

one assimilate batch writes one entry after its new nodes and meta have been
published and verified. the entry contains only successful changes : new nodes,
new meta names and new references. an empty or wholly unchanged batch writes no
entry. a source removed with `-remove` is unlinked only after the journal entry
exists. a crash after publish but before the entry leaves unjournaled data ;
`verify` never calls it good.

a reference drop writes the `drop` file first and then one journal entry. it
removes neither content nor meta. a drop of an unknown or non-live reference
refuses before writing.

writers take an exclusive lock on `.n7fs/lock` [ flock, released with the
process ] : assimilate, drop, release, reclaim, release-epoch, repair, upgrade
and confirm run one at a time per disk and wait for each other. `verify`, `find`
and all `get` paths wait on a shared lock, so they never see an import half
journaled. a writer refuses an entry replay would refuse before signing it, and
an import onto an unjournaled node refuses and names `repair`. reclaim dry-run
takes no lock and creates no lock file.

## references and drops

each reference lives below its target node :

```
<epoch>/<amos>/<bmw>/references/<ntime-dec>/<amos>/<bmw>/addr
<epoch>/<amos>/<bmw>/references/<ntime-dec>/<amos>/<bmw>/drop
```

the signed `addr` payload is `{ disk, addr, holder, name, ntime
[, converted : true ] }`. `addr` is the canonical target address, `ntime` is the
reference creation time, and the path's ntime, amos and bmw must equal the
record. `holder` is free text vouched for by the store key. assimilation uses
the absolute source path as holder and the source basename as name. moving a
record to another target, disk or ntime refuses.

the optional `drop` file beside `addr` uses the same binding fields and is
signed with the distinct drop label. live means an `addr` with no `drop` ; this
state is never duplicated in another file. dropping and later importing the
same source creates a new reference with a new ntime. an unchanged import with
a live reference creates nothing.

`find` shows live references by default, joined to their newest matching meta
record. `-all` includes meta history, dropped references and released history,
appending `dropped`, `released` and, for converted references, `converted` in
the bracketed stamp. columns remain `<address> <size> <format>
<source-or-name>`. after physical release the journal supplies the historical
reference and a released meta row with unknown size and format.

`get` by name uses live references in format 3. a dropped-only name fails with
a message saying it was dropped. `get -all` includes dropped history but never
resolves released content. get by exact address remains available for dropped
content ; a released address fails clearly and says to import the same content
to revive it. both successful paths verify the selected content and all its
signed meta before output.

## release, reclaim and tombstones

`release <disk> <addr> [ -force ] [ -reason <text> ]` accepts only a canonical
address in an active epoch. live references refuse and are listed ; `-force`
warns and names each broken holder. `reclaim <disk> [ -free <size> ] [ -older
<age> ] [ -dry-run ]` selects only nodes without a live reference, oldest import
first. `-free` stops after the requested content-byte total, `-older` filters by
age, and there is no daemon or default maximum age. sizes accept K/M/G/T suffixes
and ages s/m/h/d/w suffixes. dry-run creates and changes nothing.

each operation writes an immutable signed tombstone at
`.n7fs/tombstones/<ntime14>.<amos>.<bmw>.tombstone`, payload `{ disk, addr,
ntime, reason }`, then a `drop.releases` journal entry, renames the node to
`.n7fs/releasing/<addr>` and removes that tree. tombstones are permanent and
outside the node directory, and `verify` fails loudly if a journaled release has
lost its tombstone. a crash before the journal entry leaves a tombstone with no
release : it has no effect, a retried release finishes the job, and a later
union sync must honor a tombstone only when the journal lists its release. an
empty reason becomes the default reason. after a conversion the previous form
keeps its own copy of the bytes until it leaves the window : release warns and
names that copy and `release-epoch`. importing the same bytes is the only general
revival : new meta and references are forced past the tombstone ntime. an
address by itself cannot revive content.

`release-epoch <disk> <epoch> -now` removes a confirmed conversion's previous
epoch before it leaves the window, records a state without `previous`, and says
rollback to that form has ended. missing `-now`, an unconfirmed conversion, an
epoch outside the previous form and an active epoch refuse.

## verification and repair

`verify` replays the journal, verifies every content node, signed meta and
permanent tombstone, reads every reference and drop, and compares the replayed
set with the active epochs.
a missing node, meta, reference or required drop is a loud failure naming it.
an unlisted node, meta, reference or drop is also a loud failure. in particular,
an unjournaled publish is reported as crash-or-injection data, not as a valid
extra file. a released node still in its active directory is loud until repair
finishes its rename and removal ; the releasing-aside tree is never good content,
so a stale aside is removed rather than blocking a later release of that address.
repair does not recreate a lost tombstone : restore it from a copy.

`n7fs repair <disk>` requires attach and the store key. it first finishes any
journaled release left between journal, rename and removal. otherwise it
verifies every candidate and refuses any missing expected item or foreign
signature. it then
writes one `repaired : true` entry adopting all verified unjournaled nodes,
meta, references and drops. the command prints every adopted item ; nothing is
silently adopted. a store-signed but unlisted node is still adopted only by
this explicit command and is reported like any other item. if a conversion
crashed after its state switch but before sequence 1, repair marks that first
entry both `baseline : true` and `repaired : true`.

## read cost

there are no journal checkpoints.

- `verify` : read and authenticate the whole journal and tombstones, scan all
  active meta and reference records, and hash every active content node. cost
  is O(journal + tombstones + records + content bytes).
- `find` and `get` by name : replay the whole journal and scan active meta and
  references, but do not hash every node. get then hashes only the selected
  node. cost is O(journal + records), plus the selected content for get.
- `get` by exact address : authenticate only the first and last journal records
  and compare the last sequence with the host witness, then verify the selected
  node and meta as before. an absent address replays the chain to distinguish a
  release from damage. full `verify` remains the operation that detects a fork,
  reorder or bad middle entry.
- `status`, attach and detach use the same cheap journal-head check as a present
  get by address. assimilation, drop, release, reclaim and repair replay the
  chain before writing.

## truncation witness

the host-signed use record adds `journal_seq`, the highest journal sequence
seen per disk, beside the highest format. a presented lower sequence refuses
unless `-allow-rollback` is given. an older witness without the field means
sequence 0, so it does not reject a newer valid journal.

assimilation, drop, release, reclaim and repair append the observation after
their journal entry.
conversion appends it after the signed state switch and baseline entry. attach
and detach carry the highest sequence forward after checking the journal head.
a host-side failure while appending the observation is not rolled back ; a
newer journal is valid and a later mount raises the witness.

a first-contact host, a host without its witness, or a host unable to
authenticate that witness cannot detect a coherent truncation to an older valid
chain. this is the same local-witness limit as the format pin, not a
network-wide currency proof.

## conversion 2 -> 3

the production codec is installed with `register_codec`, and the 2 -> 3
transform with `register_step`. chains from 1 -> 2 -> 3 work through the
existing `upgrade` and `confirm` operations. content is copied into the next
epoch, never hard-linked. `release-epoch` can remove the confirmed previous
form early, after which a pending upgrade no longer refuses the window.

after the new epoch verifies, each distinct existing source receives a live
reference marked `converted : true`. the signed state switches, then sequence 1
is written with `baseline : true`, listing every converted node, every meta
name and every converted reference. the witness is updated last. confirmation
runs complete journal-and-disk verification.

**baseline limit** : deletion before this first baseline is undetectable. the
baseline authenticates what was found at conversion, not what might have
existed earlier. a fresh disk has no baseline and status reports `baseline no`.
status prints the current journal sequence and whether a baseline exists.

#,,.,,,..,,..,,,.,,.,,,,,,,..,,,.,..,,,,.,..,,..,,...,...,...,.,.,.,.,..,,...,
#UQTNN3JYSJFU5T5ZKW6K7VSJUNNDLZWRCWK3LRAKICGGIABFNMN5X5CKVDW7QJ4KSKYIMVI4SLTTO
#\\\|QMRKV7MWD6NB73VEGP3VYBFWMKAVFAY3GGUKIRJ2EJB3TOXMHIP \ / AMOS7 \ YOURUM ::
#\[7]G64CGSPMPA3MQTGA7ASSZOIJHOT76YTC7EIMMKFVFASU5F7N5ABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
