---
name: feedback-stale-tool-output-rides-into-later-commits
description: "content produced by an earlier, pre-fix run of a tool (or an interrupted background process's own test artifacts) can sit unnoticed in the working tree and get swept into a LATER, completely unrelated commit once the pre-commit hook's own broad auto-staging picks up everything modified -- verify the working tree is genuinely clean before trusting 'diff looks good' on what you explicitly staged"
metadata:
  type: feedback
---

2026-09-01, found twice independently in the same session (both during
the format-code `-d`/`-m`/`-p`/`-r` expansion work, see
[[topic-format-code-bugs-fixed]] for full context):

1. **42 files with a missing `->`** (fixed in `9b8eebca7`): an early,
   pre-fix exploratory run of the `-d` step (before the trailing-arrow-
   insertion bug was fixed) had already compacted some real `$data{}{}`
   chains into the broken `<key.path> {$var}` form (missing arrow). That
   broken content just sat in the working tree, untouched by the LATER,
   already-fixed repo-wide `-d` pass (its scan looks for raw `$data{...}`
   patterns to compact, found nothing left to do on lines that were
   ALREADY in the broken sugar form), and rode into the repo-wide
   commit alongside everything genuinely produced by the correct tool.
2. **Two files deleted outright** (`context.cmd.review`,
   `jobsite.stage.review`, both restored via `git checkout HEAD --`):
   collateral damage from a kimi dispatch's own interrupted batch-test-
   and-cleanup pass (session ended mid-cleanup, see
   [[feedback-kimi-dispatch-never-parallel]]) -- the deletions sat
   unstaged/unnoticed until an unrelated `git status` check surfaced
   them right before a routine commit.

**The common mechanism**: this repo's pre-commit hook has its own
"staging version files" step that broadly re-stages *everything* modified
in the working tree, not just what was explicitly `git add`ed -- so a
stray, unrelated change (good or bad) doesn't stay isolated just because
you never staged it yourself. A `git commit` for one specific, reviewed
change can silently absorb an unrelated stale change sitting nearby in
the tree.

**How to apply**: before committing anything, especially after a period
of iterative dispatch-test-fix-retest work (kimi dispatches, format-code
dogfooding, any tool still being actively debugged), run `git status
--short` on the WHOLE tree, not just a `git diff --cached` on what you
intended to stage. A clean "reviewed and staged N files" feeling is not
the same as "nothing else changed" -- explicitly check for unexpected
modified/deleted files first. When something the CURRENT tool version
demonstrably fixes still shows up broken in a real file, don't assume the
fix has a residual gap before checking whether that specific file's
content actually predates the fix (`git log -- <file>` against the fix
commit's timestamp/hash) -- it may just need reprocessing, not a new fix.
But also don't assume "stale, already fixed" without verifying the exact
reported case against the CURRENT tool directly first -- both directions
of this mistake happened in the same session (see
[[topic-format-code-bugs-fixed]]'s multi-line trailing-subscript case,
where "already fixed" was said too early because only a single-line
variant had actually been tested).

#,,,,,,,.,,..,,,.,.,,,.,,,..,,.,.,.,.,.,.,...,..,,...,...,,,.,,.,,,,,,,,.,..,,
#6BXOUTQUVCDGLHGDDIY7JPJPV63JZV6Q54QAMFYHT7TBIIUIWFJNRK5MWMNYZWSU66GAUNZLKNHXW
#\\\|HTUZGU65GPH4L4NMHBOXVS5F66IOMWNY4RSMW7O5P33RLNTNUKD \ / AMOS7 \ YOURUM ::
#\[7]NKGOJ7I4EXJOHNT75B46T7HISVHBPV5SDPVPBQ7T5QAOEIW3MYDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
