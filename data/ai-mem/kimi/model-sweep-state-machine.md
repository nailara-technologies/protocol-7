## 2026-09-17 : model-sweep state machine task [ coding-test-iteration-state-machine.md ] implemented

- new cmds : coding.model_sweep.cmd.model-sweep-pause / -resume / -cancel ; registered in cfg/zenki/coding/zenka.v7 keywords + subroutines.load-early regenerated via bin/dev/gen-sub-whitelist coding
- sweep axis : persisted state field [ idle/running/pause-requested/paused ] in state/model_sweep_cursor.yaml ; paused keeps in-memory <coding.model_sweep_state> defined so cmd.model-sweep refusal can distinguish paused vs running
- backend axis : crash-looping derived live from <coding.inference_servers> [ status=crashed + restart_count 1..5 ], never persisted ; status=failed prints "server=failed [ restart attempts exhausted ]"
- crash-class tag : poll_switch crash write site appends "[crash_before_ready|crash_after_ready exit=N]" from existing ready_logged + sigchld exit_status ; verify_inference_startup exhaustion site unconditionally crash_before_ready
- circuit breaker : in-memory <coding.model_sweep_breaker>->{backend} {signature,count}, checked at poll_sweep's waiting-phase advance point, trips on 3 consecutive identical crash_before_ready+exit tuples -> auto-PAUSE with paused_reason, never cancel ; reset on resume/cancel/fresh start
- resume gates breaker-paused cursors on :force: token [ single-colon convention ]
- NOT committed [ user reviews ] ; signature footers auto-regenerated on harness file-tool writes + one partial update-signatures run [ version bumped 9518->9519, load-early staged ] ; update-signatures needs interactive key password when re-run by hand
- validation done execution-free per task doc : format-code -c + ptd -c pass on all 8 files, hand-traces only, no p7c coding.* against live zenka

#,,,,,,,.,,.,,..,,.,,,,..,,.,,,,,,.,,,.,,,,,.,...,...,...,.,.,..,,,..,.,.,,,,,
#3KDRZI5AMCIS5ZKVS73UU7O6C7P6TG6ROXX6GCRI36LMWAN743PXJ3ULSV6D6KLCCZEEJP6KOI6E2
#\\\|PH67P564JS7CPETS6PLTTERKPKFHGVCS3M4BXFO37L6LWC3RU6E \ / AMOS7 \ YOURUM ::
#\[7]7EDNRBBSGP6MST3CEI5ZQ3VWQRJCCRJ45TA47IDAJA2C2BANWKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
