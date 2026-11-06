---
name: project-2026-11-05-session-handover-claims-top
description: START HERE 2026-11-05 [ 2208b3c5b, live everywhere ] : jobsite stall = missing task.touch grant, claim handling, task.release, system.top current cpu ; next : shm A
metadata:
  type: project
---

session 2026-11-05 evening [ follows [[project-2026-11-05-session-handover-pressure-io]], its shm plan and
open list still apply ]. all pushed to `hub` ; srv-U F V A and srv-16 on 2208b3c5b.

**jobsite stuck in assessing, 9 h**
- pri's /etc/protocol-7/host-config/cube.cfg `access.cmd.usr.yourum` lacked task.touch [ ab22753a5 ] : yourum
  [ = srv-A alias ] treated the refusal as a lost claim and discarded finished results ; the task stayed
  in_progress for the 6 h sweep. overlay fixed : task.touch task.release. tasks reset by hand.
- 7689deb12 only the task zenka's own answer ends a claim ; no permission \ route collapsed : kept, retried.
  the lease deadline needs a successful renewal, otherwise task_claim_ttl. task.release hands a claim back.
- 456ca9d8c task.release in task's zenka.v7 + whitelist, see [[feedback-new-task-command-three-lists]].

**system.top**
- 67e2acec9 cpu % since the last poll [ 100 = one core ], was the lifetime average. max_cpu limits read it too,
  none configured.
- 2208b3c5b system.process.post_init cancelled on the wrong key : each reload leaked a poll timer.

**notes**
- deploy : `::: <host> v7-zenki.start_once :wait-down: pull-git` then `::: <host> <zenka>.reload all` ; reloads did
  not disturb a running task. cube : `::: <host> reload config`. root's p7c over ssh : 'client not present'.
- p7_commit is detached : check p7_commit_status before pushing [ a hook refusal, descr > 55 chars, again ].
- !TRM! on a plain reply route : cube frees the route, the target ignores it -- stopping inference for a
  discarded claim would need coding to honour it. not filed.

**open, in order**
1. check jobsite left assessing and took results [ was : new 414, trash 2630, 4 pending ].
2. shm A [ FKS ] in a new session.
3. todo ASF clean refusal logging, then GDA network channel for notices.

#,,,,,.,,,,.,,.,.,...,..,,,..,...,.,,,,,,,,..,..,,...,..,,..,,,.,,.,.,..,,,,.,
#T6XYGCGYUIECD2FMZVDA2UH4DA4UNUUJRZVBNVZNBCOTDNXBAJDTVVAIFNTEXLCV3T65IRDBNNTKE
#\\\|MYRPDYO6NAJ76CLKY2KBL2AUPKE7FJDX6KMAF6ZQVS3DAZ3J7AH \ / AMOS7 \ YOURUM ::
#\[7]7EG2HK4VDON3IIYF56IR62Q2DLJLHCDTEJ3ICOBQG5WHR6HMOEBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
