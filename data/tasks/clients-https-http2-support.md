## task: add real HTTP/2 support to clients.https.request

### goal

`clients.https.request`/`clients.https.get` is the project's general-purpose
non-blocking HTTPS client (`IO::Socket::SSL` deferred handshake pumped
through `event.add_io`, correct already — see "what's already right" below).
It's HTTP/1.1-only. Some real-world targets sit behind bot-mitigation
(confirmed: Akamai, on stepstone.de, reached through this host's forward
proxy) that silently black-holes any connection whose TLS `ClientHello`
doesn't offer `h2` in its ALPN extension — no error, no TCP reset, just
total silence until the client's own timeout fires. This is not a proxy
problem and not fixable by retrying, timeouts, or headers alone: it's a
missing protocol capability. `LWP::UserAgent` has the exact same gap and
cannot be extended to fix it either (it has no HTTP/2 support of any kind).

Add real, correct HTTP/2 request/response support so that when a server
negotiates `h2` via ALPN, `clients.https.request` speaks actual HTTP/2
framing (via `Protocol::HTTP2::Client`, now installed — `.deps/profiles.yaml`
`zenka-common` profile, `libprotocol-http2-perl`/`Protocol::HTTP2`) instead
of failing or falling back to broken plain-text HTTP/1.1 over an h2-only
connection. The existing HTTP/1.1 path must stay byte-identical in
behavior for any target that doesn't negotiate `h2`.

**Explicitly not in scope for this task**: switching any actual caller
(`site-yaml`, `proxy`, etc.) over to use `clients.https.request` instead of
`LWP::UserAgent`/`base.fork`-based workers. This task only makes the
*client* correct and capable; wiring `site-yaml`'s fetch to use it is a
separate, later task once this one is proven standalone.

---

### verified findings — do not re-derive these, they're confirmed live

All of this was proven today with a standalone script
(`IO::Socket::INET` → proxy `CONNECT` → `IO::Socket::SSL` handshake →
`Protocol::HTTP2::Client`), against the real target through the real
proxy, not simulated:

1. **ALPN must offer `h2`.** `SSL_alpn_protocols => ['h2', 'http/1.1']` on
   the `start_SSL` call. With `['http/1.1']` only: TLS handshake succeeds
   fine, then total silence — zero bytes ever received, not even a partial
   response, for the full timeout duration. With `h2` offered, the server
   selects it immediately (`$sock->alpn_selected() eq 'h2'`) and actually
   responds.
2. **A minimal request still gets `RST_STREAM` (stream-level reset, error
   code 2).** Getting past ALPN is necessary but not sufficient — the
   request itself also needs a realistic header set or it's rejected at
   the HTTP/2 stream level (not silently this time — a real, fast
   `RST_STREAM`, distinguishable from a real response). The header set
   that got a genuine `200 OK` with real content (125,946 bytes, real
   page):
   ```
   user-agent: Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0
   accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
   accept-language: de-DE,de;q=0.9,en;q=0.8
   accept-encoding: gzip, deflate, zstd    ## deliberately NOT br -- see point 4
   upgrade-insecure-requests: 1
   sec-fetch-dest: document
   sec-fetch-mode: navigate
   sec-fetch-site: none
   sec-fetch-user: ?1
   ```
   These are caller-supplied `headers` (via the existing `$p->{'headers'}`
   param), not something this task should hardcode as a library default —
   see "design notes" below.
3. **`Protocol::HTTP2::Client`'s `on_done` fires on stream reset too, not
   just success** — its `request()` only routes to the `on_error` callback
   if you pass `on_error` **inside the same `%h` request hash**; without
   it, every stream closure (including `RST_STREAM`) silently goes to
   `on_done` with `undef` headers and empty data, indistinguishable from a
   real-but-empty response unless you check for it. Always pass a
   per-request `on_error => sub { my $code = shift; ... }` — check
   `Protocol::HTTP2::Client::request`'s own source (`stream_cb(...,
   CLOSED, ...)` block) if the exact mechanics matter.
4. **Response arrived `content-encoding: br` (Brotli) by default.**
   `IO::Uncompress::AnyUncompress` (already a project dependency, loaded
   fine, no new install needed) does NOT support Brotli — it covers gzip,
   zip, zstd, bzip2, xz, lzma, lzip, lzf, lzop, raw/zlib deflate, but
   Brotli is a different codec entirely, not in that family. Solution:
   request `accept-encoding: gzip, deflate, zstd` (omit `br`) — a
   well-behaved server won't send Brotli if the client never offered it.
   Confirmed this is sufficient; do not add a Brotli decoder dependency
   for this task.

---

### what's already right — reuse, don't rewrite

`clients.https.request` (`SSL_startHandshake => 0` + `event.add_io` +
`clients.https.handler.handshake` pumping `connect_SSL()` via
`SSL_WANT_READ`/`SSL_WANT_WRITE` until done) is a **correct** non-blocking
TLS handshake state machine already. Don't touch that part except to add
the ALPN protocol list. The proxy `CONNECT` tunneling this task's own
verification script did by hand is NOT needed here — `clients.https.request`
doesn't currently proxy at all (a separate, already-logged gap, out of
scope for this task) and the standalone script only added it because it
had to build the tunnel itself outside the zenka. Don't add proxy support
as part of this task either; test directly against a plain reachable HTTPS
target, or gate live verification behind whatever this host's proxy setup
requires manually.

---

### where to implement

modify:

| file | change |
|---|---|
| `src/clients.https.request` | add `SSL_alpn_protocols => ['h2','http/1.1']` to the `start_SSL` call; after handshake, branch on `alpn_selected` |
| `src/clients.https.handler.handshake` | on handshake completion, check `$sock->alpn_selected()` — if `h2`, hand off to the new h2 request-building step instead of the existing plain-text request-write + `clients.https.handler.io` switch; if not `h2` (or undef), fall through to the EXISTING code path completely unchanged |

new modules (suggested names, adjust if a clearer name fits this codebase's
conventions better once you're in there):

| file | role |
|---|---|
| `src/clients.https.h2.send_request` | builds the `Protocol::HTTP2::Client` request from `$state`'s method/path/headers/body, drains `next_frame` for the initial write, registers the read watcher |
| `src/clients.https.h2.handler.io` | non-blocking read watcher : `feed()`s bytes to the h2 client, drains any resulting `next_frame` writes (flow control, SETTINGS ack), returns once `on_done`/`on_error` has fired |

**response contract must stay identical to the existing path** — same
`on_done->({ok, status, body, params})` / `on_done->({ok=>FALSE, error,
params})` shape `clients.https.handler.io`/`clients.https.handler.timeout`
already produce, so no caller-side code needs to know or care which HTTP
version was actually used. `body` should be the decompressed content
(gzip/deflate/zstd via `IO::Uncompress::AnyUncompress`, matching point 4
above) — do this for the h2 path; extending the existing h1 path
(`clients.http.parse_response`) to also decompress is a nice-to-have if
it's a small, low-risk addition, but not required for this task — call it
out explicitly in your summary either way, don't do it silently.

---

### design notes — decisions already made, don't re-open

- **Don't hardcode the Firefox UA / browser header set as a library
  default.** `clients.https.request` is a generic transport used by more
  than one caller (`proxy`, at least). Presenting a fake browser identity
  is a policy decision for whoever calls it against a bot-sensitive target,
  not something the transport layer should silently inject for everyone.
  Keep `headers` exactly as caller-supplied, same as today.
- **ALPN offering `h2` should be unconditional, not opt-in.** It costs
  nothing for a target that only supports `http/1.1` (server just won't
  select it, existing path runs exactly as before) and is required for the
  bot-mitigation case. Don't add an `alpn` param to gate this on/off unless
  you find a concrete reason to during implementation.
- **`SSL_verify_mode`** stays exactly as the caller already configures it
  (`$p->{'ssl_verify'}`, default `TRUE`) — this task's own verification
  script used `SSL_VERIFY_NONE` for convenience only; don't carry that into
  the real implementation.

---

### pitfalls

- **`Protocol::HTTP2::Client` is a pure codec, not a transport** — it never
  touches a socket itself (`next_frame`/`feed` interface only). All actual
  I/O must go through this codebase's own `event.add_io`/non-blocking
  `sysread`/`syswrite` primitives, same as the existing h1 path. Don't pull
  in `AnyEvent`/`AnyEvent::Handle` even though `Protocol::HTTP2::Client`'s
  own POD synopsis uses them — this project has its own event loop.
- **`next_frame` can produce more than one frame per call site** — drain it
  in a `while` loop (`while (my $frame = $client->next_frame) { syswrite
  ... }`), both after the initial `request()` call and after every `feed()`
  — a single `feed()` can trigger settings acks or window updates that need
  writing back immediately. Verification script's while-loop shape is a
  correct reference for this.
- **stream reset vs success** — see verified finding #3 above. Get this
  wrong and every rejected request looks like a successful empty response
  instead of a clear error.
- **`$sock->blocking(1)` in the verification script was fine for a
  synchronous one-shot test; the real implementation must stay fully
  non-blocking** (`$sock->blocking(0)`, `EAGAIN`/`EWOULDBLOCK` handled like
  `clients.https.handler.io` already does for the h1 read path) — don't
  copy the blocking-mode convenience from the throwaway test.

---

### verify

```bash
bin/dev/ptd -c src/clients.https.request src/clients.https.handler.handshake \
    src/clients.https.h2.send_request src/clients.https.h2.handler.io
grep -n "AnyEvent" src/clients.https.h2.*        ## must be empty ##
grep -n "blocking(1)" src/clients.https.h2.*     ## must be empty ##
```

### test plan

no live zenka needed to exercise this in isolation — `clients.https.get`
can be called directly via any zenka with `clients.https` loaded and
devmod's `eval-code`, or write a small standalone harness mirroring this
task's own verification script (same proxy `CONNECT` + target) but calling
through the real `clients.https.request`/`.get` code path instead of
hand-rolling the socket work, to confirm the real implementation gets the
same `200`/125KB-ish real content this task's own manual test already
proved is reachable.

```perl
## from any zenka with clients.https loaded, via devmod eval-code :
<[clients.https.get]>->({
    url        => 'https://www.stepstone.de/jobs/devops-engineer/in-Offenburg',
    headers    => { ## the exact set from verified finding #2 ## },
    timeout    => 20,
    on_done    => 'some.reply.handler',
});
```

expected: `on_done` fires with `ok=>TRUE, status=>200`, and `body` is
real, readable HTML (already decompressed), not binary garbage and not an
empty/undef response from a silently-mishandled stream reset.

---

## signatures_note

module files end with a 4-line `#,,,` AMOS7 data signature block. do not
hand-write or copy those blocks for new/changed files — leave signing to
`bin/Protocol-7 sourcecode update-signatures`. register the 2 new modules
in whichever `subroutines.load-early` file(s) load the `clients.https`
family (check `cfg/zenki/*/subroutines.load-early` for existing
`clients.https.*` entries and mirror that placement).

---

### dispatch

model: k3-256k

prompt: |
  implement the task at data/tasks/clients-https-http2-support.md

  the "verified findings" section is real, live-confirmed data from a
  standalone test script run today against the actual target through the
  actual proxy -- not a guess. treat the exact ALPN list, exact header set,
  and the on_done/on_error distinction in Protocol::HTTP2::Client as settled
  facts, not starting points to re-derive.

  read src/clients.https.request, src/clients.https.handler.handshake,
  src/clients.https.handler.io, src/clients.https.cleanup, and
  src/clients.https.handler.timeout first -- the existing http/1.1 path is
  correct and must keep working byte-identically for any target that
  doesn't negotiate h2. you are branching it, not replacing it.

  read the "design notes" section before making any decision it already
  covers -- those are settled, not open questions.

  read the "pitfalls" section before writing the h2 io handler -- the
  next_frame-drain-in-a-loop requirement and the stream-reset-vs-success
  distinction are both easy to get subtly wrong in a way that looks like it
  works until you hit a rejected request.

  use $ARG not @_ where the file already does; lowercase comments; bracket
  annotations [ like this ]; do not touch the trailing signature blocks.

#,,..,...,.,.,...,...,.,.,,,.,,,,,.,.,...,,.,,..,,...,.,.,.,,,,.,,,,,,,..,...,
#RSVPDPEU32WP4VDAOTYOCQOJHWNIEFYBWRG2AZQUVADKFZNCL7JOO2RQVA3EH5VKND2BEXAI6B6AM
#\\\|R4OQTGLI4WWXWXQVAIB4BMDSVGNY4377UKQ6VJKTVVIGPEDIQWI \ / AMOS7 \ YOURUM ::
#\[7]OWXW4MAQCVA4CHWBAOQCNWPBBFSPAUXCJP7ZILB6X3R4FCMOISBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
