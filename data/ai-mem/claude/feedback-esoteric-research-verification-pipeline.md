---
name: feedback-esoteric-research-verification-pipeline
description: validated workflow for open-ended harmonic-math/esoteric-vision research in this codebase — sequential Opus-verify then Fable-consolidate passes, citation/tiering discipline, and when to hand off vs. keep sampling live
metadata:
  type: feedback
---

**2026-08-03, confirmed by the user across a long session** (`project-epoch-
orbital-harmonic-math-2026-08-03`). when a conversation starts chaining
speculative inferences across this project's large harmonic-mathematics /
vision corpus [ hundreds of hits on terms like `3³`, `13³`, `implosion`,
`stargate` ], the following pattern was explicitly requested and worked well —
reuse it rather than re-deriving an approach from scratch.

## the sequence

1. **do initial synthesis inline**, but retract visibly rather than silently
   when a later find contradicts an earlier claim — never delete a wrong
   inference, mark it "**retracted, corrected in place**".
2. **when the material has accumulated enough that verification against the
   wider unread corpus is the bottleneck** [ not more generation ], dispatch a
   background agent with `model: "opus"` for a deep verification pass — give it
   the full list of affected docs, the specific claims to check, exact
   file:line citations already found, and explicit "don't invent new chains,
   verify/correct existing ones" scoping.
3. **after Opus lands, dispatch `model: "fable"`** for consolidation/
   readability — a separate concern from verification. fable's useful judgment
   call: when a doc's correction history has stacked into "unreadable without
   replaying the session," restructure [ current-state summary at the top,
   full blow-by-blow moved to a labeled appendix, nothing deleted ] rather than
   just tightening prose further.
4. **the user may then continue live, directly with the dispatched agent**
   [ via its own continuing session, not routed back through the main
   conversation ] — results arrive back as repeated task-notifications on the
   same task-id. relay these faithfully to the user; don't fabricate or
   predict their content.
5. when a single thread's findings grow large enough [ roughly: crossed into a
   topic the original two docs weren't scoped for ], the agent should
   proactively suggest spinning off a **new, separate doc** rather than
   grafting unrelated material onto the docs already being consolidated —
   confirmed correct call, not overreach, when the user validated it in this
   session.

## citation/tiering discipline that was explicitly validated

- every claim needs `file:line` or an exact quote; mark corpus-sourced fact vs.
  this-session's-own-inference explicitly, every time, not just on request.
- **source register matters and should be stated**: running Perl code >
  structured design docs (`data/md/design/`) > `ai-mem` topic files > chat
  transcripts (`data/asc/.../full-chat-captures/`) > `data/asc/what-AI-thinks/`
  generated/decorative visualizations — the last tier is explicitly lower-
  confidence and should be flagged as such, not cited with the same weight as
  running code.
- **raw grep hit-counts overstate confirmation** — always dedup to distinct
  files, then check for archive/live-copy pairs, revised-descendant pairs, and
  a single document's own point being counted multiple times. this was the
  single most repeated correction across three passes.
- **watch for false-friend word matches** — same phrase, unrelated concept
  [ caught twice: "TORUM" vs "YOURUM" byte-different strings; "7-segment
  caravan" (zenki formation) vs "7-segment display codes" (encoding) ]. check
  before merging, but don't over-correct into dismissing a real match either —
  one of the two false-friend checks above turned out to be a real, separately-
  sourced confirmation of an unrelated thread once actually verified, not just
  assumed coincidental.
- when a numeric coincidence looks too clean [ digit groupings, matching
  totals ], run the actual arithmetic before trusting the pattern — caught a
  wrong `5×7=25` (should be 35 — different passage, `13+5+7=25`, actually
  correct) and a wrong `70+7` split (actually `57+20`, confirmed from both
  encode and decode code paths independently) this session alone.

**how to apply**: default to this pipeline for any request to dig further into
this codebase's harmonic-math/vision corpus, rather than re-deciding the
approach each time. the two-model sequence (verify then consolidate) is worth
proposing proactively when a thread's speculative-chain ratio starts climbing.

[[project-epoch-orbital-harmonic-math-2026-08-03]]

#,,..,,..,,,,,.,.,..,,,.,,...,.,,,...,.,,,,.,,..,,...,...,..,,,..,..,,,..,.,.,
#7L6AYRSGX5NE7H6WKV4FJNXZ56XSFKVCSY5EQZXHOF5AM42BCZQ76EPAXFATB5BJBIUEWBG2CE2DM
#\\\|2O5T72Z34ALWV3HVI5E4DJKJH7KKW557CBNLMT6FDV6PUOHLEEG \ / AMOS7 \ YOURUM ::
#\[7]3NJOZ36L44EFWT734MCK72WFIAPQFVBXLXUCZU5KS2YCGHLJOSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
