---
name: bug-web-browser-pacing-collapse-after-timeout
description: "RESOLVED 2026-08-29: after the per-page watchdog timeout fires even once, web-browser's slideshow pacing permanently collapses to near-zero delay between page attempts, causing a rapid-fire retry loop (a watchdog logged 'timed out after 0.494s'). Root cause: the timeout path never refreshed <web-browser.time.fade_complete>, which the inter-page delay math depends on. Fourth real incident in the same session as the watchdog-timeout feature itself."
metadata:
  type: feedback
---

Found running the real (non-archive) 224-file corpus batch, right after
[[bug-web-browser-stale-gtk-signal-headless-memory-leak]]'s fix and the new
per-page watchdog timeout ([[data/tasks/web-browser-page-load-watchdog-timeout.md]])
had already landed. The batch ran cleanly for 180+ pages, then — right after
the first watchdog timeout fired — degraded into a tight loop: a watchdog
logged "timed out after 0.494s" (not the configured ~20s window), followed
by 9 rapid consecutive `capture_paged.start: skipping non-content uri
'[capture_timeout:blank]'` log lines in under a second.

**Root cause**: `web-browser.handler.slideshow`'s inter-page pacing is
`$delay = $min_delay - (now - <web-browser.time.fade_complete>)`, clamped to
0 if negative. `fade_complete` is refreshed on every NORMAL page completion
(`swap_views`/`fade_in_view` in non-headless mode,
`handler.headless_load_finished` in headless mode). The NEW timeout/force-
clear path (`handler.capture_page_timeout` → `capture_paged.advance` →
`handler.slideshow`) never refreshed it. The moment the first timeout fires,
`fade_complete` freezes; every later delay computes deeply negative (real
elapsed time keeps growing, the reference point doesn't), clamps to 0, and
the slideshow fires load attempts as fast as the event loop allows — far
faster than a page can actually load. This also fully explains a pattern
seen repeatedly earlier the same session: things worked fine for a long
stretch after every zenka restart, then broke down specifically right after
the FIRST timeout, never before.

**Fix**: `handler.capture_page_timeout` now also sets
`<web-browser.time.fade_complete> = <[base.time]>->(3);` right after the
force-clear, so an abandoned page paces the same as a normal completion.
Landed, commit `4dfd2425d`.

**Diagnosis discipline that found it**: found via pure code reading
(tracing `capture_paged.advance` → `handler.slideshow`'s delay formula),
NOT via live `eval-code`/`get` queries against the running batch. See
[[feedback-live-diagnostic-queries-can-disrupt-batch]] for why that
discipline mattered — repeatedly querying live state while the batch was
active is suspected of having contributed to some of the same session's
earlier confusing failures.

**How to apply**: whenever a "force-abandon and skip" recovery path is
added alongside an existing "normal completion" path that shares downstream
pacing/timing state, audit whether the new path refreshes every timestamp
the normal path does — a recovery path that skips ONE state update the
happy path always performed can look fine in isolation and only misbehave
cumulatively, after the first time it's actually exercised.

#,,.,,,..,,,.,..,,,..,,..,..,,..,,...,.,,,,..,..,,...,..,,,,,,..,,,.,,,,,,,,.,

#,,..,,.,,,,,,,,.,...,...,.,.,,.,,,,.,,,,,,.,,..,,...,...,,,,,,..,,,.,,,,,..,,
#VG3Y7FSOTB7EVCCPKKM4PNDDWESHY3ZQJM4KIEKYJWR7SBWDRYHZEOWIUOSFLYFG4VIS6X7K67LEO
#\\\|6IBCLPGI4LTLFOWCGNFBOSPIMRSL7HNM6A7X2GEG7D2NB6VGOMG \ / AMOS7 \ YOURUM ::
#\[7]TEMNXPITGFQ7NRK5MDAQAAXAW2VI4FPFAVM7Q6EAPRQHJZIQBUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
