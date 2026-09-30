# v7-zenki : memory pressure aware heartbeat \ restart decisions

## problem [ observed 2026-09-29 ]

under memory pressure a healthy zenka answers the heartbeat too late and
v7-zenki restarts it -- which makes the pressure worse [ a new process needs
memory too ] and, for invoke-web, kills invoke.ai with it [ lost render ].

- host : 16G ram, 4G swap. invoke.ai rendering, ~9.4G page cache [ model
  files, up to 42 MB/s reads ], 1.8G swap used [ 4G full the day before ]
- zenki had 60..135 MB each swapped out ; `/proc/pressure/memory` full
  avg60 = 12.2 [ all tasks stalled on memory 12% of the time ]
- same afternoon : `system` zenka and `invoke-web` [ right after a reload ]
  got `response timeout` -> `online --> error` -> restart
- small hosts [ `atom`, 1G ram ] : starting too many zenki at once reboots
  the server outright -- the same signal should gate starts, not only
  restarts

## direction [ user, 2026-09-29 ]

intelligent decision management based on average curves, similar to the
cold-queue feature [ `task.handler.cold-queue-sweep` : sustained samples
over a threshold + a short-term load value, not a single reading ].

## pieces

1. **pressure sampler** in v7-zenki : `/proc/pressure/memory` [ some \ full
   avg10 \ avg60 ] + `/proc/pressure/io`, swap in \ out rate
   [ `/proc/vmstat` pswpin \ pswpout deltas ], MemAvailable. sample every
   few seconds into a ring buffer [ like `task.stats.gpu.temp.sparkline_buf` ]
   ; hosts without psi [ older kernels ] : fall back to swap rate +
   MemAvailable only
2. **pressure level** from the curve : calm \ elevated \ critical, with
   hysteresis [ sustained N samples to enter and to leave -- no flapping ]
3. **heartbeat tolerance** : `v7-zenki.handler.heartbeat_timer` already
   scales the response timeout by a `load-factor` [ console verbosity ].
   add a pressure factor the same way ; on `elevated` \ `critical` a
   response timeout extends and retries instead of `change_status error`.
   a zenka whose process is alive and in state D \ swapping is not hung
4. **restart gate** : while `critical`, defer restarts [ queue them, like
   the invoke-web start memory guard ] ; log once per episode, not per
   heartbeat
5. **start gate** : on-demand \ start-set-up starts wait for `calm` or for
   enough MemAvailable [ atom case ] ; start them one at a time with the
   curve checked in between, not all at once
6. **visibility** : `v7-zenki.pressure` command [ current level, curve,
   deferred restarts \ starts ] ; level changes logged at 1

## related

- `v7-zenki-keep-children-on-crash.md` [ a restart should not take
  invoke.ai down in the first place ]
- `coding-invoke-awareness.md` [ coding \ invoke.ai memory coordination ;
  the same pressure signal could feed its dependency waits ]
- `invoke-web-startup-memory-guard.md` [ dependency objects
  memory_system \ memory_gpu : reuse for the start gate ]
- host side : `vm.swappiness` 60 -> 10 keeps zenka memory in ram and
  drops model file cache first [ root, user decision ]


## state 2026-09-30 [ pieces 1, 2, 3, 6 done ]

- done : sampler + levels [ 180535263 ], elevated from avg60, leave after 13
  samples, short level log [ 776d3f8bf ], heartbeat extension under
  pressure [ 776d3f8bf -- extends 3x \ 6x 17s at the moment the timeout
  fires, also when the latest avg10 already crosses critical ], verified
  live 2026-09-30 [ 'heartbeat late under critical memory pressure --
  waiting [ 1 \ 6 ]' instead of a restart ]
- config : cfg/zenki/v7-zenki/pressure.cfg [ heartbeat_ext.secs \ elevated
  \ critical ]
- seen live : model loads push `mem full avg10` to ~19 ; invoke.ai + coding
  [ 9B, -ngl 27 ] together keep the host at elevated \ critical for long
  stretches -- that is the normal working state now, not an exception

## next : pieces 4 + 5 [ for a kimi dispatch ]

4. restart gate : while the level is critical, a zenka restart requested by
   `init_restart_timer` [ error path ] is deferred, not dropped : queue it,
   re-check every sample, run it when the level leaves critical or after a
   max wait [ config, e.g. 300s ]. log once per deferred zenka. manual
   restarts \ starts are NOT gated [ the user decides ]
5. start gate : on-demand starts and start-set-up autostarts go one at a
   time while elevated \ critical, with a sample in between ; on a host with
   a small MemAvailable [ atom, 1G ] each start waits for MemAvailable above
   a per-zenka estimate [ below ]. v7-zenki.zenka.cmd.start is the entry
   point for on-demand, v7-zenki.autostart_zenki for the set-up
6b. per-zenka memory estimate : the system zenka samples rss + swap of
   every zenka process [ /proc/<pid>/status VmRSS \ VmSwap, children
   included ] and keeps a per-zenka-name peak \ average across runs
   [ state file, survives restarts ]. v7-zenki asks it [ or reads the state
   file ] for the start gate. `<v7-zenki.pressure.zenka>` was reserved for
   this in piece 1

rules for the dispatch : read data/ai-mem/claude/feedback-llm-fix-regressions-pattern.md
first [ generic paths : list every caller ], no idle \ timer loops without a
bound, start.cfg changes currently only take effect after a v7-zenki restart
[ cause open, data/tasks/v7-zenki-start-setup-runtime-reload.md ] -- test
on mod-test with a v7 restart until that is solved

## done [ 2026-09-30, claude opus ] : pieces 4 + 5 [ uncommitted, unsigned ]

review [ claude ] : the log target zenka [ from `<buffer.zenka.log_cmd>`,
normally p7-log ] is exempt from the restart gate like cube ; enabled
defaults TRUE. a v7-zenki reload is enough [ verified : `v7-zenki.pressure`
shows the gate lines, per-sample release runs without errors ].

### design

- **restart gate** [ piece 4 ] : `v7-zenki.init_restart_timer` asks
  `v7-zenki.pressure.defer_restart` before arming its timer. a restart is
  deferred when ALL hold : instance status is `error` at that moment, level
  is `critical`, `restart_gate.enabled`, the zenka is not cube [ `is-cube`
  or name `cube` : while the router is down no manual command reaches
  v7-zenki and all heartbeats fail through it ] and it has no kept children
  [ `restart.keep_children` : invoke-web must be able to claim invoke.ai
  inside the 120s grace, so it is never deferred ]. the marker
  `pressure_deferred_restart = { since }` lives on the instance hash [ ids
  get reused, it dies with the instance ]. logged once at 1 on defer, once
  on release
- **start gate** [ piece 5 ] : the job gets `pressure_gate = { origin }`
  when it is created by `v7-zenki.autostart_zenki` [ origin autostart ] or
  by `v7-zenki.zenka.cmd.start` on the on-demand path [ origin on-demand,
  see below ]. `v7-zenki.zenka.start` [ job callback ] asks
  `v7-zenki.pressure.start_gate` : unflagged jobs pass unchanged ; a
  flagged job either starts [ flag removed, so a later restart re-running
  the same job is not start-gated ] or the instance goes to `delayed` with
  `pressure_held_start = { job_id, origin, since }`. `delayed` keeps it
  counted by `start_count` [ no duplicate start from a resolve cascade ]
  and `notify_online` keeps waiting on it [ checked : it replies only on
  online \ extbin \ error ]. the existing delayed auto-fire
  [ `zenka_status` on a same-name instance coming online ] re-enters the
  gate [ flag still set ], so it does not bypass it
- **gate check** `v7-zenki.pressure.start_gate_check` : closed when
  MemAvailable < per-zenka estimate + `start_gate.reserve_mb` [ estimate =
  `<v7-zenki.pressure.zenka>->{name}->{estimate_mb}` once 6b fills it,
  else `start_gate.default_estimate_mb` ] ; otherwise open when calm
  [ level AND latest sample ] ; otherwise one gated start per sample
  [ `<v7-zenki.pressure.sample_seq>` vs `start_gate.last_seq` ]. the
  latest single-sample level [ `<v7-zenki.pressure.indicated>`, new ] is
  used too, so pacing starts at boot on the first elevated sample [ atom :
  MemAvailable < 1024 is elevated from sample 1 ], before hysteresis has
  entered a level
- **release** `v7-zenki.pressure.release_deferred`, called by
  `v7-zenki.handler.pressure_sample` after each sample [ no own timer,
  bounded by the sampler interval ] :
  - deferred restarts : dropped if the status is no longer `error`
    [ manual restart \ terminate handled it ] ; released when the level
    is not critical or after `restart_gate.max_wait`, via
    `init_restart_timer( $iid, TRUE )` [ bypass ]. **design choice beyond
    the spec** : one released restart per sample while not calm [ a
    released restart runs an unflagged job the start gate does not space
    out ] ; all at once when calm
  - held starts : dropped if the job \ flag is gone, the instance changed
    job or is no longer `delayed` ; on-demand first [ a caller is waiting ],
    then oldest ; released when the gate check opens or after
    `start_gate.max_wait` [ still one per sample while paced ] ; release
    sets `released` on the flag and runs `jobqueue.exec_job`
- **on-demand max wait 45s** : cube's ondemand routing fails its queued
  commands back after `system.ondemand_starting_watchdog_timeout` [ 90s ]
  -- max wait + start time must stay below that
- `v7-zenki.pressure` shows `deferred restarts` and `held starts` [ name,
  instance \ origin, waiting secs ]

### changed files

- new : `src/v7-zenki.pressure.defer_restart`, `src/v7-zenki.pressure.start_gate`,
  `src/v7-zenki.pressure.start_gate_check`, `src/v7-zenki.pressure.release_deferred`
  [ added to `cfg/zenki/v7-zenki/subroutines.load-early:344-347` ]
- `src/v7-zenki.init_restart_timer:6` [ optional 2nd arg ], `:36-42` [ gate,
  drop stale deferral on any other arming ]
- `src/v7-zenki.zenka.start:92-100` [ gate after the existing same-name
  `starting` delay, before `starting` \ start timeout ]
- `src/v7-zenki.zenka.cmd.start:271-284` [ on-demand flag ]
- `src/v7-zenki.autostart_zenki:28-32` [ autostart flag ]
- `src/v7-zenki.handler.pressure_sample:8-9` [ release per sample ]
- `src/v7-zenki.pressure.sample:87` [ sample_seq ], `src/v7-zenki.pressure.update_level:49-51`
  [ indicated ], `src/v7-zenki.pressure.init_code` [ config defaults, sample_seq ]
- `src/v7-zenki.cmd.pressure:95-127` [ deferred \ held display ]
- `cfg/zenki/v7-zenki/pressure.cfg` [ gate keys ]
- no base.* module changed. `src/base.list.subroutines` [ sourcecode console
  list, regenerated with the earlier pressure commit ] does not list the 4
  new modules -- left for the commit tooling

### callers checked

- `v7-zenki.init_restart_timer` [ change_status is synchronous, so the
  status read there is the one just set ] :
  - `handler.zenka_status:267` startup error [ status `error` ] -> gated
  - `handler.zenka_status:505` status `offline` \ `restart` into queued ;
    `offline` always returns earlier [ :362 terminate ], so only `restart`
    reaches it -> not gated
  - `process_zenka_end:130` next_status `error` [ crash, heartbeat \ start
    timeout kill ] -> gated ; `restart` [ after zenka.instance.restart ] ->
    not gated
  - `zenka.instance.restart:100` status `restart` -> not gated. its callers :
    `cmd.restart:178` [ user ], `cmd.restart_own-zenka:44` [ zenka asks for
    its own restart ], `zenka_status:519` [ dependents of a zenka leaving
    online : not gated, but they sit in `depending` until the gated one is
    back ]
  - trace : manual `v7-zenki.restart` during a deferral -> status `restart`
    -> defer_restart returns FALSE on the status check first -> timer armed,
    marker deleted. `v7-zenki.terminate` -> instance deleted -> marker gone
  - `restart_pending` [ keeps an `error` instance counted by instance_count ]
    is set in zenka_status:199 and never cleared -- stays TRUE through a
    deferral
- `v7-zenki.zenka.start` : only run via `jobqueue.exec_job` [ from
  `jobqueue.handler.queue_counter` and the delayed auto-fire
  `zenka_status:643` ]. job creators with `zenka.start` : `autostart_zenki`
  [ flagged ], `zenka.cmd.start` [ flagged only on the on-demand path ].
  `cmd.start` callers without a session_id stay unflagged : `start_once` from
  resolve.object.zenka \ cmd.start dependency loop \ cmd.restart \
  notify_online :start:, `restart_concurrent:78`, `zenki.parent.start_via_v7:52`,
  cmd.restart twin mode `:142`. restart re-runs of a job
  [ `callback.instance.restart`, `children_left` ] : flag already removed
- `v7-zenki.zenka.cmd.start` flag condition : `$once` [ start_once ] AND
  not `$recursion` AND `$call->{'session_id'}` [ network command ] AND the
  zenka is in `<v7-zenki.ondemand_zenki>`. cube's ondemand routing
  [ `base.handler.command.route_to_target` ] sends `v7-zenki.start_once`
  [ no `target_command` is ever registered ]
- `v7-zenki.pressure.update_level` \ `.sample` : only caller chain is
  `pressure.init_code` + `handler.pressure_sample`

### config keys [ cfg/zenki/v7-zenki/pressure.cfg ]

    v7-zenki.cfg.pressure.restart_gate.enabled           = 1
    v7-zenki.cfg.pressure.restart_gate.max_wait          = 300
    v7-zenki.cfg.pressure.start_gate.enabled             = 1
    v7-zenki.cfg.pressure.start_gate.max_wait            = 45
    v7-zenki.cfg.pressure.start_gate.reserve_mb          = 256
    v7-zenki.cfg.pressure.start_gate.default_estimate_mb = 64

### known limits

- a user typing `p7c v7-zenki.start_once <on-demand zenka>` takes the same
  network path as cube's on-demand start and is gated too [ `v7-zenki.start`
  is not ]. separating them needs a marker from
  `base.handler.command.route_to_target` [ base, not touched ]
- dependency cascade starts [ resolve.object.zenka, cmd.start's dependency
  loop ] are not gated, also when a gated start triggered them
- an on-demand request for a zenka whose error restart is deferred gets
  `already running` from start_once [ restart_pending ] and waits in
  notify_online -- up to cube's 90s watchdog, shorter than restart max wait
- at a v7 boot under elevated pressure, autostarts come one per sample
  [ 5s each ] -- a slower boot on this host when it is not calm
- max wait overrides the MemAvailable floor : after 45s a held start runs
  anyway. on atom the gate paces starts [ one per sample, forced after
  45s ], it is not a hard memory floor -- the atom reboot case is reduced,
  not excluded. the 45s comes from cube's 90s on-demand watchdog ;
  autostarts have no such limit -> a separate autostart max wait [ longer
  or unlimited ] is a user decision
- cube's own autostart job is flagged too : at boot it is the first gated
  start [ passes ] unless MemAvailable < estimate + reserve, then it waits
  up to the max wait like any other
- p7-log is not exempt from the restart gate : while its restart is
  deferred every zenka's log buffer stays paused -- exempt it or not is a
  user decision
- during a deferral `v7-zenki.start <zenka>` can be refused [ `reached
  configured maximum concurrency` : the `error` instance keeps
  restart_pending and counts ] for up to the restart max wait ;
  `v7-zenki.restart <zenka>` works
- the menu's `p7c v7-zenki.start_once X-11` is not gated [ X-11 is not
  on-demand ] ; any menu \ script start_once of an on-demand zenka is
- load as one unit : zenka.start and init_restart_timer call the new
  modules on every start \ error restart -- sign new modules + edited
  callers together, full v7-zenki restart, not a reload

### verified

- `bin/format-code` applied [ reflow ] and `-c` : syntax valid on all 13
  changed \ new src modules [ defer_restart re-checked after the cube
  exemption ]
- nothing live : no reload \ restart allowed. `p7c v7-zenki.pressure`
  [ old code ] : CALM at the time of writing

### live test steps [ on mod-test, v7-zenki restart needed for the new modules ]

1. `p7c v7-zenki.pressure` : new `deferred restarts : none` \ `held starts :
   none` lines present
2. restart gate : lower `critical.*` thresholds in pressure.cfg [ eg.
   `critical.min_avail_mb` above the current MemAvailable ], restart v7,
   wait ~15s for `memory pressure : ... --> critical`, then `kill -9` the
   mod-test zenka process -> log `'mod-test' restart deferred`, listed in
   `v7-zenki.pressure` ; restore the threshold -> after the leave samples
   `deferred restart released [ ... ]` and mod-test comes back. also test
   max wait [ `restart_gate.max_wait = 30` ]
3. manual restart not gated : in the deferred state `p7c v7-zenki.restart
   mod-test` -> restarts at once, deferral entry gone
4. terminate : deferred state + `p7c v7-zenki.terminate mod-test` -> entry
   gone on the next sample, no restart
5. kept children : a zenka with `restart.keep_children` + critical -> log
   `restart not deferred [ kept children wait for claim ]` ; cube exempt :
   read the code path only [ killing cube on a live host is not a test ],
   or on a separate test v7 set-up : `restart not deferred [ message router ]`
6. start gate, on-demand : elevated thresholds low, on-demand mod-test
   [ `start.on-demand = 1` ] -> two different on-demand zenki requested in
   the same 5s -> second `start held [ one start per sample ]`, released
   on the next sample, queued commands answered. `start_gate.reserve_mb`
   above MemAvailable -> held until `max wait` [ 45s ], then released and
   the command answered before cube's 90s watchdog
7. user start not gated : `p7c v7-zenki.start mod-test` under the same
   conditions -> starts at once
8. autostart : v7 restart with elevated forced -> start-set-up zenki start
   one per sample, `held starts` shows the rest with origin autostart

#,,..,,.,,,,.,,..,...,,.,,...,,,,,,..,..,,...,.,.,...,...,,..,,,,,.,,,...,.,.,
#2YT4MKAVKOLLPWY4AETI2FBSIDZ64FYPREVRR3OZH2NMQVAAPJPPSBT7U3GURKEPGJMC44ZJGXIRM
#\\\|EG5XOERPNWXEIYX6THHIMD6LUD7GWCYULZ3II2LRXM3FDLK5WUB \ / AMOS7 \ YOURUM ::
#\[7]P2M6RA5M7SGQ3GQKF7KP3GXT6H2HSJ2C74HAYGDMTJEZRNGSNMDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
