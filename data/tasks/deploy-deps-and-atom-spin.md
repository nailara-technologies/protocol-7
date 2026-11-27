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

## 6. pull-git ended without a trace [ zulum 2026-11-27 ]

- `v7-zenki.start_once :wait-down: pull-git` : v7-zenki logged `pull-git zenka started
  [ pid : .. ]`, then nothing -- no `external binary .. completed`, no exit code, no state
  change. the process was gone, the checkout unchanged ; the client gave up after 300 s. a
  second run [ after a manual git fetch ] worked at once.
- an exec-external zenka's end must always be seen : a non-zero rc sets the zenka state to
  error [ checkable next time ] ; an end v7-zenki never observed is the gap here. check the
  sig_chld \ waitpid path for exec-external children [ base.process.exit_status, the
  ignore_child_pid map ] and a child reaped by someone else.
- correction [ show-buffer, owner ] : the failed run took the PLAIN zenka path
  [ `starting of pull-git zenka initiated` ], not exec-external -- `starting external
  'pull-git' program as 'root'` and `starting --> extbin` are missing ; a working run has
  both. so init_data had no start_mode at that start, and the wrongly started process's end
  was not logged either [ the instance stayed 'starting' ].
- checked, no cause found : zulum's live start setup [ devmod dump ] holds pull-git's
  v7-init [ exec-external, p7-git-pull--rebase, root ] ; all four servers use remote-server ;
  `v7-zenki.reload all` then pull-git on yourum works ; other zenki's state does not reach
  v7-zenki's start path [ owner ]. the failed instance was gone before it could be dumped.
- next time, while the instance exists : `v7-zenki.dump v7-zenki.zenka.instance.<id>`
  [ devmod : signal 53 to v7-zenki ] -- its init_data and status show which branch ran.

## 7. stale open item after a kimi dispatch

- coding.session-cache-keepalive still listed `kimi dispatch [<pid>]` after the run ended :
  the mcp server clears the item only on its next worker sweep. a stale item can trigger a
  keep-alive for work that is done. wanted : clear on the worker's end [ the wrapper exit or
  the kimi_check_status that sees it gone ].

## 8. n7fs exit codes and the completion signal [ azurum 2026-11-27 ]

- a place as root [ sudo forgotten ] : the vault was not found, n7fs exited with rc 0 and
  raised `place.complete rc=0`. a missing vault \ root key is a failure : non-zero rc.
  check every early return of the vault \ root-key open path.
- Ctrl-C : the notices said `rc=110` [ an errno, ETIMEDOUT ] and `rc=1` -- an interrupted run
  must say so [ eg. `rc=int` or `signal=INT` ], not look like a timeout.
- `-dry-run` is not in the signal : a dry run and a real place send the same line. add
  `dry_run=1`.
- the END block's p7c output reaches the terminal [ `signal place.complete raised, 0 woken` ] :
  `local *STDOUT` + open makes a new handle, the child keeps fd 1. redirect the real fds
  [ open STDOUT dup in place, or an exec with fds closed ].
- a drill started before an update keeps the old code : the 15:06 drill had no drill.complete
  [ the update came 15:19 ] -- expected, no fix needed.

## 9. n7fs place killed by the oom killer [ azurum 2026-11-27 ]

- `n7fs place JXO355A -root-key vault:main -only-category rescue -only-holder yourum` :
  kernel `Out of memory: Killed process (n7fs place) total-vm:17546460kB,
  anon-rss:12484776kB` on a 16 GB host, at ~97 % of the walk. twice the same : the bar stops,
  no error line, no summary [ SIGKILL ], the 3560 nodes for yourum never commit -- the next
  dry-run still says 3560. the tier A drill on yourum fails on a missing address because of it.
- the plan side is optimized [ c74acdbd80 : packed address sets, 16-shard holder map cache,
  50k nodes peak 292 MB ; 7712fa91b2 : bounded plan chunks ] -- test-n7fs-place-memory covers
  local holders with small nodes. 12.5 GB is outside that : a path the test does not measure.
- candidates : [ a ] dirty holder-map shards kept until the commit [ c74acdbd80's own note ]
  -- with one commit at the end they pile up for every chunk ; [ b ] the ssh-receiver upload
  path holding sealed pack bytes or per-chunk results until the end.
- wanted : reproduce with real blob sizes and an ssh-receiver-like holder [ or a local holder
  with large nodes ], log rss per chunk, find what grows ; bound it [ flush \ commit dirty
  shards every n chunks, free per-chunk upload state after its confirmation ] ; extend
  test-n7fs-place-memory to that path with a growth bound. a run killed mid-way must keep the
  chunks it already confirmed [ resume, not restart from zero ].
- workaround until then : place per tree [ -tree <name> ].

## findings 9 [ kimi ]

- reproduction : a local holder, 512 unique 2 MiB nodes, one 512-node place chunk,
  the existing 64 MiB seal commit limit, and rss samples every 64 nodes. a 64-node
  place chunk stayed flat both before and after and was too small to expose this.
- before : rss 64,660 KiB at node 64, 64,708 at 320, 66,756 at 384 and 66,756
  at 512 ; peak 288,564 KiB. after : 64,648 at 64, 64,648 at 320, 64,692 at 384
  and 64,692 at 512 ; peak 288,148 KiB. the final live rss difference is 2,064 KiB.
- cause : the lazy node map evicts only clean shards from its 16-shard cache. dirty
  shards stay cached through every mid-chunk commit until seal_nodes returns, so a
  real 2,048-node place chunk retains every shard it touched. placement's results
  and done maps are per holder, not per node ; the upload worker queue is bounded.
- bound : after its head is confirmed, _commit drops the dirty cached shards and
  their iteration state. clean cached shards stay ; later reads use the published
  descriptors. receiver put state and full upload bytes are released after upload
  confirmation, once the readback expectations have been built.
- regression : test-n7fs-place-memory now uses 256 and 768 real 2 MiB nodes, the
  real 2,048-node place chunk, rss samples every 64 nodes, and a 12 KiB per-node
  steady-rss growth bound for the first run and resume. final rss was 57,760 and
  62,764 KiB ; growth 9.773 first and 5.992 resume, with all 17 checks passed.
- crash : SIGKILL after a logged chunk boundary left 128 committed nodes at holder
  version 4. a fresh process planned and sealed exactly the remaining 384 nodes,
  with no unplaced nodes and no reseal of the confirmed 128.
- checks : place-memory 17, seal 166, placement 81, receiver 28 and sharded-map 11
  tests passed ; both changed modules and the memory test pass perl -c with the
  repo lib path.

## rules for the implementer

no sha, no json internally ; lowercase comments with [ ] brackets ; perl floor 5.32 ;
bin/format-code -r then -c for every changed src file, read its whole output [ descr max
55 bytes ] ; a new command needs its zenka.v7 list, gen-sub-whitelist and access entries ;
no commit, no sign, no reload, no deploy ; never touch files you did not change, no git
restore ; report every changed file.

#,,..,...,...,...,,.,,.,.,,.,,.,,,,.,,.,,,.,.,..,,...,...,,,,,,..,,,,,.,.,..,,
#3YGECLUCVZOUAGVAKOG4PQ46QJ3JE32OUOOHGAK4Z5RHQFT42P4KWUUYVD7JP7WDSNJOTQWNYGE2A
#\\\|U3PQHTB5KHHOP4APX7VYS6JVEKA47CH32JOL7IE5ZHQYZLMOZTH \ / AMOS7 \ YOURUM ::
#\[7]E5XOF63EZJ4GNFFQKIXRMS4QMWQ6N4XBUGPBXBYZRW75OK7ARADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
