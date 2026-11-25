---
name: session-handover-place-httpsd-core-sweep
description: NEWEST 2026-11-22 handover -- n7fs tier A placement running on fast place ; httpd signed files work over http, httpsd fixed locally but its live https test is still open ; CORE:: sweep landed ; many briefs written
metadata:
  type: project
---

state at 4ca34687ba [ all servers + azurum's receiver checkout on it ] :

**running \ next**
- n7fs : the rescue disk's tier A [ category 'rescue', 3 copies : home-packed, zulum,
  yourum ] is being placed with the FAST place code [ 9eb58eb462 ] ; the owner runs
  `n7fs place <disk> -root-key vault:main` in tmux on the home server as taeki. receipts
  exist ; the last runs failed only at put-head [ counters, fixed ] and 'background
  upload failed' [ old code ]. check its output first ; then holder-check.
- once tier A is placed with receipts : a new SATA disk arrives [ tue 2026-11-25 ] for
  the W520 ; plan in ~/.n/private-notes/ [ rescue note, 'plan 2026-11-21 : new disks' ]
- httpd signed-file serving : works over HTTP on a real server [ yourum live test passed ].
  over HTTPS it failed on zulum [ empty reply ] -> zulum runs the PLAIN serve_static path
  [ 3dabbb230a ]. fixed locally in c87a047be7 [ httpsd modules.load gets amos7
  crypt.C25519 source like httpd ; /var/protocol-7/httpsd via check-zenka-paths in
  httpsd.pre_init ; whitelist regenerated ] and a5047d3a43's serve_static is back in the
  tree. NEXT : deploy to yourum, run bin/test-scripts/test-httpd-signed-files-live.sh with
  P7_HTTP_URL=https://127.0.0.1 [ P7_HTTP_ROOT + P7_HTTP_HOST = a real vhost dir under
  /var/httpd ], only then zulum, then curl the jobsite page [ full size, no footer ].

**lessons [ see feedback-core-builtins-forked-children-https ]**
- a module that overrides builtins [ File::stat, User::pwent, Time::localtime ] makes
  list-form stat \ getpw* return objects -- use CORE:: [ sweep done, vendored code and
  frozen study files excluded on purpose ]
- work done in a FORKED child compiles on-demand subs in the child only : the parent keeps
  the stub and every child recompiles [ 30x 'loading p7-code' ] -- the modules belong in
  the zenka's modules.load \ whitelist, not in a manual pre_init load
- test HTTPS through httpsd, not only HTTP : the empty-reply bug was httpsd-only
- the sign agent died silently on a late approve [ SIGPIPE ] -- fixed 2581fbccc5
- one root key used from several machines : holder request counters resync on
  'replayed' [ 9eb58eb462 ]
- kimi tends to work around instead of fixing [ /var/tmp fallback, manual preload ] and
  sweeps too wide [ vendored modules ] : review every result before signing

**open small items**
- data/web-root/vhosts/.signed-test-cleanup is owned by httpd [ remove as root ]
- src/download.init_code was left out of the CORE sweep [ LWPx::ParanoidAgent missing
  for the local perl 5.32 floor compile ]
- the template hint 'Try: devmod.current-umask' suggests a module name, not a zenka
- base.handler.deferred_compile treats any CODE ref as 'compiled' [ a stub too ] ; harmless
  once modules are whitelisted, but a later identity check would be cleaner
- n7fs : progress bar + colours [ -nc ], tcflush before passphrase prompts [ brief ]

**briefs written this session [ data/tasks/ ]** : token-lease-and-lan-media, desktop-ui-
surfaces [ + inventory ], document-scan-archive, input-and-window-forwarding, work-and-
private-contexts, intent-and-pending-decisions, httpd-signed-files, paragraph-template-
engine, n7fs-web-desktop, recovery-partition, n7fs-logical-trees-and-mount [ follow-ups ].
built : token leases + ui session renewal, user groups, dpi control, theme tokens,
povray icon set, xpra forwarding, generator signing, n7fs set-category \ place speed-ups.

**update [ late 2026-11-22 ]**
- signed-file serving is LIVE on zulum and yourum [ http + https live tests passed ; the
  jobsite page is served stripped, 134547 bytes, no footer ]. httpsd names its key
  explicitly [ 8fc2eec798 ]. n7fs progress bar \ colours \ tcflush landed [ c85f7b18ea ].
- kimi session_21f5765d-0359-4ba3-b336-b0ec3817378f is building : signature_mode
  off|verify|require + types + per-vhost override, a verify-vs-BMW benchmark, a
  persistent BMW-keyed verification cache and a bounded RAM cache [ inotify ]. REVIEW it
  [ module lists + whitelist, no workarounds ] ; then add `tmpl` to the default types and
  verify templates BEFORE httpd.process_template [ owner : .tmpl is a default type ].
- place of tier A still running on the home server [ owner's tmux ].

**place blocked by memory [ found end of 2026-11-22 ]** : the system zenka's watchdog
[ mem.max_used = 98 % ] killed `n7fs place` three times on the 16 GB home server, place
itself at ~50 % rss [ the 'background upload failed' was the same kill ]. root cause :
place materialises the whole placement plan [ ~270,000 nodes ] in memory, plus upload
children. NEXT : kimi task -- stream the plan [ per tree \ chunk ], bounded memory ;
pass a background upload child's error text to the parent [ only its exit status
arrives today ]. stopgap if needed : temporary swap or N7FS_UPLOAD_JOBS=1.


**update [ session 2, 2026-11-22 ]** : all five hosts on c88535f844.
- place streams its plan [ 7712fa91b2 ] : 285 MB at 10k, 521 MB at 50k nodes ; resume alone 456 MB -- the per-node index / holder status maps are the rest [ follow-up ]. progress total fixed, bar clears left-overs [ 854712e655 ]. tier A placing on azurum.
- signed files [ 0138c7febe ] : modes, trust-bound caches, every process_template path verified, template type = name minus .tmpl [ bare = html ], asc in mime table, no extension = asc, system mime db fallback. live tests pass on yourum + zulum [ 214ab44c9b made them deterministic ].
- readme recent developments rewritten [ c88535f844 ] ; next : split the ~160 line "interacting" section.
- open : remove data/web-root/vhosts/.signed-test-cleanup as root.

#,,.,,.,,,,,.,.,.,,..,,,.,...,..,,.,.,,,.,.,.,...,...,..,,..,,,.,,..,,,.,,,..,
#6QPYAF5EEG4ASK2FRREDKZBE3CRVATGWMCAYI4F5J27NMYMDLINMRF2LFRBQTWB7HELK3AITDKP32
#\\\|22W5LH47E2B3XYHPPWY32A3AZDV2D7FRCRVUVLCQZDAST5Q4TKY \ / AMOS7 \ YOURUM ::
#\[7]PNW4VNUVCLVKBGRCH5PQI442TH3LD5PN6P4QGG43KXFAZM5CF6BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
