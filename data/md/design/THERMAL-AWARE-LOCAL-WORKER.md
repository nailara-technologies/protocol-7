# thermal-aware local gpu worker [ cold-queue gate, generalized ]

decided 2026-10-29 [ owner ] : the local gpu stays in the worker pool, but
temperature, memory and time aware -- instead of a manual offload switch
that gets forgotten [ 500 assessments on the local gpu while asleep ].
every range below is configurable ; the values given are the defaults.
the heating here switches off after 22:00 : at night the gpu heat is
WANTED, amplified by how cold it is outside.

## why

- heat : long local runs heat the host ; a manual on \ off is forgotten.
- memory pressure : part of the 2026-10-29 host freeze. a temperature gate
  alone does not cover it.
- the reverse case : at night, with the heating off, a backlog on the local
  gpu is a feature.

## what exists [ reuse, do not duplicate ]

- `task.handler.cold-queue-sweep` : sustained-cool gate [ last N samples
  <= threshold AND 5 s avg ], force override, debounce fallback on
  gpu-less nodes. defaults in `task.init_code` [ 57 C, 5 samples, 120 s ].
- `coding.handler.gpu_temp_update` : proportional stretch curve [ fast up
  0.08, slow down 0.03, dead band ] against `coding.cfg.gpu_target_temp_c`.
- `task.handler.gpu_temp_update` and `coding.handler.gpu_temp_update` are
  near-copies of one STRM consumer -> first step : ONE shared gate module
  [ `thermal.*` ] both zenki load.
- `weather.temp` [ `weather.parent.cmd.temp` ] : real cached outdoor temp
  for `<weather.location>`. NOT `weather.current` [ hard-coded sample data ].

## inputs

| input | role |
|---|---|
| gpu temp vs. learned idle baseline | join \ leave thresholds, +- float offsets |
| memory pressure [ psi + MemAvailable ] | pause, independent of all else |
| system idle [ cpu load, gpu, memory ] | condition for a cold start ; baseline learns here |
| schedule window [ day \ night ] | selects the offset set |
| outdoor temp + forecast | amplifies NIGHT offsets only |

## states

1. **out** : model not loaded \ not spawned.
2. **cold start** : spawn only when the start gate passes [ gpu cool +
   system idle + memory calm, all held for `start.hold` ].
3. **in pool** [ verdict `slow` while warm ] : weight scales with temperature [ the existing stretch
   curve : fewer jobs, longer gaps as it warms ].
4. **paused** : no new jobs, model stays loaded [ a reload is itself a heat
   and i\o spike ].
5. **unload** : only after `unload.hold` sustained hot or hard memory.

hysteresis : join below `cold`, leave above `hot`, minimum dwell per state
[ `dwell` ] -> no flapping.

## thresholds [ defaults ]

```
thermal.mode               = relative     ## relative | absolute ##
thermal.baseline.window    = 1800         ## s, slow avg while idle ##
thermal.baseline.band      = 1.5          ## C : learns only near itself [ no creep ] ##
thermal.baseline.max       = 55.0         ## C cap : a hot start can not lift it ##
thermal.cold               = +4.5         ## C over baseline : may join ##
thermal.hot                = +18.0        ## C over baseline : pause ##
thermal.ceiling            = 83.0         ## C ABSOLUTE, never amplified ##
thermal.dwell              = 120          ## s minimum per state ##
thermal.avg.short          = 300          ## s ##
thermal.avg.long           = 900          ## s : gate on both ##
thermal.start.hold         = 600          ## s gate held before spawn ##
thermal.unload.hold        = 900          ## s sustained hot -> unload ##
thermal.idle.load_max      = 0.6          ## loadavg per core ##
```

relative mode follows ambient \ seasonal drift without retuning ; absolute
mode uses `cold` \ `hot` as plain C. `ceiling` and the memory marks are
never moved by any profile or amplifier.

## memory

```
thermal.mem.psi_some_soft  = 10.0         ## % avg60 : no new jobs ##
thermal.mem.psi_full_hard  = 5.0          ## % avg60 : pause -> unload ##
thermal.mem.avail_min_pct  = 15.0         ## MemAvailable floor ##
thermal.mem.hold           = 60           ## s sustained hard -> unload ##
```

psi = `/proc/pressure/memory`. on WSL the VM limit is the real ceiling ;
MemAvailable covers kernels without psi.

## schedule windows

```
thermal.window.night       = 22:00-06:00
thermal.night.cold         = +8.0
thermal.night.hot          = +25.0
thermal.night.weight       = 1.0          ## full worker ##
thermal.day.weight         = 0.25         ## overflow only ##
```

06:00 = the heating comes on full until the thermostat regulates [ owner ] :
the night verdict ends exactly there. a manual override expires at the next
window switch -- nothing to forget.

## outdoor amplifier [ night only ]

```
thermal.outdoor.enabled    = yes
thermal.outdoor.t_ref      = 15.0         ## C : above = no extra room ##
thermal.outdoor.k          = 0.04         ## per C below t_ref ##
thermal.outdoor.max        = 1.5          ## amplifier cap ##
thermal.outdoor.max_age    = 3600         ## s : older data = 1.0 ##
thermal.outdoor.forecast   = yes          ## start early before a cold low ##
```

`amp = clamp( 1 + ( t_ref - t_out ) * k, 1.0, max )` scales the night
offsets ; then `ceiling` clamps. stale \ missing \ `n|a` -> amp = 1.0. the
gate needs a numeric reply [ `base.reply.value( $call, 'float' )` or a raw
mode ], not the `7.22°C` display string.

## profiles [ optional layer ]

named offset sets [ `thermal.profile.<name>.*` ] the windows point at,
e.g. `quiet` \ `heater` \ `eco`. only if plain windows prove too coarse.

## build order

1. shared `thermal.*` gate module, task + coding switch over [ no
   behavior change, existing defaults ].
2. hysteresis + slow averages + relative baseline.
3. memory input + states paused \ unload.
4. windows + start gate + idle detector [ no inference in flight, loadavg
   low, held `thermal.idle.hold` ] -> the baseline refines during REAL
   idle periods, both directions [ owner 2026-10-29 ] : temperature-free,
   so the cold-state self-reference [ band + cap, step 2 ] becomes the
   fallback only. the cap stays.
5. outdoor amplifier + forecast.
6. power feed-forward [ owner 2026-10-30 ] : power leads temperature.
   learn k [ C per W ] from settled periods : steady temp ~ baseline +
   k * [ P - P_idle ], outdoor-adjusted. the gate acts on the PREDICTED
   temperature [ hot \ pause before the overshoot, a spawn refused on
   the heat it would bring ].
   cooling fault guard : a sudden k jump at the same power = a stopped
   fan \ blocked airflow -> freeze k [ never learn it as the new normal ],
   crawl or pause, notify the owner. the absolute ceiling stays as the
   last line, independent of any learned value.
   slices 3 + 4 landed : trusted k drives predicted-temperature thresholds
   and optional expected-watts spawn refusal ; settled cooling faults freeze
   k, force hot without resetting its clock, and notify the owner once.
   k learning reworked [ owner 2026-10-31 ] : the gate pauses the load
   itself, so a 600 s settled period never happens live. replaced by a
   transient fit over a bounded sample ring [ thermal.cfg.k.fit.* ] :
   least squares of dT/dt on [ P - P_idle, T - baseline ] every 120 s
   gives tau = -1/b and k = -a/b ; accepted only with b < 0, tau in
   30..3000 s, R^2 >= 0.8 and >= 40 W power swing, clamped to k.min/max.
   the same k averaging, trust count, fault guard and ceiling apply.
6b. power curve [ owner 2026-10-30 ] : with a trusted k the gate steers
   the gpu power LIMIT instead of a load square wave : allowed watts =
   P_idle + [ target - baseline ] \ k. bounds : card min [ 100 W here ]
   .. the owner's set limit [ 144.5 W here, 85 % of 170 ] -- the curve
   only lowers below the owner's choice, never above. steps <= 5 % with
   a hold between ; restore the owner's limit on zenka exit, on a stale
   power \ temp feed and on any gate fault [ a fault drops to the card
   min ] ; ceiling + fault guard stay first. setting needs root : one
   narrow v7-zenki command taking a percent, task \ coding stay
   unprivileged. WSL : nvidia-smi READS the limit, setting is refused
   even as root [ Windows driver owns it ] -> read-only there, control
   on native linux [ this host is moving there ] and the linux servers.
7. priority pickup [ owner 2026-10-30 ] : the hover gaps are free gpu
   time. a direct request starts at once [ only pause \ unload hold it ],
   queue work carries :background: [ models ] and waits at the mark, and
   goes behind direct requests in the jobqueue. LANDED as the first half.
   second half : two workers [ gpu + cpu, two hosts, or two server slots ]
   on offset duty cycles, so one is always in its gap -- a priority
   request lands there with no added latency, background work fills both
   alternately ; the heat budget is the average, a priority round only
   delays the other worker's next background round.
8. profiles, if wanted.

#,,,.,..,,...,,,,,,,.,,..,.,.,,.,,..,,,,,,,,,,..,,...,..,,,,.,,..,...,..,,,..,
#6RIUBKXPCCWASJT4PY22FNZUDG6HZADSQTMZDN6P3XJZKEVFAXNGOAKVVQA3KOLWKQSC6CPPZJMU4
#\\\|XHUK47DX5NHTP7ULXBM7URO5YJUSW62PF5T4ZBM7RHUBDTPQ5XZ \ / AMOS7 \ YOURUM ::
#\[7]ASCXUCNWX5B6JBT5T44IG6VALAJ7UNGCKBOGGDLTNDXQF2GPEYAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
