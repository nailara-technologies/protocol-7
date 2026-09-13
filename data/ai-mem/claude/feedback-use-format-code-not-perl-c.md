---
name: feedback-use-format-code-not-perl-c
description: use bin/format-code -c for syntax-checking P7 module files, not plain perl -c
metadata:
  type: feedback
---

`bin/format-code -c <file>...` is the project's own syntax checker, built specifically for this
codebase's module dialect (`<[module.name]>` calls, `<data.path>` tree-variables, `qw||` etc). It
runs `perl -c` internally but **strips the P7-specific false positives** those constructs trigger
in a raw `perl -c` (e.g. `<coding.task.queue>` parses as Perl's own diamond/readline operator,
`//=` after one reads as "modify glob", `state %hash` misparses) before reporting real errors.

**Why:** spent a large chunk of a session (round-chain/rewind-redo feature work) manually running
plain `perl -c` on every edited file, hitting the same handful of false positives repeatedly, and
proving each one harmless only by diffing the edited file against `git show HEAD:<path>` to show
the identical error existed pre-edit at the same offset. `bin/format-code -c` does this
discrimination automatically and reports a clean `syntax valid` / real-error verdict directly —
no manual diffing needed. It also flags real perltidy formatting drift (`would reflow`) separate
from syntax errors, and the same binary without `-c` applies that reflow in place.

**How to apply:** after any edit to a `src/*` module file in this project, run
`bin/format-code -c <file1> <file2> ...` (accepts multiple files, and stdin via `-` per its
pipe-friendly design) as the syntax-check step, instead of bare `perl -c`. If it reports
`would reflow`, running `bin/format-code <file>` (no `-c`) applies the fix in place. Reserve
manual `perl -c` + HEAD-diffing for the rare case format-code itself is unavailable or suspect.

**This was already known, not new** — see [[feedback-ptd-vs-format-code-two-reasons-to-keep]]
from an earlier session (2026-07-26), which covers `format-code` vs its sibling `bin/dev/ptd` in
depth. That memory just didn't get surfaced/re-applied during a later, long session doing heavy
src/* editing (this one) — it reads as "which of these two tools to keep," not "reach for this
instead of perl -c," so it didn't come to mind as the fix for repeated `perl -c` false positives.
This entry exists to make the *when to use it* trigger more discoverable than that one alone was.

#,,.,,,,,,,..,...,,,.,..,,,,.,,,,,,.,,.,.,,,.,..,,...,..,,,..,.,.,,,,,,,.,..,,
#DVKN7SGURA7EOVYRODEQ7VHYH6CNZHLES6TAFCDIORSELZPVHDLSR6Y7PFRCLIXHZSUPGRXAOZU6K
#\\\|SDO5HX5UN2EDMNO4NHTQ6S5PZ3UH6DGDISM67AEUFWWZ73FS6QA \ / AMOS7 \ YOURUM ::
#\[7]DQ2WRBOK6UCZ6NPQDJNCGYZQFA3I72Q6WMMC7F5M23IBIGEVUADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
