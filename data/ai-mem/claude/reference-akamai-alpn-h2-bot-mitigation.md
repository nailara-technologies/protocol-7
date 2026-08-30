---
name: reference-akamai-alpn-h2-bot-mitigation
description: generalizable finding, not site-yaml-specific — a TLS ClientHello that never offers h2 in ALPN gets silently black-holed by Akamai-style bot mitigation (no error, no reset, total silence until timeout); a realistic browser header set is also required past that. LWP and this project's own clients.https client (pre-fix) both hit this identically
metadata:
  type: reference
---

## the finding

Confirmed live, 2026-08-30, against `stepstone.de` (behind Akamai — visible
via the `server-timing: ak_p` response header and `_abck`/`ak_bmsc`/`bm_mi`/
`bm_sz` cookies, Akamai's own Bot Manager markers) through a real forward
proxy on this host:

- A TLS handshake whose `ClientHello` ALPN extension offers **only
  `http/1.1`** completes successfully (proxy `CONNECT` fine, TLS handshake
  fine, cipher negotiated fine) — then the connection goes **completely
  silent**. Zero bytes ever arrive, no TCP reset, no TLS alert, nothing,
  for the full duration of whatever timeout the client has. This is not a
  connectivity problem and cannot be fixed by retrying, raising timeouts,
  or tuning headers — real browsers virtually always offer `h2` in ALPN,
  so a client that only ever offers `http/1.1` is itself read as a bot
  signal, and the response is to black-hole rather than reject.
- Adding `h2` to the ALPN list (`SSL_alpn_protocols => ['h2', 'http/1.1']`
  for `IO::Socket::SSL`) alone is *necessary but not sufficient*. A
  request sent with a minimal header set still gets a fast, explicit
  `RST_STREAM` (HTTP/2 stream reset, not silence) — getting past ALPN only
  clears the first gate. A second, request-level check inspects the
  headers themselves.
- The header set that got a genuine `200 OK` with real page content:
  `user-agent` (a real browser UA string), `accept`, `accept-language`,
  `accept-encoding` (see below), `upgrade-insecure-requests: 1`, and the
  `sec-fetch-dest`/`sec-fetch-mode`/`sec-fetch-site`/`sec-fetch-user`
  quartet — headers a real browser navigation always sends and a bare
  scripted request usually doesn't.
- Responses came back Brotli-compressed (`content-encoding: br`) by
  default. This project's `IO::Uncompress::AnyUncompress` does not support
  Brotli (different codec family entirely from gzip/zip/zstd/bzip2/xz/
  lzma/lzip/lzf/lzop, which it does cover). Fix: request
  `accept-encoding: gzip, deflate, zstd` and never offer `br` — a
  well-behaved server won't send a format the client never claimed to
  accept.

## why this matters generically, not just for one site

Any pure-Perl HTTP client built on `IO::Socket::SSL` (this project's own
`clients.https.request`, pre-fix, and `LWP::UserAgent`, which has no
HTTP/2 support at all and cannot be extended to gain it) will hit this
identically against *any* target behind similar bot mitigation, regardless
of proxy, regardless of network path. This is not specific to `stepstone.de`
— expect the same wall against any Akamai/Cloudflare/similar-WAF-protected
target that inspects ALPN + header realism as a bot signal. Perl's HTTP/2
ecosystem is thin but real: `Protocol::HTTP2::Client` (pure Perl, no XS,
now a project dependency — `.deps/profiles.yaml` `zenka-common` profile,
`libprotocol-http2-perl`) is a pure protocol codec (`next_frame`/`feed`,
no transport of its own) that plugs cleanly onto an already-correct
non-blocking `IO::Socket::SSL` handshake — it does not require adopting
`AnyEvent` or any transport of its own, despite its own POD synopsis using
`AnyEvent::Handle`.

**Also learned the hard way**: `Protocol::HTTP2::Client->request()`'s
`on_done` callback fires on a stream reset too, not just success, *unless*
you also pass a per-request `on_error` inside the same request hash (not
just at the client-constructor level, which only catches connection-level
protocol errors) — without it, a real `RST_STREAM` is indistinguishable
from a genuine empty `200`.

## how to apply

Before assuming a fetch failure against any modern public web target is a
network/proxy/config problem, check whether the target sits behind a
WAF/bot-mitigation layer (response headers from a working request via
`curl`, e.g. `server-timing: ak_p`, `cf-ray`, similar) and whether the
failing client can even speak HTTP/2 at all. `curl` succeeding while a
Perl client fails identically-configured is a strong signal for exactly
this, not a proxy or DNS issue — verify with a minimal ALPN test
(`IO::Socket::SSL::start_SSL` + explicit `SSL_alpn_protocols`) before
chasing anything else.

This project's `clients.https.request`/`.get` (as of commit `4c4ea552c` +
the proxy-CONNECT commit right after it) already handles all of this
correctly — offers `h2` in ALPN unconditionally, speaks real HTTP/2 framing
when negotiated, supports proxy `CONNECT` tunneling, and decompresses
gzip/deflate/zstd bodies (never requests `br`). Any new caller hitting
this exact wall should use it directly rather than rediscovering any of
the above.

see [[site-yaml-async-fetch-fork-memory-risk]] for the incident this was
found chasing, and [[topic-site-yaml-zenka]] for broader context.

#,,,.,.,,,,.,,,.,,.,,,,.,,,,.,,,.,,,,,,.,,,..,.,.,...,...,...,.,,,,,,,.,.,,,.,
#W5WI4IG75TXSQWW2XCEYA6QDLNIKZXYKVPHBDTZSZ5N6G7JSPOGTYGSOV6FFUZDLQKFXBOURYNP66
#\\\|7OLJAMAQ2YB4EVMSAKVL377HUPR2WLG3N6PAEVXF7T5U2LDW5VS \ / AMOS7 \ YOURUM ::
#\[7]M7QDA2PZ27AKRQIETYNFSDT65GXM72LXSKZVXBUKT32E3DYGP6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
