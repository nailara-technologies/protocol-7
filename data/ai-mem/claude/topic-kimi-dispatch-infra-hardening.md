---
name: topic-kimi-dispatch-infra-hardening
description: "kimi_dispatch/kimi_continue hardening — --afk mode, per-dispatch model routing, wrapper-process lingering pattern"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
  modified: 2026-07-19T07:47:06.151Z
---

**LANDED 2026-07-17**, three related fixes to `bin/mcp-server-p7`'s kimi
tools, all same session as the agent-detection fix
([[feedback-mcp-memory-update-agent-detection]]).

- **`--afk` flag** (commit `ee656088c`) added to both `kimi_dispatch`/
  `kimi_continue` alongside `-y`. Directly prevents the failure mode that
  burned ~30 min of tokens earlier this session: a dispatched kimi
  session hit an `AskUserQuestion` mid-task with no one able to answer
  it in a non-interactive background dispatch. `-y` only auto-approves
  tool permissions, not interactive content questions — `--afk` is the
  flag that actually covers this. Confirmed live against `kimi-legacy
  --help` before adding, not guessed.
- **Model routing** (commit `940be9206`): `model=k3|k2.7|k2.7-fast` on
  both tools, mirroring `claude_dispatch`'s existing `haiku|sonnet|opus`
  pattern in `tool_external_command`. Real pricing: K3 $15/1M output,
  1,048,576 token context, best reasoning; K2.7-code $4/1M output,
  262,144 context, cheapest; K2.7-code-highspeed $8/1M, faster. K3 is
  pricier than *both* K2.7 variants on output/cache-miss-input, not
  "between" them as first assumed — its premium is concentrated exactly
  where reasoning-heavy tool-calling work generates the most tokens
  (output), so route broad search/verification work to K2.7 and save
  K3 for design/tricky-bug work that needs the bigger context. Internal
  aliases (`kimi-code/k3` etc.) confirmed against `~/.kimi/config.toml`.
  `kimi_continue` had to migrate from the legacy `param_name`/
  `param2_name` format to the `params` array format to fit the third
  param — justified, not scope creep: it also gave `kimi_continue`
  `auto_summarize`/`keep` support it never had (its sibling
  `kimi_dispatch` already had both).
- **Wrapper-process lingering pattern** (observed, not yet fixed): a
  dispatched kimi-legacy session's outer `sh -c kimi-legacy ...` wrapper
  process sometimes doesn't exit even after the underlying work finishes
  and its result is delivered/reported. Seen at least twice — once
  needed a manual `kill`, once ran idle (sleeping, zero CPU) for 4h40m
  after its task (`state-play`/waypoints, commit `f3ff56181`) had long
  since landed. Not investigated further; if it recurs, check
  `ps --ppid <wrapper_pid>` for a still-sleeping child before assuming
  something's actually stuck — idle-but-alive is harmless, just needs
  occasional manual cleanup (`pkill -f kimi`).
- **MCP bridge timeout ≠ dispatch failure**: `kimi_dispatch`/
  `kimi_continue` calls have hit the MCP tool's own ~1800s idle timeout
  multiple times this session while the underlying kimi work kept
  running and completed successfully regardless — check
  `pgrep -af kimi-legacy` and/or `session_catchup(client=kimi)` +
  reading the session's own `wire.jsonl` directly for the real final
  output before assuming a timed-out call means lost work. Session
  files live at `~/.kimi/sessions/<hash>/<session_id>/wire.jsonl`; the
  last `ContentPart` with `type: text` before `TurnEnd` is the actual
  final report — `session_catchup`'s own summarization is itself lossy
  for large results (confirmed: undercounted a 22-vs-20 file list once).

**Recurrence 2026-07-19**: same false-failure pattern hit again on the
`strm-generic-subscribe-wrapper.md` K3 dispatch — `task-notification`
reported `status=failed` after the MCP idle timeout, but
`~/.kimi/logs/kimi.log` showed the work (6 modules, live-verified
against cred-mesh/proxy, self-recorded gotcha note) had already
completed; only the final `write_new_file` for its own memory note got
cut off mid-reply. Disk state (`git status`, `ls modules/`) confirmed
everything landed. Same lesson: check disk/logs before treating a
`failed` task-notification as lost work.

## related

[[feedback-mcp-memory-update-agent-detection]] ·
[[feedback-kimi-dispatch-pattern]] ·
[[feedback-tasks-completed-scan-verdict-trust]]

#,,,.,,,.,,.,,...,...,,..,...,..,,,..,.,.,..,,..,,...,...,,,.,.,.,,,.,,.,,,,.,
#KGJCH2EMGHGJAA5HTTI5G52WPOLCOBURT3ZZOL423EF2PNF6OU4Y7WOFYUEAPIRW7WRW3FXRFSKQ2
#\\\|QZRVAB44ZVHHAD52RFO46NAG5SQDOS2X42FJ67IFQL32NVFPLRM \ / AMOS7 \ YOURUM ::
#\[7]6IQT4LZVPZLDADPJMU3U6PGB2I52XGUADEKTHCLJK2X3B6BPGYAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
