# web-browser zenka: paged multi-position capture + headless-mode fast swap

## why

The interrupted 227-file screenshot triage only ever captured one image per
page — the settled scroll position after the OLD per-pixel auto-scroll
finished (effectively "bottom of page"), never the header, and never
anything in between. This session already built fast single-jump
scroll-position commands (`web-browser.cmd.set-pos-y` / `set-fg-pos` /
`set-bg-pos-y`, see `data/tasks/web-browser-fast-scroll-position-commands.md`
— landed, commit `994cdb17a`) to replace the slow animated auto-scroll, but
nothing yet uses them to capture MULTIPLE positions down a page. Also: the
existing `web-browser.swap_views` double-buffer fade transition (load next
page into background view, cross-fade in) is pointless in headless/batch
capture runs — nobody is watching it, and it costs real wall-clock time
across 227+ pages. This task adds both.

## precedent -- read these first, this is a retrofit onto an existing
## event-driven state machine, not a fresh design

- `src/web-browser.handler.slideshow` — the driving state machine
  (`<web-browser.slideshow.status>`: `load` → `load_finished`/`scrolling` →
  `scroll_finished` → back to `load`), timer-driven via
  `event.add_timer`/`web-browser.timer.slideshow`, one step per call, never
  blocks.
- `src/web-browser.callback.load_finished` — called after a page finishes
  loading; branches on `<web-browser.slideshow.no_scroll>` (an EXISTING
  flag, precedent for the new `headless` flag below) to skip the old
  auto-scroll entirely when set.
- `src/web-browser.swap_views` — the fade-in mechanic. Sets
  `<web-browser.status.fade_view> = 1` and `<web-browser.time.fade_view>`,
  connects `web-browser.handler.swap_views` to the GTK window's `draw`
  signal to drive the fade increment
  (`src/web-browser.view.util.fade_increment`,
  `src/web-browser.handler.swap_views`,
  `src/web-browser.handler.fade_in_view`). On completion sets
  `<web-browser.time.fade_complete>` and calls
  `<[web-browser.callback.load_finished]>`. Callers:
  `src/web-browser.callback.load_fail_page`, `src/web-browser.cmd.switch` —
  find the actual "page finished loading into the background view, now
  fade it in" call site yourself by tracing `web-browser.load_uri` and the
  WebKit `load-changed`/`notify::` signal handler that fires on
  `WEBKIT_LOAD_FINISHED` (not directly read this session — verify live).
- `src/web-browser.cmd.start-capture-slideshow` +
  `src/web-browser.handler.capture_on_fade` — the existing capture watcher
  (this session, commit `f1f4c5db7`... actually `15b5a5459`, verify via
  `git log --grep`). Watches `<web-browser.slideshow.url_index>` advancing
  and snapshots the page that was JUST displayed (one iteration behind,
  pre-swap foreground). This task's paging capture needs to happen INSTEAD
  of (or as an extension of) this single capture-per-advance, driven from
  inside the settled-page window before the slideshow advances to the next
  URL — study this file closely before deciding where the new per-position
  loop hooks in; do not just bolt a second independent watcher on top
  without checking for a race against this one.
- `src/web-browser.callback.scroll_start_js_exec` /
  `.callback.scroll_start_js_result` — shows the exact JS expression
  already used to get `document.documentElement.scrollHeight -
  window.innerHeight` (→ `<window.scroll.max>`) and `window.innerHeight`
  together in one round trip:
  `'(document.documentElement.scrollHeight-window.innerHeight)+":"+window.innerHeight+":"+window.scrollY'`
  (adjust to also capture innerHeight — the existing one only returns
  scroll_max and scrollY, not innerHeight; extend the same pattern, don't
  invent a new one).
- `src/web-browser.cmd.set-pos-y` — the new jump command (single
  `window.scroll()` JS call, no animation). Its reply fires once the JS
  round-trip completes.
- `src/web-browser.cmd.get_snapshot` — async, WebKit-native
  `$view->get_snapshot(...)`, replies via
  `web-browser.handler.snapshot_result` (`<web-browser.snapshot.pending_path>`
  / `<web-browser.snapshot.pending_reply>`). NOT reused directly for the
  new paging loop's internal captures (that command replies to a cube
  caller via `reply_id`) — the paging loop needs its own internal call
  into the same `$view->get_snapshot(...)` shape, or a refactor exposing a
  reusable non-reply-bound snapshot helper. Decide which with less
  duplication; if refactoring, keep `get_snapshot`'s own external contract
  unchanged (same reply shape for existing callers).

## part A -- headless mode: skip the fade, load straight into fg

Add `<web-browser.cfg.headless>` (boolean flag), same status as the
existing `<web-browser.slideshow.no_scroll>` precedent — settable at
runtime via `devmod.cmd.set` (`v7.devmod-enable web-browser` +
`web-browser.set cfg.headless 1`), not a new command.

When set:
- Skip the background-view load + `swap_views` fade entirely. Load the next
  URL directly into whatever view is currently foreground (no bg/fg swap,
  no `<web-browser.overlay.index>` flip, no `<web-browser.status.fade_view>`
  cycle).
- The "page ready" signal in this mode is purely the WebKit
  `load-changed` → `WEBKIT_LOAD_FINISHED` event on the fg view — same
  event source `load_finished`-family code already listens to, just
  without the fade step in between.
- When NOT set (default, existing behavior): completely unchanged —
  background-load + fade-swap as today. This is a pure opt-in fast path,
  not a rewrite of the existing transition.

## part B -- paged multi-position capture per page

New per-page capture loop, replacing (or extending — see precedent note
above re: capture-slideshow's existing single-shot capture) the
one-shot-per-URL snapshot with N snapshots stepping down the page by one
viewport height each:

1. Once a page is confirmed ready (gated per Part C below), get
   `scroll_max` + `viewport_height` in one JS round trip (extend the
   existing `scroll_start_js_exec`/`_js_result` expression, see precedent
   above).
2. Compute capture positions: `0, viewport_height, 2*viewport_height, ...`
   up to and including `scroll_max` (clamp the last step so it lands
   exactly on `scroll_max`, not past it — avoid an empty trailing capture
   if `scroll_max` is an exact multiple of `viewport_height`, and always
   capture at least position `0` even if `scroll_max <= 0`, i.e.
   single-viewport pages still get one capture).
3. For each position in order: `web-browser.cmd.set-pos-y` (or call its
   underlying `js_call` logic directly rather than round-tripping through
   the command layer — reuse the code, not necessarily the command) → on
   its reply, snapshot (per part above) → append a manifest line
   `<id>\t<uri>\t<position_index>\t<snapshot_path>` (extend the existing
   manifest format from `capture_on_fade` with a position-index column;
   confirm nothing downstream depends on the current 3-column shape before
   changing it — grep for manifest_path readers first) → advance to next
   position or, if that was the last one, resume the normal slideshow
   advance-to-next-URL flow.
4. This is a state machine, NOT a blocking loop — no `sleep`/blocking
   waits inside a zenka handler. Drive it the same way `handler.slideshow`
   drives its own steps: each position's capture completion triggers the
   next position's `set-pos-y` call via callback, mirroring the existing
   `load_finished` → `scroll_start` → (repeat) chaining shape.

## part C -- capture gating: render-complete / fade-complete, both modes

Never call get_snapshot before the page is actually in its final painted
state for that mode:
- **non-headless**: wait for the fade to finish — `swap_views`' own
  completion path already exists (`<web-browser.time.fade_complete>` set,
  `<[web-browser.callback.load_finished]>` invoked). Hook the Part B loop's
  FIRST capture (position 0, the "header") off of that same completion
  point, not off a fresh signal.
- **headless**: no fade happens at all (Part A), so gate purely on the
  WebKit `load-changed` → `WEBKIT_LOAD_FINISHED` event for the directly-
  loaded fg view — same event source, just without the fade step.
- Positions 2..N within the SAME page (after the header) are pure
  `window.scroll()` jumps with no new page load and no fade — their
  "ready" signal is just the `set-pos-y` JS call's own reply (synchronous
  round-trip, already the case today for `web-browser.cmd.set-pos-y` as
  built this session). Do not invent a new wait mechanism for these; only
  the very first capture of a newly-loaded page needs the render/fade
  gating above.

## build order (recommend, adjust if a cleaner grouping becomes obvious)

1. `<web-browser.cfg.headless>` flag + branch in the load path to skip
   `swap_views` when set (Part A). Verify live: toggle the flag via
   devmod, drive one slideshow URL through in each mode, confirm no fade
   happens when headless=1 and unchanged behavior when headless=0/unset.
2. Extend the scroll_max/viewport-height JS round trip to also return
   `innerHeight` (Part B step 1).
3. Position-list computation + the position-stepping state machine (Part B
   steps 2-4), wired to fire its first capture off the Part C gating (fade
   in non-headless, load-finished in headless), subsequent positions off
   each `set-pos-y` reply.
4. Manifest format extension (position-index column) + verify no existing
   reader breaks (grep first).

## p7 pitfalls (apply throughout)

- `base.logs` not `base.log` for structured/format-string logging (check
  which one existing nearby code actually uses before assuming).
- No `my $call` redeclaration shadowing the outer `$call` in `.cmd.*`
  files.
- No fake `PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_*` footers — the real
  signer handles new/edited files fine without one.
- `TRUE`/`FALSE` are `5`/`0` in this codebase, not `1`/`0`.
- Use `bin/dev/ptd -c` to check syntax on `src/*` files, never raw
  `perl -c` (macro preprocessor required, `<var>` macros aren't valid Perl
  on their own).
- Network-called command names drop the `.cmd.` infix
  (`src/web-browser.cmd.foo` → call as `web-browser.foo`).
- `\<var>` is the macro-escape sequence (yields a ref to the literal name
  string), never use it where a live data reference is needed — always
  explicit `\$data{'a'}{'b'}` for e.g. `event.add_var` watcher targets.

## live-testing hazard level: MEDIUM

Touches the live slideshow/swap_views state machine used by an
already-working automation path — a bad edit can leave the web-browser
zenka in a stuck fade or a duplicate-instance crash-loop (seen twice
already this session with other zenki after live-test crashes). Test
against a throwaway short URL list first, not the full 227-file corpus.
Expect possible duplicate-instance cleanup afterward
(`v7.instance_pids <id>` + `v7.stop <older-id>`, see
`data/ai-mem/claude/feedback-x11-xvfb-blocking-connect-crash.md` for the
pattern already used this session for a different zenka).

## status

Implemented 2026-08-29, syntax-checked and live-tested against a 3-URL local
file:// corpus. Build-order verification:

1. **Headless flag + load-path branch** — verified working. `web-browser.set cfg.headless 1|0`
   toggles the mode; in headless=1 loads go straight to the foreground view and
   `load_finished` is triggered without `swap_views`/fade. In headless=0 the
   existing bg-load + fade path is unchanged.
2. **Extended scroll-dimension JS round-trip** — verified working. The expression
   now returns `scroll_max:scroll_pos:viewport_height`; existing
   `scroll_start_js_result` regex still parses correctly because the new field is
   appended at the end.
3. **Position-stepping capture state machine** — verified working. Pages are
   captured at Y positions 0, viewport_height, 2*viewport_height, ... scroll_max
   (clamped) and the slideshow advances only after the last position's snapshot
   is saved.
4. **Manifest format extension** — verified safe. Grep confirmed no downstream
   readers of the capture manifest outside the web-browser zenka's own files;
   format changed to `<id>\t<uri>\t<position_index>\t<snapshot_path>`.

All touched `src/*` files pass `bin/dev/ptd -c`. Live-test commands and output
are recorded in the implementation session log. The web-browser instance was
left online and capture disarmed; working-tree changes are unstaged for review.

#,,,.,,,.,,,,,,..,..,,,..,...,,.,,,,.,,.,,,,.,..,,...,...,...,,,.,,,,,,,.,..,,
#IAE2SZ7G6YB62OUO3H5WELULIZOQRLLIKBJDYTHDQDCRK3N2ZK3X36KTF4AUHARZZ3IR3TRHEBIR2
#\\\|BA7I2R4BCWGOT5H7AMWEZDPDUER4QZ7WMNFCVFVWG4MZPLVS2A3 \ / AMOS7 \ YOURUM ::
#\[7]ASFFCVQBVSA4W3IBZYEHMBNG4K5PU4R6TDZMJV3XTO42TK7SEECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
