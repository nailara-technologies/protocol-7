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

**Broader than batch-scan verdicts (2026-08-25)**: the same distrust applies
even with no automated scan involved at all — task docs just organically go
stale after the work lands, because nobody circles back to update the status
line. Found **six** separate instances in one session, purely from
independently re-verifying task docs against `git log`/`grep` while doing an
unrelated review: `task-zenka-cold-queue-gpu-cooldown-trigger.md` (said
"planned, not started" — feature shipped same-day, commit `c54c91c4c` +
threshold-tune fix `e1c3f6b2d`), `inline-subs-batch-misc.md` and
`perlmod-move-confirmed-refactor.md` (both fully landed, zero status update),
`base-parser-list-width.md` (fixed 2026-06-09 in `c54c255c7`, doc never
touched again), plus two `data/yaml/coding-tasks/*.yaml` docs —
`user-edit-address-cluster-plugin.yaml` (still read "DESIGN DRAFT, not yet
implemented" despite a full implementation + six polish commits) and
`users-zenka.yaml` (said "phase 2 not yet built" despite `cb38cdc90`
shipping it — this one also surfaced a genuinely real remaining gap, not
just a stale line: TOFU peer-validation still missing, flagged in the
code's own header comment).

**How to apply, generalized**: never trust a task doc's own stated status —
whether it came from an automated scan or was just hand-written months ago
— without independently checking `git log --oneline --all --grep=<topic>`
and/or grepping for the described functionality in `src/`. This is cheap
(a few grep/log calls) and catches real, load-bearing inaccuracies, not just
cosmetic staleness — the `users-zenka.yaml` case shows a stale doc can also
be hiding a genuine unresolved TODO underneath the wrong headline claim.

#,,.,,,.,,...,,,,,,..,,,,,.,.,,,.,,,.,,,.,..,,..,,...,...,,,.,.,.,...,.,.,,..,
#VCP4TE332EJ3UT43SSEKSY2FEAFPU726AOGGUTC62MMYG55KRYQZQXPO465BOPNYXGEZCFGCTK3GW
#\\\|3YO4HYABEZ35AGUCAWV3OAQOVFIOAF2YHFZC6R6ECYHSKDV26C6 \ / AMOS7 \ YOURUM ::
#\[7]QMPBE2BPQI2SRA5M4IZSSQUMAVCOWOLPDRHQMW2TRBOXQ7X6N6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
