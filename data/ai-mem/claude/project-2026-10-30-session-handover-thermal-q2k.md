---
name: project-2026-10-30-session-handover-thermal-q2k
description: START HERE 2026-10-29 late [ last 344e62e56 ] : Q2K liveness deployed [ delta + pri ], thermal steps 1-5 committed, watch-only in local task over night ; GDX weather race fixed ; next : read the night snapshots, wire the verdict into the worker pool, then thermal_gate on
metadata:
  type: project
---

**landed 2026-10-29 evening [ 553f3e465 .. 344e62e56 ]**

- Q2K [ 93962d8a1, deployed delta + pri ] : site-yaml.liveness [ front of
  the fetch queue, deferred json verdict ] + jobsite.dispatch.next gate
  [ stale = newer of fetched_at \ live_at > liveness_max_age 12 h ]. gone
  -> trash [ new \ review only ], unknown -> slot released. delta cmd tested
  live [ 404 gone, re-posted aug job alive ] ; the GATE has not fired yet
  -- look for 'stale job data' in pri's jobsite log
- WY5 : queue-depth fix holds [ 801 queued, polling, no instant empty ] ;
  the final drain line + per-category counts still unread
- thermal [ design data/md/design/THERMAL-AWARE-LOCAL-WORKER.md ] : all
  modules src/thermal.* , test bin/test-scripts/test-thermal-gate.pl [ 91 ].
  local task runs it WATCH-ONLY [ task.cfg.thermal_gate off ] ; task polls
  weather.temp every 600 s. at 23:20 : outdoor 6.36 -> amp 1.35, gpu 53,
  baseline 53, cold, night marks 63.8 \ 83 [ ceiling ]
- GDX [ b28f5b2b5 ] : weather getters park callers while the first data is
  pending [ weather.parent.park_pending \ answer_parked ] ; tested with
  weather.clean-cache + terminate : first weather.temp 3.5 s, real value

**next, in order**

1. night snapshots : `p7c task.dump '^task\.thermal'` + `'^thermal\.outdoor'`
   before and after 06:00 [ night window 22:00-06:00, heating on at 06:00 ]
2. wiring [ claude, live scheduling ] : thermal.verdict into the worker
   pool [ run slow no_new pause unload ], busy signal for thermal.idle.* so
   the baseline learns from REAL idle [ owner idea ], start.ready before a
   model spawn, mem gate fed by thermal.mem.read. then thermal_gate on
3. WY5 drain check on pri ; ZRK round 2
4. maybe : Cache-Control no-cache for the jobsite vhost index.html [ a
   stale cached page broke sync, shift-reload fixed it ]

**how to work**

- kimi k3.1 thinking low = 7d +1 per spec-precise step [ 7 runs today ] ;
  claude reviews every diff : caught 1 bug \ spec slip in most runs
  [ orphan hash, baseline creep, warm = no_new, copied park block ]
- a kimi 'before' reproduction can pass for the wrong reason [ cache ] :
  re-run it with the state forced
- WSL dns here drops briefly [ 10.255.255.254 ] : retry before diagnosing

related : [[project-2026-10-29-thermal-aware-local-worker]],
[[project-2026-10-29-session-handover-jobsite-live-updates]]

#,,,.,,.,,,,,,.,,,,,.,.,.,.,.,.,.,.,,,...,...,..,,...,...,,,.,.,.,.,.,.,.,..,,
#QWOURZIKNQODRJKEQNZUOZMY7U2MMSR3ELAAD2JTCV5RXJ7TBTMY6OMQZPRD6TH2O5R6RPGHWLEQS
#\\\|DBF5GCX2GYQ3RKF7XTXFI36QG4ITGQYVCSJJN26MMO4UHW2DYTY \ / AMOS7 \ YOURUM ::
#\[7]VFQPAZVHFNXRILEQNNQGP6DBS7IE7WPMOT54UPD4ILG6ODPRI2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
