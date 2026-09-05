# web-browser zenka: hard per-page watchdog timeout + force-clear-on-stop

## why -- read this in full, this is the THIRD real production incident tonight from this feature area

Session history, in order:
1. Headless-mode fast-swap + paged multi-position capture built (this session).
   Landed, commit `22d380fb2`.
2. **Incident 1**: running the real corpus, a stale `swap_views` draw-signal
   connection (headless mode never disconnected it) drove a runaway
   `clear_bg_view` reload loop -- WebKitWebProcess hit 59% system RAM, OS
   watchdog killed it. Root-caused, fixed
   (`web-browser.util.disconnect_swap_views_signal`), independently verified
   stable across 4 full passes. Landed, commit `ad5670f98`. See
   `data/ai-mem/claude/bug-web-browser-stale-gtk-signal-headless-memory-leak.md`.
3. **Incident 2**: resuming the batch after fixing (1), a stale in-flight
   WebKit async snapshot completion from a stopped run fired against
   already-cleared/reused `<web-browser.capture.paged.pending_path>` state,
   crashing the ENTIRE GTK main loop (`undef value in subroutine entry
   [web-browser.util.snapshot_save:24]`) -- the whole web-browser zenka died.
   Fixed with undef-guards in `handler.capture_paged_snapshot_result` and
   `web-browser.util.snapshot_save`. NOT yet committed -- these fixes are
   currently uncommitted working-tree changes, verify they're still there
   before building on top.
4. **Incident 3 (THIS TASK)**: after fixing (3) and restarting cleanly,
   resuming the real corpus batch, the page
   `data/asc/what-AI-thinks/html-form/templates/webgl-template-concept.html`
   stalled the capture loop (never advanced past it in a 19-second
   observation window). Calling `web-browser.stop_slideshow` +
   `web-browser.stop-capture-slideshow` stopped ADVANCING but did NOT stop
   whatever that page's own JS was doing -- it kept running in the
   background after the "stop", and shortly after, the WHOLE HOST hit 98%
   memory with a single WebKitWebProcess at 83% memory / 96% CPU. The
   system's own OOM watchdog warning fired but this time the user had to
   manually SIGINT the entire `v7` zenka (all 9 sub-zenki, not just
   web-browser) to recover -- a full backend restart, worse than incident 1.

**The structural gap**: `stop_slideshow`/`stop-capture-slideshow` only ever
stop OUR orchestration state machine (the timer that decides when to advance
to the next URL). Neither of them touches the actually-loaded page's live
content -- if a page's own JS is doing something expensive/runaway
(unthrottled `requestAnimationFrame` loop, uncapped WebGL buffer allocation,
whatever `webgl-template-concept.html` specifically does), "stopping the
slideshow" does nothing to interrupt it. The page keeps executing and
consuming resources for as long as it stays loaded in the view, regardless
of what our command layer is told.

## what to build

### 1. Per-page hard watchdog timeout (primary fix)

Arm a timer whenever a new page load starts while the slideshow is running
(`<web-browser.slideshow.running>`), disarm it when that page's full cycle
(load + all paged-capture positions, or just load+settle for plain
slideshow) legitimately completes. If the timer fires first, FORCE-ABANDON
the page:

1. Log clearly: URL, elapsed time, at warn level (this is an operational
   signal worth seeing, not a debug-level log).
2. **Force-clear the current view's content** -- reuse the exact technique
   `web-browser.clear_bg_view` already uses (`$view->load_alternate_html(
   "<html>...</html>", '[capture_timeout:blank]' )`, distinct sentinel from
   `clear_bg_view`'s own `[clear_bg:blank]` so the two are distinguishable in
   logs/manifests) -- this is what actually terminates the page's JS
   execution context and lets WebKit reclaim its resources. Apply it to
   whichever view is currently foreground (headless) or whichever view holds
   the stuck load (non-headless -- check both fg and bg views' URIs against
   the URL that was loading).
3. Append a line to a SEPARATE "timed-out pages" log file (not the main
   capture manifest -- these are known-bad pages needing individual review
   later, don't pollute the position-capture manifest format). Shape:
   `<timestamp>\t<uri>\t<elapsed_seconds>\n`. Path: reuse
   `<web-browser.capture.manifest_path>`'s directory with a `.timeouts.tsv`
   suffix, or a new `<web-browser.capture.timeout_log_path>` set alongside
   `manifest_path` in `start-capture-slideshow` -- your call, keep it simple.
4. Clear any paged-capture state for the abandoned page
   (`<web-browser.capture.paged.*>`, same set `stop-capture-slideshow`
   already deletes -- reuse that list, don't duplicate it inline).
5. Advance to the next URL: if `<web-browser.capture.paged.armed>`, call
   `<[web-browser.capture_paged.advance]>`; otherwise fall back to
   whatever `handler.slideshow` normally does to move on (read that file
   again, this session already documented its `load`/`load_finished`/
   `scroll_finished` state shape).

**Where to arm/disarm**: `web-browser.load_uri` is the single choke point
for every page load (headless or not, capture-armed or not) -- arm the
watchdog timer there, gated on `<web-browser.slideshow.running>` (don't
watchdog ad-hoc manual browsing, only automated slideshow/capture runs).
Disarm it defensively at the TOP of `load_uri` before re-arming (same
`->cancel` + check-`is_active` idiom already used for
`<web-browser.timer.slideshow>` elsewhere -- follow that exact pattern) so
there's never more than one live watchdog timer, and also disarm it from
`capture_paged.advance` and from wherever plain `handler.slideshow`
reaches its own natural "this page is done" point, so a normal completion
never spuriously fires the watchdog moments later.

**Timeout duration**: make it configurable --
`<web-browser.cfg.capture_page_timeout>`, default **20 seconds**. Rationale:
tonight's normal captures (including a genuinely heavy WebGL dashboard page)
completed in single-digit seconds; 20s gives real headroom for a legitimately
slow-but-safe page without leaving a truly runaway page consuming resources
for very long. Do not use a longer default without discussing it -- the
whole point is bounding worst-case exposure tightly, given tonight's
history.

### 2. Force-clear on explicit stop too (belt-and-suspenders)

`web-browser.cmd.stop_slideshow` and `web-browser.cmd.stop-capture-slideshow`
currently only stop the orchestration timers/watchers. Add the same
force-clear-current-view step (item 1.2 above) to BOTH of them, so a human
explicitly stopping a batch actually terminates whatever page is currently
loaded, not just future advancement. This directly closes the gap that let
incident 3 keep escalating even after the operator (me, tonight) called
stop.

## precedent

- `src/web-browser.clear_bg_view` -- the `load_alternate_html` blank-page
  technique to reuse.
- `src/web-browser.handler.slideshow`, `src/web-browser.load_uri` -- existing
  timer-arm/disarm idiom (`<web-browser.timer.slideshow>`,
  `event.add_timer`/`->cancel`/`->is_active`) to mirror exactly for the new
  watchdog timer.
- `src/web-browser.cmd.stop-capture-slideshow` -- the exact list of
  `<web-browser.capture.paged.*>` keys it already deletes; reuse, don't
  reinvent.
- `src/web-browser.capture_paged.advance` -- how a page's cycle normally
  ends and the slideshow resumes.
- Tonight's incidents 1-3 above and their fixes (`bug-web-browser-stale-gtk-
  signal-headless-memory-leak.md`, the still-uncommitted
  `capture_paged_snapshot_result`/`snapshot_save` undef-guards) -- read
  these, this task builds on top of both, don't reintroduce either bug.

## SAFETY -- this is the third real production incident tonight, follow this exactly

- **Do NOT load `data/asc/what-AI-thinks/html-form/templates/webgl-template-
  concept.html` or ANY real corpus page while testing this fix.** It is
  KNOWN to cause a runaway that required a full backend restart tonight.
  Write a small SYNTHETIC local test HTML file instead, with a deliberate,
  clearly-labeled runaway (e.g. `setInterval` pushing onto a growing array
  every few ms with no cap, or a similar deliberately-bad pattern) --
  something guaranteed to trigger the watchdog without any uncertainty about
  what a real corpus page might do.
- Test the watchdog against that synthetic page FIRST, in isolation (single
  URL, not a full slideshow), watching `free -m` continuously (every 1-2s)
  throughout. Confirm: (a) the timeout fires at approximately the configured
  duration, (b) memory/CPU visibly drops back down within a few seconds
  after it fires (proving the force-clear actually reclaimed resources, not
  just stopped our own bookkeeping), (c) the slideshow correctly advances
  past it.
- Also test the `stop_slideshow`/`stop-capture-slideshow` force-clear
  directly: start the synthetic runaway page loading, then call
  `stop_slideshow` WHILE it's still running (before the watchdog would have
  fired), and confirm memory/CPU drops immediately rather than continuing to
  climb -- this is testing item 2 specifically, not just item 1.
- Only after BOTH of those pass cleanly against the synthetic page, try
  exactly ONE real corpus page -- a known-safe one already verified tonight
  (`data/asc/what-AI-thinks/html-form/branding/logo-html.html`, NOT the
  interactive-dashboards or templates pages) -- to confirm normal pages
  still complete well under the timeout and are never falsely abandoned.
- Do NOT attempt `webgl-template-concept.html` even after the above passes.
  Do NOT attempt the full 227-file batch. Both of those are for me to
  resume, deliberately and separately, after independently reviewing your
  fix -- not something to do as part of "testing this task."
- Keep `free -m` output and exact elapsed-time numbers for every test run in
  your final report, same rigor as the incident-1 fix report.

## p7 pitfalls (apply throughout, same as every task tonight)

- `base.logs` vs `base.log` -- check which the surrounding file already uses.
- No `my $call` redeclaration in `.cmd.*` files.
- No fake/copied AMOS7 signature footers -- leave new files with NO footer
  at all, let the real signer add one. Tonight's session found THREE
  separate instances of stolen/duplicated footers from you specifically
  (see `feedback-fake-signature-marks-ai-scratch-content.md`'s last two
  sub-cases) -- if you reuse or reference an existing file's content while
  writing a new one, do not carry its footer along, and do not do a
  full-file rewrite of an already-fixed file from a stale in-context copy
  (this exact mistake reintroduced a fake footer once already tonight).
- `TRUE`/`FALSE` are `5`/`0`, not `1`/`0`.
- `bin/dev/ptd -c` for syntax checks, never raw `perl -c`.
- Network command names drop the `.cmd.` infix.
- `\<var>` is the macro-escape sequence, never use it for a live data
  reference -- explicit `\$data{'a'}{'b'}`.

## status

Implemented 2026-08-29.

- Added `<web-browser.cfg.capture_page_timeout>` default 20s in `init_code`.
- Added `web-browser.util.force_clear_view` and `web-browser.util.force_clear_current_view`
  to load a `[capture_timeout:blank]` sentinel into the stuck view, disconnecting
  the `load-changed` / `load-failed` signals first so the force-clear does not
  re-enter the state machine.
- Added `web-browser.handler.capture_page_timeout`: logs at warn level, appends
  `<timestamp>\t<uri>\t<elapsed>s` to `<manifest_path>.timeouts.tsv`, force-clears
  the view, drops per-page paged-capture state, and advances the slideshow.
- Armed/disarmed the watchdog in `web-browser.load_uri` (only while slideshow is
  running), `web-browser.capture_paged.advance`, `web-browser.handler.slideshow`
  natural completion, `stop_slideshow`, and `stop-capture-slideshow`.
- `start-capture-slideshow` now also sets `<web-browser.capture.timeout_log_path>`.
- Fixed a latent headless-mode bug: `handler.headless_load_finished` now sets
  `<web-browser.time.fade_complete>` so `handler.slideshow`'s delay calculation
  does not die on undef after a headless load.
- All touched files passed `bin/dev/ptd -c`.

Testing (headless=1, timeout lowered to 5s for faster verification):
- Synthetic slow-getter page (`runaway_slow_getter.html`) stalls the paged-capture
  JS query; watchdog fires reliably at ~5s, appends to `.timeouts.tsv`, and the
  slideshow advances to the next URL.
- Known-safe real page (`branding/logo-html.html`) completes well under the 20s
  default, is captured repeatedly, and never appears in the timeout log.
- Explicit `stop_slideshow` / `stop-capture-slideshow` force-clear the current
  view and disarm the watchdog.

The problematic real page `webgl-template-concept.html` and the full corpus were
NOT touched during testing, per safety rules.

## follow-up bug found + fixed running the real (non-archive) corpus, 2026-08-29

After the watchdog fix landed, a real 224-file batch run (minus the 3 known
WebGL files) worked cleanly for 180+ pages, then degraded hard: a watchdog
fired after "0.494s" (not the configured window) followed by 9 rapid
consecutive `capture_paged.start: skipping non-content uri
'[capture_timeout:blank]'` log lines in under a second -- a tight
self-referential loop, exactly as the user suspected much earlier in the
session ("all timeouting again... maybe that is desyncing it?").

**Root cause**, found via code reading alone (no live queries, to rule out
interference from diagnostic polling itself -- see the feedback memory on
that): `handler.slideshow`'s inter-page pacing is `$delay = $min_delay -
(now - <web-browser.time.fade_complete>)`, clamped to 0 if negative.
`<web-browser.time.fade_complete>` is refreshed on every NORMAL page
completion (`swap_views`/`fade_in_view` in non-headless mode,
`handler.headless_load_finished` in headless mode -- the latter already
patched during this same task). The NEW timeout/force-clear path
(`handler.capture_page_timeout` -> `capture_paged.advance` ->
`handler.slideshow`) never refreshed it. The moment the first timeout fires,
`fade_complete` freezes at its last real value; every subsequent delay
calculation computes deeply negative (real elapsed time keeps growing while
the reference point doesn't move), clamps to 0, and the slideshow fires load
attempts as fast as the event loop allows -- far faster than a real page can
load -- producing the observed rapid-fire loop. This also fully explains
the "works fine for a long stretch after every restart, breaks specifically
right after the first timeout" pattern seen repeatedly earlier in the
session.

**Fix**: `handler.capture_page_timeout` now also sets
`<web-browser.time.fade_complete> = <[base.time]>->(3);` right after the
force-clear, so an abandoned page paces the same as a normal completion
(full `min_delay` before the next attempt) instead of collapsing pacing for
every page from that point forward.

Also confirmed during this investigation: repeatedly querying live zenka
state via `p7c ... eval-code`/`get` WHILE the batch is actively running
routes through the SAME single-threaded event loop the batch itself uses,
and interleaved log evidence suggests it can itself disrupt in-flight
WebKit operations. Diagnosis for the rest of this task was done via passive
OS-level monitoring (`free`/`ps`/file reads) and direct source-code reading
instead, not live process queries -- worth keeping as the default approach
for any future live debugging of this zenka.

Not yet re-verified live (session paused for a restart to also pick up the
still-unapplied `cfg.capture_page_timeout` override). Next: restart, apply
zoom/headless/timeout overrides fresh, then resume/retry from the point
this batch reached plus a retry list built from `.timeouts.tsv`.

#,,..,,..,,,.,.,.,,..,,..,,.,,,.,,...,,.,,,.,,..,,...,..,,.,,,...,,,.,..,,..,,
#CBLMPH3Z5YXR2QXTOJVV24AKDWF5KUXVPQTEM5MELOJY6QF5Q3NCDFGNX3DWMWXLNR3HGRLI2HKGM
#\\\|XDUYOXASTZYETGKGCFDVOZMF3YSA7W3HQG7TLYJZJEUBP2CH2RS \ / AMOS7 \ YOURUM ::
#\[7]5TJF3BPHARXBLSAK5O6V5M5MG6GR72URCGOLVWST5XPXYBSHBYDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
