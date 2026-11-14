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
[[n7fs-host-migration-goal]] [[session-handover-n7fs-fable-design-built]]

#,,,.,.,.,,.,,.,,,...,..,,.,.,.,.,.,.,...,...,..,,...,...,...,,.,,.,.,.,,,,.,,
#J24WOIBBEZBAYO72QRY3GW5IDDD7GDJXG27CB4QAT6IGA7QOIFLASTXITDBRGRCSK7I5AUZDZGLYS
#\\\|QL2XTUV3QOT4MXDSINYIRIOY7VWH5ZWQHXPSFOSQRJ3JUILZPYT \ / AMOS7 \ YOURUM ::
#\[7]ZX556OYK7KPKRCFXZOCHWLM7SAZDUKLU2BLZSU5EUCUWS3VCFABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
