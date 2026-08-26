# Protocol-7 Git Hooks

This directory contains git hooks for the Protocol-7 project. These hooks help maintain code quality and style consistency.

## Available Hooks

### `pre-commit`
Runs before committing. Checks and restores Protocol-7 file permissions.

### `post-checkout`
Runs after checking out a branch. Restores Protocol-7 file permissions.

### `commit-msg`
Runs when creating a commit message. Prevents forbidden patterns from being committed:
- Lines starting with `🤖 Generated with`
- Lines starting with `Co-Authored-By:`

These patterns should not appear in commits to maintain clean commit histories.

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

#,,,,,...,.,,,..,,,.,,.,,,...,,..,..,,,,,,,,.,..,,...,..,,.,,,...,..,,...,...,
#CZP4AJYC5U2LRPCMI4UCZWCTFEVWXUCV5A7RRJ2YGQCWNMSQ4OUXDSHVZF2RI3E7K5I42E77JTHG6
#\\\|ZCJAKBSLT2OSACKMFO4S4YG6EPSZJDRECNFGSRUE3J2CJ4CGQMP \ / AMOS7 \ YOURUM ::
#\[7]BFASPIEJ535MQ7D7N5PG32WQQZPS6LETZ2ROGWJEDPIMQ77OUGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
