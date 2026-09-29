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

## instrumentation result [ 2026-09-24, reverted ]

temporary DBG-STALL logs in cube : reply append time in `base.stream.emit`,
append -> write delay in `base.handler.write` [ logged when > 20ms ], and
every `io-idle-restart` callback. 40x `p7c heart` probe, 14 slow replies
[ 73..149ms ] :

- NO slow append -> write for the p7c sessions : once emitted, replies are
  written within 20ms
- ZERO idle restarts fired -> the idle watcher is not involved [ hypothesis
  2b as written is out ]
- => the ~70ms is spent BEFORE the reply is emitted : between the command
  bytes arriving on cube's socket and the command being processed [ read
  watcher \ `net.read_linewise_estimated` \ event loop poll ]
- side note : long-lived session 4990247 [ v7 ] logged multi-second
  'delays' -- most likely a measurement artefact [ first append stamp kept
  across later appends ], not investigated

- with p7-log TERMINATED : unchanged, 14/40 slow [ 76..219ms, same
  ~70ms steps ] -> log traffic to p7-log is NOT the cause [ cube logged
  'unknown target : p7-log' meanwhile ; the earlier sweep correlation was
  coincidence or a second, separate effect ]

next step : stamp socket readable -> input handler -> command dispatch in
cube [ `base.handler.input`, the read watcher callback, net.read_* ] the
same way ; check whether the read watcher is active when bytes arrive, and
whether Event's poll wakes late [ ~70ms quantum = some timer interval ? ].

## result round 2 [ 2026-09-29, instrumentation reverted, cube restarted ]

Event hooks [ prepare / check / callback ] + stamps in connect / read /
input / emit, cube only, 40x `p7c heart` : 18/40 slow.

- the loop is NOT idle during a stall : single callback slices of 70.4ms
  multiples [ 71, 141, 211, 282ms ; 48 slices > 20ms in ~2 min ]
- the slices start right after `input` on a session [ command processing ],
  once after a disconnect [ `read-done 0 2` ] -- so synchronous work in the
  command path, for plain routed commands too
- `/proc/<cube>/task/<tid>/stat` sampling : during the slices the main
  thread is in state S [ sleeping ], not R -> a blocking syscall, not CPU.
  main thread stime ~2x utime. the two extra threads are idle [ 0 cpu ]
- no sleep / select-timeout in base.* / net.* / plugin.* / cube.*
- wchan reads 0 on this WSL kernel ; strace of cube needs root [ other user ]

leading hypothesis : blocking write to the terminal. all zenki run as
children of v7 on the user's pty [ `ps -t pts/<n>` ] ; a full pty / pipe
buffer blocks the writer until the terminal drains, and conpty / Windows
Terminal drains in render ticks -> fixed ~70ms quantum. unverified.

next tests [ cheap, decisive ] :
1. probe with console verbosity 0 vs normal, and with the terminal window
   hidden / minimized vs visible -- stalls should follow console output
2. `sudo strace -f -T -e trace=write,writev -p <cube pid>` during a probe :
   look for ~70ms writes and their fd [ `ls -l /proc/<pid>/fd/<n>` ]
3. check how v7 wires child stdout [ `v7-zenki.handler.zenka_output` ] --
   pipe to v7 [ then v7's own pty write is the bottleneck ] or inherited pty

side note : the instrumentation patch had a sprintf-arity bug that warned on
every slice and flooded the console -- hooks can't be removed from a running
Event loop, so any rerun needs a cube restart to remove them.

## ROOT CAUSE + FIX [ 2026-09-29 ]

strace [ `-T -p <cube>` ] : `clock_nanosleep( 70000000 )`, 1..4x in a row,
after `AUTH_TRUE`, per command and on close. source : `p7_ntime` in
`bin/Protocol-7`. precision-0 `base.ntime` checked harmony on a unix time
rounded to 2 digits [ 10ms ticks ] ; a retry lands in the same tick
[ collision ] and slept `7 x tick` = 70ms. ~29% of ticks are harmonic at any
resolution [ mean disharmonic run 2.4 ticks, max ~21 ] -> 70ms multiples.
hot-path precision-0 callers : `base.handler.command` [ last_activity ],
`base.handler.auth` [ auth_time, connected_since ], `base.session.check.close`
[ last_seen ]. log timestamps [ precision 5 ] were NOT affected [ zero short
sleeps in the trace ].

- harmony off [ `base.ntime-harmony = 0` in cube zenka.v7, test only ] :
  0/40 slow, 4.2..5.7ms
- fix 1 : `unix_precision = ntime_precision + 4` [ one ntime unit is
  1/4200s ], cap 11 -> 22 : 1/40 slow [ first probe after restart ]
- fix 2 : collision delay 1 tick instead of 7 : 0/80 slow, mean 6.7ms
  [ several ntime calls per request ]
- per call, measured standalone : mean 14.9 -> 0.49ms, p99 702 -> 2.4ms,
  max 1194 -> 3.3ms

option left open : zero-wait lookup of the latest harmonic tick <= now
[ backdates <= ~1.5ms, monotonic guard per call ]. `p7_ntime__b32` has its
own harmony loop [ sub-us delay, not blocking today ] -- keep in step if
`p7_ntime` changes further. the unix-input branch still maps
`ntime_precision = unix_precision - 2` [ unchanged ].

## final fix [ 2026-09-29, same session ]

finding : `p7_ntime` asserted harmony on the INTERNAL unix time, but returns
the ntime derived from it -- the returned value was harmonic only 29.0% of
the time [ = the rate of any value, uncorrelated ]. the waits bought nothing
for the value callers get. `p7_ntime__b32` checks its own encoded value
[ correct ].

`p7_ntime` now : ntime truncated from the clock [ or the unix input ], then
stepping BACK one ntime unit at a time until the returned value is harmonic.
no sleep, never in the future, monotonic across calls. the step is a
decrement on the digit string -- a float step [ first attempt ] does not move
the value at precision >= 4 [ below double resolution at ~3.2e12 ], burned
all 24 retries per call and, through b32 [ log timestamps, precision 5 ],
cost ~6.5ms per log line. standalone, p0/p2/p5/p8 : ~25us mean, < 0.2ms
max, 100% harmonic, no limit hits.

live, all zenki restarted : 0/80 slow, mean ~6.9ms [ harmony-off baseline
4.6ms also had log timestamps without harmony ]. harmony stays the default
[ decided : routable timestamps may carry harmony requirements later ].

behaviour changes to keep in mind : unix-input conversions [ `->()` ]
now step back instead of forward ; values are truncated, not rounded.

## follow-up : p7_ntime__b32 [ 2026-09-29 ]

b32 harmonized twice : the numeric ntime [ inner `base.ntime` call, never
returned ] and then the encoded value. with the step-back `p7_ntime`, an
encoded-harmony retry got the same numeric value back -> collision sleep
[ 113ns requested, ~60us real ] -> up to 9 retries per log line.

now : numeric ntime fetched without harmony, then stepping back on the digit
string until the ENCODED value is harmonic [ retry limit 9 kept : ~5% of
stamps stay disharmonic by design ]. no sleeps. shared helper
`base.ntime.step_back` [ `p7_ntime__step_back` ]. unix-time input unchanged.
the retry-limit counter reset used `ntime-B32`, the increment `ntime_b32` --
unified to `ntime_b32`. standalone ~55us per call.

live : 0/80 slow, mean 4.63ms = harmony-off baseline [ 4.57ms ].

note [ user ] : the numeric value's harmony was intentional too, dropped for
the performance gain. restoring it = step back until BOTH numeric and encoded
are harmonic [ ~8% density, ~12 steps, still sub-0.1ms ] with a larger
retry limit.

#,,,,,..,,,,.,,,,,...,,.,,.,,,...,...,,,,,,..,.,.,...,...,...,,.,,..,,.,,,.,,,
#ZVHQ2Y5CJI7CCSERZUEQHWQBFFIAOMOPKHLSSQM77MDUAV2ARY64UHWYMMUPV6TZA4OXU3ZJ74C62
#\\\|PPW74UWHY7MLZH5JXIWLRLZQWEUZHTSGBFWHFMVI4LMFJS6IMWS \ / AMOS7 \ YOURUM ::
#\[7]PMEQY2SOISK4RLNONCKPDVJJKXIGNVBFAG4AF2O3R4UPLKOFRCAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
