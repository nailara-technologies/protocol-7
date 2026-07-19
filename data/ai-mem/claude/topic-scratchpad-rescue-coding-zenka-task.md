---
name: topic-scratchpad-rescue-coding-zenka-task
description: "LANDED: native coding-zenka scratchpad rescue/categorize/sweep tools built by Kimi K3 from a filed task, incl. the permission-bridge refinement"
metadata: 
  node_type: memory
  type: project
  originSessionId: e523a9e4-c458-47e5-b27c-c60766dd51a9
  modified: 2026-07-19T00:25:03.468Z
---

**LANDED 2026-07-19** (staged, not yet committed as of writing — see
`data/ai-mem/kimi/2026-07-19-coding-zenka-scratchpad-rescue-tools.md` for K3's own writeup). Filed
`data/tasks/mcp-scratchpad-rescue-coding-zenka-tools.md` for the still-open Kimi K3 session that
implemented `scratchpad_import` + `session_catchup(scratchpad=1)` (see [[topic-scratchpad-import-tool]])
to hand it this follow-up: mirror that functionality as native coding-zenka tools so the coding zenka
can rescue+categorize leftover `/tmp/claude-*/<uuid>/scratchpad/` content on its own timer —
independent of any external Claude/Kimi session being alive or having token budget.

**What actually shipped** (5 new modules, verified live via `p7_call_tool`):
- `coding.scratchpad.scan` — shared enumerator, globs `/tmp/claude-*/*/*/scratchpad`, bmw-L13 keyed,
  merges `data/scratchpad/*/IMPORT-INFO` repo state, marks unreadable dirs
- `coding.tools.handler.scratchpad_list_all` — merged table (35 dirs in live test, correct counts/mtimes)
- `coding.tools.handler.scratchpad_categorize` — LWP chat call w/ cpu[8001]→gpu[8000] backend fallback
  on connection-refused, `keep|drop|needs-human-review` verdict, rubric taken from the task file
- `coding.tools.handler.scratchpad_rescue` — imports via the **chmod child**, not a direct write (I'd
  assumed direct import; K3 corrected this — mkdir/create through the child keeps everything
  taeki-owned via the group bit); per-file original mtimes recorded in IMPORT-INFO since the child has
  no utime command
- `coding.handler.scratchpad_sweep` — hourly + startup timer, max 5 dirs/run (LWP blocks the event
  loop), aborts early if inference is down, verdicts kept in `<coding.scratchpad_sweep.verdicts>`

Permission bridge landed in `bin/mcp-server-p7` (`_scratchpad_group_grant`) matches what I'd scoped —
**with one correction**: needs `g+rx` on the scratchpad dir AND `g+x` on the uuid dir (traverse-only)
AND `g+rx` on the fixed parents (`/tmp/claude-<uid>`, proj dir) — glob/readdir needs the *r* bit on
every dir actually enumerated, not just the leaf; `x` alone doesn't let you list. I'd only stated the
leaf-dir chmod, so this is a real refinement, not just an implementation detail.

**Why:** before a reboot wipes `/tmp/claude-1000/`, want a safety net that doesn't depend on an
external LLM being available to invoke it.

**Key finding baked into the task** (verified via `ps`/`stat`/`getfacl`, not assumed): the coding zenka
process (uid/gid 777, user `protocol-7`) already carries supplementary group 1000 (`taeki`) — group
membership is not the blocker. But `/tmp/claude-1000/` is created `0700` with zero group bits, so group
membership currently grants nothing. Fix is a scoped `chmod g+rx` on just each session's `scratchpad/`
subdir (not the whole session tmp dir) — done once by something already running as `taeki` (e.g.
`mcp-server-p7` itself) — after which the coding zenka can read that dir directly via its existing group,
no privileged relay process needed. This is a much lighter lift than it first looked.

**How to apply:** the reactive scratchpad_import/session_catchup path and the new autonomous
coding-zenka tools coexist — the autonomous one is the fallback for when no external session is around
to call the reactive one. Worth reusing the gotchas K3 hit for any future coding-zenka module work:
`File::stat` overloads `stat()` in the zenka (use `File::stat::stat($f)->mtime // 0`, not `(stat($f))[9]`,
or mtimes silently come back zero); reasoning models answer in `reasoning_content` with `content` empty
(parse both, prefer content); zenka file enumeration convention is `<[file.match_files]>->($dir, qw|**|)`,
not glob, for files (dir discovery still uses glob); `bin/ptd` reformats module whitespace in place —
re-read after running it before further edits.

#,,,.,,,,,,,,,,.,,,.,,...,.,.,,,,,..,,,..,,..,..,,...,...,,.,,.,,,,,.,,..,...,
#64G27GYZBX35XLWL2HLB6FVNUZ4G75K2ETRQRN7LGKJI375XQKZFHGWKIJGKZCC6IXGDFN5QVDKGI
#\\\|64QG6CMM2VOQWI7GU2OSBIYZEJXF24OF3RRUXPZGYDWOS5YEH7T \ / AMOS7 \ YOURUM ::
#\[7]YHJEFXNLSXCFPH22QHLKQAXJOT7Q5GBOSTDLQH26JONK7AWQFKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
