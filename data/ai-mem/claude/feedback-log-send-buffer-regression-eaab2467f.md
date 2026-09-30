---
name: feedback-log-send-buffer-regression-eaab2467f
description: the log send-buffer's notify_online request went through <system.init_reports> since eaab2467f [ 2026-07-18 ] -- one-shot flush at verification ran BEFORE the request in every zenka without an early event loop turn : their p7-log files silently stopped. fixed 2026-09-30 with a session guard + one-time re-arm ; how it was found
metadata:
  type: feedback
---

**the bug** : `base.log.send-buffer.*` starts every send buffer paused and
asks `v7-zenki.notify_online p7-log` from an idle callback [ design since
2021, 8544897b6 ]. eaab2467f moved that request from a direct `send.local`
into `<system.init_reports>` to fix "callback fires before the session".
init_reports flushes ONCE, at instance verification. zenki without an early
event loop turn [ invoke-web, mod-test, calc, system .. ] handle the
verification in the first loop turn, THEN go idle -> the request lands in a
queue nobody flushes -> buffer paused forever, the zenka's p7-log file stops
[ calc's last log : the day of eaab2467f ]. zenki with their own session key
generation worked by accident : `crypt.C25519.gen_keys` turns the loop
[ `event.once(0.007)`, since 2021 ] before the connect.

**the fix [ 2026-09-30 ]** : `send-idle-callback` sends directly again, but
returns without asking while `<system.zenka.initialized>` is false [ no
re-arm there -- no idle loop, cf. the storm fix 494791f15 ] ;
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

#,,..,.,.,,.,,,,.,,..,..,,.,,,...,.,.,.,.,,,,,..,,...,...,,,,,,..,,.,,,..,,..,
#VP2CSJONJTAPJFRMVPISXWFKCHAH7QYAZIOETYYLPY4UHDZDWKADF7GAZNHWTHPSBYT3VZKGOOPQG
#\\\|PUR4EZ2J67QBHUKXE7FO6CBJKSKNBHU4DQ2BMQYS4YOIAQIOHVI \ / AMOS7 \ YOURUM ::
#\[7]NX2UHEQ5XL7KB4KY532R23TNWM2YVUX3G6JQNVGS3WXZHL4UOOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
