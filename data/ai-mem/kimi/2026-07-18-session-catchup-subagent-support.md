## 2026-07-18: session_catchup claude subagent transcript support

### What was added

`bin/mcp-server-p7` `session_catchup` now supports claude subagent transcripts
(stored at `~/.claude/projects/<proj>/<session-uuid>/subagents/agent-*.jsonl`
with `agent-*.meta.json` sidecars holding agentType/description/model).

- New tool param `subagents`: 0 = exclude (default), 1 = append transcripts to
  session text before summarizing, 2 = summarize only the subagent transcripts
  (the "recover lost subagent context" use case — claude subagent context is
  gone from the parent session once agents close, but transcripts persist on
  disk; vendor system prompt makes claude itself refuse to dig them up, so the
  MCP tool routes around that via local 9B summarization).
- New helper `_extract_claude_subagent_text($uuid)`: chronological by mtime,
  per-transcript header `.:[ subagent N .[ type ]:. description [ model ] ]:.`
  built from the meta sidecar, body via existing `_extract_session_text`.
- List mode annotates claude sessions having subagents with `[+N sub]`.
- Result header notes `[subagents only: N transcripts]` / `[includes N ...]`.
- List mode warns when subagents/instruction/tail_chars passed without
  session_id. mode 2 errors cleanly when no transcripts exist.

### Verification (E2E over real MCP stdio + live coding zenka)

- list mode showed `[+6 sub]` / `[+1 sub]` correctly.
- subagents=2 + tail_chars=150000 on session 5d437747 (fable+opus tier-2
  discriminator agents): 6 rolling chunks, ~11 min on local 9B, returned an
  accurate consolidated summary (grammar-inversion discriminator, QR mod 13
  structure, zero-wrong-lock guarantee, verification matrix).
- subagents=2 on a session without subagents -> clean isError result.

### Notes

- perl gotcha: `scalar glob()` iterates instead of counting — collect into an
  array first (used in list-mode marker).
- running MCP server processes keep old code: clients must restart their
  session (or MCP connection) to pick up this change.
- DATA SIGNATURE footer of bin/mcp-server-p7 not regenerated (needs user
  passphrase; user re-signs themselves).
- recovered raw transcripts of that session also live in
  `data/md/recovered-subagents/` (copied there by the parallel claude session;
  originally extracted to data/recovered-subagents/ by kimi).

#,,,,,,,,,,,.,.,,,,.,,,,.,.,,,,,,,,,.,,..,..,,..,,...,..,,...,,,,,,..,,,.,...,
#WP44CF25TEDBIEFQRNTBESW66HR5LW7ENNPWNFCHUUWYPDXUPVE77BTVQ526VZITZOKS4PMYMIF3C
#\\\|JST6GDCBYETEDOYAVSZK6IFPAEPRP5SVBSF53IYYKW6TEGRHJJI \ / AMOS7 \ YOURUM ::
#\[7]CGB5KSRQYG3JIGN34K2VD63BL7AHZAD6WZPYK7CARWISV5DXT2CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
