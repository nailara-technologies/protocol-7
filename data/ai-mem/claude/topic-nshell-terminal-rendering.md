---
name: nshell-terminal-rendering
description: "nshell terminal rendering bugs, fixes, and diagnostic patterns"
metadata:
  node_type: memory
  type: project
---

## `(0)!TERM!` — invalid cmd_id prefix bug [FIXED 2026-06-02]

**Symptom:** First command after connect gets `(0)clear\n`, rejected by `base.handler.command` with `"invalid command id syntax or length"`. Fires 3× rapidly on session start.

**Root cause:** `base.handler.command` orphaned route handler (lines ~1470, ~1516) generated `(0)!TERM!` when processing prefix-less replies (`cmd_id == 0`). The `clear` command triggers this via SIZE reply orphan paths. The `!TERM!` backchannel at line ~565 already guarded with `$tgt_cmd_id > 0`, but the orphaned-route fallback paths did not.

**Fix:** Added `$cmd_id > 0` guard before `sprintf "(%d)!TERM!\n"` in both orphaned route handlers.

**Defense in depth:** `base.protocol-7.command.send.local` line 107 changed wrap regex from `^(\d+)$` to `^([1-9]\d*)$` so `0` never gets wrapped as `(0)`.

**Diagnostic lesson:** Log the FULL raw input line (`line=['...']`) instead of stripping the bad command via regex substitution. The strip-regex was hiding the command body, making it impossible to see the actual input was `(0)!TERM!`.

---

## Terminal overflow path [FIXED 2026-06-02]

**Symptom:** Trailing underscore cursor artifact when buffer exceeds terminal width.

**Root cause:** `nshell.editor.process` used `terminal_size()[1]` (rows) instead of `[0]` (cols) for width check. `AMOS7::TERM::terminal_size()` returns `(cols, rows)` — NOT `(rows, cols)`.

**Fix:** Use `[0]` for cols. Overflow path now clears line with `\r\e[2K` + reprints full buffer.

---

## Green SIZE replies [FIXED 2026-06-02]

**Symptom:** After empty submit, subsequent SIZE replies appeared in green (cursor color) instead of blue (text color).

**Root cause:** Empty submit cursor redraw in `nshell.editor.process` printed green underscore without resetting color afterward. Subsequent reply handler inherited green.

**Fix:** Added `\e[0m` + `$colors{'p7_fg_0004'}` reset after the underscore redraw.

---

## Reply erasing last line [FIXED 2026-06-02]

**Symptom:** Last line of multi-line reply (e.g., SIZE) was overwritten by cursor redraw.

**Root cause:** `nshell.handler.command_reply` cursor redraw started with `\r` on the same line as the last reply output if payload lacked trailing newline.

**Fix:** Added `print "\n" if defined $payload_str && $payload_str !~ m{\n\z}` before cursor redraw.

---

## Async reply during VIEWING_HISTORY [FIXED 2026-06-02]

**Symptom:** When Ctrl+O cycling through history, a SIZE reply from a previous command overwrites the displayed history entry. Cursor is redrawn on empty line; history text is lost.

**Root cause:** `nshell.handler.command_reply` prints reply + cursor without knowing the terminal still shows a history entry from `VIEWING_HISTORY` mode.

**Fix:** Two-step approach:
1. Before printing reply: `print "\r\e[2K"` if `current_mode == 2 && display_buffer` — clears history remnants
2. After reply + cursor redraw: re-render via `nshell.render.viewport` if still in `VIEWING_HISTORY` mode

**Pattern:** Any async terminal output handler that redraws cursor should check for active UI state (search, history, etc.) and restore the displayed content after output.

---

## Key files

- `modules/base.handler.command` — cmd_id validation, orphaned route handler, `!TERM!` backchannel
- `modules/base.protocol-7.command.send.local` — cmd_id wrapping for protocol-7 routing
- `modules/nshell.editor.process` — newline submit, overflow path, color reset
- `modules/nshell.handler.command_reply` — reply display, cursor redraw, history restore
- `modules/nshell.render.viewport` — terminal width, horizontal scroll, cursor rendering

#,,,,,...,,,,,,,,,,,,,,..,,..,,,.,...,,.,,.,.,..,,...,...,..,,,,.,..,,,..,.,.,
#XS7ZCWB5TGFNRKB6WW7TVEFFZHFM5FKTWOU62ZBJ5YCQMV4TEUYUNJTB5KIBSTHLVOO5DZHFCOIAE
#\\\|ABMXGGD5B6N236PP2JOAZOBEKLE7JVLDPCNNX73CABO4GATUP6B \ / AMOS7 \ YOURUM ::
#\[7]QZAVZMCZNHERP4O3F4BN7YPCMZVGIJW36YWXX3SOJQ7WP45W52BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
