# letsencr : acme flow on the event loop [ clients.https ]

brief [ 2026-10-09 ]. the letsencr child runs the whole acme order as ONE
blocking call : `LWP::UserAgent` [ `letsencr.child.acme_http_request` ],
`sleep` loops [ `poll_challenge_status`, `check_dns_propagation` ],
blocking `Net::DNS::Resolver`. the event loop never runs in between, so a
`route-send` made inside the flow only lands in the session output buffer
[ `base.protocol-7.command.send.local` ] and leaves AFTER validation :

- http-01 : `httpd.setup-acme-challenge` reaches httpd only after the
  continuation returns -> letsencrypt fetches a missing file. today's
  production cert [ protocol-7.network on atom, 04:21 utc ] most likely
  came from a REUSED authorization [ an already valid authz skips nothing
  in our flow, the poll just returns valid ] -- check atom's httpd log for
  `challenge file not found` [ level 1 ] to confirm
- dns-01 : the nameserv provider [ `nameserv.add-txt` over cube,
  `data/tasks/letsencr-dns01-own-nameservers.md` ] has the same problem --
  this task replaces step 2 of that one

## goal

the order is a state machine driven by replies and timers. every external
step is async, and the next step starts in the reply handler :

```
new order -> authorizations [ per authz ] -> challenge set-up
  [ http-01 : httpd.setup-acme-challenge  \  dns-01 : nameserv.add-txt on
    both servers ] -> REPLY received -> propagation \ self check [ timer
  polled, async dns ] -> respond to challenge -> poll authz [ timer ]
  -> all valid -> finalize -> poll order [ timer ] -> download -> cleanup
  [ httpd.cleanup \ nameserv.remove-txt, success AND failure ] -> reply
```

## pieces

1. **acme transport** : `acme_http_request` on `clients.https.request`
   [ method, url, body, headers, `on_done` handler name, `params` ]. jws
   signing and nonce handling stay as they are ; `get_fresh_nonce`,
   `fetch_acme_directory`, `download_certificate`, `http_get_url`,
   `acme_verify_challenge` follow. replay-nonce from every response is
   kept for the next request [ saves a round trip ]
2. **flow state** : one record per order [ domains, authz urls, per-authz
   challenge + status, step, reply_id, deadlines ] in
   `<letsencr.child.orders>` keyed by order url. handlers look it up from
   `params`, never from globals of one order [ two orders may overlap ]
3. **set-up before respond** : the challenge set-up is sent WITH a reply
   handler ; `respond_to_challenge` only runs once httpd \ both nameservers
   confirmed. a failed set-up fails that authz, cleanup runs
4. **polling** : `event.add_timer` per poll [ the handler gets the EVENT,
   data at `->w->data` -- ai-mem route-send-buffers-timer-gets-event ],
   backoff as today, an overall deadline per order
5. **dns checks** : async resolver queries [ Net::DNS `bgsend` +
   `bgread` on an io watcher, or a small `clients.dns` ] -- propagation
   asks both OWN authoritative servers directly, no recursion
6. **reply** : the deferred `reply_id` [ `base.callback.cmd_reply` ] is
   answered exactly once, on success, failure or deadline
7. **cleanup** : challenge records \ files removed on every exit path ;
   `letsencr.child.util.cleanup_challenge` and the never-called
   `*_delete_txt` folded into one cleanup step

## constraints

- reuse `clients.https` as is ; fix it there if acme needs something
  [ e.g. response headers for `Replay-Nonce` \ `Location` ] -- check what
  `on_done` receives first
- `letsencr.child.send_to_parent` is a stub : remove the `manual` provider
  path or make it a real parent message
- the child stays the place for acme work [ isolation ], but it no longer
  blocks : renewals and enrollments can run while an order waits
- every new namespace call [ clients.https, nameserv ] in the child's
  `modules.load` -- missed twice before
- tests deliver replies explicitly and pass event-shaped objects to timer
  handlers [ stub tests hid all three async bugs in the enrollment work ]
- live test on letsencrypt STAGING with a domain that has no valid authz
  [ a fresh name ] -- otherwise reuse hides the challenge path again

## split

- kimi [ k3 : concurrency ] : pieces 1 + 4 + 5 with tests, after the
  state record [ 2 ] is fixed in writing
- claude : 2 + 3 + 6 + 7 [ the flow \ reply wiring ] and the review

#,,,.,.,,,...,...,..,,..,,,,,,,..,...,,.,,..,,..,,...,...,.,,,.,,,.,.,,..,...,
#SUZDG6FJKCZPSYW52BOD2MKJOBU4XR7TO2THWESSYGK6IIJXBVA7IISJ4VHELJQ6D7UIZGZ573PYG
#\\\|J5OZSGFXDZKCBXE7CDOAAKMF3PY4J5WD7E262V35OUZRLMCEOKO \ / AMOS7 \ YOURUM ::
#\[7]RDWW5CSZQKMJN2CKXZMOS5KX7JLNRXAIPGRPA42PVDTKAOHARQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
