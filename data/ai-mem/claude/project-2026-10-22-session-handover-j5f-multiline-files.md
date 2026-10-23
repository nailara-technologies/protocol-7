---
name: project-2026-10-22-session-handover-j5f-multiline-files
description: START HERE -- session 2026-10-22 [ evening ] handover [ last 1c52db2c1, all pushed, history REWRITTEN ] : J5F multi-line args in p7c \ p-7-r + coding.input.decode, multi-line parser fixes, message templates ; designs FILES-ZENKA [ files \ file-view, N7FS ] and SIGNED-STATEMENTS [ v1 signed lists ] in base, owner answers recorded ; todos FKS VWF ; cpu-only assessment stall fixed [ enqueue + spawn verify ] ; commit messages relabelled srv-<x> [ force-pushed, remotes reset ] ; todos T3I C6U 4WM
metadata:
  type: project
---

previous : [[project-2026-10-22-session-handover-remote-fetch-link]] [ its
open items 1, 2, 4, 6 still stand ; item 3 : all six cloud docs landed in
3a06655c4 ]. budget at the end : claude 7d ~25 %, kimi 7d ~8 %, cloud
credits 22 of 100 [ expire 2026-11-05 ; after that cloud sessions draw
the regular session budget ].

## landed [ pushed, live-tested on this host only ]

- a7f46506a J5F : p7c \ p-7-r send an argument with a linebreak in
  MULTI-LINE mode [ '<cmd>+', empty header, args as body, '.' -- the mode
  existed, B32 was not needed ] ; dot-stuffing ONLY for lines of dots
  alone [ hand-typed '.foo' passes ; owner : compat with old remotes is
  no issue, update them in a loop -- pick the best form ]
- a7f46506a base.handler.command : capture NON-GREEDY [ a pipelined 2nd
  packet was swallowed ] ; inner strip + incomplete check take the
  capture's strict head [ replies frame with SIZE \ STRM, never '+' ;
  '(id)cmd' without a blank is the route form ]
- a7f46506a coding.input.decode : plain \ B32: \ :file: , no base32
  guessing, :file: repo tree only [ realpath, tree check before existence,
  256K \ summarize 4M ] ; submit \ summarize-context \ ask-reply use it ;
  summarize-context path= confined ; mcp-server-p7 summarize-file reads
  client-side and sends :B32: [ active after an MCP server restart ]
- 198c82f6a a refused '+' head drops its packet [ stripped to its '.'
  line, else session ignore_ml_packet until it arrives ] -- before, its
  body ran as single-line commands ; replies \ logs as templates A6ZTSCY
  KA4I2BY OAZPKOI H7KA5EY M2MLE6A ; param syntax reply APPENDED [ '='
  overwrote waiting replies ]
- c98d323ba strip re-sign [ kimi left a signature fragment ]
- todo J5F : PROGRESS line, remaining items listed there

## deploy notes

- new templates load on `reload init` \ `reload all` or a restart ONLY :
  `reload source` keeps the old registry and sprint_t sends nothing [ the
  client hangs ]. remotes : pull + `reload all` or restart
- the installed /usr/local/bin/p7c is still the old binary until
  v7-zenki reinstalls it [ start ] ; tests used a scratch build
- devmod for tests : `p7c v7-zenki.devmod-enable coding` [ SIGNUM53, no
  restart ] -> `coding.receive-multiline` echoes ; `devmod-clear` after

## design : files + file-view [ afb1ca66f, answers ae50788b9 ]

- data/md/design/FILES-ZENKA.md [ in base, dev branch deleted ] : `files`
  [ name decided : `file.*` is the base.file.* alias space ] holds read
  rights as its own uid, attach -> handle H [ key_56 ] over content C,
  scoped to a target zenka [ + task label ], expiry \ fetch count \
  revoke as appended record versions, nested attachment groups ;
  `file-view` = user-facing, no file rights, only narrows
- N7FS native : C = node bmw [ one addressing scheme ], records as content
  nodes, heads index outside the disk [ rebuilt at start ] ; gaps marked :
  node release + tombstones, references/, stream writes, assimilate meta
  override entry, shared read across uids
- owner ANSWERED : 14 [ unreferenced -> garbage, reclaim on space need \
  max age, instant purge ; never-recoverable = crypto-shredding, protected
  content never deduplicated ], 18 [ security levels : keys follow the
  group tree, envelope encryption so layers never break chains, end to end
  by default, files direct or via the data zenka, tie \ mapping, keys \
  udev token ], 19 [ udev N7FS automounts, signed disks may trigger code :
  own payload signature, anti-rollback, signed node-set root, dm-verity ].
  still open : 12 C = bmw, 3 task proof via child zenki, and the rest
- existing building blocks listed in the doc : data [ shm mmap,
  lock_memory, signed permissions, fuse ], storage [ P7REF, checksum
  plugins, 9P client ], plan-9 [ 9P server ], keys, index, fs, udev

## design : signed statements [ 8e0260ef1, answers adcff4bee ]

- data/md/design/SIGNED-STATEMENTS.md : the stalled 'clean signature
  trees' question [ format + location ]. v1 = text + the AMOS7 footer,
  canonical form only, `p7 statement 1` + label + state key [ label,
  signer, subject ] + version + witness ; location nowhere specific
  [ content-addressed, index lookup ] ; footer TYPES full \ form and KINDS
  CODE \ DATA [ def 1 signs the slots, 258 bytes ] ; signers via trust.*
  as discover does ; first adopter : the module set
- owner answered : 1 [ sourcecode key \ temp key ; session keys later ],
  8 [ size + checksum signed : one signature, then size compare +
  BMW-384 per loaded module ; v1 member kind `file <name> <size> <bmw>` ],
  11 [ p7 lib set v1 ], 12 [ zenka.v7 = CODE ]
- review found : pre-commit DOES verify [ draft was wrong, corrected ] ;
  todo FKS [ high : AMOS7::SHM::sign_permission is a placeholder hash ] ;
  todo VWF [ signature_valid ignores a caller truth map ] ;
  base.list.subroutines is not enforced at load [ adoption step 4 ]

## later the same day : assessments on the cpu-only server [ srv-U ]

- STALL CAUSE 1 : coding.task.enqueue defaulted every task without
  analysis.routed_to to the gpu server dependency ; srv-U has
  inference.backend.gpu.enabled = no -> every job parked in 'depending'
  at queue time. fixed : gpu unless switched off [ unset = on, as
  coding.init_code ; auto keeps gpu ]
- STALL CAUSE 2 : coding.handler.spawn_servers_deferred scheduled its
  fallback verify_inference_startup for the gpu only -> on a cpu-only host
  the queue was never resumed and check_dependencies never called [ 54
  parked, 0 run ]. fixed : verify the cpu where the gpu is off
- coding.self_test.async_probe : coding.cfg.self_test_thinking = auto ->
  enable_thinking false on the cpu backend [ prompt 2 ttft was 635 s ]
- coding restarted on srv-U with both fixes ; at hand-off the self-test was
  still running -> CHECK FIRST : `::: <srv-U alias> coding.status`
  completed > 0 and the log shows 'verify_inference_startup cpu server
  verified ready' + 'task queue resumed'. if still parked : the fixes did
  not cover it, read coding.handler.verify_inference_startup again
- the earlier test job 5345177 [ a summarize of /etc/passwd, world-readable,
  queued by the OLD code ] : check it is gone after the restart ; no
  command removes a pending task with status unknown [ stop-task \ bury
  both refuse ]
- IPC::Run : marker cfg/zenki/coding/deps/os/deb/libipc-run-perl added,
  NOT yet installed -- v7-zenki caches the sys_deps probe result per zenka
  for good ; installs on the next v7-zenki restart. design for the general
  case : todo 4WM [ auto-install stage 3 ]. until then `coding.reload
  source` fails on srv-U [ llm.service.subprocess_wrapper ]
- v7-zenki `reload source` broke v7-zenki.start on all remotes [ zenka.*
  short name missing ] -> `reload init` fixed it ; see
  [[reload-success-doesnt-guarantee-new-file-loaded]]
- todos : T3I [ gpu.enabled = auto must detect ], C6U [ self-test holds a
  cpu backend for an hour+ ], 4WM [ stage 3 auto-install ]

## night 2026-10-22 \ 23 : srv-U assessments run [ 65227edd8, 2b97a3aa6 ]

- STALL CAUSE 3 \ 4 : routed_to holds service names [ coding.helper.
  task_backend, de18b5af5 ] ; data-start timeout used the gpu prefill
  rate [ cpu default 15 t\s, bbffc7bac ; measured on srv-U ~23 t\s, ttft
  ~200 s for 4.6K tokens, output ~2.7 t\s ]
- srv-U host.cfg : coding.cfg.round_soft_ceiling = 777 [ 384 cut every
  first attempt ; an assessment takes ~8-9 min ] -- todo WFC sizes both
  timeouts from measured rates later, plus metrics records
- CRASH : self-test pause + 100 tasks on the cpu lock -> release ->
  handoff -> send_request paused -> release .. nested -> deep recursion
  warning = emergency exit 110 [ bin/Protocol-7 __WARN__ handler ], end
  code killed llama. root race : inference_server dependency said ready
  before the self-test ended, a task beat the probe. fixed 65227edd8 :
  coding.async.backend_dispatch_next [ loop, none while paused ], resume
  points kick both lock queues, dependency waits while paused. verified
  live : self-test alone, then the queue resumed
- jobsite.reset rep-err=1 done after the first completion [ 260 reset ]
- OPEN : jobsite counts the result_len=0 assess-done of a coding restart
  as assessed [ 41 -> 125 ] -- probably the source of the failures and
  of 469 active vs 257 new
- self-test riddle [ cat \ mouse, the cat is the constant ] : local gpu,
  same model, reasoning off : plain 58 % cat, '[ logic riddle ]' title
  37 %, 'pure logic riddle' 40 %, 'not a trick question' up front worse ;
  in the follow-up hint it recovers 12 of 12 [ 08642a765 ]. answer check
  now reads which animal is NAMED [ coding.self_test.named_candidate,
  2b97a3aa6 ] : a reply naming mouse but echoing 'cat' had passed
- prompt 3 fails on cpu without reasoning ; the queue resumes on fail too
- jobsite [ 61b4e60e9 ] : TRUE \ FALSE reply handlers get { sid, cmd,
  call_args, params } -- no mode \ data. base.reply.mode_text ; jobsite.
  dispatch.release_slot [ only the slot holder counts down \ dispatches ].
  live on srv-U : ONE assessment in flight [ was 469 ], no FATAL
- JMG [ f920dbb6a ] : watchdog asks task.show, re-arms up to 24 x 777 s.
  5UC : kimi reviewed 15 handlers, 10 defects, kimi fixed 8 [ checked ],
  cred-mesh [ dialog answers were dropped ] + ncode by me
- ncfg [ 78e44abba ] : base.parse_ncfg_code level stack, repeats merge,
  raw sections 'name [ n bytes ]' after an empty line, '\#' ;
  base.format.ncfg writer ; base.load_section_code uses the parser ; 124
  files parse identically ; all four v7-zenki reload init clean.
  ncode.cmd.transform answers ncfg [ .cmd. data must be a STRING --
  structures in a plain routine, ncode.transform.run ]. todo FMC
- srv-U host.cfg has coding.cfg.round_soft_ceiling = 777 [ manual ]

## later the same day : history relabelled

- owner : no server names in code comments or commit messages [ they go
  stale and serve as examples ] -> 8 src comments made generic, and 78
  commit messages rewritten to srv-<x> labels, rule in
  [[reference-host-and-domain-labels]] [ no map stored ]
- done : backup branch backup/pre-host-labels [ keep until the owner says ]
  + owner bundle ; filter-branch msg-filter with the scratch filter +
  rewrite-hash-refs -m ; tags rewritten [ --tag-name-filter cat ] ;
  24218 in-file ids remapped [ rewrite-hash-refs -f ] + 94 digit-only ids
  by hand [ the tool skips them by design ] ; 5734 files re-signed ;
  force push base + tags ; all four remotes fetch + reset --hard +
  restore-p7-permissions -> all at 1c52db2c1, clean
- filter pitfalls found in the dry run : two of the names are ordinary
  words [ one a host only from 1a01f4240 on [ new node ], phrase excludes ;
  the other an x11 term after _NET_* \ FIFO ], YOURUM upper case is the
  signature name, a todo command shares a name and must stay [ it also hid
  one real host name, memory relabel 2026-10-23 ] -- and an inner regex match inside s///e
  reset $1 and would have DELETED the word [ save $1 first ]

## lessons

- kimi read the multi-line mode as absent and built B32 : brief with the
  protocol section's line numbers ; the owner knew the '+' mode
- follow-ups into a completed cloud session are cheap [ see
  [[reference-cloud-sessions-first-run]] ]
- logt \ sprint_t templates : one location per protocol message, id =
  amos-chksum of the LITERAL source text [ '\n' as two chars ]
- a design brief must name the existing neighbours [ files missed data,
  storage, plan-9 until the owner pointed ] ; verify a design doc's claims
  about code before relying on them [ the pre-commit claim was wrong ]
- prompt tests on llama-server : pass a seed per request [ the server's
  fixed --seed gave 8 identical answers ] and take 60 samples, 24 swung
  one variant from 8 to 12 ; test on the local gpu, a cpu test request
  waits behind the assessments' slot
- any 'deep recursion' warning ends a zenka [ exit 110 ] -- a synchronous
  handoff chain over a queue must be a loop

#,,,,,,..,,,.,,.,,..,,,,,,,,,,.,,,,..,,,.,,,,,..,,...,...,.,,,,.,,.,,,...,,..,
#ZOEUQQVBXPDQCLGR4HYK4VNF4HLOYDVE5RXGCQY6MG37RCAK6HZJNCPG3LGSBHLFV2FTLOCNXRQT4
#\\\|2ONZYTWTESNIWEMHIC27M22ZYZME6XF5VX7UED3532PWGSZ43ZR \ / AMOS7 \ YOURUM ::
#\[7]K3SAANVKXDTFDNR62E5PRQH5G6MJTBNYWCFQROPD7J725A6ISYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
