---
name: project-2026-10-09-session-handover-acme-async
description: handover of the 2026-10-09 session [ 650b89ec7 .. b2130608c, pushed, both remotes on 9883 ] -- letsencr acme flow on the event loop [ stage A + B, live on staging + production ], image metadata stripped from history, nameserv txt records, coding gpu recheck, outer cube = ext-cube decision, dns knock idea
metadata:
  type: project
---

previous : [[project-2026-10-09-session-handover-remote-rollout]].

## landed [ all pushed ; pri + atom run 3X2YZXGSNY-9883.0 ]

- **history rewrite** : the 3 qwen 2.2 backgrounds carried invokeai_metadata \
  invokeai_graph text chunks [ prompts, seed, models ]. stripped [ pixels
  identical ], renamed by `bin/rename.bmw` [ name = bmw-224 of the bytes ] :
  DRJG.. \ EFKD.. [ kitten ] \ Z5GQ.. ; image commit rebuilt + 4 commits
  cherry-picked, force-pushed hub [ lease ], bundle recreated [ `gbc` alias ],
  remotes rebased [ they carry a local-modifications commit : NEVER hard
  reset them ], local backup branch + reflog gone. old objects still on
  github [ by hash, support request ] and in the remotes' stores until gc
- **letsencr acme flow on the event loop** [ data/tasks/letsencr-acme-async.md ] :
  the old child ran one blocking call [ LWP + sleep ] -- a route-send
  challenge set-up only left AFTER validation [ http-01 never really worked
  for fresh names ; atom's protocol-7.network cert came from a reused authz ].
  now `letsencr.child.acme.*` : order record, phase steps [ directory ->
  account -> new_order -> authz -> setup [ reply handler ] -> propagate ->
  respond -> poll -> finalize -> poll order -> download ], one order at a
  time [ queue ], nonce consumed on use, per-order deadline timer, fail
  answers once, reused authz logged at level 1. transport
  `letsencr.child.acme.request` on clients.https [ kimi, k3 ].
  live : local staging [ failure path ] + atom production for the fresh
  `ui.data.v7.ax` [ full success path ]. old blocking modules removed.
  tests : test-letsencr-acme-flow 48, -acme-async 43, -enroll 74
- **parent timers** : four used `delay` -> fired at once [ rate limits got
  immediate retries ]. now `after`, confirmed live [ retry in 900 s ]
- **nameserv** : add-txt \ remove-txt [ several values per name ], longest
  zone match, NODATA ; child may route them [ letsencr zenka.v7 access ]
- **coding** : spawn path uses dependency.ok_resolve [ cpu fallback waited
  for a model path nobody requested since 1eb8ba2a3 ] + gpu_fit_recheck
  [ respawns gpu once vram frees -- invoke had held it ]
- **design** : cube never public ; incoming later through an OUTER cube that
  is itself the gateway [ registers as ext-cube ], a dmz segment ;
  command-relay = optional adapter ; external stays outgoing only
  [ HOST-SETUP.md, command-relay-zenka.md ]. dns knock for per-session
  incoming addresses [ data/tasks/dns-knock-dynamic-ingress.md ]. image
  surfaces [ data/tasks/image-surface-addressing.md, keyword 'room' ]

## open

1. letsencr retry off-by-one : first retry 900 s, not 300 [ attempt +1
   twice in handler_enrollment_reply ]
2. pri refuses `taeki` through the ssh forward [ auth-keypair : user not
   authorized ] -- pri + atom cube bind 127.0.0.1:42 BY DESIGN : dial
   `ssh -L <local>:127.0.0.1:42` + `p-7-r 127.0.0.1:<local> -host <name>`
3. 10 dead letsencr modules [ listed in the acme-async task ]
4. coding : cpu fallback keeps running once the gpu is back
5. dns-01 live : zones, nameserv on pri + atom, cross-host route to the 2nd
   nameserv, inwx delegation [ user ], wildcard test
6. outer cube \ ext-cube ; p-7-r starting the ssh forward from the host record
7. later : dns knock, image surface addressing [ kitten first ]

## lessons [ see the linked memories ]

- [[route-send-buffers-timer-gets-event]] : reply handlers get ONE hash
  [ params inside ] ; add_timer ignores `delay` -- both hidden by stubs,
  found by the first live run. live-run early, stubs lie about shapes
- a reachability pass [ roots : cmd \ init \ dns providers \ external refs ]
  finds dead modules transitively ; check computed `$code{"..."}` names
- commit hook : descr lines max 55 chars, message = title + empty line +
  `- ` bullets

#,,,.,...,...,.,.,,..,,,,,..,,,.,,,.,,,..,,.,,..,,...,...,,.,,...,,..,,,.,,.,,
#4744RV7XY6PRMCZPOJXMWHPBH2KFWTSKFC3O6PF62BUPVIBL5DFXDC2TP47Q62A4JW5UWWN3D3FDA
#\\\|JO7B4CRJIH6YZVO5HM4QIDLYM3IIY5SDFPEJULBKGJQH7PXKHZ3 \ / AMOS7 \ YOURUM ::
#\[7]VS4M2R2C5WZGHMYTHUA35GZSJLI23PE52LUTSCQK2I7ZUDGG34AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
