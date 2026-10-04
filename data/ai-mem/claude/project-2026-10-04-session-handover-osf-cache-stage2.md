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
- open : one unknown anchor fails a whole lookup [ skip-and-answer
  may suit batches better ] ; a fetched file is 0640 [ partial
  inherits the zenka umask ] -- matters once fetch targets a real apt
  archive dir
- next : stage 4 [ multi-source segments + merkle ], cross-host peers
  via `discover`

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

#,,.,,..,,.,,,.,,,,,,,..,,,..,,,,,..,,,,,,,.,,..,,...,.,.,,,,,,..,,,,,,.,,...,
#O5W5PRL5GYMOXQASAJRBTC4AD2SXRSIPG7J4M3ZVLXQLTFDA3GD5WOVUAMQWXURDRIBRZ43NYOB3Q
#\\\|R5XE4BMDO6ANPN5L53VYT7EXZ7YGF7HEY654TUBZDADDPX6QDQI \ / AMOS7 \ YOURUM ::
#\[7]EJJN2BCGAD26WGVBWEATY2E5AVPTFD3RVBWM7L3ZAC2N2PUIUYAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
