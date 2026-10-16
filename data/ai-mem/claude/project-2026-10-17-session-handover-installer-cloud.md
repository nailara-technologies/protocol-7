---
name: project-2026-10-17-session-handover-installer-cloud
description: START HERE -- session 2026-10-16..17 [ last 2faf44de7, pushed ] : deps line done [ core-perl frame, tracked, backend::debian, p7-install, p7-deps in house style + real exit codes ], cloud dispatch tool working [ pty, launch clone, push path ], 2 cloud sessions merged ; OPEN : step 4 root runner, step 7 debs + signed repo, legacy scripts, cloud tool polish
metadata:
  type: project
---

follows [[project-2026-10-16-auth-watcher-add-incoming]] [ its plan steps
1-7 ; this entry records what of them landed ].

## landed [ all pushed, servers on c27b5a7b4 or later for p7-install ]

- plan step 1 [ 2804a43ea ] : AMOS7::TERM::Frame core perl ; p7-deps \
  AMOS7::deps load on core perl + data/lib-path/pm ; YAML::Tiny copied.
- step 5 [ 527b46808, 62362bbc7 ] : AMOS7::deps::tracked [ dedup, atomic,
  DIRECTORY lock -- without it 8 writers lost 30 of 40 ] ; every install
  path records [ os-pkg, perlmod stage 2 ] ; sys-deps probes fresh.
- step 3 [ 937216116 ] : AMOS7::deps::backend::debian, os_package
  dispatches by family [ \A[a-z0-9_]+\z checked before require ],
  'manual' for unknown families, detect_os knows nixos.
- steps 2 + 6 from cloud sessions [ squash-imported, reviewed ] :
  bin/p7-install [ c27b5a7b4 ] ; p7-deps on the Frame helpers, '::' under
  ':::[ section ]' [ 6cc72cbfb ] ; included profiles count in check,
  list fits the terminal [ 2faf44de7 ]. style rules : see the previous
  entry, step 6 DECIDED. p7-deps check \ install exit 1 on missing \
  failed [ owner : keep ] ; NO_COLOR only when non-empty [ p7-vault too ].
- cloud tooling in bin/mcp-server-p7 : claude_cloud_dispatch \ _status \
  _result -- see [[reference-cloud-sessions-first-run]].
- legacy install script : the unit via p7-deps install-service [ the
  plain cp left 'changed on disk' on delta ].
- list rendering [ 2804a43ea ] : base.parser.list sizes columns with the
  align offset ; separator = longest line + 2 [ 1 past 80 ].

## open

- step 4 second half : generic root runner [ the debian zenka's root apt
  child -> backend::<family>::install ].
- step 7 : debs via dh-make-perl [ 21 modules \ ~17 dists ] + our own
  SIGNED repo index [ osf-cache only serves anchored debs ] -- the signing
  key decision is open [ gpg repo key vs p7 trust chain ]. goals :
  upstream disappearance, offline node groups. a cloud VM has apt but no
  CPAN : the first consumer.
- legacy scripts bin/dependencies/*.debian.sh : retire or one-line calls
  to p7-install [ owner's call ].
- p7-install picks the 'minimal' profile by default ; the servers use
  basic-remote-server -- pass --profile, or detect the one in use.
- cloud tool polish : recognise the workspace trust dialog in the capture
  [ end the process, reply 'not started' + the one-time command ] ;
  'STARTED A BILLED' only with an id [ at status=starting say 'may be
  starting' ] ; cursor-forward escapes [ ESC[nC ] as spaces and utf-8 in
  the shown raw output.
- hub/dev/p7-install-frame-helpers and dev/p7-deps-house-style are
  merged [ squashed ] -- delete when the owner wants.
- the cred-mesh \ p7-vault delegation idea and the vault inotify watch :
  previous entry, unchanged.

#,,..,.,.,,,,,..,,.,,,..,,...,.,.,.,,,,..,,,.,..,,...,...,...,,.,,,.,,,,,,.,.,
#FUGF2ZVNJLFTC7Y6QEQYFHP74NT5HN3GZWH6WNYSWVVKMSMFP7KI6WJK3H57PQV2EZAUA2GDO2JVK
#\\\|M2CKGHSWUW4TRNK6IQZ3LG5ZNYZ3XMLM32NCBZ4AHA2M2AUGX3K \ / AMOS7 \ YOURUM ::
#\[7]Q5SDV5OBHAZQF5MFYF47I4T6Y34PBBPTJ5QOCUJ4OVKC42CDQUCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
