---
name: feedback-dont-preempt-version-bump-before-commit
description: never run bin/dev/update-version manually before a commit to preempt the pre-commit hook's version-mismatch gate -- it forces a second, redundant signing pass
metadata:
  type: feedback
---

Never run `./bin/dev/update-version` manually before `git commit` just because you expect the
pre-commit hook to block on a version mismatch. Let the hook trigger the version bump itself
during the commit attempt.

**Why**: found during the v7 -> v7-zenki identity rename (commit `23a0e8d53`). The first
`git commit` attempt was blocked by the hook's version-mismatch check, so the assistant ran
`bin/dev/update-version` manually and staged the resulting files itself. This produced unsigned
version-bump files, which then failed the hook's signature check on the *next* commit attempt,
requiring the user to run their signing tool a second, redundant time. User: "version was already
updated, you only force redundant re-signing that way.."

**How to apply**: if a `git commit` attempt fails on a version-mismatch gate, just report it and
wait -- do not run the suggested fix-it command yourself. The hook itself stages the version-bump
files as part of its own commit-time flow when left alone; running the fix command out-of-band
front-loads unsigned content that then needs a whole separate signing round with the user's tool.
This is a narrower instance of the established git/signing workflow already in force this
session: the assistant stages and verifies, the user signs with their own tool, the assistant
runs `git commit` -- never runs fix-it/signing tooling on the user's behalf mid-flow.

#,,..,...,,,.,.,.,.,.,..,,..,,,..,,.,,,.,,..,,..,,...,..,,.,,,,.,,,..,,,.,,,,,
#JNBE676BU6NGUQY2HX5CVT3AG3KFLU6TCXOOPD4VOYKHVRYOXQRPHSB4JPB2DD4TNGON4WUB7CEXM
#\\\|GPHTNFAD3DPK4R4SB4SZ3DHCMXFSYS6IDFRBCTQ7QDA4SC3PA4K \ / AMOS7 \ YOURUM ::
#\[7]OSAEF2RX3X2SQ2EJDZUUDTSTDO6URNOREGTNJTILVUH24ONTLGDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
