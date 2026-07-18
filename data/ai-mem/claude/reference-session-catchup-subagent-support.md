---
name: reference-session-catchup-subagent-support
description: "session_catchup MCP tool now reads background Agent-tool/subagent transcripts for both claude and kimi, with a subagent_id filter -- use to recover lost subagent context instead of guessing"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 31b52ba5-702b-46b0-88e6-69d4d6dd5d6d
  modified: 2026-07-18T21:31:49.430Z
---

**2026-07-18.** `session_catchup` (protocol-7 MCP) previously only indexed
top-level `claude` CLI sessions and `kimi` MCP dispatches — background
Agent-tool subagents (Opus/Fable/etc dispatched via the `Agent` tool) were
invisible to it, only reachable through their own ephemeral `/tmp/claude-*`
transcript files (not meant to be read directly) or the task-notification
stream at dispatch time.

Two same-day expansions (Kimi's own implementation, tested live in-session):

1. **`subagents` param** (claude-side): `0` = exclude (default), `1` =
   append raw transcript text, `2` = summarize only the subagent
   transcripts via local 9B model, token-free. Use `2` — `1` is expensive
   and mostly unnecessary.
2. **Kimi subagent support + `subagent_id` filter**: kimi subagents
   (`<session-dir>/subagents/<agent-id>/context.jsonl` + `meta.json`)
   are now read the same way. `subagent_id` is a case-insensitive
   substring filter over agent id/type/model/description — implies
   `subagents=2` when not set explicitly, so pull one specific subagent
   transcript with just:
   `session_catchup session_id=<uuid> subagent_id=<name-fragment>`

**How to use**: when a background Agent-tool dispatch's result seems
lost, garbled, or you want to re-derive its full reasoning (not just the
final notification text), call `session_catchup` with the current
session's own `session_id` and either `subagents=2` (all of them) or
`subagent_id=<fragment>` (one specific one) — cheaper and more reliable
than trying to reconstruct from memory or re-dispatching the same work.

Verified live same session: `subagents=2` accurately summarized a kimi
explore agent; `subagent_id=fable` correctly selected 1 of 6 transcripts
with an accurate summary of its derivation; no-match filter returned a
clean error with no wasted inference.

#,,.,,,,.,.,.,.,,,.,.,.,.,.,.,..,,,,,,..,,.,.,..,,...,...,,..,...,.,.,...,,,.,
#LMLKFGNO3HQTPPLJQ6CYFN2JGGU7UPMATXLWZWRANAURLRVUCVPSLSF4G6TH7AKQLNCTKOL5BL7OQ
#\\\|W7COIBLQ54YGHMU4OQ6PSVJDCRTQSR7RKZE3DGTI2NHLZXOKYQG \ / AMOS7 \ YOURUM ::
#\[7]IYDIVGMLF4DBOWKJWRGGWP3LWN6LXLN4467FZC2KPUNK444OP4DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
