---
name: n7fs-go-live-and-terminal-follow-ups
description: n7fs go-live DONE 2026-11-15 : 4 receiver holders, full scrub receipts, 4 copies ; pipelined holder sessions [ f5ba1c0d6 7b4814f6c a4b285287 ] ; follow-ups AMOS7::SSH, send buffer, progress line
metadata:
  type: project
---

**go-live 2026-11-14** [ owner all-clear, root@ on srv-U V A authorized ] :
- head v2 [ 190a63c7a ] refuses v1 heads : every old holder failed `outer authentication`.
  owner chose a RE-SEAL from the still present sources, with NO doubled remote space :
  remote old copies deleted before each new one ; only azurum keeps
  v1-old fallback [ removed 2026-11-15 ]. local v1 key-side state [ removed ] :
  `~/.n/n7fs-v1-old-2026-11-14/`.
- order : delta + yourum unregistered [ registry only, `holder remove` WITHOUT -root-key :
  with it the sealed-registry publish reads every holder and fails on a v1 head, AFTER the
  vault save ] ; place onto pri + home-packed ; then wipe delta \ yourum, `holder add` again,
  relay from pri ; then holder-migrate n/a [ fresh holders start per-root ], receiver mode,
  cycle config + `cycle -dry-run`, owner sees the destructive gate first.
- the owner runs passphrase steps from a scratchpad script [ read -s once, -pass-fd 3 ] in
  tmux session 0 ; I can capture-pane it. drain typed keys before a confirm prompt.
- fixes : 507361f8a root_dir ignores a seal-root hash [ place without -root ] ; 6032f6026 ': '
  warning prefix + `.: N7FS :.` usage ; 7e947d5d9 legacy warning once ; 33795a138 batched
  commit uploads [ the sharded map rewrote up to 1024 shards per commit, each several ssh
  forks of a 1.1 GB perl : 234 ms -> 6 ms per node ]. benchmark :
  scratchpad bench/place-bench*.pl [ local vs ssh:azurum:/tmp ].
- format-code -c missed a bareword FALSE in a data/lib-path .pm [ found at runtime ] : check why.

**follow-ups, owner ideas** :
- AMOS7::SSH on Net::SSH2 [ what the ssh zenka autoloads ] : persistent in-process session,
  ~/.ssh/config subset, ProxyCommand over a socketpair [ hysteria nc ], strict known_hosts ;
  system ssh silently only when acceptable [ mux works ], else a degradation warning. then
  native transports \ UDT behind it, standalone or as a zenka first. kimi K3.1 candidate.
- terminal : progress line like bin/format-code show_progress [ \r ] ; warnings start with
  "\r\n" so no shared state ; cursor hidden while it runs, restored on END \ INT \ TERM ;
  confirms like bin/ncode user_confirmed [ one key, raw mode ] and warn_apply [ blinking
  .: A P P L Y I N G :. , any key aborts ] before destructive cycle phases ; no tty = flags.
- cores : the start [ placement, dry run, place each replay the journal over 92k nodes ]
  and sealing are single core. first a cached replay state shared by the three, then N
  forked sealers building their own packs [ parent maps + commits, head last ] ; default
  workers = twice the cores [ owner 2026-11-14 ], an option overrides. a shared queue,
  not fixed columns : workers pull small batches when free, biggest nodes first, so the
  end does not taper off [ like _parallel in the relay ]. reuse the
  multi-core pattern of update-signatures \ verify-p7-signatures [ sourcecode zenka, src/ ].
- json : n7fs was meant to be json-free, only the registry \ cycle state moved [ 3e613a33a ].
  JSON::PP is the single-core hot spot : 1024 shards encode 3.1 s vs 0.12 s XS, decode
  23.8 s vs 0.16 s. step 1 [ after the kimi run ] : JSON::XS, JSON::PP fallback with a
  degradation warning, compare canonical bytes on real map data first [ SIV names ].
  step 2 : a json-free n7fs format version [ shards, manifests, journal ] -- design stage,
  dual reader or re-seal, Fable window candidate.
- send buffer [ owner idea 2026-11-14 ] : -bwlimit is a peak, the gaps [ commits, sealing,
  one upload in flight, _throttle restarting per blob ] stay unused. one long-lived sender
  per holder draining a bounded spool queue [ ~256 MB ] at the cap with one token bucket ;
  sealer + commits only enqueue ; a commit is a barrier [ wait for its blobs, then the
  head ]. flat predictable traffic, gentler on the usb wlan. before more parallel uploads.
- -check-full : 3 ssh range reads per node ; use holder-check -scrub for full coverage until
  it is batched.

**go-live DONE 2026-11-15 10:3x** : zulum delta yourum home-packed all on ssh-receiver:n7fs-h-*
specs, each 92486 nodes \ 16297969029 bytes, full scrub receipts [ v217-v220 ], placement
"incoming target 2 : 92486 nodes at 4". delta was repaired afresh [ golive-7a : remove, drop pin
5N4ESVV, head moved aside to srv-V /root/n7fs-backup-2026-11-15/, add, relay -list 0 blobs, adopt ].
all old backups removed 2026-11-15 [ owner : first import state ] : head copies, azurum v1-old 18 G, local v1 + head state.
- holder transport [ spec N7FS-SEALED-REPLICAS.md, holder transport section ] : the per-call
  ssh design was unusable [ owner : 0.8 % cpu for hours, would have taken days ]. now
  `n7fs-receive session` [ has \ get \ get-range \ put ], pipelined window 64, sets via
  holder_read_many + _prefetch [ map shards, tree indices \ chunks ]. 31 ms per read, 1000 blobs
  145 MB in 12 s. stall timeout 120 s, N7FS_SESSION_TRACE=<file>|1, per-pid channels.
- still per call : scrub batches [ 400 names, remote hashes -- fine ], heads \ lists [ signed ].
- unexplained : first delta scrub sat >10 min, both ends waiting on a read ; rerun passed. if it
  recurs the stall warning + trace show the last request.
- open : zulum holder domain still "pri" ; retire pri [ ssh Host pri, pri.v7.ax vhost \ cert,
  memory files ] ; zenka restart on zulum ; scratchpad worktrees wt \ wt2 to remove.
- I broke the live-tree rule twice this day [ edited Holder.pm while golive-7b \ 7d ran ; the
  placement wrote a trace file named '1' into the repo root ]. n7fs edits : worktree only, copy
  over between runs.

**never edit the tree a live n7fs runs from** : n7fs requires some modules lazily [ Seal
requires Drill at line 488 ] : my uncommitted json_codec edit made the live place fail on
pri [ 2026-11-14 18:5x, home-packed had finished ]. work in a git worktree, or deploy and
restart deliberately.

**live state 2026-11-14 evening** : host hard-crashed under the sustained wlan push [ usb
wlan, same as every holder push ; /tmp wiped ] ; home-packed 12 G of ~16.3 G committed, pri
empty. c4fd04a42 background uploads ; script now ~/.n/n7fs/golive-2.sh [ -bwlimit 4M ].
owner order : wire the LAN cable, finish the re-seal, then the native linux install.
[[n7fs-host-migration-goal]] [[session-handover-n7fs-fable-design-built]]

#,,,,,,,.,,,.,.,.,,..,,,,,,..,.,.,,..,...,.,.,..,,...,..,,...,,,,,...,,..,.,.,
#FD33V7MQQG7MKLOOHA5MFLH26775TSSQXHSUBAUN4OMF5I3ALF6WQ66O76JMPG27H7YDX6BT6LQJC
#\\\|OK4K7AIVU5NWVPQ63WORWITKQGKJIAQM4JR54AC5BXHBLGM4YBT \ / AMOS7 \ YOURUM ::
#\[7]MAAHFWQLKWOBPR5PGR2OVGVI4HSSUWFBU3J34YCXHC4MG6LGHCCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
