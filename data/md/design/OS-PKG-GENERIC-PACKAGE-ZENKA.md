# os-pkg — the generic package zenka

design [ 2026-10-03 ]. task : `data/tasks/os-pkg-condensed-install-log-stream.md`.

## role

`os-pkg` is the distribution-neutral frontend for operating system
packages. it speaks one vocabulary to callers [ shells via `p7c`, zenki,
dashboards ] and forwards to a backend zenka per distribution. `debian` is
the first backend and already works ; `os-pkg` itself is still a stub
[ `os-pkg.init_code` empty, config in `cfg/zenki/os-pkg/` : on-demand,
`max_concurrency = 1`, drops privileges ].

```
p7c \ zenki \ ui  →  os-pkg  [ unprivileged, generic ]
                       │
                       ├── debian   [ root apt child, serialized queue ]  — exists
                       ├── rpm      [ dnf \ zypper ]                      — later
                       └── …        [ pacman, apk ]                        — later
```

privilege stays where it is : only the backend's forked root child touches
the system [ `debian.start.apt_child`, forked before `root.drop_privs` ].
os-pkg never needs root.

## what already exists to build on

- **debian zenka** : `debian.cmd.install-packages` [ deferred reply ],
  `debian.apt_enqueue_install` \ `debian.apt_pump` [ one job in flight ],
  `debian.handler.apt_child_output` [ per-line output, `< N` exit code ],
  `debian.cmd.install-history`, `debian.log.condense` [ new, pure ]
- **sys-deps zenka** : already routes installs to `debian.install-packages`
  and handles the deferred reply [ `sys-deps.cmd.install`,
  `sys-deps.handler.install_reply` ] — the working cross-zenka precedent.
  note : `feedback-cross-zenka-deferred-reply.md` documents a failure mode
  of reply handlers on routed deferred commands ; sys-deps' handler is a
  later, working path — read both and use the one sys-deps proves
- **AMOS7::deps** : `AMOS7::deps::os_package::probe_os_pkg( $pkg, $type )`
  and `AMOS7::deps::debp` [ `probe_apt`, `install_apt` ] — the distribution
  type is already a parameter here ; os-pkg's backend selection should
  reuse the same type names
- **STRM replies** : `coding.cmd.subscribe-session` [ live subscription to a
  running task ] is the pattern for streaming lines back during a job

## commands [ generic vocabulary ]

```
os-pkg.install  <pkg> [ <pkg> .. ]   install          [ STRM progress ]
os-pkg.remove   <pkg> [ <pkg> .. ]   remove           [ STRM progress ]
os-pkg.upgrade  [ <pkg> .. ]         upgrade all \ given
os-pkg.update                        refresh package index
os-pkg.status   <pkg> [ <pkg> .. ]   installed version or 'absent'
os-pkg.search   <term>               available packages
os-pkg.history  [ n ]                recent jobs [ condensed ]
os-pkg.backend                       which backend, distribution, version
```

v1 : `install`, `status`, `history`, `backend` — the debian zenka already
supports install and history ; `status` maps onto `probe_os_pkg`. the rest
needs new backend commands and comes after.

## backend selection

read `/etc/os-release` once at init : `ID` and `ID_LIKE` [ debian, ubuntu,
raspbian, … → `debian` ; fedora, rhel, opensuse … → `rpm` later ].
override in `cfg/zenki/os-pkg/` [ `os-pkg.backend = debian` ] for testing.
unknown distribution -> commands answer false with a clear message, never
guess.

## generic package names [ optional, later ]

a small mapping table for the few names that differ per distribution
[ e.g. perl modules : `libjson-perl` on debian ] ; plain names pass
through unchanged. sys-deps already resolves perl modules to debian
packages [ `AMOS7::deps::module::load_known_deps` ] — reuse, do not
duplicate.

## forwarding and the reply

1. caller → `os-pkg.install foo bar`
2. os-pkg validates, picks the backend, stores the caller's `reply_id`
   locally, forwards to `debian.install-packages` [ sys-deps pattern ]
3. while the job runs : condensed lines [ `debian.log.condense`, incremental
   state per job ] stream back to os-pkg and from os-pkg to the caller as
   STRM [ subscription pattern ]
4. on completion : final summary line [ n of m packages, exit code ] as the
   closing reply

access : cube `access.zenki` needs `access.cmd.usr.os-pkg =
debian.install-packages` [ like the existing `sys-deps` line ] plus
whatever streaming command the subscription uses.

## security

installing packages is root-equivalent. `os-pkg.install` \ `remove` \
`upgrade` must be restricted to the admin user and to explicitly listed
zenki [ cube access rules ], never `*` for users. read-only commands
[ `status`, `search`, `history`, `backend` ] can be wider. the current
os-pkg config grants `access.cmd.usr.cube = *` — fine for a stub, must be
narrowed before install is wired.

## p7c and the status segment

`p7c os-pkg.install <pkg>` prints the STRM lines as they arrive — the
lightweight frontend for shells and scripts. the same stream feeds a
fixed-height status segment in terminal uis \ dashboards [ header `n of m
packages`, errors pinned, never scrolled past ].

## implementation stages

1. os-pkg skeleton : init_code with backend detection, `os-pkg.backend`,
   `os-pkg.status` [ via probe_os_pkg ] — read-only, safe
2. `os-pkg.install` forwarding with the final reply only [ sys-deps
   pattern ], access rules narrowed first
3. streaming : debian pushes condensed lines per job, os-pkg relays as STRM ;
   `p7c` prints live
4. `history` via `debian.cmd.install-history`, condensed
5. remove \ upgrade \ update \ search : new debian commands, then os-pkg
6. second backend [ rpm ] when a host needs it

#,,..,.,.,,.,,,..,.,.,,,,,.,.,,.,,,,.,,.,,.,,,..,,...,...,,,,,,..,,,.,..,,,,,,
#BWCSRQG2BENPYL6XXCQBSNYFJTUY6KRFOB7MWCOCHZS4BCUBDRXTVCULUZMNOHWMH567AWS66N4UK
#\\\|CKNYCRNGG6HHYPTCHIPHIGESNKFZ7SG4WC63LPFDPHNADFYN5ZV \ / AMOS7 \ YOURUM ::
#\[7]4MVFET75OHX3PXV22GWVVRR2O7HRQQFFN3FFDW4M4OF7L3KIFMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
