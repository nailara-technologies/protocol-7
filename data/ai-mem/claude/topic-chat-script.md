---
name: bin/chat — multi-model conversation script
description: file-backed chat system for user+kimi+claude, current state and planned features
type: project
originSessionId: 327ba945-ac12-456a-985f-690320d1550f
---
bin/chat is fully implemented and operational at bin/chat (~950 lines).

## current state (2026-05-14, session 23)

**dispatch:**
- kimi: `p7c kimi.ask-reply <b32r-encoded>` — reply captured and written to history
- claude: inbox file at `data/chat/inbox/claude-code` — claude polls and replies via bin/chat

**caller detection:**
- auto-detected via `/proc/$PPID/comm`: `claude` → `claude`, `Kimi Code` → `kimi`
- override: `P7_CHAT_CALLER=<name>` env var

**model names:** `kimi` and `claude` (short form, no `-code` suffix)

**history format:** plain text, `[2026-05-14T13:01:03] <caller>   message`
- lives at `data/chat/channel/<name>/history`
- committable (conversation record)

**implemented features:**
- `:note:` — write to history, skip dispatch
- `:reply-to:N:` — thread marker, quotes line N in dispatch
- `:->>#channel:` / `:->>#channel:N:` — cross-channel context injection
- per-channel persona: `data/chat/channel/<name>/persona`
- `--search` / `--grep` / `--all-channels` — history search with 1-based line indices
- rolling model memory: auto-triggers at 500 lines, summarizes via model, saves to `data/chat/model/<name>/memory`
- `--summarize` — manual memory rotation trigger
- `-summary` — lazy on-demand summary via coding zenka (cached in `summary.md`, stale when history newer)
- `-summary --all-channels` — per-channel + combined ephemeral overview
- no-args: shows timeline (channels + last-active + first sentence of summary)
- `-wait-reply` — indefinite wait by default, `-wait-reply N` for N second timeout
- single-dash long options normalized to double-dash automatically
- xz archive on clear/rotation

**file layout:**
- `data/chat/channel/<name>/history` — committed
- `data/chat/channel/<name>/summary.md` — committed (lazy, coding zenka)
- `data/chat/channel/<name>/persona` — committed
- `data/chat/model/<name>/memory` — committed
- `data/chat/inbox/` — gitignored (transient IPC)
- `data/chat/archive/` — gitignored (xz rotation archives)

**pre-commit hook:** `data/chat/` exempt from signature checking

## planned / open items

- kimi zenka state machine upgrade (watcher-based, same as coding zenka) — fixes overlapping reconnect hang
- bin/chat: coding zenka model as third dispatch target (local inference participant)
- zenka-desk: phase 1 buffer system + panel.chat (see mcp-server-p7-expansions.md phase 5)
- bin/chat phase 2: channels zenka takes over history management

#,,,.,,,,,.,.,..,,,,,,,.,,,..,..,,.,,,...,..,,..,,...,...,.,.,.,,,.,.,,,,,..,,
#O6TRPEZLLNXCYITT2VUAW3ACQIHXHYAICFODYJUK5V5CP3CROMXDN77ST33FRPM2SHXT5F4KIZF56
#\\\|CGNXG3MQTOYO644WKWTIX7KTPPVWD23UPWRELFGK2VB5ZADQ7NF \ / AMOS7 \ YOURUM ::
#\[7]YBZIBGVX7W677TBBSRTNEJL2QM3WETXHJRJD6XWMJTGHMC2DOYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
