---
name: feedback-amend-env-and-unsigned-files-staging
description: pre-commit hook demands a new version on every commit incl. amends -- use AMEND=1 git commit --amend ; the user's signing run stages only signed files, so stage unsigned ones [ bin/c_src/*.c ] myself
metadata:
  type: feedback
---

the pre-commit hook refuses `git commit --amend` with "version mismatch [ expected *-<n+1>.0 ]". the sanctioned way is `AMEND=1 git commit --amend --no-edit` [ user, 2026-10-07 ] -- never -bypass-sig-check \ SKIP_SIGNATURE_CHECK.

**Why:** 2026-10-07 the p-7-r pin-line commit landed with only the version files : the user's sign run stages only files carrying an AMOS7 signature, `bin/c_src/p-7-r.c` has none, so it stayed unstaged.

**How to apply:** before asking for a signed version, `git add` every changed file without a signature block [ bin/c_src/*.c, data/web-root/** pages, other unsigned files ] myself ; after the commit check `git status --short` is empty. if one slipped through and the commit is unpushed : stage it, `AMEND=1 git commit --amend --no-edit`.

**2026-10-07, later : the sign run stages MORE than intended and rewrites what it stages.** it stages every modified signed file -- including a kimi \ subagent's half-finished edits still in progress [ happened : 7 unreviewed harness files staged next to my 2 ]. and it reformats with `format-code -r`, which changed code meaning [ `s/\@ARG/\@_/g` -> `s|@ARG|@_|g`, committed uncompilable in a561449c0 ; format-code fixed in e8fb73635 ]. so after "signed" : `git status --short`, `git restore --staged` anything not reviewed [ it then needs re-signing in its own batch ], and run `perl -c` \ the harness on the STAGED content right before committing -- a check done before the sign run does not cover what gets committed. better : don't ask for a sign while an agent is still editing.

#,,,,,.,.,...,...,,.,,..,,,,,,,,,,,,.,,..,...,..,,...,...,...,.,,,,,.,.,,,,.,,
#QNYKLY6KVU7PD5HJQUSBKJHJU3XTF4QXMAJNON3SF6QBIQFNEGOEHFKWGHGGCFSOFY52ZNNRANKSI
#\\\|YUHMVZNUVMUIH6JHMQ3CRTWKZZXSLC46HMOQGHTMULSVRJJP676 \ / AMOS7 \ YOURUM ::
#\[7]NQX3BNHYEEH6EDUXU6IICUFCODFAZ5X3MOG46ZC2XE4KLNXBLUAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

**Recurred 2026-10-08 :** `19fd9c44f` pushed with only the version files -- the jobs.vhost
index.html change [ unsigned web-root page ] stayed unstaged. right before EVERY commit run
`git -c color.ui=false status --short` and treat any ` M` [ unstaged ] line as a stop.

#,,.,,.,,,,,.,.,,,..,,,,.,,,.,,,.,,.,,,,,,,.,,..,,...,...,.,,,..,,.,,,,,.,,,.,
#3W4V7ET5GI66FRHKPHKQ66QGBWG47XFYB3M2A4T37PJ3VYFBRUHBZKAUOO74F3AJCPJHKNDHBVOFY
#\\\|IV3G4UYUBHMRI7LMS6TCB7WJVDIJENAX37RY5DL6X7JVSIU4PLO \ / AMOS7 \ YOURUM ::
#\[7]X67XYHKTKZNG4OPMUW2YRE4ATEYIZKOY4ORXMOJ4MYAI5DTNBMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
