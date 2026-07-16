---
name: feedback-mcp-memory-update-agent-detection
description: "p7_memory_update's agent='auto' misdetected kimi-legacy as claude — LANDED fix via /proc process-ancestry signal, live-verified"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

**LANDED 2026-07-17, commit `b46a372a2`.** Found live: kimi (via
`kimi-legacy -r`) called `p7_memory_update` with the default
`agent='auto'`, and it wrote to `data/ai-mem/claude/` instead of
`data/ai-mem/kimi/`. Kimi noticed and moved the file manually as a
workaround at the time.

**Root cause, confirmed live via a diagnostic `p7_call_tool` round trip:**
the old code resolved `auto` by checking `$mcp_client_name` (from the MCP
`initialize` request's `clientInfo.name`) against `/kimi/i` — kimi-legacy
reports a generic `clientInfo.name` of literal `"mcp"`, not anything
containing "kimi", so it always fell through to the `'claude'` default.
An env-var-based fix attempt (`AI_AGENT`) was tried first and also failed
live: kimi-legacy sets no such variable at all.

**Actual fix: process ancestry via `/proc`.** `resolve_agent_auto()` in
`bin/mcp-server-p7` now checks three signals in order: `AI_AGENT` env
(most reliable when a CLI sets it, confirmed present for Claude Code) →
walk `/proc/<pid>/status`'s `PPid` chain up to 8 levels, reading each
ancestor's `/proc/<pid>/cmdline` for a "kimi" or "claude" substring
(cooperation-independent — works regardless of what the spawning CLI
does or doesn't set) → `clientInfo.name` (kept as a last-resort
fallback). Confirmed live: kimi-legacy's ancestry contains `"Kimi Code"`
and `kimi-legacy -y -p ...`, correctly resolving to `kimi` even though
`claude` also appears further up the same ancestry chain (this was a
Claude-dispatched Kimi call) — the nearer match wins, which is the
correct behavior since it reflects the actual immediate caller.

**Also added:** `p7_detected_agent`, a side-effect-free MCP tool
reporting both resolution defaults (`p7_memory_update` vs.
`p7_memory_summary` have different fallback-when-ambiguous defaults) and
all three raw signals. Exists specifically so this class of bug doesn't
need a temporary debug log line plus a live dispatch to diagnose again —
just call the tool.

**Earlier idea considered and superseded:** `session_catchup` doesn't
auto-detect at all, it takes an explicit `client` param from the caller.
That's a reasonable alternative shape, but the ancestry-based fix solves
`agent='auto'` directly without requiring every caller to be more
explicit, so it was preferred.

## related

[[feedback-kimi-dispatch-pattern]] (kimi-cli MCP integration notes)

#,,,.,.,,,,,,,,,.,,,,,,,.,,..,.,,,,.,,..,,.,,,..,,...,..,,,..,.,.,,,,,,.,,...,
#LNCSH2WUHTDIAVNP3CYSO5OB7UGK2JLZMZU5GISFOBCW5OR5MFFJQIKMTYK4CUVF4M2OEASZMFKGA
#\\\|VQYFCMFDVY24RFEVGGKMM5IPC34UBPQQ72THS52SHKBROGLGP5I \ / AMOS7 \ YOURUM ::
#\[7]KZBRWEYKH6RFSN43S6TQRQPXWAZQMWAE537B64HMZ3Q7SR2WQOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
