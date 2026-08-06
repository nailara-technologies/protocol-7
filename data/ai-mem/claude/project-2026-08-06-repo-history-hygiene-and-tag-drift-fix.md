---
name: project-2026-08-06-repo-history-hygiene-and-tag-drift-fix
description: a git-history rewrite on base orphaned release tags off base's real ancestry; root-caused, fixed via new bin/dev/fix-tag-drift script, 124/127 tags re-anchored, 3 genuinely-abandoned tags deleted
metadata:
  node_type: memory
  type: project
  originSessionId: b9319112-4c00-4c0f-9559-fd4842eee849
  modified: 2026-08-06
---

Any history-rewrite changes every descendant commit's hash, but
pre-existing tags keep pointing at the old (now
unreachable-from-branch-tip) hashes unless explicitly retargeted.
`.git/filter-repo/commit-map` gives a deterministic old→new lookup for
anything a *given* rewrite actually touched — check every drifted tag
against it before assuming a fix needs matching logic; most drift traces
to earlier, unrelated rewrites, not the current one.

`bin/dev/fix-tag-drift <branch>` (committed): for each tag not an
ancestor of the branch, matches its target commit to the branch's own
history by exact subject line, falling back to a pickaxe search on the
tag's own annotated-message version-string (`git log <branch>
-S"<string>"`) when a later rename changed the subject text but not the
content. Only auto-applies clean (empty-diff) matches; anything with a
real content difference or zero candidates is reported for manual
review, not guessed at — some "broken" tags are correctly broken (they
point at an abandoned release with no valid branch-mainline equivalent)
and should be deleted, not force-matched.

Two `git filter-repo` gotchas worth remembering: `--replace-text` only
rewrites blob content, not commit/tag messages — that needs the separate
`--replace-message` flag (or `--message-callback` for non-literal
rewording). And its post-rewrite `_record_metadata` step can throw an
`AssertionError` while the actual rewrite already succeeded — verify
empirically (`git log --all -S`/`-i --grep` sweeps + `git fsck`) rather
than trusting the exit code.

#,,,,,,,.,,.,,,,,,..,,,..,.,.,.,,,,..,,..,.,,,.,.,...,...,..,,...,,..,...,...,
#NKSHJYCSOFJNXYYC6MM73TNADL4QBV4HYAEJDF7HM2CKPO6C7ENCOPLHDRFYTJ4Y7IFTPGZJB3HSW
#\\\|DK5BLC4F5NBNQSLWI73OVFUBAQJEHV3OXVOFNDLCRXBVTEEO3O2 \ / AMOS7 \ YOURUM ::
#\[7]4A6F7ULYJBH6KZWMUG77LQSYZM7T426MHBTKKUEVQCIFF6FDPKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
