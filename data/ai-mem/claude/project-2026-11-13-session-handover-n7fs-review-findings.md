---
name: session-handover-n7fs-review-findings
description: 2026-11-13 Fable N7FS review findings 2 3 4 6 landed [ receipts, scrub, trash, per-root, receiver mode, service root ] ; open 5 7 8 9 ; add-only log mount sketch ; deploy notes
metadata:
  type: project
---

2026-11-13 : Fable review [ ~/.n/private-notes/fable-n7fs-review-2026-11-11.md ] worked
through with kimi + review. commits [ base, pushed up to a869f77f4 ] :

- 02327836a finding 4 : receipt coverage sizes-only \ sampled \ full, keyless
  `holder-scrub`, drain trusts only full receipts, byte-weighted 64 bit sampling
- 5a91a66dd test sandboxes reuse ~/.7/inline-code [ no make per test ]
- e1bc31c26 finding 2a : gc grace 1 d + `.trash/<date>/`, purge \ restore, per-root
  holder subdirs `r-<tag>/`, `holder-migrate`
- 73327eae0 finding 2b [ K3.1 high ] : receiver mode `ssh-receiver:`, root-signed
  requests [ counter spent BEFORE the action ], P7SH outer head signature
- a869f77f4 finding 3 : incremental receipts [ entry `added` + covered digest ],
  place ends with holder-check, 2 d unreachable grace
- finding 6 [ this commit ] : disk \ category bound to one root [ self-certifying
  `.n7fs/seal-root` = a guard against MISTAKES, not a boundary ], multi-root
  holder-receiver-line ; service root = `n7fs root init <file>`

DEPLOY NOTES [ nothing live yet ] : all hosts with n7fs upgrade TOGETHER [ new head
format ] ; run `holder-migrate` on every flat holder BEFORE receiver mode [ flat
holders do not separate roots ] ; then switch holders to `ssh-receiver:`.

OPEN : finding 5 [ map sharding, commit by bytes \ time, chunked manifests,
retention per tree prefix e.g. 24 hourly 30 daily, repack -- DESIGN CHOICES for the
owner first, fresh session ] ; 7 [ rollback : signed head time + other holders'
versions, tree complete \ partial, registry in the sealed map ] ; 8 [ snapshot
before pull ] ; 9 [ `n7fs cycle`, monthly restore drill ] ; 10 small [ receipts
signed by the same host key, local clock ].

ADD-ONLY LOG MOUNT [ owner idea, first user of the add-only writer ] :
backing mount `/data/disks/p7-log-archive` [ PATH-ROLES.md note ], address
`/N7FS/<disk id>`. the mount encrypts : per-segment one-time X25519 key + AEAD to
the archive PUBLIC key, ciphertext chunks written at once, one-time secret
forgotten at seal -> older files unreadable on the server by math. read policy
default 'open segment' : recent plaintext + segment secret only in an mlocked,
MADV_DONTDUMP memory cache, best effort -- a restart loses readability, never
data ; strict mode = write-only. rotation by size \ time. names \ sizes stay
visible unless chunks go checksum-named with a sealed index.

ALSO : the slow-host day was FanControl holding PROCHOT EXT [ board throttled the
CPU to 545 MHz ] -- killed, updated, fixed ; check `% Processor Performance` first
next time. kimi cost : see [[kimi-dispatch-model-verify-before-send]].
[[n7fs-first-live-round]] [[n7fs-host-migration-goal]]

#,,,,,,..,,,.,.,.,...,..,,...,,.,,,..,...,,,,,..,,...,...,...,..,,,,.,..,,.,,,
#5ARBR3XGTYMDNH4S5CVQSDXA6FZPCKDKVXZ27ZLOAKWOIT6HVZ3GVNEYWLC3T2MPACCDTI3R62LDC
#\\\|R2626ZI45D4ONRMMBIO433EJB5H5IS3NJVW6VIJI2MY3GZNGG72 \ / AMOS7 \ YOURUM ::
#\[7]E7W46QHCLX3HYX3LQALVYADK7ULIAOHGWIL254IOQ46QNMYMICBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
