# N7FS format 3 : stage 1 as built

2026-11-07. the signed journal, references, reference drops, crash repair and
conversion 2 -> 3 from [ `N7FS-REFERENCES-RELEASE.md` ]. format 1 and 2 readers
keep their existing behavior and warnings. paths, content addressing, immutable
writes, mount records and the epoch conversion window are unchanged.

stage 1 does not include release, reclaim, tombstones, release-epoch,
hard-linked conversion, `-prune` or journal checkpoints. the journal retains a
`drop` object and an empty `drop.releases` list so those operations can be added
without changing the record format.

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
- `drop.releases` is present and empty in stage 1. node and meta drops are
  represented for the later release work ; only reference drops are written now.

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
process ] : assimilate, drop, repair, upgrade and confirm run one at a time per
disk and wait for each other. `verify`, `find` and `get` by name wait on a
shared lock, so they never see an import half journaled. a writer refuses an
entry replay would refuse before signing it, and an import onto an unjournaled
node refuses and names `repair`.

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
record. `-all` includes meta history and dropped references, appending `dropped`
and, for converted references, `converted` in the existing bracketed stamp.
columns remain `<address> <size> <format> <source-or-name>`.

`get` by name uses live references in format 3. a dropped-only name fails with
a message saying it was dropped. `get -all` includes dropped history, and get
by exact address remains available regardless of reference state. both paths
verify the selected content and all its signed meta before output.

## verification and repair

`verify` replays the journal, verifies every content node and signed meta, reads
every reference and drop, and compares the replayed set with the active epochs.
a missing node, meta, reference or required drop is a loud failure naming it.
an unlisted node, meta, reference or drop is also a loud failure. in particular,
an unjournaled publish is reported as crash-or-injection data, not as a valid
extra file.

`n7fs repair <disk>` requires attach and the store key. it first verifies every
candidate and refuses any missing expected item or foreign signature. it then
writes one `repaired : true` entry adopting all verified unjournaled nodes,
meta, references and drops. the command prints every adopted item ; nothing is
silently adopted. a store-signed but unlisted node is still adopted only by
this explicit command and is reported like any other item. if a conversion
crashed after its state switch but before sequence 1, repair marks that first
entry both `baseline : true` and `repaired : true`.

## read cost

there are no checkpoints in stage 1.

- `verify` : read and authenticate the whole journal, scan all active meta and
  reference records, and hash every active content node. cost is O(journal +
  records + content bytes).
- `find` and `get` by name : replay the whole journal and scan active meta and
  references, but do not hash every node. get then hashes only the selected
  node. cost is O(journal + records), plus the selected content for get.
- `get` by exact address : authenticate only the first and last journal records
  and compare the last sequence with the host witness, then verify the selected
  node and meta as before. it does not replay or authenticate the whole chain.
  cost is O(number of journal names + selected content bytes), not O(journal
  bytes). full `verify` remains the operation that detects a fork, reorder or
  bad middle entry.
- `status`, attach and detach use the same cheap journal-head check as get by
  address. assimilation, drop and repair replay the chain before writing.

## truncation witness

the host-signed use record adds `journal_seq`, the highest journal sequence
seen per disk, beside the highest format. a presented lower sequence refuses
unless `-allow-rollback` is given. an older witness without the field means
sequence 0, so it does not reject a newer valid journal.

assimilation, drop and repair append the observation after their journal entry.
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
epoch in stage 1, never hard-linked.

after the new epoch verifies, each distinct existing source receives a live
reference marked `converted : true`. the signed state switches, then sequence 1
is written with `baseline : true`, listing every converted node, every meta
name and every converted reference. the witness is updated last. confirmation
runs complete journal-and-disk verification.

**baseline limit** : deletion before this first baseline is undetectable. the
baseline authenticates what was found at conversion, not what might have
existed earlier. a fresh disk has no baseline and status reports `baseline no`.
status prints the current journal sequence and whether a baseline exists.

#,,,,,.,,,.,,,.,.,,.,,,,.,...,,.,,.,.,,,,,...,..,,...,...,...,,.,,.,,,.,.,.,.,
#DDAS5ZKD32WFFK5RVVMAWGNYQWL2GKNKOVQBO7J5FRDQH2OJUWJEHXLXNBC4XTKGN2JVZQZQFMIV2
#\\\|LMONCMZBQ7VSTQSA2G7WGBCQHKVPHEWQXN6VTYFACUG23FRNQQP \ / AMOS7 \ YOURUM ::
#\[7]ZJXAMLALNUQA72TTEUPEBXNDQ4D6RM5RYGV7FLAVL4HXZEUQMGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
