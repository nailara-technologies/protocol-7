---
name: reference-mcp-sign-commit-workflow
description: 2026-10-30 : signing + commits go through the protocol-7 mcp tools [ p7_sign \ p7_sign_status \ p7_commit_prepare \ p7_commit \ p7_commit_status ] ; signing talks to p7-signing-agent
metadata:
  type: reference
---

since 2026-10-30 the owner's workflow : request signatures with `p7_sign`
[ status : `p7_sign_status` ], prepare commits with `p7_commit_prepare`,
commit with `p7_commit` [ status : `p7_commit_status` ]. p7_sign connects
to the new p7-signing-agent.

**checked in bin/mcp-server-p7 + bin/dev/p7-commit-plan [ 2026-10-30 ]** :
- p7_sign `op` decides the version bump : new = bump, amend \ amend-message
  = none, reset [ data/md/design/COMMIT-MANAGER.md ] ; `version=true` is the
  op-less form. the bumped files join the same sign request
- p7_sign `plan=true` runs `bin/dev/p7-commit-plan -apply` first : derives
  the needed steps from changed files [ module add\del\rename -> sub-list +
  dep-graph ; <[call]> set changed -> dep-graph ; gen-sub-whitelist per
  zenka ; amos-versions + format-code reported, run by update-signatures ].
  dry look : `bin/dev/p7-commit-plan [ -json ] [ paths ]`
- order : p7_sign [ same op ] -> p7_sign_status -> p7_commit_prepare
  [ binds a checksum of the STAGED diff ] -> p7_commit -> p7_commit_status
  [ 'stale' if staging changed after prepare ]

**How to apply:** use these tools instead of the older hand-run sign \ commit
steps. the user still approves each sign in the p7-sign-agent terminal [ y \ n \ d ] -- that approval is the per-commit sign-off ; still re-check
staged content [[feedback-amend-env-and-unsigned-files-staging]].

#,,,.,..,,.,,,..,,,,,,,,,,,,,,,..,,,.,,,,,.,,,..,,...,..,,...,...,.,,,,,.,,..,
#DXVD7MOXPQJQPTLAOO7IZJWR5E5XMCB4KGBES3QIUSA3YO7BRFGOFVWDRIBPUD7KALKLEBZ5T747S
#\\\|24UVP5TMTC3SPGLN2GKYFFIHD3C3LUFRYJ3AUWJWGZDNSG3Y2RP \ / AMOS7 \ YOURUM ::
#\[7]YZWHZ7ROHBCZKLCTKY7YJW4BFJAMNWSHQMHR5VSWIUJRHCFWUKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
