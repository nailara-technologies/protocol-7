---
name: project-round-chain-rewind-redo-landed-2026-09-14
description: round-chain rewind/redo/round-regen feature fully landed and live-verified in the coding zenka + nshell, 2026-09-14
metadata:
  type: project
---

Full round-based rewind/redo for the coding zenka's async task loop, committed and confirmed
working live end-to-end (not just unit-level) on 2026-09-14, across commits `bb19e85e1`,
`725833105`, `5ef0760e2`, `f2158945e`. Design origin: [[topic-format-code-bugs-fixed]]-adjacent
work earlier the same day in `data/tasks/coding-zenka-session-ui.md` (git-commit-style
parent-pointer chain, BMW-L13 chained checksums, masking not replacing for compaction).

## What exists now

- **`round_chain`**: a top-level array on each task record, git-commit-style — each node has
  `{round, type, parent, checksum, delta, timestamp[, masks_from]}`. `checksum = chain_L13(parent,
  canonical_json(delta))`. `round_chain_current` is the movable tip a new append parents off of —
  NOT always the array's physical last entry, which is what makes rewind-then-append a real fork
  instead of overwriting history.
- **`coding.round_chain.append`** (called from `coding.async.state_machine`'s `tools_done`/
  `user_responded`/loop-assertion branches, and from `coding.async.complete`'s success path) —
  the only writer.
- **`coding.round_chain.reconstruct`** — pure, folds nested compaction masks, walks parent
  pointers to build the effective messages array as of any node.
- **`coding.cmd.rewind-round`** / **`coding.cmd.redo-round`** — pure buffer/pointer navigation,
  NO inference triggered. Move `round_chain_current`, sync `execution.messages`, embed a replay
  of the target round directly in their own reply (`mode=>'size'`, not `'true'` — see the
  feedback memory this links to for why).
- **`coding.cmd.round-regen`** — the separate, deliberate command that DOES trigger fresh
  inference at the current round_chain position, creating a real fork. Named after rejecting
  "re-parent-round" as unclear about the inference side.
- **`coding.cmd.restream`** / **`coding.round_chain.restream`** — standalone, manual "resync my
  view" push via a task's live session.listeners. NOT auto-called by rewind/redo (see linked
  feedback memory — that combination caused a real regression).
- **nshell wiring**: Esc (after first-press-aborts) steps back one round on every subsequent
  press; F1 (always reliable) and Shift+Esc (best-effort, needs `nshell.term_init`'s Kitty/
  xterm keyboard-protocol negotiation to land on the user's terminal) redo forward.

## Known, deliberate scope gaps (not bugs)

- Subtask/chunked-summary/compaction message folding and failed-task completion paths are not
  round_chain-tracked yet.
- Genesis (system + first user message) is not its own round_chain node — a rewind/regen to a
  bare final-answer round with no parent (a no-tool-call round-0 task) is explicitly refused
  rather than silently mishandled.
- No true terminal-width-aware line counting anywhere in this stack (`restream`'s `[lines]` tail
  option shares `base.cmd.show-buffer`'s existing non-width-aware limitation, not a new one).
- A verbose-vs-summary toggle for tool-call output (live streaming already summarizes; replay
  now shows full content by design, confirmed live as the right default for replay specifically)
  is a real, separate, not-yet-built feature.

See [[feedback-coding-async-reply-and-listener-lifecycle-gotchas]] for the three reusable
subsystem-level gotchas found while live-testing this (session.listeners lifecycle, `size` vs
`true` reply mode, `redraw=>FALSE` pattern) — those apply to any future coding-zenka/nshell
feature, not just this one.

#,,..,.,,,,,.,..,,,,,,..,,,,.,,..,,.,,.,.,,.,,..,,...,...,.,,,..,,,,,,,..,,..,
#XEO7BUAE3LW7CGOOMSD3ESO2K7GVKYMZVJYUAOWTYWA7HEUNGRAGO6SJ4WDA6INXUQJUJ4JGQ6FUG
#\\\|EE36GR4O6LITKAZFVNPS3HUOZTF3M3XZMJ5LKS3TNJFLTKNN3HY \ / AMOS7 \ YOURUM ::
#\[7]7NUX3MXU23FUJWIL4F2KTAHU6FKESUBCU5S3ON735OPOKDRDWMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
