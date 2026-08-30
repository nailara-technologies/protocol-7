## task: add proxy CONNECT support to clients.https.request

### goal

`clients.https.request` (just gained real HTTP/2 support, commit
`4c4ea552c`, `data/tasks/clients-https-http2-support.md` — read that task
file for the full HTTP/2 background, it's assumed context here) connects
directly to the origin host — no proxy awareness at all. This is the
second, separate reason site-yaml still can't be usefully switched over to
it: this host reaches the internet through a forward proxy
(`http_proxy`/`https_proxy` env, an HTTP proxy doing `CONNECT` tunneling —
confirmed live all day today, including the HTTP/2 verification work
itself, which built this tunnel by hand outside the zenka because the real
client doesn't have it).

Add `CONNECT`-tunnel support: when a proxy is specified, connect to the
*proxy*, issue an HTTP `CONNECT` to the real target, wait for `200`, and
only then proceed with the existing (unchanged, correct) TLS handshake on
that now-tunneled socket. Without a proxy specified, behavior must be
byte-identical to today.

**Explicitly not in scope**: SOCKS5 proxy support (this host also has
`ALL_PROXY=socks5://...` set, but the `http_proxy`/`https_proxy` HTTP-CONNECT
proxy is the one actually used for HTTPS traffic in every test done today —
don't add SOCKS handling speculatively). Also not in scope: wiring any real
caller (site-yaml) to use this — that's the next task after this one lands
and is verified standalone.

---

### where to implement

modify:

| file | change |
|---|---|
| `src/clients.https.request` | accept an optional `proxy` param (a proxy URL string, e.g. `http://10.0.110.7:4040` — caller-supplied, this module must NOT read `$ENV{http_proxy}`/`https_proxy` itself, see design notes); when present, connect to the proxy instead of the origin and perform the `CONNECT` handshake before the existing `start_SSL` call |

no new files should be needed for this — it's a self-contained addition to
the existing pre-handshake connect logic, not a new async state (see
design notes on why a bounded blocking read is acceptable here,
specifically, unlike everything else built today).

---

### design notes — decisions already made, don't re-open

- **Proxy is a caller-supplied param, not auto-detected from env.** Same
  principle as the HTTP/2 task's header-set decision: this is a generic
  transport used by more than one caller; reading ambient `http_proxy`/
  `https_proxy` env vars inside the transport layer is exactly the kind of
  hidden-magic-in-a-shared-module problem this project has been bitten by
  before (unrelated site-yaml env-var investigation earlier today — a
  transport that silently changes behavior based on process environment is
  harder to reason about than one where the caller explicitly decides).
  Accept `$p->{'proxy'}` as a plain URL string; parse host/port from it the
  same way the existing code already parses the target `url`.
- **The proxy CONNECT exchange may be a bounded BLOCKING call, matching
  this file's own existing precedent** — `clients.https.request` already
  does a synchronous blocking `IO::Socket::IP->new(..., Timeout => 7)` for
  the plain TCP connect, unconditionally, today. Adding one more bounded
  blocking round-trip (send `CONNECT ...`, read until the blank line
  ending the proxy's response headers, same ~7s-class timeout) for the
  proxy handshake specifically is consistent with what's already there,
  not a new category of risk — converting the *entire* connect sequence
  (TCP + optional CONNECT + TLS) to a fully non-blocking multi-state
  sequence is real, separate, valid future hardening, but out of scope
  here. Don't build a new async state machine for just this step; a plain
  blocking `sysread`/readline loop bounded by a short timeout, right next
  to the existing blocking `IO::Socket::IP->new` call, is the right size
  for this task.
- **SNI / `SSL_hostname` stays the origin host, never the proxy.** The
  socket's peer changes (proxy instead of origin) but everything else
  about the subsequent TLS handshake — hostname for SNI, ALPN list,
  verify mode — is unchanged and must still reference the real target.

---

### implementation sketch

roughly, inserted between the existing `## parse url ##` block and the
existing `## tcp connect ##` block:

```perl
my $proxy = $p->{'proxy'} // '';

my ( $connect_host, $connect_port ) = ( $host, $port );
if ( length $proxy ) {
    my ( $proxy_host, $proxy_port ) = $proxy =~ m{^https?://([^:/]+):(\d+)}
        or do {
            <[base.logs]>->( 0, 'clients.https.request: cannot parse proxy url: %s', $proxy );
            return undef;    ## same immediate-failure shape as the existing url-parse-failure branch above ##
        };
    ( $connect_host, $connect_port ) = ( $proxy_host, $proxy_port );
}

## tcp connect [ to proxy if set, else straight to origin -- unchanged otherwise ] ##
my $tcp_sock = IO::Socket::IP->new(
    PeerHost => $connect_host,
    PeerPort => $connect_port,
    Type     => SOCK_STREAM(),
    Timeout  => 7,
);
## ... existing tcp-connect-failure handling, unchanged ...

if ( length $proxy ) {
    $tcp_sock->blocking(1);    ## bounded blocking handshake, see design notes ##
    print {$tcp_sock} "CONNECT $host:$port HTTP/1.1\r\nHost: $host:$port\r\n\r\n";
    my $resp = '';
    $tcp_sock->timeout(7);
    while ( my $line = <$tcp_sock> ) {
        $resp .= $line;
        last if $line eq "\r\n" or $line eq "\n";
    }
    if ( $resp !~ m{^HTTP/1\.[01]\s+200} ) {
        <[base.logs]>->( 0, 'clients.https.request: proxy CONNECT failed: %s', $resp );
        $tcp_sock->close;
        <[event.add_idle]>->({ 'handler' => $on_done, 'params' => { 'ok' => FALSE, 'error' => "proxy connect failed: $resp", 'params' => $params } });
        return undef;
    }
    $tcp_sock->blocking(0);    ## back to non-blocking for everything after this point ##
}

## ... existing start_SSL call, completely unchanged from here on ...
```

this is a sketch, not gospel — the real implementation should match this
file's actual current structure and error-handling conventions exactly
(it already has a well-established pattern for the tcp-connect-failure and
start_SSL-failure cases; the proxy-CONNECT-failure case should look and
feel like a third instance of that same pattern, not something novel).

---

### pitfalls

- **don't forget to set the socket back to non-blocking (`$tcp_sock->
  blocking(0)`) after the bounded blocking CONNECT exchange completes** —
  everything from `start_SSL` onward depends on non-blocking I/O exactly
  as it already does today; leaving the socket in blocking mode would
  silently break the whole downstream event-driven handshake pump.
- **the proxy response's `Content-Length`/body, if any, on a non-200
  CONNECT failure** — don't worry about draining it correctly, this is an
  error path; logging the raw response text (as sketched above) and
  failing cleanly is sufficient, don't over-engineer error-body parsing
  here.
- **`$host`/`$port` (the real target) must NOT be overwritten by the proxy
  host/port** — they're still needed unchanged for the `CONNECT` request
  line, the `SSL_hostname` (SNI), and (for the h2 path landed in the prior
  task) `$state->{'host'}`/`$state->{'port'}` used to build `:authority`.
  Keep the proxy host/port in their own separate variables, as sketched.

---

### verify

```bash
bin/dev/ptd -c src/clients.https.request
```

### test plan

live, against the real proxy on this host and a real target — same
methodology as the HTTP/2 task's own verification, but through the real
`clients.https.request`/`.get` code path instead of a hand-rolled script:

```perl
## via devmod eval-code, any zenka with clients.https loaded ##
<[clients.https.get]>->({
    url     => 'https://www.stepstone.de/jobs/devops-engineer/in-Offenburg',
    proxy   => $ENV{'https_proxy'},    ## or the literal proxy url for this host ##
    headers => { ## the header set from the HTTP/2 task's verified findings ## },
    timeout => 20,
    on_done => 'some.reply.handler',
});
```

expected: `on_done` fires `ok=>TRUE, status=>200`, real decompressed HTML
body — the same result the HTTP/2 task's standalone script already proved
reachable, but now through the actual `clients.https.request` code path
with no hand-rolled socket code involved.

also confirm the no-proxy case is unaffected: the same call with `proxy`
omitted, against any plain reachable HTTPS target, must behave exactly as
it did before this task (byte-identical to `4c4ea552c`'s state).

---

## signatures_note

module files end with a 4-line `#,,,` AMOS7 data signature block. do not
hand-write or copy those blocks — leave signing to `bin/Protocol-7
sourcecode update-signatures`. no new files, no `subroutines.load-early`
changes expected for this task.

---

### dispatch

model: k2.7

prompt: |
  implement the task at data/tasks/clients-https-proxy-connect.md

  read data/tasks/clients-https-http2-support.md first for context on what
  clients.https.request already does and why (real HTTP/2 support landed
  same day, commit 4c4ea552c) -- this task adds the one piece that work
  deliberately left out.

  read src/clients.https.request in full before changing anything -- this
  is a small, surgical addition to its existing connect sequence, not a
  rewrite. the "design notes" section has already-settled decisions
  (proxy as a caller param not env-auto-detected; a bounded blocking
  CONNECT exchange is fine here, matching this file's own existing
  blocking TCP-connect precedent) -- don't re-derive or second-guess them.

  the "implementation sketch" is a sketch, not literal code to paste in --
  match this file's actual current variable names, error-handling shape,
  and logging conventions exactly.

  test live against a real proxy and a real HTTPS target before reporting
  done, not just a syntax check -- this task exists specifically because a
  synchronous, working proxy tunnel is the one thing standing between
  today's HTTP/2 work and it actually being usable.

  use $ARG not @_ where the file already does; lowercase comments; bracket
  annotations [ like this ]; do not touch the trailing signature blocks.

#,,,,,.,.,.,.,,,,,,.,,.,,,.,,,.,.,..,,,,.,,..,..,,...,...,,,.,...,,.,,.,.,..,,
#IXEZIXOMF7E3A5QXX5OSO6FDIX742KN4BKZQJGYIOMF6U45FL2BT5YDTGIFUTAMHR5XWVISMJ2DJW
#\\\|GEPD23CQ3P6SF5X62BTSNEYMCKNMMKUS6KQVF3PGCDFUNU24RBU \ / AMOS7 \ YOURUM ::
#\[7]BATBT7SLHC2THHQPQBQVTSZI4TW5JUO2CTJOLMGRAUIKGNVER6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
