---
name: feedback-claude-dispatch-summarize-hang
description: claude_dispatch can hang indefinitely (near-zero CPU, alive for 1h+) when its auto_summarize coding_summarize call fails with prompt overflow — the poll loop doesn't treat "failed" as terminal
metadata:
  node_type: memory
  type: feedback
  originSessionId: 34aa7d51-70a7-457f-a1f9-f1ad06e0dd7b
---

A `claude_dispatch`'d outer session can hang forever waiting on its
own `auto_summarize` (default true → calls `coding_summarize` on the
local 9B coding zenka) if that summarization task fails. Observed
2026-06-08: outer session `f870d68f...` (PID 2503034) ran for 1h17m
burning ~55s total CPU (near-zero %CPU, sockets open, no log activity)
— the coding zenka log showed its summarization task `7277779` failed
and **resolved** ~50min earlier with `initial prompt overflow:
estimated 22294 tokens exceeds n_ctx=22000 by 294`, but the outer
session's poll/wait loop only treats "completed" as terminal, so a
"failed/resolved" result leaves it blocked indefinitely.

**Why:** the MCP `claude_dispatch` tool itself also timed out (2400s)
waiting on the same outer session — so the hang is invisible from the
dispatcher's side too; you only see "command timed out", not "the
summarizer choked." [[coding-timeout-restart-loop]] documents that
large-prompt jobs can overflow `n_ctx` even after the data-start-
timeout/context-reduction fixes — this is the *consumer-side* fallout
of that: a failure several layers down silently wedges the top-level
dispatch.

**How to apply:**
- if a `claude_dispatch` call times out AND the dispatched session's
  PID is still alive afterward, check `ps -o pid,etime,time,pcpu` —
  near-zero CPU growth over many minutes = stuck, not working
- cross-check `/var/log/protocol-7/<host>.coding.zenka.log` for
  `initial prompt overflow` / `::task:: failed [...] resolved` entries
  near the time the dispatch call was made — that's the smoking gun
- the actual implementation work product (files written before the
  hang) is safe on disk regardless — review it directly rather than
  waiting for the session's self-report; it may be complete even
  though the session never returned
- kill the stuck PID (and its parent `sh -c claude ...` wrapper) —
  no data loss, the work is already on disk
- consider passing `auto_summarize="false"` to `claude_dispatch` for
  tasks expected to produce large diffs/output, to sidestep this class
  of hang entirely

#,,.,,,.,,,,.,,..,,..,,,,,..,,,,,,...,,,,,,.,,..,,...,...,..,,,,.,...,,..,...,
#PWDUH2AJ4ZTANW53VITRFQJ5YSETZGF6SU5VK3DSMWI4DS7V73F7YY7S3YCFDQ3KCI52P4Q5KMML4
#\\\|7SHZIYGJQLP3P3JZW3ZKE2MKII4YOVWBRQFVR4YT7PQTVPIKMH5 \ / AMOS7 \ YOURUM ::
#\[7]D7BSKBF2O6RY44O3PWTP3RUTXR537X53XTGGSUC5PU4QYBWM22DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
