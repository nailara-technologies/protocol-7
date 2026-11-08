# N7FS stage 3 : local union sync as built

2026-11-08. this is an additive store-format-3 extension following
`N7FS-TREE-CATEGORIES.md` and `N7FS-INCOMING.md`. it provides a standalone,
one-way local CLI. a union is two runs. there is no network, encryption,
placement or background daemon.

## commands

```
n7fs sync <from-disk> <to-disk> [ -dry-run ] [ -trees-only ]
n7fs sync-conflicts <disk>
n7fs sync-conflicts <disk> resolve <record-name>
```

both disks must be attached format 3. the source and receiver are locked in
sorted disk-id order. the source lock is shared; the receiver lock is
exclusive unless this is a dry run. source == receiver and a copied disk id
are refused. source authentication includes the ordinary signed record checks,
full journal replay and the same host format/journal witness checks as
`status`; rollback therefore needs the existing explicit `-allow-rollback`.
nothing is written to the source. dry run writes no records, journal, state,
lock or witness changes and performs the same source checks.

the report contains nodes, content bytes, references, trees, categories,
assignments, drops and conflicts. `sync` exits nonzero while any unresolved
conflict remains, including after a no-change run, or when it fails.
`sync-conflicts` prints durable unresolved
records and exits zero after a successful listing. an idempotent sync prints
`no changes ; no journal entry` and writes none.

`-trees-only` synchronizes category definitions, live trees, their manifests
and all pinned file content. ordinary references, reference assignments,
batches, reference drops and releases are excluded. it never writes or
advances a per-source cursor, so a later full sync still imports the ordinary
references. tree origins deduplicate the overlap. a failed sync tells the
operator to run `n7fs repair <to>` before retrying.

## origin and translation

sync never copies a signed record. every reference, tree, tree drop, category
version, assignment, batch, cursor, conflict and retained-release tombstone is
a new receiver record signed by the receiver's delegated store key. the new
payload carries:

```
origin : { disk, id }
```

`disk` is the disk where the item was first created and `id` is its original
record path. references use the original node-relative reference path;
retained releases use the source content address. an onward sync keeps the
first origin. absent origin on an older or native format-3 record means its
own disk and record path. journal operations repeat origin and replay and
`verify` bind both fields to the signed record. reference drops preserve the
reference origin.

matching uses origin, never holder path, name or receiver record path. an item
whose origin is the receiver and an item already present by origin are not
applied again. dropped and retained-release origins are remembered, so an old
copy cannot resurrect them. this gives A -> B -> A and A -> B -> C -> A echo
suppression without suppressing a genuinely new native reference.

content is copied by BMW identity into the receiver's active write epoch.
source content and its signed meta are verified before any receiver publish.
the ordinary format-3 node writer supplies streaming copy, temporary
directory, fsync, atomic publish and read-back verification. an already
present node is verified and reused; a new holder still receives the matching
receiver-signed meta needed by `incoming list`. no whole-source content scrub
is done.

a tree manifest is streamed through JSON Lines translation. every file
address is rebound to the receiver epoch. the rewritten manifest is hashed
and its receiver address is computed from those new bytes, never by replacing
the epoch in the source manifest address. the tree record keeps its origin,
so a translated manifest returning to the first disk is still an echo. all file
nodes are copied and checked before the translated manifest is journaled.
raw path, symlink, owner-name and xattr octets are not UTF-8 round-tripped.
restore on both disks therefore produces the same tree content.

## per-source cursor

| kind | magic | label | location below `.n7fs/` |
|---|---|---|---|
| sync cursor | `P7FY` | `p7 n7fs sync cursor:0001` | `sync-cursors/<ntime14>.<tail8>.sync-cursor` |

the signed payload is `{ disk, source, source_seq, source_hash, ntime }`.
`source_hash` is BMW384 of the exact source journal entry bytes at
`source_seq`. the journal's `add.sync_cursors` repeats the binding fields in
the same entry as all applied work. the next run starts after that sequence.

a source head below the cursor is refused as rolled back. a different
authenticated entry hash at the cursor sequence is refused as rewritten or
rolled back and names the source and sequence. these checks are independent
of the host witness and remain useful when a source travels without its
witness.

the current implementation writes one receiver journal entry per sync run,
plus the independent tree-drop entry described below when needed. trees-only
runs never write a cursor. the cursor covers only completely translated work; no cursor-only entry
is written when there is no work. conflicts are durable work, so a run that
records a conflict advances past it. an already recorded conflict alone does
not cause another entry.

## apply order and crash recovery

tree drops are applied before tree adds. when a name is dropped and recreated,
the drops get their own earlier receiver journal entry without a cursor; the
replacement and cursor follow in the next entry. a crash between them is safe
to repair and retry. within the remaining run the order is categories, nodes
and required meta, references, trees, assignments and batches, then reference
drops and retained releases. source batches are re-issued as receiver batch records. only
finally live source trees and finally non-released source references are
added; their later drops and releases still propagate. this avoids requiring
bytes that an old journal add names but a later source release has already
removed.

fault points exist between every record class and immediately before the
journal write. repair preserves the existing explicit content/meta/reference
adoption path and quarantines unjournaled trees, tree drops, categories,
assignments, batches, cursors and conflicts. origin is retained when repair
adopts references. retry after repair completes the sync; the test suite
checks every point followed by repair, retry and full verification.

## categories, assignments and conflicts

ntime is not used as a causal clock. source history is indexed once by the
exact origins of category versions and assignments on either disk. a source
has seen the receiver only when that exact current version occurs before the
source change; seeing an older receiver version does not count. a later source change
after that incorporated version wins. two genuinely concurrent assignment
values keep the receiver value and create a durable conflict containing both
values. an explicit `set-category` or `incoming tag` journals resolution of
the matching conflicts.

| kind | magic | label | location below `.n7fs/` |
|---|---|---|---|
| sync conflict | `P7FZ` | `p7 n7fs sync conflict:0001` | `sync-conflicts/<ntime14>.<tail8>.sync-conflict` |

journal `add.conflicts` makes a conflict current and `drop.conflicts` resolves
it. history remains after resolution. conflict and cursor records participate
in replay, verification and quarantine like the stage-1 and stage-2 records.
`sync-conflicts resolve <record-name>` resolves any kind while keeping the
receiver value. unresolved tree conflicts are re-evaluated on every sync even
when the cursor has passed the original add: a still-live source tree imports
when its name is free, and a source tree that is gone resolves the conflict.

concurrent category definitions become one new version with the strictest
effective merge: cascade, maximum copies and priority, full replica, no
foreign work, private layer and sorted union of want. the merge is reported;
it is deterministic and does not need a clock winner.

pool membership is only the current per-reference assignment, so it crosses
with the reference and its matching meta. tagging on either side converges
without conflict when there was no concurrent assignment. `category show`
uses the same replayed current assignment for individual and batch records.

## trees, drops and retained releases

same tree name and origin is a no-op. the same name from another origin is a
conflict; the source tree is not imported under that name and the receiver
tree is unchanged. a tree drop matches the original tree identity and drops
only that tree. live trees, including synced trees, continue to pin their
manifest and file nodes.

only source `drop.releases` journal operations propagate releases. source
tombstones are authenticated, and those without a matching journaled release
are explicitly ignored. reference drops and releases drop only origin-matched
receiver references.

a synced release is a `drop.sync_releases` journal operation containing the
translated node address, its origin and the matched reference drops. it never
renames or unlinks content. when another origin still has a live reference,
or a live tree pins the content, only the matched reference drops are written
and retention is reported. otherwise a receiver-signed tombstone and a
retained-release operation suppress later resurrection. the retained-release
operation is valid even when the receiver never had the node, which allows an
initial sync spanning an old add and a later release to preserve the deletion
without needing the deleted source bytes. an address live again at the source
head is never released, including import-release-reimport in one run.
references added earlier in the same receiver run count as live, and journal
order between an old release and a later revival is preserved.

the source is never changed and sync never reclaims content bytes. retained
content remains verifiable and readable by exact address; reclamation stays
an explicit local decision outside sync.

## performance and known limits

- source and target journals are replayed and their signed record indexes are
  rebuilt for each invocation. work after that fixed replay/index cost is
  linear in entries since the cursor. there is no per-entry scan of all
  references and no quadratic causality lookup. memory is linear in the
  authenticated record indexes; 100k-reference stores are not loaded as one
  JSON document, but their record indexes are held in memory.
- content and manifests stream in 1 MiB reads or line by line. a run normally
  writes one journal transaction, with a second earlier transaction only when
  tree drops must precede replacement adds. a very large first sync is not
  split into smaller journal batches. interrupted runs rely on repair and
  retry rather than a partially advanced cursor.
- origin matching does not merge two independently created references merely
  because their holder strings or content match. this is intentional.
- a conflict listing is local durable state, not a network-wide conflict
  proof. the local host witness has the same first-contact limitation as
  format 3.
- synced releases deliberately retain bytes and are distinct from local
  physical release. filesystem history, backups and other copies are outside
  this stage's deletion guarantees.
- network sync, sealing, placement, native signer integration and laptop
  want-set scheduling remain outside stage 3.

#,,.,,...,.,.,,.,,,,.,.,.,,..,,..,,.,,,..,,,,,..,,...,...,..,,.,,,...,,..,,,,,
#M3QEWLHGTLN6H2EK64ON56JN7WLDWOEEG7XQG4QBRVR2WEPL6HV4CSFMOPTJDWLT6LT2CJXBOGCBW
#\\\|CCJPJH2KU4K7X4J4VVQCAQ2K5VBXCSOF4XDAZZGE7AGSPV5EKMQ \ / AMOS7 \ YOURUM ::
#\[7]S6PKNLN5RMDQXZ55ERROXT3TZX2IYQZAONI63RD45JDW3ZDLAECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
