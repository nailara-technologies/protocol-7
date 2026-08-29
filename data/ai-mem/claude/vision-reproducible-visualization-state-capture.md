---
name: vision-reproducible-visualization-state-capture
description: "SEED: apply the ALREADY-LANDED web-browser input record/replay + wait-for-state infra to make hand-tuned interactive visualization captures reproducible instead of manual and fragile — grew out of an unrecoverable data-loss incident, 2026-08-28. Corrected 2026-08-29: this is a retrofit/apply task, not a build-from-scratch task"
metadata:
  node_type: memory
  type: vision
---

Grew directly out of [[feedback-deleted-manually-tuned-captures-without-confirming]]: 117
files deleted from a shared snapshot directory, some of which were hand-tuned interactive
visualization captures (cubic-space visualizations with manually-adjusted parameters) the
user intended to keep for the website. Unrecoverable — no filesystem snapshot/trash existed,
and the captured STATE (manual slider/camera/scroll adjustments) isn't reproducible from a
fresh page-load of the source HTML alone, which resets to default parameter values.

**User's own framing, verbatim in spirit**: partly his own fault too — he knew the directory
needed sorting/rescuing and postponed it because doing so manually was too much effort. Will
recreate the lost captures "someday" with "better infrastructure to make it reproducible" —
explicitly: not manually again.

**CORRECTION (2026-08-29, caught by the user)**: the first version of this note proposed
inventing state-capture/replay infrastructure "someday." That infrastructure already exists
and is LANDED, not hypothetical — I hadn't checked `data/tasks/completed/` before writing it.
Two completed tasks built exactly this:
- `data/tasks/completed/web-browser-param-capture-graphing.md` — `window.debug*` state-vector
  exposure convention (e.g. `window.debugZoom`, `debugRotX`, `debugRotY` in
  `data/web-root/vhosts/space.v7.ax/visualization.html`), `web-browser.cmd.graph-params`,
  `console_capture.*` js-injection/buffer pipeline.
- `data/tasks/completed/web-browser-input-capture-replay.md` — builds directly on the above.
  `web-browser.cmd.replay-record start|stop`, `replay-play <buffer|json> [verify=...]`,
  `replay-synth type=drag|wheel path=linear|bezier ...`, and a standalone
  `web-browser.cmd.wait-for-state var1 var2 ... [tolerance] [samples] [timeout]` convergence
  poller. Normalized, device-independent event format (fractional x/y, ms timestamps).
  Recordings are pinned to their frontend via a BMW checksum of the URL so replay can't
  silently fire against the wrong page. All six build-order steps landed 2026-07-16 (commits
  `9c297b9e5`, `803384253`), live-verified including deliberate-mismatch FAIL detection —
  see `data/ai-mem/kimi/topic-web-browser-replay-verify-synth.md` for exact numeric results
  and the one known gotcha (`alignRotation()` drifts `rotX`/`rotZ` toward the nearest 90°
  under follow-mode, so only `rotY`/`zoom` are stable `verify=` targets on that page).

That task's own "relationship to other work" section already named this exact use case
("screenshot-driven template generation across the project's visualizations") as a distinct,
not-yet-started follow-up — this vision note and that follow-up are the same task.

**What's actually still missing**: not the capture/replay/convergence machinery — that's
done and reusable as-is. What's missing is per-page wiring: does a given AI-generated
visualization page (the lost cubic-space ones, and any future one) expose
`window.__p7ReplayTarget` and a `window.debug*` state vector at all? `visualization.html`
(the hyperspace/space.v7.ax page) already does — it was the actual implementation fixture
used to build and verify `replay-record`/`replay-play`/`replay-synth` in the first place
(user-confirmed, 2026-08-29), so record/replay/verify is directly usable on it right now,
zero retrofit needed. Any OTHER visualization page (the lost cubic-space captures may or may
not be this same page — not yet confirmed either way) needs that one-line wiring added first
— this is a small per-page retrofit, not a new subsystem. The scroll-position commands built
the same session
(`web-browser.cmd.set-pos-y`/`set-fg-pos`/`set-bg-pos-y`, see
`data/tasks/web-browser-fast-scroll-position-commands.md`) remain a useful, separate,
complementary piece (page-level scroll position, not in-canvas interactive state) — not a
substitute or a first step toward the above; they solve a different axis of "state."

**How to apply**: don't build this speculatively — the hard part is already built. When
resumed: (1) check whether the specific visualization page(s) in question already expose the
`window.debug*`/`__p7ReplayTarget` convention, (2) if not, add the one-line wiring per the
existing pattern, (3) use `replay-record`/`replay-play`/`replay-synth` + `wait-for-state` +
`get_snapshot` directly — no new capture format or transport needed. Still explicitly
"someday" — wait for the user to pick this up rather than starting unprompted.

#,,,,,.,.,.,.,,.,,...,,..,..,,...,,,,,,..,..,,..,,...,..,,...,...,,.,,..,,,..,
#CCOXXUN2TT6J7PKKYRPGWDQDEAMLAUIAIA66I3J3UKSHQZ3RSKFCTSWTVGHXVDBX3A7W6LKTFK3R6
#\\\|ZJKI2AH3QPOIKSTWREMLZBCKL4IYL5JQCWMC5VWPPFMUXBU7X7K \ / AMOS7 \ YOURUM ::
#\[7]SH5LAU7UW2LKS5B2TX25RJEGTUNDHZU7IBY7P4RAFV24LBH3DQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
