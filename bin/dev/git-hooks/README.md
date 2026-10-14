# Protocol-7 Git Hooks

This directory contains git hooks for the Protocol-7 project. These hooks help maintain code quality and style consistency.

## Available Hooks

### `pre-commit`
Runs before committing. Checks and restores Protocol-7 file permissions.
Also reports pii pattern matches in the staged diff [ `bin/dev/pii-audit -s`, report only ].

### `post-checkout`
Runs after checking out a branch. Restores Protocol-7 file permissions.

### `commit-msg`
Runs when creating a commit message. Removes llm metadata through
`bin/dev/strip-llm-metadata`, patterns in `cfg/git/llm-metadata.patterns`
[ shared with the `harmonize-emails` history rewrite ] :
- `Co-Authored-By:` and `Claude-Session:` lines [ also indented ]
- `Generated with Claude Code` lines
- the `[CLAUDE] ` subject prefix [ the subject itself stays ]

Also reports pii pattern matches in the message [ `bin/dev/pii-audit -f`, report only ].

Note : a plain `git cherry-pick` runs no `commit-msg` hook -- `post-commit`
covers picked commits.

### `post-commit`
Runs after every commit, including each commit of a cherry-pick or rebase.
A commit with an llm author \ committer [ `identity` patterns ] gets the
configured `user.name` \ `user.email` instead, the author date stays, llm
metadata leaves the message [ `bin/dev/strip-llm-metadata -H` : HEAD rebuilt
with `commit-tree` + `update-ref`, no hook runs twice ]. a cloud session's
commit can be picked into a local session without any changed environment.

### `pre-push`
Refuses to push commits that still carry an llm identity or llm metadata,
listing them with the reason [ author \ committer \ message ]. fix recent
commits with `git rebase --force-rebase <base>` [ post-commit re-authors
each ], older history with `p7-work harmonize-emails outliers execute`.

### pii check
Patterns live outside the repository : `/etc/protocol-7/pii-audit/patterns` [ or `$P7_PII_PATTERNS` ], mode 0600. No pattern file = silent [ a normal installation state ], never a failure. Output names category + file + line only, never the matched text. See `data/tasks/repo-pii-leak-prevention.md`.

## Installation

To use these hooks, configure git to use this directory:

```bash
git config core.hooksPath bin/dev/git-hooks
```

This tells git to look for hooks in the tracked `bin/dev/git-hooks/` directory instead of `.git/hooks/`.

**One-time setup** (from the project root):
```bash
cd /data/projects/protocol-7
git config core.hooksPath bin/dev/git-hooks
```

After this, all hooks will automatically run during git operations.

## Verification

To verify the hooks are configured correctly:

```bash
git config core.hooksPath
# Should output: bin/dev/git-hooks
```

## Note

The `.git/hooks/` directory contains sample hooks provided by git. The actual hooks used are in this directory (`bin/dev/git-hooks/`) and are version controlled, so all developers have the same hooks.

#,,,.,.,.,...,.,.,.,,,..,,,..,.,.,.,.,,.,,...,..,,...,...,.,,,.,,,...,.,.,.,,,
#FDEW3PNQZ6TNQVASE4BBM6ZTJIM2YKWAQDYEL33AT2RAALE7DSL3ZRNRQZFVFLSFUHYIWOE26XSTM
#\\\|I2P3DRYTYWFEBUJQ3GREVWZBNZVXVMNDFQAXUL7QBY4GUW7YSS6 \ / AMOS7 \ YOURUM ::
#\[7]PIY6F7RZPN7YFBVHLUKM54WZ5WSCIPYWW3TFWC3AARTZYZHN2IAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
