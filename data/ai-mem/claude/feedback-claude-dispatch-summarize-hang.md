---
name: feedback-claude-dispatch-summarize-hang
description: claude_dispatch AND kimi_dispatch can hang indefinitely (near-zero CPU, alive for 1h+) when auto_summarize's coding_summarize call fails or stalls — the poll loop doesn't treat "failed" as terminal
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

**confirmed also on `kimi_dispatch`, 2026-07-30**: same shape — MCP tool
reports "still running" long after the underlying `kimi-legacy` process
has actually exited and its deliverable is already on disk. `bin/dev/
notify-pid-gone <pid> [interval]` (blocks until the PID is gone, then
returns — see the script itself, in `bin/dev/`) is a cleaner check than
manual `ps -o pid,etime,time,pcpu` polling: grab the real PID from `ps
aux | grep <dispatch-command-fragment>` right after firing the dispatch,
then run `notify-pid-gone` in the background and treat *that*
completion, not the MCP task's own status, as the signal to verify the
actual output file/diff and `TaskStop` the still-"running" MCP task.

**it may also self-resolve within ~13 minutes without intervention now**:
the coding zenka's own hard timeout ceiling for a summarization round is
`coding.http-timeouts.request-completed = 777s` (~13min), and per
[[topic-coding-round-timeout-adaptive]] (landed 2026-07-16, `411b5635c`)
it now escalates through a 384s adaptive soft ceiling and a 77s
stall-detection timer first, recovering faster than the old flat 777s
wait in most cases. so a stuck `auto_summarize` call is not necessarily
wedged forever the way the original 2026-06-08 incident was (prompt
overflow, which doesn't route through this timeout path at all) — check
whether it clears on its own before assuming a hard hang, especially if
under ~13 minutes have elapsed.

#,,..,.,.,..,,,,,,...,,,.,..,,,,.,,,,,,.,,...,..,,...,...,,..,,.,,,.,,..,,...,
#DXYVG5CF4P4TW55PPJJMLTB733XNLWPTISWA6LZBXBLDUKNECIDLN2MREUE5HIX26UOQUOAP3PAHS
#\\\|ZCNCSQEPZS4ETT3JELQU5OBJO6IVUOVMOQBZ7FIMT5GSM3OJUWQ \ / AMOS7 \ YOURUM ::
#\[7]U5TDCO5CPAN36TAAGVFWP27EX23YUMQTMIRACLDJEND7INHJB4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
