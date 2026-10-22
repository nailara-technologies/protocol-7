---
name: feedback-llm-fix-regressions-pattern
description: four regressions in one night [ 2026-09-30 ] all came from earlier LLM fixes that assumed "this is the single choke point \ the only case" in a generic system -- how they were found, and the rule for new fixes
metadata:
  type: feedback
---

found 2026-09-30 : `94f90886f` [ log request into one-shot init_reports ],
`4b905ee4c` [ resolve hook inside the pure dependency.ok ], `b8f2fe3a2`
[ latency outliers at level 1 ], plus an old never-built "check if already
online" in v7-zenki's own log branch. common shape : a fix for ONE observed
case changed a generic path [ base.*, dependency.*, a shared handler ] on an
assumption about its callers that was false -- "single choke point every
start path funnels through", "the flush comes after the entry". the original
race usually came from LLM code acting outside its context [ sending before
the zenka is online ], and the "fix" moved the failure instead of removing it.

**Why:** the user, after the second one : "that needs the root cause exactly
identified.. compared to bending generic systems around it while still not
knowing what is happening". two of my own quick fixes that night were
rejected for the same reason [ flushing init_reports from the log code,
starting generic changes before explaining why other zenki worked ].

**How to apply:**
- before changing a generic path : list ALL its callers and what each needs
  [ pure check vs. action ] -- see [[security-fix-verify-both-code-paths-not-just-symptom]]
- find the exact cause first : measure the order [ level-2 lines, `p7c
  localtime <ntime>` ], compare with a zenka where it works [ mod-test is the
  free test zenka ], then `git log --follow` the path for the commit that
  introduced it and read its message for the assumption
- read the fix history of the path for storm \ race fixes a change must not
  undo [ e.g. 5a16981ce, the log storm fix ]
- test every scenario type the history names, not only the reported one
- one-shot mechanisms [ init_reports, callbacks.initialized, verify-instance ]
  are the usual trap : anything queued after they fired is silently never
  processed. [ start.cfg changes not applied on a v7-zenki reload look
  similar, but the files ARE re-read -- cause open, see
  data/tasks/v7-zenki-start-setup-runtime-reload.md ]

#,,.,,,,,,,,,,,..,,..,.,.,..,,.,.,,..,...,,.,,..,,...,...,...,.,.,..,,,.,,,,.,
#B6LZOQRNUDV6IDQANRO7DVCVA72YZWNGLJUDKQTSVVMEEN7SMYWUHXASM3LHDDUG4DTQHUU5IYHNY
#\\\|DX4AYZQF6RIQYAPREOTXJIDDCVXBR4GHMT3I6IFM2TQOJLMKU3H \ / AMOS7 \ YOURUM ::
#\[7]4PBPLZKMLIK57QG57ZNZ7YD6BHFJSHVNIFXVNUPNGMXG7WPLDCAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
