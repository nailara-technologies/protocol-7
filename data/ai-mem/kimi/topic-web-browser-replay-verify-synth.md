# web-browser replay verify= + replay-synth [ steps 4-6, July 2026 ]

landed modules:
- `web-browser.wait-state-poll` — shared settle-poll extracted from
  wait-for-state. args: view names tolerance samples timeout require_flag
  finish. finish cb gets { ok error values elapsed }. `require_flag` gates
  settle counting on window[flag] true [ used with __p7ReplayDone so verify
  can never settle mid-dispatch ].
- `web-browser.replay_template.dispatch_js` — js fn source, invoked as
  `( <fn> )( events_json, speed )`, returns event count. single home of the
  dispatch loop; build payload by CONCATENATION, never sprintf [ '%' in js ].
- `web-browser.replay.dispatch` — shared perl engine: payload build +
  evaluate_javascript + optional verify poll/diff. used by replay-play and
  replay-synth. verify hashref { var => target }; poll timeout auto-extended
  by max_t/speed.
- `web-browser.cmd.replay-synth` — type=drag|wheel path=linear|bezier
  duration=<ms> [steps=] ; drag linear x0 y0 x1 y1, bezier p0x..p3y [0..1] ;
  wheel [x y] dz0..dz3 [ bezier = 4 ctrl values, default flat 120 ].
  steps+1 events; drag = down/moves/up, wheel = dz curve at fixed pos.

wait-for-state + replay-play refactored onto the shared modules [ no
duplicated poll/dispatch code ]. replay-play gained verify= tolerance=
samples= timeout= args.

visualization.html: `window.__p7ReplayTarget = canvas;` added ONCE after the
canvas declaration [ ~line 224 ], NOT in the per-frame debug block at ~833 —
a per-frame assignment would clobber `replay-record start target=<expr>`
overrides every frame.

live verification [ after `p7c web-browser.reload source` on running zenka ]:
- drag linear x0=0.3→x1=0.7 : rotY delta exactly (x1-x0)*W*0.07 = +33.88
- verify=debugRotY:82.76 → `verify PASS [tol=0.05] : debugRotY=82.76
  [target 82.76, delta +0] [settled after 1.3s]`
- bezier drag dispatches, both axes follow the curve
- wheel dz=-120 : zoom 1 → 1.61 ; verify on untouched rotY → PASS delta +0
- FAIL path : `verify FAIL [tol=0.01] : debugZoom=1.327 [target 999,
  delta -997.673 MISMATCH] [settled after 4.0s]`
- replay-play /tmp/file.json verify= → PASS delta +1.42109e-14

gotchas:
- alignRotation() drifts rotX/rotZ toward nearest 90° when followEnabled —
  never use debugRotX/debugRotZ as settle/verify targets; debugRotY and
  debugZoom [ after zoom-follow converges ] are stable.
- new modules are NOT in a running zenka until `p7c <zenka>.reload source`.
- whitelist regenerated [ 649 subs ]; signatures pending — user re-signs.

#,,..,.,.,..,,.,,,.,.,..,,,..,...,...,..,,.,,,...,...,..,,..,,,..,,..,...,,,.,
#DVFVMBCVDUAUHULCFA3WUBTXKBH3Y2EVJVAYA4HNIT4OMDQO3Z7YOI5D22X5PH5BEQ6K5ES5KL5Y2
#\\\|HVVK72WFFVQ6QVS6OKOAKLFKQTKWTG5BHN2QKOK64FEK4OQZ4RT \ / AMOS7 \ YOURUM ::
#\[7]7UXWPAGAUPOD3E72TA67MZMPM72IKD5H326UUFDGQBUTQZB25UBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
