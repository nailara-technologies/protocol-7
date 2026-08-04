---
name: feedback-model-routing-opus-cubic-viz-k3-design
description: user-stated model-routing signal — Opus is the standout for cubic-space-visualization performance refactors (one-pass, error-free, exceeds expectations); K3 matched Opus's "catches real errors, not just verifies" quality level immediately on its first design-corpus dispatch
metadata:
  type: feedback
---

**2026-08-04, user's direct assessment across two different dispatch threads.**

- **Opus's standout area: cubic-space-visualization performance upgrades and
  refactorings** — user's exact framing: "each always one pass and error
  free, and with better results than hoped for." **Confirmed citation**:
  commit `492b55ff4` ("Upgrade cubic topology visualization to v14 with
  independently controllable layers", Wed Feb 11 2026), commit message
  states "Opus 4.6 generated" directly — 6-12 FPS baseline → 15-60 FPS,
  layered/independently-controllable rendering architecture, both
  `.refactored.html`/`.optimized.html` variants of
  `grid-v14-layered.*.html` landed in this single commit
  (`data/web-root/vhosts/visual.v7.ax/`, archived copies in
  `data/asc/what-AI-thinks/html-form/visualizations/cubic-space/`).
  `f751626bf` afterward was a pure directory-consolidation rename (0-byte
  diffs, not further perf work); `fc5e7c09b` (Sat Jul 25, "fix stale
  v13.7.1 reference, dead CSS, pinkish color cast") was unrelated
  copy/CSS cleanup on the wrapper page, not perf work either. An earlier
  version of this memory entry guessed `4d0d86a2d`/`189ba03c2`
  (`persist-cube` indexing perf fixes) — that guess was wrong, corrected
  here after the user pointed at the real starting commit. **User's
  added emphasis**: this was Opus's *first contact* with this
  visualization — no prior warm-up pass, no earlier failed attempt on
  this file — and the ~10x peak FPS gain (6→60 FPS ceiling; 12→15 FPS
  floor) landed on that first pass.
- **K3, first outing on a design-corpus complement dispatch** (see
  [[project-epoch-orbital-harmonic-math-2026-08-03]] and
  `data/tasks/k3-design-corpus-complement-2026-08-04.md`): matched the
  "actually disagrees with prior work when warranted, not just rubber-stamps"
  quality Opus had already established — caught a real headcount error in
  `recurring-cube-number-collision-audit.md`'s own "error found" verdict
  (missed a fourth corpus source), on the first dispatch, no ramp-up needed.
  User's correction, important: Opus did this kind of catch *first* — K3's
  notable trait isn't novelty of the catch, it's reaching that bar
  immediately rather than needing several rounds to get there.
- **K3's rounds feel similarly bug-free overall** (user's framing), which
  the user reads as net *token-efficient* despite K3's real per-token
  premium — input $3.00/1M, output $15.00/1M (~3.75x K2.7's $4/1M output;
  see [[project-kimi-k2.7-vs-k3-tier-economics]] for the full breakdown) —
  because fewer retry/correction rounds offsets the higher per-token cost.

**how to apply**: when routing dispatch work —
- performance-shaped refactors on the cube/voxel/index visualization code:
  default to Opus.
- open-ended design-corpus consolidation/triage/adversarial-check work:
  K3 is validated as a genuine third perspective alongside the existing
  Opus-verify/Fable-consolidate pipeline
  ([[feedback-esoteric-research-verification-pipeline]]), not merely a
  cheaper stand-in — safe to hand it real complementing work, not just
  overflow.

#,,,,,..,,..,,,..,..,,,,,,.,,,,..,,.,,.,.,.,,,.,.,...,...,,..,,.,,..,,.,,,.,,,
#EUVBCMCI26CAAWNVIA56UUPQE5FPNKIUVKFDG4FV42YUE2UXDAU6GXWX2MPWMTP3QGCPZOH4Y5U76
#\\\|27CX23AG5N5KGMF3ONN7C2GUDH6AHFN4J4WBUGC5VRAMSDTO3KI \ / AMOS7 \ YOURUM ::
#\[7]CHQGLZBZGAMQLRISD7D4RJQTWKS5PEBM2WJ6QPTDO2TM7QDAZKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
