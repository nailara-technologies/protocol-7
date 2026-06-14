# Task: ticker notify mode, phase 2 - deferred dismiss-reply + top position

## Environment
- Project: Protocol-7 (`/data/projects/protocol-7`), branch `base`
- Language: Perl 5 + Gtk3
- Ticker zenka: `modules/ticker.*`
- Builds on: commit `23c0b3ede` (notify mode, dismiss-on-hover) and
  `read-me/md/session-state/TASK_TICKER_NOTIFY_MODE.md` (phase 1, done)

## Background
Phase 1 added `ticker.cmd.read-file-notify`: a one-shot message that hides
itself once the user hovers over it (fade-out completes -> `$window->hide`,
`<ticker.notify.dismissed> = TRUE`, see `modules/ticker.handler.fade_out`
lines ~39-55).

This phase adds two independent features on top of that.

## Feature A: `:wait-dismissed:` deferred reply

### Syntax
`ticker.read-file-notify :wait-dismissed: <path>` - the flag is a
whitespace-delimited token at the start of `$call->{'args'}`, stripped
before the path is used. Accept `:wait:` as an alias for the same thing
(canonical name is `:wait-dismissed:`; both parse identically).

### Behavior
- Without the flag: today's behavior, immediate `{mode=>true|false,
  data=>'...'}` reply (unchanged).
- With the flag, and only if the file loaded successfully (no error):
  - return `{ 'mode' => qw| deferred | }` instead of the immediate reply
    (this is the existing mechanism in `base.handler.command` /
    `modules/base.callback.cmd_reply` - `$call->{'reply_id'}` is already
    set up by the dispatcher for this purpose),
  - store `$call->{'reply_id'}` so it can be resolved later (e.g.
    `<ticker.notify.pending_reply_ids>` - a list/array, since a second
    `read-file-notify` could arrive before the first is dismissed; see
    "multiple pending" below).
  - if the load *fails* (`$loaded->{'error'}` defined), reply immediately
    as today (`{mode=>false,...}`) - do NOT defer an error.

### Resolving the deferred reply
In `modules/ticker.handler.fade_out`, at the existing dismiss point (where
`<ticker.notify.dismissed> = TRUE` is set, ~line 46):
- for each pending reply id in `<ticker.notify.pending_reply_ids>`, call
  `<[base.callback.cmd_reply]>->( $reply_id, { 'mode' => qw| true |, 'data'
  => 'notify dismissed' } )`,
- clear the list.

### Multiple pending notifications
If `read-file-notify` is called again (new message) before a previous
`:wait-dismissed:` call's message was dismissed:
- the earlier deferred reply has NOT yet fired. Decide (and document the
  choice in code comments):
  - **option 1 (recommended, simplest)**: the new notification replaces the
    displayed content immediately (current behavior: `read-file-notify`
    always shows the latest message). When *that* message is eventually
    dismissed, resolve *all* pending reply ids in
    `<ticker.notify.pending_reply_ids>` at once (they were all "waiting for
    the user to look at the ticker", and the user just did).
  - this means a flood of `:wait-dismissed:` calls all resolve together on
    the next dismiss - acceptable for a status-ping use case.
- if termination-after-dismiss is enabled
  (`ticker.notify.terminate_after_dismiss`), resolve all pending replies
  *before* exiting.

### Include content checksum in the reply
The dismiss reply's `data` should include the content checksum of the
message that was actually shown/dismissed, for chaining into workflows -
e.g. `'notify dismissed [chksum=<...>]'` using `<ticker.content.chksum>`
(already maintained by `ticker.load_file_content`). Keep it a single-line
string (per [[feedback-cmd-data-must-be-string]] - `mode=>true` data must
be a single line, no embedded newlines).

## Feature B: notify-mode top position by default

### New config
`ticker.notify.use_top_position` (boolean, default **enabled** / TRUE).

### Behavior
- When `<ticker.display.mode>` switches to `notify` (in
  `ticker.cmd.read-file-notify`) and `ticker.notify.use_top_position` is
  enabled (`<[base.cfg_bool]>`):
  - apply the `top-strip` placement profile instead of whatever
    `<ticker.window.profile>` is currently set to (don't overwrite
    `<ticker.window.profile>` itself - just call
    `<[ticker.cmd.set-window-profile]>->({'args' => 'top-strip'})` or
    equivalent, so the underlying config value is preserved).
- When switching back to `continuous` mode (`read-file-cont` /
  `read_file`), restore the profile from `<ticker.window.profile>` (default
  `bottom-strip`) - i.e. continuous mode is unaffected and keeps using
  whatever profile it always used.
- If `ticker.notify.use_top_position` is FALSE, notify mode uses
  `<ticker.window.profile>` same as continuous mode (no position switch).
- Swap-edge mode: if `ticker.mouse.swap_edge` is enabled, this top/bottom
  default should not fight with swap's own top/bottom toggling
  (`ticker.cmd.swap_profile`) - simplest approach: notify mode's top
  position override only applies when swap-edge is *not* active for that
  window; if swap-edge is active, leave swap's existing logic in control
  and skip the override (flag this assumption in a code comment - it's a
  judgment call, ok to revisit).

## Files likely involved
- `modules/ticker.cmd.read-file-notify` - parse `:wait-dismissed:`/`:wait:`
  prefix, defer reply, apply top-position profile
- `modules/ticker.handler.fade_out` - resolve pending deferred replies on
  dismiss
- `modules/ticker.set_default_values` - default
  `<ticker.notify.pending_reply_ids> = []`,
  `<ticker.notify.use_top_position> //= TRUE`
- `modules/ticker.cmd.read-file-cont` / `read_file` - restore profile when
  switching back to continuous (if it was overridden by notify's top
  position)

## Constraints
- Follow [[feedback-cmd-data-must-be-string]]: deferred reply's final
  `data` is a single-line string.
- `TRUE`/`FALSE` constants, not bare `1`/`0`.
- Lowercase comments, `[ word ]` bracket annotations.
- Don't break phase 1 (immediate-reply `read-file-notify` without the flag,
  dismiss-on-hover, `terminate_after_dismiss`) or continuous/swap-edge
  modes.
- After editing, the user runs `bin/Protocol-7 sourcecode
  update-signatures` themselves - no `#,,.,,,...` stub lines.

## Suggested test plan
1. `ticker.read-file-notify <path>` (no flag) - immediate reply, unchanged
   from phase 1.
2. `ticker.read-file-notify :wait-dismissed: <path>` - command hangs
   (deferred); hover over the ticker to dismiss; confirm the caller then
   receives `TRUE notify dismissed [chksum=...]`.
3. Two back-to-back `:wait-dismissed:` calls with different files - both
   callers receive their reply after a single dismiss of the second
   message.
4. `:wait:` alias behaves identically to `:wait-dismissed:`.
5. With `ticker.notify.use_top_position` at its default (TRUE): notify
   message appears at the top strip; after dismiss, a subsequent
   `read-file-cont` call shows content at the bottom (or wherever
   `ticker.window.profile` points), confirming the profile was restored.
6. Set `ticker.notify.use_top_position = 0`: notify message appears at the
   same position as continuous mode.
7. With `ticker.mouse.swap_edge` enabled: confirm swap-edge continuous mode
   still works (top/bottom toggling on hover) and notify mode doesn't fight
   it (per the documented assumption above).

## Note: Feature C (mouse-click events / `ticker.mouse-events` STRM) is a
separate, larger phase 3 - not part of this task. It was discussed but
needs its own design pass (STRM registration, event filtering by name list,
content-checksum tagging of click events, left/right-click semantics per
mode). Flag to the user if you think phase 2 work here would make phase 3
easier or harder to retrofit, but do not implement phase 3 now.

#,,,.,..,,,,,,,..,...,..,,,..,...,..,,.,.,,.,,..,,...,..,,...,,,,,,,,,,..,,.,,
#JMNDVRBVY6ZMTJRQIW44QTSYEYIHUEB2PAQJ5EEVL5XWVZT46QH3CY7O3EB6PQD4OHMHUBZFDHZUE
#\\\|24CLXO7KQHNFSQY2PEXWHIX3X37RLD6TMR35FYE2JZYX4V2NJMN \ / AMOS7 \ YOURUM ::
#\[7]RLBUPKVW75KMVSMMZ3LUNPSEGJVDHJ533WEKJ6C5YCTVVUT45UDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
