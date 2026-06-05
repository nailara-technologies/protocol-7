## task: chat-mcp-ascii-frame-upgrade

## dispatch
upgrade the chat system on two fronts: (1) MCP server gets a lightweight
notification side-channel so models see incoming messages without polling;
(2) bin/chat display is upgraded to use ascii frame idiom for the timeline
and history views. read first: `bin/chat` (full); `bin/mcp-server-p7`
(tool dispatch section ~lines 762-920, chat tool loader ~630-640, main loop);
`modules/mcp.tools.chat` (existing chat tool definitions);
`data/yaml/ascii-frames/session-catchup.yaml` and `task-queue.yaml`
(separator-stretch frame examples); `data/yaml/ascii-frames/memory-composite.yaml`
(progress mode single-line example). keep bin/chat self-contained — it cannot
call zenka modules directly; frame rendering must either be inline or via
`p7c memory.eval-code` with a graceful fallback when p7c/zenka is unavailable.

## part 1 — MCP notification side-channel

the model (kimi or claude) cannot see new chat messages while busy unless it
polls. the mcp server already communicates via STDOUT (JSON-RPC) and STDERR
(log_msg). kimi appears to see STDERR output between tool calls.

**notification hook — minimal, zero-background-thread:**
- add a `check_chat_pending()` sub to mcp-server-p7 that stat-checks the
  newest mtime across all `data/chat/channel/*/history` files. store the
  last-checked mtime in a package var (`$last_chat_mtime`). update it each
  time a chat tool is called (so the baseline is "last time we looked at chat").
- call `check_chat_pending()` at the TOP of the tool-call dispatch handler
  (before dispatching the actual tool). if new messages exist, print a single
  compact line to STDERR:
  `[chat] new message(s) — call p7_chat_channels to see active channels`
  do NOT spam: skip the hint if the current tool call IS a chat tool (avoid
  recursive hints). rate-limit to at most once per 30 seconds regardless.
- also call `check_chat_pending()` once at the bottom of the MCP main loop
  iteration (after writing the JSON-RPC response) so the model sees the hint
  in the same output flush.
- no inotify, no threads, no event loop changes — pure stat() polling piggybacked
  on existing tool call cadence. if the model is idle (not calling tools),
  no notification fires — that is acceptable.

**new MCP tool: `p7_chat`** (unified convenience entry point):
- zero-args call → equivalent to `bin/chat` no-args: returns a compact channel
  timeline (channel name + age of last message + first line of summary if cached).
  format it as plain text with the .:[ ]::[ chat ]:.  frame idiom rendered
  inline (hardcoded, not via zenka — just the string, no eval needed for a
  fixed-width summary).
- with `channel` arg → reads last 20 lines of that channel's history (delegates
  to the existing `tool_p7_chat_read` logic).
- with `message` arg → sends to default channel (delegates to `tool_p7_chat_send`).
- with `channel` + `message` → send to named channel.
- description must make clear it is the go-to zero-config entry: "read or send
  chat messages. no args = show active channels. message= to send. channel= to
  scope. combines p7_chat_channels + p7_chat_read + p7_chat_send."
- add it to `modules/mcp.tools.chat` alongside the existing five tools.

## part 2 — bin/chat ascii frame display

upgrade the display output of `bin/chat` (the tty path only — non-tty stays
plain text) to use the `.:[ ]::[ ]:.` frame idiom. three views to upgrade:

**1. timeline view (no-args):** currently shows a list of channels. wrap it in
a separator-stretch frame — the top is `.:[ ]::::::::::::::::::::::::::::::[ chat ]:.`
(hardcoded at terminal width or 72 chars whichever is smaller). each channel
line becomes a content row. bottom is `:.......` dotted rule. render the frame
inline in bin/chat using print — no zenka dependency, just string construction
matching the `.:[ width ]::[ label ]:.` idiom. use `terminal_size()` (already
imported) for width.

**2. history view (`-channel <name>`):** add a single-line channel header above
the history output: `.:[ #<name> ]::::::::::::::[ last N messages ]:.` using
the same inline renderer. the history lines themselves stay as-is (no per-line
framing).

**3. send confirmation:** after a successful send, print one line:
`.:[ sent ]::[ #<channel> ]:.` — a minimal slot-spring confirmation line. no
full frame needed, just the top border as a status stamp.

**inline frame renderer** — add a `frame_line($left_slot, $label, $width)`
sub to bin/chat that produces one `.:[ $left_slot_padded ]::[ $label ]:.` line
at exactly `$width` chars, using the slot-spring rule (left slot pads to fill).
for separator-stretch (no left slot value), call `frame_line('', $label, $width)`.
this is ~10 lines of string math, no external deps.

## design constraints

- **zero-config-convenient**: calling `p7_chat` with no args from any model
  session gives a useful channel overview immediately. no setup, no channel
  required. the notification hint is automatic and self-explanatory.
- **non-tty clean**: bin/chat plain-text output (pipes, redirects) must remain
  unchanged. the frame rendering is tty-only, gated on the existing
  `-t STDOUT` check already used for ANSI color.
- **graceful degradation**: if p7c or the zenka is unavailable, bin/chat falls
  back to the current plain-text output. the MCP server notification hint omits
  gracefully if the chat dir doesn't exist.
- **no new external deps**: bin/chat already has AMOS7, IO::Compress::Xz,
  Getopt::Long. mcp-server-p7 already has JSON, POSIX. use what's there.
- **rate limiting on hints**: the STDERR notification must not fire on every
  tool call. 30-second cooldown via `$last_hint_time` package var.

## acceptance
- calling `p7_chat` (no args) from the kimi MCP session returns a formatted
  channel timeline inside a `.:[ ]::[ chat ]:.` frame.
- calling `p7_chat message="hello"` sends to the default channel and confirms.
- when a new chat message arrives WHILE kimi is doing other tool calls, kimi
  sees a one-line STDERR hint within the next tool call response.
- `bin/chat` (no args, tty) shows the timeline inside the ascii frame.
  `bin/chat -channel general` shows the history with a channel header line.
- plain-text output (non-tty) is unchanged.
- no AMOS7 signature stubs in new or edited files.

#,,..,...,...,...,...,..,,,,.,,.,,...,,,.,,,,,..,,...,...,...,...,..,,.,.,.,,,
#WQEHBP3ZLOJFB4GIAHMWDTC6ISMZLI2VN4SGJKN25EDBT4QOQ7R6PILZXOHYCRGTLUNAPBLCVTRXA
#\\\|G36I3G6KJUR7B32CSY7PDC4J4TKB3422AO5O6K2KXPKPWDHKIX6 \ / AMOS7 \ YOURUM ::
#\[7]DIU226GS54CBLDSJGVFZI2XSF2RMPS6JP257LW3CA2FEGO4WA2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
