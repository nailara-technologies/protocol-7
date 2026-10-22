---
name: feedback-verify-bug-still-open-before-scoping-dispatch
description: "when extracting a scoped kimi/claude dispatch task from an older task doc's 'still open' section, check git log for later same-day commits before trusting the doc's own last-recorded status -- a bug can be fixed the same day it's filed with the doc never updated"
metadata:
  type: feedback
  originSessionId: b6c2a1fe-37b8-4649-b925-a7b50632b435
---

Wrote `data/yaml/coding-tasks/cred-mesh-transport-subscription-and-base32-gap.yaml`
(2026-09-05) by re-reading `data/tasks/cred-mesh-rotation-subscription-
cross-zenka.md` in full and extracting its still-open tail ("bug 5,
undiagnosed" + a stale-subscription symptom) into a scoped dispatch. Did
the right check for the OTHER four bugs in that file (confirmed FIXED via
git log before trusting them) but skipped it for the two "open" items,
trusting the doc's own final wording at face value.

Kimi's dispatch result: both were already fixed the same day they were
filed — commit `8c74b5d83` (2026-07-18) closed bug 5 literally hours
after it was written into the doc, and the stale-subscription symptom
was closed by the same day's `proxy.init_code` zenka-guard fix. The
doc's tail was just never updated to say the retest afterward passed.
Independently verified afterward (`git show 8c74b5d83`, re-ran
`bin/dev/cred-mesh-test` myself, both matched kimi's claim) — the
dispatch cost real kimi quota re-deriving something `git log` would have
shown for free.

**How to apply:** before writing ANY scoped dispatch task from an older
doc's "still open" / "undiagnosed" / "not yet fixed" section, run
`git log --oneline --all --since=<the doc's own date> -- <files that
section names>` (or grep commit bodies for the bug's own distinctive
terms) to check whether something already closed it after the doc's
last edit. The same diligence already applied when judging whether an
entire task file is DONE (`bin/dev/task-scan-candidates`, see
`[[project-2026-09-05-task-archiving-and-kimi-dispatch-queue]]`) needs
to extend to individual still-open sub-items inside a file being kept
active, not just to the file's overall status.

#,,,.,..,,,,,,,,,,.,.,,,.,.,.,.,,,,.,,...,...,..,,...,...,,..,,.,,...,...,.,.,
#QLKPAUKPNXEQPUSQDHY5ZDHAICS6DAO6AOHAN75WSIWCGCTVE5NQWJYWPAAFJBRJYPZ3N3AU2KMX2
#\\\|3CLFUW2ZH4YC2P3CMACL3HWQJEGGJKLC27BVK6AT3GJYEEUGZZ7 \ / AMOS7 \ YOURUM ::
#\[7]BNHW4GVCFW27EMUMYNNV6Q2GL7C5BV2WD33VP44LPR5KIIKFACDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
