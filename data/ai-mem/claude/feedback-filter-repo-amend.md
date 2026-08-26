---
name: feedback-filter-repo-amend
description: any history-rewriting git op (filter-repo, or a plain commit --amend) requires AMEND=1 env prefix to pass the Protocol-7 pre-commit hook
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f5b14fde-ecec-4f58-b7f2-95aaab875b62
---

`AMEND=1 git filter-repo ...` — the pre-commit hook requires this prefix for filter-repo commands to work.

**Why:** the Protocol-7 pre-commit hook blocks history-rewriting operations without the AMEND=1 flag; without it filter-repo fails at the hook stage.

**How to apply:** any time `git filter-repo` is used (path removal, history scrubbing, ref rewriting), prefix with `AMEND=1`. Also clear `.git/filter-repo/already_ran` if a previous run was interrupted.

**2026-07-24: same gate applies to a plain `git commit --amend`, not just
filter-repo.** Rewording an unpushed commit's message (`git commit
--amend -m "..."`) failed with a "version mismatch detected" error from
the pre-commit hook (the version-file bump the hook expects on every
commit didn't get re-staged on a bare amend) — plain `--amend` was
silently rejected (commit hash unchanged, message unchanged, no error
surfaced to the caller beyond the hook's own printed warning). Fixed by
prefixing the same way: `AMEND=1 git commit --amend -m "..."` — hook logs
`[ amend mode ]` and proceeds normally, `0 staged files` this time since
nothing content-wise changed, only the message. **How to apply:** treat
`AMEND=1` as required for *any* git operation that rewrites an existing
commit rather than creating a new one — filter-repo and `commit --amend`
both, likely any other rewrite-history git subcommand too.

#,,.,,.,,,...,,.,,,,.,...,...,.,.,..,,.,,,,..,..,,...,...,.,.,,.,,.,.,,,,,.,,,
#6BYW2RINPFD3YBHOIHER6PRGSJ2URSLYPHNWIXKZWGKBDVHHTMSZUSYYTVCRLPM77DOROCY7WFU4O
#\\\|QSFASNX2VZ4ID6FZHIHOFXEFLMJLAI2IGSPFD6G4EOTTQONOPF4 \ / AMOS7 \ YOURUM ::
#\[7]3XHR5CWSRR5IHI4Z2YTBAOAUE2IRMTR7X64X65ADA4QCJY2FIOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
