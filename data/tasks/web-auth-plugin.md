## task: generic web authentication plugin — plugin.web.auth.*

### vision

a generic auth plugin namespace `plugin.web.auth.*` that:
- lives in the web zenka as a plugin (loaded optionally via start file)
- can also be loaded in standalone httpd zenki (same modules, same API)
- gates HTTP routes behind session/token validation
- is the prerequisite for: browser state changes having global effect,
  multi-site sync security, and distributed session sync

---

### design constraints

#### dual-loadability (web + httpd)

modules in `plugin.web.auth.*` must work when loaded in either:
- the **web zenka** (primary use; full plugin stack)
- a **standalone httpd zenka** (future use; same modules, different context)

the start file opt-in pattern:
```
## in configuration/zenki/web/start:
modules.load = ... plugin.web.auth

## in configuration/zenki/httpd/start (future, opt-in):
modules.load = ... plugin.web.auth
```

the auth plugin detects its context via zenka name:
```perl
my $zenka = <system.zenka.name>;    ## 'web' or 'httpd' or other
```

both zenki must whitelist the auth modules. auth config lives at
`configuration/zenki/web/auth.*` (shared by reference or symlink for httpd).

#### route-level gating

auth is applied PER ROUTE. each vhost route definition can declare
`auth.required = 1` or `auth.public = 1`. the web relay checks this
before forwarding to the target zenka:

```perl
## in httpd.route.handler.web-relay or a new auth middleware ##
if ( $route->{'auth.required'} ) {
    my $session = <[plugin.web.auth.verify_session]>->($request);
    return <[httpd.reply.unauthorized]> unless defined $session;
    $request->{'session'} = $session;
}
```

---

### module structure

```
plugin.web.auth.init_code          — load config, initialize session store
plugin.web.auth.verify_session     — validate session token from cookie/header
plugin.web.auth.create_session     — issue new session after login
plugin.web.auth.destroy_session    — logout / invalidate
plugin.web.auth.session.read       — read session data by token
plugin.web.auth.session.write      — update session data
plugin.web.auth.session.prune      — remove expired sessions
plugin.web.auth.handler.login      — POST /auth/login route handler
plugin.web.auth.handler.logout     — POST /auth/logout route handler
plugin.web.auth.handler.status     — GET /auth/status (session check)
```

---

### session storage

sessions are stored as files (same philosophy as checksum store):

```
/var/protocol-7/web/sessions/
  active/<token_hash>/
    session.yaml          — created_at, last_seen, user_id, node_id, data
  expired/<epoch_v7>/
    <token_hash>.yaml     — moved here on expiry, pruned after N epochs
```

token is a C25519-signed nonce or AMOS checksum of (node_id + ntime + secret).
`token_hash` is BMW-L13 of the token (never store raw token on disk).

session.yaml content:
```yaml
---
token_hash: AAQLHLE4XOG4Q
user_id: taeki
node_id: V7L36RY-local
created_at: 3TBNBF6YLGCNKCQ
last_seen: 3TBNBF6YLGCNKCQ
expires_at: 3TBNBF6YLGCNKCQ
data: {}
```

session lookup: cookie `p7_session=<token>` → compute BMW-L13 hash →
check `-e "sessions/active/<hash>/session.yaml"`.

---

### cross-node session sync

sessions use `file.zenka_dir.write` → stored in `/var/protocol-7/web/`.
cross-node sync: the same sync mechanism used for job records applies to
sessions — push `sessions/active/` to remote web nodes. merge: newest
`last_seen` wins (a session active on node A is valid on node B after sync).

session revocation: delete from `sessions/active/` → move to
`sessions/expired/<epoch>/`. revocation propagates via sync (remote node
finds session in expired dir, treats as invalid).

---

### auth methods (phase 1: simple token)

for the jobsite use case, a pre-shared token per browser client is sufficient:

- admin generates tokens via `p7c plugin.web.auth.create_session`
- token stored in browser localStorage (or as a cookie)
- sent as `Authorization: Bearer <token>` header or `p7_session` cookie
- no password UI needed for phase 1

phase 2: TOTP or keypair auth via `crypt.C25519.*`.

---

### jobsite-specific gating

the `/jobs-sync` endpoint currently has no auth. after this plugin:
- GET `/jobs.json` — public (read-only, no PII)
- POST `/jobs-sync` (reverse changes) — requires valid session

this prevents unauthorized writes from external actors while keeping
the read API open for dashboard viewing without login.

---

### priority

**medium priority** — required before:
- browser state sync has global/multi-node effect
- multi-site jobsite reverse fan-out

implement in this order:
1. `plugin.web.auth.verify_session` + session file store — DONE, all 11
   `plugin.web.auth.*` modules exist and session storage is wired
   (commits `f5dd2648f`, `f91bbbd80`)
2. gate `/jobs-sync` POST behind session check — DONE 2026-07-17
   (`configuration/zenki/httpd/routes`: added `auth.required=1` to the
   `/jobs-sync` route; found ungated via independent re-verification —
   the write endpoint was live and public despite this requirement)
3. session create/destroy + token distribution — DONE,
   `plugin.web.auth.create_session`/`destroy_session` both exist
4. cross-node session sync — STILL OPEN, no matching module found
   anywhere in the tree

## status

Items 1-3 complete as of 2026-07-17 (the security-relevant gating,
specifically). Item 4 (cross-node session sync) remains unimplemented —
this is what keeps the task open, not the auth-gating gap that was just
closed.

## dispatch

#,,,.,.,.,.,,,,..,...,..,,,..,.,,,.,,,,.,,,.,,..,,...,...,,,,,,..,,,,,.,,,,.,,
#OHGT7EZW75PGJPSLK3BMI6L4R7WE4Y6MZVSRL6323I2HYPXZJ6S4XIPDHBEEXIUMDOKSOVZYK7W3S
#\\\|ZNZCUUKXPYD72OWP7G4BB54NCHJCUQE6WL3BQ52MR7CBJQZCGHI \ / AMOS7 \ YOURUM ::
#\[7]B7337WP2V7PMQSCDECCKAIK6ATSW5OEI5NMELSTA2A5RQJXTMUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
