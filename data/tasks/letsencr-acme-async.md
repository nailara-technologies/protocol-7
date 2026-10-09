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

## state record [ piece 2, fixed 2026-10-09 ]

`clients.https.request` calls `on_done` with `{ ok, status, body, headers,
params }` [ header names lower-cased : `replay-nonce`, `location` ]. ONE
fix needed there first : `clients.http.parse_response` [ shared by the
https http/1.1 path ; check the h2 path too ] keeps only the LAST
value of a repeated header -- acme sends several `Link` headers [ `rel="up"`,
alternate chains ] : repeated headers become an array ref [ or a joined
list under a second key ] without changing single-valued callers.

```
<letsencr.child.orders>->{ $order_id } = {   ## $order_id = base.gen_id
    order_id      => $order_id,
    reply_id      => $reply_id,              ## answered exactly once
    domains       => [ ... ],  primary_domain => $d,  staging => 0 | 1,
    order_url     => $location,  order => $order_json,
    step          => 'new' | 'authz' | 'setup' | 'propagate' | 'respond'
                     | 'poll_authz' | 'finalize' | 'poll_order' | 'download'
                     | 'cleanup' | 'done' | 'failed',
    authz         => {                      ## keyed by authz url
        $url => {
            domain   => $d,   wildcard => 0 | 1,
            type     => 'http-01' | 'dns-01',
            token    => $t,   key_auth => $k,   dns_value => $v,
            challenge_url => $c,
            status   => 'pending' | 'set_up' | 'responded' | 'valid'
                        | 'invalid' | 'reused',   ## reused : authz already valid
            setup    => { httpd => 0|1 }  or  { $ns_target => 0|1, ... },
            polls    => $n,
        },
    },
    nonce         => $replay_nonce,          ## from the last response
    deadline      => $epoch,                 ## whole order, e.g. 15 min
    timer         => $event,                 ## the one pending poll timer
    error         => $msg,
};
```

- every async call carries `params => { order_id => $order_id, authz =>
  $url }` ; handlers fetch the record by `order_id`, a missing record = a
  late reply after cleanup -> log at level 2 and drop
- one handler per step : `letsencr.child.acme.on_<step>` ; a step function
  `letsencr.child.acme.step_<step>` starts the next request. the failure
  path is ONE function [ `letsencr.child.acme.fail` : cleanup, reply false,
  delete the record ]
- an authz already `valid` at fetch time is marked `reused` and skips set-up
  \ respond -- logged at level 1, so a reused authz is visible in the log
- set-up : `setup` holds one flag per target ; `respond` starts when all
  flags are 1 ; a set-up reply `false` fails the authz
- the `deadline` is checked in every handler and by the poll timer

## status [ 2026-10-09 ]

- stage A DONE + live : eb0cf4658, 4f4d1cbda. local staging run [ failure
  path : httpd ready before respond, one false reply, cleanup ] ; atom
  production run for the fresh name `ui.data.v7.ax` [ full success path,
  first real http-01 validation through the new flow, cert installed ]
- old blocking flow removed [ continue_challenge_processing,
  poll_challenge_status, acme_get_authorization, acme_finalize_order,
  download_certificate, respond_to_challenge, create_*_challenge,
  check_dns_propagation, acme_verify_challenge, acme_renew,
  parent.handler_challenge_confirmed ] -- unreachable, checked transitively
- OPEN stage B : acme_new steps 1-4 [ directory, account, order ] still
  block the child a few seconds ; client globals guarded only by the queue
- OPEN : dns-01 live needs our nameservers delegated ; the parent logs
  `ACME enrollment success` three times per certificate
- unrelated dead modules found on the way [ not removed ] :
  parent.{query_httpd_vhosts, send_httpd_vhost_query,
  handler_httpd_vhost_reply, handler_httpd_vhost_error, send_to_child,
  send_from_child, handler_challenge_validated, handler_httpd_reload_reply},
  child.extract_rsa_{modulus,exponent}

## split

- kimi [ k3 : concurrency ] : pieces 1 + 4 + 5 with tests, after the
  state record [ 2 ] is fixed in writing
- claude : 2 + 3 + 6 + 7 [ the flow \ reply wiring ] and the review

#,,,,,.,,,,,,,..,,.,,,..,,..,,,,,,,..,..,,.,.,..,,...,..,,,,,,...,,.,,,..,.,,,
#O4UT4CA7D4VIDXQVX7GPUIGHKDNKP45XVGEF66JNTJ3TOLVCW3BXA25LVKJHBDAGSJY36OOUEVVZ6
#\\\|KGRF4DOQGQ7HZFSCNUZGDJMVY7DXFQRSDGRFLFRTROZX25NWRP6 \ / AMOS7 \ YOURUM ::
#\[7]MDAHYGD7FTF5IGOOK6STUEF4G43LBSXQSBJVAUNGYKD7ZJAE4IDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
