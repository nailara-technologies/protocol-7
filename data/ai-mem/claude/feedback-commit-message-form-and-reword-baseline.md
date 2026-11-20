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
backup branch + splitting the one-liners [ tip 3b9f9af83 ].

**Why:** a plausible-looking detection rule can silently point the wrong way ; the
approval step then checks the proposed text, not the premise.

**How to apply:** before any history reword, show the per-day single \ multi-line
distribution of the older history as the baseline, and state explicitly which form is
being produced. for message-only rewrites prefer `git filter-branch --msg-filter` [ no
checkout -> post-checkout's restore-p7-permissions never dirties the tree, dates kept,
its `../map/<sha>` remaps in-message hash refs in the same pass ] ; in-file hash refs
[ data/tasks, data/ai-mem ] then need one remap + user signing, amended into one commit.

#,,,,,...,.,.,,..,...,,..,...,..,,,..,...,..,,..,,...,..,,.,,,.,.,,.,,..,,,.,,
#DK2LNCMG6H2GHFLT7AZZK24AGC3UBWSRJ66ZTW67LTDXA7X7PJJZILYWO67QYVXFNM2Q2H5IMCGNS
#\\\|SQWO4JQL3K7VMBPLHTKTLAX33SM6CTWLL52LQSNSXPUZYZH7QLT \ / AMOS7 \ YOURUM ::
#\[7]CB4TFOBSXPQEGW4MRMP6KP6QPUUGJTMQCCYJSZ5VTMHPC5VFF4DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
