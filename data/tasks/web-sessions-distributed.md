## task: distributed web sessions — synchronizable across nodes

### context

this task depends on `web-auth-plugin.md` (session storage design) and
expands it with distributed sync semantics. a session created on node A
should be valid on node B after sync, without requiring a central auth
server.

---

### core principle: sessions as signed data objects

a session is a signed YAML file — its validity is self-contained:
- created and signed by the issuing node (C25519 or AMOS checksum)
- any node can verify the signature without contacting the issuer
- expiry is encoded in the session itself (not checked against a server)

this makes sessions inherently portable and offline-verifiable.

---

### session token format

```
<node_id>.<ntime_b32>.<AMOS_chksum_of(node_id+ntime+secret)>
```

example: `V7L36RY.3TBNBF6YLGCNKCQ.CLREWMQXYZABC`

verification: extract node_id + ntime, recompute expected checksum using
shared secret, compare. no database lookup required.

the `shared secret` can be a per-deployment key stored at
`/etc/protocol-7/web/session.key` (readable only by web/httpd zenka users).
cross-node: all nodes share the same key (deployed via admin, not synced).

---

### session sync mechanism

sessions piggyback on the existing job sync infrastructure:

1. web zenka A pushes job updates to web zenka B
2. in the same push batch, include session deltas:
   ```perl
   ## in jobsite.sync.push or a new plugin.web.sessions.sync ##
   my @session_updates = <[plugin.web.auth.session.changed_since]>->($since_ntime);
   ```
3. receiving node merges sessions (newest `last_seen` wins)

session revocations sync via the `expired/<epoch>/` dir — same as job
deleted dir mechanics.

#### what does NOT sync

- session `data` field (user preferences, UI state) — local only by default,
  opt-in to sync by flagging specific keys as `sync: true`
- raw tokens — only `token_hash` (BMW-L13) is stored/synced, never the
  original token

---

### multi-node session validity window

sessions have a `valid_nodes` list (optional):
```yaml
valid_nodes: ['V7L36RY-local', 'V7L36RY-pri']   ## empty = any node
```

if `valid_nodes` is empty, session is valid on all nodes that share the
session key. this is the default for the jobsite use case.

---

### browser session portability

when a user logs in on one machine, they can take the session token to
another machine:
1. copy token from browser localStorage
2. paste into new browser's localStorage
3. token is valid on any node that has synced since the session was created

this is sufficient for the jobsite use case (single user, multiple machines).

---

### session escalation (future)

for multi-user scenarios, sessions can have privilege levels:
- `level: 0` — read-only (default for unauthenticated)
- `level: 1` — can push reverse changes (write jobsite stage/notes)
- `level: 2` — can trigger re-assessment, blacklist companies
- `level: 9` — admin (create/revoke sessions, access all routes)

the auth plugin checks `$session->{'level'} >= $required_level` per route.
level 0 is implicit (no session required for public routes).

---

### relationship to P7 auth system

P7 already has `auth.*` modules for zenka-to-zenka authentication (C25519
keypairs). web sessions are a parallel system for HTTP clients (browsers,
curl). they share the same cryptographic primitives but different identity
models:
- zenka auth: identity = public key (long-term)
- web session: identity = signed time-limited token (short-term)

a future bridge: a zenka can mint web session tokens for trusted callers,
allowing automation scripts to access the HTTP API using their zenka identity.

---

### implementation sequence

1. `web-auth-plugin.md` phase 1 (file-based sessions, pre-shared token)
2. add session sync to job sync push (sessions/active/ delta)
3. session revocation sync via expired/ dir
4. privilege levels on routes
5. C25519-signed tokens (replaces AMOS checksum for stronger guarantees)

---

### priority

**lower priority than web-auth-plugin** — the session sync aspect is not
needed until there are multiple web nodes. implement auth first with
node-local sessions, add sync later when deploying to pri.v7.ax.

## dispatch

#,,,.,.,.,,.,,..,,,,.,,,,,,,.,.,,,,..,,,.,..,,..,,...,..,,...,,,,,,..,..,,,,.,
#BFW7ZKRZX3IX44VZSXJIPWAESOV5SMOHN4WDQWWFYU5RI3WG6HWU2HXTE7R5WOBOR6OFSDG5H5ABQ
#\\\|YKSH7WRLHK3G7WZYKXW6BOBYM2EVOPJIHME5OVEP6IYU2VLSVAE \ / AMOS7 \ YOURUM ::
#\[7]QESWLE4GHZK5ZMJR7VUP7LDDIOKRRECKECXHTPWTOMENZIWIY2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
