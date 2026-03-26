---
name: kimi dispatch pattern
description: dispatching implementation tasks to kimi via bin/kimi-task is highly token-efficient and productive
type: feedback
---

Dispatching coding tasks to kimi via `bin/kimi-task -next -file task.md` is the
most token-efficient way to get implementation work done. Opus input tokens for
task prompts are cheap; kimi's output tokens do the heavy lifting.

**Why:** opus output tokens are 5x more expensive than input. A well-crafted
task prompt (3-5KB) can produce 10+ modules of implementation from kimi.

**How to apply:**
- Write detailed task files with: files to read, what to build, P7 pitfalls
  to avoid (base.logs not base.log, no `my $call`, no fake signatures, TRUE=5)
- Use `-next` flag for fresh session per task
- Review kimi output for known issues: fake signature stubs, `base.log` vs
  `base.logs`, `my $call` redeclaration, `sprintf qw|...|` misuse
- User signs and stages; Claude commits — keeps the flow fast
- Kimi can work autonomously on tasks while waiting for token reset

#,,,,,..,,,.,,,..,,.,,..,,,,.,,,.,.,,,,.,,,..,..,,...,..,,.,,,,..,,..,,,.,.,,,
#FBBTHJGZHQVU24QC4UGJFHOW2MRIMNO2W6DPXZEXRDD2HD6VO6VVZHSNSW4SNSF6NGBDQ4HHZ7SBS
#\\\|XN6LV6F33L7RPDAJ5NOH2DALE7NBHUIXWXE5JDZQSFSA3GHCDTN \ / AMOS7 \ YOURUM ::
#\[7]JGNOQYSGORAGZQKQMTKI4B47CXDMTXHPN4QXX2KFRW7G6462ZMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
