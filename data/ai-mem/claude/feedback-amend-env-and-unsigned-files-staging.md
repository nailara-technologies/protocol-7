---
name: feedback-amend-env-and-unsigned-files-staging
description: pre-commit hook demands a new version on every commit incl. amends -- use AMEND=1 git commit --amend ; the user's signing run stages only signed files, so stage unsigned ones [ bin/c_src/*.c ] myself
metadata:
  type: feedback
---

the pre-commit hook refuses `git commit --amend` with "version mismatch [ expected *-<n+1>.0 ]". the sanctioned way is `AMEND=1 git commit --amend --no-edit` [ user, 2026-10-07 ] -- never -bypass-sig-check \ SKIP_SIGNATURE_CHECK.

**Why:** 2026-10-07 the p-7-r pin-line commit landed with only the version files : the user's sign run stages only files carrying an AMOS7 signature, `bin/c_src/p-7-r.c` has none, so it stayed unstaged.

**How to apply:** before asking for a signed version, `git add` every changed file without a signature block [ bin/c_src/*.c, other unsigned files ] myself ; after the commit check `git status --short` is empty. if one slipped through and the commit is unpushed : stage it, `AMEND=1 git commit --amend --no-edit`.

#,,,.,...,,,,,,.,,,,.,...,,,.,.,.,,,,,,,,,,.,,..,,...,...,.,.,.,.,,,,,.,.,..,,
#RLORUC5FJMA4BZ6LJKN235F5RZ2SH43YW6DD7BJLVYWMCUXMGNXT4QCK4G2R3ZEHYS353AXRW7JX6
#\\\|MYNPRJ3S5CIOAXMTSF5G5XTNFLF3IEERW2QIRDISICVXHKJARCC \ / AMOS7 \ YOURUM ::
#\[7]MMDVRSNRGI6WQBYTL37LZTMJCU5AFONCSLNDPMB7N756WRZVTIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
