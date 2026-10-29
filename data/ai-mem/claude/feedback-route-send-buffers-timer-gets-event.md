---
name: route-send-buffers-timer-gets-event
description: route-send only BUFFERS until the event loop runs [ no round trip inside one blocking call ] ; timer handlers get the EVENT [ ->w->data ] ; reply handlers get ONE hash [ params inside ] ; read the payload via base.reply.mode_text [ remote routes answer in call_args.args ] ; add_timer ignores `delay` [ fires at once ]
metadata:
  type: feedback
---

two async gotchas found reviewing kimi's letsencr enrollment, 2026-10-09 [ b6e3750c7 ] :

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
   that : "retry in 1800 s" ran within seconds, fixed 9d990defc ].

also : base.event.* is swapped to event.* at pre_init -- call `<[event.add_timer]>`, never
`<[base.event.add_timer]>` [ host-edit.flow.schedule died on it, 8ff2c9c5b ].

**Why:** stub-based tests hide all three -- stubs act instantly and get plain hashes.
**How to apply:** when reviewing \ writing async zenka code, check every route-send whose
result is used in the same call, every timer handler's first arg, and that tests deliver
replies explicitly and pass Event-shaped objects [ see test-letsencr-enroll.pl ].

- 2026-10-23 : the cube wire carries ONLY call_args->{args} [ base.protocol-7.command.send.local:152 ] -- extra call_args keys [ peer_addr, headers .. ] vanish. 6CJ admission [ 231f0dc7b ] passed 122 stubbed checks and was inert live. pack side data into args [ json ] ; a route-send stub must deliver args only

- **reply payload : read it with `<[base.reply.mode_text]>->($call)`, never `$call->{'data'}` alone** [ 2026-10-29 ] : an external route [ `external.<host>.<zenka>` ] answers in `call_args.args`. jobsite.handler.queue-depth-reply read data only with a `// 0` default -> every remote depth reply read 0 = "drained" 3 s after the import [ 1127 queued on delta ; fixed d7ab4301d ]. an unreadable \ false reply must mean "unknown", never a default that is also a valid answer

#,,,,,,.,,.,,,.,.,,.,,.,.,,..,..,,,..,...,...,..,,...,...,.,.,,,.,...,,,,,,..,
#HTDCXOBGBAPEBL7MX2A7EWGUXTTZLYNQRCJELFCJSBX3B7TZNYRCIKYEH4CAYA7G4ALJLQQ4NDBQE
#\\\|APYK3IDLWX4PR6JWZNMXXTJSGF6OKQAMMY6TU3P74WTOS6UXS3D \ / AMOS7 \ YOURUM ::
#\[7]WY3RLI3S7NFENEGSMDQBMVVRPEYIYF24MCHB5GS3ZKHEMP5BAQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
