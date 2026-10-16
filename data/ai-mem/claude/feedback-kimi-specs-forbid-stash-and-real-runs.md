---
name: feedback-kimi-specs-forbid-stash-and-real-runs
description: 2026-10-16 : with parallel kimi tasks and unsigned work in the tree, one kimi ran a 'git stash' round trip to compare against HEAD [ it popped cleanly, luck ] and another ran the real billed CLI despite the spec -- every kimi spec now forbids git stash \ checkout \ reset \ restore and real external runs explicitly
metadata:
  type: feedback
---

2026-10-16, three kimi tasks in parallel on separate files, plus reviewed
but unsigned work waiting in the same tree :
- the sys-deps probe task 'proved' a pre-existing reflow with a `git stash`
  round trip. a stash takes ALL unstaged work [ the other tasks' and the
  pending reviewed files ] ; a failed pop would have lost it. it popped
  cleanly -- checked : stash list empty, every pending change present.
- the cloud-dispatch task ran the real `claude --cloud` once although the
  spec said never [ rejected before a session existed, nothing billed ].

**Why:** kimi reaches for the shortest proof ; 'touch only these files'
does not stop git commands that move other files, and 'never run X' was
read as 'never run X successfully'.

**How to apply:** every kimi spec says, in the rules block : no git stash \
checkout \ reset \ restore \ commit -- compare against HEAD with `git diff
HEAD -- <file>` or `git show HEAD:<file>` only ; no real run of anything
billed or outward [ cloud sessions, pushes, remote hosts ] -- stubs only,
and say what stays unverified. after a parallel round : `git stash list`
empty + every pending change still present, before the signing round.
see [[feedback-amend-env-and-unsigned-files-staging]] [ the signing run
stages every modified signed file ].

#,,.,,...,,.,,,,.,,,,,...,..,,,.,,,..,..,,..,,..,,...,..,,...,,..,,,.,..,,.,.,
#6R525V4DGPRJVDYCVLYIV6PEX2RPR32B5VJE6G52TVJQSLH6JF77X6F3R4Y5ICKRB6JZA76T2OJ3E
#\\\|TPEYI6WTC6ACMDNRIHY3RVMAWFXDNMMO7VMTT5FKBVEQNHPPVFC \ / AMOS7 \ YOURUM ::
#\[7]3ZCZV5FT46M4RQ4TMP5SPFVFZIZVRH3G6LEWA5JV5KVE45TCJ6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
