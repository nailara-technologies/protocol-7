---
name: site-yaml-async-fetch-fork-memory-risk
description: site-yaml's async HTTP fetch forks a worker per request — real OOM risk on 1GB-RAM hosts like atom. current recommendation: extend clients.https.request (already has correct non-blocking TLS) with proxy CONNECT support, no fork/exec needed; chmod_child-exec is the fallback if that hits an obstacle
metadata:
  type: project
---

`site-yaml.async_fetch.spawn` (landed via `data/tasks/site-yaml-async-fetch.md`
+ `data/tasks/site-yaml-async-import.md`, mirroring `povray.spawn_render`)
forks a one-shot `<[base.fork]>` worker per HTTP fetch — one job-detail fetch
from `fetch_tick`, one search-page fetch from `cmd.import`. this stopped the
`heartbeat.timeout` kills (the original problem), but the user flagged a
follow-on concern: this forks an already memory-loaded zenka process
(LWP::UserAgent, Event, JSON, YAML::XS, HTML::Entities all resident) for
*every single request*.

**why this is a real risk, not just theoretical:** Perl's fork+copy-on-write
is much less cheap than a typical C program's — refcounting touches nearly
every SV (scalar value) as code executes, so even a child that only does one
`$ua->get($url)` call ends up COW-copying a meaningfully large fraction of
the parent's resident pages, not just the pages it "logically" needs. on a
host with ample RAM this is invisible; on a memory-constrained host it is not.

**the specific constraint:** the user runs a host ("atom", reachable via
`ssh -p 2242 atom.v7.ax` per shell history) with only 1GB RAM, and has
direct prior experience of memory-pressure crashes there — "these are the
things that make it crash." site-yaml's fork-per-request design is exactly
that class of thing at scale (many job-detail + search-page fetches during
an import cycle).

**why fork was chosen anyway, this round:** it let the worker reuse the
*already-configured* `LWP::UserAgent` (proxy env, headers, gzip/charset
decoding) with zero reimplementation — the fastest safe path to stop the
active heartbeat-kill problem. rebuilding equivalent behavior on raw
non-blocking sockets is real, separate work.

**SUPERSEDED — `coding.async.http_client` is the wrong client to extend.**
Initially considered migrating to `coding.async.http_client` /
`coding.handler.http_io` (non-blocking sockets via `event.add_io`, same
pattern used for streaming LLM inference calls). Read the actual code:
it's `http://`-only (URL regex literally can't match `https://`), no
`IO::Socket::SSL` anywhere, no proxy awareness, and its request builder is
hardcoded `POST` + JSON body (built for talking to a local trusted
inference server, not scraping arbitrary public HTTPS sites). Extending it
would mean implementing non-blocking TLS handshake pumping *and* a SOCKS5/
CONNECT proxy handshake from scratch — genuinely substantial,
security-sensitive new engineering. Correctly assessed as not worth it —
but the conclusion "so a non-fork rewrite isn't the clean path" was wrong,
because a *different*, better-fitting client already exists (next section).

---

**CURRENT RECOMMENDATION (2026-08-30) — extend `clients.https.request`
instead, no fork or exec needed at all.**

`src/clients.http.*` / `src/clients.https.*` is a separate, already-built,
genuinely general-purpose non-blocking HTTP(S) client family (used
elsewhere — e.g. `proxy`; cred-mesh deliberately does NOT load it, per
[[topic-credential-fabric-proxy-transport]]'s F13 note). Critically, it
already solves the hard part correctly:

```perl
## clients.https.request : deferred handshake, connect_SSL() pumped from
## an event.add_io watcher (poll => 'rw') until it stops needing more I/O
IO::Socket::SSL->start_SSL( $tcp_sock, SSL_startHandshake => 0, ... );
## clients.https.handler.handshake, called on every watcher fire:
my $result = $sock->connect_SSL();
return if $ssl_err == SSL_WANT_READ() or $ssl_err == SSL_WANT_WRITE();
```

That's a correct non-blocking TLS handshake state machine — already
written, not something this follow-up needs to build. It also supports
arbitrary method/headers/body, `ssl_verify`, timeouts, and a generic
`on_done`/`params` callback contract. `clients.http.parse_response` exposes
status code + headers to the caller, so redirect-following (3xx + `Location`
header → one more `clients.https.get` call) can live in site-yaml's own
fetch logic without needing to be built into the client.

**what's actually still missing, and it's bounded:** proxy support.
`clients.https.request` connects `IO::Socket::IP->new(PeerHost => $host,
...)` straight to the origin — no `CONNECT` tunneling, no SOCKS5. The fix
is one inserted step, not a rewrite: when a proxy is configured, connect to
the *proxy* host:port instead of the origin, write `CONNECT
<host>:<port> HTTP/1.1\r\nHost: <host>:<port>\r\n\r\n` non-blocking, read
until a `200` status line, THEN hand that already-connected socket into the
existing `start_SSL`/handshake-pump path completely unchanged. Same
`event.add_io` pattern already used throughout this file family — bounded,
well-scoped, not security-novel the way hand-rolled TLS would have been.
SOCKS5 (`ALL_PROXY=socks5://...`) is a separate small binary handshake if
ever needed instead of/alongside HTTP CONNECT, but typically `https_proxy`
being an `http://` URL means CONNECT-tunneling is the relevant path.

**net effect if this lands:** site-yaml's async fetch primitive calls
`clients.https.get` (with proxy support added) directly — zero forking,
zero exec'ing, true single-process non-blocking I/O. This supersedes BOTH
the fork-per-request design that landed AND the chmod_child-exec
middle-ground below — those remain useful history/fallback if extending
`clients.https.request` turns out to hit an unexpected obstacle, but this
is now the target to scope first.

**lighter middle-ground option, if fork is wanted and the non-blocking-socket
rewrite is rejected:** user pointed at the existing `chmod_child` pattern
(`coding.start.chmod_child` + `coding.chmod_child.readline`, also
`ncode.start.chmod_child`) as the precedent — it does NOT `<[base.fork]>`
the zenka itself. it uses `IPC::Open2::open2($r_fh, $w_fh, $perl_bin, '-e',
$child_code)`, which is fork+**exec**: `exec` replaces the child's process
image entirely, so none of the COW-inherited zenka pages (the whole `%code`/
`%data` tree, LWP, Event, YAML::XS, JSON, HTML::Entities) survive into the
child — it starts as a fresh, minimal perl process loading only what the
small inline `$child_code` string needs. `chmod_child` also stays alive
persistently and is reused across many requests via a line-based stdin/
stdout protocol (one command line in, one reply line out), rather than
paying fork+exec cost per request.

applying this to site-yaml's fetch worker would mean: spawn ONE persistent
minimal `perl -e '...'` HTTP-fetch child (its own small `use LWP::UserAgent`
inside the exec'd string, not the parent's already-loaded `$ua`), keep it
alive, and reuse the exact wire protocol already designed for the one-shot
worker (`"GET <url>\n"` in, `"OK<len>\n<content>"` / `"ERR <code>\n"` out) —
`async_fetch.spawn`/`finalize`'s framing already fits this. **the one thing
that must NOT be copied from `chmod_child` as-is**: `coding.chmod_child.
readline` does a *blocking* `alarm(2)`-guarded `readline()` — fine for
near-instant chmod ops, wrong for HTTP fetches that can legitimately take up
to 30s. the parent side would still need `event.add_io` non-blocking reads
on the persistent child's stdout pipe (site-yaml's existing `handler.
fetch_io` shape), not a blocking readline. total footprint under this
option: the zenka's own RSS (untouched, never forked) + one persistent
lightweight LWP+SSL child paid once, instead of COW-copying the entire
zenka's state on every single fetch.

**further refinement — drop LWP from the parent entirely, not just per
request:** if the exec'd-worker design above lands, the parent zenka never
performs an HTTP request itself, so it no longer needs `LWP::UserAgent`/
`HTTP::Request` (or their transitive stack — `HTTP::Message`, `Net::HTTP`,
`IO::Socket::SSL`/`Net::SSLeay` for HTTPS) loaded in its own process at
all — not a transient per-request COW saving, a *permanent* baseline RSS
reduction for the zenka's whole lifetime. `site-yaml.init_code`'s module
autoload + `$data{'site-yaml'}{'ua'}` construction (headers, `env_proxy`,
`bypass_proxy`/`no_proxy`) would move out of the parent and into the
exec'd child's inline script instead (built as a heredoc string per spawn,
same technique `chmod_child` uses for `$admin_gid`/`$admin_uid`), and
`site-yaml.http.get` itself would stop existing in the parent.

**the one dependency this creates:** `site-yaml.stepstone.job` /
`.stepstone.search` (the synchronous fetch+extract wrappers still used by
`cmd.fetch`, deliberately left out of scope in both fork-per-request
dispatches) call the parent's own `$data{'site-yaml'}{'ua'}->get()`
directly — that's the one remaining caller that breaks if the parent's UA
is removed outright. dropping LWP from the parent only fully closes once
`cmd.fetch` is also routed through the worker (or is deliberately accepted
as staying a rare synchronous exception with its own small UA kept just
for that one path).

**how to apply:** before adding any more fork-per-request call sites to
site-yaml (or any other memory-constrained/on-demand zenka), check whether
the `clients.https.request` proxy-CONNECT extension has landed yet. if not,
treat the current fork-per-request worker as a known, deliberate stopgap —
correct for correctness, not yet correct for footprint on low-RAM hosts
like atom. when scoping the follow-up dispatch, point it at
`clients.https.request`/`clients.https.handler.handshake` as the precedent
to extend, not at `coding.async.http_client` (wrong client, see SUPERSEDED
note above) and not at a fresh chmod_child-exec build (fallback only).

see [[topic-site-yaml-zenka]] for the broader site-yaml design context.

#,,,,,.,.,.,,,,,.,.,,,,,.,...,...,.,.,.,,,,,,,.,.,...,...,.,,,.,,,..,,,.,,,..,
#EI5A2I2V35QISBTCTUMHUNIW37JLN35CP4BGAYI26AFC3AED64HVIOK334L6MPJAZDP56ZWHADBKG
#\\\|F3X5HK5ELN4FXMLDJTXAL2VKOTB7VJGE52TEHGPDOVPKY4OLSKW \ / AMOS7 \ YOURUM ::
#\[7]KRWLLDC6QO3AQ36IZPSNIQL6KTGH65FBHUGQ2IKRPFBX6TRWZWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
