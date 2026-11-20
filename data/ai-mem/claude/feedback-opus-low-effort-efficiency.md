---
name: feedback-opus-low-effort-efficiency
description: user finds Opus 5.5 at LOW effort more efficient overall than Sonnet at medium/high -- correct-first-time beats extra reasoning ; keep it, pair with fast feedback and written briefs, fresh session + handover when context grows
metadata:
  type: feedback
---

2026-09-24 : this session and a separate web session both ran Opus 5.5 at
low effort. User's assessment : more efficient than prior Sonnet sessions on
medium or high -- far fewer research rounds and corrections, gets things
right first time. The web session did the whole token-based backend lock
[ 21 modules, caller enumeration, offline sim, 928bc0df6 ] for 6 of 100
promo credits and passed all five live checks first try.

**Why:** the costly failure mode in this project is the plausible-but-wrong
fix that must be reverted [ d457519dc ], not shallow per-step reasoning.

**How to apply:**
- low effort is the default ; it works because of fast feedback [ live
  checks, fixture harnesses, user review ] -- keep verification tight
- a written brief [ problem, history, callers, constraints, live checks ]
  is what makes low effort sufficient for big tasks ; see
  data/tasks/coding-backend-lock-tokens.md as the template
- raise effort only for open-ended diagnosis without a brief
- as context grows, prefer a fresh session + handover over raising effort
- split : Opus web for design-heavy/correctness-critical, kimi k2.8 for
  mechanical well-specified work, local session for live-zenka verification
  [[feedback-token-budget-pacing-early-week]]

#,,..,...,,,.,,,,,.,,,..,,..,,,..,.,,,.,.,,..,..,,...,...,,,.,.,,,,..,,,.,...,
#52KQT7RVBRTWNS4KNQHRKPEMNNGY6CBHILEPPFAQ542DRKNO5HS5RNJCWZ57AQMWOWGQ24KANR7WA
#\\\|JDQE24ZLUD3DVFBWHK25AOHHD46HBQJIGWXL5JHK7ZE2KKXBKAC \ / AMOS7 \ YOURUM ::
#\[7]BT2H3SL5ZGCRNH4CK355OSAGURU2L6VSMBL4LXQZG3TKPKUTVMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
