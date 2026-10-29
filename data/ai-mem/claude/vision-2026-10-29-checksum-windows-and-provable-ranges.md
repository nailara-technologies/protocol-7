---
name: vision-2026-10-29-checksum-windows-and-provable-ranges
description: 2026-10-29 owner + claude : <size>:<chksum> pairs, provably collision-free size ranges per checksum type [ enumeration vs pigeonhole ], collision-free BRANCHES [ uniqueness among actual siblings ], checksums of paths for routing, three window shapes [ fixed \ content-defined \ sliding ]
metadata:
  type: project
---

**checksum design notes [ 2026-10-29 ]** -- grew out of the TJ6 disk
capture [ bit-exact multi-source reconstruction, BMW-384 \ 512 proofs ].

- **identity** : bmw384 is the network-facing identity ; a distribution's
  signed hash [ sha256 .. ] is an ATTRIBUTE `{ algo, hash }` with a
  reverse lookup -- already so in data/md/design/OSF-CACHE-ZENKA.md
  'hash layers'. size travels with it [ `<anchor> <size> <bmw384>` ]
- **`<size>:<chksum>`** : removes the append-until-it-matches forgeries
  and is an instant pre-filter ; the generic collision strength still
  comes from the hash [ known collision attacks keep the length ]
- **provable ranges** : for n bytes there are 2^(8n) inputs -> enumerate
  and prove collision-free up to ~4-5 bytes ; once inputs outnumber
  outputs, collisions MUST exist [ short amos ~35 bits : provable only
  up to ~4 bytes ; bmw384 : 48 bytes, not enumerable ]. a per-type
  profile : proven-free \ unknown \ guaranteed-colliding sizes
- **collision-free branches** : prove uniqueness among the ACTUAL members
  of a branch, at any size ; a collision splits one level deeper. the
  N7FS layout `<amos>/<bmw>/` is this [ todo 4EO ]. a parent that
  compresses its children's short checksums loses a leaf-level proof
- **checksums of checksums** : a checksum over a path names a route ;
  each hop decides on its prefix -- links VISION-ROUTES-AS-SIGNATURES.md
  and [[topic-checksum-parenting-namespace-trees]]
- **windows must be predictable** [ every holder builds the same tree ] :
  fixed [ disks, bit-exact proofs ; shift-sensitive ] \ content-defined
  [ rolling-hash boundaries, an insert changes only nearby windows ] \
  sliding [ rolling checksum, finds known data at ANY offset ; confirm
  with bmw384 ]. check which shape osf-cache.cmd.merkle uses before N7FS
  settles -- one rule set for both

related : todo TJ6 [ security \ forensics capture, disk reconstruction ],
[[vision-config-installer-zenka-landscape]] [ layer axis ]

#,,,.,..,,..,,,,.,,.,,.,,,,..,,,.,,.,,,.,,,,,,..,,...,...,.,.,...,,..,.,.,...,
#GEKYUIGBWSYIDXKQXG6NTUPPWP6AT3P55V5GRTJR3U7MNTW4CCODD2VOEWHVMBCZVQESE3T4VLNQK
#\\\|ITSBTAQ33ZP4P46SVWOPZCBIUHSFGJ6BZ22ZJ3XIHALUNCAODRM \ / AMOS7 \ YOURUM ::
#\[7]AJ22FOWMJDL73AIWKO33FRCE2IUZMMXIYD6OI52QGDD2SS7UPKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
