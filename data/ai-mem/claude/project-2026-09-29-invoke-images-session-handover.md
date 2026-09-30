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
  its first real use is untested. start.cfg changes need a V7 RESTART
  [ start setups are only read at v7-zenki's first start ]

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

**open, in this order** :
1. T-C at the next backend restart : mod-test `dependencies = cube models`,
   models stopped -> starting mod-test must start models [ ok_resolve ]
2. `use warnings` in format-code's check preamble
3. mod-test start.cfg : remove the keep-children test lines when done
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

#,,..,,,.,,.,,.,.,.,.,,,.,..,,,,.,.,,,,..,...,..,,...,...,..,,.,,,.,.,..,,,,,,
#JHJDXLLG7HGNILVG6XYYLTPHILCDRPOZWLFVDBO4XEUPSUS57BWF3VDSNR33WVJYA3BLQ45D4CSQU
#\\\|RC7WYIOUCNUSVMPIPGITJEZ44AVTENFENYXE2TK2APMYGO4LD6D \ / AMOS7 \ YOURUM ::
#\[7]IJ3MDDH4RL4VP3SNCSXGZNTW3EOR7OFFDAKBTCTKDYIO6W566SCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
