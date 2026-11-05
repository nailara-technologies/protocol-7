---
name: project-2026-11-05-session-handover-transport-claims
description: START HERE 2026-11-05 [ 485d04329, pushed ] : transport never blocks, oversized packets refused, jobsite scan lists in parts, task keep-alive + supersede, sign agent fixes ; open items listed
metadata:
  type: project
---

session 2026-11-04 \ 05 : 15 commits 24cafb80c .. 485d04329, all pushed to `hub` [ github ].
deployed : pri [ srv-U ] + delta [ srv-V ] at ea1a6fbeb+ [ jobsite \ site-yaml ], srv-U \ srv-F \ srv-A at ab22753a5+
[ task keep-alive ], pri also 4413c6fe3 [ httpd ]. a15de54fd [ pull-git ] + 485d04329 [ deps ] NOT pulled yet.

**done**
- 0fd160c6a -> REVERTED by 70a02805e : a permanently non-blocking cube socket broke every synchronous
  exchange [ base.get_session_id whoami, ~10 X-11 \ web-browser \ login-screen helpers ] -- zenki failed
  start-up 0110. real fix : base.s_write 5th param = send + MSG_DONTWAIT on sockets, used only by
  base.handler.write [ event drain ]. covers cube links, external tcp, ssh-w socketpair, stdio transport.
- ccecebb0b base.handler.command : a packet larger than size.buffer.input [ 242707 ] paused the session for
  good. now FALSE reply to its id [ NDAQSOR ] + drop to its end across reads : ignore_ml_packet [ '.' line ],
  ignore_line [ oversized single line, '+' tail -> continues as packet ], ignore_ml_midline [ partial lines,
  no injection from the remainder ]. new templates need `reload all` [ reinit ], not `reload source`.
- jobsite remote scan [ ea1a6fbeb + 43f684630 ] : skip \ block lists [ 226 KB ] sent once per scan in
  <= 32 KB parts via site-yaml.scan-lists, imports carry lists=<scan-id>. LIVE ok [ skipped > 0 ].
  a NEW remote command needs FOUR grants : cube access.users [ remote-fetch ], cube access.zenki
  [ jobsite + external.*. ], external zenka.v7, AND the target zenka's own access.cmd.usr.cube.
- 330e9fd5e jobsite watch : 'done' without result re-sends task.wait-done ; job.load_all kept dropping
  watch_extensions [ '1 of 24' forever ] + watch_kind.
- c4746e3bd + ab22753a5 task claims : task.claim_expire [ pending again, failed at max_attempts ],
  task.touch keep-alive + task.claim_lease [ 600 s, in claim reply ] ; sweep each minute, lease only for
  keep_alive claims [ kimi \ remote task-worker keep stale_claim_secs 6 h ] ; models renews every 20 s while
  its coding instance lives, drops at the same deadline [ models.task.drop-claim, late result discarded ] ;
  jobsite.dispatch.supersede fails the previous task on a new attempt [ closes the double-run gap ].
- sign agent : e6dbe7584 fresh-start unsigned-code gate [ y \ n \ d before passphrase ] + one log line
  per file [ harmonic retries ] ; 3b29aaf11 refused signature shown, requester-gone check each loop pass,
  AMOS7::TERM confirm_key cancel_fh [ withdrawn prompt ]. test-p7-sign-run stubs p7c [ was sending real
  'signing request' notifications ].
- 24cafb80c update-signatures :stage: only signed + unstaged-valid ; 5c66c9994 invoke-queue-harmonize both
  dbs ; 4413c6fe3 httpd refused POST [ 405 \ 413 ] closes [ scanner body parsed as 'REQ:-qO-' ] ;
  a15de54fd process_zenka_end honours restart.disabled for exec-external [ pull-git looped on error ] ;
  485d04329 no deps markers when root resolves to /usr/local/protocol-7.

**open, in order**
1. kimi results unreviewed + uncommitted : s2c idle \ blank \ dpms [ src/login-screen.idle_policy +
   login-screen.cmd.idle-lock, untracked ], s2b draft [ data/md/design/LOGIN-SCREEN-ZENKA.md section 9 ].
2. delete the 23 untracked cfg/zenki/cube/deps/src-used/devmod* on delta, srv-F, srv-A [ ask first ] ;
   until then pulls there need `git stash push -u -- cfg/zenki/cube/deps/src-used` + pop.
3. devmod-ack [ LAST, design ] : '. weather . send.local: unknown target : cube [ cmd : v7-zenki.devmod-ack ]'
   -- the plan was devmod requests WITHOUT network ; current version races + is noisy everywhere.
4. owner's editor fixes [ separate topic ] -- includes issues of the todo list command itself.
- watch : delta link heartbeat timeouts [ route collapsed between scans ] ; srv-A models 'subscribe refused'
  towards external.pri.task [ likely transient at the task restart ].
- delta's v7-zenki predates :wait-done: -> use :wait-down: there until it pulls.

related : [[feedback-sync-helpers-need-blocking-cube-socket]] [[feedback-ondemand-helper-recursion-in-deps-register]]

#,,,,,...,...,...,,,,,,.,,..,,...,,,.,,,,,,,,,..,,...,...,.,.,,,,,,,.,..,,..,,
#NFACBMFVS7XC6BXQYP2QOIEBWPCQYMG42YBQE7WT7G7EAUBWWTKHZ7LRXMG7OX6SWLQVYTBJOULF4
#\\\|BOHHZ3DTLFAJII22B7EGEW4P5KLLXAGIXM64GIHIDTECWRXSEP4 \ / AMOS7 \ YOURUM ::
#\[7]JTC4UXIB6IMFXBKKTYE7J3JPOXTIYCNSTSEL3KN3LCKK5BYCH4BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
