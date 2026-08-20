---
name: feedback-combined-grep-conflated-caller-counts
description: "grep -rln 'funcA|funcB' src/ reports files matching EITHER pattern, not files calling a specific one -- conflated base.ntime.B32_2_unix's real caller count (2) with base.ntime_BASE32_to_numerical's (19) when scoping a bug-fix dispatch, caught by kimi's own verification pass, not by me"
metadata:
  type: feedback
---

Scoping `bug-ntime-b32-2-unix-missing-compint-float-support.md` for
dispatch, I ran:

```
grep -rln "base\.ntime\.B32_2_unix\|base\.ntime_BASE32_to_numerical" src/
```

and reported "confirmed: base.ntime.B32_2_unix is called by 23 other
modules" in the dispatch prompt. That count is the union of files
matching *either* pattern — most of the 23 were actually callers of
`base.ntime_BASE32_to_numerical` (a different function, 19 real
callers), not `B32_2_unix` (2 real callers per
`data/training/codebase-depgraph.txt`). Kimi's own verification pass
caught this during the dispatch, not me — it cross-checked against the
depgraph before trusting the inflated blast-radius claim I'd handed it.

A second claim in the same bug report was also wrong: the specific
example value (`33WHIVSUBEGYLKXY`) I'd cited as "a valid high-precision
timestamp the old decoder chokes on" turned out to be genuinely
undecodable by *any* decoder (unterminated BER compressed integer) —
`p7c localtime` rejects it too. I'd assumed it was a good repro case
without checking that specific value against the alternate decode path
I was pointing to as "already correct."

**Why:** an OR-combined grep across two related-but-distinct function
names is a fast way to scope "is this general area touched," but it
actively misleads if the dispatch prompt then reports the combined count
as one function's specific blast radius — the receiving model (or a
human) will reasonably trust a number stated as "confirmed."

**How to apply:** when citing a caller count for a specific function in
a bug report or dispatch prompt, grep for that exact function name only,
or cross-check against a real call graph (`data/training/codebase-depgraph.txt`
exists in this repo specifically for this). If two similarly-named
functions are in play, never combine their grep patterns before
reporting a count attributed to just one of them. Also: verify a
"known-bad" repro value against *every* decode path being compared, not
just the one already suspected broken — an input that's bad everywhere
isn't evidence of a gap between two paths.

#,,..,,,,,,..,.,,,,..,,,,,...,,,.,,..,...,,..,..,,...,..,,...,,.,,,,,,.,.,.,,,
#5LTQ3ERTPKYRGEH5EZ6USNRO5GEZJBR5TGG2N7HRZUFAY6YDU6VEKDEQXH5R7RQK22NU7QC4QFECI
#\\\|5AQIECAW3745UMCHMNAG7MXBNBQZSX7ONDQA72O4M7SEB6SRK6Z \ / AMOS7 \ YOURUM ::
#\[7]HNLY5BP3JA6XL5ZIU7PJEUWBMLIEBGCAUSBG6TIUWGO36OG2BKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
