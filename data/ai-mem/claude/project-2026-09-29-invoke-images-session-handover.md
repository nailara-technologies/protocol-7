---
name: project-2026-09-29-invoke-images-session-handover
description: handover of the 2026-09-29 \ 30 session [ invoke-web rebuilt + recovery chain, image index, pressure sampler + pressure-aware heartbeat, pid-file registry, strict format-code ] -- what runs, what is open, where the briefs are
metadata:
  type: project
---

**state at the end [ 2026-09-30 ~01:00 ]** : invoke.ai rendering the queue,
invoke-web `start_paused = startup`, v7-zenki pressure sampler live. last
commits 6eabe182c .. d8908bf8d, working tree clean except kimi's pending
legacy strict fixes [ data/tasks/legacy-zenki-strict-errors.md ].

**invoke-web** [ see [[reference-invoke-web-run-user-and-invokeai-facts]] ] :
- image index done : ~49k images, BMW-L13 keys, state/image-index.db ;
  idle-watcher job, chunked reads with event.once, backup in a forked child
- render outcome : `render done` \ `failed` \ `suspicious` [ l2i node ] ;
  the result-image check [ black \ flat ] runs in its own timer
  [ handler.render_check ] -- inline it blocked past the heartbeat
- recovery chain `recover.*` : cuda error [ gpu.recover, max 3 \ hour ] and
  zenka crash [ recover.after_crash : pid file left + process gone, max 3 \
  hour ] -> pause, restart, retry EXACTLY the interrupted items [ recorded by
  queue.hold while invoke.ai is down : status in_progress ] + cuda failures
  -> resume. own retried record state/retried-items [ survives a prune ]
- queue hold : invoke.ai's processor starts resumed and dequeues ~80s before
  its api is up -- pending items -> status 'held' while it is down, released
  after the startup pause. start_paused : no | yes | startup
- requeue \ requeue-failed \ requeue-cancelled [ list, all, text filter,
  cancel times ] ; requeue-missing ; autofetch [ off \ ask \ on, default off ;
  blake3 verified in a private 0700 dir ; symlink \ hard link \ owner checks ]
  -- NOT live-tested yet : `p7c invoke-web.fetch-missing <model>`

**v7-zenki** :
- pressure sampler [ psi, swap rate, MemAvailable ] : `p7c v7-zenki.pressure`
  ; elevated from avg60, critical from avg10 \ avg60, leave after 13 samples
- heartbeat : under elevated \ critical pressure [ or a latest avg10 over
  the critical threshold ] a late reply extends the timeout [ 3x \ 6x 17s ]
  instead of an error restart. cause found 2026-09-29 : model loads push
  `mem full avg10` to ~19 -> direct reclaim stalls every process
- report-pid-file : pid files removed only on teardown, v7 startup, manual
  terminate \ restart ; an error restart keeps them -> crash detection.
  owner uid recorded in a sidecar, lstat, re-registration = owner refresh
- host : vm.swappiness 10 [ /etc/sysctl.d/60-swappiness.conf ]

**tooling** : bin/format-code -c checks use strict + loader imports [
fbbc58194 ], see [[feedback-use-format-code-not-perl-c]] ; compile report
hints for `my $call` \ `my $reply` in .cmd. ; base.cfg_bool knows on \ off.

**open, in this order** :
1. index new renders at `render done` [ small : handler.render_check has the
   image content already ]
2. data/tasks/v7-zenki-keep-children-on-crash.md : invoke.ai survives an
   invoke-web restart [ SIGPIPE on the output pipes first ]
3. pressure brief pieces 4-5 [ defer restarts \ starts while critical, atom
   start gate ] + per-zenka memory stats collected by the system zenka
4. coding-invoke-awareness.md ; images \ elfdb planning, see
   [[project-images-elfdb-planning-base]]

**Why:** a long session with many interlocking parts ; compaction would lose
which pieces are live, which are untested and why they were built.
**How to apply:** start here when invoke-web, v7-zenki pressure \ pid files
or the image index come up ; check `p7c invoke-web.status`, `index status`
and `v7-zenki.pressure` first.

#,,,,,,..,...,,,,,,,,,,,.,,..,,..,.,.,...,.,,,..,,...,...,...,.,,,.,.,,,,,,.,,
#KXC7J2ZFCXR57A72CAPK4TQ5USBP2VK3OGPN4GKACKA625QBL6ASPFJRFBPMQC4ORC2K6KAQTJ7Z6
#\\\|I56HRGSZXHNNBPWUCP2T2DUFYDH4FHJZORUFFPKCD25OCTZFPP4 \ / AMOS7 \ YOURUM ::
#\[7]NY6IVQTCMYQAP6JFMYULE6KRHICEIY7B2BNSM7IBW7CJWV77ZGCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
