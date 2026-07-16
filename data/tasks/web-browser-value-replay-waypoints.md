# web-browser zenka: direct value replay, curve-smoothed waypoints

## what this is

A follow-up to [[web-browser-input-capture-replay]] (LANDED, commits
9c297b9e5, 803384253, d0e823312) — that task drives page state by
simulating DOM input (recorded or curve-synthesized) and lets the page's
own interaction logic compute the resulting values. This task adds a
second, complementary replay mode: setting the state values directly,
bypassing interaction logic entirely.

## why a second mode, not an extension of the first

`window.debugZoom = zoom;` (and siblings) in `visualization.html` is a
**one-way mirror**, written every animation frame from the real
closure-local `zoom`/`rotX`/`rotY` variables to `window` for external
read access (capture/graph/verify). Assigning to `window.debugZoom`
externally does nothing — the render loop overwrites it again next frame
from the real internal variable. Confirmed by reading the source directly
(`visualization.html:277-281` declares the plain `let` closures;
`:836` writes the one-way mirror) before proposing this, not assumed.

So driving state directly requires each page to expose a **write-back
hook**, symmetric to how `window.__p7ReplayTarget` is already the
write-side convention for input replay. Two replay modes, genuinely
different in kind:

- **input-simulation** (existing): dispatches synthetic DOM events: the
  page's own physics/damping computes state. Right tool for bug
  reproduction, since the bug usually lives in that interaction logic.
- **value-injection** (this task): directly sets state along a recorded
  or curve-synthesized timeline via the write-back hook, skipping
  interaction logic. Right tool when you just need to *land* on an exact
  state fast — which matters concretely because inverting "what input
  produces this exact state" is genuinely hard-to-impossible once
  damping/velocity is involved (`alignRotation()`'s drift toward the
  nearest 90° is exactly why `rotX`/`rotZ` were already ruled out as
  stable `verify=` targets in the landed task — you can't easily
  reverse-engineer input to hit a precise `rotX`, but you can just set it).

## design sketch (not agreed in detail yet)

### 1. write-back hook convention

Each page under test exposes something like:

```js
window.__p7SetState = { rotX: v => { rotX = v; }, zoom: v => { zoom = v; }, ... };
```

mirroring the existing `window.debug*` exposure and `__p7ReplayTarget`
conventions exactly — same opt-in shape, same "one line per page" cost.

### 2. curve-smoothed, tolerance-verified arrival

Not an instant snap: interpolate from current value to target over a
duration using curve math generalized from `replay-synth`'s existing
linear/bezier engine (currently x/y position and wheel `dz` only — this
generalizes it to arbitrary named vars via the write-back hook instead of
synthetic events). After the eased curve completes, run the existing
`wait-state-poll` settle check and apply a final hard-set via the hook if
there's residual drift — smooth *and* exact, not a tradeoff between them.

### 3. waypoints : named, pinned, exact target states

A waypoint is a named target state vector, pinned to its frontend via the
same `<[chk-sum.bmw.L13-str]>` mechanism already used for recording
pinning (see [[web-browser-input-capture-replay]] "frontend pinning"
section) — so a waypoint name can't misfire against the wrong page.
`goto-waypoint <name>` drives (2) toward the stored vector.

### resolved command shapes (2026-07-16, ready to implement for 1-3)

- **hook**: add `window.__p7SetState = { rotX: v => { rotX = v; }, rotY:
  v => { rotY = v; }, zoom: v => { zoom = v; } };` to `visualization.html`
  right where `rotX`/`rotY`/`zoom` are declared (`:277-281`), so the
  closures are captured directly — same file, same "one line block" cost
  as `__p7ReplayTarget`. Only wiring the three vars already used as
  `verify=` targets; no need to cover every debug var.
- **`web-browser.cmd.state-play var=target,.. duration=<ms>
  [path=linear|bezier] [tolerance=] [samples=] [timeout=]`** — generalizes
  `replay-synth`'s curve engine: instead of producing DOM events, produces
  a timed sequence of `window.__p7SetState[name](value)` calls via the
  hook. Mirror the existing `web-browser.replay.dispatch` /
  `replay_template.dispatch_js` split (shared JS dispatch template + Perl
  wiring) rather than writing a parallel one-off. After the eased curve
  finishes, run `wait-state-poll` same as `replay.dispatch`'s `verify=`
  path; if there's residual drift beyond `tolerance` once settled/timed
  out, issue one final direct `__p7SetState[name](target)` call per var
  to force exact landing — smooth curve, exact guarantee, not a tradeoff.
- **`web-browser.cmd.waypoint-set <name> var=target,..`** — stores the
  vector in-memory (e.g. `$data{'waypoint'}{$name}`), pinned via the same
  `<[chk-sum.bmw.L13-str]>` computation `replay-record` already uses
  (`$view->get_uri()`, fragment stripped). No file persistence in this
  pass — that's the same follow-up shape as the already-noted
  `mpv-persistence` "snapshot+curve automation" item, not scope creep here.
- **`web-browser.cmd.goto-waypoint <name> [duration=] [path=]
  [force=1]`** — looks up the stored vector, checks the pin the same way
  `replay-play` does (abort with a clear mismatch message unless
  `force=1`), then drives `state-play` toward it.

### 4. multi-window coordination (bigger, less settled)

Motivated by the project's move toward multi-window space-embedded UIs,
where several windows are different views/layers into a shared
conceptual space and need to arrive at related perspectives together, not
independently drifting on their own schedules. Since each window already
pins to its own frontend independently, a waypoint registry naturally
generalizes to name → { per-window target state, shared transition
timing }, so one `goto-waypoint` call fans out to several windows on a
common clock. Registry location/shape (per-zenka vs. shared across
zenki, how "a group of windows" is named/discovered) is not decided —
needs its own design pass, likely informed by how `tile`/`window.place`
already coordinate multi-window placement, rather than inventing a
parallel mechanism.

## vision / not yet scoped

Discussed but deliberately not designed here — noted so it isn't lost,
not because it's next:

- **the cubic space as ambient, not one more visualization** — the intent
  is that every visualization/window is implicitly a view *into* one
  shared cubic space, not a separate coordinate system of its own. This
  includes flat 2D UIs: a 2D "desktop" window is conceived as a
  translucent plate positioned/oriented as an object *within* the cube,
  showing whatever view is informative through it, not as separate flat
  UI bolted alongside a 3D visualization. Under this framing, (1)-(3)
  above (write-back hook, curve-smoothed exact arrival, pinned waypoints)
  are the mechanism-level substrate every window needs regardless of
  whether it renders 3D or 2D content — the universal layer is the
  positioning/orientation/waypoint machinery, not the rendering.
  `rotX/rotY/zoom` is already implicitly a spherical-camera
  parameterization (angle, angle, distance) of one object's perspective
  within that space, so a **direction + focal point** framing is closer
  to the intended native representation than raw per-page scalar vars,
  once more than one visualization needs to share it.
- **parent-space / nesting** — waypoints or windows positioned relative
  to a containing space's coordinate frame rather than each page's own
  flat variable set. Connects to existing design threads
  ([[topic-window-canvas-addressing]], [[topic-node-group-geometry]])
  rather than starting fresh.
- vector/vertex representation generally, once more than one visualization
  needs to share a common spatial addressing scheme rather than each
  having its own bespoke `window.debug*` variable names.

## relationship to other work

- builds directly on [[web-browser-input-capture-replay]] — reuses the
  BMW-L13 pinning, the `replay-synth` curve engine (generalized), and
  `wait-state-poll`.
- motivated by the same **project website templates** effort noted in
  that task, plus the emerging multi-window space-embedded UI direction
  ([[topic-window-canvas-addressing]], [[topic-tile-window-place-hybrid-desktop]]).

## status

Design-only, nothing implemented. Spun off during the session that closed
out [[web-browser-input-capture-replay]] (commit d0e823312), 2026-07-16.

#,,..,...,..,,,.,,..,,,,,,..,,,..,,,,,.,.,.,,,..,,...,...,...,,,,,..,,,..,...,
#44EF6JZSX3EI2B7QDYQNJC6A4DLV3NPJ4DJEIZLGDI4LMRD5YZXIPA55BZ6JWMVOYA435V7NOCIGC
#\\\|A65ALUCFLY2SGYFSHA4QDFAI7YEWJDAGICWQXKCZ3YNBX576PXK \ / AMOS7 \ YOURUM ::
#\[7]U3IRUVAHTRLPSISUD3UAXP64SRIP6TOBI2CIPT5FVLTY5R62Q2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
