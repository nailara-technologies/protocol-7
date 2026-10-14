---
name: feedback-commit-message-form-and-reword-baseline
description: commit message form is short title + empty line + '- ' bullet body ; a reword task must derive "offender" from the older history baseline, never from a line-count guess
metadata:
  type: feedback
---

established commit message form : short `area : topic` title [ aim ~72 chars ], one empty
line, then `- ` bullets wrapped at ~75 with two-space continuation. a short single-line
message is fine when there is nothing more to say ; a long single line with everything
folded in via `;` `--` `[ ]` is the offender.

2026-09-30 : kimi [ k3 ] was asked to reword the offenders and inverted it -- it treated
every multi-line message as the offender and collapsed the 16 CORRECT ones into single
lines, leaving the ~50 real offenders untouched ; the user approved the plan without
spotting it, it was force-pushed. repaired 2026-10-01 by restoring the originals from a
backup branch + splitting the one-liners [ tip b0b29730e ].

**Why:** a plausible-looking detection rule can silently point the wrong way ; the
approval step then checks the proposed text, not the premise.

**How to apply:** before any history reword, show the per-day single \ multi-line
distribution of the older history as the baseline, and state explicitly which form is
being produced. for message-only rewrites prefer `git filter-branch --msg-filter` [ no
checkout -> post-checkout's restore-p7-permissions never dirties the tree, dates kept,
its `../map/<sha>` remaps in-message hash refs in the same pass ] ; in-file hash refs
[ data/tasks, data/ai-mem ] then need one remap + user signing, amended into one commit.

#,,,,,,..,,.,,,,.,,..,,,.,...,.,,,.,.,..,,,,,,..,,...,...,.,,,.,,,,,.,...,,.,,
#TCOC3QIALEH2NWA3D7SRI7EY2JHSVOKI3QZKWUDSUSJI5RWV5JIVDJ54DH6XL7XIKDD3Y6NP2332M
#\\\|OSVZZISVN2MC42O2UF4CLZUPXLBSIHPVP2EUVDM7YAOD7MPGXGP \ / AMOS7 \ YOURUM ::
#\[7]KNV2IGPYIN3UMTX7FI5SKPBQ3BLBKCJE5Y7AMY6ALIISFCLY2GAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
