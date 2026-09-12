---
name: feedback-dont-preempt-version-bump-before-commit
description: SUPERSEDED 2026-09-12 -- the hook does NOT auto-bump; running bin/dev/update-version yourself on a version-mismatch block is the correct, expected flow
metadata:
  type: feedback
---

**Superseded 2026-09-12.** This note originally said never to run `./bin/dev/update-version`
manually and to just wait for the hook to bump the version itself during commit. That premise
does not match this repo's actual current pre-commit behavior: on a version-mismatch block, the
hook does NOT bump anything itself -- it prints `suggestion : run ./bin/dev/update-version to fix`
and stops, requiring exactly that manual step before retrying the commit. Confirmed live,
2026-09-12, twice in the same session, both times expected/unobjected-to by the user (one of
which they explicitly told the assistant to run it: "updated, you can commit and push it too").

A second, separate signing pass is unavoidable either way once `update-version` runs (whoever
runs it) -- the version-bump files it writes are unsigned regardless, and always need the user's
signing tool before the next commit attempt. That cost is not something running it manually
adds; it was never avoidable by "waiting for the hook" in the first place, at least not as this
hook currently behaves.

**How to apply**: on a version-mismatch pre-commit block, run `./bin/dev/update-version` directly,
then ask the user to sign (`update-signatures`) before retrying the commit -- same flow as any
other unsigned-file block. Do not resurrect the old "just wait" advice without first checking
whether the hook has actually started auto-bumping again; if it starts doing so, this note's
premise would need re-superseding once more.

#,,,.,.,,,.,,,...,.,,,,,.,,.,,,.,,,.,,,.,,,.,,..,,...,...,.,.,,,.,.,,,.,,,,..,
#VCDK4LEHE5EZBP5XKJRLZHOHXQKVR37RZOYOWT4ONDMI4W4CGGZD4VEGZLBDA67EON6TAPPPHLZE4
#\\\|4ZWHOFRATGVDBZP3CICGAZYLVF4VFKUXUWWFQS4E6W4X6WSUXUH \ / AMOS7 \ YOURUM ::
#\[7]ZPAWZ6A25MOWHGZAWSJN3U2JON65TH7XQV7HEJJRII2H3776T2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
