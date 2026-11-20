---
name: feedback-new-module-whitelist-and-resign-version-files
description: 2026-10-29 twice : a NEW module in a whitelisted zenka needs bin/dev/gen-sub-whitelist <zenka> [ p7_sign plan:true did not add it ; reload source hides the gap, a restart exposes it ] ; a second sign run for the same commit must include the 3 version files or the hook refuses
metadata:
  type: feedback
---

**1. new module -> regenerate the zenka's whitelist.** zenki with
`cfg/zenki/<zenka>/subroutines.load-early` load ONLY the listed subs at
start. `jobsite.sync.push_soon`, `jobsite.handler.sync-soon` [ 534158f66 ]
and `base.reply.value` were missing -- pri ran fine only because
`reload source` loads past the whitelist ; the next jobsite restart would
have made trash \ rescue \ the depth reply call undefined subs.

**Why:** `p7_sign plan: true` [ bin/dev/p7-commit-plan ] did not pick up
the new modules, and the live check after `reload source` passes.

**How to apply:** after adding any src/ module, run
`bin/dev/gen-sub-whitelist <zenka>` for every zenka that calls it, and
put the regenerated load-early file in the SAME sign run. a deploy check
must not rely on `reload source` -- `git diff` the load-early file.

**2. re-signing within one commit takes the version files along.** the
first sign run with `version: true` signs src-ver + README.md +
source-code-versions.md ; a later sign run for the same commit that
leaves them out invalidates them [ pre-commit : 'no signature present ::
cfg/protocol-7.src-ver' ]. a follow-up run lists ALL staged signed files,
without `version: true` [ no second bump ].

**3. never pass an unsigned file to p7_sign** [ 2026-10-29 ] : data/web-root html went into a sign run [ 22bf971f0 ] and got a signature footer after </html>. stage unsigned files yourself ; to undo : `bin/Protocol-7 sourcecode strip-signature-footer <file>`. a commit holding ONLY unsigned files still needs a version bump : a sign run on cfg/protocol-7.src-ver with version true

**4. an aborted sign run leaves files signed** [ 2026-10-29 ] : the next run reports them as needing no action AND does not stage them -- bde5b4bdb shipped without 3 of its files. check `git show --stat HEAD` before every push ; stage such files yourself. also : pre-commit refuses a `# descr` over 55 chars, only a NEW file shows it

related : [[use-format-code-not-perl-c]],
[[reload-success-doesnt-guarantee-new-file-loaded]]

#,,,,,,.,,.,.,,,,,...,...,,..,..,,,.,,...,.,,,..,,...,...,,,.,,.,,..,,.,.,,..,
#A3XBUYVIHWDWJUF2MHOKZQ45MGRSYTPXAOZQNNS4QMIEQTMXP2VWSYRRU6PRUAZBVBWHAY5FVPJ2I
#\\\|QR5HYNUCTQ234MURTT5I62RL5S3CPYBYUYKOEKOJDMIZ3SVD4JD \ / AMOS7 \ YOURUM ::
#\[7]AAGUY5CL2M4QOL77HRYQO42UR7UGDHU7UORMN4EKUNJMG3J5WYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
