## user-edit vertical viewport + one-line flicker fix

Date: 2026-08-16

### what changed
- `src/user-edit.form.render` now implements a terminal-aware vertical viewport.
  - Caches terminal size via `user-edit.setup_stdin_watcher` and reacts to `SIGWINCH` via new module `user-edit.handler.term_resize`.
  - Slices the rendered frame to `budget = term_rows - hint_lines`.
  - Walks the frame descriptor slots to locate the active field and keeps it inside the visible slice by adjusting `scroll_top`.
  - When the title/header is scrolled out of view, prepends one empty content row as top padding so the first visible field is not flush against the terminal top edge.
- Removed the unconditional trailing `\n` after the rendered frame in interactive mode.
  - In raw terminal mode `\n` is LF-only; a bare newline after a frame that already fills the screen scrolls the top line off by one, producing the "flicker/jump by one line" symptom.
  - The trailing newline is now only emitted when `help_visible` is true, because the multi-line hint block needs the next row.
  - Also removed the leading blank `print "\n"` before the hint block.

### key debugging insight
The initial report said "no change" after the viewport code was added. A temporary `[viewport debug: ...]` printf in the render path showed the branch was actually being reached (`rows=27 budget=27 total=27 vp=off`). The real problem was not viewport bypass but the extra newline: the form happened to be exactly the terminal height, so the unconditional newline scrolled the screen every render.

### testing notes
- Python pty harness is useful but timing-sensitive; a fresh `v7.user-edit start taeki` process may take several seconds before emitting the first frame.
- When frame height == terminal height, the screen should not scroll.
- When frame height > terminal height, the viewport should slice to exactly the terminal height and scroll with the active field.

### related files
- `src/user-edit.form.render`
- `src/user-edit.setup_stdin_watcher`
- `src/user-edit.handler.term_resize`
- `cfg/zenki/user-edit/subroutines.load-early`

#,,..,.,.,,..,,,.,,..,...,,..,,..,,,.,,,.,,,.,..,,...,...,.,,,..,,...,,..,...,
#I52PK5HWT6DDWLY7YSIFA6T7MQ2R4H6LHHOKHDTRSJXZQDX33EMPXKEDB33AXVYNJALM6RTGUWZUI
#\\\|IZIFTUUPDOWFZ6IGSZ5CHBDEQ2ZNS4APPJJJD4O6L5JUEXSTBPU \ / AMOS7 \ YOURUM ::
#\[7]MBGDMSKO5L6IKYRT54GQUUU2FDOGVT3GYHMGO42GXDJIBZGLQCDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
