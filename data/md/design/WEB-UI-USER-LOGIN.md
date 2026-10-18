# web ui user login : credentials in front of create_session [ draft ]

design only -- no code in this step. the build plan is
`data/tasks/web-ui-user-login.md`, which also carries the open questions
for the owner. builds on the web auth layer of commit 32853e14c [ gated
`/jobs*` routes, `web.auth-issue`, `p7_session` cookie ].

## what exists [ read from the source, 32853e14c ]

- **gate** `httpd.route.handler.web-relay` : routes with `auth.required`
  call `plugin.web.auth.verify_session` on the httpd session [ bearer
  header first, then the `p7_session` cookie ] ; `auth.exempt-loopback`
  spares the REAL socket peer 127.0.0.1 \ ::1 \ `::ffff:` mapped, plus
  `web.auth.exempt_peers` from host config. the verified session lands in
  `$session->{'auth_session'}` and nothing reads it yet : **every valid
  token has full access to all six `/jobs*` routes** [ read and write ].
- **session store** `plugin.web.auth.session.*` :
  `<var_P7>/web/sessions/active/<token_hash>/session.yaml`, token_hash =
  `bmw.L13-str( token )`, the session carries `user_id`, `secret_hash`,
  epochs. `verify_session` refuses a session minted under another
  secret, destroys an expired one, and rewrites `last_seen` on every hit.
  `destroy_session` moves the file to `expired/<epoch>/`.
- **token** `plugin.web.auth.create_session` :
  `token = chk-sum.amos( "$node_id $ntime $user_id $secret" )` --
  deterministic, no random input.
- **login today** `plugin.web.auth.handler.login` : a synchronous httpd
  handler. it does NOT create a session -- it verifies a token minted
  earlier by `web.auth-issue` and, when valid, sets the cookie to that
  same token. the admin token IS the session.
- **minting** `web.cmd.auth-issue` : admin only [ cube \ root \ explicit
  grant ], prints the token once, per-token ttl. the jobsite push token
  [ `jobsite.sync.token_for_url`, `jobsite.cfg.sync_token[s]` ] is one
  such token, user `jobsite-push`, usually one year.
- **ui** `index.html` : `jobsFetch` turns any 401 into the token-paste
  overlay [ `#auth-overlay`, one shared prompt for concurrent 401s ],
  retries the request after a good login. the token never goes to local
  storage.
- **cube grant** `access.cmd.usr.httpd` has `web.*`, which technically
  includes `web.auth-issue` [ noted in `cfg/zenki/cube/access.zenki` ].
- **follow-up in progress** [ not in this clone ] : the session store
  moves to `/var/protocol-7/shared/web-auth` [ owner protocol-7, group
  httpd, 2770, files 0660 ] so the web, httpd and httpsd zenki [ three
  unix users ] share it. everything below is designed against that dir.

the goal keeps the store, the cookie and the gate. the only new piece is
a **credential check that ends in `create_session`**, plus rights at the
gate.

## 1. credential options

### [ a ] protocol-7 users with a password

**where users live.** the users zenka keeps one record per user at
`[USERS_HOST]/<user>/details.yaml` [ `users.record.path`, `USERS_HOST` =
`etc_P7/users/host-system`, dir 0770 ]. the record is an envelope [ name,
checksum, timestamp, `fields` ] with an open field set. the optional
`host_password` field is `masked` and is staged through `sessions.hold`,
**explicitly not permanent credential storage** [ the note in
`users.record.optional_fields` ]. `users.cmd.value-all` returns the whole
field set. a hash stored in the record would therefore leak through an
ordinary read path. **password hashes do not belong in the users
record.** the record can stay the identity [ the login name must exist
there -- see the owner questions ], and the hash lives in its own store.

**the existing password check is not reusable.** `auth.pwd.success`
[ cube user auth, `bin/mk.usr` ] compares
`chk-sum.bmw.B-32-56.TRUE( password, uname )` with `eq`. that is a fast
hash salted with the user name, compared in non-constant time. it is fine
for a local socket, but on a public login a leaked hash file falls to
offline guessing at hash speed. option [ a ] needs a real password KDF.

**what is available without new installs.** this is checked against the
zenki that would verify, not against a dev box :

| primitive | where | on httpd \ web hosts |
|---|---|---|
| `Crypt::KeyDerivation::pbkdf2` [ hmac-sha256 ] | CryptX | **yes** : `Crypt::Misc` + `Crypt::PRNG::Fortuna` are in `cfg/zenki/{httpd,web}/deps/p-mod`, both are CryptX |
| `Crypt::Misc::slow_eq` [ constant time ] | CryptX | **yes** -- already used by `keyring.verify` |
| `Crypt::PK::Ed25519` | CryptX | yes [ CryptX has carried it for years ; verify the version at init ] |
| argon2id | `Crypt::Argon2`, or CryptX >= 0.088 | **only with the `vault` profile** [ `.deps/profiles.yaml` : bookworm ships CryptX 0.077, no argon2 ] |
| yescrypt \ bcrypt via core `crypt()` | the host's libc libcrypt [ libxcrypt ] | depends on the host. it works on a libxcrypt system [ `$y$`, `$2b$` checked on a 5.38 dev box ], it is not guaranteed elsewhere, and perl only passes the string through |
| `Crypt::Ed25519` | `cryptography` profile | used by `crypt.C25519.*` ; not in the httpd \ web p-mod lists |

**recommended hash.** argon2id when the verifying zenka has it
[ `Crypt::Argon2` or CryptX >= 0.088 -- the same primitive `bin/p7-vault`
already relies on ], otherwise pbkdf2-hmac-sha256 at 600000 iterations
[ always present through CryptX ]. store a self-describing PHC-style
string [ `$argon2id$v=19$m=..,t=..,p=..$salt$hash` \
`$pbkdf2-sha256$i=600000$salt$hash` ], salt 16 bytes from
`base.prng.bytes`. on a successful login with an older scheme or cost,
rehash and rewrite. **never fall back to a fast hash** : init runs a
known-vector self-test of the chosen KDF ; on failure password login is
disabled [ fail closed, log level 0 ], token paste still works. core
`crypt()` yescrypt is not recommended as the default, since its
availability is the host's libc, not ours to check in deps.

**cost.** the web zenka is one event loop. pbkdf2-sha256 at 600000
iterations alone takes several hundred ms on typical hardware, well over
the budget below. the fallback scheme is the one most likely to force
the forked child [ owner question 4 ]. an argon2id hash at ~64 MiB
takes 0.1 .. 0.5 s, and those seconds block `jobs.json` for everyone.
stage 1 caps it [ one KDF at a time, a queue limit, 429 beyond ] with
cost tuned to ~150 ms. if that is not enough, move verification into a
forked child zenka [ the `weather.base.fork_weather_child` pattern ].
this is an owner question with a default.

### [ b ] the user's Ed25519 key, browser signs a server challenge

**the private key does not travel to the browser.** pasting the user's
`<user>.base` key [ or its encrypted form, `crypt.C25519.decrypt_priv_
keystr` ] into a page would put the master key in reach of any script on
that origin, and of every job ad the ui renders [ section 5 ]. the safe
shape is **delegation** :

1. **the browser generates its own key** :
   `crypto.subtle.generateKey( { name: 'Ed25519' }, false, ['sign',
   'verify'] )`. with `extractable = false` the private half cannot be
   exported, not even by a script on the page. the `CryptoKeyPair` is
   structured-cloneable and kept in IndexedDB [ origin-scoped ]. its
   public half [ 32 raw bytes ] is always exportable.
2. **the user enrolls it from their own machine.** the ui shows the
   browser public key as b32. on a machine holding `<user>.base`, a
   small tool [ `bin/p7-web-enroll-key <pub_b32> [ -days n ]` ] builds a
   standard **`p7 delegation v1`** statement with the existing
   `trust.statement` [ HOST-ROOT-DELEGATION.md ] :
   issuer = the user's base pub, subject = the browser pub, name =
   `<user>.web.<label>`, not_before \ not_after, scope `''` [ the browser
   key certifies nothing ]. it signs the statement with the user's key
   and prints the wire b32. the user pastes that into the browser, and
   the ui posts it to `/auth/enroll-key`.
3. **the server accepts the enrollment** when the statement parses
   exactly [ the acceptance order of HOST-ROOT-DELEGATION.md rule 2 ],
   the issuer pub is the key the server already trusts for that user
   [ `authorized-remote{<user>}`, the auth-keypair registration -- where
   the web side reads it from is an owner question ], and the scope is
   empty. it stores the subject pub plus the statement in the user's
   credential record. the master key stayed on the user's machine the
   whole time.
4. **enrollment needs a live session of the same user.** `/auth/enroll-key`
   is refused without a valid `p7_session` whose `user_id` equals the user
   in the statement name, and it gets the login routes' `Origin` and
   content-type checks. without this rule a look-alike page could show
   its OWN browser pub, have the user sign it with
   `bin/p7-web-enroll-key`, and post that statement to the real server.
   the first enrollment therefore follows a password or token login.
   `bin/p7-web-enroll-key` also prints a short fingerprint of the pub
   [ `trust.key_id`, first 13 chars ], and the ui shows the same
   fingerprint before the user runs it.

**login wire** [ mirrors auth-keypair v2 : server nonce, labelled
signature, single use ] :

```
-> POST /auth/challenge      { "user": "<user>" }
<- 200 { "nonce": "<b32 32 bytes>", "expires": <unix s> }   [ also for unknown users ]
-> POST /auth/login-key      { "user": "<user>", "pub": "<b32>", "nonce": "<b32>",
                               "ts": <unix s>, "sig": "<b32>" }
<- 200 + Set-Cookie p7_session   |   401 { "ok": false, "error": "invalid credentials" }
```

```
login_msg = pack( 'Z* a32 a32 n/a* n/a* N',
    'p7 web-login v1', nonce, browser_pub, username, origin, ts )
sig       = Ed25519_sign( browser_key, login_msg )
```

- `Z*` = label + one \0 ; `n/a*` = 16-bit big-endian length + bytes ;
  `N` = 32-bit big-endian. this is the same template language as
  AUTH-LINK-BINDING.md.
- the label is distinct from `p7 auth-keypair v2`, `p7 link-bind v1 *`
  and `p7 delegation v1` : no signature is valid as another kind.
- `origin` is what the server saw : the request's `Origin` header, which
  must equal `<scheme>://<Host header>` of the same request [ scheme from
  the real socket : TLS or not ]. it binds the signature to the origin
  that asked for it.
- the nonce comes from `base.prng.bytes(32)` and lives in the verifier
  zenka's memory, keyed by its b32, with a ttl of 60 s. it is **single
  use** : the first request that deletes the entry wins. it is deleted on
  every exit path [ success, failure, expiry ]. a replayed or late
  `login-key` finds no entry : 401.
- `ts` must be within ±120 s of server time. this is defence in depth,
  since the nonce alone already stops replay.
- unknown user or unknown pub : the server still answers the challenge
  with a real nonce, and `login-key` fails with the same 401 after the
  same verify work [ a verify against a dummy pub ].

**test vector** [ message bytes only -- the signature vector is made in
the stage that builds it, from a fixed-seed key, test only ] :

```
nonce       = 32 x \x55      browser_pub = 32 x \x66
username    = test-user      origin      = https://web-ui.example   [ EXAMPLE, rfc 2606 ]
ts          = 1700000000
login_msg hex : 7037207765622d6c6f67696e20763100
                5555555555555555555555555555555555555555555555555555555555555555
                6666666666666666666666666666666666666666666666666666666666666666
                0009746573742d75736572
                001668747470733a2f2f7765622d75692e6578616d706c65
                6553f100                                            [ 119 bytes ]
```

**js crypto needed : webcrypto only, no vendored lib.** Ed25519 in
`crypto.subtle` is native in Firefox 129 [ 2024-08 ], Safari 17 and
Chrome 137 [ 2025 ]. a vendored js lib [ tweetnacl style ] would hold
the private key as a js byte array, readable by any script on the page.
that is the exact property non-extractable webcrypto keys remove, so it
is rejected, not just less preferred. two caveats :

- **secure context only.** `crypto.subtle` is undefined on plain http to
  a non-loopback address [ the WSL \ LAN case in `cfg/zenki/httpd/
  routes` ]. the ui feature-detects and hides key login there, and
  password \ token login still work.
- raw-format import \ export of Ed25519 keys has had engine quirks
  [ Firefox \ Safari ]. the stage tests `exportKey('raw', publicKey)` in
  each target engine and falls back to `spki` [ 12-byte fixed prefix ]
  if needed.

### [ c ] both -- recommended

| | [ a ] password | [ b ] browser key |
|---|---|---|
| phishing | a password typed into a look-alike page is gone | **origin-bound** : another origin cannot reach the IndexedDB key, and the signed `origin` must match. this holds only with the enrollment rule [ b ] 4 : session of the same user + matching fingerprint |
| server-side leak | a hash file can be guessed offline [ cost-limited by the KDF ] | only public keys stored : nothing to guess |
| credential stuffing | needs rate limits | nothing to stuff |
| new device | instant | needs the user's own machine once [ enrollment ] |
| xss on the origin | the attacker can ride the session, and can capture a password typed while it runs | can ride the session and sign while it runs, but cannot export the key |
| deps | CryptX [ present ] | `Crypt::PK::Ed25519` [ CryptX ] or `Crypt::Ed25519` ; browser webcrypto |
| ui on plain-http LAN | works [ but see 3 : password over plain http is refused off loopback ] | not available |

**recommendation : [ c ], password first, key login second, plus a
per-user method policy.** password login reaches every user and device
on day one and needs no enrollment flow, so it lands first. key login
is the strong path : it is phishing-resistant and leaves no guessable
secret on the server. once it exists, users with write rights should be
able to drop the password [ `login.methods = key` in their credential
record ], so a phished password is worth nothing for them. token paste
stays for machine and admin use.

## 2. per-user rights at the gate

rights attach to the **relayed command** of a route [ its `command:`
arg ], not to the url. the gate already has it in `$args->{'command'}`,
and the command names are what the cube access files speak.

| route | command | class |
|---|---|---|
| `GET /jobs.json` | `web.jobs-data` | read |
| `GET /jobs-trash` | `jobsite.list-trashed` | read |
| `GET /jobs-prefs` | `jobsite.get-prefs` | read |
| `POST /jobs-sync` | `web.jobs-sync` | write [ the ui's stage moves, `index.html` ~1063 \ ~1387, AND the machine push ] |
| `POST /jobs-trash-rescue` | `jobsite.rescue-http` | write |
| `POST /jobs-import-url` | `jobsite.import-url-http` | write |
| `POST /jobs-prefs` | `jobsite.set-prefs` | write |

**config**, in the shape of `access.*` [ space-separated masks,
backslash continuation ]. a tracked file holds the roles and the machine
principals, which are code-level knowledge. host config maps real users
to roles, since user names are deployment data :

```
## cfg/zenki/httpd/access.web [ tracked ]
access.web.role.read   =  web.jobs-data jobsite.list-trashed jobsite.get-prefs
access.web.role.write  =  web.jobs-data jobsite.list-trashed jobsite.get-prefs \
                          web.jobs-sync jobsite.rescue-http \
                          jobsite.import-url-http jobsite.set-prefs
access.web.role.push   =  web.jobs-sync

access.web.usr.jobsite-push  =  :push      ## the machine push token ##
access.web.exempt            =  :write     ## loopback \ exempt_peers ##

## /etc/protocol-7/httpd/host.cfg [ per deployment, NOT tracked ]
web.auth.rights.<user> = read | write
```

- a `:role` reference expands to the role's mask. plain command names are
  allowed too, for one-off grants. no wildcards : a new route must be
  granted explicitly.
- **enforced in the gate** after `verify_session` :
  `plugin.web.auth.rights.allows( $user_id, $command )`. if it is false,
  the gate answers **403** [ not 401 : the identity is fine, the right is
  missing ] and logs at level 1. resolution happens per request from the
  loaded config, not from the session, so a rights change applies to live
  sessions without re-login.
- **exempt peers** have no session and no user. today they get full
  access, and `access.web.exempt` names their principal explicitly
  [ default `:write` = today's behaviour ]. an operator can lower it to
  `:read`.
- **no entry = no rights** : a valid session whose user has no rights
  line gets 403 on every `/jobs*` route. this matters for tokens minted
  with `web.auth-issue` for ad-hoc names : they need a rights line too.
  the migration in the task file creates it before enforcement is on.
- `/auth/status` returns the resolved class [ `read` \ `write` \ `push` ]
  so the ui can hide write controls. hiding is cosmetic : the gate
  decides.
- these masks are a separate namespace from `access.cmd.usr.*` [ the
  cube's ] and are read only by httpd \ httpsd. they never widen what the
  httpd cube user may relay.

## 3. abuse

**where the check runs.** the verification runs in **one verifier zenka**
[ recommended : `web`, which already carries `plugin.web.auth` ]. httpd
\ httpsd relay `/auth/login-password`, `/auth/challenge` and
`/auth/login-key` there with the deferred route-send pattern of
`web-relay`. the verifier calls `create_session` and returns the token.
httpd then sets the cookie, because the cookie flags need the real
socket. this gives :

- the hash store is owned by the verifier's unix user [ 0600, its own
  `etc_P7` dir ]. it is **not** in the shared `web-auth` dir and not
  readable by the public-facing httpd processes.
- httpd and httpsd share one rate-limit state without a shared file.
- the peer address reaches the verifier in the call args. it is trusted
  only because the caller is the `httpd` \ `httpsd` cube user [ checked
  through the session user, as `web.auth-issue` checks its caller ].

be honest about the limit. httpd already holds `web.auth.secret`, can
write the session store, and has `web.*` on cube [ which includes
`web.auth-issue` ]. **a compromised httpd can forge sessions anyway.**
centralising protects the stored credentials, not live sessions.
narrowing httpd's `web.*` grant to the commands its routes name is an
owner question.

**rate limiting \ lockout** [ verifier memory, survives nothing -- a
restart resets it, acceptably ] :

- per peer address : 10 failed attempts \ 10 min, then 429 with
  `Retry-After`.
- per [ peer, user ] : exponential delay after 3 failures [ 1, 2, 4 ..
  max 60 s ], answered as 429.
- per user, all peers : after 20 failures \ hour the user gets a log line
  at level 0 and a delay, but **no hard lockout**. a hard lockout would
  let anyone lock a known account out from the internet.
- global : one KDF in flight, a queue of 4, 429 beyond. this caps
  CPU \ RAM DoS through the KDF.
- the counters key on the real socket peer [ never `X-Forwarded-For` ],
  the same rule as the gate.

**timing-safe compares.** hash and pub comparisons use
`Crypt::Misc::slow_eq`. for an unknown user, the verifier runs the KDF
against a fixed dummy hash of the current scheme \ cost, so a miss costs
the same time as a wrong password. for key login, a miss runs a verify
against a dummy pub.

**no user enumeration.** one answer for every failure :
`401 { "ok": false, "error": "invalid credentials" }`. this covers an
unknown user, a wrong password, a disabled user, a method not allowed
for the user, and no rights. `/auth/challenge` always issues a nonce.
the rate-limit answer is the same 429 for existing and unknown users.
log lines name the user only after a charset check
[ `^[\w.+-]{1,64}$`, the `web.auth-issue` rule, plus a length cap ] and
never log the password.

**session fixation.** password and key login always mint a fresh session
through `create_session`. a cookie or bearer sent along with the login
request is ignored, never adopted.

**logout everywhere.**

- `web.auth-revoke-user <user>` [ admin ] and `POST /auth/logout-all`
  [ the user's own sessions ] scan `active/*/session.yaml` for the
  `user_id` and call `destroy_session` on each. session counts are small
  enough for a scan, and an index would be a second source of truth.
- a password change or a credential removal runs the same revoke.
- removing an enrolled browser key revokes the sessions minted with it.
  to make that possible, `create_session` records the method and the key
  id in the session `data` [ `{ login => 'key', key_id => .. }` ].

**secret rotation.** changing `web.auth.secret` already refuses every
session minted under the old one [ the `secret_hash` binding in
`verify_session` ]. that includes the **jobsite push token**, which must
be re-minted and redeployed to `jobsite.cfg.sync_token`. user sessions
just need a fresh login. password hashes and enrolled keys do not depend
on the secret, so rotation never forces re-enrollment.

**csrf.**

- **session csrf** : the cookie is already `HttpOnly; SameSite=Strict`,
  plus `Secure` on TLS. cross-site requests carry no cookie. the gated
  POSTs take JSON bodies.
- **login csrf** [ SameSite does nothing here -- the attacker logs the
  victim into the attacker's account ] : the login routes require
  `Content-Type: application/json`, which a cross-site form cannot send
  without a CORS preflight. httpd sends no `Access-Control-*` header
  anywhere [ none in `src/` ; `httpd.http_options` answers only `Allow` ],
  so the preflight never succeeds. that must stay true. they also
  refuse a present `Origin` that differs from `<scheme>://<Host>`.
- `/auth/logout` and `/auth/logout-all` get the same `Origin` check.

**transport.** password login is **refused on a non-TLS socket** unless
the peer is loopback. a password over plain http on a public address is
not accepted, even if the user tries.

## 4. ui flow in index.html

keep the German ui strings and the existing dark `--p7-*` tokens [ no
bright surfaces ]. `#auth-overlay` becomes a small tabbed box :

- **anmelden** [ default ] : `benutzer` [ `autocomplete="username"` ] +
  `passwort` [ `autocomplete="current-password"` ]. the current
  `autocomplete="off"` defeats password managers and goes away for this
  form. the error is always `anmeldung fehlgeschlagen` ; a 429 shows
  `zu viele versuche -- bitte in <n> s erneut`.
- **schlüssel** : shown only when `window.isSecureContext &&
  crypto.subtle` exists and IndexedDB holds a key for this origin. one
  button : challenge, sign, `login-key`. when no key exists yet, a link
  opens enrollment : generate the key, show its b32 plus the
  `bin/p7-web-enroll-key` line to run, take the pasted statement, post
  it to `/auth/enroll-key`.
- **token** : the existing paste field, unchanged, for machine \ admin
  use. it still posts to `/auth/login`, whose behaviour is left
  byte-identical.

**responses.**

- `jobsFetch` keeps its single shared prompt for 401, and the original
  request is retried after login [ an unsent `/jobs-sync` stage move
  survives an expiry ].
- **403 does not open the prompt.** it shows a non-blocking notice
  `keine berechtigung` and returns the response. otherwise a read-only
  user would loop between prompt and 403.
- `/auth/status` gains `expires_at_epoch` [ today it returns no expiry ],
  `rights` and `methods`. the ui reads it at load. it hides write
  controls for `read`, shows the user and a logout \ "überall abmelden"
  item, and warns five minutes before expiry [ `sitzung läuft ab` ].
  expiry stays fixed [ no sliding ] ; a 401 after expiry opens the
  prompt as today.

## 5. fail closed, and the threat model of a public host

**must stay fail-closed** :

| condition | result |
|---|---|
| no `web.auth.secret` | every gated route 401, no session can be created [ existing ] |
| KDF self-test fails \ no KDF module | password login disabled [ 503 on its route ], token and key login unaffected |
| verifier zenka unreachable | login routes 503 ; existing sessions keep verifying in httpd [ store is local ] |
| `access.web` missing or a parse error | every gated request 403, exempt peers included [ their principal is undefined too ], log level 0 [ breaks the push loudly, never opens it ] |
| `/auth/enroll-key` without a session of the statement's user | refused, nothing stored |
| user without a rights line | 403 |
| nonce missing \ expired \ used, `ts` out of window, origin mismatch | 401 |
| delegation invalid \ expired \ wrong issuer \ non-empty scope | enrollment refused, nothing stored |
| password login over plain http off loopback | refused |
| credential store unreadable \ corrupt | that user fails like a wrong password, log level 0 |

**threat model** [ the `/jobs*` api is served on a public host ] :

- **internet scanners and credential stuffing** : rate limits, the KDF,
  no enumeration, key-only for write users.
- **phishing of a password** : key login plus `login.methods = key`
  removes the payoff for users who opt in.
- **xss through job content.** the ui renders scraped job ads and
  imported urls, which is attacker-controllable text. HttpOnly keeps the
  token out of reach, but a script running in the page can still act
  with the session [ and, with key login, sign while it runs ]. output
  escaping in `index.html` is a security boundary, and a
  `Content-Security-Policy` with script hashes for the inline script is a
  follow-up worth its own task.
- **compromised httpd process** : can forge sessions [ see 3 ] ; it
  cannot read password hashes or user master keys.
- **reverse proxy on the same host.** if a proxy ever sits in front of
  httpd on the same machine, every request's real socket peer is
  127.0.0.1, and **`auth.exempt-loopback` then means no auth for
  anyone.** in that set-up the flag must be removed from the routes, and
  the operator notes say so. the gate cannot detect it.
- **exempt peers** : full `:write` by default, for a LAN address. on a
  host whose public address is NATed from a LAN, an exempt LAN address
  can be the router -- keep the list empty unless needed.
- **log injection** : user names are charset-checked before any log line.
- **shared store permissions** : the follow-up's 2770 \ 0660 plan means
  any of the three zenka users can write sessions -- intended. today
  `destroy_session`, `session.write` and `init_code` hardcode 0750 \
  0640 ; the follow-up has to change those, and new files from this work
  must use the follow-up's modes, not copy the old ones.

## not in this design

- webauthn \ passkeys [ hardware-backed, attested ] : stronger than [ b ]
  and the natural next step. it needs CBOR \ COSE parsing on the server
  and is out of scope for this pass.
- password reset by email : no mail flow ; resets are admin-issued.
- multi-host session sharing beyond one host's shared dir.

#,,,,,.,.,.,.,.,.,,..,,..,..,,,.,,.,.,..,,.,,,..,,...,...,,..,,,.,...,..,,.,,,
#WUZOQRZ33UBPC4RW22K4BC5XT7X3SIFV6EXTAF3XZ6MZRBDUHEJ77D3LCNKTOKTWP2UF4OF5W3BP4
#\\\|IP6WDZZLKL5DY53GIFUSML25X26PYGPZP7G3FBWWSSSPANCZAJH \ / AMOS7 \ YOURUM ::
#\[7]J5AN5MMJ3MXCKGFBCXHT3MGTANPZPK5TTZSYMLWNY3CQUKKFI6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
