---
name: feedback-web-browser-tls-ignore-and-proxy-no-proxy
description: "web-browser zenka couldn't load local self-signed services (WebKit rejects by default, no override existed) and leaked http_proxy/https_proxy/ALL_PROXY env vars into WebKit's proxy resolver even with use_proxy=no; both fixed 2026-07-29 -- the proxy fix initially landed inert (proxy_setup ran before open_window assigned web_context) but was corrected same day by moving the call inside open_window"
metadata:
  type: feedback
---

Found live 2026-07-29 getting a Nessus trial instance running for
nessus-agent verification (`https://localhost:8834/`, self-signed cert
before activation).

**Bug 1 — TLS rejection, no override existed.** WebKit rejects
self-signed/invalid certs by default; `web-browser.load_uri` just
reported `[ unacceptable tls certificate ]` with nothing to bypass it.
Fixed: `web-browser.cfg.ignore_tls_errors` (default `no`, opt-in) calls
`$web_context->set_tls_errors_policy('WEBKIT_TLS_ERRORS_POLICY_IGNORE')`
in `web-browser.open_window`. **This is a global toggle** — while `yes`,
TLS validation is off for every site the browser visits, not scoped to
one host. Flip back to `no` once done with the local self-signed
service.

**Bug 2 — proxy env-var leak, use_proxy='no' didn't mean no proxy.**
`web-browser.proxy_setup` only ever called
`set_network_proxy_settings(...CUSTOM...)` when a proxy was actively
configured; when `use_proxy='no'` it just logged and returned, leaving
WebKit at its *implicit* default — which falls back to glib's proxy
resolver and reads `http_proxy`/`https_proxy`/`ALL_PROXY` straight from
the process environment, regardless of the zenka's own config. Confirmed
live: the zenka process had `https_proxy=http://<host>:4040` /
`ALL_PROXY=socks5://<host>:1040` inherited from wherever v7 was started,
and every `load_uri` to `localhost` was silently tunneled through that
proxy and failing. Fix: explicitly set
`WEBKIT_NETWORK_PROXY_MODE_NO_PROXY` in the `else` branch instead of
leaving WebKit at its default.

**RESOLVED same day**: `cfg/zenki/web-browser/zenka.v7` originally
called `[web-browser.proxy_setup]` at line 127, **before**
`[web-browser.open_window]` at line 128 — and `open_window` is what
assigns `<web-browser.gtk_obj.web_context>`. So on every normal boot,
`proxy_setup` ran while `web_context` was still undefined, and the fix
above (both branches) never actually executed — confirmed by a live
crash (`cannot call method 'set_network_proxy_settings' on an undefined
value` at `web-browser.proxy_setup:66`) the first time the `else`
branch's code path got hit at all, since previously (before this fix)
that branch was dead code when `use_proxy='no'`. A defensive
`return <web-browser.init_proxy> if not defined $context;` guard was
added first to stop the crash, but that alone left **the NO_PROXY fix
inert on every boot** — the actual load-succeeding run that day was made
possible by the TLS fix alone, not the proxy fix.

Real fix landed: removed the standalone `[web-browser.proxy_setup]`
start-file step entirely and call `<[web-browser.proxy_setup]>;` from
inside `web-browser.open_window`, right after
`<web-browser.gtk_obj.web_context> = $web_context;` and before the
`foreach my $view` init-view loop (which is what starts making real
network requests). Gotcha hit while landing this: a bare `<[X]>` macro
call immediately followed by a comment line then a `foreach` statement
needs an explicit trailing `;` — without it, `ptd -c` failed with a
`syntax error, near '$view ('` on the *following* statement, not the
macro line itself.

**How to apply:** if a local/self-signed HTTPS service needs to be
reached via the web-browser zenka, flip `ignore_tls_errors` to `yes`
temporarily and flip it back to `no` once done (it's a global toggle,
not scoped to one host). The proxy call-order issue is now fixed, so
`use_proxy='no'` reliably means no proxy on every boot, not just when
timing happens to work out.

#,,.,,,,.,...,,..,,.,,.,,,,,,,,.,,,.,,...,,.,,..,,...,...,,,,,,.,,...,,.,,,,.,
#6X6Y4XCHDHSCYUN5X5WBCTCOWXVTQ5O2BBDTDOJXTMDIB4OGQJFIJGIRGNO2ZUMZ5TG76H4AMWZSM
#\\\|W4MQKCBUJDGGCJN4GIDIL6JIAXH6AXM3XVFGXLY3DCU7COYBQLX \ / AMOS7 \ YOURUM ::
#\[7]H6A3KMRPMPG6SQJCG5KWF5ZXWWIGHCCLFVFZR2RJX7RRDNO5UUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
