---
name: bug-web-browser-stale-gtk-signal-headless-memory-leak
description: "RESOLVED 2026-08-29: web-browser's new headless capture mode caused a real host memory emergency (WebKitWebProcess hit 59% RAM, OS watchdog killed it) -- a stale swap_views draw-signal connection kept firing forever once headless mode skipped the code path that normally disconnects it, driving a runaway clear_bg_view load loop. Fix + the isolation technique that found it are reusable."
metadata:
  type: feedback
---

Found 2026-08-29 running the real 227-file screenshot pilot with the newly-built
`web-browser.cfg.headless` fast-swap mode ([[vision-generic-web-template-hybrid-doc-browser]]'s
Stage 1 groundwork). The system's own memory watchdog
(`src/system.process.handler.collect_table`) had to kill a WebKitWebProcess that reached
59.79% of total system RAM mid-run.

**Root cause**: `src/web-browser.swap_views` connects `handler.swap_views` to the GTK
window's `draw` signal to drive the fade animation; that connection is normally disconnected
either at the top of the next `swap_views` call or inside `handler.swap_views`'s own
completion branch. Headless mode's `handler.load_changed` branch never calls `swap_views`
again — so a connection established by an earlier non-headless run (or by toggling
`cfg.headless` mid-session) was NEVER disconnected once headless mode took over, and kept
firing on every single `draw` event (which happens continuously on a live WebGL/canvas page).
Each spurious fire drove `handler.fade_in_view` → `clear_bg_view`, which loads the sentinel
URI `[clear_bg:blank]` into the background view — a runaway load/reload loop, confirmed via
manifest inspection (real page's positions captured correctly once, then the manifest
started cycling through `[clear_bg:blank]` many times per second).

**Generalizable lesson**: in this GTK/WebKit-event-driven codebase, a `signal_connect` whose
matching `signal_handler_disconnect` lives only inside the "normal" re-entry path (i.e. only
gets cleaned up the NEXT time the same function runs) is unsafe the moment ANY code path can
skip that function's normal re-invocation — exactly the same shape of bug as the
[[feedback-x11-xvfb-blocking-connect-crash]] alarm/signal lifecycle issue, different
subsystem. Adding a new "fast path" that bypasses an existing mechanism must audit what that
mechanism was responsible for cleaning up, not just what it visibly does.

**Fix** (commit pending as of this writing): new `web-browser.util.disconnect_swap_views_signal`
helper, called defensively at the start of every headless `load_uri` and in
`handler.load_changed`'s headless branch — guarantees no stale connection can ever fire
regardless of prior mode/toggle history. Belt-and-suspenders: `capture_paged.start` and
`callback.capture_paged_query_result` now also refuse to run the paged-capture loop against
sentinel URIs (`[clear_bg:blank]`, `[PAUSE]`, anything starting with `[`).

**Diagnosis technique worth reusing**: isolated a live-GUI-zenka memory leak by (1) stopping
the real batch immediately on the watchdog's kill message, (2) testing a single suspect page
via a PLAIN one-shot load+snapshot first (ruled out "the page itself is just heavy" —
memory stayed flat), (3) re-running ONLY the new capture-loop logic against that one page
in a tight `free -m`-polled loop (1s interval, hard abort threshold), which reproduced the
runaway in ~10s and made the exact failure mode (bogus URI flooding the manifest) directly
visible. This is the same "isolated reproduction, never iterate live at full scale" discipline
as [[feedback-powershell-exec-and-safe-regex-gotchas]], applied to a GUI/GTK zenka instead of
a subprocess.

**How to apply**: before building any "skip the normal path" fast mode for an existing
GTK-signal-driven or event-driven subsystem, explicitly enumerate what cleanup the skipped
path was responsible for and replicate it defensively in the new path — don't assume "we
never call that function anymore" means its side effects are irrelevant. When a live zenka's
memory behavior is suspect, isolate with a single-input, tightly-polled repro before ever
re-running at batch scale, exactly as documented here.

#,,,.,,.,,,,,,,,.,.,.,...,,,,,,..,..,,..,,.,,,..,,...,...,..,,,..,,,,,.,.,,,,,
#Z5ZR5FSAW6OKDTSNMVTAUBAKDHCIFHR5XOC6OLFZKMKDA6VGRATYII4BFKK4XLRGJNANF25RMJB4O
#\\\|LJIQOSIR62KAJSTGNY7ZLFU4VWFP7RDXKIXUCYXEXCMZOFY3O2P \ / AMOS7 \ YOURUM ::
#\[7]RG7L7X5RX6NOIRNO72QRNNPU2XJJCRZRC6EI7EJDR3RXOHIGA4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
