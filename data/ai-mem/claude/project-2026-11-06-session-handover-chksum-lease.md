---
name: project-2026-11-06-session-handover-chksum-lease
description: START HERE 2026-11-07 : amos_chksum keeps binary bytes, coding memory states, gpu lease live and following pause \ resume, next N7FS dogfood
metadata:
  type: project
---

follows [[project-2026-11-06-session-handover-host-labels]]. all four servers on 8317b1e35 [ lease off there ] ; later commits local, unpushed. desktop has models.cfg.gpu_lease.enabled = yes in /etc/protocol-7/host-config/{models,coding,invoke-web}.cfg.

**amos_chksum [ 08eb7eae9 ]** : non-utf8 input lost its bytes [ FF = FE = E9 collided ]. valid utf-8 stays text, unchanged. anything else : bmw over the exact bytes, elf over byte values [ elf reads characters, a pure byte form would have moved all non-ascii text ]. key checksums moved once, nothing referenced them. model ids did NOT move : both halves hash text [ path, metadata -- the second half is not file content ]. this settles N7FS decision 1 : addresses were already byte safe through amos-of-bmw-text.

**coding memory [ eadbd5de9 ]** : spawn reports busy \ too-small, inference.backend.gpu.on_busy = wait \ cpu. memory_gpu \ memory_system objects still gate nothing. busy path not yet seen live.

**gpu lease [ 24298ba3b .. pause commit ]** : models.gpu_lease.*, sole residency for coding and invoke-web. LIVE PASSED 2026-11-07 on the desktop : pause -> grace -> vram verified -> release -> coding spawned, resume -> coding yields -> grant -> queue resumes. the processor is polled [ 2 s waiting, 15 s holding ], ui buttons bypass the zenka and write no db. session-park does NOT pause, parked items still render. not seen live : pause during a wait [ grant resumes it, indistinguishable from our own pause ], models silent, second resume during a wait. a resume can overlap coding for one image : queue.hold rejected, it is for a stopped invoke.ai only and would empty the queue view. five live bugs had passed the stubs : command names, empty replies, whitelist, no re-request after yield, cube. prefix. reload source does not run init_code : new timers need reload init.

**also** : seed restart yields to real tasks [ 0de17f140 ], cpu seed restart parked the backend [ 5780ff791, VNN closed ], keys gen-chksum, todo search + aligned tags + cut-off warning at 106.

**lessons** : a coding restart fails what it holds [ route collapsed ], the job needs a rescan -- ask before restarting during a queue, and do not call a gap between renders idle. search the todo first : VNN already named today's stuck backend. kimi assumed 72 columns and rewrote 134 lines : give the wording rule up front.

**open** : models registry 'YAML::Tiny bad indenting' on a multi-line model name [ yaml_load claims YAML::XS, can empty the registry again ] ; 3 registry entries gone 93 -> 90, unchecked ; models.discover :clear: :re-scan: can save an empty registry ; TDA ; 7U6 jobsite sync rebuilds the list ; P23 ; D5W ; stale harnesses test-coding-liveness-deferral, test-coding-spawn-smart-self-test-cancel ; azurum waits for the next update ; pii patterns have no addresses yet.

**logs** : level 1 lines do not reach the /var/log zenka files reliably, read the console /dev/shm/.7/STDOUT/* with colors stripped.

**next** : N7FS dogfood [ owner has not chosen what to import ].

#,,.,,..,,,,.,,,.,.,.,.,.,,..,,,,,..,,,.,,,.,,..,,...,.,.,...,,,.,,,.,,,,,.,.,
#O7U7SV6HGJQGTMW7JBTCEHMIPG6KPJXRCANMDJRKG5TQ5FM2H5NEYYV7V32MUIE6W3ZZQ2HDNWUQG
#\\\|J5ZLPUY4EUHRILFQPVRAY76HTB2CI6ARJXKTAG6VS57KWZFV7SK \ / AMOS7 \ YOURUM ::
#\[7]7UZRFLDTI7M7BGUVUS2NBAGVHDQP2GEGXPMXHIKA3WEZBFMRB6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
