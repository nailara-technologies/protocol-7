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

DEPLOY NOTES : code is ON all hosts [ pulled with the needrestart exemption ], but
n7fs is NOT in use anywhere until all clear -- no holder \ place \ pull runs yet ;
all hosts with n7fs upgrade TOGETHER [ new head format ] ; run `holder-migrate` on every flat holder BEFORE receiver mode [ flat
holders do not separate roots ] ; then switch holders to `ssh-receiver:`.

OPEN : finding 5 DESIGN DECIDED [ N7FS-SEALED-REPLICAS.md 'map growth and
retention' : 256 shards, 64 MiB \ time commits, chunked manifests, retain ladder
in the sealed map, repack ; all times ntime, durations in Y levels = ntime year
/ 13^n [ owner : YOURUM = 13, no base 60 \ unix ] ] ; stage 1 Y ages e0c4b7916,
stage 2 sharded map 1061c8697 [ kimi sealed root + all shards under ONE nonce --
caught in review, now per-blob domains map-shard-XX \ map-tree ; check nonce
domains in every new sealed kind ] ; next stage 3 chunked manifests, 4 retain +
repack ; 2026-11-14 : Fable review of finding 5 [ R1-R17 ] fixed in 4 groups : 771276547 R1 R2 R8, f63ba9f91 R5 R7, 46d246899 R3 R6 R4 [ shard key = 2 b32 chars of the bmw part, 1024 shards ], 88da14772 R10 R11 R13 R14 R15 ; Fable design stage 1 = 3d40bfd51 [ receipts per root, clock floor ]. TEST RUNS : check every script's EXIT CODE and that it printed its "passed," summary -- summing summaries alone hides a script that dies mid-run [ 2026-11-14 : test-n7fs-retain.pl died at an epoch boundary, fixed with a pinned test clock N7FS_TEST_NTIME, warned when set ]. ALL review findings R1-R17 FIXED : 3203321b7 [ head v2 = Fable design stage 2 + R9 SIV nonces ], 35a32e27b [ R12 R16 R17 + SIV subkey ]. NEXT : Fable design stage 3 [ peers, head_survey, heads, head-refresh, stale refused ] ; + derive a separate SIV subkey [ head v2 _long_id hashes with the same outer key that encrypts : key separation, not a hole ] ; owner answers 1-6 recorded at the end of the Fable design file [ registry : middle way, p7 config style, aligned ]. pushed by the owner up to 94675d85e [ 2026-11-14 ]. DONE : PENDING DOC REFS for the next commit [ N7FS-SEALED-REPLICAS.md derived placement paragraph ] : data/md/design/EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md [ rolling validity window prev/current/next, totp shape ; first seen rule ], data/md/design/CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-VALIDITY.md §2 [ epoch as temporal network root, <epoch>:<key>[:<name>] auto-closing collision exclusion ], data/tasks/epoch-validity-search-protocol.md [ search result checksum IS its route = the rocket ] ; 7 [ rollback : signed head time + other holders'
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

DONE [ same day ] : `p7-deps install-service` writes /etc/needrestart/conf.d/protocol-7.conf [ needrestart never restarts Protocol-7.service -- it would kill the desktop in X \ native mode ] ; check-service reports it. run `sudo bin/p7-deps install-service` once per host.

ALSO : the slow-host day was FanControl holding PROCHOT EXT [ board throttled the
CPU to 545 MHz ] -- killed, updated, fixed ; check `% Processor Performance` first
next time. kimi cost : see [[kimi-dispatch-model-verify-before-send]].
[[n7fs-first-live-round]] [[n7fs-host-migration-goal]]

#,,..,...,,,,,,,,,.,.,...,,,,,,.,,,,,,,.,,.,.,..,,...,...,..,,,,.,...,,,.,.,,,
#DRZEXJ2HWZJC64ZVFKRKDHTAMR4YMPNGIKSXIZ3VFWIJJJ3EYQFND4YZDCNKKWGUPRSUV3ERTMVBY
#\\\|R5MATJVXEKPT2AHD2Y4AZJJHOCSDFG3AM5JN5ZM64RT26VBNRJL \ / AMOS7 \ YOURUM ::
#\[7]ZWCHQDMT4ZF6775VNGMJ55DB6263OUYYJF3PXCHRTK34JZNSCWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
