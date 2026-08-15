---
name: reference-nshell-ss3-arrows-and-live-debug-probe
description: terminal DECCKM/SS3 arrow-key gotcha (fixed 0747face5) and how to live-probe a running nshell session via debug-status/char-add without disturbing it
metadata: 
  node_type: memory
  type: reference
  originSessionId: be5d0280-7c97-460f-b8e3-aff23f4948b0
  modified: 2026-08-12T18:08:35.161Z
---

**The gotcha**: a terminal in application-cursor-key mode (DECCKM) sends arrow
keys as SS3 (`\eOA`/`\eOB`/`\eOC`/`\eOD`) instead of the normal CSI form
(`\e[A`/`\e[B`/`\e[C`/`\e[D`). Nothing in Protocol-7 toggles DECCKM itself —
it gets set by whatever else ran in that terminal (another program, the
emulator's own default, etc.) and Protocol-7 code has to be defensive
regardless of who flipped it. `modules/nshell.read_from_buffer` already
normalized Home/End for exactly this reason (`\e[H`/`\eOH`, `\e[F`/`\eOF`)
but the four arrow keys never got the same treatment — so a session in
DECCKM mode had completely dead Up/Down/Left/Right while PageUp/PageDown
(`\e[5~`/`\e[6~`, no SS3 variant) kept working. Fixed in 0747face5 by adding
an `%ss3_arrow_map` normalization at the same choke point, ahead of every
mode-specific dispatch.

**How to apply**: any place in this codebase that pattern-matches raw
terminal escape sequences (not just nshell) should accept both CSI and SS3
forms for arrow/cursor keys, the same way Home/End already do here. If a
future bug report is "some keys work, arrow keys silently do nothing," check
`cat -v` output for that exact terminal/tab first — `^[OA` vs `^[[A` settles
it in one step.

**Live-probe technique for a running nshell session** (no restart, no
disturbing the user's actual input): nshell registers debug cube commands
per `configuration/zenki/nshell/start` (`char-add`, `debug-status`). Address
a specific session by its session id from `list subnames <user>` — e.g.
`<session-id>.debug-status` — routed via `mcp__protocol-7__p7_command`.

- `debug-status` is **safe on any live session** regardless of how it was
  started: it just reads `<nshell.state>` (mode/history-index/editor-buffer)
  and returns it, no injection. Good for "ask the user to press a key, then
  immediately check state" round-trips.
- `char-add` (key injection) only actually takes effect if the zenka
  process was started with `-no-tty-debug` — otherwise the injected bytes
  queue into `<nshell.buffer.debug_input>` but the real event loop is in
  `-t STDIN` mode and never reads that buffer, so injection is silently a
  no-op. Check `ps aux | grep nshell` for the flag before trusting a
  `char-add` result; a normal interactive session (attached to a real pts)
  will not honor it.
- The session id printed by `list subnames <user>` changes whenever the
  zenka process restarts/reconnects, even though the terminal keeps running
  the "same" shell session from the user's point of view — re-run
  `list subnames` if a previously-good session id starts erroring
  `client not present`.

See [[feedback-config-reload-clobber]] for a different but related class of
bug: runtime state silently diverging from what the code on disk would
predict — always worth ruling out process staleness (check the running
pid's start time vs the last relevant file mtime) before concluding a fix
on disk didn't work.

#,,.,,,,,,,.,,..,,,..,,,.,,..,,,,,,,.,,,.,,.,,..,,...,..,,...,.,,,,,,,,..,.,,,
#RUTPCDVG4KUZLXGXLKH7E4PO43ESUJHVKGY7DF46UDORJESMDJTEU7DSQ7NJJRBGAQ2UMDJXVB4FU
#\\\|YMXRPNIXKLG6PN6Z6J2QTLFEZ66HKALRYAI5DBQRMNF6HF5IUZ3 \ / AMOS7 \ YOURUM ::
#\[7]3LYKFM7IXB2YNVIPABE5W5YJBEMKCZI7Q2NBFVIKAQP443FEAYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
