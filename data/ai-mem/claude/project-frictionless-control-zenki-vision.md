---
name: project-frictionless-control-zenki-vision
description: "2026-08-16 user direction: user-edit and related zenki are becoming ZENTRAL CONTROL POINTS for the system and need to be frictionless by default -- first concrete instance is building the event-loop-safe in-frame prompt (option B) instead of a blocking terminal excursion for the key-actions create flow, with more such compaction/refinement passes expected"
metadata:
  type: project
---

**Per user, 2026-08-16**, deciding between two fixes for the key-actions
create prompt visually breaking out of `user-edit`'s ascii.frame (plain
`base.term.ask` output, unstyled, below the frame border): explicitly chose
the bigger option -- **B: a real in-frame, event-loop-safe prompt**, not
just a cosmetic wrapper around the existing blocking excursion (option A).
Full account of both options and the tradeoff is in the key-actions rescue
thread this session; option B is exactly the previously-flagged,
still-unbuilt gap documented in
[[reference-console-question-ask-primitive]]'s "BLOCKING — the constraint
that matters" section: `base.term.ask` cannot be called inside a running
event loop, and an event-loop-safe prompt "needed for `masked` credential
entry *inside* user-edit's form" has been a known, deferred gap since at
least 2026-08-12.

**Stated reasoning, directly from the user**: this is not a one-off
polish request. "There will be multiple more such compaction and refinement
passes" -- i.e. expect a recurring pattern of picking a working-but-rough
mechanism (a blocking excursion, a raw-terminal drop-out, etc) and
replacing it with a properly integrated, in-loop equivalent, repeatedly,
across future sessions. And the motivating WHY, stated directly: `user-edit`
and "soon related zenki" are becoming **ZENTRAL CONTROL POINTS** for the
system, and such control points need to be **frictionless by default** so
that overall system usage becomes effortless.

**How to apply**:
- Do not treat future "just make it look nicer" requests in `user-edit` (or
  whichever zenka becomes a control point next) as purely cosmetic asks in
  isolation -- check whether the underlying mechanism is a stopgap
  (blocking excursion, raw drop-out, a one-off workaround) that the user
  would rather see properly integrated instead, per this stated preference.
- When scoping such a pass, the underlying event-loop-safe-prompt
  infrastructure (once built for key-actions) is very likely REUSABLE for
  the other already-known blocked features that hit the exact same wall:
  `masked`/credential field entry inside a running form
  ([[project-credential-types-into-user-edit]]), and the encrypted-key
  passphrase entry this same key-actions excursion also uses. Build it
  general enough to serve all three, not key-actions-specific.
- This is real, nontrivial infrastructure work (spans `editor.control.*`,
  `editor.ui.ascii_frame`, the buffer/masking layer, and `user-edit`'s own
  excursion/dispatch mechanism) -- scope and dispatch it as its own proper
  task, not a quick inline patch tacked onto whatever else is in flight.

#,,,.,,..,.,,,,,,,,,,,.,.,.,.,,,.,,,,,,..,.,.,..,,...,...,...,.,.,..,,.,,,...,
#PVW2BB3AYK7NEC645UQN4RNX4QOPQ5BCHZ7NM25DXPKDUYOQJPYC25OCEEWVXHPVOKGW2NVQDS2TC
#\\\|SX4GZCSCJ7A7XLQD3FPCQPAHZVWAGKVZ7LIWP27A25B5FGSRSUZ \ / AMOS7 \ YOURUM ::
#\[7]UGTEGD4SNAPG25DUZOJYN2SYKW42EPR3FKTJDSRHOFMHBDENYOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
