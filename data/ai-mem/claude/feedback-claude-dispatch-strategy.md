---
name: feedback-claude-dispatch-strategy
description: "use claude_dispatch early to offload kimi orchestration, reviews, and ptd — keeps parent context small and token-efficient"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 56461443-76ee-4bbf-9976-ee5713dd7c8d
---

claude_dispatch and claude_continue are live in the MCP server (commit 1adbf83d2).
Use them proactively to offload kimi dispatch workflows out of the parent context.

**Why:** Each kimi dispatch eats 5–20K tokens of context for the dispatch + result
summary. Offloading to claude_dispatch means the parent context only sees a short
summary, not the full kimi output. This keeps the parent session lean and extends
effective working time before compaction.

**Pattern — kimi via claude_dispatch:**
```
mcp__protocol-7__claude_dispatch(
  prompt="Read task at data/tasks/X.md, dispatch to kimi, review result, run ptd"
)
```
claude handles: task reading → kimi_dispatch → review → ptd formatting → summary.
Parent receives only the summary + session UUID.

**Pattern — parallel dispatch:**
Multiple claude_dispatch calls can run in parallel (each is a separate CLI session).
Dispatch 2-3 kimi tasks simultaneously via separate claude sessions without
blocking the parent context.

**Tested:** `iris-ring-ledger-mode.md` workflow — claude found task in needs-testing/,
dispatched to kimi, reviewed result (already implemented in c80c2a69e), skipped ptd
since no changes. Two UUIDs returned: outer claude session + inner kimi session.

**How to apply:** For any kimi dispatch, prefer routing through claude_dispatch
unless the task needs live feedback in the parent context. Small tasks (< 10 min
estimated) may stay inline; larger or parallel tasks → claude_dispatch.

**Why:** keeps parent context under 100K tokens during long sessions; outer session
can be continued via claude_continue if review needs follow-up; kimi session can
be continued via kimi_continue for additional passes.

#,,.,,.,.,..,,,,.,.,,,,..,.,,,,..,...,...,..,,..,,...,...,..,,.,,,,..,,,,,,,.,
#LCLB2O3AA7VUL74O5YJ37PIH3KLD6TWMIAZR2UHVS45BQJNAFKQJFAAFPC2VV4SXVYTKQBZ4ESN7I
#\\\|OQX7YCRFCMZHWLZBGXEVECFC2SVBUDUTOQPWU5NAA2CIDJ43LKH \ / AMOS7 \ YOURUM ::
#\[7]ZBQJRDD4OIN54CJE5FJ2HO7524XLCNDV77MKIFPWJ4MYROXIK6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
