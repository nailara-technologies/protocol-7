---
name: project-2026-10-16-session-handover-deps-service-p7r
description: START HERE -- session 2026-10-15..16 [ last c9b156ce5 ] : auto-install stage 1+2 live on all 4 servers, p7-deps service commands + pm-src, ':::' over ssh -W, start gate, startup probe, nameserv cache [ off ], forensics fix, route fix ; OPEN : taeki remote auth on servers [ user runs it ], deploy c9b156ce5, 4ZW live
metadata:
  type: project
---

follows [[project-2026-10-15-session-handover-vault-secret-wipes]].

## landed [ pushed up to 555a8dbcb ; c9b156ce5 NOT pushed yet ]

- [[project-2026-10-15-forensics-restart-loop-cube-ids]] : forensics sweep
  [ e92393bb8 ], v7-zenki start-up heartbeat probe + 77 s stable window
  [ 6af854d3f ], cube id-less route leak [ a13dfd251 ].
- start gate [ e3f1d756d ] : zenki.disabled + on-demand allow list gate
  EVERY start, `:ignore-disabled:` per call. srv-V host.cfg on-demand =
  dist-upgrade pull-git, srv-F = pull-git [ no dist-upgrade : 1 GB, oom ].
- nameserv forwarding cache 4ZW [ 01c411aea ] : built, OFF. next : a
  nameserv[cache] instance on srv-A + resolv.conf with `search .`
  [ srv-A : search domain + *.protocol-7.network wildcard -> srv-F broke
  github.com lookups ].
- auto-install : [[project-2026-10-15-sys-deps-autoinstall-stage1]] -- stage
  1 + 2 ENABLED on all 4 servers [ host.cfg auto_install_deps = yes ;
  srv-A installed libsys-statistics-linux-perl live ] ; reply-format fix
  + zenka-common gaps + poloniex/c-trade/plnx removal [ 555a8dbcb ].
- c9b156ce5 : `p7-deps install-service \ enable-service \ disable-service
  \ check-service` [ AMOS7::deps::service ; a server clone at
  /usr/local/protocol-7 = ok ], pm-src builds shared [ known_dependencies
  pm_src ], v7-zenki check_service_unit [ logs, never copies ],
  install_zenka_symlinks keeps Protocol-7 \ nshell [ bin/nshell ] \ :: \
  :::, p-7-r ':::' = ~/.ssh/config Host alias [ no dots, HostName
  required ] over `ssh -W 127.0.0.1:42` on a socketpair. tested : srv-U's
  pin matches through it.
- small : base.parser.duration no negative age, select-strm-mode in
  access.cmd.usr.*, ea26cf761 zenka-dirs autovivify.

## open

- **taeki p7 auth on the servers** : user said YES ; the classifier
  denies me writing keys remotely -- user runs the ssh block [ incoming/
  taeki.public + authorized/cube link, 0750\0770\0700, owner protocol-7,
  `p7c reload plugins` ] for srv-U, then srv-V srv-A srv-F ; test
  `::: srv-U list sessions` [ installed p-7-r gets ':::' mode only after a
  v7-zenki restart rebuilds it ].
- push c9b156ce5, deploy [ pull-git + teardown ], `bin/p7-deps
  check-service` per host.
- legacy install script : reduce to p7-deps install + install-service, or
  retire [ user's call ] ; Debian::Apt::PM declaration [ unused ] remove?
- rename set-up zenka -> config-profiles later [ frees 'setup' for WW5 ].
- sys-deps zenka still uses require \ AptPkg probes ; delete retired/ on
  srv-U + srv-F, local log-anon.bak-2026-10-15.
- review lesson repeated 3x this session : kimi's tests encode its own
  bugs [ cpanm unprivileged, nshell target, reply format ] -- read the
  assertions, mutation-check.

#,,,,,.,,,..,,.,,,,..,.,,,,.,,,,.,.,,,...,.,.,..,,...,..,,,,,,,.,,.,.,.,.,,,.,
#AJXI6BJJU5CPBDKKOQ4RBH4C6KDTAUGBMBFYDSVOFB6SPENWQAYIHIJOCSM7CYTHPNEGFTMNMCWLY
#\\\|OKF2MSLKJEKBQSW4M2DG32A4E75UFINRZZMZRMXW3DUSBLVBTOL \ / AMOS7 \ YOURUM ::
#\[7]45ZWWYX7CSZRK4XVMB43S5KJFTKNRCV7HADZJ6EDNDWEHPKHGYAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
