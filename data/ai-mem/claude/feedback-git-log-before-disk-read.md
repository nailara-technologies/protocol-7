---
name: feedback-git-log-before-disk-read
description: "when checking whether a task/memo item is stale, grep git log first before reading files on disk"
metadata:
  node_type: memory
  type: feedback
---

When verifying whether an "open" item in a memory/task file is actually
already done, check `git log --oneline --all --grep=<keyword>` (and
`git log --oneline --all -- <path>` for a known file) BEFORE reading
files/src directly.

**Why:** user feedback during a topic-next-steps.md staleness sweep — git
log search is cheaper and reads less into context than opening the actual
module/config files, and often answers the staleness question on its own
(commit message + subject line is usually enough to tell if something
landed).

**How to apply:** for staleness/"is this done yet" checks, git log grep is
the first move, not a fallback. Only fall through to `grep`/`Read` on
actual files when git log doesn't turn up a relevant commit, or when the
detail needed (e.g. exact config key name, exact code path) isn't in any
commit message.

#,,,.,.,,,,.,,..,,,,.,..,,...,..,,,.,,,..,.,.,..,,...,.,.,..,,,,,,...,,..,,..,
#CI6L76B3AI3B64NIT3ZV34LGV5PA2LNMJR5BEECOPQ5S77AWWSAOMMW3A75KPCNOLDA7WLYM62SQ4
#\\\|MUL3EF5HY7CQDEPYWJ43OMGDWHCHPCUCX3JVE7W2T37NCKKOLGW \ / AMOS7 \ YOURUM ::
#\[7]NEEUT7IMXTICPJB54TFTHUNXJEYT5FWLZDRJONJ7TEKK724SNOCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
