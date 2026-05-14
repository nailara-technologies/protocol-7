---
name: bin/chat — multi-model conversation script
description: file-backed chat system for user+kimi+claude, current state and planned features
type: project
originSessionId: 327ba945-ac12-456a-985f-690320d1550f
---
bin/chat is fully implemented and operational at bin/chat (~1000 lines).

## current state (2026-05-14, session 23 — complete)

**dispatch:**
- kimi: `p7c kimi.ask-reply <b32r-encoded>` — reply captured and written to history
- claude: inbox file at `data/chat/inbox/claude-code` — claude polls and replies via bin/chat
- mcp: `P7_CHAT_CALLER=mcp` — 5 MCP tools in bin/mcp-server-p7

**caller detection:**
- auto-detected via `/proc/$PPID/comm`: `claude` → `claude`, `Kimi Code` → `kimi`
- override: `P7_CHAT_CALLER=<name>` env var; mcp tools set `P7_CHAT_CALLER=mcp`

**model names:** `kimi` and `claude` (short form, no `-code` suffix)

**implemented features:**
- `:note:` — write to history, skip dispatch
- `:reply-to:N:` — thread marker, quotes line N in dispatch
- `:->>#channel:` / `:->>#channel:N:` — cross-channel context injection
- per-channel persona: `data/chat/channel/<name>/persona`
- `-search` / `-grep` / `-all-channels` — history search with 1-based indices
- rolling model memory: auto-triggers at 500 lines, summarizes via model
- `-summarize` — manual memory rotation trigger
- `-summary` — lazy on-demand summary via coding zenka (cached, stale-when-history-newer)
- `-summary -all-channels` — per-channel + combined ephemeral overview
- no-args: shows timeline (channels + last-active + first sentence of summary)
- `-wait-reply` — indefinite wait by default, `-wait-reply N` for N second timeout
- `-trim N` / `-clear` / `-clear-all` / `-clear-msg N` — history management
- single-dash long options supported (normalized internally); `--` also works
- ANSI colors via AMOS7 %C + terminal_size() tty detection; plain text for non-tty
- xz archive on clear/rotation

**MCP tools (in bin/mcp-server-p7):**
- `p7_chat_send` — send message, optional -channel/-model/-wait-reply
- `p7_chat_read` — read last N lines of channel history
- `p7_chat_summary` — lazy summary (blocks until coding zenka completes)
- `p7_chat_search` — literal or regex history search
- `p7_chat_channels` — list all channels with timestamps

**file layout:**
- `data/chat/channel/<name>/history` — committed
- `data/chat/channel/<name>/summary.md` — committed (lazy, coding zenka)
- `data/chat/channel/<name>/persona` — committed
- `data/chat/model/<name>/memory` — committed
- `data/chat/inbox/` — gitignored (transient IPC)
- `data/chat/archive/` — gitignored (xz rotation archives)

**pre-commit hook:** `data/chat/` exempt from signature checking

## open items / next steps

- bin/chat: coding zenka as third dispatch target (local inference participant)
- zenka-desk: phase 1 buffer system + panel.chat (mcp-server-p7-expansions.md phase 5)
- bin/chat phase 2: channels zenka takes over history management
- kimi flush_on_acquisition inline sub extraction (coding zenka extract-inline-subs template)
- AMOS7::P7 dep-graph module loader (see topic-amos7-p7-loader.md)

#,,,,,..,,,.,,,,,,,..,.,.,.,.,..,,,,,,,.,,,,,,..,,...,...,,..,,,.,.,.,,,,,.,.,
#T4T4NZYXHRLKFBGI6WTL5RF775HZ635XQWDJQ7W3ATHU36MBYW755TFWW7NNBSI35FBMOUYDNNHQQ
#\\\|CIPT6GN4TET5WZXLODTFCRA5H5N7ETSEKJEGET7ABB3G4MWN5LQ \ / AMOS7 \ YOURUM ::
#\[7]EAPVF2JX3W4GXJBPFVBQZEYSMWOXFG724IBNJLBM4P2DUQ2JCKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
