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

- done : sampler + levels [ 4d8fe31e2 ], elevated from avg60, leave after 13
  samples, short level log [ 6eabe182c ], heartbeat extension under
  pressure [ 6eabe182c -- extends 3x \ 6x 17s at the moment the timeout
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

#,,..,...,.,,,,.,,,,.,,.,,,..,,,,,,,,,,.,,,..,..,,...,...,.,,,.,,,,,,,,..,.,.,
#J4Q2OIBGMAF7AQYJB2DP5BP3GUC3ZDZRR35E3LF6SJ4LLUXCBIVBFMZ5VVHDPAGSQXSZDFGWAGM4Y
#\\\|3YDRZR7TZZZWTXRBYGVIOEJ6XPFEFA33YBSFMDXITHJMNVVAC4A \ / AMOS7 \ YOURUM ::
#\[7]EWKYQGT2GNFMHYNS3Y4LJLIUTMVHGKOZYAELVWOQ4VGF2ONDWCDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
