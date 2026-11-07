# N7FS references and release : design for store format 3

status : stage 1 built [ journal, references, reference drops, repair,
conversion 2 -> 3 and the journal witness ], documented as built in
`N7FS-FORMAT-3.md`. release, reclaim, tombstones, release-epoch, hard-linked
conversion, `-prune` and journal checkpoints remain design for later stages.
builds on `N7FS-FORMAT-2.md`, the owner's answer of 2026-10-22 in
`FILES-ZENKA.md` [ point 14 ] and the
`references/<ntime-dec>/<amos>/<bmw>/addr` layout of `N7FS-SPEC.md`.

## what it solves

- a deleted meta record or node goes unnoticed : signatures only prove what
  is there
- nothing can be removed : a confirmed upgrade keeps the old epoch [ the
  dogfood disk went 37 -> 80 MB ], a purge is impossible
- `references/` is missing : the files zenka keeps a heads index outside the
  disk, word groups have no current head to build on
- `-remove` leaves empty directories

## 1. the journal : what the disk should hold

an append-only signed chain under `.n7fs/journal/<ntime14>.journal`, signer =
the store key, label `p7 n7fs journal:0001`.

    { seq, prev [ bmw of the previous entry ], disk,
      add [ nodes, meta names, references ], drop [ the same + releases ] }

- every write ends with one entry : one per assimilate batch, one per
  release. the entry is written BEFORE a release deletes and AFTER an import
  publishes, so a crash leaves extra data [ reported, recoverable ], never a
  claim of data that was not yet there
- replaying the chain gives the expected set. `verify` compares it with the
  disk : **missing** = a loud failure, **unlisted** = a loud failure, except
  an unjournaled node from a crash, which is named as such and adopted only
  by an explicit `n7fs repair`
- **truncation** : cutting the tail gives a valid older disk. the host witness
  pins the highest seq, as it pins the format. a first-contact host cannot
  tell [ same open limit as format 2 ]
- large disks : a signed checkpoint [ the full set's checksum at a seq ] saves
  replaying from the start. not in the first build

## 2. references

    references/<ntime-dec>/<amos>/<bmw>/addr

a signed record [ `p7 n7fs reference:0001` ] : `{ disk, addr, holder, name,
ntime }`. `<ntime-dec>` is the creation time, `<amos>/<bmw>` the target, the
checksum of the path comes from the spec. one reference per source \ holder.

- **assimilate writes one** for each new source, so a plain disk works without
  a separate step
- **dropping** writes a signed drop record beside it and a journal entry,
  nothing is rewritten
- **live** = a reference with no drop. the node's state follows from this and
  is never stored, so it cannot disagree
- **meta stays** : meta describes an import [ history ], a reference says that
  someone still wants the node. `find` shows live references by default, and
  history with `-all`

## 3. garbage and release [ the owner's two paths ]

a node with no live reference is **garbage** : the bytes stay and it can come
back.

- **back by content only** : importing the same bytes revives it, the caller
  proved it holds them. reviving by address alone is an owner path, never
  general [ the oracle `:n7fs:` refuses ]
- **reclaim** : `n7fs reclaim <disk> [ -free <size> ] [ -older <age> ]`, oldest
  garbage first. no daemon : a caller decides when
- **instant purge** : `n7fs release <disk> <addr>` for content that must be
  gone now. with live references it refuses and lists them unless `-force`
  [ warn, name what breaks ]

both write a **tombstone** [ `p7 n7fs tombstone:0001` ] signed by the store
key : `{ disk, addr, ntime, reason }`, so a later union sync does not bring the
node back. reclaim is when union sync first hears of a node [ the owner's
rule ]. importing the content after a tombstone is allowed : a newer ntime
wins, like TIMESTAMP-DELTA-SYNC.

order : tombstone + journal, rename the node aside, remove it. a crash in
between is finished by `repair`, and a half-removed node never verifies as good.

**what a release does not prove** : overwriting is no proof on ssds, journaling
or copy-on-write filesystems, and backups keep the bytes. never recoverable
needs crypto-shredding [ FILES-ZENKA 14 ], which is a later content format and
not part of this one.

## 4. epoch release and cheaper upgrades

- the spec releases the old form when it leaves the window. added :
  `n7fs release-epoch <disk> <n>` releases earlier, only for a confirmed
  conversion and never for an active epoch. it ends the rollback to that form,
  so it says so and needs `-now`
- **conversion hard-links content** when both epochs are on one filesystem :
  content is immutable, so only meta and records get rewritten and an upgrade
  no longer doubles the disk. other filesystems copy as today

## 5. small : empty directories

`assimilate -remove -prune` removes the directories it emptied, inside the
given paths only. off by default : an empty directory can mean something.

## 6. conversion 2 -> 3

through `upgrade` \ `confirm` as before. the first journal entry is a
**baseline** listing what is found, with `baseline : true` : a deletion before
it cannot be detected, and it says so. every existing source gets a reference,
marked as converted.

## decisions [ owner, 2026-11-07 ]

1. **a reference's holder** : free text, the files zenka uses its handles. the
   store key vouches for it, not the holder
2. **tombstones** stay for good : union sync can come late, they are small
3. **garbage** has no default max age : reclaimed only when asked
4. **an unlisted node** fails `verify` loudly : nobody signed for it
5. **`find`** shows live references by default, `-all` adds history
6. **build order** : journal + references, then release and reclaim, then
   hard-linked conversion and `-prune`. the journal is the base of the rest

#,,,,,.,.,,,,,,..,...,,.,,,.,,...,...,,..,,,.,..,,...,...,,.,,,.,,..,,,,,,..,,
#QLEQPSLRIL3MICB2A6GGI4W6AJTLABGRWYSRUX6CDMOANBMXCCBV4RLJ2IQLD2WOBLZYIKXCIXPPC
#\\\|W7H7OOGIXB42YABLZFNH2Z2PSMIU6DY7TEWZQJYUJNVVFRQ7XT6 \ / AMOS7 \ YOURUM ::
#\[7]WP54HAL756V5JNF3I3WZUNWBA3QV2TEQURPI2PWPXIOFE22NNKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
