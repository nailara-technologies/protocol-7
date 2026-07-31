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
files/modules directly.

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

#,,..,...,,.,,,,,,,,,,.,,,.,,,..,,,,.,,..,,,.,..,,...,...,...,,..,,,,,,..,,,.,
#E5OMYZHIGNPEWUQTBBC3XDFJ2LNERHK3BQDXNECJ33U72XU5TH5ZU5M2VZQSZS3GM3NHHNRC5CVJG
#\\\|XJ2XC6UQ52ZYH5PZJM5ZNGPGPC4ZWBNS4G6334X2EWVBJDPM4MY \ / AMOS7 \ YOURUM ::
#\[7]WS4X3EYIRXLWYNVWIOMH2F4DYG6XAN5TVHSS7FQQTGJZV2MK42DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
