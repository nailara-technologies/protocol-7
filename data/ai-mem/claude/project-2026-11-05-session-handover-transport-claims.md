---
name: project-2026-11-05-session-handover-transport-claims
description: START HERE 2026-11-05 [ 0d60550d7, pushed ] : transport never blocks, oversized packets refused, jobsite scan lists in parts, task keep-alive + supersede, sign agent fixes ; open items listed
metadata:
  type: project
---

session 2026-11-04 \ 05 : 15 commits b0b306db3 .. 0d60550d7, all pushed to `hub` [ github ].
deployed : pri [ srv-U ] + delta [ srv-V ] at ce4e687df+ [ jobsite \ site-yaml ], srv-U \ srv-F \ srv-A at db198e73c+
[ task keep-alive ], pri also b3bba48f2 [ httpd ]. 2b73d5537 [ pull-git ] + 0d60550d7 [ deps ] NOT pulled yet.

**done**
- 5567aa7fa -> REVERTED by 9220834b9 : a permanently non-blocking cube socket broke every synchronous
  exchange [ base.get_session_id whoami, ~10 X-11 \ web-browser \ login-screen helpers ] -- zenki failed
  start-up 0110. real fix : base.s_write 5th param = send + MSG_DONTWAIT on sockets, used only by
  base.handler.write [ event drain ]. covers cube links, external tcp, ssh-w socketpair, stdio transport.
- 54c66ac33 base.handler.command : a packet larger than size.buffer.input [ 242707 ] paused the session for
  good. now FALSE reply to its id [ NDAQSOR ] + drop to its end across reads : ignore_ml_packet [ '.' line ],
  ignore_line [ oversized single line, '+' tail -> continues as packet ], ignore_ml_midline [ partial lines,
  no injection from the remainder ]. new templates need `reload all` [ reinit ], not `reload source`.
- jobsite remote scan [ ce4e687df + 7823884fc ] : skip \ block lists [ 226 KB ] sent once per scan in
  <= 32 KB parts via site-yaml.scan-lists, imports carry lists=<scan-id>. LIVE ok [ skipped > 0 ].
  a NEW remote command needs FOUR grants : cube access.users [ remote-fetch ], cube access.zenki
  [ jobsite + external.*. ], external zenka.v7, AND the target zenka's own access.cmd.usr.cube.
- 43f1e63ba jobsite watch : 'done' without result re-sends task.wait-done ; job.load_all kept dropping
  watch_extensions [ '1 of 24' forever ] + watch_kind.
- b1c2bae20 + db198e73c task claims : task.claim_expire [ pending again, failed at max_attempts ],
  task.touch keep-alive + task.claim_lease [ 600 s, in claim reply ] ; sweep each minute, lease only for
  keep_alive claims [ kimi \ remote task-worker keep stale_claim_secs 6 h ] ; models renews every 20 s while
  its coding instance lives, drops at the same deadline [ models.task.drop-claim, late result discarded ] ;
  jobsite.dispatch.supersede fails the previous task on a new attempt [ closes the double-run gap ].
- sign agent : b986c9799 fresh-start unsigned-code gate [ y \ n \ d before passphrase ] + one log line
  per file [ harmonic retries ] ; 6137c9169 refused signature shown, requester-gone check each loop pass,
  AMOS7::TERM confirm_key cancel_fh [ withdrawn prompt ]. test-p7-sign-run stubs p7c [ was sending real
  'signing request' notifications ].
- b0b306db3 update-signatures :stage: only signed + unstaged-valid ; 827299163 invoke-queue-harmonize both
  dbs ; b3bba48f2 httpd refused POST [ 405 \ 413 ] closes [ scanner body parsed as 'REQ:-qO-' ] ;
  2b73d5537 process_zenka_end honours restart.disabled for exec-external [ pull-git looped on error ] ;
  0d60550d7 no deps markers when root resolves to /usr/local/protocol-7.

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

#,,..,.,.,,,,,,.,,,.,,,..,..,,.,,,.,.,.,,,..,,..,,...,...,,,.,,.,,,,.,.,,,.,,,
#LWBSFE64CCKBRPONB5MLQB2OXHB7B4TLFISRR3BMQKIGJBZCWXT35RDU5CF7PLVJHMNVD5HECDZVS
#\\\|RHEUPSPOVI2RWXBHQCWHZVWF4FQT4SG75HYXP3UW3JS2UA6KP3J \ / AMOS7 \ YOURUM ::
#\[7]KZWA6HNNY5NA36BZ7MQGQMBVHMHSBYYOH3ZVQOABGOBQGDA3UKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
