---
name: feedback-sign-gate-and-pending-edits
description: a sign run stops at format-code [ tidy, descr > 55 bytes ] and leaves unsigned version files ; never edit a file while its sign run awaits approval
metadata:
  type: feedback
---

2026-11-27 : three sign runs lost in a row.
- editing a file while its p7_sign job awaited approval -> REFUSED : content changed.
- `bin/format-code -c` saying "syntax valid" is not enough : read its whole output
  [ strip ansi ] -- it also reports tidy needs and header limits [ descr line max 55 bytes ].
  the sign run then aborts AFTER the version bump : README \ source-code-versions stay
  unsigned and the commit hook refuses. re-sign them together with the fixed file, no
  second bump.
- p7-sign-wait exit 0 is not approval : check its last lines for `0 of N files need action`.

**Why:** each lost run costs an owner approval round.
**How to apply:** run `bin/format-code -r` before p7_sign on new files ; keep files untouched
until the run is committed ; related [[mcp-sign-commit-workflow]].

#,,..,,.,,...,.,,,,,.,,..,,.,,...,.,,,,,.,,.,,..,,...,...,,.,,.,.,,,,,,..,.,,,
#C5HR4JXWSR7FWVFQXSATE5QEWUQX2J4TP5BXG5YGZULVXLF3K7GT4N7HCZ5NQSO6WPIYT5TQS7IU4
#\\\|WORDKV5VGHVBKZU5B3URG5ZXQKSQNKWO3Y2DOOXEGBCT4PQMEEO \ / AMOS7 \ YOURUM ::
#\[7]43PXSEQ5IIFEWFEPTYKXM7GUCETQD2XASTIMQSPJZXTKRVU7KIDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
