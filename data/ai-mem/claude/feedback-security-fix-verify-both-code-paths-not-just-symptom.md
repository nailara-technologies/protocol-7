---
name: feedback-security-fix-verify-both-code-paths-not-just-symptom
description: when a shared primitive gates both a functional bug AND a security property, fixing the symptom (broaden the check) can silently remove the security property on a different call path that relied on the same check for a different reason -- caught 2026-09-17 by the user before shipping, not by me
metadata:
  type: feedback
---

Working [[bug-v7-zenki-get-children-registry-gap-2026-09-17]]: found that
`base.exists.sub-process`'s `waitpid`-based liveness check could never see
a grandchild pid (a coding-zenka's own spawned `llama-server`), because
`waitpid()` only works on direct children. My first proposed fix was to
broaden the check (swap to a same-UID `kill(0,$pid)`-style liveness test)
everywhere `get_children` used it.

**The user caught a real security regression in that proposal before I
implemented it**: `get_children` actually has TWO code paths sharing that
same liveness primitive for genuinely DIFFERENT reasons. One path (the
`Proc::ProcessTable` walk) has its own independent, kernel-sourced
ppid-ancestry check backing it up -- there, the liveness check really was
just filtering stale pids, safe to broaden. The OTHER path
(`instance_child_pids`-based) has NO independent ancestry check at all --
it just trusts a zenka's self-reported claim outright, and the narrow
`waitpid` semantics ("must be YOUR real kernel-verified child") was the
only thing standing between that self-report and being treated as fact.
Broadening the check uniformly would have let a compromised/buggy zenka
self-report an arbitrary foreign pid and have it accepted once merely
"alive" -- exactly the failure mode `waitpid`'s stricter semantics existed
to prevent on that path.

**Why this matters generally**: a shared low-level check (liveness,
existence, permission) can be doing more than one job across its callers
even within the SAME function. Fixing the job that's visibly broken by
loosening the check can silently disable a DIFFERENT, non-obvious job the
same check was doing elsewhere -- and that second job not being covered
by any test or symptom means nothing will visibly complain when it breaks.

**How to apply:** before broadening or replacing a shared gating check
(liveness/existence/permission/auth), enumerate every call site that uses
it -- not just the one with the visible bug -- and ask what EACH site is
actually relying on the check FOR, not just whether the site currently
works. If a call site has no OTHER verification backing it up, the shared
check may be load-bearing there for a reason that has nothing to do with
the bug being fixed. Scope the fix to only the call site(s) that actually
need the broadened behavior, exactly like
[[bug-v7-zenki-get-children-registry-gap-2026-09-17]]'s eventual fix did
(a new, narrowly-scoped helper for one loop, the shared primitive and its
other 18+ callers left untouched). This generalizes
[[feedback-fix-immediately-reduces-cognitive-load]]'s "fix at the root"
principle with a caveat: fixing at the root still requires understanding
everything currently anchored to that root first.

## related

[[bug-v7-zenki-get-children-registry-gap-2026-09-17]]

#,,.,,,,.,,.,,,,.,,.,,,.,,.,,,,.,,,.,,,,,,..,,.,.,...,...,.,.,,.,,,,.,,,,,,,.,
#RNP5MWPW7X5KHEPV223OY3ZRB2RY3EUODU3YSOH6G5B7VVP27UIOS5IMKCQ2FH5FU2MK26D53JFWE
#\\\|ZQZIUISI6T57JS4CUIFOK44LWZORRZE6ZJLBZG5QFJALMGDKTM4 \ / AMOS7 \ YOURUM ::
#\[7]XIXQHOJNTMV3YYNAWBW665PPCHZIA6VFVRB7L2YRS3QTDJHZJSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
