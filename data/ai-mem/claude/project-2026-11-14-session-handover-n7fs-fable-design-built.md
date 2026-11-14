---
name: session-handover-n7fs-fable-design-built
description: 2026-11-13..14 : Fable N7FS design findings 5 7 8 9 10 FULLY BUILT [ stages 1-12 + review R1-R17 ], pushed ; nothing live yet ; next = owner all-clear, live upgrade, first n7fs cycle ; Fable window plan ; the substrate notes thread
metadata:
  type: project
---

**state, all pushed up to e18b4c723** [ owner pushed ] :
- finding 5 [ Y-level ages, sharded map, chunked manifests, retain ladders + repack ] and all
  17 review findings of the second Fable run [ ~/.n/private-notes/fable-n7fs-review-finding5-2026-11-13.md ]
- Fable design stages 1-12 [ ~/.n/private-notes/fable-n7fs-design-7-8-9-2026-11-13.md, owner
  decisions 1-15 at its end ] : root-signed receipts + clock floor, head v2 [ SIV plaintext-keyed
  nonces, subkey ], peers + stale refusal + anchors, partial trees, registry middle way [ vault
  note for vault roots, `<root-key>.state/registry` p7 config style for file roots, sealed copy on
  every holder ], recover without state writes + n7fs drill, n7fs snapshot [ snap: prefix, shrink
  guard ], holds + restore -at, n7fs cycle additive + destructive [ strict gate, rule parameter
  ready for 5-of-7 ], drill -offline + overdue + key-copy-moved, design docs in line
- tests : 37 scripts, 1695 checks ; ALWAYS check each script's exit code AND summary line
  [ a dying script hid once : the epoch-boundary bug, fixed with N7FS_TEST_NTIME ]

**nothing live** : all hosts have the code [ pulled with the needrestart exemption ] but NO n7fs
command runs until the owner's all-clear. then : upgrade all hosts together, holder-migrate flat
holders, switch to ssh-receiver:, first `n7fs cycle` with -dry-run first. timer example only :
read-me/md/N7FS-CYCLE-TIMER.md [ nothing installed ].

**lessons** : kimi git-restored my uncommitted notes twice and deleted a memory file
[[kimi-restores-files-it-did-not-touch]] -- every prompt forbids touching others' files, commit
notes before a run ; never edit a file inside a pending p7_sign request [ content_changed abort ] ;
kimi's stage 2 sealed all map blobs under one nonce -- check nonce domains in every review.

**Fable window** [[fable-access-window]] : Fable reset until 2026-11-17 08:59 ; plan a whole 5h
window ; topics : add-only log mount, hyperspace viz [ grid-v14-layered.refactored.html ], NRT.NRD
economics + resource pool ledger, synthesis of the substrate thread, 3D tests [ BCC\FCC claim,
povray shell, printable shell ].

**the substrate thread** [ owner riff 2026-11-14, design notes only ] :
topic-network-as-computer.md "space as a generic computation substrate" ; topic-checksum-
parenting-namespace-trees.md "implicit anchors" ; N7FS-SEALED-REPLICAS.md open list [ derived
placement, home zenki ring, graphical views, curves, phase, recipe copies via P7REFS, image paths ].
p7 config style for hand-editable files, never json, aligned separators [[p7-config-style-not-json]].
[[session-handover-n7fs-review-findings]] [[n7fs-host-migration-goal]]

#,,.,,,..,,,.,,..,,.,,.,.,,,,,.,,,..,,,,,,,..,..,,...,...,,,,,.,.,,,.,.,,,..,,
#H3NU2HEGZ6N3QNP37X3SR44EHQD2UVJDZKYJ7W7MT7JX2BHOFOLWCGVABDLOZXF4GOOI6VCVOMHYI
#\\\|M3SU4ZOYM4ARSFNTRYX2Z564LFMB76NF6ZEMEQPP5Q4Q5XWBNPT \ / AMOS7 \ YOURUM ::
#\[7]WIR73T6POTFIMNNNNI5BKS3WXJWFTKHYVYOQVFFHPAW3J3R7CUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
