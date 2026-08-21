# Task: ticker "notify" display mode (dismiss-on-hover, one-shot)

## Environment
- Project: Protocol-7 (`/data/projects/protocol-7`), branch `base`
- Language: Perl 5 + Gtk3
- Ticker zenka: `src/ticker.*`
- Related prior work: `read-me/md/session-state/CLAUDE_DEBUG_TICKER_SWAP.md` (swap-edge mode, now stable - do not break it)

## Background
The ticker currently has one display mode, driven by `ticker.cmd.read_file`:
it loads a file's content, parses it for scrolling display, and (re)starts
the continuous scroll/fade animation. Hovering fades the ticker out; leaving
fades it back in. This loop runs forever ("continuous" mode).

## Goal
Add a second mode, "notify": a one-shot message that the user dismisses by
simply hovering over the ticker (no click). After dismissal the ticker goes
idle/hidden until the next notify call. Use case: status pings from the
coding zenka ("task #42 finished") shown briefly, dismissed by glancing at
them.

## Required changes

### 1. Extract shared content-loading helper
Factor the chksum/slurp/parse block out of `src/ticker.cmd.read_file`
into a new internal helper `src/ticker.load_file_content` (NOT a `.cmd.`
module - per [[feedback-cmd-data-must-be-string]] internal helpers must
return plain Perl values, not `{mode,data}`).

- Signature: takes a file path, returns `{ updated => TRUE|FALSE, error =>
  $msg }` or similar - whatever is simplest for both callers to branch on.
- It should perform: permission/existence checks, chksum comparison against
  `<ticker.content.chksum>`, slurp + `<[ticker.parse_text]>` + bookkeeping
  (`<ticker.content.chksum>`, `<ticker.content.txt>`, `<ticker.content.len>`,
  `<ticker.current_file>`), exactly as `read_file` does today.
- It must NOT call `<[ticker.start_animation]>` or do mode-specific
  show/hide - that stays in the two `.cmd.` wrappers below.

### 2. `src/ticker.cmd.read-file-cont` (rename/alias of today's `read_file`)
- Calls the shared loader.
- Sets `<ticker.display.mode> = 'continuous'`.
- On update: `<[ticker.start_animation]> if !<ticker.animation_started>`
  (same as today).
- Returns `{mode=>true|false, data=>'...'}` as `read_file` does today.
- Keep `src/ticker.cmd.read_file` working too - either as a thin alias
  calling this, or update its white-list entry to point here. Don't break
  existing callers/configs that still use `read_file`.

### 3. `src/ticker.cmd.read-file-notify` (new)
- Calls the shared loader.
- Sets `<ticker.display.mode> = 'notify'`.
- Clears any pending "dismissed/idle" state (see #4) so the message shows
  even if the previous notification was dismissed while the window was
  hidden.
- Ensures the window is visible (`$window->show` / `set_visible(1)` if it
  was hidden by a previous dismissal) and (re)starts the fade-in/animation,
  same as `read-file-cont` does on update.
- Returns `{mode=>true|false, data=>'...'}`.

### 4. Dismiss-on-hover behavior
Hook into `src/ticker.handler.fade_out`, at the point where
`<ticker.fade_opacity> == 0` (fade-out complete, around line 36-58):

- If `<ticker.display.mode> eq 'notify'` (and we are NOT in swap-edge mode -
  swap-edge's fade-out-at-0 branch already does something different and must
  stay untouched):
  - hide the window: `$window->set_visible(0)` (or
    `<[base.X-11.hide_window]>`/whatever the existing hide helper is - check
    `src/base.X-11.*` for a `hide_window` counterpart to
    `unhide_window`),
  - clear `<ticker.content.txt>` / stop the scroll animation so nothing is
    drawn underneath when shown again,
  - set a flag `<ticker.notify.dismissed> = TRUE`,
  - do NOT re-arm fade-in. The existing mouse-leave handlers
    (`ticker.open_window`'s `leave-notify-event`, and
    `ticker.handler.check_pointer`'s poll-based leave detection) must check
    `<ticker.display.mode> eq 'notify' and <ticker.notify.dismissed>` and
    skip starting `fade_in` in that case - the ticker stays hidden/idle.

- If `<ticker.display.mode> eq 'continuous'` (or unset), behavior is
  unchanged from today.

### 5. Optional teardown after dismiss
New config `ticker.notify.terminate_after_dismiss` (boolean, default off /
0). If enabled, instead of hiding and going idle in step 4, the zenka
terminates (e.g. `Gtk3->main_quit` / however the ticker zenka cleanly exits
today - check `src/ticker.main_loop` / shutdown path).

- Document clearly in the config comment that this trades a small
  startup flicker + latency on the *next* notification (zenka must be
  restarted, presumably via v7 on-demand) for not leaving an idle process
  around.
- Default (off) is "hide and stay idle, ready for the next call".

## Files likely involved
- `src/ticker.cmd.read_file` -> extract loader, rename/alias
- `src/ticker.load_file_content` (new internal helper)
- `src/ticker.cmd.read-file-cont` (new, or the renamed `read_file`)
- `src/ticker.cmd.read-file-notify` (new)
- `src/ticker.handler.fade_out` - dismiss-on-complete branch
- `src/ticker.open_window` - `leave-notify-event` handler, check
  `ticker.notify.dismissed`
- `src/ticker.handler.check_pointer` - poll-based leave detection, same
  check
- `src/ticker.set_default_values` - default `<ticker.display.mode> =
  'continuous'`, `<ticker.notify.dismissed> = FALSE`,
  `<ticker.notify.terminate_after_dismiss> //= FALSE`
- `cfg/zenki/ticker/subroutine.white-list` - add the two new
  `.cmd.` entries (and `read-file-cont` if `read_file` is renamed)
- `cfg/zenki/ticker/source/` - add corresponding
  `ticker.cmd.list_monitors`-style command source files if that's the
  pattern used for other `ticker.cmd.*` (check existing
  `ticker.cmd.swap_profile` / `ticker.cmd.list_monitors` entries for the
  convention)

## Constraints
- Do not break continuous mode (default, used today) or swap-edge mode.
- Follow [[feedback-cmd-data-must-be-string]]: `.cmd.` modules return
  `{mode=>'true'|'false', data=>STRING}` only; structured/internal state
  lives in non-`.cmd.` helpers.
- `TRUE`/`FALSE` constants, not bare `1`/`0`, per project convention.
- Lowercase comments, `[ word ]` bracket annotations, per
  `data/yaml/code-style/CONVENTIONS.yaml`.
- After editing, run `bin/Protocol-7 sourcecode update-signatures` (the user
  will run/sign this themselves - do not add `#,,.,,,...` stub lines, that
  blocks signing).

## Suggested test plan
1. `ticker.read-file-cont <path>` - confirm existing continuous scroll/fade
   behavior unchanged.
2. `ticker.read-file-notify <path>` - ticker shows the message; hover over
   it -> fades out -> window hides and stays hidden after mouse leaves.
3. `ticker.read-file-notify <path2>` while hidden - ticker re-appears with
   new content.
4. With `ticker.notify.terminate_after_dismiss = 1` - after dismiss the
   zenka exits; next `read-file-notify` call restarts it (via v7 on-demand)
   and displays the message (accept the startup flicker).
5. Confirm swap-edge mode (if enabled) still works for continuous mode.

## Open questions for the user (flag, don't guess)
- Exact hide mechanism: is there an existing `base.X-11.hide_window`
  counterpart to `unhide_window`, or should `$window->set_visible(0)` /
  GTK `hide` be used directly?
- Should `read-file-notify` interrupt an in-progress continuous-mode
  animation immediately, or queue until the current scroll cycle ends?
  (default assumption: interrupt immediately, since notify is meant to be
  urgent)

#,,..,,..,..,,.,,,,,.,.,,,,,.,,,.,..,,,,,,..,,..,,...,..,,...,.,.,,..,,..,,,.,
#5EBMTW2CCMTOCQYGXJG7UVCP35GPKUCUYBFQALHGBNRWSBZ7OJD5F4OECYCW6IL5WP2AHJXHRO55C
#\\\|S6MXJZSOKFZRC3B6BU2OFBHFBKAEYEFVLGCFZZQQZYGAYQUSR4L \ / AMOS7 \ YOURUM ::
#\[7]26TT6IK2IKWIISKTI4R3RR2XB4YXU3VSN3ETUNILINA2AC3GMWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
