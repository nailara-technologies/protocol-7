---
name: feedback-self-reexec-tests-need-recursion-guard
description: a script that re-executes itself [ e.g. a test running a child with Inline::C hidden ] needs an env recursion guard ; under 'use English' the mode flag must be read from @ARGV, never @ARG [ = @_ ]
metadata:
  type: feedback
---

2026-10-18 : kimi's bin/test-scripts/test-truth-fallback.pl re-executed
itself as `perl -MBlockInlineC $0 -child`, but tested the flag with
`@ARG and $ARG[0] eq '-child'` -- under `use English` @ARG is @_, empty
at file scope. every child ran as a parent again and spawned its own
child : a FORK CHAIN, each level loading and compiling Inline::C. the
host froze ; the user stopped it with Esc. I first blamed kimi's other
work and an Inline rebuild before reading the script -- wrong both times.

**Why:** one wrong variable turns a single child into an unbounded
process chain ; on this host that is a full freeze, not a failed test.

**How to apply:**
- any self re-exec : set an env marker before spawning
  [ `local $ENV{'P7_..._CHILD'} = 1` ] and refuse to spawn when it is
  already set -- the guard holds even if the argv check is wrong
- read script arguments from @ARGV ; @ARG only inside subs
- review a delegated test's process spawning BEFORE its first run, and
  run unknown tests under a process limit [ `ulimit -u` ] in a subshell
- when processes pile up : read the spawning code first, then explain

#,,,,,.,.,..,,...,,,.,...,..,,.,,,,,.,,..,,.,,..,,...,...,.,,,.,.,.,,,...,.,.,
#AAFQCH6FPPEZUMVNU5SLPABTEOSJRBESEGSIIYP25LR4NQXXDN76XQNNS7JCX45UECKAFLRKUNX5A
#\\\|7WDW2D62M5MDJTMRXEIS3TNWR63EAHKOGTSGFE34W75EFNU7Z72 \ / AMOS7 \ YOURUM ::
#\[7]UXD2NZYYK2IUCTBT5HGK2RNIH7Q2O6DLKW6PPLYVPY477X3UL2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
