---
name: project-2026-10-24-session-handover-link-live-ids-qlk
description: START HERE -- session 2026-10-23/24 handover : link pri live over ssh-w, job ids encoded once, QLK closed [ marks role + receiver-side foreign = marks-only ], distributed assessment live [ task zenki list, assess_parallel 2, local gpu 47 t/s claims pri's tasks, :no_tools: guard ]
metadata:
  type: project
---

previous : [[project-2026-10-23-session-handover-admission-drain-repair-zyh]].
budget at the end : claude 7d ~75 %, kimi 7d ~66 %.

## landed [ pushed, hub/base, deployed to pri unless noted ]

- 0c9478f48 link stage 1 [ kimi + review fixes : pin_from, no dotted link
  names, host records 0640 group protocol-7 ] + jobsite desc_check flags
  cleared on a clean pass
- 8e66ecb63 job ids : encoded ONCE where site-yaml parses the listing
  number, every other vax-int call in jobsite \ site-yaml \ web.jobs gone
  [ digit-only encoded ids : 65454 = listing 14580215, see
  [[feedback-vax-int-digit-only-encoded-ids]] ] -- delta pulled too
- 33272a6a0 jobsite.delete \ jobsite.job.trash [ the web's delete as cli ]
- a541450f8 link runtime fixes [ live : `link pri : up over ssh-w`, pin
  pri_42 ] ; QLK export marks newest-wins + last_export_at max-merge ;
  p7c \ p-7-r 'cmd+' reads the body from stdin
- a68850a8e p7c \ p-7-r : options only before the command word
- 396c6a875 + d15a11e36 https POST bodies > 16 KB [ 413 \ 414 guard,
  idle-restart of a replaced watcher, would-block read kept the session ]
- 59e625ae2 + fbcf554f9 + 00ec9a53d jobsite sync to https urls through
  clients.https [ static calls ; modules.load continuation ]

- 914a58249 + 161294d2b sync url roles + the receiver decides [ a
  foreign peer's batch is marks-only ] -- QLK CLOSED, pri's export table ok
- c40bc28c0 models task zenki list, jobsite assess_parallel, cpu server
  nice 11, negative cpu threads ; b7b0f476e foreign tasks only with
  ':no_tools:' as first line ; 34811df51 startup scan of local queues
  [ orphaned local tasks claimed ], no valued.resolve on empty node

- 363a759d2 reassess \ appended batch fill a free slot at once ;
  bb37d4893 claim limit [ task_max_claims, default one per ready backend
  serving the pin ] + claim ttl 1800 s ; e2d628f30 models' grant for
  coding.inference-status ; 3af43f0cf slot reserved at claim SEND
- LIVE CONFIRMED : pri cpu 3.5 t/s + local gpu 39.4 t/s in parallel on
  pri's tasks [ the gpu claims pri's 2nd slot over the link ]

## live state [ end of session ]

- local httpd + jobsite RUN again [ pri's url role marks ] ; local models
  task_zenka = 'task external.pri.task' ; pri jobsite assess_parallel = 2
  [ backup host.cfg.bak-before-assess-parallel ]
- todo coding seed-retry : a failed cat self-test leaves pri's cpu at
  restart_needed, jobs wait in 'depending' -- a coding restart frees it

## live state [ earlier in the session ]

- local : /etc/protocol-7/host-edit records group protocol-7 ; record
  hosts/pri.json [ role link, ssh-w, af 4, link_user task-worker ] ;
  protocol-7 user has its own ssh key + pri in known_hosts ; pri has
  `authorize-link task-worker` ; /etc/protocol-7/models/host.cfg :
  models.cfg.task_zenka = external.pri.task [ claims work, but pri's
  jobsite dispatches ONE task at a time -> todo assess_parallel ]
- local /etc/protocol-7/jobsite/host.cfg : sync_urls loopback + pri's
  https jobs-sync, token web.auth-issue jobsite-push [ 1 year ]
- LOCAL JOBSITE AND LOCAL HTTPD ARE TERMINATED ON PURPOSE : its pushes
  overwrote pri's web cache [ stale stages, dropped entries ]. pri's own
  jobsite stayed correct, a full pri sync restored the active jobs. the
  owner deletes the 22 leftover web-only cards [ 18 skipped batch, HWWN4
  WYCAC YDO5S 65454 ] in pri's ui

## open, in order

1. DONE : sync_url_roles + receiver rule, QLK closed. next : yourum as
   3rd worker [ same model fits : 6.6 GB of 10 free ; model file, coding
   + models, link to pri, assess_parallel 3 ], the coding seed-retry bug
2. todos open : progress overcount after deletes, address family memory
   [ DoS-safe ], web-auth-gate harness broken on HEAD, coding seed-retry
   leaves restart_needed ; NEW idea : a check that every route-send
   command of a zenka has its cube grant [ see lessons ]
3. kimi noted : bodies between size.buffer.input [ ~237 KB ] and
   max_post_size [ 1 MB ] stall the https body accumulator
4. older queue unchanged : 3MK, yourum 3rd worker, RTY, H2N

## lessons

- harness stubs hid FIVE live link bugs [ runtime import, ->connected on
  a socketpair, no autoflush, no handle registry entry, reloads ] -- the
  first live run is the test
- `reload source` does not rerun init : a key-form change needs a restart
- a sync url is a write grant over another host's web, not a mirror
- never parse a secret with a length guess : a 13-char token printed in
  the fallback branch [ revoked + re-minted ]
- see [[feedback-whitelist-static-calls-and-v7-rewrap]] -- also : a NEW
  route-send command needs its access.zenki grant, stub tests never show
  the refusal [ models -> coding.inference-status, e2d628f30 ] ; the
  refusal is logged by CUBE, the caller only sees an empty answer

#,,,,,,,.,,,,,...,,,.,.,.,,..,,,.,.,,,..,,,..,..,,...,...,..,,.,.,,..,..,,...,
#JR3MCGJ3VQ4TJL66VUAELG252T7S3BZRGSVGML7OTBZ6NLDFT3NWT6FICRP7SG3NUM5W34U6JDQIY
#\\\|EDRMCU66XKCTLB47VSTATCW2L3BZ2KO2FEAEQOJHZ4YCABMFAXP \ / AMOS7 \ YOURUM ::
#\[7]KM5LDWSMFVIKLY7R6QQTD7JAB2ZJXJCMREB4WSURDDSBFPZN2KAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
