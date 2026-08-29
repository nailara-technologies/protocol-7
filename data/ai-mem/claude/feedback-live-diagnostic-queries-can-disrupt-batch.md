---
name: feedback-live-diagnostic-queries-can-disrupt-batch
description: "Repeatedly querying a running zenka's live state (p7c ... eval-code / get) WHILE it's mid-batch routes through the SAME single-threaded event loop the batch itself uses, and interleaved log evidence from 2026-08-29 suggests it can interrupt in-flight WebKit operations. Diagnose via passive OS-level monitoring + source reading instead."
metadata:
  type: feedback
---

Found during the web-browser screenshot-triage batch, 2026-08-29 (see
[[project-screenshot-triage-corpus-2026-08-29]] and
[[bug-web-browser-pacing-collapse-after-timeout]]). While investigating why
the batch appeared stuck, a pasted live log showed a burst of my own
`p7c web-browser.eval-code` diagnostic queries (`<web-browser.slideshow.
running>`, `url_index`, `status`, `timer.capture_page_timeout`, etc.)
interleaved DIRECTLY in the middle of a runaway failure sequence — right
between a watchdog timeout firing and a WebKit `cannot load page ... [ frame
load interrupted ]` error for the next page.

**Why this is plausible, not just correlation**: Protocol-7 zenki are
single-threaded/event-loop based (per this project's core architecture).
`eval-code` executes IN that same process, on that same event loop, as
whatever async WebKit load/snapshot operation is currently in flight. A
diagnostic query issued at the wrong moment competes for the same event-loop
turn as an in-progress page load — "frame load interrupted" is exactly the
kind of symptom a genuinely interrupted async operation would produce.

**How to apply**: while a live batch/slideshow is actively running, do NOT
poll its state via `eval-code`/`get`/`set` to "just check what's happening."
Use passive, out-of-process monitoring instead — `free -m`/`ps` for
memory/CPU, reading the manifest/log FILES the batch itself writes, `wc -l`
on output files for progress. Only send commands into the live zenka when
actually taking an action (stopping it, or once it's already stopped) — not
for read-only curiosity mid-run. This is the same discipline as
[[feedback-x11-xvfb-blocking-connect-crash]]'s lesson about never using
`alarm()`/`SIGALRM` inside an Event.pm zenka's own timer callback: don't let
diagnostic/instrumentation code compete with the framework's own event loop
for the same resource it needs to function correctly.

#,,.,,,..,,,.,..,,,..,,..,..,,..,,...,.,,,,..,..,,...,..,,,,,,..,,,.,,,,,,,,.,

#,,..,,.,,,.,,..,,,,,,...,,..,,,,,...,,..,,..,..,,...,..,,...,.,.,,,,,,.,,.,.,
#EW6KDKJH42LHMO7Y23GFARDME2KNGCTRHNJ7SNTFXIU456R2U4KJ6UOGZG7UKQ5XLIUB2JFQTCNAI
#\\\|LERHGWHJWNOYTR45TMMHVJW5OXGR52YOYZ3UXVNRZBQHXE3H2P6 \ / AMOS7 \ YOURUM ::
#\[7]EKLRR2R2JLGLSFNHS5DU5Z7SKZ4UYDDGMAXLHQFLTWW4QWXOLAAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
