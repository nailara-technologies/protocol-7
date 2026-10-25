---
name: project-2026-10-25-session-handover-worker-host-config
description: START HERE -- session 2026-10-24/25 handover : srv-A 3rd worker live, gpu offloading done [ the local gpu can go for its fan ], host-config overlays [ root owned, trust check ], encrypted swap everywhere, minimal profile, external.list links, format-code cfg mode \ -report \ -parsed, hourly jobsite-scan event
metadata:
  type: project
---

previous : [[project-2026-10-24-session-handover-link-live-ids-qlk]].
details of everything below : [[project-2026-10-24-srv-a-third-worker]].
last commit 342104878 [ servers on 10fb5efad + comment-only 342104878 pending pull ].

## landed [ all pushed, all four servers deployed ]

- 9406bea69 cpu mem scope reaches the user manager [ non-root mem_max never
  worked ], MemorySwapMax=0
- 463db3371 host overlays : /etc/protocol-7/host-config/<zenka>.cfg, root
  owned, base.host.trusted_file fail-closed ; /etc/protocol-7 root:protocol-7
  0755 ; host.detected ; cube host-local grants [ cube.cfg ] ; design
  data/md/design/HOST-CONFIG-OVERLAYS.md. migrated on all hosts incl. local,
  old files in /root/p7-host-cfg-backup-2026-10-24/
- 5bf4b5d95 external.list links \ orbital
- 9be64e3b3 start-set-up.minimal [ cube p7-log ], external out of base --
  hosts with links : v7-zenki.host.zenki.enable = external [ local, srv-A,
  srv-U set ]
- 3de23e82e format-code cfg mode [ cloud branch, 8 credits ], -report,
  -parsed, cfg sweep 78 files
- 10fb5efad + 342104878 event-setup.jobsite : hourly send-command
  jobsite.scan [ srv-U events.load_config = jobsite, rescan_interval 0 ],
  verified by events.trigger_event

- 08ab710b8 start_once :wait-up: \\ :wait-down: [ waiter first ], an error
  end replies FALSE + exit code ; deploy : start_once :wait-down: pull-git

## live state

- srv-A : cpu worker, link label = its host name, claims srv-U's
  :no_tools: tasks, 8G scope ; srv-U assess_parallel 3
- twofish random-key swap : srv-A 4G, srv-U 8G, srv-V sda3 [ by-partuuid,
  RESUME=none ], srv-F already had it ; all reboot-tested
- local : models + jobsite are NOT in the base profile [ started by hand ]

## open, in order

1. N7FS work [ owner's next focus, little budget left this week ]
2. step4 join rules [ 'path/ x', wrap hyphens, '.  ' after identifiers,
   lost sentence breaks ] -- shared by src + cfg mode
3. src/download.init_code : -c-only 'uninitialized in integer addition' at
   :52 [ base tool too, age unknown ] -- add section markers, compare 5.32
4. p7c task.create+ stdin body double-encodes
5. two src files never converge in format-code [ base.swap_subs,
   protocol.protocol-7.init_code ] ; test-v7-zenki-host-zenki.pl 1 old fail
6. 9406bea69 names a host in message + diff [ owner : history rewrite? ] ;
   cloud branch dev/format-code-cfg-mode can be deleted
7. step 2 DISPATCHED to kimi [ session f1b781d1-0e9b-4f20-b3e2-2beb566bd77a,
   uncommitted in the tree when it ends ] : restart :wait-up:, terminate
   :wait-down:, subname strip -- review its diff + test table, check no
   access grant was added, then the owner's sign run. after that :
   notify_online :start: [ an observer with a start option, like the one
   dropped from notify_offline ] ; design topic : who may start what
   [ grants are per command, not per argument \\ target zenka ]
8. older : tool-call hang in coding, per-model sampler, dead
   coding.tools.handler.edit_file, open-layer sweep, 3MK RTY H2N

#,,.,,...,..,,,,,,,,.,,..,,,.,,..,,,.,,,.,,,,,..,,...,...,,..,..,,,,,,,..,.,.,
#FPSO3GZ6XIIANWMU2CG2SBZ4SPTE7UGWNW7SGFF26LFWEFPM7BKS2YQSVWE3GDY5ZQ65UH3PSLOUW
#\\\|WBARFORMXKPC7VIFO53F7O6CYDMFKVUKPO4QMOXZQ2WMYSAZF6E \ / AMOS7 \ YOURUM ::
#\[7]DVXEI7NX25WYWLK2SXT3TWG7RFGES5TRBKGH65U3LCVORKC454CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
