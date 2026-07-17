# web-browser zenka: input capture/replay, synthetic curves, state snapshots

## what this is

A follow-up to [[web-browser-param-capture-graphing]] (LANDED, commit
cae42647d) — that task built live variable capture + graphing, which
successfully root-caused the zoom-momentum-reversal bug (a stray click
sandwiched between rotate-drag/wheel-zoom gestures misfiring the
empty-space zoom reset). Design was worked out conversationally; nothing
below is implemented yet.

The natural next step: capture/graphing only lets you *observe* a
reproduction after it happens live. This task is about *driving* the
reproduction deterministically instead — record real input once, replay
it exactly, or synthesize input from a curve, and recall/verify the
resulting state precisely. Two motivations converge here:

1. **exact bug reproduction** — animations/perspectives driven by
   interactive input (drag, wheel) are currently only reproducible by a
   human re-doing the gesture by feel. A recorded or synthetic input
   script makes reproduction deterministic and shareable (drop it in as
   a regression check), and makes it practical to fuzz for other
   timing-coincidence bugs like the one just fixed.
2. **project website templates** (don't exist yet) — the project needs
   an automated way to generate screenshots across the many existing
   visualizations (space.v7.ax's visualization.html and others) under
   **defined test conditions**, despite the visualizations having
   dynamic/animated state. That requires the same two primitives:
   drive the view to a known state deterministically, then capture it.

## design (sketched, not agreed in detail yet)

### 1. input capture

Record real DOM input events (`mousedown`, `mousemove`, `mouseup`,
`wheel`) with timestamps into a buffer, same shape as
`web-browser.console_capture`'s per-view ring buffer — reuse the
`p7cons`-style postMessage channel and `base.buffer.add_line` sink
rather than inventing a new transport.

### 2. input replay

Dispatch synthetic `MouseEvent`/`WheelEvent` objects on the same
timeline recorded in (1). Turns "reproduce the mystical bug" into "run
this recorded script" — deterministic, and safe to check into the repo
as a regression fixture for the actual page under test (e.g.
`visualization.html`'s drag/wheel handlers).

### 3. synthetic linear/curve-based input

Rather than only replaying a raw recording, generate input from
parametric drivers: linear ramps, easing curves, bezier paths. Useful
for:
- stress-testing easing/momentum code paths (like the
  `CURVES.ZOOM_FOLLOW` / `CURVES.ZOOM_TARGET_ZOOM` logic just touched)
  without a human re-driving the wheel every time.
- fuzzing for other stray-event / race-condition bugs of the same
  shape as the empty-space-click zoom-reset bug — e.g. randomized
  short-gap click insertion between synthetic drag sequences.

### 4. snapshot-based state recall

Not just a screenshot — capture the **full relevant parameter vector**
at a point in time (whatever's exposed via the existing
`window.debug*` convention from param-capture-graphing, e.g.
`rotX/rotY/zoom/manualZoom/...`), so a "perspective" is recallable
exactly, not just visually approximated. This is what makes (1)-(3)
useful for *exact* reproduction rather than "looked about the same":
replay input deterministically, then verify the landed state vector
matches a recorded target exactly (or within tolerance), not just that
the screenshot looks similar.

### convergence: automated screenshot generation for website templates

Combining (2)/(3) + (4): drive a visualization to a defined state via
synthetic/replayed input, wait for convergence (poll the state vector
until stable or until a target is hit), then call the existing
`web-browser.cmd.get_snapshot` to capture. This gives **defined test
conditions despite dynamic values** — the actual missing piece for
building screenshot-driven website templates across the project's
several existing visualizations, most of which currently only look
"correct" after some amount of human-driven interaction (rotation,
zoom, selection) that has no deterministic replay path today.

## open questions — RESOLVED (2026-07-16, ready to implement)

Precedent confirmed live in the tree: `web-browser.cmd.graph-params`,
`web-browser.graph_params.install`, `web-browser.graph_template.default.js_source`,
`web-browser.graph_template.list`, `web-browser.console_capture.{js_source,install,
buffer_name,reset}` all exist and landed as part of
[[web-browser-param-capture-graphing]] — this task builds directly on top of
that working code, not a fresh mechanism.

- **capture format**: normalized, device-independent. Each event record is
  `{ t: <ms since recording start>, type: 'down'|'move'|'up'|'wheel',
  x: <0..1 fraction of target's clientWidth>, y: <0..1 fraction of
  clientHeight>, dz: <wheel deltaY, only for type='wheel'> }`. Fractional
  x/y means a recording replays correctly regardless of window/canvas size
  at replay time. This is the *one* format shared by capture, replay, and
  curve-synthesis (synthesis just generates the same record shape without a
  human ever producing it).
- **replay target**: mirror the existing `window.debug*` convention exactly
  — each page under test sets `window.__p7ReplayTarget = canvas;` once
  (one line, same place the `window.debugZoom = zoom;` block already lives
  in `visualization.html:832-839`). The generic replay JS template
  dispatches synthetic events against `window.__p7ReplayTarget`, falling
  back to `document` if unset. No per-page replay logic beyond that one
  assignment — same split as `debugRotX`/`debugZoom` today.
- **convergence detection**: new generic command, not visualization-specific.
  `web-browser.cmd.wait-for-state var1 var2 ... [tolerance=0.01]
  [samples=5] [timeout=10]` — polls `window[name]` for every listed var
  (same existence-check pattern as `graph-params`'s missing-name abort) at
  a short fixed interval until `samples` consecutive reads are each within
  `tolerance` of the previous read, for every var, or `timeout` elapses.
  Replies with the final value vector either way (success flag distinguishes
  settle vs. timeout). Reusable standalone, not folded into replay only.
- **module placement**: same split already established by
  `graph_template.*` (in-page JS) vs. `graph-params`/`graph_params.install`
  (Perl wiring) — new work follows the identical shape, listed below.

### frontend pinning (added 2026-07-16, not yet implemented)

A recording is only meaningful against the page it was captured on — nothing
currently stops `replay-play` from firing a recorded gesture at an unrelated
page. Pin each recording to its frontend using the existing
`<[chk-sum.bmw.L13-str]>->($input)` (13-char BASE32 BMW checksum, same
primitive already used for cache-keying/path-checksums elsewhere, e.g.
`base.parser.key_mem_chksum`) over the view's URL path+query (fragment
stripped, since that often holds ephemeral view-state, not identity):

- `replay-record start` computes the pin checksum from `$view->get_uri()`
  (Perl-side, no extra JS round trip) and writes it as a leading buffer
  line via the same `base.buffer.add_line` sink used for event records,
  shaped `{type:'meta', url:<full-uri>, chk:<L13-str>}` — reuses the
  existing per-record `type` field to stay out of `replay-play`'s event
  loop rather than inventing a second storage path.
- `replay-play` reads the leading `meta` record (from either a named
  buffer or a JSON file — same shape either way), recomputes the current
  foreground view's pin checksum the same way, and aborts with a clear
  mismatch message (recorded url/chk vs. current url/chk) unless the
  caller passes an explicit override (e.g. `force=1`) — this is the guard
  against "replay on the wrong frontend."
- side benefit for the screenshot-batch idea below: recordings sharing a
  pin checksum are already grouped by frontend with zero extra metadata —
  later tooling can bucket by `chk` directly.

### module layout (mirrors `console_capture.*` / `graph_template.*` exactly)

- `web-browser.replay_capture.js_source` — hooks `mousedown`/`mousemove`/
  `mouseup`/`wheel` on `window.__p7ReplayTarget` (fallback `document`),
  normalizes to the record shape above, pushes to `window.__p7ReplayBuffer`
  while `window.__p7RecordingActive` is true, posts each record via a new
  `p7replay` message-handler channel (same `postMessage` shape as
  `p7cons`, not overloading the console channel).
- `web-browser.replay_capture.install` — wires the `UserScript` + registers
  `script-message-received::p7replay`, mirroring
  `web-browser.console_capture.install` line for line (view, view_id ->
  named buffer via `base.buffer.add_line`).
- `web-browser.replay_capture.buffer_name` — mirrors
  `web-browser.console_capture.buffer_name`.
- `web-browser.cmd.replay-record start|stop [target=<js-expr>]` — toggles
  `window.__p7RecordingActive`; `start` installs the capture script if not
  already installed (idempotent guard like `__p7ConsoleHooked`).
- `web-browser.cmd.replay-play <buffer-name-or-json-path> [speed=1.0]
  [verify=var:target,...] [tolerance=0.01]` — loads the normalized event
  array, dispatches synthetic `MouseEvent`/`WheelEvent` objects against
  `window.__p7ReplayTarget` on the recorded timeline (scaled by `speed`),
  then — if `verify=` given — calls the same settle-poll logic as
  `wait-for-state` and diffs final values against the targets, replying
  pass/fail with the deltas.
- `web-browser.cmd.replay-synth type=drag|wheel path=linear|bezier
  duration=<ms> ...` — generates a normalized event array from parametric
  curves (no prior recording needed) and feeds it into the same
  `replay-play` dispatch engine, so linear ramps/easing/bezier fuzzing
  reuses one playback path rather than a second implementation.
- `web-browser.cmd.wait-for-state` — standalone convergence command as
  specified above; also called internally by `replay-play`'s `verify=`.

### build order

1. `replay_capture.js_source` + `.install` + `.buffer_name` + `replay-record`
   command — get a real recording landing in a named buffer, verified by
   hand-driving `visualization.html` and reading the buffer back.
2. `replay-play` (recording-only, no `verify=` yet) — dispatch synthetic
   events against `__p7ReplayTarget`, confirm the same rotate/zoom motion
   reproduces from the recorded buffer.
3. `wait-for-state` standalone — validate against `visualization.html`'s
   `window.debugZoom`/`debugRotX`/`debugRotY` settling after a manual drag.
4. wire `verify=` into `replay-play` using (3).
5. `replay-synth` curve generator, reusing (2)'s dispatch engine.
6. add `window.__p7ReplayTarget = canvas;` to `visualization.html` (one
   line near the existing `window.debugZoom` block at line ~833) and use
   it as the first real fixture: record a rotate-drag + wheel-zoom gesture,
   replay it, verify the landed `rotX/rotY/zoom` vector matches within
   tolerance — this is the acceptance test for the whole feature.

## relationship to other work

- builds directly on [[web-browser-param-capture-graphing]] — reuses
  the `window.debug*` exposure convention and the js_source template
  pattern (`web-browser.graph_template.*` → likely
  `web-browser.replay_template.*` or similar).
- motivates and is motivated by a **project website templates** effort
  that doesn't exist yet — screenshot-driven template generation across
  the project's visualizations is blocked on this, not the other way
  around, so this task is the prerequisite piece.

## status

All six build-order steps LANDED (2026-07-16, kimi K3 model, 3 dispatch
rounds). Steps 1-3 + frontend pinning: commits 9c297b9e5, 803384253. Steps
4-6 (verify= wiring, replay-synth, visualization.html fixture): live-tested
against the running web-browser zenka — linear/bezier drag and wheel synth
all verified via `verify=` against `window.debugRotY`/`debugZoom`,
including a deliberate mismatch case to confirm FAIL detection works, not
just the happy path. Gotcha found live: `alignRotation()` drifts
`rotX`/`rotZ` toward the nearest 90° under follow-mode, so only `rotY` and
`zoom` are stable `verify=` targets — see
`data/ai-mem/kimi/topic-web-browser-replay-verify-synth.md` for full
details and exact numeric results.

Feature complete for the original motivation (exact bug reproduction via
recorded/synthetic input + state verification). The "screenshot-batch
across all visualizations" convergence idea from the relationship section
above is a distinct follow-up task, not yet started.

#,,,.,...,,,,,,,.,.,,,,..,...,..,,,.,,.,.,,,.,..,,...,.,.,...,,.,,...,,,,,,.,,
#3WBWRCFXT44DQNZO3NKF4Q22VDTVNSTMQH5LXXKZRKUGPVCZX2G4SI26T5SGK74QPJZYUJMBR7PD2
#\\\|QWADDIH4H3D4FG2MXMLD24PZ57IBVJS3USFSGQ5FZHJFPBC3YX7 \ / AMOS7 \ YOURUM ::
#\[7]OIQ6OEOFPRNY63TMOLA56GEBGNI4OHXSZDUGBEZMAOSGFLPS6GBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
