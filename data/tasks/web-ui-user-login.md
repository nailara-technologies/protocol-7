# web ui user login [ from data/md/design/WEB-UI-USER-LOGIN.md ]

real user login for the jobsite web ui
[ `data/web-root/vhosts/jobsite.vhost/index.html` ] on top of the web auth
layer of e818f20fb. the session store, the cookie and the gate stay ;
new are the credential check in front of `create_session` and per-user
rights at the gate. read `CLAUDE.md` and the design file first.

## open questions for the owner [ decide before the stage named ]

1. **token entropy** [ stage 0 ] : `create_session` derives the token as
   `amos( node ntime user secret )`, with no random input. with
   user-triggered logins, two sessions of one user inside one ntime tick
   would get the same token. a leaked secret would also make tokens
   recomputable from public fields. **default** : append 32 bytes of
   `base.prng.bytes` to the input. old tokens stay valid, since only the
   hash is stored.
2. **identity source** [ stage 3 ] : must a web login name exist as a
   users zenka record [ `[USERS_HOST]/<user>/details.yaml` ], or is the
   web credential store its own namespace ? **default** : its own
   namespace, with an optional check against the users record when the
   users zenka is reachable.
3. **KDF** [ stage 3 ] : argon2id where `Crypt::Argon2` \ CryptX >= 0.088
   is present [ the `vault` profile ], pbkdf2-sha256 600000 otherwise --
   or require the `vault` profile on the verifying host and use argon2id
   only ? **default** : both, preferring argon2id, with the scheme
   recorded per hash.
4. **verifier zenka** [ stage 4 ] : `web` [ default : already carries
   `plugin.web.auth` ] or a dedicated on-demand zenka. also : is a 150 ms
   KDF on the web event loop acceptable, or fork a child from the start ?
   **default** : in-loop with a cap of one in flight ; fork later if
   `jobs.json` latency shows it.
5. **httpd cube grant** [ any time ] : narrow `access.cmd.usr.httpd`'s
   `web.*` to the commands its routes name [ removes `web.auth-issue`
   from a compromised httpd's reach ] ? this design does not need it,
   but recommends it.
6. **exempt principal** [ stage 1 ] : keep loopback \ exempt peers at
   `:write` [ today's full access, default ] or lower them to `:read` ?
7. **password over plain http** [ stage 5 ] : refused off loopback
   [ default ]. confirm, since it disables password login for a plain-http
   LAN set-up [ token paste still works there ].
8. **user master pub for enrollment** [ stage 8 ] : the web side needs
   the user's `<user>.base` public key. read the cube's
   `authorized-remote` registration through a new narrow cube command,
   or register it into the web credential record by an admin command ?
   **default** : admin command `web.auth-set-user-key <user> <pub_b32>`,
   explicit and auditable.
9. **password set flow** [ stage 3 ] : admin sets the initial password
   through stdin [ `p7c web.auth-set-password <user> < file`, never on
   argv ] ; is self-service password change in the ui wanted in this
   pass ? **default** : no, admin only.
10. **delegation lifetime** [ stage 8 ] : default `not_after` for a browser
    key enrollment. **default** : 180 days.

## rules for every stage

- floor perl : `bin/format-code -c` and `bin/dev/ptd -c` pass [ perl 5.32
  when installed ].
- `bin/test-scripts/test-web-auth-gate.pl` still passes after every stage.
- house style : lowercase comments, `[ word ]` brackets, module file
  header `# name` \ `# descr`, no `sub { }` modules.
- no real host, domain or address in any tracked file. examples use rfc
  5737 \ 3849 addresses or `.example`, marked as examples.
- new state files follow the shared-dir modes [ 2770 dirs, 0660 files ]
  when they live in `/var/protocol-7/shared/web-auth`. the credential
  store is 0600 \ 0700, owned by the verifier's user.

## stage 0 : session prerequisites [ small ]

- `src/plugin.web.auth.create_session` : add 32 prng bytes to the token
  input [ q 1 ] ; charset-check `user_id` [ `^[\w.+-]{1,64}$` ] ; accept
  `data => { login => .., key_id => .. }` [ already generic ].
- `src/plugin.web.auth.handler.status` : add `expires_at_epoch`.
- test : extend `test-web-auth-gate.pl` -- `two sessions same user same
  tick -> distinct tokens`, `bad user_id -> undef`, `status carries
  expires_at_epoch`.

## stage 1 : rights config, no enforcement

- new `cfg/zenki/httpd/access.web` [ roles `read` \ `write` \ `push`,
  `access.web.usr.jobsite-push = :push`, `access.web.exempt = :write` ].
  the same file serves httpsd [ a symlink or an explicit load, matching
  how `routes` is shared ].
- new `src/plugin.web.auth.rights.load` [ parse, expand `:role`, refuse
  wildcards, merge `web.auth.rights.<user>` from host config ] and
  `src/plugin.web.auth.rights.allows` [ `( user_id, command )` -> TRUE \
  FALSE ; the exempt principal under a reserved name ].
- load it in `cfg/zenki/httpd/zenka.v7` init ; whitelist the modules
  [ `bin/dev/gen-sub-whitelist httpd` ].
- test : new `bin/test-scripts/test-web-auth-rights.pl` -- role
  expansion, `read` refuses `web.jobs-sync`, `push` allows only
  `web.jobs-sync`, an unknown user is refused, a wildcard line is a parse
  error, a missing file is refused, host-config rights merge.

## stage 2 : enforce rights at the gate

- **deploy order** : stage 1's file plus a `web.auth.rights.<user>` line
  for every existing ad-hoc token user must be in place first, or remote
  sync breaks.
- `src/httpd.route.handler.web-relay` : after `verify_session`, check
  `rights.allows( user_id, command )` -> 403 + log level 1. the exempt
  path checks the exempt principal. a rights load error -> 403 for every
  request, exempt peers included, log level 0.
- `cfg/zenki/httpd/routes` : comment update [ rights now apply ].
- test : extend `test-web-auth-gate.pl` -- `push token relays
  /jobs-sync`, `push token -> 403 on /jobs.json`, `read user -> 403 on
  /jobs-sync`, `write user relays all six`, `exempt peer uses exempt
  principal`, `no rights line -> 403`, `broken access.web -> 403 not
  relay`.

## stage 3 : credential store + KDF [ verifier side, no route yet ]

- new `src/plugin.web.auth.cred.hash` \ `.cred.verify` [ PHC-style
  string, argon2id \ pbkdf2-sha256, `Crypt::Misc::slow_eq`, dummy-hash
  path ] ; `.cred.self_test` [ known vector at init -> disables password
  login on failure ] ; `.cred.read` \ `.cred.write` [ one yaml per user
  in the verifier's own `etc_P7` dir, 0600 : hash, methods, enrolled
  keys, disabled flag ].
- `cfg/zenki/web/deps/p-mod` [ and httpd's, if it ever verifies ] : add
  the CryptX submodules used [ `Crypt::KeyDerivation`, `Crypt::Argon2`
  when chosen ] in the existing `Name__Sub` form, so the dependency
  check stays truthful.
- new `src/web.cmd.auth-set-password` [ admin gate copied from
  `web.cmd.auth-issue`, password from stdin, triggers revoke in stage 6 ].
- test : new `bin/test-scripts/test-web-auth-kdf.pl` -- hash \ verify
  round trip per scheme, a wrong password fails, the dummy path takes
  time within 20 % of a real verify, the self-test vector, a rehash on
  an outdated cost, a corrupt record fails closed, the file mode is 0600.

## stage 4 : verifier command

- new `src/web.cmd.auth-password` [ args : user, password, peer, scheme ;
  caller must be the `httpd` \ `httpsd` cube user ; rate limits, one KDF
  in flight + queue of 4 ; on success `create_session( { user_id, data
  => { login => 'password' } } )` ; one generic failure answer ].
- new `src/plugin.web.auth.ratelimit.*` [ per peer, per [ peer, user ],
  per user ; in-memory, pruned by a timer ].
- `cfg/zenki/cube/access.zenki` : add `web.auth-password` to
  `access.cmd.usr.httpd` [ explicitly, even while `web.*` covers it ].
- test : new `bin/test-scripts/test-web-auth-password.pl` -- `good
  password -> session`, `wrong -> generic failure`, `unknown user ->
  same answer`, `disabled user -> same answer`, `caller not httpd ->
  refused` ; new `bin/test-scripts/test-web-auth-ratelimit.pl` -- 429
  after 10 per peer, backoff per [ peer, user ], no hard lockout,
  queue full -> 429.

## stage 5 : httpd route POST /auth/login-password

- new `src/plugin.web.auth.handler.login_password` [ checks
  `Content-Type: application/json`, the `Origin` rule, TLS-or-loopback
  [ q 7 ] ; relays deferred to `web.auth-password` with the real peer ;
  a reply handler sets the cookie exactly as `handler.login` does ;
  ignores any incoming cookie \ bearer ].
- new `src/plugin.web.auth.handler.login_password.reply`.
- `cfg/zenki/httpd/routes` : `POST /auth/login-password`.
- `/auth/login` stays byte-identical.
- test : extend `test-web-auth-password.pl` -- `form content-type ->
  415`, `foreign Origin -> 403`, `plain http off loopback -> refused`,
  `cookie flags HttpOnly SameSite=Strict [ Secure on TLS ]`, `incoming
  cookie not adopted`.

## stage 6 : revoke

- new `src/plugin.web.auth.revoke_user` [ scan `active/*/session.yaml`
  by `user_id`, optional `key_id` filter, `destroy_session` each ].
- new `src/web.cmd.auth-revoke-user` [ admin ] ;
  `POST /auth/logout-all` [ the user's own, `Origin` check ] ; called
  from `auth-set-password` and from key removal.
- test : new `bin/test-scripts/test-web-auth-revoke.pl` -- three sessions
  of one user plus one of another, `revoke -> only the three gone`,
  `password change revokes`, `key filter revokes only that key's
  sessions`, `secret rotation -> push token refused` [ documents the
  re-mint ].

## stage 7 : ui password form

- `data/web-root/vhosts/jobsite.vhost/index.html` : tabbed
  `#auth-overlay` [ anmelden \ token ], autocomplete attributes, generic
  error, 429 text ; `jobsFetch` : 403 -> notice, no prompt ; load-time
  `/auth/status` -> hide write controls for `read`, user menu with
  abmelden \ überall abmelden, five-minute expiry warning.
- dark `--p7-*` tokens only, German strings.
- test : manual checklist in the commit message [ login, wrong password,
  429, read user sees no write controls, 403 no loop, expiry retry keeps
  a pending stage move ] ; optional headless check with the installed
  chromium.

## stage 8 : key enrollment + key login [ server ]

- new `src/web.cmd.auth-set-user-key` [ q 8 ] ; `POST /auth/enroll-key`
  [ requires a session of the statement's user, `Origin` \
  content-type checks ; parses `p7 delegation v1` with `trust.statement`, acceptance order of
  HOST-ROOT-DELEGATION.md rule 2, issuer eq the stored user key, scope
  empty ] ; `POST /auth/challenge` [ 32 prng bytes, 60 s, issued for
  unknown users too ] ; `POST /auth/login-key` [ `p7 web-login v1`
  message, single-use nonce, `ts` ±120 s, origin rule, dummy verify on a
  miss ] ; `src/web.cmd.auth-remove-key`.
- new `bin/p7-web-enroll-key` [ perl, local lib path `BEGIN` block like
  `bin/mk.usr` ; signs with the user's `<user>.base` ; prints the wire ].
- test : new `bin/test-scripts/test-web-auth-keylogin.pl` -- the
  `login_msg` hex vector of the design file byte for byte, plus a
  signature vector from a fixed-seed key [ 32 x `\x03`, test only, added
  to the design file in this stage ] ; `replayed nonce -> 401`, `expired
  nonce -> 401`, `wrong origin -> 401`, `unknown user -> same 401`,
  `delegation with scope -> refused`, `expired delegation -> refused`,
  `wrong issuer -> refused`, `enroll without session -> refused`,
  `enroll with another user's session -> refused`, `fingerprint printed
  by the tool eq the ui's`. `Crypt::PK::Ed25519` \ `Crypt::Ed25519`
  goes into the verifier's `deps/p-mod`.

## stage 9 : ui key login

- `index.html` : schlüssel tab when `isSecureContext && crypto.subtle`
  [ hidden otherwise ] ; enrollment panel [ generate non-extractable
  Ed25519, IndexedDB, show pub b32 and the enroll command, paste the
  statement ] ; raw \ spki export fallback.
- test : the browser signs the design's vector message with the
  fixed-seed test key imported as pkcs8, and the result equals the stage
  8 signature vector [ Ed25519 is deterministic ] ; manual check in
  Firefox, Chromium, Safari.

## stage 10 : per-user method policy

- credential record `login.methods = password key` \ `key` ; the verifier
  refuses a method not listed with the generic failure.
- test : extend `test-web-auth-password.pl` -- `key-only user -> password
  login fails generically`.

#,,..,,.,,.,.,..,,...,..,,.,,,,,,,,.,,,,.,.,.,..,,...,...,.,.,,.,,..,,...,..,,
#THPYQCM3THZUJW6KLJHCWK7PG6PGF3DPOSYQ34TWW3IMJXYEIBRFFKN5MCZSPYST2WRNQZLIUDPB6
#\\\|XIPV73VS62NLNWRJMQ26IUAEG42LP2URQLWLYDAEKJL3WO6ZEWI \ / AMOS7 \ YOURUM ::
#\[7]MLJJQAY6XQMRMOT5KJEWPB4OLLEQOJH72PVECHSWV6X4CLNAWCAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
