# v7-zenki : heartbeat latency stats + quiet heartbeat logging

brief for a new session [ 2026-09-24 ]. read `CLAUDE.md` [ module syntax,
style ] and `data/ai-mem/claude/reference-per-target-log-levels.md` first.

## the problem

- at console level 2 [ `-vv`, or console verbosity set to 2 ] the heartbeat
  routing lines wash out everything else ; same for the logfile when it is
  raised to 2 for a capture window. today they are dropped entirely by
  devmod flags [ `devmod.skip_v7_heartbeat`, `devmod.skip_log_msg` ] in
  `src/base.protocol-7.command.send.local` [ ~:115-135 ] and
  `src/base.handler.command.route_to_target` [ ~:305 ]
- heartbeats do carry information -- response latency -- but nobody
  collects it : v7 sends them with `notime`
  [ `src/v7-zenki.handler.heartbeat_timer` ~:56, `'args' => 'notime'` ;
  handled in `src/base.handler.heart` / `src/base.cmd.heart` ]

## what already exists [ verified 2026-09-24 ]

- failure escalation is in place, so routine success lines can go quiet :
  success = level 3, error response = 0, first response timeout = 2,
  repeated timeouts = 0 -> status `error` -> restart
  [ `v7-zenki.handler.heartbeat_timer_response`,
  `v7-zenki.handler.heartbeat_response_timeout` ]
- the zenka-side latency value [ `beating [ 0.00113 secs ]`, try
  `p7c coding.heart` ] is stamped at the EARLIEST routing point on the cube
  side [ `base.handler.cmd_filter_hooks` call in `route_to_target` ~:245 ]
  -> that is the clean measurement, use it, not a v7 round trip
- EXCEPTION : cube itself sends no time string [ would always be 0 ]. for
  cube, v7 must measure send -> response itself

## the plan [ agreed with the user ]

1. v7 heartbeats without `notime` [ ask the user why it was added -- cost
   or tidiness ; decides remove vs config switch ]
2. `heartbeat_timer_response` parses the reply, records per zenka under
   `<v7-zenki.stats.heartbeat>->{<zenka>}` :
   count, last, min, max, running mean, last_at, `source => 'zenka'` ;
   for cube : v7-measured send -> reply, `source => 'v7-rtt'` [ not
   comparable with the others, keep it marked ]
   ; `heartbeat_response_timeout` increments a `timeouts` counter
3. outliers only [ e.g. > 10x the zenka's own running mean ] log one
   `'2:1'` line [ console 2, stored 1 ]
4. first heartbeat response timeout : `2` -> `'2:1'` [ a single missed-then-
   recovered heartbeat currently leaves no trace in the logfile ]
5. heartbeat routing + success lines -> plain level `3` [ NOT '3:2' : raising
   the logfile to 2 must not bring the flood back ] ; retire the devmod
   skip flags [ or keep them as a hard off-switch if the user prefers ]
6. optional : a small `v7-zenki.heartbeat-stats` command for a formatted
   table [ new command : access list in zenka.v7 + `reload config`, see
   `feedback-reload-success-doesnt-guarantee-new-file-loaded` ]

## verification

- `-vv` console : no heartbeat lines, other level 2 lines visible
- logfile raised to 2 for a moment : no heartbeat flood
- stats tree fills for several zenki + cube within a few heartbeat cycles,
  cube marked `v7-rtt`
- stop / slow a test zenka : timeout stored at level 1, escalation to 0 and
  restart unchanged
- syntax : `bin/format-code -c` ; reload : plain `p7c <zenka>.reload`
  [ v7-zenki + cube ; base.* changes affect every zenka on its reload ]
- don't commit without the user's signed version

## status [ 2026-09-24, same day ]

- steps 1-4 + 6 done [ c9ffcacca .. 5d73bc312 ] : stats per instance,
  `v7-zenki.list heartbeat`, outliers logged '3:1' + counted
- step 5 was ALREADY in place : `cfg/logging-configuration`
  `log.level.cmd-offset.heart = +1` moves heartbeat routing lines to
  level 3. the devmod flag `skip_v7_heartbeat` was never set anywhere
  [ since 2021 ] -> removed as dead code
- idea : a devmod command showing heartbeat traffic TEMPORARILY [ offset
  to 0 for n seconds, then restored ], like `discover.cmd.show-temp-echo`

#,,..,..,,...,,,.,,.,,.,,,..,,...,,,.,.,.,,,,,..,,...,..,,.,,,,..,.,,,...,.,,,
#AHJL2FOCEWXU5YDVAAY72KLJPIUOXX3ATJRY23TOHPPKUKDHFYZCSZMKJTBKGVL5D3QWJVBU26V6K
#\\\|ILNUCWCIXEIDMHZGNSA7J6MNWIMI2QL5CEDXGNXEZ33AKE3EXLQ \ / AMOS7 \ YOURUM ::
#\[7]TQJWYR347Y75DQHCCIC6NCBKFDRG655MGFJ6ARY22Z2O6MB7CUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
