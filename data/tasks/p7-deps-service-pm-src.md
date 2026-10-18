# p7-deps : service commands, shared pm-src builds ; v7-zenki : unit check, launch symlinks

[ 2026-10-18 : bin/dependencies/ is retired -- this file keeps the old script
as a historical reference ; `git log -- bin/dependencies` finds its last version ]

the legacy `bin/dependencies/install_minimal_dependencies.debian.sh` does a
few host steps nothing else covers. they move into `bin/p7-deps` [ works
without a running backend -- the unit must exist before the first start ]
and v7-zenki [ keeps what it can current at start-up ].

## what exists today [ read these first ]

- `bin/dependencies/install_minimal_dependencies.debian.sh` lines 5-11 :
  `ln -f -s $NAILARA_ROOT/bin/Protocol-7 /usr/local/bin/Protocol-7`,
  `ln -f -s $NAILARA_ROOT/bin/nshell /usr/local/bin/nshell`,
  `cp $EXT_LIB_PATH/systemd/system/Protocol-7.service /lib/systemd/system/`
  ; near the end : Crypt::Curve25519 built from `data/lib-path/pm-src/
  crypt-curve25519` [ upstream does not compile ], then a git clean.
- `data/lib-path/systemd/system/Protocol-7.service` : the unit. its comment
  : the install path is `/usr/local/protocol-7`, a checkout elsewhere is
  linked there [ RequiresMountsFor, WorkingDirectory, ExecStart use it ].
- `bin/p7-deps` : commands install \ check \ list \ status \ ... [ the
  dispatcher near the top, `show_help` at the end ] ; uses
  `AMOS7::deps::module` \ `debp` \ `os_package`.
- `bin/dev/cloud-session-setup` : `%pm_src` [ module -> pm-src dirs in
  build order : Digest::BMW -> digest-bmw, Crypt::Ed25519 -> canary-stability
  crypt-ed25519 ] and the build loop [ copy to a tempdir, `cpanm --notest
  --quiet <dir>`, CPAN fallback, `PERL_CANARY_STABILITY_NOPROMPT=1` ] --
  no build files land in the tree.
- `src/base.known_dependencies` : module -> { debian, cpan, cpan_fallback }.
- `src/v7-zenki.install_zenka_symlinks` : creates `p7-<zenka>` links in
  `/usr/local/bin` at start-up, replaces only links that are exactly its
  own [ see the `v7.<zenka>` migration ] ; `src/v7-zenki.compile_bin_p7c`
  installs p7c [ `v7-zenki.cfg.p7_bin_path` ].

## what to build

1. **p7-deps service commands** [ root ; refuse clearly without root ;
   idempotent ; every step reports `ok` \ `set` \ `changed` \ `failed` ] :
   - `install-service` : the unit to `/usr/lib/systemd/system/
     Protocol-7.service` [ changed only when the content differs ],
     `/usr/local/protocol-7` -> the checkout [ only if missing or already a
     symlink ; a real directory there is left alone and reported ],
     `/usr/local/bin/Protocol-7` -> `<checkout>/bin/Protocol-7`,
     `/usr/local/bin/nshell` -> `<checkout>/bin/nshell`, then
     `systemctl daemon-reload` when the unit changed.
   - `enable-service` \ `disable-service` : `systemctl enable` \ `disable
     Protocol-7`.
   - `check-service` : read-only, no root needed : each part `ok` \
     `missing` \ `differs`, plus `enabled` \ `disabled` and `active` \
     `inactive`. exit 0 when all parts are ok, 1 otherwise.
   - NONE of them starts, stops or restarts the service -- say so in the
     help text. symlinks : replace only symlinks [ never a regular file ] ;
     no shell [ list-form system \ exec ].
   - help text : the four commands under their own heading.
2. **shared pm-src builds** :
   - `src/base.known_dependencies` : a `pm_src` key [ directory names
     under `data/lib-path/pm-src`, in build order ] for Crypt::Curve25519
     [ crypt-curve25519 ], Digest::BMW [ digest-bmw ], Crypt::Ed25519
     [ canary-stability crypt-ed25519 ].
   - `AMOS7::deps::module` : `install_pm_src( $p7_root, @dirs )` -- the
     cloud-session-setup loop [ tempdir copy, cpanm, no files in the tree ] ;
     `resolve_install` returns method `pm_src` for such a module.
   - `bin/p7-deps install` : a pm_src module is built from its local
     sources first, CPAN as fallback, reported which one was used.
   - `bin/dev/cloud-session-setup` : uses `install_pm_src` + the
     known_dependencies key ; its own `%pm_src` hash goes.
   - NOT for v7-zenki \ the debian zenka : the root apt child takes no
     source paths from the unprivileged side [ falls back to cpan ].
3. **v7-zenki at start-up** [ root ] :
   - `src/v7-zenki.install_zenka_symlinks` : also `::` -> the installed p7c
     [ `<v7-zenki.cfg.p7_bin_path>`, default `/usr/local/bin/p7c` ] when
     p7c exists ; `/usr/local/bin/Protocol-7` and `nshell` as in 1. same
     rule as its p7-* links : create when missing, replace only a symlink
     that is not current, never a regular file ; logged like the others.
   - a new `src/v7-zenki.check_service_unit` [ called from init_code or
     post_init, wherever the p7c install is called ] : compares the
     installed unit with the repo copy ; differs \ missing -> ONE level 0
     log line `systemd unit differs from the repo -- bin/p7-deps
     install-service`. it NEVER copies the unit : a changed unit changes
     restart behaviour, that is the admin's decision.

## rules

- `bin/p7-deps` and `bin/dev/cloud-session-setup` are plain perl scripts
  [ look at their style ] ; `src/*` files are modules : `## [:< ##`,
  `# name  = ...`, `# descr = ...` [ max 55 chars ], NO `sub { }`
  wrapper, `<[module.name]>->( ... )`, `<a.b.c>` data.
- comments lowercase, annotations in `[ ]` never `( )`. no copyright \
  author \ license headers. minimum perl 5.32.
- files end with a 4-line AMOS7 signature footer starting with `#,,` --
  IGNORE those lines completely ; new files get them later.
- syntax check every touched file with `bin/format-code -c <files>`
  [ NOT `perl -c` ].

## tests [ the acceptance criterion ]

`bin/test-scripts/test-p7-deps-service.pl` : runs the service logic
against a TEMPORARY root [ make the target paths overridable for the test,
e.g. env `P7_DEPS_SERVICE_ROOT` prefixing every absolute path ;
systemctl stubbed via a fake binary first in PATH that records its args ]
: install-service on an empty root sets everything, a second run is all
`ok`, a changed unit -> `changed` + daemon-reload, a regular file at a
symlink path is left alone and reported, check-service exit codes,
enable \ disable call systemctl, nothing ever calls start \ restart.
plus `install_pm_src` with a tiny fake pm-src dist [ a Makefile.PL that
writes a marker ] and a stubbed cpanm : built from a temp copy, the source
dir unchanged afterwards. plus `v7-zenki.install_zenka_symlinks` for `::`
[ temp symlink dir ] and `v7-zenki.check_service_unit` [ differs ->
one level 0 log, no copy ].

## out of scope

- never touch the real /usr, /etc or systemd in tests ; no live
  installs, no `p7c`, no zenka starts, no git commits, no signing.
- do not change the legacy install script.
- do not touch files not named here.

## report

new \ changed files, test output [ last lines ], format-code result,
anything you had to decide yourself.

#,,,,,...,...,.,.,,..,,,.,.,,,,,.,.,,,.,.,,..,..,,...,...,...,,.,,,.,,...,...,
#WXHK6FSJIZE6AE5JAFKC6BMVFEHM5BTUJQ355VZZ4YDLS4XGQCT7WK7GUGBZKCUNVDUUND5K55TLQ
#\\\|MB3WKKDPCO3HRCH4C44KRGZD6IL4URPGWFR4VSFU5V5AQRKRF6Z \ / AMOS7 \ YOURUM ::
#\[7]5JXI73CH3OGSD2FCZ7PIBESMMJCUAI2KDJENWTZHGQYMFFSDPGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
