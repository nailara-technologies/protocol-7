---
name: project-2026-11-05-n7fs-current-state
description: N7FS researched state 2026-11-05 : format 1 built and tested, standalone CLI only, never deployed, no zenka uses it ; no code since 2026-10-18 ; next-step decisions listed
metadata:
  type: project
---

researched 2026-11-05 for a clean start, read-only. interrupted 2026-10-25 : [[project-2026-10-25-session-handover-worker-host-config]]
named it the owner's next focus, production issues came first. no n7fs code commit since d13fc7ef3 \ ac8317cda
[ 2026-10-18 ], design only after that [ files zenka 10-22, assimilation depths 10-21 ].

**exists**
- bin/n7fs [ keygen pubkey init list attach detach status verify assimilate upgrade confirm ], AMOS7::N7FS +
  Convert Disk Sign Store Sum. standalone like p7-vault, no zenka, no network.
- docs : data/md/design/N7FS-SPEC.md [ + decisions after v1, open list ], N7FS-FORMAT-1.md [ as built ],
  FILES-ZENKA.md, ASSIMILATION-DEPTHS.md ; todo 4EO in data/yaml/todo/base.yaml [ the large design entry, open ].
- tests run 2026-11-05, all pass : test-n7fs-assimilate 62, -convert 45, -id 65 ; fixtures/n7fs/mutate.pl 16 caught, 0 survived.

**does not exist**
- nothing in src/ or other bin/ tools calls it [ grep AMOS7::N7FS | bin/n7fs : tests only ]. shm A may change that
  if it reuses AMOS7::N7FS::Sign -- check the shm A diff.
- no live disk on the desktop : no /N7FS, no ~/.n/n7fs. servers not checked.
- format 1 removes no node ; no tombstones, no references/, no stream writes, no assimilate meta override, no
  shared read across uids [ the gaps named in FILES-ZENKA.md ]. no replication, no chunks, no network resolution.
- BMW-L13 still a stand-in [ spec : one AMOS7 module from the src/ algorithm, a converter step replaces it ].

**decisions the owner must make [ blocks or shapes the next step ]**
1. binary byte form : amos_chksum of binary input depends on a prior in-place utf-8 upgrade. one form must be
   chosen before N7FS stores binary -- hashes are addresses, so changing later means conversion. FIRST.
2. spec 'store key signs meta and state, content verified by its checksum path' is marked suggested -- confirm.
3. chunk size and packing, optional prefix level [ spec open list ].
4. FILES-ZENKA open points : 12 [ C = bmw ], 3 [ task proof via child zenki ] and the rest of its list.
5. direction : first consumer -- files zenka [ needs the gaps above ] or plain assimilate on a real disk.

**proposed start**
fix decision 1 with a test, then dogfood format 1 : a real disk, assimilate a non-critical tree with -keep, verify
[ cheap, finds real problems before more format ]. then node release + references, which the files zenka needs.
kimi for implementation, claude for format decisions and review. this order is a proposal, owner has not chosen.

#

#,,..,,.,,,..,,,.,...,.,,,,..,,..,...,,,,,,..,..,,...,..,,.,,,,,.,.,,,...,,..,
#57W675TKRGKMHOVV7U6VJAQE4TWGIUDSAFO7KEJYPUHBCONSBI6ENDMERB5UR323FWZFQ355KW7AE
#\\\|CQ5G2H6JXY2PGC3IH3HFVR3O63UTXLPNAU2WAE2ZZHEMW77KXLH \ / AMOS7 \ YOURUM ::
#\[7]C3J2C3O7IXJXBNQLI56XXKKAF5657MTVON6JJJCKTKZIHOESE6DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
