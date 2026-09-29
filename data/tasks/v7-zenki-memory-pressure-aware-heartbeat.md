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

#,,,.,,,.,,..,...,.,,,.,,,.,.,.,,,...,,..,,,,,..,,...,..,,..,,,..,...,.,.,,,.,
#DXMWLQNFM6B5EPE7EV4WWNRCJPUE6J3A3PLQYXIT7VXE4WLO7J5HAR74Q7GZB5CD4TU2OGWSDRV7Y
#\\\|VDZYOUTHBO7IDE2Y2HNXZA7LBLZP3CY6C6NZVZWNVCGJPBM6I77 \ / AMOS7 \ YOURUM ::
#\[7]J2EN3BOOFHKW5T3DRRTOP22N4FI6HCSIDB2W46AL43TBWZNQEADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
