---
name: topic-scratchpad-rescue-coding-zenka-task
description: "task filed for Kimi K3 to add native coding-zenka scratchpad rescue/categorize tools, plus the permission finding that unblocks it"
metadata: 
  node_type: memory
  type: project
  originSessionId: e523a9e4-c458-47e5-b27c-c60766dd51a9
  modified: 2026-07-18T23:18:48.070Z
---

Filed `data/tasks/mcp-scratchpad-rescue-coding-zenka-tools.md` (2026-07-19) for the still-open Kimi K3
session that just implemented `scratchpad_import` + `session_catchup(scratchpad=1)` (see
[[topic-scratchpad-import-tool]]) to hand it a follow-up: mirror that functionality as native
coding-zenka tools (`coding.tools.definitions` + `coding.tools.dispatch`, same pattern as `read_file`/
`search_code`) so the coding zenka can rescue+categorize leftover `/tmp/claude-*/<uuid>/scratchpad/`
content on its own timer — independent of any external Claude/Kimi session being alive or having token
budget. Current tools are reactive only (need an active external session to trigger them).

**Why:** before a reboot wipes `/tmp/claude-1000/`, want a safety net that doesn't depend on an
external LLM being available to invoke it.

**Key finding baked into the task** (verified via `ps`/`stat`/`getfacl`, not assumed): the coding zenka
process (uid/gid 777, user `protocol-7`) already carries supplementary group 1000 (`taeki`) — group
membership is not the blocker. But `/tmp/claude-1000/` is created `0700` with zero group bits, so group
membership currently grants nothing. Fix is a scoped `chmod g+rx` on just each session's `scratchpad/`
subdir (not the whole session tmp dir) — done once by something already running as `taeki` (e.g.
`mcp-server-p7` itself) — after which the coding zenka can read that dir directly via its existing group,
no privileged relay process needed. This is a much lighter lift than it first looked.

**How to apply:** when this task lands (check `data/tasks/completed/` for
`mcp-scratchpad-rescue-coding-zenka-tools.md`), the reactive scratchpad_import/session_catchup path and
the new autonomous coding-zenka tools should coexist — the autonomous one is the fallback for when no
external session is around to call the reactive one.

#,,.,,,,,,,,,,,,,,,,.,,,,,...,.,,,,..,..,,.,,,..,,...,...,,,,,,,.,...,..,,,,,,
#2DJ7XTR6FNMC3TWXBCWQ57U7LNSLMW5UV23I2FYF7752662N2DXUK3MEPLFKEDVLENUVBZUESG7TA
#\\\|3CVM7PCOJRN3KXNPTNPZGCA73RDVOFRCF2BVDT4W75MSCRME5AD \ / AMOS7 \ YOURUM ::
#\[7]QZDW2KE6UIE2ORGYFA65V4X7ZGJVPOLO3X654Y625O57AA572SDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
