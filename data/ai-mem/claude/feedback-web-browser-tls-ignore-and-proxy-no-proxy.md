---
name: feedback-web-browser-tls-ignore-and-proxy-no-proxy
description: "web-browser zenka couldn't load local self-signed services (WebKit rejects by default, no override existed) and leaked http_proxy/https_proxy/ALL_PROXY env vars into WebKit's proxy resolver even with use_proxy=no; both fixed 2026-07-29 (commit 18e79492d), but proxy_setup runs before open_window assigns web_context so the NO_PROXY fix is currently a no-op"
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

**Known follow-up, not fixed**: `configuration/zenki/web-browser/start`
calls `[web-browser.proxy_setup]` at line 127, **before**
`[web-browser.open_window]` at line 128 — and `open_window` is what
assigns `<web-browser.gtk_obj.web_context>`. So on every normal boot,
`proxy_setup` runs while `web_context` is still undefined, and the fix
above (both branches) never actually executes — confirmed by a live
crash (`cannot call method 'set_network_proxy_settings' on an undefined
value` at `web-browser.proxy_setup:66`) the first time the `else`
branch's code path got hit at all, since previously (before this fix)
that branch was dead code when `use_proxy='no'`. Patched with an early
`return <web-browser.init_proxy> if not defined $context;` guard to
stop the crash, but this means **the NO_PROXY fix is currently inert on
every boot** — the actual load-succeeding run that day was made possible
by the TLS fix alone, not the proxy fix. Real fix needed: move the
`proxy_setup` call to after `open_window` in the start file (or have
`open_window` call it itself right after assigning `web_context`).

**How to apply:** if a local/self-signed HTTPS service needs to be
reached via the web-browser zenka, flip `ignore_tls_errors` to `yes`
temporarily. Don't assume `use_proxy='no'` alone protects against a
proxy-poisoned shell environment reaching WebKit — until the call-order
issue above is fixed, an inherited `https_proxy` env var can still leak
through to the zenka's network requests regardless of this zenka's own
config.

#,,,,,,,.,...,,..,.,,,,,,,,,.,,.,,,,.,,..,.,.,..,,...,..,,.,,,.,,,,..,,.,,,,,,
#DI4LVWOHSBTQXXRJHXIC45ENKIAYQ7KF5BZZS3SXQR7N2O7WAJJA46IVQ3CVMJ6IJQMU6PGIAGWG2
#\\\|TL7ZQ5CXQB6IGJKMNGJGIR7STYRFDB2ERKZ6PFBNPVVKA2KSWQE \ / AMOS7 \ YOURUM ::
#\[7]NSJ363BJFWP6DJG7GKHMCIKZFS4AOHHFTHVF4SUZKUXMZ3SN6WAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
