---
name: route-send-buffers-timer-gets-event
description: route-send only BUFFERS until the event loop runs [ no round trip inside one blocking call ] ; timer handlers get the EVENT [ ->w->data ] ; reply handlers get ONE hash [ params inside ] ; add_timer ignores `delay` [ fires at once ]
metadata:
  type: feedback
---

two async gotchas found reviewing kimi's letsencr enrollment, 2026-10-09 [ 4a3e42c0b ] :

1. `<[protocol-7.route-send]>` -> base.protocol-7.command.send.local only APPENDS to
   `$data{'session'}{$sid}{'buffer'}{'output'}` ; the event loop flushes it later. a command
   sent and then "used" inside the same blocking call never left the process [ the http-01
   self-test fetched before httpd ever got the setup -- would have failed every live run ].
   fix pattern : send WITH a reply handler, continue there ; a command answering its caller
   later returns `{ mode => 'deferred' }` and replies via `<[base.callback.cmd_reply]>->(
   $call->{'reply_id'}, { mode, data } )` [ letsencr.child.continue_challenge_processing ].
2. an `event.add_timer` handler receives the Event object, not the 'data' hash : read
   `$event->w->data` [ 137 uses in src ]. a handler checking `ref eq 'HASH'` silently no-ops.

3. a route-send REPLY handler gets ONE hash `{ sid, cmd, call_args, data, params }`
   [ base.handler.command.process_reply ] -- the reply params are INSIDE it, the TRUE \ FALSE
   text is in `call_args`. `my $reply = shift ; my $params = shift` silently gets undef params
   [ letsencr.child.acme.on_setup, found by the first live staging run 2026-10-09 ; the test
   stub had delivered the wrong shape too ]. make stubs deliver the real shape.
4. `event.add_timer` knows `after` \ `at` [ + `interval` ] only -- an unknown `delay` is
   ignored and the timer fires AT ONCE [ four letsencr parent retry \ rate-limit timers did
   that : "retry in 1800 s" ran within seconds, fixed 4f4d1cbda ].

also : base.event.* is swapped to event.* at pre_init -- call `<[event.add_timer]>`, never
`<[base.event.add_timer]>` [ host-edit.flow.schedule died on it, 998f9175a ].

**Why:** stub-based tests hide all three -- stubs act instantly and get plain hashes.
**How to apply:** when reviewing \ writing async zenka code, check every route-send whose
result is used in the same call, every timer handler's first arg, and that tests deliver
replies explicitly and pass Event-shaped objects [ see test-letsencr-enroll.pl ].

#,,,,,.,,,,..,...,,,.,..,,,..,.,.,...,..,,,.,,..,,...,...,...,,,,,,,,,.,,,.,,,
#7CDLTVOAOL6RQRGYYNX3J523QRLI53DVYBCFXVOZN3BNFWK2KHHGOQ2L7XYKK5F3MJCEKLAHUAIMS
#\\\|4BVG5RIC7DCDNUOGULNKOGUYFCYN6JEEY24LAWI22OZ2AVWVDGX \ / AMOS7 \ YOURUM ::
#\[7]GTAGC3DTXXMPHFMLUQDYJHT5QXMZRYKF7BNIQY3XHSD57TM2KUBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
