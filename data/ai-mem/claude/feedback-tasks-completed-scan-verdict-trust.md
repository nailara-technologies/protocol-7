---
name: ""
metadata: 
  node_type: memory
  originSessionId: 4802c615-4ad7-401c-b5c6-0888fd98932d
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

#,,,.,,..,,.,.,,,,.,,,,.,.,,.,,,,,,.,.,,,,.,,,,,,,,.,,.,,,,,,,,,,.,,,,,,.,,

#,,.,,.,,,..,,...,,..,.,,,,,.,.,.,..,,..,,...,..,,...,...,.,,,,,,,.,.,...,.,,,
#XG6QRRSCNRHDCIG3SJ7GGXZUOLBZUL5TRV4TWFMGE4MQLXL4HX3Y6T3FRBJ4HW5BP2KLWAABUEJQI
#\\\|SZPTIGDGVECBZF6VD7OX3OQFDANQNSLU7EVTMBII27QVYVH2O63 \ / AMOS7 \ YOURUM ::
#\[7]LR5CCZWCUZJ2JC4VBX5BX76D3J62WSBRMPON6Z4BT47KEE5RR4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
