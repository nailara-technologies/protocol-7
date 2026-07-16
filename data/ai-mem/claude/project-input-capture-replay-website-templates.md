---
name: project-input-capture-replay-website-templates
description: "input capture/replay + curve-based synthetic input + state-vector snapshots, spun off to unblock automated screenshot generation for not-yet-built project website templates"
metadata: 
  node_type: memory
  type: project
  originSessionId: bb0cf140-dd76-483c-a959-f138f5260815
---

**LANDED 2026-07-16**, all 6 build-order steps, kimi K3 model (3 dispatch rounds), live-verified against the running web-browser zenka. Commits: 9c297b9e5 (capture/replay steps 1-3), 803384253 (BMW-L13 frontend pinning), d0e823312 (verify= wiring, replay-synth curves, visualization.html fixture). Design doc: `data/tasks/web-browser-input-capture-replay.md`. Follow-up spun off: [[project-web-browser-value-replay-waypoints]] (direct value-injection replay + waypoints, design-only).

Originally spun off in the same session that landed [[topic-plugin-web-jobs]]-adjacent work — specifically the session that shipped `web-browser.cmd.graph-params` ([[web-browser-param-capture-graphing]] task, commit cae42647d) and used it to root-cause the visualization.html zoom-momentum-reversal bug (a stray click sandwiched between rotate-drag/wheel-zoom gestures misfiring an empty-space zoom reset).

**Why:** the user has long wanted project website templates, which don't exist yet, and identified that building them requires an automated way to screenshot the project's many existing visualizations under **defined test conditions despite dynamic/animated values**. That in turn requires two primitives that don't exist yet: (a) driving a visualization to an exact, reproducible state via input replay/synthesis rather than live human interaction, and (b) verifying the landed state via a full parameter-vector snapshot (reusing the `window.debug*` convention from param-capture-graphing), not just eyeballing a screenshot. The user explicitly connected this to bug-reproduction value too: capture/replay turns "reproduce the mystical bug by feel" into a deterministic, replayable script — same mechanism, two payoffs.

**How to apply:** when asked about website templates, screenshot automation, or deterministic reproduction of interactive-animation bugs in the web-browser zenka, this design doc is the starting point — don't re-derive from scratch. It explicitly builds on the `graph_template.*` / `window.debug*` conventions, so keep new work consistent with those rather than inventing a parallel mechanism. Website-template work is understood to be *blocked on* this capture/replay layer, not the reverse.

#,,,.,,,,,,..,.,,,,,.,,,.,..,,...,,,,,.,,,,,,,..,,...,...,.,,,,.,,,,,,,.,,...,
#C3YGZIOFGBNYYWS4KNTDTYF3VTBG7QKFO7ALRYZ5MXOREXF2AVRCXN5TU3SMKHFPTXHHRCTHQPY64
#\\\|4PAFM44UQ3P7QIDSHFLHYQP2IFPBQ7ND44PQ56VBE7KCASGTGSC \ / AMOS7 \ YOURUM ::
#\[7]B2Z7XHEVHVCHT6LWZR26QAS6JSPFEOMDCLKK3TGFVCFACHJH4EAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
