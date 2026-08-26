---
name: feedback-ptd-vs-format-code-two-reasons-to-keep
description: "bin/dev/ptd is not a redundant older sibling of bin/format-code -- two independent, unrelated reasons to keep both: ptd skips comment-block reflow (format-code's PPI-based preprocessing pass does not), and ptd has no PPI load at all so it starts ~175ms faster than format-code, which unconditionally 'use PPI;' for safe quote/heredoc/pod token identification"
metadata:
  type: feedback
---

Landed 2026-07-26, same session as the `bin/dev/ptd` in-memory-Perl::Tidy +
error-reporting backport (see [[topic-format-code-bugs-fixed]] for
`format-code`'s own PPI-based preprocessing pipeline this compares against).

## first reason (already known): reflow scope

`bin/format-code` does comment-block reflow (realigning `##` blocks,
wrapping, box-padding, list detection — the whole arc in
[[topic-format-code-bugs-fixed]]) on top of running perltidy. `bin/dev/ptd` only
runs perltidy — no comment reflow at all. For files/situations where reflow
is unwanted (or where the caller wants perltidy's formatting decisions
without any of format-code's own heuristics in the loop), `ptd` is not a
downgrade, it's a different, still-needed tool.

Now that `ptd` got the same error-message compaction/merging backport
`format-code` has (`7ecde035e`, same session), `ptd -c` and `format-code -c`
produce equivalent diagnostics for a given file's syntax-check pass — the
`-c` behavior itself is not a reason to prefer one over the other anymore,
only reflow-vs-no-reflow and the startup-latency gap below are.

## second reason (found 2026-07-26, independent of the first)

User observed `bin/dev/ptd` running with noticeably lower startup latency than
`bin/format-code`, despite both having been converted this same session to
the in-memory `Perl::Tidy` API — the assumption going in was they now load
"the same modules," so the latency gap looked like a regression or leftover
inefficiency somewhere. It wasn't: `bin/format-code` unconditionally
`use PPI;` at the top of the file, for its quote/heredoc/pod-safe token
identification (`PPI::Document->new(\$text)`, `->isa('PPI::Token::...')`
checks throughout `preprocess_source`). `bin/dev/ptd` never loads PPI at all —
it has no reflow logic, so it never needed PPI's parse tree in the first
place.

Measured in isolation: `perl -e 'use PPI;'` took about 175ms vs. bare
`perl -e '1'` at about 3ms -- essentially the entire startup-latency gap
between the two tools is explained by this one module load, not by anything
left over from the Perl::Tidy conversion. This cost is paid once per process
(amortized away in a large batch run), but is fully visible on every single
file / interactive invocation -- exactly the case where the user noticed it.

**How to apply:** don't read PPI's absence in `ptd` as an oversight or a
"leftover from before ptd got the same upgrade" -- it's structurally
correct: `ptd` doesn't do the kind of preprocessing that needs a full parse
tree, so it shouldn't load one. This is now a second, independent argument
(on top of the reflow-skipping behavior) for keeping `bin/dev/ptd` around
rather than retiring it once `format-code` gained feature-parity on the
perltidy side -- worth surfacing again if a future session considers
retiring it outright (e.g. a further move to `bin/dev/legacy/ptd`) and
starts reconsidering whether `ptd` is still worth keeping at all.

#,,,.,,.,,..,,,..,.,.,,,.,,,.,.,,,...,,,,,.,.,..,,...,...,...,.,,,,,.,.,,,,..,
#3PO64VMVZXWEOOZRL3RXFKF7IM6BADVW4APSF6MMPBTVDML3YHAITW7EFJXN6N5CBG75C64ZIG4CQ
#\\\|GCRUVYCULJOXWGD44MGFED6IPN422ZOAA76MRBXS5626YF53X3E \ / AMOS7 \ YOURUM ::
#\[7]SSCDMNUMOX4LUK7BA2E4EHE5P5TYTIEC5L6XBWVUU2RRURO3VKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
