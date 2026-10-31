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

**next** : thermal k live check ; azurum to full desktop set [ root ] ;
slice 1 of external access ; N7FS [ binary byte form NOT decided -- not
used yet ]

#,,..,...,,,.,,.,,,..,..,,..,,,.,,,..,,.,,...,..,,...,...,...,.,,,.,.,...,..,,
#ZPNAVXG4TFETISUMZ6E25AC5SSEPJRQOT7TE2MUK7MWBODDNUYH2BWXQJPH2N7SSRCLK5J5HDDW3I
#\\\|DGGICMCNBHSFPQOMFHB4UCFGFFE53D5IJG7ENYBXOLAAM3Q4ZQ3 \ / AMOS7 \ YOURUM ::
#\[7]GFBD6VHHP4MM2ZWDCNKOYG3FRJSGMUSK3BMAUBRLJEJP5NMVE6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
