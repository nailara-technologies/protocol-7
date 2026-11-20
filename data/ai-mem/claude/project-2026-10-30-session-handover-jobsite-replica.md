---
name: project-2026-10-30-session-handover-jobsite-replica
description: START HERE 2026-10-30 morning [ last 8db4dfe6c, pushed + 4 servers pulled ] : claim-release access fix, commit-plan bugs, liveness sweep + 112 jobs imported into pri ; kimi building jobsite REPLICA mode [ session f82e3d0d ] -> review, sign, live test
metadata:
  type: project
---

**landed [ 6be90dfe3 .. 8db4dfe6c, all pushed, pri \ atom \ delta \ yourum on 8db4dfe6c ]**

- 6be90dfe3 cube access : coding may send models.coding-online [ 15bca6f7b
  added only the alias ; cube refused it -> no claim was ever released ].
  live : no denial any more on local, pri, yourum. the release line itself
  logs ONLY per released claim -- still unseen [ needs a coding restart
  while a claim is held ]
- f3b3b9798 p7-commit-plan : 'not X ? A : ..' negated the whole ternary
  [ explicit paths never 'A' ] ; untracked src/ counted ; 'Name' header
  dropped. coding : a repeated thermal hold logs 'again [ hold N ]'
- 4cde357de jobsite.liveness-sweep [ :dry: \ max \ status ], 2 in flight ;
  bin/dev/jobsite-export-survivors ; coding night window 22:00-05:42
  [ room heating starts 05:42 ; coding restarted on pri + yourum ]
- 8db4dfe6c dep-graph .txz opt-in [ -txz ], untracked ; history purge
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

**replica mode : LANDED e981d86fc [ review done ; fix : forwarded ui actions kept in replica-unsent.json until the primary says ok:true, retry 15 .. 900 s ], pulled on all 4, srv-U [ pri ] web httpd jobsite restarted. stash@{0} is now redundant [ drop ]**

- live test BLOCKED on root config : pri web.cfg needs web.cfg.jobs_sync_ui_users = jobsite-replica [ ui role now keyed on the VERIFIED user, no token copy on pri ] ; local token rotated to a jobsite-replica one [ v7-zenki.jobsite-sync-token ] ; local jobsite.cfg needs primary_url = https://<srv-U-jobsite-host>/jobs-sync + sync_url_roles ...=ui. then restart local jobsite + compare with bin/dev/jobsite-ui-compare local pri
- LIVE 2026-10-30 : local = replica of pri, jobsite-ui-compare identical [ 18 jobs ]. real causes : https body is character-decoded [ decode_json died, fixed b4d095df1 ] + local web never got the replica plugin code [ deploy restarted web on pri only -- after a plugin change reload plugins on EVERY host running web ]. CORRECTION : b4d095df1 also claims an undefined $mem -- WRONG, it is declared at plugin line 137 [ the change there is a no-op ]. still to test : one ui stage change local -> pri
- stash@{0} = letsencr param-only send, half done [ set aside ] ; stash@{1} = old replica stash, redundant [ drop ]
- [ DROPPED by owner 2026-10-30 : no longer practical ] - letsencr srv-U : its host name dns-01 fails -- CAUSE FOUND : srv-U = dns-01 via nameserv alias [ acme.<domain> ], srv-V = default http-01. INWX lacks _acme-challenge CNAME + acme.<d> NS for its names : 1 CNAME + 3 NS [ dn0000 dn0110 dn1110 = 3 servers ] each. its old name -> drop it from letsencr config once the new one has its cert [ else failed renewals from ~11-20 ]. <srv-U-jobsite-host> protocol-7.network <personal-zone> v7.ax ok [ v7.ax acme NS covers all 3 servers ]. owner adds the records at INWX. UNCOMMITTED letsencr param-only send fix [ 3 files ] set aside : param was never delivered next to args
- 2026-10-30 08:22 : old sync token leaked into pri httpsd log [ pasted in a browser ] -> owner revoked it ; NEW v7-zenki.jobsite-sync-token : `::: srv-U web.auth-issue jobsite-push -ttl 31536000 | :: v7-zenki.jobsite-sync-token+ url=https://<srv-U-jobsite-host>/jobs-sync` [ token never on argv \ screen ; + form words = key=value headers ]. rotated, pushes ok again. pri still holds jobsite-push session ABIAR3KNEMPRO [ 06:38, unknown owner ]. ui role : keyed on the verified user id [ done ]

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


**update 2026-10-30 late [ next session ]**

- DONE : 3. claim expiry fails the task [ 1fe4b9910, guarded by expected_agent ]
- DONE : 4. pull-git hang was already fixed by c7189ffb7 [ no setup entry ]
- KKHN2 : owner said drop -- web view already dropped it [ removed-log ] ;
  only the pre-replica jobsite store keeps applied/KKHN2.yaml, replica
  refuses local deletes by design -- delete it if replica mode ever ends
- 5. start model now OFSQC4I [ d1a64fafb ], 72T4WFI kept commented
- night-brake step 6 slices 1 + 2 LIVE [ 19807cb93 ] : power_avg + k
  learning, no behavior change. next : slices 3 [ gate on predicted
  temp, spawn refusal ] + 4 [ cooling fault guard ] once k has samples

**update 2026-10-30 night**

- slices 3 + 4 LANDED [ 82c6bc5c8 ], inert until k has 30 samples
- ebd203883 p7_soft_require : .pm for one-word names, package names only [ no string eval : stash autoviv is a non-issue for dynamic loads ]
- trashed-job rescue : eb9a83cff reassess scores on-disk data [ upsert never resurrects trash ], 798d26c21 dispatch.next let reassess entries through, b635ff097 manual url of a trashed job -> review whatever the score [ owner : scores jitter up to 3 points ], 6e99382f9 browser posts never plant id-only stubs. LIVE on pri : VSHN4 VKMN6 CTHN4 reassessed -- CLOSED 2026-10-31 : rescue worked, owner re-trashed VSHN4 + VKMN6 [ no interest ], CTHN4 in review [7]
- replica LIVE both ways [ local -> pri forward ok after the localhost vhost symlink, owner-made : /var/httpd/localhost -> jobsite.local ; plain http from 172.24.32.1 is refused by design ]. aaf1beb21 a pull that predates a forward is dropped [ race seen : 2 quick clicks ]
- 465122508 jobs.json canonical ; 4154739af ui dimensions in base.sort order [ owner reads loc + remote first : relocation decides interest ]
- sign tool appends an AMOS7 block to .html it is handed [ removed by hand in 4154739af ] -- never pass unsigned web files to p7_sign, or fix the tool
- open : night-brake side-triggers ; stash@{0} letsencr

#,,,,,,,.,..,,,,.,...,,,.,,.,,.,.,,..,..,,.,,,..,,...,...,...,..,,.,.,...,,,,,
#O5ZSS3SB6WCRYZLNZYEOVTYKSW7R7B42U4KP5EPAT2NS7UGICEI5XD4MYZ3YVUDSWQ5T7VBFCBZXE
#\\\|TWDXKHSDIEP66OTVLQCS3WQ4CMHKMA6TGPH5VUCZD5RTTFO56TT \ / AMOS7 \ YOURUM ::
#\[7]YBQSFGG6RA423FOVLHG7BLIBWUUNLMKIR34WOTVV6CV36BJWWYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
