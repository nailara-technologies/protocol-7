---
name: session-handover-external-access
description: 2026-10-31 [ last 42210691a ] : backlog closed [ discover back-off, ':<content>' ids, letsencr param sends, thermal k transient fit ] ; EXTERNAL-ACCESS-ARCHITECTURE.md ; azurum reachable but minimal set + no remote user
metadata:
  type: project
---

**landed 2026-10-31** [ pushed hub, pulled srv-U F V A ]

- 6f7ac2739 discover backs off x1.2 to 780 s while nodes is absent [ owner : no
  10-min windows, 13 min ] ; models ':<content>' = exactly one install path ;
  p7-deps help ' \ '
- ed16d0d9f letsencr param-only sends [ stash dropped ] -- no renewal due on
  any host, so the paths are not live-exercised yet
- 1645a23fc thermal k from a transient fit [ settled periods never occur :
  the gate pauses its own load ] ; live in task, check
  `p7c task.dump '^task\.thermal\.gate\.k'` after load [ k_fit_tau \ r2,
  k_samples -> trusted at 30 ]
- 42210691a data/md/design/EXTERNAL-ACCESS-ARCHITECTURE.md : five layers,
  listener -> fd hand-off -> outer \ local cube, routed vs TUNNELED [ nested
  e2e layer ], filtering relay zenka. slice 1 = key_arrival in the
  authorization buffer [ AUTHORIZATION-BUFFER.md is design only ] -> kimi

**azurum**

- WSL regenerates /etc/hosts : ~/.ssh/config Host azurum now has the
  address + `HostKeyAlias azurum` [ keeps the pinned key ]
- running only v7-zenki cube system p7-log [ no pull-git, no discover in
  its setup ] ; `::: azurum` link + host-root pin ok, then 'user not
  authorized' [ no remote user entry ] -- needs root@azurum [ not in the
  standing root authorization, ask ] ; `ssh azurum :: ..` works as taeki

**corrections** : local httpd log was never stuck [ quiet traffic ] ;
VSHN4 \ VKMN6 owner re-trashed [ no interest ] ; night-brake slices 3 + 4
were already in 1453c62d3

**devmod signal set** [ owner 2026-10-31, kimi slice ] : signals stay
ACTIONS [ standalone cube \ unconnected zenka have no other lever ] :
numbers climb with the resulting state : NUM50 unload-all [ off ], NUM51
load-safe [ safe, from below ], NUM52 unload-unsafe [ safe, from above ],
NUM53 load-full [ full, today's ] -- 54 stays free [ gap to NUM55 log
width ]. load-safe must never load unsafe code at all [ unloading right
after is already too late ]. unsafe = writes %data [ set \ del ], blocks
[ sleep ], exhausts [ eat-mem ], runs anything [ exec-sub \ eval-code ].
v7-zenki keeps off | safe | full per zenka, pushes it as a start-up value
[ race free on restart ], serializes runtime signals [ next one after the
ack ] ; an unload signal also updates the remembered state. handler only
sets a flag, the event loop acts. DECIDED : devmod-enable is safe [ NUM51 ] ;
devmod-enable-rw retains the old full behavior [ NUM53 ]

**later 2026-10-31** [ last 4cdda1ca0, deployed srv-U F V A ]

- 9d486bb45 thermal idle power was the CURRENT reading [ dP ~0, k never
  learned ] -> learned while idle holds. live : idle 45.7 W, fits run but
  r2 ~0.51-0.58 [ < 0.8, none accepted ] -- likely fan curve [ k falls
  with temp ] and two time constants. NEXT : fit the scratchpad gpu log
  [ temp, W, fan, sm clock, 2 s ] offline before changing the model ;
  the session scratchpad is gone next session -- re-log with nvidia-smi
- 25168a908 coding compaction suspend deadlocked [ re-entered lock kept,
  late release stale ] -> lock handed over at suspend ; live ok
- 2bacd12bc dry_penalty_last_n -1 -> 1024 : full-context DRY broke quoting
  + tool calls ; the 9b went from 2 failures to a correct review
- 4cdda1ca0 moe planner used TOTAL vram, fit check FREE -> 7777 ctx ;
  now one budget, 35B A3B gets 53586 ctx. data/md/design/PATH-ROLES.md
- models : QIU7U7Y:TW2NJGY Huihui Qwen3.6 35B A3B Q3_K = exact quotes,
  deeper, but 34 rounds and wrote its working into the file [ prompt must
  enforce the format ] ; Security Auditor 14b XFX2XIQ:MWUPQMA can not do
  tool calls [ delete asked, not answered ] ; Qwen3.8-27B dense skipped
  [ 12 GB card ]. a :review: model slot idea waits for a good model
- devmod on coding : unload-unsafe + devmod-clear done
- open : PATH-ROLES steps [ role helper first ], bin-links list [ root
  PATH case unclear -- owner : /usr/local/bin links do not work for root ]

**next** : thermal k offline fit ; azurum to full desktop set [ root ] ;
slice 1 of external access ; N7FS [ binary byte form NOT decided -- not
used yet ]

#,,..,.,,,..,,,,.,...,.,,,.,,,,..,...,,,.,..,,..,,...,...,,.,,,..,,.,,.,,,,,,,
#6WYFEDA4P4KAIEVYXO3VELW73HOOVENR7EYVKGPR7DIQWMPYSMQTWTPJ4KNVJIK2RQDUZE7Q4YPAS
#\\\|ZRTKBBQNZJJY5RO4VN4XRH3RYVI65UNKEGRQFN62P4TPQSPXRXY \ / AMOS7 \ YOURUM ::
#\[7]LJIFU5W6KQZOMIMIZ76CC64XVA6CHDAF54XRKVEIUWIRDXVBSGAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
