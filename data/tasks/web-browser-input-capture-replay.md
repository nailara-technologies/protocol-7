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

## open questions

- capture format: raw event log vs. normalized (position deltas only,
  device-independent) — normalized is probably needed for curve-based
  synthesis to share a format with recordings.
  - replay needs to target the same event listeners
  (`canvas.addEventListener('wheel'/'mousedown'/...)`)  already present in
  each visualization page — is a generic "input replay" JS template
  (following the `graph_template.*` convention) enough, or does each
  page need small per-page hooks (a `window.__p7ReplayTarget` = canvas
  convention, mirroring `window.debug*`)?
- convergence detection for (4): needs a generic "state vector settled"
  check (e.g. N consecutive samples within epsilon) — likely reusable
  across any page that exposes `window.debug*` state, not
  visualization.html-specific.
- how much of this belongs in `web-browser.*` zenka modules vs. living
  as page-side JS templates (same split already established between
  `graph_template.*` in-page JS and the Perl-side `graph-params`
  command that wires it up).

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

Design-only, nothing implemented. Spun off during the same session that
landed [[web-browser-param-capture-graphing]] (commit cae42647d).

#,,,,,,,,,,,.,,,,,,.,,.,.,...,.,,,,..,.,,,,,.,..,,...,...,.,,,,.,,.,,,...,,.,,
#UKK6U5CZ32RL4M46DZJS6FCQPNTSVDNISQYD5725YHRMTYLOINOGLDTZPAY7ODYYTHSFIKSRTB6SI
#\\\|OWLG27I4RSWTOSM6N4FOFAJFWJEZEENBMUVO6QDLLLCY7WFP4TF \ / AMOS7 \ YOURUM ::
#\[7]TCPWW2755TF3GWMR4RDAOLFBWRBXWWS6G65OMV3QVXAGLCZIKMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
