---
name: project-2026-10-29-session-handover-jobsite-live-updates
description: START HERE 2026-10-29 night [ last 00afc97c8 + this memory commit ] : jobsite live updates done + owner-confirmed, WY5 deployed [ verify the next scan's drain + counts ], pri -t 7, MX \ browser-peer vision saved ; next : WY5 check, Q2K, ZRK round 2
metadata:
  type: project
---

**where things stand [ 2026-10-29 night ]**

landed today, all live on pri [ jobsite \ web \ httpd ] :
- WY5 : fetch to an empty page [ ceiling 20 ], remote block_data, per
  category `queued · new · known` ; remote queue-depth fix [ d7ab4301d ] ;
  owed rescans [ 89e067007 ]
- live updates jobsite -> web -> browser : see
  [[project-2026-10-29-jobsite-live-update-chain]] [ owner : 7 clean round
  trips ]
- ui : stage dropdowns close [ second click \ outside \ Escape ]
- editor keys bar : title click = F1, hybrid title, F1=Keys chip,
  modified by content checksum [ 7c8a19ecc .. 6793228df ]
- p7-commit : utf-8 messages [ 168aa99bd ] ; WY5 title reworded + force
  pushed with lease [ owner ran it ]
- coding cpu threads -1 [ pri 7 of 8 : 1.3 -> 2.5 t \ s ; host overrides on
  pri + yourum set to -1, backups *.bak-threads ]
- base.reply.value [ typed reply payload or a reason ]
- vision : MX plan + geo latency dns + browser as network peer
  [[project-2026-10-29-mx-topology-plan]]

## next, in order

1. **WY5 check** : the scan after the backlog run -- `site-yaml queue
   empty` only once delta drained, real `new` \ `known` per category, no
   `queue depth unknown` lines in pri's jobsite log [ that line = my
   reply-shape guess was wrong ]
2. **todo Q2K** : liveness check for STALE job data only [ site-yaml drops
   404 \ 410 at fetch time already ]
3. **ZRK round 2** : confirm window where something is lost, usage-count
   ordering [ flat counts per action, slow decay, reorder at start-up ]
4. parked : NCW attested binaries ; mail correlation -> yourum primary
   worker ; smtpd -> MX swap [ owner's order ]

## how to work [ cost me rounds today ]

- [[feedback-new-module-whitelist-and-resign-version-files]] : new module
  -> regenerate the zenka whitelist [ needs the cmd in the zenka's OWN
  access.cmd.usr.cube ] ; re-sign runs take the version files ; never pass
  unsigned files [ web-root html ] to p7_sign -- stage them, version-only
  sign run on cfg/protocol-7.src-ver
- an aborted sign run leaves files signed : the next run skips AND does not
  stage them -> check `git show --stat` before pushing [ 8cfac2a4b missed 3 ]
- pre-commit refuses a `# descr` over 55 chars [ new files only show it ]
- deploy with `reload source` keeps a running assessment alive ; a jobsite
  RESTART interrupts it [ the owed rescan picks the jobs up again ]
- owner's host froze once [ mouse only, reboot ] : the WSLg input freeze
  pattern, not today's work

#,,,,,..,,,..,.,.,,.,,..,,,..,.,,,,..,.,.,..,,..,,...,...,...,,..,,..,,.,,,..,
#2OAH2DZCM2TVK7MUUSZERYYM7EVNCYPPJERH4DHQR6UHDUPIECWY4NIGBYXG7GC7HGEAFFE5QO6R4
#\\\|QLTN336AFENJI7AOWJWDX7QPP7VXYYQDPLFGX5YRZCQLUUUONSF \ / AMOS7 \ YOURUM ::
#\[7]JX4NQ3RBUTOADR75SDO4HEUQ4DKL7BXBXRW6FYCFCNSCNZRH6KBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
