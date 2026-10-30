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

#,,,,,.,,,,.,,.,.,,..,..,,.,,,,,,,,.,,,,,,,,,,..,,...,...,.,,,.,,,...,,..,,.,,
#3KODLJJE7BRMB5J2KQA7LNP6SPPAMPMLBIC2RA3WLXWMITMW2RT7CIRC3GI2LS56SV4PBNAYQAPKA
#\\\|U5F5NUJDCARKMVLUVJCHS73L35G7EHEIW72XWZDEQILS2FNQ2U5 \ / AMOS7 \ YOURUM ::
#\[7]4INAGH7S4CC2PUF7KNEQHVZ6X6FKGAG3EJHFWVRVVTQK4GM3OWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
