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

#,,,,,,,.,...,..,,,,,,.,,,.,,,,..,,,.,...,,..,..,,...,...,,.,,...,..,,,.,,,..,
#VS5ZAQ55YTSRHCA57ARUS7UJOJV7ZOIE57JRITHYTAY4DDNLZZ2ZR7TIRLB2LKFPAM5PUY2P6TE4A
#\\\|K5E5PRXRBEGDWRN4OJLFKQ6XEXY7QQGVSXFHOYNBYKXYZ5AU5CL \ / AMOS7 \ YOURUM ::
#\[7]3C2QZDKF37TRCEWTKRUFOJJO3O452N7HYNLUTJF3CP6M2QIW64DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
