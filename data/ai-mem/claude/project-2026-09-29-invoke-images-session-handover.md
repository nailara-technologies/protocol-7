---
name: project-2026-09-29-invoke-images-session-handover
description: handover of the 2026-09-29 \ 30 session [ invoke-web rebuilt, image index, v7-zenki pressure + keep-children + pid files, strict format-code, FOUR regressions found and fixed in base \ v7-zenki \ usage ] -- what runs, what is untested, what is open
metadata:
  type: project
---

**state [ 2026-09-30 ~18:00 ]** : working tree clean, last commit 08577b71f.
invoke.ai rendering [ start_paused = startup ], coding zenka can
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
and `use warnings`, P7 modules wrapped in a sub like the loader ; ptd -c is
syntax only. named subs in bin/Protocol-7's main:: are a transitional state
to convert : data/tasks/bin-protocol-7-main-subs-to-modules.md

**done since ~11:00 2026-09-30** :
- kimi review of 98da67302 \ e697008ad \ ab0d22e5b \ 554362c1c : one real
  finding -- power-x11 never set `<system.zenka.initialized>` [ no
  get_session_id, no init-done:TRUE ] -> its log send-buffer never resumed.
  fixed be99ae2c2 : `[init-done:TRUE]` in its zenka.v7, plus
  `base.callback.run_initialized` [ runs `<system.callbacks.initialized>`
  once, from verify-instance AND init-done:TRUE ; in all load-early lists ]
- kimi's "hybrid zenki [ nshell, user-edit, vault-edit ] lose logs too" was
  NOT real : the send-buffer's first idle send fires only at [zenka.loop],
  after init-done:TRUE set initialized. nshell logs as its SESSION name ->
  `<host>.taeki.zenka.log`, not `nshell` [ I searched the wrong name ]
- format-code `use warnings` + sub wrap committed [ b4dbf5e76 ] ; 5 real
  multi-word qw bugs -> data/tasks/multi-word-qw-as-string.md
- start.cfg reload loss REPRODUCED : a removed dependency survives a
  v7-zenki reload [ `p7c v7-zenki.list dependency` ], gone after restart ->
  task file updated 08577b71f. `v7-zenki.drop-dependency <zenka>` is the
  manual override [ drops it from ALL chains ]

**open, in this order** :
1. kimi task files [ after the reset ] : multi-word-qw-as-string,
   format-code-chk-files-out-of-src, v7-zenki-start-setup-runtime-reload,
   zenki-ondemand-config-consistency, v7-zenki-heartbeat-offline-race
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

#,,.,,..,,,.,,.,.,,.,,...,,,.,,..,,,,,.,,,...,..,,...,..,,..,,.,.,.,,,,..,,.,,
#5AAM5MBD6FLFF4ZKTM5XWL6XHNDSAAGXUEKCNV4LMTKJY2TB4AOUYCAGNVS22RGPHBGU6P6OKOMRY
#\\\|KO6NG5E2PTCKGS7RAQ3YWWAMKXPXW2KAXLS4EESFPBRYJEOKGDK \ / AMOS7 \ YOURUM ::
#\[7]RW4FAWI34LRS7OVIUFNOXRLEXBMQDBJV5E52N7QN62BT5GFM5SAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
