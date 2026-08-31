---
name: clients-http
description: clients.http.* and clients.https.* async non-blocking HTTP/HTTPS client namespaces
metadata:
  type: project
  originSessionId: session-33
---

## 2026-08-30/31: h2 support added, two response-body paths now exist — keep them in sync

`clients.https.*` gained real HTTP/2 support (`clients.https.h2.send_request`,
`clients.https.h2.handler.io`, negotiated via ALPN in `clients.https.request`/
`clients.https.handler.handshake`) alongside the original http/1.1 path
described below (`clients.https.handler.io` + `clients.http.parse_response`).
**These are two separate response-handling code paths that silently diverge if
you fix one and not the other** — confirmed live: a 2026-08-30 fix taught only
the h2 path to decompress (`content-encoding`) and charset-decode
(`Encode::decode`, default UTF-8) the response body; the h1.1 fallback kept
handing raw wire bytes downstream with neither step, for another full day,
until a user-reported mojibake regression (`fÃ¼r` for `für` — classic
UTF-8-as-Latin1 double-encoding) traced it back. Real-world impact went beyond
cosmetic: since every caller in this codebase requests
`gzip, deflate, zstd` (see `site-yaml.async_fetch.headers`), a server that
actually honored that on the h1.1 path would have handed still-compressed
binary straight to HTML extraction, producing content-free job records (see
[[topic-jobsite-assessment-accuracy]]'s 2026-08-31 entry for the downstream
consequence of exactly that).

**Fix shape**: extracted the decompress+decode logic into one shared
`clients.https.decode_body($body, $headers_hashref, $log_tag)`, called from
both `clients.https.h2.send_request`'s `$on_response` and
`clients.https.handler.io`'s EOF branch. Any future response-processing change
to either path should go through this shared helper, or be added to both
explicitly — there is no structural guarantee the two paths stay behaviorally
identical otherwise.

## clients.http.* (8 modules, session 33)

Non-blocking HTTP using IO::Socket::IP + event loop IO watcher. No fork, no LWP.

**Interface:**
```perl
<[clients.http.post]>->({
    url     => 'http://host/path',
    body    => $json_string,
    timeout => 10,
    on_done => 'my.handler.name',
    params  => { forwarded => 'to callback' },
    headers => { 'X-Foo' => 'bar' },   # optional extra headers
});
```

**on_done handler receives:** `{ ok => TRUE/FALSE, status => 200, body => '...', params => {...} }`

**Flow:** request → connect + sync write small payload → event.add_io r watcher →
handler.io accumulates → EOF → parse_response → on_done callback

**Modules:** init_code, request, post, get, handler.io, handler.timeout, cleanup, parse_response

## clients.https.* (9 modules, session 33)

Parallel namespace adding SSL handshake phase. Same interface + `ssl_verify` param.

```perl
<[clients.https.post]>->({
    url        => 'https://host/path',
    body       => $json,
    ssl_verify => 0,    # optional: disable for self-signed/internal certs (default: TRUE)
    ...same as clients.http.post...
});
```

**Flow:** TCP connect → start_SSL deferred (SSL_startHandshake=>0) → rw watcher →
handler.handshake: connect_SSL loop (returns on WANT_READ/WANT_WRITE) → sync write →
switch to r watcher → handler.io (shared logic with http)

**SSL internal frame handling:** handler.io checks `$IO::Socket::SSL::SSL_ERROR` before
treating 0 bytes as EOF — SSL_WANT_READ/WRITE means internal TLS frame consumed, not EOF.
Same check in handshake write loop for WANT_WRITE during syswrite.

**clients.http.parse_response shared** by both namespaces — scheme-agnostic HTTP parsing.

## Usage so far

- **jobsite.sync.push** → clients.http.post (replaced fork+LWP pattern)
- **kimi-web.cmd.dispatch_parallel** → clients.http.post (replaced broken http_post_async)

## Load in zenka

Add `clients.http` or `clients.https` to `modules.load` in start file.
Whitelist auto-populated on restart. No explicit whitelist entries needed.

#,,,,,,,,,,.,,.,.,,,.,,,.,,,.,,..,.,,,,..,,.,,..,,...,...,,..,,..,.,,,.,,,...,
#TJXAP26BUIXDPFBNZT4ENNMG33TET4SFSS23RRAQWOIEKZHH3XBBITTYMEQZ5BV54TX2QTGZFFQNC
#\\\|BP5AHDPTM3EE2QXO6KTH6FFKNPPIB3MB5EPRQZOYWO6JFZRAWT6 \ / AMOS7 \ YOURUM ::
#\[7]K5RKKBYFEPEPQULGANBCSXP4EHRSYKXQP2GEBCKSWA4LYBGU3SCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
