# deploy findings 2026-11-27 : dependency gaps, atom v7-zenki spin, log prefix width

status : OPEN 2026-11-27 -- found while deploying AMOS7-v6.91.4 to the four servers.

## 1. module dependencies only registered where the code first ran

- a zenka registers a loaded perl module at runtime in var/zenki-deps/p-mod/<zenka>/
  [ untracked, host-local ]. the tracked list cfg/zenki/<zenka>/deps/p-mod/ is what a release
  carries. nothing moves a runtime registration into the tracked list.
- case : system.disk [ 762b534441 ] needs Filesys::Statvfs. registered only on the desktop ;
  the servers' pre-start check knew nothing, auto-install [ host overlay
  v7-zenki.cfg.auto_install_deps = yes ] had nothing to install, system.disk failed each poll.
- fixed for this case : tracked marker [ f5d13ba108 ], debian mapping in
  base.known_dependencies [ 3aa28de5af ], one-notice fallback in system.disk.statvfs.
  auto-install then worked on yourum and zulum.
- wanted : a comparison before each release -- runtime registrations vs the tracked list,
  every module missing from the tracked list reported [ or added ], and every tracked module
  without a debian mapping or cpan fallback in base.known_dependencies reported. first check
  whether sys-deps.undeclared \ sys-deps.promote already cover perl modules [ they speak of
  os packages ] ; extend them rather than adding a tool. candidate hook : bin/dev/release-version
  or the release step of the sign workflow.

## 2. sys_deps resolver sends an empty cpan install

- atom, after the restart : `undef value $cpan[0] in join or string
  [v7-zenki.resolve.object.sys_deps:68]` then `sys_deps: cpan install failed for zenka
  'letsencr' : no modules specified`. a missing module resolved to the cpan route without a
  package name ; the list holds undef, the install goes out empty.
- wanted : find letsencr's module [ `sys-deps.check letsencr` on atom ], add its mapping ;
  the resolver drops undef and logs the unresolvable module by name once, instead of an empty
  install.

## 3. atom v7-zenki busy-poll [ evidence before action ]

- v7-zenki on atom [ 9 days up, code from before fbd58a42de ] spun at ~93 % of a core :
  ~36 000 poll() calls per second, all timeout 0, no events -- an Event watcher permanently
  due. requests were no longer served [ v7-zenki.reload never arrived ; cur-pid \ src-ver
  are answered by cube and hid it ]. restarted [ systemctl restart Protocol-7.service ],
  the new process idles at ~2 %.
- evidence on atom : /var/protocol-7/v7-zenki-spin-2026-11-27/ [ status stat fd unix strace
  log-tail, root 0700 ].
- lead [ unproven ] : section 4 -- a croaking timer callback. a gdb sample of a spinning
  instance would settle it [ v7-zenki.hotspot cannot attach to v7-zenki itself : the anchor's
  job, data/tasks/v7-zenki-anchor.md ].

## 4. log prefix width : kill with a non-numeric pid

- `cannot kill a non-numeric process ID [v7-zenki.calc_prefix_lengths:62]
  [EV:SIGNUM41 send-timer [ decrease lp-width ]` -- 15 times in atom's v7-zenki log.
- v7-zenki.calc_prefix_lengths arms one-shot timers whose callback runs
  `kill 41, @zenki_pid` ; a non-numeric entry in @zenki_pid makes kill croak INSIDE an Event
  callback. a croak there is the same class as the 2026-11-26 SIGSEGV path [ a callback dying
  with watchers in flight ].
- wanted : only numeric pids reach kill [ filter, log the bad entry by instance once ] ; find
  where a non-numeric value enters @zenki_pid. then check whether a croaking timer callback
  can leave Event with a watcher permanently due [ the section 3 spin ].

## 5. reinit fails for httpd \ httpsd on reload [ old ]

- `reinit source [ error ]` on yourum and delta : crypt.C25519 init wants write access to
  /home/protocol-7 when it runs again as the zenka user. the running server is unaffected.
- wanted : the reinit path skips or defers the key-dir write when privileges are dropped
  [ see memory : init_code runs before drop_privs ].

## findings [ kimi ]

- section 4 : @zenki_pid could receive undef while an instance had no completed
  process.id assignment [ start not finished \ failed \ stopped ]. the only direct writer
  found is zenka.start's successful open2 pid assignment. collection now accepts numeric
  pids only and logs each rejected instance once per calculation at level 0 with its
  zenka name ; timer delays and prefix logic are unchanged.
- event check : under local Event 1.28, a one-shot timer running `kill 41, undef` croaked
  once and the watcher was inactive afterwards. with no other watcher the loop exited ;
  it did not stay permanently due or reproduce the busy-poll. this does not exclude a
  different watcher or library state in atom's older spinning process.
- section 2 : resolve_install returns pm_src with dirs and no pkg [ e.g.
  Crypt::Curve25519 ] ; sys_deps.probe sent that undef pkg to the cpan list. the resolver
  now drops nameless packages and logs the affected module once per sys_deps state.
- letsencr : the local dependency check reports everything installed. added certain apt
  mappings for Crypt::OpenSSL::RSA, Crypt::OpenSSL::X509, Crypt::PK::Ed25519,
  Crypt::PK::RSA, LWP::UserAgent, Net::SSLeay, IO::Socket::SSL and
  Protocol::HTTP2::Client. AMOS7 modules are internal and need no debian mapping.

## rules for the implementer

no sha, no json internally ; lowercase comments with [ ] brackets ; perl floor 5.32 ;
bin/format-code -r then -c for every changed src file, read its whole output [ descr max
55 bytes ] ; a new command needs its zenka.v7 list, gen-sub-whitelist and access entries ;
no commit, no sign, no reload, no deploy ; never touch files you did not change, no git
restore ; report every changed file.

#,,,.,,.,,,..,.,,,,.,,,.,,...,.,,,...,..,,.,,,..,,...,..,,...,...,..,,,,.,...,
#7PYKIHZ2AC7DATU7T6ESQWDM5AW66QH4IBMAWVUOGTA5F4XQW3YMJRHFX77WJRCIOTICWHFYIXASI
#\\\|7RTALTU7U6R3BVODLO3Z6XPUDQXLJ6TRPO3KEXY64RA2F2IETMM \ / AMOS7 \ YOURUM ::
#\[7]BSTPUIKSNOPNR3DJ64YCOQ72IBRFWAX33RLDJTDTHLDZOHUIGCAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
