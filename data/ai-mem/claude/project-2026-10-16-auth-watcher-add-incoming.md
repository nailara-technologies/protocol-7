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
     bin/dependencies/*.debian.sh [ or one-line calls ] -- RETIRED 2026-10-18.
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
     study done 2026-10-16 [ kimi, read-only : palette meanings, the ':'
     grammar, 13 p7-deps departures, a helper proposal for
     AMOS7::TERM::Frame -- frame_section_header, frame_title_banner,
     frame_status_row, frame_kv_row, frame_result_box, frame_error_line \
     warn_line, frame_option_list, frame_help_block, frame_color_enabled
     [ -t STDOUT + NO_COLOR ] ; frame_rule_line \ colorize_content \ bar
     have no callers ]. DECIDED [ user ] :
     1. titles TRUE blue [ p7_fg_0004 ] ; green only for ok \ success.
     2. main title ' .: main title :. ' ; a section title continuing a
        ':' \ '::' column on the left : ':::[ section title ]'.
     3. errors in the format-code form [ ':: < tool > : message' ] with
        the AMOS7 exit codes [ '<{NC}>', 0110 ] -- or an improvement.
     4. references : bin/todo, plus bin/amos-chksum or bin/format-code
        [ = bin/ptd ] -- adopt format-code's progress bar style.
  7. [ user, 2026-10-16 ] a zenka builds DEBIAN PACKAGES -- for
     environments \ appliances that deploy nothing else [ the user hit
     this before ]. home : the build zenka's recipe registry [
     build.cmd.recipe-run ] -> a 'deb' recipe ; delivery : osf-cache
     shares .debs peer to peer [ lookup \ has \ fetch \ segment \ merkle,
     also over external links ] but ONLY anchored ones : InRelease
     verified with gpgv against apt's trusted keyrings -> Packages ->
     hash [ bin/dev/osf-holdings, osf-cache.debian.* ]. own-built debs
     are in no debian-signed index -> rejected, correctly. needed : our
     own signed repo index [ InRelease + Packages ] whose key the target's
     apt trusts -- apt requires that anyway [ appliances ]. OPEN decision
     : which key signs -- a dedicated gpg repo key, or tied to the p7
     trust chain [ host-root \ owner ].
     goals [ user ] : survives UPSTREAM DISAPPEARANCE [ a removed CPAN
     dist \ mirror package stays installable and verifiable from our own
     signed index ] and OFFLINE INSTALLS for node groups [ nodes without
     internet fetch from each other ] -- keep both in every design choice
     here [ e.g. the index must be self-contained, no upstream lookups
     at install time ]. a package owns its files : that is when Protocol-7, p7c, :: \
     ::: move to /usr/bin [ decided : /usr/local/bin until then -- dpkg
     owns /usr/bin ; cron's PATH lacks /usr/local/bin -> full paths ].
     also the legacy 'LLL cpan2deb' note : CPAN modules without a debian
     package ship as debs too -- dh-make-perl [ user ; it also resolves
     module -> package : 'dh-make-perl locate' ]. measured 2026-10-16
     [ apt-file on the owning .pm, any package name ] : 160 declared
     p-mod, 15 AMOS7, 21 modules \ ~17 dists with NO debian package :
     AnyEvent::Curl::Multi Config::Hosts Crypt::Curve25519 Crypt::Ed25519
     Debian::Apt::PM Device::Gembird Digest::BMW Digest::Skein Glib::Event
     HTTP::Soup Imager::Screenshot IPC::Shm::Simple Mediainfo Net::IP::Lite
     Poppler Term::VTerm[ ::Pos ::Rect ::Screen ] Tie::Dir X11::WM.
     Crypt::Curve25519 builds from data/lib-path/pm-src [ patched copy ] ;
     Debian::Apt::PM is the unused one [ drop instead ]. a module name ->
     'lib<name>-perl' guess is wrong for sub-modules [ Crypt::Misc is in
     libcryptx-perl, SDL::* in libsdl-perl, PDL in 'pdl', Perl::Tidy in
     'perltidy' ] -- always look up the owning package. the backend interface [ 3 ] then
     has a package to install, not just names.
  direction [ user ] : the future settings zenka [ its namespace already
  freed ] ties packages a USER installed to
  that user's data in the users zenka -> reproducible user + developer
  set-ups ; expect cross-integrations [ tracked entries need a user
  field, not just zenka \ family ].
- README 2026-10-16 : auto-install, keys + vault sections added [ commit
  pending at writing ].

#,,.,,,.,,.,.,..,,..,,.,.,.,,,..,,..,,,,,,.,,,..,,...,...,..,,.,,,.,.,,.,,...,
#6RGNIUIQAIM4UFJYTSNGATKA2OEBTHSLGA3VOWUXYL7RDACQGPUGZPHGHB5RL5NMEZB4GJ5F3R6RE
#\\\|ZS5VOJOMZW23D52O6FKZEREHHXWE2CNZHS6CKGMTOQBSFB3EU2V \ / AMOS7 \ YOURUM ::
#\[7]UTFCVUJKE6CYOYO3AK6QXWMJGPDLPDAHO55W35LZEJCIMKOEJGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
