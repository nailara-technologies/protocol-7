---
name: n7fs-go-live-and-terminal-follow-ups
description: 2026-11-14 n7fs go-live : v1 holders unreadable by head v2, re-seal from source ; sharded-map upload regression fixed [ 32383cdf4 ] ; follow-ups AMOS7::SSH, progress line, ncode-style confirm
metadata:
  type: project
---

**go-live 2026-11-14** [ owner all-clear, root@ on srv-U V A authorized ] :
- head v2 [ 3203321b7 ] refuses v1 heads : every old holder failed `outer authentication`.
  owner chose a RE-SEAL from the still present sources, with NO doubled remote space :
  remote old copies deleted before each new one ; only azurum keeps
  `/data/disk/n7fs-2026-11-packed.v1-old` [ owned, fallback ]. local v1 key-side state :
  `~/.n/n7fs-v1-old-2026-11-14/`.
- order : delta + yourum unregistered [ registry only, `holder remove` WITHOUT -root-key :
  with it the sealed-registry publish reads every holder and fails on a v1 head, AFTER the
  vault save ] ; place onto pri + home-packed ; then wipe delta \ yourum, `holder add` again,
  relay from pri ; then holder-migrate n/a [ fresh holders start per-root ], receiver mode,
  cycle config + `cycle -dry-run`, owner sees the destructive gate first.
- the owner runs passphrase steps from a scratchpad script [ read -s once, -pass-fd 3 ] in
  tmux session 0 ; I can capture-pane it. drain typed keys before a confirm prompt.
- fixes : e3afc30f8 root_dir ignores a seal-root hash [ place without -root ] ; e058b8a74 ': '
  warning prefix + `.: N7FS :.` usage ; aeadda003 legacy warning once ; 32383cdf4 batched
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
- json : n7fs was meant to be json-free, only the registry \ cycle state moved [ 973608c34 ].
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

**receiver switch 2026-11-15 : STOPPED, delta head carries zulum's holder id** :
- all four holders relayed + adopted, sampled receipts, placement 4 copies. dedicated key
  ~/.ssh/n7fs-holder + Host n7fs-h-{zulum,delta,yourum,home} [ top of ~/.ssh/config,
  HostKeyAlias pri.v7.ax \ azurum ] ; restricted lines installed [ /usr/bin/perl
  /usr/local/protocol-7/bin/n7fs-receive ; azurum : separate clone /usr/local/protocol-7-n7fs,
  its login-screen-auth runs from the old /usr/local/protocol-7 ] ; holder pri renamed zulum.
- seal state [ ~/.n/n7fs/seal-roots/<root>.state/state, plain json ] : all four on
  ssh-receiver:n7fs-h-* specs. pins : zulum IOKRYKX v209, home P3QCNWN v213, yourum UHG6UQU
  v214, delta 5N4ESVV v216. head files [ r-5HPWKEH/3MCP5ZMU.. ] : srv-U v209 [ 22:11, its
  registry publish refused : old holder id in the line ], srv-V **v215 written 05:16:25 with
  holder IOKRYKX**, srv-A v214, azurum v213. every rename since refuses at delta.
- backups : hosts /root/n7fs-backup-2026-11-15/ [ head files ], local ~/.n/n7fs-backup-2026-11-15/
  [ state ]. run NOTHING that publishes or writes receipts until fixed ; never re-pin delta
  to the head's id [ hands zulum's identity to delta's spec ].
- causes found : [1] holder id = bmw of 'ssh-receiver:<alias>:<dir>' -- receiver lines are
  per alias [ fixed by hand ] ; [2] n7fs mux ControlPath %C ignores the alias : srv-V and
  n7fs-h-delta shared one socket [ fixed in tree : %n-%C, uncommitted ] ; [3] rename saves the
  registry before the publish [ partial state on failure, like holder remove ] ; [4] scrub on
  a full-shell holder sends 'scrub' to bash ; [5] the 05:16 publish [ registry_publish ->
  head_refresh -> _context takes holder_id from the head READ at that spec ] sealed zulum's
  id into delta's head : how is open -- reproduce in a git worktree with two holders.
- also uncommitted : Seal.pm 'head belongs to another holder [ found, pinned ] at <spec>'.

**never edit the tree a live n7fs runs from** : n7fs requires some modules lazily [ Seal
requires Drill at line 488 ] : my uncommitted json_codec edit made the live place fail on
pri [ 2026-11-14 18:5x, home-packed had finished ]. work in a git worktree, or deploy and
restart deliberately.

**live state 2026-11-14 evening** : host hard-crashed under the sustained wlan push [ usb
wlan, same as every holder push ; /tmp wiped ] ; home-packed 12 G of ~16.3 G committed, pri
empty. b611a3601 background uploads ; script now ~/.n/n7fs/golive-2.sh [ -bwlimit 4M ].
owner order : wire the LAN cable, finish the re-seal, then the native linux install.
[[n7fs-host-migration-goal]] [[session-handover-n7fs-fable-design-built]]

#,,,,,..,,,,,,,.,,,.,,,..,,,,,,,.,,.,,,,,,,,.,..,,...,...,.,.,,.,,,.,,,,,,,.,,
#3QEJZFLI3ALFQ6GYRTZQQTPXZNX7LAB6P2YYUS73CTAJJ66CDL5WTH5JLWNU23JXRZX4C2XPTYPPE
#\\\|A2D3FCUX6JY2TYOTRBEMGGTGWUOWMLZPNXFLNZDM3PIJHENU7CP \ / AMOS7 \ YOURUM ::
#\[7]H7C3Q6C3NBT6FTMQEAEVGJ4GK7CL3M4C6AIYA3YNRYAFNMH3S4DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
