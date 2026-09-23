---
name: feedback-git-restore-worktree-needs-source-head
description: git restore --worktree with no --source defaults to restoring FROM THE INDEX, not HEAD -- safe only in the instant right after --staged unstaged the same paths; unsafe later if anything (e.g. a concurrent signing/commit tool) re-staged them in between
metadata:
  type: feedback
---

`git restore --worktree -- <paths>` restores the working tree from the
**index**, not from HEAD, when `--source` is omitted. Right after `git
restore --staged -- <paths>` (which resets the index to HEAD for those
paths), the index and HEAD are identical for them, so a follow-up
worktree-only restore happens to produce the correct result. That
coincidence breaks the moment anything re-stages those paths in the
index afterward — a concurrent signing/version-bump tool doing its own
`git add` on whatever's currently dirty being the concrete case that hit
this. The worktree restore then silently pulls the *re-staged* (unwanted)
content back into the working tree, not HEAD's content, with no error —
`git status` shows the command "succeeded."

**Cost this caused, 2026-09-23**: reverted 24 files to HEAD (2 dangerous
default-encoding flips + 22 per-callsite changes), confirmed clean via
`git restore --staged` + `git restore --worktree` right after. Considerable
real time passed (a long investigation into an unrelated bug) during which
the project's own signing tool re-staged the still-dirty-in-the-index... no
wait — re-staged them because they were STILL DIRTY relative to HEAD in the
index at the time it ran (the earlier `--staged` unstage had only touched
the *first* 2 files' timing, not all 24 consistently) -- a later
worktree-only restore on the remaining files pulled the re-staged (still
Qwen's original) content right back into the worktree. Looked exactly like
live, ongoing corruption until traced back to this mechanic.

**How to apply**: never call `git restore --worktree` alone when the goal is
"reset to HEAD," except in the exact instant after a `--staged` restore on
the *same* paths with nothing able to run in between. The reliable form
resets both together, atomically, from an explicit source:
```
git restore --source=HEAD --staged --worktree -- <paths>
```
or equivalently `git checkout HEAD -- <paths>`. Verify afterward with
`git -c color.ui=false diff HEAD -- <paths>` (see
[[feedback-git-color-forced-verification-pitfall]]) showing genuinely empty
output — not just `git status` showing no `M`, which can't distinguish
"matches HEAD" from "matches a re-staged index that itself doesn't match
HEAD."

#,,.,,,..,,,.,.,,,,..,,,.,...,.,.,.,.,,,.,,.,,.,.,...,..,,..,,,.,,..,,..,,.,,,
#VINSOQPYNFXHZAEHTAJCOW5OPTCUAVIPP4PENUHMKAVN34KCBPFIJGAOQFDSFTERC5VNQHHSUEM4E
#\\\|UIY5T3LFMTTKDY7J7LXUQENJB647YMU2ICWXBKL4X4S2LIUS7C6 \ / AMOS7 \ YOURUM ::
#\[7]VSJ6DZG7RHXFLSYFKUKI2JKW75MCNXKQABY4OOK424KYZV6UOKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
