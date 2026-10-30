---
name: project-2026-10-30-session-handover-night-brake
description: START HERE 2026-10-30 early [ last 672074350 ] : night hover brake live [ 68 C, 20 s steps ], idle-learned baseline via gpu power, soft model swap 7 \ 27 m, stale-claim sweep, temp-boost [ live on next coding start ], priority pickup ; next : morning checks, start-model, offset duty cycles
metadata:
  type: project
---

**landed 2026-10-29 night \ 10-30 [ c2d26221f .. 672074350, all pushed ]**

- idle baseline [ c2d26221f ] : task subscribes X-11 gpu_metric power,
  busy = watts > thermal.cfg.idle.power_max [ 60, idle 42 ] ; real idle
  held 600 s feeds gate.sample ; stale power = active. the cpu load alone
  read 0.1 under a 144 W inference -- power was essential
- night brake [ 7177747a7 ] : coding holds a new task [ task.execute ] and
  a next round [ enqueue_round ] while the gpu is over thermal.cfg.hover.night
  68 : 15 s per C, 20 s steps re-checked, max 180. coding.handler.thermal_tick
  samples every 5 s. switch coding.cfg.thermal_gate = yes. live : hovers
  64-70 C, clean square-wave load. pri's one-round assessments only reach
  execute, never enqueue_round -- the first version missed them
- soft model swap [ f18c23bb3, cb9802932 ] : models.task.pin-accepted
  takes a pin not loaded when every backend is idle >= 420 s [ load only ]
  \ 1620 s [ served a request ] ; coding's ensure_model_pinned switches
- jobsite stage false-conflict [ 7177747a7, live on pri ] : base_stage, a
  touched record [ liveness stamp ] no longer bounces a long-press
- models claim release on a failed start [ notify-online-reply ]
- stale claims [ 2499e6b7f, 5a742ec5a ] : task.handler.stale-claim-sweep
  fails claimed \ in_progress tasks without update for 6 h ; timer armed
  live via task.eval-code on both hosts [ post_init on the next start ]
- temp-boost [ 076c5d429 ] : coding.temp-boost [ min ] [ warm|hot|full|on ]
  | off, default 42 m hot +8 C. NOT reachable until the next coding start
  [ access.cmd.usr.cube is read at start ; reload config clobbers runtime
  values in coding -- never use it there ]
- priority pickup [ 672074350 ] : models appends :background: to queue
  work, only that waits at the hover mark [ + jobqueue priority +2 ] ;
  direct requests start at once, pause \ unload still hold them
- pri : assess_parallel 6 [ host-config jobsite.cfg + runtime ], two
  orphaned in_progress tasks failed by hand

**later the same night [ a9cc3f999 ]**

- outdoor amplifier on the hover mark : night mark += ( amp - 1 ) x
  thermal.cfg.hover.amp_c 12 ; coding polls weather.temp itself [ cube
  access.zenki grants it ]. live : first hold at 74.7 C at ~3 C outside
- soft swap CONFIRMED live : after a coding restart 72T4WFI -> OFSQC4I by
  itself, but only once a dead claim was released [ see below ]
- coding stalled after a `reload source` at 02:50 : commands answered,
  timers dead [ held task never resumed, thermal tick \ log silent ].
  restart fixed it, cause UNKNOWN [ the reload hit a 'my $reply masks'
  warning in coding.cmd.temp-boost, fixed ]. after any coding reload :
  check that 'thermal hold' \ 'acquire' lines keep coming
- gap : a coding restart drops its tasks but models keeps their claims
  till the 1800 s ttl -- models should drop claims when coding comes back
  [ notify_online ]. released by hand tonight : models.eval-code
  release-claim + `ssh root@pri ':: task.reset <id>'`

**next topic : local jobsite \ ui sync [ owner 2026-10-30 ]**

- acceptance : both uis show the same jobs. tonight [ jobs.json ] local
  917 vs pri 428 : 555 only local, 66 only pri, 6 stage differences
  [ QHY52 new vs applied ] -- there is no pri -> local sync at all
- tool : bin/dev/jobsite-ui-compare local pri [ kimi, exit 0 = same ]
- local jobsite STOPPED ; httpd + web run for the radio. pri is safe :
  local pushes as role 'marks', pri drops every non-mark field
- side triggers start the on-demand local jobsite : web's
  plugin.web.jobs.reverse.queue 'jobsite.sync-soon', the ui's relayed
  jobsite.* [ prefs, rescue-http, import-url-http ], site-yaml import.
  gate those [ start only when running or configured as ui host ] ;
  an explicit jobsite.scan must keep working as designed
- sync must tolerate a dead target : per-url skip + backoff, not a full
  batch resend every cycle [ 127.0.0.1 was refused since 32EZ.. -- local
  httpd had been down since 10-28 09:45 ]

**next**

1. morning : hold lines + temp curve, `p7c task.dump '^task\.thermal'`
   [ idle baseline ], pri backlog [ new 554 at 02:45 ], 'swap accepted'
2. start model : coding.cfg.start_model 72T4WFI vs pri's pinned OFSQC4I
   -- the soft swap now covers it, verify after the next coding restart
3. design step 6 [ power feed-forward + cooling fault guard ], step 7
   second half [ offset duty cycles over two workers ]

**how to work**

- regenerated subroutines.load-early files are SIGNED : list them in
  p7_sign paths. unsigned [ web-root html ] : stage by hand, never list
- put the version bump in the same sign run as the code ; a refused
  commit re-bumps the version unsigned -> sign the 3 version files again
- stub tests hid three live bugs tonight [ ntime vs time clock, the
  task.queue 'order' array, one-round tasks skipping enqueue_round ] :
  run the real handler once in the live zenka before trusting a test

related : [[project-2026-10-30-session-handover-thermal-q2k]],
[[project-2026-10-29-thermal-aware-local-worker]],
[[feedback-amend-env-and-unsigned-files-staging]]

#,,..,.,.,,,.,.,.,...,,,.,,,.,.,.,..,,,,,,...,..,,...,..,,,,,,.,,,...,.,.,...,
#4WLPIDMYPBDJR5BFKSNSSPFL4NNFUFSSZOB5QS6PBNBLQONIHS73ME3DRQ4AHEC6HM7CIGLMJRPCE
#\\\|ONBLM4TBTPJMDPMXJLZIOSQN2L4JN5WNW2JCYH2P7SYBCXWDADQ \ / AMOS7 \ YOURUM ::
#\[7]3YDFVTCQFLQCETO6WSRLY2D27NZW65OH644JFP4TGSYNCZQJ24AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
