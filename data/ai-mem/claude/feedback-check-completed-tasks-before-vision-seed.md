---
name: feedback-check-completed-tasks-before-vision-seed
description: "wrote a 'someday, needs building' vision seed (vision-reproducible-visualization-state-capture.md) purely from how the user spoke about a need, without checking data/tasks/completed/ first -- the described infrastructure (input record/replay + wait-for-state) was already landed weeks earlier and needed retrofitting, not inventing"
metadata:
  type: feedback
---

2026-08-29: wrote `vision-reproducible-visualization-state-capture.md` framing full
interactive-state capture/replay as infrastructure that needs to be built "someday," based
entirely on the user's own framing of the need ("better infrastructure to make it
reproducible"). Never checked `data/tasks/completed/` first. The user later pointed at
`data/tasks/completed/web-browser-input-capture-replay.md` and
`web-browser-param-capture-graphing.md` — both landed 2026-07-16, both build almost exactly
what I proposed inventing (`web-browser.cmd.replay-record/replay-play/replay-synth`,
`wait-for-state` convergence polling, `window.debug*` state-vector convention). The real gap
was per-page wiring (does this specific visualization page expose the convention yet?), not a
missing subsystem.

**User's own framing, verbatim in spirit**: "you inherited it from the way i spoke about it,
i should have mentioned we should check the current state as it was at least planned" — the
user takes partial responsibility for not flagging it, but the underlying miss is mine: I
took the user's spoken description of a felt need at face value as a description of the
CURRENT implementation state, rather than treating it as a description of the problem to be
solved (which may already be partly or fully solved).

**How to apply**: before writing a vision/seed memory that frames something as "needs to be
built," search `data/tasks/completed/` (and `data/tasks/` generally, and relevant
`data/ai-mem/*/topic-*`/`project-*` files) for prior art on the same problem shape first —
even when the user's own phrasing sounds like they're describing a gap. A user's framing of a
*need* is not evidence about the *current state of the codebase*; those are separate
questions and only the second one is answerable by searching, not by re-stating the framing
back. This applies most when the "someday, not urgent" framing means the note might sit
unread for a long time before anyone checks it against reality — get it right up front rather
than relying on a future correction pass.

#,,,.,,,.,..,,,..,,..,.,,,.,.,.,,,..,,.,.,..,,..,,...,...,,.,,,,.,,.,,...,,,,,
#J3SNGRXUK4JMHHFWEOSY526G557LFBPZ7HWW6VXMG6PS543VMLBCP3K4GEFHMJZZETTTQBM253HHG
#\\\|S2CQMBR7U6TFVU5QWFCZFMVUOYYYK5Z3WMMPLJVCANXXKXSDQKL \ / AMOS7 \ YOURUM ::
#\[7]34AD2CUHJAFUGIKJBRWGRMQ2IWKFQMBGFN5HD754VHGM5VKP4MBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
