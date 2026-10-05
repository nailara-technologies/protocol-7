---
name: project-2026-10-04-session-handover-osf-cache-stage2
description: handover of the 2026-10-04 session [ last cb6e0ac8c ] -- osf-cache stages 2 \ 2b \ 2c landed and verified live [ local holdings, peer lookup ], stage 3 task file ready for kimi, plus loader \ storage \ hook \ v7-zenki fixes ; stage 3 landed + live-verified later the same day [ 512c58752 ] ; next = stage 4
metadata:
  type: project
---

session 2026-10-04, last commit `cb6e0ac8c`. previous handover :
[[project-2026-10-03-session-handover-osf-os-pkg-space]].

## landed

- **osf-cache stage 2** [ `01edae6b8` ] : incremental holdings scan
  [ name size mtime ctime inode ], yaml state via format.yaml,
  query_local \ has wire format \ merge_replies ; hash layers :
  anchors as `<algo>:<hex>` [ sha256 \ sha512-only repos ], **bmw384
  [ B32, 77 chars ] = internal id** -- why 384 + human handles in the
  design doc `## hash layers`
- **stage 2b** [ `a632330eb` ] : running zenka -- init_code defaults
  only, `osf-cache.startup` post-drop [ index build, sliced rescan
  timer ], cmds `has` \ `status` \ `rescan`. live : 5 sources, 90183
  anchors, 18 cached debs, 8 anchored
- **stage 2c** [ `d180d43b0`, `cb6e0ac8c` ] : `osf-cache[peer]` subname
  instances [ own state file + cache dir, created by init_code via
  `file.make_path` with owner ], `osf-cache.peers.list` [ `list sessions
  osf-cache` ], `osf-cache.lookup` [ deferred reply, `<sid>.has` fan-out,
  5 s timeout ]. verified live with an EMPTY peer
- `v7-zenki.sid-lookup <cube-sid>` -> instance id [ for restart \
  terminate ; details via `v7-zenki.list zenki|subnames <instance>` ]
- loader : plugin.* listed in modules.load were never reloadable
  [ `a629e0b43`, see [[reload-success-doesnt-guarantee-new-file-loaded]] ]
- storage checksum plugin hashed the PATH string, not the file ; cache
  ignored the algorithm ; `bmw.512_32` -> `bmw.512.B32`, new
  `bmw.384.B32`
- post-checkout hook skips other worktrees ; powershell on-demand
  timeout 1800 s

## next steps

1. **dispatch stage 3 to kimi** once its 5h window resets :
   `data/tasks/osf-cache-stage3-segment-fetch.md` [ segment command,
   transport decided with the user : one request per segment, B32 in
   args, cube never blocked ; fetch -> .partial -> verify size + anchor
   + bmw384 -> place ]. k3 ran out of the 5h window mid-task in 2c --
   prefer k2.8 unless the task is genuinely correctness-critical
2. **holder test for stage 2c** : copy 2-3 anchored debs into
   `/var/protocol-7/osf-cache/peer-archives/` as protocol-7 [ user ],
   `p7c <peer-sid>.rescan`, then `p7c <main-sid>.lookup <anchors>`
3. stage 3 live test : peer fetches from main into peer-archives
4. later : cross-host peers via the `discover` zenka [ swap
   `osf-cache.peers.list` ], stage 4 multi-source segments + merkle

## update later the same day [ `16e32691c`, `512c58752` ]

- **stage 3 landed and verified live** : kimi [ k2.8 ] implemented
  segment \ fetch \ verify ; review added a request `seq` so a late
  reply to a timed-out segment is dropped [ it used to advance the
  offset and leave two requests outstanding ]. live : peer fetched
  igt-gpu-tools from main, 2035064 bytes, 32 segments, 1.2 s,
  byte-identical, holdings updated, main lookup lists the peer
- live-only fix : `segment` had to go on the main's
  `access.cmd.usr.cube` line [ routed calls arrive as user cube, see
  [[feedback-whitelist-vs-access-cmd-usr-cube]] ]
- holder test [ step 2 below ] done : lookup finds the peer for hello
  \ povray ; libprotocol-http2-perl is not in the index [ version not
  in testing ]
- lookup with unknown anchors FIXED [ `30636818e`, user's rule ] :
  known ones are looked up, an `unknown :` line lists the rest ;
  nothing known [ incl. a single anchor ] -> mode false
- 0640 fetched files : FIXED later [ file_mode, see stage 4 section ]
- next : stage 4 [ multi-source segments + merkle ], cross-host peers
  via `discover`

## stage 4 landed [ `1c15c65d9`, after midnight 2026-10-05 ]

- decided with the user : REAL binary merkle tree now [ a flat list
  would change the root later ], 64 KiB leaves, bmw384, leaf `\x00` \
  inner `\x01` prefixes, odd node promoted ; root trust = all asked
  agree [ own nodes ], `root_quorum` //= 5/7 once n holders exist
  [ variants may follow, rule lives in `osf-cache.merkle.quorum` ]
- task file `data/tasks/osf-cache-stage4-multi-source.md`, kimi k3
- verified live : main and peer compute the same root for
  igt-gpu-tools, peer fetched libopenexr [ 12 segments, 0.7 s ]
  byte-identical ; trees backfilled into `/var/protocol-7/osf-cache/
  merkle/` [ shared, content-addressed ]
- NOT verified live : parallel fetch from 2+ holders and bad-holder
  exclusion [ unit-tested with 2 and 7 holders ] -> needs a third
  instance, e.g. `osf-cache[peer2]` [ by_subname.peer2.cache_dir in
  zenka.v7 + v7-zenki start ]
- kimi stopped before regenerating the whitelist -- after any kimi
  job, check `subroutines.load-early` was regenerated
- later the same night : LIVE multi-source verified via a third
  instance `osf-cache[peer2]` [ `by_subname.peer2.cache_dir =
  /var/protocol-7/osf-cache/peer2-archives`, `ee2d3623d` ] : igt-gpu-tools
  [ 32 segments ] and povray [ 23 segments, 0.7 s ] from main + peer,
  byte-identical
- fixed : fetched files were named after the pool basename [ no epoch ]
  -> `osf-cache.debian.archive_name` [ apt QuoteString : `1:3.7` ->
  `1%3a3.7` ] ; and they came out 0640 [ zenka umask ] -> chmod
  `<osf-cache.cfg.file_mode>` //= 0644 before the rename
- still not live : bad-holder exclusion [ needs a node that serves
  wrong bytes on purpose ] ; next = cross-host peers via `discover` or
  stage 5 credits

## live facts

- two osf-cache instances share one name -> address by session id
  [ `p7c <sid>.<cmd>` ] ; `v7-zenki.subname-sids peer` finds the peer
- cube `has_access` maps sids to names -> the name grant
  `osf-cache.has` covers `<sid>.has` [ a new grant needs cube `reload
  config` first -- that was the only cause of the first failure ]
- I may restart storage and osf-cache myself [ user, 2026-10-04 ]

## workflow lessons

- standalone tests passed while the first live start failed four ways
  -> [[standalone-test-harness-zenka-environment]] ; harness now mirrors
  the zenka
- kimi pitfalls seen : multi-word `qw| a b |` as a scalar, `<word>`
  without a dot [ perl readline ], new test packages without `use
  English`, regenerating whitelists of unrelated zenki, an unfinished
  run [ quota ] -- always run the tests yourself and check `git status`
  for out-of-scope files after a kimi job
- pre-commit hook : `# descr` max 55 chars

#,,..,.,,,..,,,,.,..,,..,,,.,,.,,,.,.,,..,,,.,..,,...,..,,.,.,.,.,.,,,...,.,,,
#BP7QVW3FWKQY53ZOGRVYODVWRANIPIS7LRU6IOEGJWCRIC2RZ5KXRVTLUO2Y4D33U3FLYCI4EWHUW
#\\\|XCF676DXF5FYG54LAEP57PSXU3IVJNGPEM6YXOTIKJXKG3HFK2Y \ / AMOS7 \ YOURUM ::
#\[7]ZJZXRHTP7KHHY4PZYB5HEVDBS7JEY3JRW4C7LN64ZDTW4YPOQOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
