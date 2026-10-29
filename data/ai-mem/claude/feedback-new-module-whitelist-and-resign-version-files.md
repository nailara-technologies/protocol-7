---
name: feedback-new-module-whitelist-and-resign-version-files
description: 2026-10-29 twice : a NEW module in a whitelisted zenka needs bin/dev/gen-sub-whitelist <zenka> [ p7_sign plan:true did not add it ; reload source hides the gap, a restart exposes it ] ; a second sign run for the same commit must include the 3 version files or the hook refuses
metadata:
  type: feedback
---

**1. new module -> regenerate the zenka's whitelist.** zenki with
`cfg/zenki/<zenka>/subroutines.load-early` load ONLY the listed subs at
start. `jobsite.sync.push_soon`, `jobsite.handler.sync-soon` [ fc2ea1712 ]
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

related : [[use-format-code-not-perl-c]],
[[reload-success-doesnt-guarantee-new-file-loaded]]

#,,.,,.,,,..,,,,,,,.,,,,,,..,,,..,...,.,,,.,.,..,,...,...,,.,,,,.,,.,,...,...,
#EQJ6ICPVA67RFKYUJOVQPPSWZU54PA6HJTUVTPAWJX6RDABONS2YFNDVOIMD3HKNA3OUK4YMFVO4A
#\\\|IDVN73LCNC3MNKTTN5SA6B6R2VI43F4OQRLO4I6B5SRB3UQ7J56 \ / AMOS7 \ YOURUM ::
#\[7]TRDMXCXCHHNDO7F75HC5FLBAG6N4QQFWIZ474MBHVKRV3SQ4GOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
