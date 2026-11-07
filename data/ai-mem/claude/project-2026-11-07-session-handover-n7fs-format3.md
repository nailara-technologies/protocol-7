---
name: session-handover-n7fs-format3
description: START HERE 2026-11-07 : N7FS format 3 complete [ stages 1-3 ], dogfood disk on format 3, render loop design note ; what is open
metadata:
  type: project
---

session 2026-11-07 [ follows [[session-handover-chksum-lease]] ].

done, pushed to hub + pulled on srv-U F V A + azurum :
- 63ade5e6f stage 1 : signed journal, references, drops, repair, disk lock
- bc0b430af stage 2 : release, reclaim, tombstones, release-epoch [ my review fixed : stale aside bricked repair, empty -reason unreadable tombstone, lost tombstone unnoticed, release silent about the previous epoch's copy ]
- 65b0bd510 stage 3 : hard-linked conversion, assimilate -remove -prune [ fixed : prune removed directories already empty before the import ]
- servers reloaded for the gpu lease \ v7-zenki :hold: \ cube commits : v7-zenki source+init, cube source, coding all [ U A azurum ], models all [ A ]
- dogfood disk 4CGU3KA [ ~/.n/n7fs-dogfood ] : format 3, journal + baseline, both old epochs released, 46 MB, 105 nodes \ 204 listings verify

pattern that worked : kimi builds a stage in sandboxes, then I ATTACK on scratch disks [ crash points, re-imports, real data copy ] -- every stage had defects its own green tests [ 171 \ 69 mutants ] missed. keep that step.

design : data/md/design/RENDER-LOOP-LIVE-TEMPLATES.md -- the VIRTUAL QUEUE : items hold bindings, resolved at dispatch against the current template version ; three open questions for the owner at its end. see [[render-pipeline-direction]].

open :
- owner holds models\task [ do not release ] ; local zenki NOT reloaded for the gpu lease commits [ render running ] -- owner's call
- N7FS later : journal checkpoints, crypto-shredding, union sync [ must honor a tombstone only when the journal lists its release ], native zenka signer [ todo 6RH ], checksum search index, link tree
- todo XAH shorten ; start_once mismatch todo offered, not written ; "render queue empty" repeats
- first step of the render loop : verify how invoke-web enqueues before resolve-at-dispatch

#,,..,.,.,,,,,,..,,..,,,,,.,.,...,,..,...,,..,..,,...,...,.,,,,..,...,.,,,.,,,
#UKJ522Y2B6O2I6EQTCMDP7JTAIJFB2K7523SGURFZKJBGBVZCXDKDTRGLBS3453WMS467KXFAMNE2
#\\\|M24LNAYC7Y3JYT4JJ7SBXKV6O6BZAND2XFJWWQHDIPHGBIAG5VX \ / AMOS7 \ YOURUM ::
#\[7]QNWSXCL6SOPD6JPI2QMWFAWLULDNHDL5RQSYSJFYJPIIKC2O3UDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
