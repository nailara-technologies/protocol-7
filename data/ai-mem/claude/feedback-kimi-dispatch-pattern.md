---
name: kimi-dispatch-pattern
description: dispatching implementation tasks to kimi via bin/kimi-task is highly token-efficient and productive
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3e611ce5-11ac-409b-bf6d-272aa2ab6339
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
- `-template` flag is coding zenka only — kimi does NOT support it; write
  the full task context directly in the task file instead
- Kimi v2 is faster at orientation and has more consistent result quality
- Review kimi output for known issues: fake signature stubs, `base.log` vs
  `base.logs`, `my $call` redeclaration, `sprintf qw|...|` misuse
- User signs and stages; Claude commits — keeps the flow fast
- Kimi can work autonomously on tasks while waiting for token reset

#,,..,,,,,.,.,.,.,,.,,,..,,..,...,,,.,.,,,.,,,..,,...,...,.,.,,.,,...,..,,,,.,
#UTKNAVPGI2DFS2E4YGE6CNAY2PMAEZ74DONIZR3NR53OJ3HMDZLBKEI5AQSDZBLSMC5DQ7QWUOFOY
#\\\|P6CQC2PG4PHXMFDZUBCGY7RME27ZYF6EXMTGBMEBLZDOGHDBF6D \ / AMOS7 \ YOURUM ::
#\[7]WGNA5QVYMZXK7BLO2UEU6QRAJFB5ERIT26BRA5U6OHANY6YU2KBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
