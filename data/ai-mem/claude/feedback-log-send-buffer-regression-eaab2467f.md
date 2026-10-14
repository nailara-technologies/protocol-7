---
name: feedback-log-send-buffer-regression-aa2235630
description: the log send-buffer's notify_online request went through <system.init_reports> since aa2235630 [ 2026-07-18 ] -- one-shot flush at verification ran BEFORE the request in every zenka without an early event loop turn : their p7-log files silently stopped. fixed 2026-09-30 with a session guard + one-time re-arm ; how it was found
metadata:
  type: feedback
---

**the bug** : `base.log.send-buffer.*` starts every send buffer paused and
asks `v7-zenki.notify_online p7-log` from an idle callback [ design since
2021, 8544897b6 ]. aa2235630 moved that request from a direct `send.local`
into `<system.init_reports>` to fix "callback fires before the session".
init_reports flushes ONCE, at instance verification. zenki without an early
event loop turn [ invoke-web, mod-test, calc, system .. ] handle the
verification in the first loop turn, THEN go idle -> the request lands in a
queue nobody flushes -> buffer paused forever, the zenka's p7-log file stops
[ calc's last log : the day of aa2235630 ]. zenki with their own session key
generation worked by accident : `crypt.C25519.gen_keys` turns the loop
[ `event.once(0.007)`, since 2021 ] before the connect.

**the fix [ 2026-09-30 ]** : `send-idle-callback` sends directly again, but
returns without asking while `<system.zenka.initialized>` is false [ no
re-arm there -- no idle loop, cf. the storm fix 5a16981ce ] ;
`send-buffer.init` registers a one-time re-arm in
`<system.callbacks.initialized>` [ also one-shot, at verification ] for
buffers created before the session. tested : start with \ without key
generation, p7-log down at start, p7-log reappearing, p7-log restart while
running, reload, buffer created after verification.

**Why:** the user rejected two quick fixes [ flushing init_reports from the
log code, then a direct-send fallback ] until the root cause was measured :
"that needs the root cause exactly identified.. compared to bending generic
systems around it while still not knowing what is happening". the premise
"all other zenki work" was itself wrong -- nobody looked at the files.

**How to apply:**
- a queued \ deferred send that "never arrives" : first check which ONE-SHOT
  mechanism it relies on [ init_reports, callbacks.initialized, verify ] and
  measure the order with level-2 lines + `p7c localtime <ntime>` before any fix
- compare against a zenka that works [ mod-test is the free test zenka ]
- read the fix history of the path [ `git log --follow` ] for storm \ race
  fixes it must not undo
- `v7-zenki.notify_online` is not logged by v7-zenki ; the zenka side is where
  it shows

#,,,.,.,,,.,,,,,,,...,,,,,..,,.,,,.,.,..,,...,..,,...,...,..,,,..,,.,,..,,,.,,
#YNK6AHIKM4KEPLQ5M7JRM6DCO7GJUMQQA24MT2ZURGOYOIWK2CGHMURY45KDXLTDR3HHKNDSDEREA
#\\\|DFPEPMR2WNRUV3YDWPOH6XQEKYRJ7I6SVIL6LFWO2YSFNIAGPTR \ / AMOS7 \ YOURUM ::
#\[7]C2L6YAS4RSOMQ7CBTCD3LGVK7FW7UVZYGQ5YPBNLUD5C2Y66QUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
