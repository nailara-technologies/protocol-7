---
name: project-2026-09-29-invoke-images-session-handover
description: handover of the 2026-09-29 \ 30 session [ invoke-web rebuilt, image index, v7-zenki pressure + keep-children + pid files, strict format-code, FOUR regressions found and fixed in base \ v7-zenki \ usage ] -- what runs, what is untested, what is open
metadata:
  type: project
---

**state [ 2026-09-30 ~20:00 ]** : last commit 1cc6a525e.
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
- keep-children [ 36a2d8259 ] : opt-in `restart.keep_children` in
  start.cfg ; on status error the registered children survive, a new
  instance claims them [ `v7-zenki.claim-children` ], grace 120s. tested
  live on mod-test [ keep, grace expiry, claim ]. invoke-web opted in --
  its first real use is untested. start.cfg changes currently only take
  effect after a v7-zenki restart [ the files ARE re-read on a reload -- the
  cause is open : data/tasks/v7-zenki-start-setup-runtime-reload.md ]

**regressions fixed this night** [ method : [[feedback-llm-fix-regressions-pattern]] ] :
- `eaab2467f` [ 07-18 ] log send-buffer request in one-shot init_reports ->
  most zenki lost their p7-log files. fixed bf6bc9570, see
  [[feedback-log-send-buffer-regression-eaab2467f]]
- `a40e31e96` [ 08-26 ] resolve hook inside dependency.ok -> pure checks
  [ zenka stop, `list dependency` ] cascade-started dependencies of
  non-running zenki. fixed 36a2d8259 : dependency.ok pure, start paths call
  dependency.ok_resolve
- `c9ffcacca` [ 09-24 ] heartbeat latency outliers at log level 1 every few
  seconds. now only >= 1s, level 2
- v7-zenki's OWN log branch never checked "already online" [ old gap ] :
  stuck after any pause while p7-log stayed online. fixed [ 5s resume timer ]
- usage kimi \ claude : a refresh cycle ending without a token failed the
  retry at once. now one more 30s cycle [ 954c341a6 ]
- plus : p7 syntax translator read y- \ s- \ m- .. key segments as quote
  operators [ kimi, 5b46b49ef ] ; list-context stat() under File::stat in
  8 modules ; `<[base.file.*]>` calls in 12 modules ; `not` \ `or`
  precedence bugs in my own code [ 3x ]

**tooling** : `bin/format-code -c` checks use strict + the loader's imports
and `use warnings`, P7 modules wrapped in a sub like the loader ; ptd -c is
syntax only. named subs in bin/Protocol-7's main:: are a transitional state
to convert : data/tasks/bin-protocol-7-main-subs-to-modules.md

**done since ~11:00 2026-09-30** :
- kimi review of 36a2d8259 \ bf6bc9570 \ cf4864498 \ 954c341a6 : one real
  finding -- power-x11 never set `<system.zenka.initialized>` [ no
  get_session_id, no init-done:TRUE ] -> its log send-buffer never resumed.
  fixed 627488de3 : `[init-done:TRUE]` in its zenka.v7, plus
  `base.callback.run_initialized` [ runs `<system.callbacks.initialized>`
  once, from verify-instance AND init-done:TRUE ; in all load-early lists ]
- kimi's "hybrid zenki [ nshell, user-edit, vault-edit ] lose logs too" was
  NOT real : the send-buffer's first idle send fires only at [zenka.loop],
  after init-done:TRUE set initialized. nshell logs as its SESSION name ->
  `<host>.taeki.zenka.log`, not `nshell` [ I searched the wrong name ]
- format-code `use warnings` + sub wrap committed [ 54997cf44 ] ; 5 real
  multi-word qw bugs -> data/tasks/multi-word-qw-as-string.md
- start.cfg reload loss REPRODUCED : a removed dependency survives a
  v7-zenki reload [ `p7c v7-zenki.list dependency` ], gone after restart ->
  task file updated 4b8b5c766. `v7-zenki.drop-dependency <zenka>` is the
  manual override [ drops it from ALL chains ]

**done ~18:00-19:30** [ a v7-zenki reload is enough for all of these ] :
- ba1b07685 start.cfg dependency changes applied by a RELOAD [ post_init
  rebuilt chains only for added zenki ; now all, every run ]
- 7fafe8d97 channels \ osd-logo \ power : start.on-demand [ idle timeout
  without it = error restart loop ] ; osd-logo is started \ ended by tile
- de0fa8a1d heartbeat FALSE `client not present` between a zenka end and
  sig_chld no longer an error [ kimi ]
- 65aa80072 pressure pieces 4 + 5 : restart gate [ critical, max 300s ;
  manual \ cube \ log target \ kept children exempt ] + start gate [ max
  45s ] [ claude opus dispatch -- aliases now 5.5 \ fable 5.1, b2b4f1170 ;
  pass max_budget ~15 for opus ]
- 177a79ef3 multi-word qw ; e5a3e6662 format-code .chk. out of src

**done ~19:30-20:00** : task files from design docs [ research-first ] --
v7-zenki-hot-self-restart, signed-command-interface, authorization-buffer,
nested-cube-network-segmentation, dream-idle-generation-first-step,
repo-pii-leak-prevention, zenka-hybrid-startup-followups. session \ work
start.cfg removed [ 1cc6a525e -- console-only zenki have NO start.cfg,
that is the marker ; user rule ]

**open, in this order** :
0. zenki whose start.cfg was REMOVED keep their v7-zenki entries after a
   reload [ `list dependency` still shows session \ work ] :
   `init_start_setup` resets config only for zenki still present, the
   chain rebuild then recreates them. fix : drop config \ setup \
   dependency entries of vanished zenki on reload [ v7-zenki-start-setup-
   runtime-reload.md ] -- clears on a v7-zenki restart meanwhile
1. NOT yet seen live : heartbeat race branch [ level 2 "session gone" ],
   pressure gates [ next critical episode ], keep-children on a real
   invoke.ai crash, `p7c invoke-web.fetch-missing <model>`
2. on-demand mismatch warning at v7-zenki start [ task step 4 ] ;
   per-zenka memory stats by the system zenka
3. coding-invoke-awareness.md ; images \ elfdb planning,
   [[project-images-elfdb-planning-base]]

**Why:** a very long session [ >900k tokens ] with many interlocking fixes ;
compaction would lose which parts are live, which are only tested on
mod-test, and which regressions were found.
**How to apply:** start here for invoke-web, v7-zenki keep-children \
pressure \ pid files, the log send-buffer, dependencies or usage refresh.

#,,.,,.,,,.,.,...,..,,...,.,,,,..,.,.,...,...,..,,...,..,,.,,,,..,,.,,.,.,...,
#IXYUYVFOJ6YFA5ZCHU7G3I3X22WUDNHFXS2CECLKDPC22JSCU3TUX3S2YW6VU6IMAORPE3PLQDHUA
#\\\|MASQZ5JYZLBMPMV57DGGC3GSOF4EQGX7BH5XI5Y276QGL5XM5PV \ / AMOS7 \ YOURUM ::
#\[7]Z3BP7BN4RUSCDW7HHHKRLXQ36JM6J4Y4AYKFX45ISDP4IAJQESCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
