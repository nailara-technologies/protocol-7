---
name: project-2026-11-06-session-handover-chksum-lease
description: START HERE 2026-11-07 : amos_chksum keeps binary bytes, coding memory states, gpu lease live and following pause \ resume, next N7FS dogfood
metadata:
  type: project
---

follows [[project-2026-11-06-session-handover-host-labels]]. all four servers on 82f164998 [ lease off there ] ; later commits local, unpushed. desktop has models.cfg.gpu_lease.enabled = yes in /etc/protocol-7/host-config/{models,coding,invoke-web}.cfg.

**amos_chksum [ 5d0ef0224 ]** : non-utf8 input lost its bytes [ FF = FE = E9 collided ]. valid utf-8 stays text, unchanged. anything else : bmw over the exact bytes, elf over byte values [ elf reads characters, a pure byte form would have moved all non-ascii text ]. key checksums moved once, nothing referenced them. model ids did NOT move : both halves hash text [ path, metadata -- the second half is not file content ]. this settles N7FS decision 1 : addresses were already byte safe through amos-of-bmw-text.

**coding memory [ 5187b61a7 ]** : spawn reports busy \ too-small, inference.backend.gpu.on_busy = wait \ cpu. memory_gpu \ memory_system objects still gate nothing. busy path not yet seen live.

**gpu lease [ 6a5a24d82 .. pause commit ]** : models.gpu_lease.*, sole residency for coding and invoke-web. LIVE PASSED 2026-11-07 on the desktop : pause -> grace -> vram verified -> release -> coding spawned, resume -> coding yields -> grant -> queue resumes. the processor is polled [ 2 s waiting, 15 s holding ], ui buttons bypass the zenka and write no db. session-park does NOT pause, parked items still render. not seen live : pause during a wait [ grant resumes it, indistinguishable from our own pause ], models silent, second resume during a wait. a resume can overlap coding for one image : queue.hold rejected, it is for a stopped invoke.ai only and would empty the queue view. five live bugs had passed the stubs : command names, empty replies, whitelist, no re-request after yield, cube. prefix. reload source does not run init_code : new timers need reload init.

**also** : seed restart yields to real tasks [ e767ebbae ], cpu seed restart parked the backend [ bdbb1bb6a, VNN closed ], keys gen-chksum, todo search + aligned tags + cut-off warning at 106.

**lessons** : a coding restart fails what it holds [ route collapsed ], the job needs a rescan -- ask before restarting during a queue, and do not call a gap between renders idle. search the todo first : VNN already named today's stuck backend. kimi assumed 72 columns and rewrote 134 lines : give the wording rule up front.

**open** : models registry 'YAML::Tiny bad indenting' on a multi-line model name [ yaml_load claims YAML::XS, can empty the registry again ] ; 3 registry entries gone 93 -> 90, unchecked ; models.discover :clear: :re-scan: can save an empty registry ; TDA ; 7U6 jobsite sync rebuilds the list ; P23 ; D5W ; stale harnesses test-coding-liveness-deferral, test-coding-spawn-smart-self-test-cancel ; azurum waits for the next update ; pii patterns have no addresses yet.

**logs** : level 1 lines do not reach the /var/log zenka files reliably, read the console /dev/shm/.7/STDOUT/* with colors stripped.

**next** : N7FS dogfood [ owner has not chosen what to import ].

#,,..,,..,.,,,,,.,,.,,,..,,..,...,,,.,.,,,...,..,,...,...,..,,..,,.,,,,.,,.,.,
#Y55KVZDFO77GZ7DIYAML3PV4REAHYHPVYMJRZ4RQNXITTJZIBDZ5RJ4OREEKT3TUDS4MEEWCW6N26
#\\\|BJXVFSB3TN7IHXS34PGRLCTMAJ5KIT42QERL6PGGPYZHRWM6W6X \ / AMOS7 \ YOURUM ::
#\[7]FGJAUVF3WAATQQPQ3M7ZRLQSKYWAPOGIF2BV6FDM2UUAOHERASAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
