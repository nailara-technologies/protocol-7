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

**kimi-cli MCP integration (session-69, 2026-06-01):** kimi-cli now loads
`~/.kimi/mcp.json` → `bin/mcp-server-p7` for every session, including dispatched
ones. Dispatched kimi sessions have the full p7 tool set: `p7_memory_update`,
`session_catchup`, `p7_call_tool`, `store_summary_focus`, `coding_summarize`, etc.
kimi can orient itself, query the live system, and update its own memory mid-task
without any extra scaffolding in the prompt.

**Nested dispatch pattern:** claude_dispatch sessions can themselves call
`kimi_dispatch` or `coding_summarize` as part of their workflow — e.g. a claude
session that reads a task, dispatches to kimi, waits for result, summarizes it with
`coding_summarize`, and writes the summary back via `p7_memory_update`, all before
returning a compact result to the parent. This creates a 3-layer stack:
  parent claude (context-lean) → claude_dispatch (orchestration) → kimi_dispatch (impl)
Each layer only sees a summary of the layer below. Ideal for large multi-step tasks
that would otherwise blow the parent context.

**How to apply:** For any kimi dispatch, prefer routing through claude_dispatch
unless the task needs live feedback in the parent context. Small tasks (< 10 min
estimated) may stay inline; larger or parallel tasks → claude_dispatch. For very
large tasks, consider the 3-layer stack — claude_dispatch handles orchestration
so the parent only ever sees the final summary.

**Why:** keeps parent context under 100K tokens during long sessions; outer session
can be continued via claude_continue if review needs follow-up; kimi session can
be continued via kimi_continue for additional passes.

#,,,,,.,.,...,,..,,.,,,..,,,,,...,,.,,,..,,,,,..,,...,...,...,,,.,,,,,,.,,.,.,
#2MHNDPE6TPFGOCMXJMTZCSC7S4XLSHSIFVFJW3YQATUSMI55O2Z3PUUDJ2JC7ZLF7S44AC7DJAIWI
#\\\|3AXH3EMRSSHJSX2URBCD77UGGMLO2FZQ7K4JDU4YRP5BWPMMI74 \ / AMOS7 \ YOURUM ::
#\[7]OUTZGDCBB25UB6USNXMSTTUBEVPCLJ3VKACAF22P5MQCSTL2HICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
