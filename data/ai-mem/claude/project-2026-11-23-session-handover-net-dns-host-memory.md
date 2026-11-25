---
name: session-handover-net-dns-host-memory
description: NEWEST 2026-11-23 : host-build stage 2, net zenka pieces 1-5c, dns policy + behaviour, sign agent queue, host-memory \ base-os-manifest briefs ; tier B X220T import running on azurum
metadata:
  type: project
---

## landed 2026-11-23 [ all on hub base, pulled on atom zulum delta yourum azurum ]

- 6e99a42c47 p7-host-build stage 2 : host-root, pins both ways, access.p7_user, wol .link
- 3e7de75f35 \ c02927a1ef \ fa7814bf52 \ 7584fe42ce : power WoL commands, net zenka pieces 1-4
  [ net.interfaces \ status \ event \ leases \ macs, dhcpcd hook bin/dhcpcd-hook/, wlan root
  helper bin/p7-wlan-helper with ssid b32: default, leases persisted ]
- 7bd8bd90b6 : nodes per-network observations, power.wake parallel + never external, interface
  roles lan \ external \ unknown, system.disk-register \ update \ done, n7fs assimilate registers
- 456e756e2c : format-code keeps 'not ( .. )->@*' spacing ; nameserv.set-upstreams per source
- 65d1dfb8b9 : dns policy per network [ trusted split held blocked, timed trust, no own-name leaks ]
- 043c45a44e : dns behaviour probe [ open filtering intercepting blocking-outside ] + a real
  bind bug fix in nameserv.cache.forward.try [ non-blocking socket without local port ]
- 67cd97de0a : p7-sign-agent request queue, end-of-run display, TERM confirm_key watch \ guard
  [ owner must ctrl-r the idle agent once to load it ]
- briefs : net-zenka.md [ roaming, dns by role, refinements ], host-memory.md [ first line,
  two versions, strands, secure reference bundle, awareness ladder, sealed-until-known, epoch
  buckets, correlation zenka, rules bound to data, lineage ], base-os-manifest.md
- SUBSTRATE-SYNTHESIS.md question 3 decided [ identity tree \ occupancy view ; re-creation exact
  up to tracked entropy ]
- pending sign at writing : p7-log anon tokens per epoch window [ kimi, 53 tests ]

## running \ next

- azurum tmux tierB : X220T `n7fs assimilate` [ root, HOME=/users/taeki ] ; repair + verify done
  [ 497499 nodes, 152518 orphan assignments quarantined = leftovers, rescue category in batch ]
- after import : category rescue-b -copies 1, set-category tree:tierB- rescue-b, place -dry-run
  [ owner looks ], then place
- dns piece 2 : encrypted fallback [ dot 853, doh 443 ] -- claude dispatch
- p7-log shredding step : random per-window table key, lookback horizon
- MCP server : a long claude dispatch blocks other protocol-7 tools [ p7_commit_prepare,
  kimi_dispatch hung 30 min ] -- commit directly via bin/dev/p7-commit prepare \ commit meanwhile
- rules : one pending sign at a time [[one-pending-sign-at-a-time]] ; quiet cases for network
  actions [[network-silence-is-a-feature]]

## owner direction

- moving from modules toward templates \ rules \ declarations ; trust as a rhizome of signed
  and signing nodes, position \ proximity decides weight ; identity = content, time = position

#,,..,...,,.,,,.,,..,,,..,,,.,..,,,,,,,,,,.,.,..,,...,...,,.,,,,.,...,,,.,,,,,
#RDL2R6I223SBAP4TQ6PLL4SLPAED4NJP6ILIU2X2L57AF5AQINXQ7AYNL2QLXSOCWSQ36CWSLRDGA
#\\\|7BPMDMRE63O3CUWPER6X2X65O6S6YNN6N2LNCT56X2E2MANQERY \ / AMOS7 \ YOURUM ::
#\[7]WZG6R2ITWDHX4YGU2NH3CZ3RLZVOSBF2YRCKOKWCGC6HT4JJJABY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
