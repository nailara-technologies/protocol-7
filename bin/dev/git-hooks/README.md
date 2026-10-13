# Protocol-7 Git Hooks

This directory contains git hooks for the Protocol-7 project. These hooks help maintain code quality and style consistency.

## Available Hooks

### `pre-commit`
Runs before committing. Checks and restores Protocol-7 file permissions.
Also reports pii pattern matches in the staged diff [ `bin/dev/pii-audit -s`, report only ].

### `post-checkout`
Runs after checking out a branch. Restores Protocol-7 file permissions.

### `commit-msg`
Runs when creating a commit message. Prevents forbidden patterns from being committed:
- Lines starting with `🤖 Generated with`
- Lines starting with `Co-Authored-By:`

These patterns should not appear in commits to maintain clean commit histories.

Also reports pii pattern matches in the message [ `bin/dev/pii-audit -f`, report only ].

### pii check
Patterns live outside the repository : `/etc/protocol-7/pii-audit/patterns` [ or `$P7_PII_PATTERNS` ], mode 0600. No pattern file = one skip notice, never a failure. Output names category + file + line only, never the matched text. See `data/tasks/repo-pii-leak-prevention.md`.

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

#,,..,,,,,,,.,.,,,..,,.,.,,,,,.,.,,.,,,,.,,,,,..,,...,...,...,..,,,.,,,.,,,.,,
#YERS3IRYLRWNPD3CXAFWTQYCBWAXUD4HAWWQ3CTCE4G243LMMHJA6AEEDCC4ZQ4Q7ZBUX2AZI3UN4
#\\\|JODZY766PI722JTWB774VXV4QMMQ4GJVC4Z5A7ROG5DNMKWIO2Y \ / AMOS7 \ YOURUM ::
#\[7]KPVQM7GYQUA3DQGWU7Y6YMMCZ3JEI7ZZ3SOARIOA7TLQ54QXFCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
