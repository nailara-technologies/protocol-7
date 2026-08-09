# mcp kimi dispatch status-check / reattach tool — task

## context

source: 2026-07-29 session, discovered live via repeated false-negative
`status=failed` notifications on `kimi_dispatch`/`kimi_continue` — see
[[topic-kimi-dispatch-infra-hardening]] for the full recurring pattern
(3-for-3, then 4-for-4 in one session alone).

root cause, confirmed by reading `bin/mcp-server-p7` directly: our own
`kimi_dispatch`/`kimi_continue` tools already declare
`timeout => 4620` (77 minutes, `bin/mcp-server-p7:117,151`). the 1800s
cutoff producing the false `status=failed` notifications is NOT ours —
it's the outer Claude Code harness's own generic MCP-tool idle-silence
watchdog (the failure message itself names
`CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT`), sitting in front of any MCP tool
call regardless of what timeout the tool itself declares. Not fixable
from inside `bin/mcp-server-p7`.

the underlying `kimi-legacy` process is unaffected by this — it keeps
running and writing to `~/.kimi/logs/kimi.log` and its own session
directory (`~/.kimi/sessions/<hash>/<session_id>/`) completely
independent of whether the MCP tool call watching it is still alive.
today's entire workaround, done manually every time this happened, was:
`ps aux | grep kimi` to confirm the process is alive, tail
`~/.kimi/logs/kimi.log` for that session id to see recent activity, and
either wait (if alive) or `kimi_continue`/`kimi -r <uuid>` (if genuinely
dead) to recover the result.

## goal

formalize that manual workaround into a real MCP tool so it doesn't
need re-deriving by hand every single time a dispatch outlives 1800s.

## task 1.1 — kimi_check_status tool

```
## dispatch + prompt
new MCP tool in bin/mcp-server-p7 (follow the existing kimi_dispatch/
kimi_continue tool_external_command registration pattern): kimi_check_status(session_id).

behavior:
1. resolve the kimi-legacy process for the given session_id -- check
   whether it's still running. the dispatch/continue tools already
   launch it via a known command shape (`kimi-legacy -y --afk -p ...`
   or `-r <session_id> -p ...`); this tool needs to find the matching
   live process (e.g. grep ps output for the session_id in its
   resume-flag args, or track a session_id -> pid mapping at dispatch
   time and persist it somewhere kimi_check_status can read).
2. if still running: return quickly (well under 1800s) with a
   "still in progress" status plus the tail of the session's own log
   activity (last N lines from ~/.kimi/logs/kimi.log filtered to that
   session id) so the caller has a sense of what it's doing without
   waiting the full duration.
3. if not running: read the final result from the session's own state
   (its persisted session directory, or by doing a lightweight
   kimi -r <session_id> --print-last-message style non-mutating fetch
   if the CLI supports one -- check `kimi-legacy --help` for anything
   resume-adjacent that doesn't inject a new prompt) and return it as
   the actual result, same shape kimi_dispatch/kimi_continue already
   return.

this tool should itself return well within any idle-timeout window --
it's explicitly the "quick poll" alternative to sitting inside a
1800s+ blocking call.
```

## task 1.2 — wire it into the false-negative recovery pattern

```
## dispatch + prompt
update the kimi_dispatch/kimi_continue tool descriptions in
bin/mcp-server-p7 to mention kimi_check_status as the recommended next
step when a status=failed notification arrives for one of them --
matching the manual pattern already documented in
[[topic-kimi-dispatch-infra-hardening]], but pointing at the new tool
instead of "go check ps aux and the log file by hand."
```

## notes

- this doesn't eliminate the harness's own idle-timeout — dispatches
  still occasionally report false failures. it just makes recovering
  from that report fast and mechanical instead of a multi-command manual
  investigation each time.
- keep the session_id -> pid tracking mechanism simple; a small state
  file or in-memory table scoped to the mcp-server-p7 process's own
  lifetime is enough, it doesn't need to survive mcp-server-p7 restarts
  (a restarted server can't recover tracking for dispatches from before
  its own restart anyway, and that's an acceptable limitation given
  today's manual process already had the same gap).

#,,.,,..,,...,,..,,,,,,,.,...,,.,,..,,...,,,,,..,,...,...,,,,,.,.,.,.,.,,,,..,
#CC5MLH2HR2MJQALMQQZ5QLRI4K3HRROBCMZVPZI7FUFU4XD54472IVDYPQUESM6JQJDECPKL4B5HK
#\\\|LA2S762LZQT643J4IBNY6RTSFUIISYLB4U6GZLC4RFOSZUAGSOK \ / AMOS7 \ YOURUM ::
#\[7]MU4LENLCAB6YCPNTH5ZTVS3RMSAJRNS2FZRDTJZPV3A6MU3TNOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
