---
name: project-2026-09-29-invoke-images-session-handover
description: handover of the 2026-09-29 \ 30 session [ invoke-web rebuilt, image index, v7-zenki pressure + keep-children + pid files, strict format-code, FOUR regressions found and fixed in base \ v7-zenki \ usage ] -- what runs, what is untested, what is open
metadata:
  type: project
---

**state at the end [ 2026-09-30 ~09:30 ]** : working tree clean, last commit
62f67700f. invoke.ai rendering [ start_paused = startup ], coding zenka can
run next to it [ Qwen3.8-9B -ngl 27 + invoke.ai fit, critical pressure but
stable -- a coding \ invoke.ai feedback loop is feasible on this host ].

**invoke-web** [ see [[reference-invoke-web-run-user-and-invokeai-facts]] ] :
- output through a transport FILE /var/run/.7/invoke-web/invokeai.out
  [ O_APPEND, PYTHONUNBUFFERED ; runtime dir via
  `base.file.zenka_dir.run_path` ], inotify reader from a saved offset,
  ring buffer `invokeai` persisted by p7-log
- queue hold [ status 'held' while invoke.ai starts -- its processor
  dequeues ~80s before the api is up ] ; recovery chain `recover.*` for cuda
  errors and zenka crashes, retries EXACTLY the interrupted items ; own
  retried record ; requeue \ requeue-failed \ requeue-cancelled
- render check in its own timer ; every finished render indexed
  [ index.on_render ] ; autofetch [ default off, blake3 verified in a
  private dir ] -- NOT live-tested : `p7c invoke-web.fetch-missing <model>`

**v7-zenki** :
- pressure sampler [ `p7c v7-zenki.pressure` ] ; heartbeat timeout extended
  under pressure [ 3x \ 6x ] instead of an error restart -- verified live
- report-pid-file : removed only on planned ends -> crash detection
- keep-children [ 98da67302 ] : opt-in `restart.keep_children` in
  start.cfg ; on status error the registered children survive, a new
  instance claims them [ `v7-zenki.claim-children` ], grace 120s. tested
  live on mod-test [ keep, grace expiry, claim ]. invoke-web opted in --
  its first real use is untested. start.cfg changes currently only take
  effect after a v7-zenki restart [ the files ARE re-read on a reload -- the
  cause is open : data/tasks/v7-zenki-start-setup-runtime-reload.md ]

**regressions fixed this night** [ method : [[feedback-llm-fix-regressions-pattern]] ] :
- `eaab2467f` [ 07-18 ] log send-buffer request in one-shot init_reports ->
  most zenki lost their p7-log files. fixed e697008ad, see
  [[feedback-log-send-buffer-regression-eaab2467f]]
- `a40e31e96` [ 08-26 ] resolve hook inside dependency.ok -> pure checks
  [ zenka stop, `list dependency` ] cascade-started dependencies of
  non-running zenki. fixed 98da67302 : dependency.ok pure, start paths call
  dependency.ok_resolve
- `c9ffcacca` [ 09-24 ] heartbeat latency outliers at log level 1 every few
  seconds. now only >= 1s, level 2
- v7-zenki's OWN log branch never checked "already online" [ old gap ] :
  stuck after any pause while p7-log stayed online. fixed [ 5s resume timer ]
- usage kimi \ claude : a refresh cycle ending without a token failed the
  retry at once. now one more 30s cycle [ 554362c1c ]
- plus : p7 syntax translator read y- \ s- \ m- .. key segments as quote
  operators [ kimi, 62f67700f ] ; list-context stat() under File::stat in
  8 modules ; `<[base.file.*]>` calls in 12 modules ; `not` \ `or`
  precedence bugs in my own code [ 3x ]

**tooling** : `bin/format-code -c` checks use strict + the loader's imports
[ not yet `use warnings` -- would have caught an `or` bug, open ] ; ptd -c is
syntax only. named subs in bin/Protocol-7's main:: are a transitional state
to convert : data/tasks/bin-protocol-7-main-subs-to-modules.md

**in flight at ~11:00 2026-09-30** :
- kimi REVIEW of 98da67302 \ e697008ad \ ab0d22e5b \ 554362c1c [ read-only,
  session adf6c425-6ac9-490c-acbc-c76c217a66c7 -> kimi_check_status ] --
  check its findings, each needs a concrete failure scenario
- bin/format-code : `use warnings` + P7 modules compiled as a sub body like
  the loader [ uncommitted, needs signing ]. first attempt flagged 38 files,
  mostly artifacts ; fixed version found 2 real ones so far :
  `letsencr.cmd.enroll:110` multi-word qw in scalar [ error text = 'error' ],
  `weather.cmd.current:9` comma in qw [ harmless ]. full run result in
  /tmp/claude-1000/fc-warn2.txt
- T-C PASSED [ starting mod-test started its missing dependency models ]
- new task files for kimi : v7-zenki-start-setup-runtime-reload.md [ files
  ARE re-read on reload, loss happens in the merge ],
  zenki-ondemand-config-consistency.md, v7-zenki-heartbeat-offline-race.md,
  pressure brief pieces 4-5

**open, in this order** :
1. kimi review findings + commit format-code [ see in flight ]
4. invoke-web keep-children first real run [ a crash while rendering ]
5. pressure brief pieces 4-5 [ defer restarts \ starts while critical ] +
   per-zenka memory stats by the system zenka
6. coding-invoke-awareness.md ; images \ elfdb planning,
   [[project-images-elfdb-planning-base]]

**Why:** a very long session [ >900k tokens ] with many interlocking fixes ;
compaction would lose which parts are live, which are only tested on
mod-test, and which regressions were found.
**How to apply:** start here for invoke-web, v7-zenki keep-children \
pressure \ pid files, the log send-buffer, dependencies or usage refresh.

#,,,.,.,,,,,,,,.,,.,,,,,,,,.,,..,,,,,,,,,,,..,..,,...,...,,,.,,..,,..,.,.,,,.,
#MQ7XS65SQ2W5NZDUKDTMORUCQBOXNM765L5ZLEJ3ZZULFBFLXONP4R6W52D7EAYYH65BKZZAJULGI
#\\\|OLXQU3OICF4O2UU7JECGSLGAR7LCGLJAMX7VXD47NOEDUYNY5S6 \ / AMOS7 \ YOURUM ::
#\[7]YD4ZHHLFYV25L2ESVTCUG6KBNVL3YZPT5MKHWWBSBZYCKSLH7AAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
