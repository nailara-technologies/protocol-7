---
name: tasks-completed-scan-verdict-trust
description: "'still open' batch-scan verdicts are as unreliable as 'move to completed' ones — spot-check both"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

Don't trust a "still open" verdict from the tasks-completed batch scan
(9B local model, or a fast kimi pass) just because it's the *safe-sounding*
answer. The scan's own doc (`data/tasks/SESSION-STATUS-tasks-completed-scan-resume.md`)
already says "do not trust the model's verdict alone" for "move to
completed" — but on 2026-07-16 the same distrust turned out to apply
equally to "still open": a round-1 scan wrongly marked all three files in
the jobsite-ui trio (`jobsite-ui-reassess-button.md`,
`jobsite-ui-interviewed-tab.md`, `jobsite-ui-flexible-export.md`) as
still-open with "no matches found" — all three features were live,
working, and in daily use (user caught it by testing the actual UI). Root
cause each time was a bad/too-narrow search pattern, not absent code.

**Why:** an LLM batch-scanning `data/tasks/*.md` against a large codebase
is doing a negative-existence claim ("I searched and found nothing") —
those are exactly the claims most vulnerable to an incomplete grep pattern
or wrong directory, and there's no natural skepticism trigger the way
"move to completed" has (that one already carries an explicit
re-verification rule).

**How to apply:** when a "still open" verdict looks surprising — especially
for a feature the user might actually use day to day — spot-check it the
same way as a "move to completed" verdict: grep the actual UI/module files
yourself or ask the user to test it live, don't just accept the negative
and move on. This applies to any future round of
[[coding-zenka-improvement-pipeline]]-adjacent scanning work, not just
this specific backlog.

**Massively confirmed 2026-07-17**: a single spot-check of one "still
open" verdict (`web-browser-input-capture-replay.md`, rated "no matching
code found" despite being fully implemented across 5 real commits that
same session) led to dispatching an independent K2.7 re-verification of
all 52 remaining "still open" items from one scan batch. Result: **31
false negatives** — 22 fully complete, 9 partially complete with named
gaps. One of the fixed gaps (`web-auth-plugin.md`) was a live security
issue: a write endpoint (`/jobs-sync`) that the task explicitly required
gated behind auth had never actually been gated, and sat that way
undetected until the re-verification caught it. A ~60% false-negative
rate on "still open" is not a one-off — treat every batch-scan "still
open" bucket in this repo as unverified by default, not just spot-check
the surprising ones.

#,,,.,,..,,.,.,,,,.,,,,.,.,,.,,,,,,.,.,,,,.,,,,,,,,.,,.,,,,,,,,,,.,,,,,,.,,

#,,.,,,..,,,.,,,,,...,,,,,.,.,,.,,,..,...,...,..,,...,.,.,..,,,.,,,,.,,,,,,.,,
#5I5VASH555ZMVMQKONYAYJ5ILVI3RKFLE2JODV4BFQ2PLVQIDAQTJJSM3345NQMLZ6ZMGPSB2GZ72
#\\\|R6RMOFKYNNKZT6YIAHUH26Z6GSXAN4J2CYWICQC2KEB4IIJVYJO \ / AMOS7 \ YOURUM ::
#\[7]JNKL4OEYNS3ECFVZB2DM7NQIK57IINTCADWKTNAMC6BEXR756GBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
