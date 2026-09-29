# invoke-web : memory guard before starting invoke.ai

brief [ 2026-09-29 ]. not built. read `CLAUDE.md` first.

## the problem

invoke.ai takes 6-9 GB RAM while it loads [ 9 GB RSS seen at startup,
`RAM used to load models: 9.05G` in the graph stats ] plus VRAM. the coding
zenka [ inference servers ] is the other big RAM + GPU user. on this 16 GB
WSL host both at once exhausted the 4 GB swap earlier today [ the whole
system stalled, zenka heartbeats timed out ]. `invoke-web.start` spawns
unconditionally today.

## mirror the coding zenka

coding already gates its spawns with dependency objects :

- `dependency.setup( 'memory_system', { callback =>
  coding.callback.object_memory_system } )` -- free RAM from /proc/meminfo,
  `min_free_mb` default 4096
- `dependency.setup( 'memory_gpu', { callback =>
  coding.callback.object_memory_gpu } )` -- free VRAM via nvidia-smi,
  `min_free_mb` default 3072
- wiring : `coding.init_code` ~:376, `coding.init_dependencies`

invoke-web : same objects [ cross-load the coding callbacks or move them to
a shared name -- they are not coding-specific ] with invoke.ai's own
thresholds in zenka.v7 [ e.g. 8 GB RAM, 4 GB VRAM free ].

## decided [ user, 2026-09-29 ]

- start while memory is short : WAIT -- queue the start until the memory
  dependency is satisfied [ like coding ], an auto-start rather than a
  refusal. the reply says it is waiting and for what [ free vs needed ]
- the coding zenka gets a generous idle shutdown : once its work is done it
  frees RAM \ VRAM, so a waiting invoke.ai start [ or a parked render
  session, see invoke-web-queue-sessions.md ] gets its chance later, e.g.
  in the night
- the inverse too : the coding zenka must be invoke-AWARE. it is started
  on demand by other zenki -- the jobsite zenka today, later e.g. a nightly
  forensics sweep zenka -- and must not spawn its inference servers into a
  machine where invoke.ai holds the memory. it waits \ defers the same way
  [ its memory_system \ memory_gpu objects see free memory ; they should
  also see a running or STARTING invoke.ai, see the race below ]

## still open

- auto-start paths [ adoption, a future autostart ] : always wait, never
  force
- the reverse direction : should coding's spawn also see a STARTING
  invoke.ai [ its RAM climbs for a minute after the spawn ] -- a free-RAM
  check alone races when both start within seconds. a shared "big memory
  user starting" marker might be needed
- `start --force` for the user who knows better

## built [ 2026-09-29, kimi dispatch dce6e60fa, reviewed ]

- dependency objects `memory_system` \ `memory_gpu` with the coding zenka's
  callbacks cross-loaded [ modules.load : `coding.callback.object_memory_system
  coding.callback.object_memory_gpu` ], set up in `invoke-web.init_code`,
  thresholds `invoke-web.start.min_free_ram_mb` \ `_vram_mb` [ 8192 \ 4096 ]
  refreshed on every init
- `invoke-web.cmd.start` : not satisfied -> the start is queued
  [ `invoke-web.start_waiting`, `invoke-web.handler.start_guard` re-checks
  every 13s and starts by itself ], on-demand timeout paused meanwhile ;
  `start force` skips the guard ; `status` shows a waiting start with free
  vs needed [ `invoke-web.memory_free` ]
- verified live via eval-code : RAM 4485 \ 8192 MB -> not met [ invoke.ai
  itself held the memory ], VRAM 7102 \ 4096 -> met ; threshold 1 MB ->
  met, 999999 -> not met [ re-evaluated live, not cached ]
- still to test live [ needs invoke.ai stopped ] : a real queued start that
  proceeds once memory frees up ; `start force`
- coding side : `data/tasks/coding-invoke-awareness.md`

#,,..,..,,.,,,...,.,,,,,,,,,.,,,.,,..,,,.,..,,..,,...,...,.,.,.,,,...,.,,,.,.,
#IYXJFQ3JOW3HLQ3KRZCFR6TCKKHB4LHZ6EAFRKKR25UBTYVOQMOZNPIXEBPN4XUR6OLPE2I3QDNVK
#\\\|ZZ3524HCQVW76IBONXCTQDMUKO5KWCPVKQMJBP3MVNXFKK6BG64 \ / AMOS7 \ YOURUM ::
#\[7]RZGZWDSTFKVEO3KFFHU6GK6LBWZHQITKGT7CXC3TE6MTQXJ3RKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
