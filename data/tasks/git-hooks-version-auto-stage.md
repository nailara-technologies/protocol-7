# task: pre-commit hook should auto-stage version-bump files

## status

landed in b9e4c7a23 — stage-only variant (no auto-bump-via-update-version,
since that produces unsigned files the signature check rejects). full
auto-bump still depends on a future signing-service zenka per the design
discussed with the user.

## problem

every commit leaves these three files modified-but-unstaged afterward:

```
modified:   configuration/protocol-7.src-ver
modified:   read-me/md/README.md
modified:   read-me/project-identity/source-code-versions.md
```

`bin/dev/git-hooks/pre-commit` validates the version by reading
`configuration/protocol-7.src-ver` **from the working tree** (`open $fh,
'<', $vers_file`, around line 144-155) and comparing its embedded commit
count against `(git log count) + 1`. `bin/dev/update-version` is the tool
that bumps these three files on disk.

the check passes as long as the *working-tree* file has the right count
-- but the files are never `git add`ed, so the *committed* blobs still
have the previous commit's version. after the commit lands, the working
tree (already bumped for commit N+1's expected count... or for the
commit that just happened, depending on when update-version was last run)
diverges from the index again, showing as "modified" in `git status`
immediately after every commit. the user currently has to manually
`git add` + amend these three files for every single commit, which
"circumvents the signature system" (amend skips the version check via
`$is_amend`/`.amend` handling at the top of the hook).

## goal

a normal `git commit -m "..."` (no manual file staging of the version
files, no amend) should:
- result in the version files being correctly bumped AND included in
  that same commit's tree
- leave a clean `git status` afterward (no modified version files)

## investigation starting points

read first:
- `bin/dev/git-hooks/pre-commit` (full file) -- especially the version
  check block (~line 137-191) and the `$is_amend` / `.amend` handling
  near the top (~line 56-68)
- `bin/dev/update-version` (full file) -- understand exactly what it
  writes and whether it can be invoked in a stage-only mode (write +
  `git add`, no commit side effects)
- `bin/dev/git-hooks/commit-msg` and `bin/dev/git-hooks/post-checkout`
  for related conventions (the post-checkout hook already does a
  permission-normalization pass on every checkout -- same family of
  "fix up the tree as a hook side effect" logic, useful as a style
  reference)
- `bin/dev/git-hooks/README.md` for how these hooks are installed /
  invoked (symlinked into `.git/hooks/`? copied?)

## likely shape of the fix

most likely: in `pre-commit`, before the version-mismatch check, run
`update-version` (or the relevant subset of its logic) against the
*about-to-be-created* commit (`commit_count + 1`), then `git add` the
three resulting files so they become part of the commit being made --
all from within the pre-commit hook, before it exits 0.

watch out for:
- **infinite loop / re-trigger risk**: does staging files from within
  `pre-commit` re-trigger `pre-commit`? (it shouldn't -- pre-commit
  doesn't re-run on `git add`, only on `git commit` -- but verify no
  hook chains into another commit)
- **amend path**: when `$is_amend` is true, the version check is
  skipped entirely (`$skip_version_check = 1`). decide whether
  auto-staging should still happen on amend (probably not -- amend
  intentionally reuses the prior version) -- read the `.amend` /
  `PERSISTENT_AMEND` handling carefully before changing this branch.
- **idempotency**: running the hook twice (e.g. a failed commit due to
  the signature check *after* the version check, then a retry) should
  not double-bump the version. `update-version`'s existing
  bump-vs-already-bumped detection (it must have some, since the
  original "version mismatch" error message implies it can detect
  current vs expected) should be reused, not reimplemented.
- do not touch the signature-checking logic later in the same hook file
  -- only the version-check block and whatever staging step is added.

## acceptance

- `git commit -m "test commit"` (with some unrelated staged change)
  results in a single commit containing both the unrelated change and
  the updated `configuration/protocol-7.src-ver` +
  `read-me/md/README.md` + `read-me/project-identity/source-code-versions.md`,
  with `git status` clean immediately afterward.
- a second commit afterward also passes its version check cleanly (no
  off-by-one from the first commit's bump).
- amend (`AMEND=1 git commit --amend ...` per existing convention) still
  works as before -- version check still skipped, files not
  force-bumped.
- existing signature-check and descr/param-length checks in the same
  hook are unaffected.

## signatures note

do not add the `#,,..` stub to any new file. the signing system writes
it. lowercase comments, `[ word ]` annotations.

#,,.,,.,,,...,,..,..,,,,,,.,.,.,.,,,,,,.,,.,.,..,,...,...,...,,..,..,,,.,,..,,
#CCH6655SETC5WKRUVZ5ZQTFPXNTGEBJ64WOF6LUL5SXVGKPA74ZO5AQXANB6VM22ESL37OP3QI7V4
#\\\|U2LRXMSZJSMENBKOLJUQQFRLUGTCDPKLQUFOZP5UGFWDJ6MM3HW \ / AMOS7 \ YOURUM ::
#\[7]UTALLTOM2OBZUJCT6DTJOXWXNKWEH5IUFKD5VTFDBNTDQLSHXWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
