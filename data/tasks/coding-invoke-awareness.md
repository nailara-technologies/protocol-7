# coding zenka : invoke-aware inference spawning ; invoke-web drain

brief [ 2026-09-29 ]. read `CLAUDE.md` first, then
`data/tasks/invoke-web-startup-memory-guard.md` [ the invoke-web side, same
memory objects ]. user decisions of 2026-09-29 throughout.

## why

invoke.ai [ ~9 GB RAM while loading + VRAM ] and the coding zenka's
inference servers are the two big memory users on a 16 GB WSL host ; both
at once exhausted the 4 GB swap. the coding zenka is started on demand by
other zenki [ jobsite today, later e.g. a nightly forensics sweep ] and must
not spawn into a machine where invoke.ai holds the memory -- and invoke.ai
should give the memory back once its queue is done.

## invoke-web side : drain [ BUILT 2026-09-29, not yet live-tested ]

- activity = any invoke.ai output line [ parse_output_line ] + any write to
  `<root>/databases/invokeai.db*` [ inotify on the directory : browsing and
  selecting images in the web ui writes client_state -- verified : no
  output line, but the -wal mtime moves ] -> `invoke-web.activity.touch`
- `invoke-web.handler.drain_check` [ every 60s, armed at ready ] :
  1. queue empty + a parked session with resume mode `empty` -> resume it
  2. queue drained [ nothing in progress, no pending outside parked
     sessions ] and idle >= `invoke-web.drain.idle_after` seconds ->
     `invoke-web.cmd.stop`, wait for the exit [ max 60s ], then the regular
     idle-term path `base.handler.ondemand_timeout` -> `v7-zenki.idle-term`
     -- the zenka ends right away, no extra 300s on-demand wait
- a paused queue with pending items does NOT count as drained unless
  `invoke-web.drain.paused_counts_idle = yes`
- keys [ zenka.v7 ] : `invoke-web.drain.idle_after` [ 0 = off ; e.g. 4620
  like the coding zenka's own idle shutdown ], `.paused_counts_idle`

## coding side : invoke awareness [ NOT built ]

a dependency object next to `memory_system` \ `memory_gpu` [ coding's spawn
already waits on those, see `coding.init_dependencies` ] :

1. `present invoke-web` [ cube command ] -> not present : satisfied at once
   [ the common case ]
2. present -> `invoke-web.status` : invoke.ai `running`, `starting` or a
   start waiting on the memory guard -> NOT satisfied. invoke-web present
   but invoke.ai stopped -> satisfied
3. while not satisfied, no polling : `v7-zenki.notify_offline invoke-web`
   [ a one-shot reply when the zenka shuts down ; `protocol-7.route-send`
   with a reply handler ] -> re-check the dependency. the invoke-web drain
   above ends with exactly that shutdown
4. invoke-web's `starting` state is the "big memory user starting" marker
   of the memory guard brief -- no new mechanism for the start race

the idle shutdown of the coding zenka itself stays as configured
[ `cfg/zenki/coding/start.cfg` : 4620s -- user : keeping state alive for a
while proved useful ]. no change there.

## open

- should coding's dependency wait have an upper bound [ e.g. a nightly
  sweep that must run eventually : ask invoke-web to drain \ pause ? ]
- cold-queue resume [ invoke-web-queue-sessions.md ] : GPU temperature
  via the X-11 `gpu_metric temp subscribe` feed, mirroring coding's

#,,,,,.,.,.,.,,..,.,,,...,.,,,.,.,,..,,..,.,.,..,,...,..,,...,,.,,,,,,,.,,,..,
#PGU6QJREHI5Y3XSFHN5UBXVJ6ZSVKS3MX47ETVIQFVM5O3HKSY3ZIMCPUHDYJAOM7PVVAFKBF6UCW
#\\\|2MKLEOGVZTAPP2YDL77FWGAIBHYO7B7N46KGIER5WLOFV5W6QTY \ / AMOS7 \ YOURUM ::
#\[7]62FNH7OHQX2XYKBHNZ4JNBT3V5JUXT5XVUFCVS4UYAOMABJ5MCAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
