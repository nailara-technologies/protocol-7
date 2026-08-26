---
name: clients-http
description: clients.http.* and clients.https.* async non-blocking HTTP/HTTPS client namespaces
metadata:
  type: project
  originSessionId: session-33
---

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

#,,,,,.,.,,.,,,,.,,,,,,.,,..,,,,,,,..,,.,,,.,,..,,...,...,..,,,,,,.,.,,,,,..,,
#HGBUNRLOXOX4SBLUAGOD6AUNLGXBETFOPTOFN7GQSKYEGDZY7H6V7B756NJEXRPP3MEM2IEHFHQZ2
#\\\|2N5YT53WMRYLNSDTSUCKLTG5TE5DTO47LEDX2NLQ5RFP6UJUKCI \ / AMOS7 \ YOURUM ::
#\[7]GIE4G4HCUMGTCLRY3STG54NZIEYXWV2W5CFUXILO72WAFJL3PKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
