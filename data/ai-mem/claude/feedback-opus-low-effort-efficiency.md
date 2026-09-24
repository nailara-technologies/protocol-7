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
[ 21 modules, caller enumeration, offline sim, 45995da5b ] for 6 of 100
promo credits and passed all five live checks first try.

**Why:** the costly failure mode in this project is the plausible-but-wrong
fix that must be reverted [ d3c07acee ], not shallow per-step reasoning.

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

#,,,,,...,,..,,..,...,,,.,,..,,,.,,..,.,,,,,,,..,,...,.,.,.,,,,.,,...,,..,,..,
#WBBXC4DPTBLI4IZ462X3W7DMOTUZAPFVJL6RYLO53FJ2MXIAVV57AGXADAHV4YVRK65EFFNANOC4E
#\\\|AOGTADMXGFR54CC3CY3VU2GNFQXNEWB5SHTH2EHNTAYHGGLSU7A \ / AMOS7 \ YOURUM ::
#\[7]KNGKUK4PULYSYFAW4K272L7ATKAF44N7KUN2NLP2ZJNP6LJWA4AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
