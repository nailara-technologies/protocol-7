---
name: resource-accounting-design
description: 2026-11-16 Fable + K3.1 built data/md/design/RESOURCE-ACCOUNTING-UNIFIED.md [ NRT ledger, untracked ] ; owner answers in private notes ; next : fable pass folding answers + irrigation
metadata:
  type: project
---

design doc : data/md/design/RESOURCE-ACCOUNTING-UNIFIED.md [ 961 lines, UNTRACKED, unsigned ]. shape share -> slot -> fill -> usage -> proof -> transaction ; prepaid or wait, no credit ; pools = ownerless crowd-filled slots ; journal the only state ; stage 1a \ 1b for kimi.

private notes [ ~/.n/private-notes/ ] :
- fable-nrt-nrd-brief-2026-11-16.md [ original brief ]
- k31-review-resource-accounting-2026-11-16.md [ 25 findings, fable : 19 accepted 6 modified ]
- owner-pool-authorization-2026-11-16.md [ AUTHORITATIVE owner position + answers to q15 16 19 22 23 + irrigation pointer ]

names : lowercase nested under AMOS7::NRT, see [[harmony-names-hint-not-rule]].

2026-11-16 later : owner answers 15 16 19 22 23 + irrigation FOLDED [ fable pass 5 ] ; Fable reset REDEEMED [ week back to 56 % ]. open q 2-6 8-14 21 24 25 + new 26-30 [ converting zenka, smallest fill, capacity source, network core, public drops to outside slots ] ; proposed awaiting owner : 7 17 18 20 21a.

**Why:** owner wants a unified resource accounting substrate before building.
**How to apply:** resume the doc from these files ; never build before the owner approves the first state.

2026-11-16 late : Fable SUBSTRATE-SYNTHESIS.md [ data/md/design, untracked ] : "a tree of cells" [ place window occupants journal gate parent ; reduce up, irrigate down ] ; 17 contradictions, 15 owner q ; smallest step AMOS7::cell::time exact Y-grid function. brief ~/.n/private-notes/fable-substrate-synthesis-brief-2026-11-16.md
2026-11-16 late : Fable N7FS-FORMAT-4.md [ untracked ] : json-free n7fs, 38 json kinds, one canon text form shared with the ledger, Prior module for old reads, 8 stages, 17 owner q. brief ~/.n/private-notes/fable-n7fs-json-free-format-brief-2026-11-16.md
2026-11-16 committed : a51999e20 [ Nested.pm empty-parent root + parent check ], 2b87fcc73 [ AMOS7::cell::time exact y-grid ; float epoch_int off by one at 10082 level-1 boundaries, first ~13.5 y ahead -> switch in a versioned step, e.g. with format 4 ]. k3.1 synthesis review [ 24 findings ] : AMOS-7 = 32 bits [ 50 % collision ~77000 ], ledger canon must follow format 4, recover shortens journal. owner : format 4 canon = ledger form [ q1 ], both disk upgrade paths [ q5 ], receipts before ledger stage 2 [ q17 ].

#,,,.,.,.,,..,,,,,,,.,.,,,,.,,.,,,,,,,,..,,,,,..,,...,...,..,,.,.,..,,,,.,.,.,
#OSUIZVOMTVGZWX3UU2VMXBEDYGVZM2C57QLXK4YLV6IQZAPHJGU7GJPP4MDYDZ6Y2ARVP4LHRZUBU
#\\\|7ZH57ZCJRJNP2TKLSE33DO3YVCGRPCJPUAJA52MWKC75T4CBAY2 \ / AMOS7 \ YOURUM ::
#\[7]3ASTMAWLCBLZZIU2PU2IO4NFXSQLAXS4RNKHJ6VEETHLSUS56GAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
2026-11-16 late : owner ACCEPTED data/md/design/DECISION-GUIDE-2026-11-16.md [ all 12 + section 2 confirms ] -> format 4 stage 1 [ AMOS7::cell::canon ] ready for kimi.
2026-11-16 late : committed format 4 stage 1 AMOS7::cell::canon + ::list [ fail-closed verify, lazy rows faster than json::xs ] + DECISION-GUIDE. next : format 4 stage 2 [ kind tables + Prior ] or ledger 1a.
2026-11-16 late : committed ledger stage 1a [ AMOS7::NRT, bin/nrt ]. owner ideas recorded in private note : remainders flow to parent, nested units, clean-unit anonymization, trunks, SHADOW ACCOUNTS, BUFFER POOL -> next ledger design pass.
2026-11-17 : owner position note grew a full ledger idea set [ fairness curves, buffer pools, shadow accounts, nested units, design test zero..saturated, visualization -> realtime perspectives \ layers ] -- read ~/.n/private-notes/owner-pool-authorization-2026-11-16.md before the next ledger pass.
2026-11-17 : fable folded the owner idea set into the ledger [ sections 15-22, conflicts 17-29, q35-47 with recommendations ] ; owner accepted q35-47. doc needs re-sign + commit.

#,,.,,...,,..,.,.,.,,,,,.,..,,,,.,,,.,.,,,...,..,,...,...,.,.,,,.,...,.,,,...,
#QHSCHZ7EIGG4AHWR23GJFSAXFWLTCJURJLVBM7Y5XM24CYFHLGLQDZP27SBB5WFN3OKZWE5WDKIH2
#\\\|IEAUGNVUVGJU6J3N26TPWS7WGB3CIMZZTZW2VJMA5FYDMDT7QDJ \ / AMOS7 \ YOURUM ::
#\[7]TAV6LGV4LAS6BD3HOH7MD6P2ADBUTNJ4UYHQMDNGYSOQIJSCZUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
2026-11-17 : committed format 4 stage 2 [ AMOS7::N7FS::Canon + Prior, json3 caveat for carried-over manifest chunks ]. next : format 4 stage 3 [ wire + home state ] or ledger 1b.
2026-11-17 : committed 47a902d23 [ 10 k3.1 security findings fixed ; nested parents end A I Q Y ]. kimi week at 91 % -- no more kimi before reset.

#,,,,,.,.,.,.,..,,,..,,,.,,,,,...,,.,,.,.,,,.,..,,...,...,...,,.,,...,.,,,,.,,
#TLVXCFWS64HFTDV5VSZDDATFHASUC3XVAGMTKEY6PLOE5CPOBDA6RCBSPDNDS54DBA2VW5VCV33RQ
#\\\|HBXAUHZI55G5CZTOFAUXDJ47IIQLBBZRJGFMLRQAANFIEMJCU7P \ / AMOS7 \ YOURUM ::
#\[7]4HD4VFBBYN2OYE2MCGPSIIBOZJH3W2VMZDQJMPAS73BZYBSGLUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
2026-11-17 end : see [[session-handover-resource-ledger]].

#,,..,,,.,.,.,,..,.,.,.,,,.,,,...,.,.,.,.,.,,,..,,...,...,...,..,,,..,..,,..,,
#D3LTLGVCODQARKLVJ25OVYK6UQ232RDVWUNZXEFUERZ7GMAYFF5S3BZCPO6YOH3LGH4DGDEQMKPEO
#\\\|ZINUIMSBRMZEZE43WWQZVXUK5EERCLITQ7KPMMLRRT7ANXLME3Z \ / AMOS7 \ YOURUM ::
#\[7]BQULZVDF2U2JQDP6ISMRQVLESPZB2OXBHWZ3Z7N4HVCTJUDBLKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
