---
name: project-2026-10-30-session-handover-jobsite-replica
description: START HERE 2026-10-30 morning [ last aa9b29c3d, pushed + 4 servers pulled ] : claim-release access fix, commit-plan bugs, liveness sweep + 112 jobs imported into pri ; kimi building jobsite REPLICA mode [ session f82e3d0d ] -> review, sign, live test
metadata:
  type: project
---

**landed [ 9748a8dfa .. aa9b29c3d, all pushed, pri \ atom \ delta \ yourum on aa9b29c3d ]**

- 9748a8dfa cube access : coding may send models.coding-online [ 9d2fd7907
  added only the alias ; cube refused it -> no claim was ever released ].
  live : no denial any more on local, pri, yourum. the release line itself
  logs ONLY per released claim -- still unseen [ needs a coding restart
  while a claim is held ]
- 265dd9329 p7-commit-plan : 'not X ? A : ..' negated the whole ternary
  [ explicit paths never 'A' ] ; untracked src/ counted ; 'Name' header
  dropped. coding : a repeated thermal hold logs 'again [ hold N ]'
- f8b0c5b0e jobsite.liveness-sweep [ :dry: \ max \ status ], 2 in flight ;
  bin/dev/jobsite-export-survivors ; coding night window 22:00-05:42
  [ room heating starts 05:42 ; coding restarted on pri + yourum ]
- aa9b29c3d dep-graph .txz opt-in [ -txz ], untracked ; history purge
  deferred [[project-2026-10-30-deferred-history-purge]]

**jobsite state**

- local sweep : 883 checked -> alive 847, gone 9 [ all 410 ], unknown 6
- 863 alive local-only : 701 in pri's removed-log [ pri dropped them on
  purpose ], 43 in pri's trash, 119 unknown to pri -> upsert : 112 new,
  50 refused [ trash + 7 student \ checksum blocks ]. owner then cleaned
  pri's queue by hand [ new 12, applied 17 ]
- KKHN2 is 'applied' locally but TRASHED on pri -- owner to decide
- false 'alive' [ 200 on an expired page ] is rare, mostly Bauwesen \
  Architekt postings -- trust the verdicts
- local jobsite RUNNING again [ started for the sweep ; it assesses ]

**open, uncommitted**

- bin/dev/jobsite-export-survivors : -removed <removed-log.yaml> [ ids
  the target purged ] -- sign with the replica work
- job-upsert takes the json as ARGS [ p7c jobsite.job-upsert "$(cat f)" ],
  not stdin '+'. write the json with ->utf8 [ wide chars otherwise ]

**replica mode : LANDED 536a365f7 [ review done ; fix : forwarded ui actions kept in replica-unsent.json until the primary says ok:true, retry 15 .. 900 s ], pulled on all 4, srv-U [ pri ] web httpd jobsite restarted. stash@{0} is now redundant [ drop ]**

- live test BLOCKED on root config : pri web.cfg needs web.cfg.jobs_sync_ui_users = jobsite-replica [ ui role now keyed on the VERIFIED user, no token copy on pri ] ; local token rotated to a jobsite-replica one [ v7-zenki.jobsite-sync-token ] ; local jobsite.cfg needs primary_url = https://<pri-jobsite-host>/jobs-sync + sync_url_roles ...=ui. then restart local jobsite + compare with bin/dev/jobsite-ui-compare local pri
- 2026-10-30 08:22 : old sync token leaked into pri httpsd log [ pasted in a browser ] -> owner revoked it ; NEW v7-zenki.jobsite-sync-token : `::: srv-U web.auth-issue jobsite-push -ttl 31536000 | :: v7-zenki.jobsite-sync-token+ url=https://<pri-jobsite-host>/jobs-sync` [ token never on argv \ screen ; + form words = key=value headers ]. rotated, pushes ok again. pri still holds jobsite-push session ABIAR3KNEMPRO [ 06:38, unknown owner ]. ui role : keyed on the verified user id [ done ]

1. kimi replica mode [ session_f82e3d0d-576c-4123-a4f8-b63f915f5471 ] :
   primary_url, non-blocking pull every 120 s into the local httpd cache,
   replica gates scan \ assess \ liveness, ui actions forwarded with a new
   role 'ui' [ pri accepts stages only from that role ]. review, sign,
   then live : set primary_url on local, compare with
   bin/dev/jobsite-ui-compare local pri [ exit 0 = same ]
2. side-trigger gates + dead-target backoff from
   [[project-2026-10-30-session-handover-night-brake]]
3. models claim ttl expiry [ 1800 s ] does not tell task : the task stays
   'in_progress by models' until the 6 h stale-claim sweep [ RSRZTLA,
   2026-10-30 ] -- on expiry also fail \ reset the task
4. pri 2026-10-30 : start_once :wait-down: pull-git hung > 7 min -- the
   pull-git pid [ 134725 ] exited, v7-zenki kept the instance 'starting'
   [ no online \ offline line, no pull-git log ]. v7-zenki SIGCHLD fine
   [ not blocked, no zombies ] -> an exit while 'starting' is not handled.
   retry worked. guard remote pulls with timeout 150 until fixed
5. 72T4WFI fails self-test prompt 2 twice [ frees the mouse, runs out of
   tokens ] -- per-model fix only, never global

#,,,,,,,.,,,.,,,,,,.,,,.,,,.,,,.,,,..,,..,.,,,..,,...,...,...,..,,,,.,..,,.,.,
#GFL3AF5K3IT2FL76DHLAQZFNQK6F5RQ2UDPCMKTGU7IYEBW6Y3DOF7KH6GHD4WP24OXUEYU3MMAUA
#\\\|2T6PZWYYLZSG2C7E5NEB5JQ35Z73P6VFJT6OZFALRONAU4ZNLYW \ / AMOS7 \ YOURUM ::
#\[7]2T3XNF5OXUELBNRXIF4EQQUK6K2NSWLQYYNOZWBXFP3ZLAMANUCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
