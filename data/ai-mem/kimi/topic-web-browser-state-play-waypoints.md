# web-browser state-play + waypoints [ value-injection replay, July 2026 ]

landed modules [ complementary to input-capture-replay; task
data/tasks/web-browser-value-replay-waypoints.md sections 1-3 ]:
- `web-browser.cmd.state-play <var=target> .. duration=<ms> [path=] [steps=]
  [tolerance=] [samples=] [timeout=]` — eases __p7SetState vars to exact
  targets. reads current values via window.debug<Name> mirrors, generates
  curve steps { t, vals:{name:val} } [ bezier = ease-in-out, ctrl points
  pinned to endpoints ], reuses replay.dispatch.
- `web-browser.cmd.waypoint-set <name> <var=target> ..` — $data{waypoint}
  {name} = { url chk vars }, pinned like replay-record [ bmw.L13, fragment
  stripped ]. in-memory only.
- `web-browser.cmd.goto-waypoint <name> [duration=2000] [path=bezier]
  [force=1] ..` — pin check like replay-play, then calls cmd.state-play
  with synthesized args string [ cmd-calling-cmd works: pass
  { reply_id, args } ].
- `web-browser.replay_template.dispatch_js` — records with .vals call
  __p7SetState hooks instead of DOM dispatch [ shared template, one fn ].
- `web-browser.replay.dispatch` — new force_set { mirror => [ hook, target ] }:
  after verify poll, one direct hook call per mismatched var; reply label
  FORCED [ guaranteed-exact landing, not curve-only ].
- visualization.html : window.__p7SetState after :281 [ rotX rotY zoom ].

CRITICAL page physics [ visualization.html ]:
- updateCamera() eases `zoom` toward `manualZoom` EVERY frame
  unconditionally — setting zoom alone decays back within ~1s. the zoom
  hook MUST also pin manualZoom [ user-approved deviation from the
  agreed one-liner ]: `zoom: v => { zoom = v; manualZoom = v; }`.
- rotX hook-sets get pulled toward nearest 90deg by alignRotation()
  [ followEnabled && !isDragging ] — same caveat as verify= before:
  rotX landing only holds on multiples of 90. live-demoed: state-play
  rotX=33 -> verify FORCED [timeout], then drifts.

gotchas hit this pass:
- `$1`/`$2` capture clobber: a SECOND regex test (`$val !~ $num_re`)
  between the capture match and its use resets $1/$2 to undef ->
  waypoint stored { '' => 0 }. save captures to lexical vars
  IMMEDIATELY after the match. ptd does not catch this.
- pipe alternation inside pipe-delimited regex breaks at RUNTIME load,
  not in ptd: `m|^(?:a|b)$|` -> "Unmatched ( in regex". use braces:
  `m{^(?:a|b)$}`. broken subs reject the whole `reload source`.
- `p7c web-browser.reload source` works [ in access.cmd.usr.cube ].
  `list-subs` does NOT: devmod is commented out of modules.load in
  zenki/web-browser/start [ enable there if needed ].
- `p7c web-browser.commands` lists registered commands; `run_js`,
  `get_uri`, `get_snapshot` available for live testing.
- new page-side hooks need a page reload: run_js 'location.reload()'
  [ same uri, pin-safe ].

live-verified 2026-07-16 [ p7c against running zenka ]:
- state-play rotY=120 zoom=2.5 bezier -> PASS delta +0 both, held on
  tight-tolerance follow-up [ manualZoom pin works ]
- waypoint round-trip: wp1=120/2.5, moved to 45/0.8, goto-waypoint wp1
  -> PASS delta +0 both [ snapshot: HUD Zoom 80% -> 250% ]
- error paths: no-hook var, no-such-waypoint, non-numeric target all
  return clean false replies
- FORCED path: rotX=33 timeout -> one exact hook call, label FORCED

whitelist regenerated [ 652 subs ]; signatures pending - user re-signs.

#,,.,,,,.,...,,,.,,.,,,,.,.,,,...,,,.,,,.,,.,,..,,...,...,,,,,,..,,,.,,.,,..,,
#4IRNOKPFD7PEDJ7YKNBFRCG7UQKKP4CMJWQ7IRRNNMEQPQEVP4WT5ZYZ3RESGNG5EF6QCFBUU7EIO
#\\\|DXWMUW2U3P6K27R3G2YCYUHNSVYMSO2W4JQA64QJXB6MK42REUT \ / AMOS7 \ YOURUM ::
#\[7]SU3XJ73A7YVEMPWXAIGXMXD3IDLFDOEVYYSIOQUFD7ODMGUQTQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
