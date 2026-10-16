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
  spec said never [ rejected before a session existed, nothing billed --
  but it ran on the local machine with a configured claude CLI : only the
  malformed argument form [ --cloud=x -p .. ] kept it from starting a real,
  billed cloud session. a real cost risk, not just a breach ].

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

#,,..,,,.,,.,,,,.,..,,,.,,,..,,.,,..,,,,,,.,.,..,,...,...,.,.,...,..,,...,...,
#LAVGPFOHVZNL4T6DSBO4E6ZM7BF52APMPHT4MDUKV4VCW7ZGQUWUN67YKS7K7VG3WCJS37XA7EZN2
#\\\|RN6XLW2CIUDOAZKFDL5I3UMRE4N6WW56YLFBUHSPGHZVNUP44Z2 \ / AMOS7 \ YOURUM ::
#\[7]TI2QB46PYKCNFISRM7PDCFF37I3ZMFL2YH5UNU3PC4GP37V466BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
