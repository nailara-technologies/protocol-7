---
name: session-handover-pulse-stage2-v7
description: 2026-11-26 handover -- windows-host pulse for mpv, n7fs place safe stop, watcher stage 2 live [ place.complete@azurum ], v7-zenki spin incident, v7 root process + litter design drafts
metadata:
  type: project
---

state is DERIVED first : `p7c coding.handover`, `p7c coding.sessions`, `p7c usage.plan`.
base pushed to a8a0428c08 ; azurum pulled cf76eb867c [ a8a0428c08 = design docs only ].

## landed today

- d918dac81f powershell host-tools.cfg [ winget \ url, BMW-384 pin in
  data/state/powershell.host-tools.state, fetch on first use ] ; pulse-start \ pulse-status :
  pgaskin pulseaudio v5 portable, tcp <wsl host ip>:4713, acl = wsl network. the windows
  firewall rule came from the owner's allow click [ the plan said none ]. old /user/pulseaudio removed
- 894b175484 mpv.pulse.select_server per spawn : cfg mpv.pulse_server > wslg pactl info >
  host [ routes powershell.pulse-start, reply-wait timer ] ; ipc socket deadline from
  base.interval.next [ mpv-socket-wait ~13 s, the old 4.2 s missed under memory pressure ].
  owner confirmed audio. host path never exercised live [ wslg was answering ]
- dda1830e18 \ 0f7d987f01 n7fs place : closing line [ complete \ nothing to place \ stopped ],
  INT \ TERM \ HUP set a flag, seal_nodes stops at the next node and commits, 2nd signal ends
  at once ; N7FS_TEST_FAULT_SIGNAL + fault point seal:node ; test-n7fs-placement 81
- c6c2d99b90 watcher stage 2 slice, LIVE : azurum events.signals-since -> desktop events
  pulls `::: azurum` as unix user protocol-7 [ stream_child, events-remote-pull rhythm ],
  fail closed both ways, dedup by BMW id, raised as place.complete@azurum -> notify -> the
  session. n7fs already raised place.complete with the real rc [ next #1 done ]
- cf76eb867c system.disk.post_init waits for system.callbacks.initialized ; remote pull
  success logs at level 1 \ 2
- a8a0428c08 data/tasks/v7-zenki-anchor.md + litter-roaming.md [ DRAFTS ]

## temporary set-up [ owner : dedicated, temporary until something better ]

- WSL protocol-7 : ~/.ssh/id_events_pull + Host azurum [ HostKeyAlias azurum ], p7 key
  events-pull.base, overlay /etc/protocol-7/host-config/events.cfg [ the pulls live there,
  not in the shared zenka.v7 ]
- azurum : ~protocol-7/.ssh/authorized_keys restrict,port-forwarding,permitopen=127.0.0.1:42,
  command=/bin/false ; incoming/events-pull.public linked from authorized/cube
- my set-up script REPLACED protocol-7's known_hosts -> zulum link down ~1 h, repaired
  [ [[never-overwrite-other-users-files]] ]

## incident : v7-zenki spin [ design answer : the v7 draft ]

old v7-zenki [ pid 229, root ] : log silent from 2026-11-25 14:30 [ right after starting
on-demand kimi ] while still working ~20 h ; then ~2 h at 100 % cpu, empty kernel stack,
signal 53 \ TERM ignored -> one long perl op, likely a backtracking regex. evidence gone with
the restart. nothing in the tree can act : every zenka is its child, cube can only drop the
connection [ needs v7-zenki's loop ]. -> data/tasks/v7-zenki-anchor.md

## design decisions so far [ owner ]

- a root process ABOVE v7-zenki, the unit's main process [ a sibling makes systemd start a
  second v7-zenki ] ; minimal, everything preloaded, small memory ; pulse pipe from the event
  loop ; /proc evidence before action, gdb last ; reporting by the NEW v7-zenki
- name : `v7`, process title without host prefix ; v7-zenki's name NOT settled [ `v7-`
  redundant, `zenki` taken ] ; `zenki` = the console command [ zenki.console.* exists ] ;
  litter = a named group, mainly a team sent roaming [ litter-roaming.md ]
- first get the design clean, no code before it -- the owner wants features that make it an
  improvement, not overhead [ draft lists socket handover, crash-loop safe mode, verified
  start, restart history, oom layers ]

## next

1. v7 design : naming block, wrapper form [ beside protocol-7-gtk3 or shared entry ], perl \
   c, first-version features
2. log-silence check in the system zenka [ would have caught 14:30 ]
3. find why v7-zenki's log stopped after the kimi on-demand start [ with next #18 :
   handover write wakes kimi via kimi.acp-status ]
4. install gdb on the hosts [ a hung perl process : `gdb -batch -p <pid> -ex bt` ]
5. older next list : handover 18 [ project-2026-11-25-handover-pm-native-hub-watchers.md ]
   items 2-16, 18

#,,.,,,,,,,,,,,,.,.,.,..,,...,..,,.,,,,.,,,,.,..,,...,...,.,,,,,,,...,,.,,.,,,
#ENXHCHRXDO2E7MMLA5G3KK7RKXTVBA6Z6Y3N7HPVTK5ZDHYEGTX7EVL72CRAZND56APCVUUWJYLF2
#\\\|KZN5SO7L2EO7GK747U3ON273CFFBZGBSUCIBMY6YINH3I7BZ45I \ / AMOS7 \ YOURUM ::
#\[7]YULAJPUGGREFRZLFYRGXZNVZQQUDKODJWGP7EJLIK3LPWRNQ4WCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
