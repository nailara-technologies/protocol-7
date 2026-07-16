---
name: feedback-mcp-memory-update-agent-detection
description: "p7_memory_update's agent='auto' misdetects kimi-legacy as claude, writes to data/ai-mem/claude/ instead of kimi/ — root cause found, fix not yet applied"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

Found live 2026-07-17: kimi (via `kimi-legacy -r`) called `p7_memory_update`
with the default `agent='auto'`, and it wrote to `data/ai-mem/claude/`
instead of `data/ai-mem/kimi/`. Kimi noticed and moved the file manually
as a workaround.

**Root cause, precise:** `tool_p7_memory_update` (`bin/mcp-server-p7:1834`)
resolves `auto` by checking `$mcp_client_name` (populated at
`bin/mcp-server-p7:848` from the MCP `initialize` request's
`clientInfo.name` field) against `/kimi/i`
(`bin/mcp-server-p7:1846-1852`) — if it doesn't match, it silently falls
through to `'claude'` in the `else` branch. Whatever `clientInfo.name`
kimi-legacy's MCP client library actually sends in its `initialize`
handshake isn't matching that pattern (not yet confirmed exactly what
string it sends — that's the next diagnostic step, not done yet).

**Why not fixed immediately:** found mid-session while kimi had a live
MCP connection to the same running server process; editing
`bin/mcp-server-p7` would need a server restart, which risked disrupting
kimi's in-progress dispatch. Deferred deliberately, not overlooked.

**Better fix path than "smarter regex":** `session_catchup`
(`bin/mcp-server-p7:2588`) does NOT rely on `$mcp_client_name`/
`clientInfo.name` auto-detection at all — it takes an explicit `client`
parameter from the caller (`$args->{'client'} // 'all'`) and, when
listing rather than summarizing a specific session, searches both
`_list_claude_sessions()` and `_list_kimi_sessions()` rather than
guessing one. That's the robust pattern already proven in this same
file: `p7_memory_update` should follow it — stop trying to infer agent
identity from a handshake field that's evidently unreliable for
kimi-legacy, and instead lean on the `agent` parameter it already accepts
(just make omitting it fail loud or require the caller state it,
mirroring `session_catchup`'s explicit-`client`-param shape) rather than
silently defaulting to `'claude'` on a failed guess. The same `/kimi/i`
pattern is reused at line 1764 for the identical MEMORY.md dual-path
logic and likely has the same bug there too — fix both call sites
together, not just `tool_p7_memory_update`.

## related

[[feedback-kimi-dispatch-pattern]] (kimi-cli MCP integration notes)

#,,.,,.,,,.,.,,..,.,,,.,.,.,,,,..,...,...,.,,,..,,...,...,.,.,.,,,,..,..,,...,
#HBSDWPNEIEE3VO66SDVPXTBLY7MLQ33GESRZJTCQKAXREYYTYDRM3SJISDDKBPSOC6M4KWL6DEILE
#\\\|AF4MRU3Q2SYM3S7CUGXJUEDOZLNE7ZDEVHGELXPXFTOMACG2LNS \ / AMOS7 \ YOURUM ::
#\[7]YVD6VYEXNNYDW73MHI3OU23QQ46R2VCW3J4KLI6A6PXWFKYCHSBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
