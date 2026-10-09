---
name: route-send-buffers-timer-gets-event
description: route-send only BUFFERS until the event loop runs [ no round trip inside one blocking call ] ; an event.add_timer handler gets the EVENT [ data at ->w->data ]
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

also : base.event.* is swapped to event.* at pre_init -- call `<[event.add_timer]>`, never
`<[base.event.add_timer]>` [ host-edit.flow.schedule died on it, 998f9175a ].

**Why:** stub-based tests hide all three -- stubs act instantly and get plain hashes.
**How to apply:** when reviewing \ writing async zenka code, check every route-send whose
result is used in the same call, every timer handler's first arg, and that tests deliver
replies explicitly and pass Event-shaped objects [ see test-letsencr-enroll.pl ].

#,,,,,,.,,..,,..,,,,.,,.,,,,,,,,.,,..,,..,.,.,..,,...,...,,.,,...,...,,.,,.,.,
#4SQXWWRF66PKTCIMQLYSYMHCXNGJVRBSLC4MV5A2QSUZNWQCTCNN4UQJONC6MSVBAT5OSLK2AIKN4
#\\\|OOK333HRN6ARF6UV4XUK4P53BJ7BYYJXTGTX7HKJCXND22UZRZD \ / AMOS7 \ YOURUM ::
#\[7]Q3VKU3ID4ZJG4VM5S6X6ZHSZIFEG7TC5UQY7UG6L6SHIOUILYQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
