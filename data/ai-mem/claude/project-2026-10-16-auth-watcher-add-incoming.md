---
name: project-2026-10-16-auth-watcher-add-incoming
description: START HERE -- session 2026-10-16 day [ after the deps-service handover ] : taeki remote auth LIVE on all 4 servers, cube re-reads authorized keys via inotify [ 9a62a05d8 ], dep-graph plugin scoping [ 954 subs off eager lists ], p7-keys add-incoming [ 01b150d3d, 716313a79 ] ; OPEN : push+pull 716313a79 + live incident test on pri, unit update pri\atom, 4ZW
metadata:
  type: project
---

follows [[project-2026-10-16-session-handover-deps-service-p7r]].

## why taeki auth failed all night [ not keys vanishing ]

- my hand-written ssh block used `install -d .../incoming` : creates the
  missing PARENT `remote-keys/` as root:root 0755 -> `p7-keys authorize`
  [ as protocol-7 ] could not mkdir `authorized/` ; a root retry made
  `authorized/` root 0700.
- cube read `authorized/<zenka>/` only at start-up + reinit. `reload
  plugins` = base.reload_plugins = recompile only, NEVER runs init_code ->
  no re-read. `reload init` does. [ logs : 0 removals in 3 days. ]
- fixed by hand on all 4 [ chown, authorize as protocol-7, reload init ].
  `::: <host> ..` works everywhere.

## landed

- 9a62a05d8 : `plugin.auth.auth-keypair.watch-authorized` -- self-expanding
  inotify [ deepest existing parent, never above home ; re-scan after every
  re-read ; IN_IGNORED \ MOVE_SELF -> fall back ], 1 s debounce handler,
  armed in cube zenka.v7 after the start-up load + on reinit, gated on
  auth.supported_methods having auth-keypair. LIVE : pri fallback test
  [ mv authorized/cube aside 1->0, back 0->1, watch moved down again ].
- same commit : bin/dev/dep-graph parses `plugins.load` [ full subtree ] ;
  namespace-only plugin rule = depth-1 `plugin.<ns>.<x>` + static calls.
  -954 eager subs, httpd gained plugin.web.auth. user's goal : any code
  spared per zenka = memory + start time. dynamic-name targets [ storage
  extract_* ] compile on demand. plugin.external.udt = prepared next
  transport, not loaded yet.
- 01b150d3d [ kimi k2.8, ~2 % of its 7d -- user : very effective ; my
  review found the gid-strictness break, invented 'unsigned' footers, a
  non-idempotent repeat ] : `p7-keys add-incoming <user> <key|file|->
  [<zenka>]`, keys.owned_dir [ owner decides, a deliberate group like
  protocol-7:taeki stays ], keys.authorize_link shared with authorize.
- 716313a79 [ NOT pushed at writing ] : live root test on pri found the
  repeat path skipped the ownership walk -> walk first, then answer
  [ third arg allow_same ] ; keys.root_registry_note. 50 checks.
- `USER=protocol-7 p7-keys ..` as root selects cube's registry
  [ key_vars reads $ENV{USER} ] -- plain root = /root/.n [ a test tree
  there on pri was removed with the user's ok ].
- README : service commands, p-7-r usage + pin, `::` \ `:::` + ssh config,
  authorizing a remote user.

## open

- DONE : 716313a79 + 3b038d1da pulled on all 4 ; pri incident test passed
  [ root-owned authorized/ -> 'fixed ownership .. root:root -->
  protocol-7:protocol-7', login kept working ; plain root prints the
  registry note, creates nothing ].
- unit differs on pri + atom : `bin/p7-deps install-service` [ user's call ].
- 4ZW live, legacy install script, set-up rename, sys-deps probes [ see
  the handover above ].
- atom [ 964 MB, 1 vCPU ] : memory pressure critical on every teardown ;
  letsencr start timed out once, retry fine.
- IDEA [ user 2026-10-16, no rush, plan first ] : cred-mesh reads p7-vault
  secrets through delegation -- a vault grant to cred-mesh instead of
  cred-mesh keeping its own copies. to settle in the plan : what is
  delegated [ one entry \ field \ filter ], how long, revocation, whether
  p7-vault stays standalone [ its explicit design goal ] -- read
  data/md/design/VAULT-FORMAT.md + cred-mesh's current secret source first.
  history [ user ] : vault-edit [ cred-mesh's terminal client ] never got
  p7-vault's secret editing -- a left-over gap ; the standalone script was
  chosen instead because it is needed anyway on hosts not fully set up, or
  with the backend shut down \ failing. so : the delegation must not make
  p7-vault depend on a running cred-mesh -- the backend is the optional
  side, vault access works without it. the user values p7-vault being a
  generic tool for ANY linux machine, not only protocol-7 hosts -- keep
  every integration optional and outside the script's core.
  part of the plan [ user + me agreed ] : p7-vault interactive shell
  watches the vault dir with Linux::Inotify2 -- format is append-only
  [ new version files, sync never overwrites ] so a new file is always
  safe to pick up : refresh the index, print ':: n entries changed'. no
  protocol with cred-mesh needed, the file system is the interface.
  conditions : OPTIONAL dep [ eval require ; missing = SILENT, plus a
  manual `reload` command -- user's choice over an automatic mtime
  fallback, intuitive either way ], interactive mode only [ one-shot reads fresh anyway ], only
  IN_CLOSE_WRITE \ IN_MOVED_TO [ never a half-written file ], the same
  self-expanding pattern as plugin.auth.auth-keypair.watch-authorized for
  blob subdirs ; locked session = mark stale only.
- PLANNED [ agreed 2026-10-16, not started ] : installer + generic deps
  layer. findings : AMOS7::deps::{debp,dist_upgr,module,service} are core
  perl ; NOT core : os_package [ File::Which -> small PATH scan ], TERM
  [ Event, Term::ReadLine, Fortuna -- p7-deps uses only
  frame_border_line ], tracked.yaml [ YAML::Tiny -> keep the format, put
  a copy into data/lib-path/pm ].
  1. AMOS7::TERM::Frame : core-only frames \ colours, TERM re-exports it.
  2. bin/p7-install : standalone like p7-vault [ script + AMOS7/ ] --
     base packages, clone \ update /usr/local/protocol-7, p7-deps install
     <profile>, install-service [, enable-service ] ; then retire
     bin/dependencies/*.debian.sh [ or one-line calls ].
  3. backend interface : AMOS7::deps::backend::<family> loaded by name
     [ debp -> backend::debian, alias kept ] : probe \ install ->
     { ok, failed, manual } \ refresh \ needs_root. 'manual' = admin
     action [ nixos is declarative : report configuration.nix lines ].
     new OS = one file + detect_os line. names : deps/os/<dir>/ per
     family ; perl modules via base.known_dependencies family keys,
     cpan_fallback when unmapped [ a new OS still gets every module ].
  4. one detect_os [ os-pkg zenka has its own os-pkg.backend_type ] ;
     the debian zenka's root apt child -> generic root runner calling
     backend::<family>::install [ names checked in root, no shell ].
  5. AMOS7::deps::tracked [ record \ read \ undeclared \ promote, entries
     carry the family ] replaces 3 writers : bin/os-pkg [ + its own
     promote \ undeclared ], sys-deps.handler.install_reply,
     v7-zenki.sys_deps.track. sys-deps : fresh \ _file probes, no
     hard-coded 'debian'.
  6. p7-deps style overhaul as it becomes central -- read bin/todo,
     bin/format-code, bin/amos-chksum first [ user's references ],
     derive the shared look into the frame module.
  direction [ user ] : the future settings zenka [ its namespace already
  freed ] ties packages a USER installed to
  that user's data in the users zenka -> reproducible user + developer
  set-ups ; expect cross-integrations [ tracked entries need a user
  field, not just zenka \ family ].
- README 2026-10-16 : auto-install, keys + vault sections added [ commit
  pending at writing ].

#,,,,,.,.,,.,,.,,,.,,,,..,...,,.,,,,.,,..,,,.,..,,...,...,.,.,...,,..,...,.,.,
#OZ2575EALA2VJEGC4DPI5MLTCJJPV3BN4BKK7ZD356LP4IK64USJ5BTRCBAY6F7HGPRXKEQF5IPRY
#\\\|IYKGKV53HN3ZSWRNXQMQSFVGS2AZ5HCO2X6JKJGEJD6RO6IXNIP \ / AMOS7 \ YOURUM ::
#\[7]YB3ORBSXLWFTDROH3B6O427GJGHZGUK5W3VZNEX5JZLXMGGXGYAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
