---
name: project-2026-10-23-session-handover-admission-drain-repair-zyh
description: START HERE -- session 2026-10-23 handover : 6CJ admission live [ incl. multi-line wire fix ], TQA drain, 5M3 repair applied on srv-U, ZYH code in [ not live yet : waits for the managed link ], QLK root cause [ no user state syncs between hosts ], link stage 1 dispatched to kimi [ hit its 5h limit, resume ]
metadata:
  type: project
---

previous : [[project-2026-10-22-session-handover-j5f-multiline-files]].
budget at the end : claude 7d ~70 %, kimi 5h exhausted [ k3 + sub-agents
spent a window on exploration alone ], cloud credits 10 of 100 [ ~6 per
session ; when gone, cloud sessions draw the regular pool ].

## landed [ pushed, hub/base ]

- 231f0dc7b + c11d53797 6CJ : admission gate on /auth/login, /status,
  /logout and Bearer routes [ per-source, per-path fail counts, 429 +
  Retry-After, login queues ]. c11d53797 : the cube wire carries ONLY
  call_args->{args} -- send.local now sends call_args with param \ data
  and no args as a multi-line packet [ base.format.multiline_command ] ;
  with args it stays single-line [ the five letsencr senders : todo HCK ].
  live here + srv-U [ valid token checked by the owner ]
- fdc1a6a47 TQA : httpd.cmd.drain shared by httpd \ httpsd [ unwatch +
  close the listen socket, wait for 'http' sessions, cap 25 s ], the
  broken httpsd drain removed, site-yaml drain + its grant. NOT yet seen
  live : the second twin restart of httpd after the one loading it
  should show no DRAIN TIMEOUT. idle keep-alive holds a drain to the cap
- fdc1a6a47 + 839701512 5M3 : jobsite.repair-encoding [ dry run default,
  apply ] -- applied : local 7 jobs, srv-U 296 [ backup tar.xz under
  /var/protocol-7/jobsite/repair-encoding/ ], 0 irreversible ; owner saw
  trash fixed. 839701512 = CORE::stat [ File::stat trap ]
- 7b15c4188 ZYH : models.cfg.task_zenka [ default 'task' ] ; remote =
  peek [ show first ], claim only local backends whose ':model:' pin is
  served without a swap [ content half of the key ; srv-U and local both
  pin QDBKEXY content ] ; task.cmd.subscribe STRM + 30 s task.next poll.
  deployed to srv-U [ pull-git ] but NOT active anywhere : needs the link
- ca5b4e177 : todos, LOGIN-ADMISSION.md built, memory notes
- dev/models-remote-task, dev/repair-encoding deleted on hub

## open, in order

1. kimi session 9979563b-fd7a-473f-a572-505ec8223163 [ 63.5k context,
   exploration done, nothing written ] : `kimi_continue` on k2.8 after
   the 5h reset -- 'write stage 1 as briefed'. brief : LINK-ZENKI-AND-
   TRANSPORTS.md stage 1 [ link.session.open, link.transport.ssh-w.open,
   supervisor in external, always-on, pin move ] + access.cmd.usr.
   task-worker [ access.users ] + models' external.*.task.* grant
   [ access.zenki ] + a how-to [ host-edit commands, authorize-link ].
   owner answers recorded in the doc : record renamed to plain name,
   ssh-w, always-on ; questions 1 2 5 7 8 9 wait for stage 2
2. review, sign, commit ; then live : 'pri' record [ host-edit ],
   authorize-link task-worker on srv-U, restart external, local
   /etc/protocol-7/models/host.cfg task_zenka = external.pri.task,
   restart models + srv-U task, watch the first remote claim
3. QLK -> 3MK : NO user state syncs between hosts [ export time equal
   only by hand ; export marks only in the exporting host's web/jobs/ ;
   stage changes only on that host ]. fan-out as records { job, field,
   value, time, host }, newest wins per field ; transport = the existing
   remote web endpoint [ sync_urls \ sync_tokens ], owner's note. no
   one-off copy [ desyncs at the next export ]
4. yourum as 3rd worker after ZYH [ smaller model -> agreement check on
   already assessed jobs ] ; RTY mail assessments ; H2N assessment
   history [ incl. trash propagation after N epochs ]
5. uncommitted at handover : data/yaml/todo/base.yaml [ QLK details ],
   LINK-ZENKI-AND-TRANSPORTS.md [ answers ], this file + index line

## lessons

- stubs hide runtime differences : the route-send stub passed every
  call_args key [ 122 green checks, inert live ] ; harnesses lacked
  File::stat. verify live with devmod receive-multiline \
  bin/dev/test-multiline-socat
- '# descr =' one line <= 55, the rest in '# note  =' -- every kimi and
  cloud brief must say it ; the pre-commit hook enforces it on new files
- the signing run may reset my staging and gives one version : one
  commit per signing run
- kimi_dispatch kill : killing the wrapper pid may leave the run going
  briefly [ a late write restored files once ] -- check the tree after
- k3 with sub-agents can spend a whole 5h window on exploration ; brief
  with exact file:line anchors and prefer k2.8 for writing

#,,,.,,,,,..,,,..,,..,.,.,,..,.,,,.,.,,,.,,.,,..,,...,..,,.,.,..,,..,,,..,.,.,
#52Z6KVOKTDULFXJQGQUFQMKVEKZYO6I6J736NDYVBQUGYBACJMZ6K5XKASF6PRMRDFSECZDNETRHG
#\\\|67U2KV5GCKY3V6BR2Y3H22VDP4N6BCXYC37WMH3UYXQFEWCZKLC \ / AMOS7 \ YOURUM ::
#\[7]EQ6YFTO55JP4FQJGGCHTNIYDKTMNFE5AM2H4MBND63TY5RJIHUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
