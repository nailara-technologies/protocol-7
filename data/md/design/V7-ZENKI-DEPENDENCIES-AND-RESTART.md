# v7-zenki : dependencies and restart

draft 2026-10-21 [ owner + claude ]. design only, nothing implemented
here. two todos meet in v7-zenki's view of a zenka's lifecycle :

- part A [ todo B4C, part 2 ] : what a dependency edge means when its
  target can never run, fails to start, or comes and goes
- part B [ todo FEQ ] : `v7-zenki.backend-restart` -- the whole backend
  restarted in place by an execve of v7-zenki itself

they share one question : who restarts what, and when must nothing be
restarted at all. part B's drain uses part A's reverse order and its
'refused with a reason' answers.

## where things stand [ base 4df3fad10 ]

part 1 of B4C landed in `39e0342b6` :

- start.cfg key `optional_dependencies` : counts like `dependencies`
  where the zenka is not disabled on this host, left out where it is
  [ `v7-zenki.zenka.get_dependencies` ]. `v7-zenki.set_up_zenka_dependencies`
  rebuilds every chain from the current config and logs a skipped
  optional dependency once. first user : `cfg/zenki/external/start.cfg`
  [ `dependencies = cube nodes`, `optional_dependencies = discover` ]
- a hard dependency refused because it is disabled refuses the dependent
  with the reason [ `v7-zenki.zenka.cmd.start`, after `start_once` of the
  dependency returned false and `zenka.is_disabled` holds ]
- `bin/test-scripts/test-v7-zenki-optional-dependencies.pl` [ 9 checks,
  real module code through `p7_syntax__translate`, stubbed state ]

what the code does today, read from source :

| place | behaviour |
|---|---|
| `dependency.chain` | `{ object_id => [ object_id .. ] }`, plain arrays, no edge attributes. `dependency.ok` \ `ok_resolve` \ `get_missing` \ the chain parsers read it |
| `dependency.ok` | pure check, every chain entry must pass its type callback |
| `dependency.ok_resolve` | same, plus the type's resolve hook on an unmet entry [ debounced, `dependency.resolve.min_interval` 5 s ] |
| `v7-zenki.resolve.object.zenka` | the zenka type's resolve hook : `start_once` with `recursion => 1` [ implicit, respects manually stopped ] |
| `jobqueue.check_dependencies` | moves 'depending' jobs to 'queued' once `ok_resolve` passes -- no deadline : a job whose dependency never comes up waits forever |
| `v7-zenki.handler.zenka_status` | on a transition away from online \ extbin : for every `dependency.get_reverse` object whose `dependency.ok` now fails, `zenka.instance.restart` of each instance -- skipped for `stopping` instances and for the instance-level `dependency_exempt` |
| `v7-zenki.zenka.start` | seeds `dependency_exempt` from `exempt-dependency.by-subname.<n>.regex` \ `.deps` [ `cfg/zenki/mpv/start.cfg` : `^audio(?:-\d+)?$` -> `X-11 openbox` ] |
| `v7-zenki.handler.sig_chld` | computes the exit value [ `$? >> 8` ] and passes it to `process_zenka_end` |
| `v7-zenki.process_zenka_end` | uses the exit value only for `external` instances [ exec-external ] ; a stdin-zenka's exit code changes nothing -- error \ offline, then `init_restart_timer` |
| `v7-zenki.cmd.teardown` | `:no-restart:` -> exit 76 [ `RestartPreventExitStatus=76` ], else exit 0 -> `Restart=always` brings v7-zenki back after `RestartSec=5` |
| `v7-zenki.teardown` | reabsorb kept children, TERM newest-first, KILL after `system.kill_timeout` [ 2.1 s ], `exit(1)` on the abort timeout, clean tmp \ pid files, `exit($exit_code)` |
| `base.handler.ondemand_startup` \ `base.zenki.ondemand.handler.startup_reply` | on a FALSE reply cube logs the reason and answers every queued caller with a FIXED template : `FALSE client not present` [ IRW7V6A ] \ `FALSE ondemand zenka start-up error` [ USMP72A ] |

the last row is a gap against the part 1 commit message [ 'cube answers
the queued on-demand callers with it' ] : the caller gets an answer
instead of a hang, but the reason only reaches cube's log. both parts
below want the reason at the caller, so passing it through is stage 0.

### who depends on X-11

23 start.cfg files list X-11 as a HARD dependency, none as optional :
X-11-pointer, auto-hide, compton, dbus, dunst, impressive, mpv,
notify-osd, openbox, osd-logo, protocol-7-menu, reenc-msg, remote-cam,
screen-setup, screenshot, select-region, start-anim, storchencam,
ticker, tile, universal, web-browser, window-place
[ `grep -E '^\s*(optional_)?dependencies\s*=.*\bX-11\b' cfg/zenki/*/start.cfg` ].
mpv is the only one with an instance-level exemption [ headless audio ].

X-11 itself : `dependencies = cube`, `zenka-start.timeout = 42`,
`startup-error.retry-count = 2`, a `startup-error` hook
[ `v7-zenki.callback.xorg-error-handler` reports to `cube.system` ] and
`X-11.init_code` looking up Xorg \ Xvfb \ Xnest \ Xephyr \ nxagent through
`base.required_bin_path`.

## part A : dependency edges [ B4C part 2 ]

### A1 : edges carry an optional mark

the mark lives next to the chain, not in it : every chain reader keeps
seeing a plain array.

```
<dependency.chain>->{ $object }      = [ $dep_a, $dep_b ]     ## unchanged ##
<dependency.chain_mark>->{ $object } = { $dep_b => 'optional' }
```

- `base.dependency.add( $object, $depends_on, { 'optional' => TRUE } )` :
  third argument optional, sets the mark ; a later hard add of the same
  edge clears it [ hard wins when a zenka lists a name in both keys ]
- `base.dependency.del` \ `del_object` drop the mark with the edge
- `v7-zenki.set_up_zenka_dependencies` already deletes the chain on
  every init ; it deletes the marks of that object with it and passes the
  mark for names that came from `optional_dependencies`. that needs
  `zenka.get_dependencies` to say which is which -- a list context form
  returning `( \@hard, \@optional )` keeps the scalar string for its
  current callers
- `base.dependency.get_reverse( $object, $filter )` : `$filter` absent =
  all edges [ as today ], `hard` \ `optional` select by mark
- `base.dependency.ok( $object, $event, $mode )` : `$mode` absent = every
  edge [ as today : start paths wait for optional edges too ]. the
  'met' rule of an optional edge is A4's ; the liveness check of A3 asks
  with mode `hard`
- `base.dependency.*` is base code, `coding.parser.dependency_*` use the
  same chains : the mark is generic, nothing in it names v7-zenki

### A2 : the 'unavailable' state

a zenka that can NEVER run on this host as configured says so, and
v7-zenki stops trying. different from a crash : retrying will not help
until something on the host or in the config changes.

#### the zenka side

- a dedicated exit code. proposal : 69 [ `EX_UNAVAILABLE` of sysexits.h,
  'a service is unavailable' ] -- distinct from 76 [ v7-zenki's own
  `:no-restart:` ] and from 1 [ any failure ]. a `cfg/` constant, not a
  literal in two places
- the reason before the exit : `base.zenka.exit_unavailable <reason>`
  sends `v7-zenki.zenka-unavailable <reason>` when a cube session exists
  [ cube injects the source zenka name + instance as for `claim-children` ],
  then exits 69. without a session yet [ failure before auth ] the exit
  code alone counts, the reason becomes 'exit code 69 [ no reason sent ]'
  plus the zenka's own last log line [ open question : read it from the
  stderr pipe \ the log buffer ]
- first user, X-11 : no server binary for the configured mode, mode
  `host` without a reachable `DISPLAY`, no device for `xorg`. only what is
  sure : a busy display or a driver that failed once is a crash [ A4 ],
  not unavailable. the `startup-error` retry count stays for those

#### the v7-zenki side

- `process_zenka_end` : exit value 69 on a stdin-zenka -> status
  `unavailable` instead of error \ offline, no `init_restart_timer`, the
  instance is terminated as in the restart-disabled path
- `<v7-zenki.zenka.unavailable>->{ $name } = { reason, since, instance }`
  [ per name : a subname instance that can not run is open question 3 ]
- waiters on `notify_online` get FALSE with the reason [ cube passes it
  on : stage 0 ]
- **treated like disabled** : `zenka.is_unavailable` is asked at every
  place that asks `zenka.is_disabled` for dependency purposes --
  `get_dependencies` leaves an unavailable optional dependency out,
  `set_up_zenka_dependencies` logs it once, `cmd.start` refuses a hard
  dependent with "dependency 'X-11' is unavailable on this host : <reason>".
  simplest form : one `zenka.is_unusable` [ disabled or unavailable ]
  for those call sites, `is_disabled` stays the profile check
- the change of state itself re-runs the chain set-up [ as on reload ] :
  dependents already in the 'depending' queue are re-checked and refused
  at once [ hard ] or released [ optional ] instead of waiting forever

#### clearing it

- reload config [ v7-zenki's reload path : `init_start_setup` ] empties
  the whole map -- the host may have changed [ a display attached, a
  package installed ]
- an explicit start of THAT zenka [ start mode `manual`, the place where
  `manually_stopped` is deleted ] removes its entry and tries again
- an implicit start [ dependency, resolve hook, restart ] never clears
  it -- that would be the restart loop again
- `v7-zenki.list` \ status shows `unavailable : <reason> [ since ]`

### A3 : failed starts [ crash, not unavailable ]

#### hard edge

- the dependency keeps its restart + backoff [ `init_restart_timer`,
  `restart.min_delay` .. `max_delay`, the resolve hook ] -- unchanged
- the dependent does not wait forever : a 'depending' job gets a
  deadline = the dependent's start-up timeout
  [ `<v7-zenki.start_setup.zenki.start-up.timeout>` from
  `zenka-start.timeout`, else the global ]. past it the job leaves the
  queue, `notify_online` waiters get FALSE with "dependency 'X-11' did
  not come up [ status error, 3 attempts ]". the dependency keeps
  retrying on its own ; the next start of the dependent queues anew
- the deadline lives in `jobqueue.check_dependencies` [ a `since` stamp on
  the job, checked on the sweep it already does ] -- jobqueue knows no
  zenka names, v7-zenki supplies the timeout and the reply handler when
  it adds the job

#### optional edge

- the dependent goes on without it : the edge counts as met once the
  dependency is online, unusable [ A2 ], manually stopped, or its start
  attempt made for this job ended in error \ offline. one log line :
  "optional dependency 'discover' of 'external' did not come up --
  starting without it"
- no extra wait : 'did its attempt end' is a status the dependency
  reaches by its own start-up timeout. `optional_dependencies.wait`
  [ a per-edge wait ] only if a real case needs it [ owner, B4C ]

### A4 : lifecycle of an optional edge

| event | hard edge [ today, unchanged ] | optional edge |
|---|---|---|
| dependent starts | waits for it | waits for it [ A3 : or its failed attempt ] |
| dependency crashes \ stops | dependent restarted | NOT restarted ; `<dependent>.dependency-lost <name>` |
| dependency comes back online | dependent restarted earlier, nothing more | `<dependent>.returned-dependency <name>` |
| dependency unavailable \ disabled | dependent refused [ A2 ] | dependent goes on |

#### the reverse loop

in `v7-zenki.handler.zenka_status`, the transition away from online :

```
foreach my $dep_id ( <[dependency.get_reverse]>->( $object_id, 'hard' ) ) {
    next if <[dependency.ok]>->( $dep_id, undef, 'hard' );
    ## restart as today [ stopping \ dependency_exempt skipped ] ##
}
foreach my $dep_id ( <[dependency.get_reverse]>->( $object_id, 'optional' ) ) {
    ## online instances of the dependent : dependency-lost notice ##
}
```

the optional edge is the automatic, per-edge form of `dependency_exempt`.
the instance-level exemption stays for single instances [ mpv audio : the
edge to X-11 is hard for mpv, only headless instances are exempt ].

the transition TO online adds the mirror : online instances of optional
reverse dependents get `returned-dependency`. hard reverse dependents
need nothing -- they were restarted and waited.

#### the notices

- names fixed by the owner : `<dependent>.returned-dependency <name>` and
  `<dependent>.dependency-lost <name>` [ harmony TRUE ; the word order is
  inverted against each other on purpose -- the inverted forms checked
  the other way ]
- sent by v7-zenki through cube to each online instance of the dependent
  [ by instance sid where there are several ]
- generic receivers `base.cmd.returned-dependency` \
  `base.cmd.dependency-lost` : dispatch to
  `$code{"<zenka>.dependency.returned.<name>"}` \
  `$code{"<zenka>.dependency.lost.<name>"}` when the zenka registered it,
  else one log line. `<name>` as the zenka name is spelled [ `X-11` :
  hyphens are fine in code names ]. a subname, where the dependency has
  one, as second argument
- opt-in per zenka : the command granted to v7-zenki in that zenka's
  access set-up [ zenka.v7 ] plus the handler. without the grant cube
  refuses the notice : v7-zenki logs that once per [ dependent, name ]
  pair at level 2 and stops sending it until the next reload. nothing
  else changes for a zenka that did not opt in
- handlers must be idempotent : a dependency coming online while the
  dependent was still initialising may be seen at init AND by the notice
- `dependency-lost` is the 'drop windows \ connections cleanly' hook ;
  `returned-dependency` is 're-attach instead of a restart'

## part B : backend-restart [ FEQ ]

`v7-zenki.backend-restart [ :keep-zenki: ] [ :deadline=<s>: ] [ reason ]`
-- name pending its harmony check [ FEQ ]. opt-in, new. **teardown keeps
its behaviour** : exit 0 -> systemd restart, `:no-restart:` -> exit 76.

### why execve

execve keeps the pid :

- systemd sees no exit : no `Restart=` cycle, no `RestartSec`, nothing
  counted against `StartLimitBurst` \ `RestartSteps`, the main pid stays
  the same, no `TimeoutStopSec` racing the drain [ it applies to a stop,
  this is none ]
- pid files stay valid
- it works without any supervisor -- a restart-spawner process would
  become a new main pid, so there is none
- the new image reads current source, `host.cfg` and the profile fresh :
  no reload ordering issues [ the overlay order fixed in `4df3fad10`
  is the start-up order by construction ]

### B1 : sequence

1. **guard** : one backend-restart at a time ; refused while a teardown
   runs. sets `<v7-zenki.backend_restart>` = `{ since, deadline, reason }`
2. **record** : the `:keep-zenki:` presence list [ B4 ], when asked for
3. **announce** [ B2 ]
4. **drain** : busy query per zenka, with a cap [ B2 ]
5. **stop** in reverse dependency order, per-zenka grace, TERM \ KILL
   [ B2 ]
6. **reap** everything : kept crash children reabsorbed and ended as
   teardown does, `waitpid` until no child is left -- the new image must
   not inherit children or zombies it does not know [ the adopt variant,
   B5, is the exception that knows them ]
7. **clean** tmp paths and registered pid files [ as teardown ]
8. **prepare exec** [ B3 ]
9. **exec** ; on return **fall back** [ B3 ]

steps 5 .. 7 are teardown's body. teardown ends in `exit()` [ twice :
the abort timeout exits 1 inside the loop ]. proposal : move that body
into `v7-zenki.stop_all_zenki`, returning `{ abort_timeout => bool }` ;
teardown = `stop_all_zenki` + the same exits. behaviour of teardown
unchanged, proven by a test of its order \ signals \ exit codes before and
after [ open question 6 : or a copy, if even a behaviour-neutral move is
not wanted ]. the backend restart continues to exec after an abort
timeout : KILL was sent, a hung process must not keep the backend down.

### B2 : graceful drain

more time = more graceful [ owner ] : without a systemd stop timeout the
drain can take as long as the work needs, bounded by caps.

- **while active** : `init_restart_timer`, the resolve hook, autostart
  and `cmd.start` \ `start_once` refuse with "backend restarting" ; the
  reverse loop of A4 restarts nothing [ every instance is marked
  `stopping` as it is stopped, the flag covers the rest ]
- **'backend restarting' answers** : an on-demand call arriving meanwhile
  is refused by v7-zenki with that text, cube passes it to the caller
  [ stage 0 ] instead of a hang. cube is stopped last, so it answers
  until the end ; a caller after cube is gone sees the socket closed
- **notice** : like `cmd.reboot-warning` -- `wall` to terminals, plus a
  line to connected sessions \ nshell [ "backend restarting in ~N s :
  <reason>" ]. which cube command reaches every session is open
  question 7
- **busy query** : generic `base.cmd.busy`, granted to v7-zenki,
  dispatching to `$code{"<zenka>.busy.report"}` when registered [ returns
  a count + a short 'what' ], else 'idle'. same opt-in pattern as the A4
  notices. polled every `drain.poll` [ 2 s ] per zenka until idle or its
  cap `drain.max_wait` [ per zenka in start.cfg, global default ]. named
  cases [ FEQ ] : coding tasks, letsencr orders, nameserv sync pulls,
  jobsite sync, httpd file transfers
- **order** : reverse topological order of the chains [ hard + optional
  edges ], dependents before their dependencies, `p7-log` before `cube`,
  `cube` last. a cycle [ should not exist ] falls back to teardown's
  newest-first order for its members, logged. one level at a time ;
  within a level in parallel [ the wait is per zenka anyway ]
- **per-zenka grace** : TERM through `zenka.cmd.terminate` [ planned end :
  status shutdown, no restart ], KILL after `stop.grace` [ start.cfg,
  else `system.kill_timeout` ]
- **deadline** [ option ] : `:deadline=<s>:` bounds drain + stop ; when it
  passes, whatever still runs goes through teardown's TERM \ KILL path at
  once
- **systemctl stop during the drain** : SIGTERM is the normal teardown,
  it wins -- the flag is cleared, no exec, systemd's stop proceeds

### B3 : the exec

#### recorded at start-up

in `bin/Protocol-7`, before anything changes them :

- `$EXECUTABLE_NAME` [ `$^X` ], `$PROGRAM_NAME` [ `$0` ], a copy of
  `@ARGV`. today `program_name` is recorded at line 53, but `@ARGV` is
  shifted \ re-split right after [ symlink chain, `'v7-zenki -c -v'` ]
  and `$0` becomes `Protocol-7.<name>` later -- the copy must come first
- the shebang is `#!/usr/bin/perl` without switches : `$^X $0 @ARGV`
  repeats the systemd `ExecStart` exactly
- the working directory and a copy of `%ENV` [ systemd's environment +
  `/etc/default/protocol-7` ] -- restored before exec, so runtime changes
  to `%ENV` do not leak into the new image [ open question 8 ]

#### before exec

- uid : real and effective 0 [ ExecStart runs as root ] ; anything else
  -> refuse, fall back
- signals : every catchable signal to `SIG_DFL` through
  `POSIX::sigaction` [ caught ones reset by execve anyway ; `SIG_IGN`
  survives exec and a `CHLD` left ignored makes the new image lose exit
  codes ], then `POSIX::sigprocmask( SIG_SETMASK, POSIX::SigSet->new )`
  -- the blocked mask is inherited : an exec from a handler or a masked
  section leaves `SIGCHLD` blocked [ the 2026-10 lost-SIGCHLD failure,
  `base.init_zenka.install_signal_handlers` note 2026-10-07 ]. pending
  signals are delivered at the unmask under default dispositions : a
  `TERM` \ `HUP` then ends the process -> the systemd path, acceptable
- run the exec from a timer callback, not from inside a signal watcher
- fds : perl sets close-on-exec above `$^F` -- check `$^F == 2`, then
  walk `/proc/self/fd` : every fd above 2 without `FD_CLOEXEC` [ POSIX
  opened, inherited ] is logged by path and set close-on-exec. only
  stdin \ stdout \ stderr [ the journal ] pass
- `exec { $recorded_X } $recorded_X, $recorded_0, @recorded_ARGV`

#### exec failure

exec only returns on failure. never stay half torn down :

- log the error [ `$OS_ERROR` ]
- under systemd [ `INVOCATION_ID` in the recorded environment ] : exit 1
  -> `Restart=always` restarts, a `:keep-zenki:` record survives
- without a supervisor : clear the flag and start the zenki again in the
  running image [ autostart + the presence list ] -- the old image still
  has its configuration loaded, only its instances are gone

### B4 : `:keep-zenki:` presence list

case 2026-10-21 : a teardown on pri left jobsite, coding and models down
-- they are not in the remote-server autostart list.

- **when** : before the drain, by `backend-restart :keep-zenki:` -- and
  the same record serves `teardown :keep-zenki:` [ the systemd path : the
  file survives the exit ]
- **where** : `file.zenka_dir.write('keep-zenki.list', ..)` ->
  `/var/protocol-7/v7-zenki/keep-zenki.list`, 0600, atomic replace
- **what** : one line per name [ + subname ] : instance count, start
  mode [ autostart \ manual \ implicit \ on-demand ], plus a header :
  written at, reason, writer pid, src-ver. the instance does not carry
  its start mode today [ `cmd.start` computes `$start_mode` and drops it ]
  -- it is stored on the job \ instance first
- **restore** : the new image, after its init and autostart set-up,
  loads the list, unlinks it [ before starting : a crash during the
  restore must not loop on the same list ], then starts the `manual`
  entries in dependency order with start mode `restore` [ manual for the
  checks, own log text ]. `autostart` is covered by autostart,
  `on-demand` waits for its first call, `implicit` is brought by its
  dependent. disabled \ unavailable ones are refused with one log line
  each
- **stale** : a list older than `keep_zenki.max_age` [ e.g. 600 s ] or
  from another src-ver is logged and dropped, not applied
- `:ignore-disabled:` and `:env:` overrides of a manual start are not
  replayed [ per call by design ; open question 9 ]
- `:no-restart:` with `:keep-zenki:` : refused as a contradiction
  [ open question 10 ]

### B5 : adopt variant [ later ]

keep the zenki running across the exec and adopt them. the pid stays,
so the zenki stay children of the same process : the new image can
`waitpid` them like its own.

- record per instance : pid, `/proc` start time, cmdline [ the identity
  triple `claim-children` already checks ], zenka name, subname, cube sid
- `cube` must stay up [ every zenka's session is with cube, not v7-zenki ] ;
  v7-zenki's own session reconnects, heartbeats resume, the restart
  notifications re-arm
- a child ending in the exec window : its zombie waits, the new image's
  first `waitpid( -1 )` sweep [ `v7-zenki.handler.liveness_sweep` ] feeds it
  through the SIGCHLD path
- stdin-zenka pipes from v7-zenki are closed by close-on-exec : a zenka
  reading stdin after init sees EOF -- check per start mode which ones
  still read
- different from B4 : B4 restarts the same set, B5 keeps the processes

## staged plan

| stage | content | depends on |
|---|---|---|
| 0 | cube passes the refusal reason to queued on-demand callers [ a template with the text ] | -- |
| A1 | chain marks : `dependency.add` mark, `del` cleanup, `get_reverse` filter, `ok` mode ; set-up passes the mark | -- |
| A2 | reverse loop : no restart over optional edges ; `returned-dependency` \ `dependency-lost` sent ; `base.cmd.*` receivers with opt-in | A1 |
| A3 | unavailable : exit code constant, `base.zenka.exit_unavailable`, `zenka-unavailable` command, state + clearing, `is_unusable` at the disabled call sites ; X-11 as first user | 0 |
| A4 | failed starts : depending-job deadline [ hard ], 'attempt ended' rule [ optional ] | A1 |
| B1 | record exec args + env early in `bin/Protocol-7` ; `:keep-zenki:` writer \ restorer ; `teardown :keep-zenki:` | -- |
| B2 | `stop_all_zenki` moved out of teardown [ behaviour-neutral ] ; `backend-restart` without drain : stop, reap, exec, fallback | B1 |
| B3 | drain : active flag guards, 'backend restarting' answers, reverse order, per-zenka grace, `base.cmd.busy`, deadline, notice | B2, 0 |
| B5 | adopt variant | B2 |

B1 alone already fixes the pri case through the systemd path.

## test plan

stub-style, like `test-v7-zenki-optional-dependencies.pl` : the real
module code through `p7_syntax__translate`, `%data` \ `%code` stubs for
log, jobqueue, cube sends ; no zenka, no fork unless named.

- **test-base-dependency-marks.pl** [ A1 ] : add with \ without mark,
  hard wins over optional, del drops the mark, `get_reverse` all \ hard \
  optional, `ok` modes, readers of plain arrays unchanged
- **test-v7-zenki-optional-edge-lifecycle.pl** [ A2 ] : `zenka_status`
  online -> error of a dependency : hard dependents restarted, optional
  ones not ; notice commands recorded with the right names and order ;
  `dependency_exempt` still honoured ; a refused notice logged once ;
  `base.cmd.returned-dependency` dispatches to a registered handler,
  else logs
- **test-v7-zenki-unavailable.pl** [ A3 ] : exit 69 -> status
  unavailable, no restart timer, waiters FALSE with reason ; hard
  dependent refused with the reason, optional dependent released ;
  reload clears, manual start clears, implicit start does not
- **test-v7-zenki-failed-start.pl** [ A4 ] : a depending job past its
  deadline leaves with "did not come up", the dependency's own restart
  timer untouched ; an optional dependency whose attempt ended lets the
  dependent queue
- **test-cube-ondemand-refusal-reason.pl** [ 0 ] : FALSE reply text
  reaches every queued caller with its cmd id
- **test-v7-zenki-keep-zenki-list.pl** [ B1 ] : write \ read round trip
  through a temp `var_P7`, stale and foreign src-ver dropped, restore
  order, disabled refused, unlinked before the starts
- **test-v7-zenki-exec-prep.pl** [ B2 ] : in a forked child only : block
  SIGCHLD, set `CHLD` to IGNORE, open a fd without close-on-exec, run the
  prep, exec a small perl probe that reports its signal mask, `CHLD`
  disposition and open fds -- expected : empty mask, default, 0 1 2.
  same probe for the exec-failure fallback [ a missing `$^X` ]
- **test-v7-zenki-drain-order.pl** [ B3 ] : reverse topological order
  over a stub chain [ cube last, p7-log before it, a cycle falls back ] ;
  busy polling stops at idle or the cap ; `cmd.start` refused with
  'backend restarting' while active ; deadline hands over to TERM \ KILL
- teardown regression [ B2 ] : order of TERM \ KILL and the exit codes
  0 \ 1 \ 76 identical before and after the move

live, on a test host and only by the owner : X-11 on a host without a
display ; `backend-restart` under systemd [ `systemctl show -p MainPID
-p NRestarts` unchanged ] and without a supervisor.

## open questions

1. exit code 69 for unavailable, or a protocol-7 number of its own
   [ harmony check ]
2. reason before cube auth : stderr pipe, log buffer, or exit code only
3. unavailable per name or per subname [ `X-11[xvfb]` may run where
   `X-11[xorg]` can not ]
4. does unavailable belong in `v7-zenki.list available`, and in the
   status line of hard dependents ['refused : X-11 unavailable']
5. should hardware events [ a display attached ] clear unavailable, or
   reload \ manual start only
6. teardown's body moved [ behaviour-neutral ] or copied
7. which cube command reaches every session \ nshell for the notice
8. `%ENV` restored to the start-up copy, or kept as it is at exec time
9. replay `:env:` overrides from the presence list or not
10. `:keep-zenki:` with `:no-restart:` : refuse, or keep the list for the
    next manual start
11. default `drain.max_wait`, `stop.grace` and `keep_zenki.max_age`
12. adopt variant : which start modes still read stdin after init

## references

- todos B4C, FEQ : `data/yaml/todo/base.yaml`
- part 1 : commit `39e0342b6`
- `src/v7-zenki.zenka.get_dependencies`, `src/v7-zenki.set_up_zenka_dependencies`,
  `src/v7-zenki.zenka.cmd.start`, `src/v7-zenki.zenka.start`,
  `src/v7-zenki.handler.zenka_status`, `src/v7-zenki.resolve.object.zenka`,
  `src/v7-zenki.process_zenka_end`, `src/v7-zenki.handler.sig_chld`,
  `src/v7-zenki.cmd.teardown`, `src/v7-zenki.handler.shutdown_cmd`,
  `src/v7-zenki.teardown`, `src/v7-zenki.cmd.reboot-warning`,
  `src/v7-zenki.zenka.cmd.claim-children`
- `src/base.dependency.*`, `src/jobqueue.check_dependencies`,
  `src/base.handler.ondemand_startup`,
  `src/base.zenki.ondemand.handler.startup_reply`,
  `src/base.file.zenka_dir.write`, `src/base.init_zenka.install_signal_handlers`
- `cfg/zenki/X-11/start.cfg`, `cfg/zenki/external/start.cfg`,
  `cfg/zenki/mpv/start.cfg`, `data/lib-path/systemd/system/Protocol-7.service`
- `bin/test-scripts/test-v7-zenki-optional-dependencies.pl`

#,,..,...,,.,,..,,,.,,,.,,.,,,..,,,.,,,.,,,,.,..,,...,...,..,,...,...,,,,,,,.,
#DYWFQLEB6PSRPJERGUZK6RZJDMNCOUEMAOABURW4C5YGBUQFQRQRJHD6V5KKFQ7KS6SWRZJT4QFZ4
#\\\|ODGG7AVFCVOEZIYOI62QNUBXKLVF3WEKEIVCYKQOQWLUUK237HP \ / AMOS7 \ YOURUM ::
#\[7]453P7KIODOFQ3EGKHRJ25BI3TZBJDLEKGL3W3YA5FHDFLGSOCUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
