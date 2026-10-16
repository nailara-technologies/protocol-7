---
name: feedback-verify-push-landed-before-deploy
description: 2026-10-16 : the user said "go ahead" before pushing ; I tore down all four servers on the old code. before any pull-git + teardown, `git fetch` and check @{u} is the commit to deploy -- and gate the teardown on the server's own head
metadata:
  type: feedback
---

the servers pull from the hub, so a deploy depends on the user's push.
2026-10-16 the user answered "ready, go ahead" to the deploy plan while
the push had not happened ; I ran pull-git + teardown on all four and
restarted every zenka on the unchanged code [ harmless that time, but an
avoidable full restart of four servers ].

**Why:** "go ahead" approves the plan, not the precondition ; the push is
an outward step the user does themselves.

**How to apply:** before a deploy run `git fetch` and compare `git log -1
@{u}` with the commit ; and inside the remote script refuse the teardown
when the pulled head is not the expected commit [ `[ "$H" = "<sha>" ] ||
exit 1` ]. a change that only touches standalone zenki [ p7-keys ] needs
a pull only, no teardown. related : [[feedback-changed-established-behavior-silently]].

#,,,.,,,,,.,.,.,.,,,.,,,.,,,.,.,,,,,.,..,,.,.,..,,...,...,,..,.,.,.,,,.,,,.,,,
#O7U3O2WWO2WBATOV7S3343W6QWD6EF4E2NSARRTQLUUVNC4RPKSOITAC7QOU4LBQKYOVMLEHAA6R6
#\\\|D37P7BSPQKNEOCC35HVQ5KZUTH235KFYNNMR4ZTMTSVC32UWAKJ \ / AMOS7 \ YOURUM ::
#\[7]TFDITMYGUDJWKNS6Y2WV52JFUB7Z7ZTLIPSTY5WDWHNWSRBPJMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
