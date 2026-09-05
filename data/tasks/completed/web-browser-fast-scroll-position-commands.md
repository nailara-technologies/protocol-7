# task: web-browser — fast direct scroll-position commands (pixel/percent)

## context

Part of the same 2026-08-28 session as the other web-browser/X-11 task files
(style-triage screenshot pipeline, `data/ai-mem/claude/
vision-generic-web-template-hybrid-doc-browser.md`). The capture-slideshow
feature (built and verified working earlier tonight,
`data/tasks/web-browser-capture-slideshow-var-watcher.md`) is real but
impractically slow for a large batch: ~136 seconds/page average observed
live against `data/asc/what-AI-thinks/html-form/` (227 files), confirmed
via manifest timestamps during a live run tonight.

## root cause, confirmed via code reading

`src/web-browser.handler.auto_scroll` animates the page scroll ONE PIXEL AT
A TIME: `<window.scroll.pos>++` then a single-pixel `window.scroll(0,
<pos>)` JS call via `<[web-browser.js_call]>`, on a `draw`-signal-connected
handler throttled to `<web-browser.autoscroll.delay>` (default 0.033333s,
~30fps). For a page with e.g. 6028px of scrollable height (an actual
observed value in tonight's log — `": starting auto-scrolling.., [ 6028
pixels ]"`), that's ~6028 individual JS round trips at ~30fps ≈ 200+
seconds of scrolling for ONE page, before slideshow's own `min_delay` (7s)
and load time are even added. This is the single dominant cost in the
batch — not `min_delay`, not page load, not the capture/snapshot itself.

`<window.scroll.max>` is set once per page in
`src/web-browser.callback.scroll_start_js_result` (a JS query result,
scrollable height in pixels) and is available at the point auto-scroll
would normally start.

## what to build

Three new commands (names chosen by the user via this project's `harmony`
naming-candidate tool — pass the harmonic-truth assertion, use these exact
names):

1. `web-browser.cmd.set-pos-y <value>` — jump the CURRENT FOREGROUND view's
   scroll position directly, ONE `window.scroll(0, <target>)` JS call via
   `<[web-browser.js_call]>` (same call shape `auto_scroll` already uses),
   no animation loop, no timer. `<value>` accepts either a bare integer
   (pixels) or a value ending in `%` (percent of `<window.scroll.max>` —
   compute `int(<window.scroll.max> * $pct / 100)`). Update
   `<window.scroll.pos>` to match the new target after the JS call
   succeeds, same as `auto_scroll` keeps it in sync today. Horizontal
   (X) position is explicitly OUT OF SCOPE for this task — vertical only,
   left for a future expansion per the user.
2. `web-browser.cmd.set-fg-pos <value>` — same pixel/percent jump, but
   explicit about targeting `<web-browser.overlay.index>->{'fg'}`
   regardless of any in-flight swap/fade state (see below) — likely a thin
   wrapper around the same underlying logic as `set-pos-y`, made explicit
   for use alongside the bg-targeting command below.
3. `web-browser.cmd.set-bg-pos-y <value>` — same jump, but targets
   `<web-browser.overlay.index>->{'bg'}` (the view currently loading
   in the background, not yet visible) instead of fg. Lets a caller
   pre-position the NEXT page's scroll BEFORE it becomes the foreground
   view, so the eventual swap shows the page already at its target
   position with zero visible scroll animation.

Two candidate names the user's `harmony` check rejected (do NOT use these
exact strings — pick different variants if a name is needed for something
not covered above): `set-fg-pos-y`, `set-bg-pos`.

## the actual performance win : wire this into the slideshow path

Building the three commands alone doesn't speed up the existing
`web-browser.cmd.start_slideshow` / capture-slideshow flow — that still
goes through `web-browser.handler.slideshow`'s existing
`load` -> `load_finished` -> `scrolling` (via `scroll_start`/`auto_scroll`)
-> `scroll_finished` -> `load` cycle, per-pixel scroll included. This task
is ONLY about adding the three new low-level positioning commands
correctly; wiring a fast-path into the slideshow state machine to use them
instead of the existing animated scroll is EXPLICITLY OUT OF SCOPE here —
that's shared, complex, stateful code (`web-browser.handler.slideshow`,
already flagged as risky to touch live earlier tonight) and deserves its
own separate, carefully-scoped task after these primitives exist and are
verified independently. Do not modify `web-browser.handler.slideshow`,
`web-browser.handler.auto_scroll`, `web-browser.scroll_start`, or
`web-browser.swap_views`/`handler.swap_views` in this task.

## live-testing hazard

`web-browser` crashed twice earlier tonight (a heartbeat-timeout kill and
a segfault, both documented in the sibling task files, both since fixed
and verified). It's currently stable. These are new, small, additive
commands with no interaction with existing state machines (per the
explicit out-of-scope note above) — lower risk than tonight's earlier
work, but still: verify via `bin/dev/ptd -c` first, and if you do test
live, a single `set-pos-y 50%` call against a loaded page is a much
smaller blast radius than anything touching the slideshow/swap_views
machinery. Check `v7.list zenki` for a single stable `web-browser`
instance before AND after any live test.

## dispatch notes [ for whoever picks this up, human or AI ]

Read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md`
first if you're kimi. P7 pitfalls: `base.logs` not `base.log` for
multi-arg sprintf-style calls, never redeclare `my $call`, never add fake
`PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE` footers to new files, `TRUE`/`FALSE`
are `5`/`0` not `1`/`0`, use `bin/dev/ptd -c` to check syntax (NOT raw
`perl -c`), and NEVER use `\<var>` for a live reference — a leading
backslash is this codebase's macro-escape and silently watches/reads a
dead literal-string reference instead of the real data slot (confirmed
this exact session, see `data/ai-mem/claude/
feedback-x11-xvfb-blocking-connect-crash.md` and the capture-slideshow
task file). If you learn something non-obvious while working on this, add
a note to your own memory files, same as any other task.

#,,,,,,,.,,.,,,,.,,,.,.,.,..,,...,,.,,,..,...,..,,...,..,,..,,.,,,,.,,..,,,,,,
#R5FA5BLD3VRBAXGBU6CWZTBXVF4DPPCLIZNULDTJHEAX7SIZFXMWSBKPILAGYIMDMEPPMYHSTOMCI
#\\\|ML4UFUVHITZMK3K7HT7GGN3ILVAJFHR5MSOEVX6VHO3UXVG3QMQ \ / AMOS7 \ YOURUM ::
#\[7]SI7K5SXJEK7PFCJ5KC44FGJSKYGEJKJ2D5I5DQXZ43ZJBITGX4AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
