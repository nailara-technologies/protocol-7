# cube : replies stall in ~70ms steps after the first byte

brief for a new session [ 2026-09-24 ]. read `CLAUDE.md` [ module syntax,
style ] first. diagnostic task : find the cause before changing anything in
the shared write path [ `base.handler.write` is used by every zenka ].

## the symptom

- `v7-zenki.list heartbeat` [ cube row, source `v7-rtt` ] shows recurring
  round trips of ~71ms and ~212ms, normal is ~1.2ms. zenka-stamped rows
  [ routed heartbeats ] show the same 71 / 212ms as rare maxima
- reproducible with `p7c` too, independent of v7 :
  `p7c heart` 12/40 slow, `system.heart` 12/40, `coding.heart` 17/40
  [ 0.3s spacing ]. slow values are quantized :
  77, 147, 218, 288ms [ ~70ms multiples + ~7ms ]

## what strace showed [ `strace -f -tt -e trace=write,recvfrom p7c heart` ]

the WHOLE reply arrives ~70ms [ or ~135ms ] late :

    write "select unix\nauth unix-taeki\n"
    recv  "\\"                                   <- blocks ~135ms
    recv  "\\PROTOCOL-7-VERSION\\...AUTH_TRUE =)\n"   <- rest at once

CORRECTION [ same day ] : `strace -tt` stamps a syscall at its START, so the
gap belongs to the FIRST recv [ waiting for the first byte ], not to a
split write. `base.stream.emit` appends a reply frame in one `.=`. there is
no one-byte-first split -- the question is only why a complete reply waits.

p7c itself does blocking 1-byte `recv`, no waits [ `bin/c_src/p7c.c` ].

## the write path so far

- `base.handler.write` : var watcher on the output buffer ; writes the full
  buffer via `base.s_write` [ full-length syswrite ]. if bytes remain and the
  watcher is not re-armed -> `base.event.io_idle_restart` pushes it to
  `<watcher_list.paused>` -> restarted by the idle watcher
  `<watcher.io.transfer>` [ `Event->idle`, no min/max,
  `base.event.init_code` ] via `base.event.callback.io-idle-restart`
  [ which calls `->now` for output buffer watchers ]
- candidate : a reply that lands while the output watcher is inactive
  waits for the idle restart [ unverified ]

## open questions

1. [ dropped : based on a misread strace, see correction above ]
2. WHY ~70ms steps ? the idle watcher fires when the loop has nothing else
   to do [ per the user : busy phases like logging bursts delay it ]. two
   hypotheses :
   a. cube busy in ~70ms slices [ synchronous log flush, periodic scan ] ->
      the idle restart waits for one or two slices
   b. Event.pm does not run the idle watcher before blocking ; the loop
      sleeps until the next timer [ ~70ms interval somewhere ]
   test : temporarily log each `io-idle-restart` callback with a hires
   timestamp plus the time the watcher was queued [ push time in
   `io_idle_restart` ] ; correlate with what ran in between. idle loop +
   late callback -> b ; busy stretches -> a, then find the work

## constraints

- temporary instrumentation only, revert before commit
- cube reload : `reload source` excludes `plugin.*` ; base.* changes reach
  every zenka on its reload
- syntax check : `bin/format-code -c`
- don't commit without the user's signed version

## more observations [ 2026-09-24, later ]

- a second, smaller step of ~13-14ms also shows up
- startup is worse : 4 of 8 cube heartbeats stalled after one restart
- correlation seen in a `-vv` capture : cube 71ms stalls while p7-log
  reported a high write rate [ `legacy_gap_sweep: write rate 62.90/tick
  still above threshold` ], a p7-log 301ms outlier right after `starting
  sweep` -> supports hypothesis 2a [ busy slices ]
- outliers are now logged to the v7-zenki logfile with timestamps
  [ `heartbeat latency ... [ average ... ]` ] + counted in
  `v7-zenki.list heartbeat` -> usable to correlate with other zenka logs

#,,,.,.,.,,,.,,..,.,.,,.,,,,,,.,.,.,.,,..,,,,,..,,...,...,,.,,...,,,,,,.,,..,,
#JXNHTXXNMORBS7SX4GA3CS4HXWXCH27UGDGNQRJWTXUXITFFTPLKV5AI5TG6TWNNH73ZY46MA7VFE
#\\\|V2NN3XH2HAPAZLWSUQWAWNEXOCXPGDTIN7LJUQQ6HGCNJJIFUGZ \ / AMOS7 \ YOURUM ::
#\[7]WFEO6HEZWYAG5QRS4U636OEQEAIG7K4FUYBENEJETOJGQCD672CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
