---
name: feedback-check-local-session-log-before-kimi-continue-roundtrip
description: before spending another kimi_continue round-trip to re-fetch data a session already produced, check local free sources first -- kimi-legacy -r session log dir, session_catchup tool, or the coding zenka's own task buffer (coding.show-buffer)
metadata:
  node_type: memory
  type: feedback
  originSessionId: b9319112-4c00-4c0f-9559-fd4842eee849
  modified: 2026-08-06
---

2026-08-06: during the resumed `840b069f` task-archive audit, I asked kimi
for a prose summary via `kimi_continue`, the summary dropped the actual
filenames I needed, so I paid for a *second* `kimi_continue` round-trip
(same session, `auto_summarize=false`) just to get the raw list — data
kimi had already fully computed and stated in the prior turn. User pointed
out this was avoidable: the same data was already retrievable for free
via `kimi-legacy -r <uuid>` (kimi's own local session-log directory),
the `session_catchup` MCP tool, or — confirmed live in this session via
`coding.show-buffer T-7903001-F` — the coding zenka's own full-content
task buffer, which had already captured the complete unsummarized output.

**Why:** every `kimi_continue` call re-sends the accumulated session
context and re-runs live reasoning, so it's real token/budget cost even
when the actual ask is "just show me what you already told me." Local
session logs/buffers hold that same content for free.

**How to apply:** before dispatching another `kimi_continue`/`claude_continue`
purely to re-extract or reformat data from a turn that already completed,
check local sources first: `kimi-legacy -r <session-uuid>` session log dir,
the `session_catchup` tool, or (if the task ran through the coding zenka)
`coding.show-buffer <task-id>` for the full unsummarized content. Only
fall back to a live continue call if the data genuinely wasn't captured
anywhere, or if new reasoning (not just reformatting) is actually needed.

#,,,.,..,,,,.,,,.,,.,,...,,,,,,.,,,,,,,.,,,..,..,,...,...,.,.,,..,.,.,,..,,,.,
#FMZRKHEACRNATU3PE4HDQJVUNUMLJSUIMUXA4MKBINDWHXGNCJ7KRFUKGE2JSKMJGWUKE3SBAH3H4
#\\\|7UQ52CD6QIXXASER6TDFRWGUEE56XJ6ZFURBWQCL3E7FCDMPVUW \ / AMOS7 \ YOURUM ::
#\[7]RBXQHKLCJ46W4BAOIVHWHMPJKROV3HAGWBWU6NA53Z4OAEUT2WBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
