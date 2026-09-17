---
name: verify-staged-content-before-commit
description: after the user signs+stages, re-add of untracked (??) files is not enough -- already-tracked modified files can ALSO still be sitting unstaged (leading-space M) and silently get left out of the commit
metadata:
  node_type: memory
  type: feedback
---

Landed an incomplete commit (`772fbe744`) 2026-09-17: after a multi-round
edit session on 4 already-tracked files, the user's sign+stage cycle
staged some files but left those 4 still unstaged (`git status --short`
showed them with a **leading space** before `M` — this project's
convention throughout the session for "modified, not staged," vs a
bare `M` for "staged"). Only explicitly `git add`ed the *untracked*
(`??`) new files before committing, on the assumption that anything not
`??` was already handled — missed that "already tracked" and "already
staged" are independent facts. The commit went through with the OLD
(pre-edit) content for all 4 files from the index, silently dropping
real changes (in this case, a `$reinit` guard whose entire purpose was
preventing a duplicate-timer bug — the commit shipped without it).

**How to apply**: before every commit, read the *full* `git status
--short` output, not just skim for `??`. Any file — tracked or not —
showing unstaged changes (leading-space prefix in this project's color
scheme, or plain `git diff --cached --stat` vs `git diff --stat`
disagreeing) needs an explicit `git add` regardless of whether it was
already in a previous commit. After staging and before running
`git commit`, a quick `git diff --cached --stat` should show every file
you intend to change — if a file you know you edited isn't in that
list, it isn't going in.

**Recovery, if caught after the fact and not yet pushed**: a follow-up
fix commit works, but squashing is cleaner and was preferred here —
`git reset --soft HEAD~N` (only when confirmed unpushed via
`git rev-list --count <remote>/<branch>..HEAD` or equivalent) collapses
the incomplete commit and its fix back into the staged index, then one
clean commit replaces both. Never `reset --hard` for this — soft reset
keeps everything staged, nothing is at risk of being lost.

#,,,.,,,,,.,,,,,,,.,,,,..,,.,,..,,..,,.,,,,.,,,,,..,,...,...,.,,,,,.,.,.,.,,,

#,,,.,.,,,,,.,,.,,,,,,...,.,.,.,,,...,,,.,..,,..,,...,...,,..,,.,,,.,,,,,,...,
#BYPKJPX6AJEEFQGSNYD5GGUHUCH6S3AMJE2B4SOQ4RJQCVCH37TFOA6VKUHWAXTXXCTD2DSQI467U
#\\\|CC2K42JX554MNTYUI64SINBSBKXPNT2MGXJ5DTBTRWD4DB6MLOP \ / AMOS7 \ YOURUM ::
#\[7]6PD4VQVS7AKD6LT372XR7NPFHBLMF36FEXMVSJDAHXIXABH3XCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
