---
name: project-2026-10-18-session-handover-n7fs-truth-srv-U
description: START HERE -- session 2026-10-18 handover [ last 106b7a331 ] : bin/dependencies retired, N7FS v1 on base, truth fallbacks bit-identical, computed AMOS7 module versions, srv-U prepared for cpu inference ; open : srv-U model switch + first coding start, memory-cap task, device db, the `:` model resolver
metadata:
  type: project
---

previous : [[project-2026-10-17-session-handover-installer-cloud]].
budget at the end : claude 7d ~92 % [ reset wednesday ], kimi ~70 %,
cloud credits $58 [ expire 2026-11-05 ].

## landed [ all pushed to hub ]

- **deps line closed** : root runner, detect-hw [ -write ], hw profile
  hw-thinkpad-sandybridge, legacy audit -> `bin/dependencies/` RETIRED
  [ e90ff2cb3 ] ; Inline::C + gcc declared ; setup configs on
  bin/p7-dist-upgrade.
- **N7FS v1** [ d13fc7ef3, squash of dev/n7fs-v1 -- branch + worktree
  deleted ] : bin/n7fs + AMOS7::N7FS*, BMW384, single-dash options,
  epoch-window upgrades ; spec data/md/design/N7FS-SPEC.md, as built
  N7FS-FORMAT-1.md ; design notes in base.yaml N7FS entry [ root \
  disk-id \ <mount>:<disk>, clone + vm rollback window, placement and
  transport, `:<content>` addressing, block dedup on the mod-13 window ].
- **truth fallbacks bit-identical** to the compiled ones [ 73993a86d ] ;
  truth = n mod 13 square-class table [ topic-harmonic-mathematics ] ;
  BitConv + ELF fallback fixes ; amos-chksum -VS was hashing a hash ref.
- **module versions** [ ac8317cda ] : update-amos-versions computes
  `AMOS7::<M>-VERSION.<amos>` over name + normalized source [ whitespace
  and comment-box markers ignored -> sign-run reflows keep versions ] ;
  $ALGORITHM_VERSION split ; $VERSION not exported.
- **srv-U** : pulled via pull-git to dc2da9082 ; nameserv EDNS fix for
  Net::DNS 1.36 [ udpsize ] live ; host.cfg coding \ system \ jobsite
  [ root:root 0644 ] with layers 1 + 3 [ context cap 32768, system zenka
  llama-server limit ] ; /data/models now 2775 ; Qwen3.8 9B Heretic
  Q4_K_M downloaded via fetch-files [ check it finished ].

## open, next steps

1. srv-U : model ids are `<install-path part>:<content part>` -- the
   host.cfg files still name 72T4WFI:TK55OIY [ did NOT resolve ]. find
   the Qwen3.8 id on srv-U [ `p7c models.list models :QDBKEXY` ], set it
   in coding [ model_id + path ] and jobsite host.cfg, restart those two,
   first coding start with a memory watch, one jobsite assessment
   [ data/tasks/coding-cpu-host-setup.md ].
2. resolver : accept the `:<content>` half id in models get_path_by_amos
   and the jobsite pin [ today only a side effect of base.cmd.list ].
3. data/tasks/memory-cap-scope-via-v7-zenki.md [ layer 2 : transient
   scope by v7-zenki, two commands, refuses foreign pids and caps below
   current use ].
4. data/tasks/device-database-auto-install.md ; jobsite sync partition
   + presence [ data/tasks/jobsite-sync-multiplex.md ].
5. small : a test case for comment-box reflow in
   test-amos-module-versions.pl ; three old cpu coding tests fail on
   HEAD too ; amos_chksum of binary input depends on a prior in-place
   utf-8 upgrade [ decide one byte form before N7FS stores binary ].

lessons saved today : [[feedback-self-reexec-tests-need-recursion-guard]],
[[feedback-compare-against-old-behavior]],
[[feedback-single-dash-long-options]], host updates via pull-git
[ [[feedback-no-manual-modifications-on-hosts]] ].

#,,,,,,..,...,.,,,.,,,..,,..,,.,,,..,,,.,,...,..,,...,...,..,,,.,,.,,,.,,,..,,
#UBY36HXQEYMQM4ACASEH3ESMCYXE3HC7L67C6BA2NLYF2QWXQFFEALFB7UMZPMNCV4R7H236SAF6Q
#\\\|DWAAYTJLJ7V27SYUDQV3UAUSSGXHV3M56XBO2AV6EZHU2YBFPTI \ / AMOS7 \ YOURUM ::
#\[7]KHFOHX6FATRCXPFJLEXI67ZZZZAXDFUFNOZHE7HO66UKJARZCEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
