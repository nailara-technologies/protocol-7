---
name: project-2026-10-17-session-handover-installer-cloud
description: START HERE -- session 2026-10-16..17 [ last 5c09e923b, pushed ] : deps line done [ core-perl frame, tracked, backend::debian, p7-install, p7-deps in house style + real exit codes ], cloud dispatch tool working [ pty, launch clone, push path ], 2 cloud sessions merged ; OPEN : step 4 root runner, step 7 debs + signed repo, legacy scripts, cloud tool polish
metadata:
  type: project
---

follows [[project-2026-10-16-auth-watcher-add-incoming]] [ its plan steps
1-7 ; this entry records what of them landed ].

## landed [ all pushed, servers on 4df0463c6 or later for p7-install ]

- plan step 1 [ 2a2663571 ] : AMOS7::TERM::Frame core perl ; p7-deps \
  AMOS7::deps load on core perl + data/lib-path/pm ; YAML::Tiny copied.
- step 5 [ bb06337e4, 3062eb968 ] : AMOS7::deps::tracked [ dedup, atomic,
  DIRECTORY lock -- without it 8 writers lost 30 of 40 ] ; every install
  path records [ os-pkg, perlmod stage 2 ] ; sys-deps probes fresh.
- step 3 [ 640858520 ] : AMOS7::deps::backend::debian, os_package
  dispatches by family [ \A[a-z0-9_]+\z checked before require ],
  'manual' for unknown families, detect_os knows nixos.
- steps 2 + 6 from cloud sessions [ squash-imported, reviewed ] :
  bin/p7-install [ 4df0463c6 ] ; p7-deps on the Frame helpers, '::' under
  ':::[ section ]' [ 86f32f13d ] ; included profiles count in check,
  list fits the terminal [ 5c09e923b ]. style rules : see the previous
  entry, step 6 DECIDED. p7-deps check \ install exit 1 on missing \
  failed [ owner : keep ] ; NO_COLOR only when non-empty [ p7-vault too ].
- cloud tooling in bin/mcp-server-p7 : claude_cloud_dispatch \ _status \
  _result -- see [[reference-cloud-sessions-first-run]].
- legacy install script : the unit via p7-deps install-service [ the
  plain cp left 'changed on disk' on delta ].
- list rendering [ 2a2663571 ] : base.parser.list sizes columns with the
  align offset ; separator = longest line + 2 [ 1 past 80 ].

## open

- step 4 second half : generic root runner -- BUILT 2026-10-17 [ cloud
  session, branch dev/apt-child-generic-root-runner 44f8d1d74, imported +
  reviewed ] : AMOS7::deps::root_runner [ detects the family itself,
  backend::<family>::install, checking @INC hook : owner root \ tree
  owner, never the zenka user, no group\world write ]. added in review :
  the dirs ABOVE the lib root are checked too [ else any other local
  account able to write an ancestor swaps in its own tree ] ; group write
  ok for a PRIVATE group [ no members besides root \ tree owner, none
  with it as primary group -- this host : protocol-7 dir is 775 taeki ] ;
  sticky world write only above the root [ /tmp ]. base.debian
  .install_package direct-root fallback now through the debian backend
  [ was a shell string ]. LIVE CHECK still open : servers stat \ find,
  debian zenka start, install-packages, cpan via runner, sudo test run.
  next : fold the runner into os-pkg as its root child [ cloud proposal,
  agreed as a separate step ].
- step 7 : debs via dh-make-perl [ 21 modules \ ~17 dists ] + our own
  SIGNED repo index [ osf-cache only serves anchored debs ]. KEY DECIDED
  2026-10-17 : a gpg repo key [ apt-native, signed-by= ], NEVER created
  by hand -- the repo builder generates it on first publish [ gpg --batch,
  ed25519, sign-only, own GNUPGHOME in user-keys/root/ ], host-root signs
  its fingerprint [ like the .dlg ], p7-install checks that + the pin
  before writing /etc/apt/keyrings, fail-closed. separate key, not
  derived from host-root. unencrypted for now ; encryption LATER via our
  own tools [ p7-vault unlock style ] once the detaching secret \ key
  holding child of the signature workflow exists -- reuse it to hold and
  pass on such external keys too [ esp. ed25519 ]. read side exists :
  osf-cache.debian.read_inrelease. goals :
  upstream disappearance, offline node groups. a cloud VM has apt but no
  CPAN : the first consumer.
- legacy scripts bin/dependencies/*.debian.sh : RETIRED 2026-10-18 [ audit data/tasks/legacy-debian-deps-coverage-audit.md, gaps declared, setup configs on bin/p7-dist-upgrade ] ; was : RETIRE once everything
  they did is covered [ owner 2026-10-17 ] -- unless outdated anyway.
  first a read-only coverage audit [ kimi ] : each action -> covered \
  missing \ outdated.
- p7-install profile : DONE 2026-10-17 [ kimi ] -- the installed profile is
  recorded in the tracked store [ type profile, via record() ], p7-install
  without --profile uses the most recent one, 'minimal' only when none is
  recorded ; the choice and its reason are always printed.
- cloud tool polish : DONE 2026-10-17 [ kimi ] -- trust dialog detected
  ['Do you trust the files in this folder?'], the process group killed,
  'NOT STARTED, NOTHING BILLED' + the one-time command ; 'STARTED A
  BILLED' only with an id, 'MAY BE STARTING' otherwise ; ESC[nC as
  spaces, utf-8 kept [ test-mcp-cloud-pty-text.pl ].
- bin/dev/notify-pid-gone : now [-i <seconds>] <pid> [<pid> ..] -- a
  second pid was read as the poll interval [ slept ~4 days, the kimi
  completion notices never came ]. interval > 300 s warns.
- hub/dev/p7-install-frame-helpers [ 01f172086 ] and dev/p7-deps-house-style
  [ 29fff9c0e ] DELETED 2026-10-17 [ squash-merged ].
- the cred-mesh \ p7-vault delegation idea and the vault inotify watch :
  previous entry, unchanged.
- IMAGES [ 2026-10-17 ] : imported 2 qwen backgrounds [ XPRC.., 5TFD.. ] ;
  the sleeping kittens D77K.. [ 113 steps ] stay UNTRACKED [ 2026-10-18 :
  grey kitten has fur past the other's outline, owner renders a better
  one ] -- invoke metadata stripped,
  rename.bmw ; records : data/yaml/prompts/image/psytrance-network-kitten
  .yaml [ variants, magic_words, style_prompts ], data/yaml/gfx/
  background-provenance.yaml [ distance \ sharing ]. further image imports
  WAIT for the checksum storage [ 2026-10-18 : N7FS root \ disk-id \
  addressing DECIDED, 216b62509, data/yaml/todo/base.yaml N7FS entry --
  next = the assimilate command ; owner : fix that first, too many good
  kittens for the repository ] -- candidates stay in invoke : the running
  kitten re-render [ R2G.. source, seed batch pick #2, eye fix good, as a
  background still too bright ; a 35 % layer blend of the reference-mix
  render gave the best fur -- saved as reference image
  /mnt/ext-xfs-data/backup/src-gfx/FQWD6KMMYYUVUCHCRWFYDNNMV6AWWFZOZEJST2WPLPJ4M.png
  [ prompted 113 base + reference-mix "deep" render at 35 % normal, built
  from the clipboard copies, not the invoke originals ] ].
  design notes of the day : style transitions, gates \ jurisdictions,
  sharing by distance in
  data/md/design/VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES.md ; layer
  compositing, re-feeding, prompt categories in
  data/tasks/images-elfdb-feature-collection.md.

#,,,,,.,,,.,.,,.,,,,,,,..,..,,.,.,,..,,,,,,..,..,,...,...,.,,,.,,,,,,,.,,,,,,,
#AC7XGR3RWY77OZ7IGV3ZTO4IQCL26N3O3DUF6ANG4HK6COKQVNZ5XQXWCYHYUN4UFBLXXH265KAEU
#\\\|JRNRZYEA5E5OWGXW4WSRMYR7ZA4LAYYJ7AGQDRTKY4NEHR2TPLK \ / AMOS7 \ YOURUM ::
#\[7]5EEKSOFWNNZBO6SBIMUMZBBZVS62FZEAQ4Z5B3FTRS5T3HHKIKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
