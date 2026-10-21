# sessions zenka : session classes, rotation, renewal

draft 2026-10-21 [ user + claude ]. design only -- nothing here is built.
source : todo R4F [ data/yaml/todo/base.yaml ]. owner direction : the
sessions zenka understands native and related session types alike
[ web.auth sessions, link \ keypair sessions, held secrets, outside-sourced
tokens such as the usage zenka's ] with refined, p7-accessible logic --
classes, renewal and rotation live there, not per plugin. builds on
[ WEB-UI-USER-LOGIN.md ], [ AUTH-LINK-BINDING.md ], the rotation command
`v7-zenki.rotate-web-auth-secret` [ landed 2026-10-21 ] and the sessions
stub [ cfg/zenki/sessions ].

## what exists [ read from the source, 4df3fad10 ]

- **web.auth tokens** `plugin.web.auth.create_session` : token =
  `chk-sum.amos( node_id ntime user_id secret entropy )`, entropy = 32
  bytes `base.prng.bytes`. the store keeps `token_hash` [ bmw.L13 of the
  token ] and `secret_hash` [ bmw.L13 of web.auth.secret ], never the
  token. store : `<var_P7>/shared/web-auth/{active,expired}`, owner
  `<system.amos-zenka-user>`, group `web.auth.group` [ httpd ], 2770 \
  0660.
- **one mint path today** : `web.cmd.auth-issue <user_id> [ -ttl <s> ]`
  [ admin, token printed once ]. `plugin.web.auth.handler.login` verifies
  a pasted token and mints nothing -- so every live token today is
  hand-minted. the password \ key login of WEB-UI-USER-LOGIN.md is not
  built.
- **verify** `plugin.web.auth.verify_session` : refuses a session whose
  `secret_hash` differs from the current secret's ; destroys an expired
  one ; rewrites only `last_seen` -- `expires_at_epoch` never slides. two
  consequences used below : a drain ends within one ttl, and a record with
  an EMPTY `secret_hash` passes the binding check [ `length .. and ne` ].
- **rotation** `v7-zenki.cmd.rotate-web-auth-secret [:force-now:]
  [:no-restart:]` : finds the host configs carrying `web.auth.secret`
  [ root 0600 ], counts live sessions per user, refuses unless
  `:force-now:`, writes one new secret everywhere [ temp + rename ], reads
  it back, restarts the zenki that hold it. its own note names the gap :
  ':when-gone: + session classes'.
- **jobsite machine token** `jobsite.sync.token_for_url` : one bearer
  token from `jobsite.cfg.sync_token[s]` in the jobsite host.cfg, minted
  by hand with `-ttl 31536000` [ one year ]. at expiry or after a
  rotation every push chunk fails with a level 0 `chunk failed` line and
  the url's watermark freezes [ `jobsite.handler.sync-response` ] -- no
  401 path, no renewal, nothing says 'token expired'.
- **usage tokens** `plugin.usage.{claude,kimi}.*` : oauth credentials the
  outside cli owns [ `~/.claude/.credentials.json`, `~/.kimi*/credentials` ].
  renewal = run the cli on a pty so it refreshes itself
  [ `refresh_token` ], a watchdog before the claimed expiry
  [ `refresh_watchdog`, claude's expiresAt not trustworthy ], a 401 ->
  refresh -> one retry [ `refresh_retry` ]. per plugin, per provider.
- **sessions zenka stub** : on-demand, `restart.disabled`, drops to
  `<system.amos-zenka-user>`. an identity holder child [ `spawn` \
  `attach` \ `detach` \ `sign` \ `pubkey` \ `stop` \ `status` ] and
  one-shot named secret children [ `hold` \ `release` \ `secrets` ].
  children carry the no-Event.pm rule [ `sessions.holder.child` header ].
  `release` returns the secret AND ends the child.
- **pending state pattern** `base.file.zenka_dir.{write,load,unlink_file}`
  : atomic write [ temp + rename ] under `<var_P7>/<zenka>/`, default 0600.

## 1. session classes

a class is assigned at mint and stored in the record [ `class` key ]. it
says how a session ends, not who it belongs to. three classes [ R4F ] :

| class | what | ends by | on rotation |
|---|---|---|---|
| `interactive` | a person's login [ ttl 24h default ] | logout, expiry | drains [ section 2 ] |
| `renewable:<holder>` | a token its holder re-fetches by itself | expiry, renewal replaces it | ends freely [ = early expiry ] |
| `manual` | hand-minted, pasted somewhere by a person | expiry, re-mint | listed apart -- needs a person |

`<holder>` names who renews it : `jobsite@pri`, a zenka on a named host.
a renewable token also names its **source** : `p7` [ minted by web.auth,
section 4 ] or an outside issuer [ `claude`, `kimi` : the usage oauth
tokens ]. the renewal shape is the same [ proactive before expiry, on a
401, one retry ] ; only the fetch step differs. outside-sourced tokens
have no web-store record and no web.auth secret -- their class lives in
the sessions zenka's own registry, and a web.auth rotation never touches
them.

two more kinds are shown by the sessions zenka but stand **outside the
class scheme** -- nothing mints them as a session record and nothing
rotates them through web.auth :

| kind | what | ends by |
|---|---|---|
| held | a secret a holder child keeps [ `sessions.hold`, the identity holder ] | `release`, holder end |
| link | an authenticated p7 link [ auth-keypair v2, unix, zenka ] | disconnect |

### mapping of what exists

| kind today | class | note |
|---|---|---|
| `web.auth-issue` for a person [ ui paste ] | `manual` | the only mint path today |
| jobsite push token [ `jobsite-push`, 1y ] | `manual` today -> `renewable:jobsite@<host>` | section 4 |
| password \ key login [ WEB-UI-USER-LOGIN.md, not built ] | `interactive` | `create_session` called by the login verifier |
| usage oauth credentials | `renewable:usage`, source `claude` \ `kimi` | the source adapter stays in the plugin [ section 4 ] |
| cube sessions, external links | -- [ link ] | listed read-only from cube \ external |
| `sessions.hold` [ e.g. users `host_password` staging ] | -- [ held ] | |
| `sessions.holder` identity | -- [ held ] | its own key, not a session to rotate |

**records without a class** default to `manual` : visible, never drained
silently, never ended as renewable. the pri store had 0 sessions on
2026-10-21, so there is nothing to migrate -- the default only covers
stores elsewhere.

**an empty `secret_hash`** : such a record survives every rotation. the
class step also closes this : a record without `secret_hash` is refused
[ `create_session` always writes one ; an empty one is a damaged or
hand-made record ].

who passes the class : `create_session` takes `class` like `ttl` today.
`web.auth-issue` sets `manual` ; the login verifier sets `interactive` ;
the renewal mint [ section 4 ] sets `renewable:<holder>`. the caller
never picks `renewable` freely -- it comes from the renewal grant.

## 2. rotation semantics

a leaked `web.auth.secret` alone forges nothing [ 32 prng bytes per token,
only hashes stored ]. the secret is the switch that ends all sessions at
once -- rotation is hygiene and is seamless by default.

| class | default [ no flag ] | `:when-gone:` | `:force-now:` |
|---|---|---|---|
| `renewable` [ source p7 ] | ends -- the holder renews on its next 401 | ends | ends |
| `interactive` | refuses, lists them | waits until none are live, then rotates | ends them |
| `manual` | refuses, lists them apart with the place to re-mint | NOT waited for -- listed apart, the rotation does not wait on a person | ends them, listed for re-mint |

- **renewable = early expiry.** a holder already handles expiry ; a
  rotation is the same event earlier. nothing waits on it.
- **interactive drains.** `:when-gone:` records a pending rotation
  [ section 3 ] and re-checks at each network epoch boundary
  [ `base.ntime.epoch_dec 'next'` -> one timer ] : when no live
  interactive session minted under the current secret remains, the
  rotation runs. because expiry never slides, the wait is at most one
  interactive ttl ; logouts shorten it.
- **manual is listed apart.** the report names each manual session's
  user and, where known, where it is pasted [ `data.deployed_to`, set by
  whoever mints it ]. `:when-gone:` with only manual sessions left runs
  the rotation and reports them as ended -- waiting a year for a pasted
  token is not a drain.
- **`:force-now:`** stays as it is : everything ends, the report lists
  what to re-mint.

### what counts as live

'live' = in `active/`, not expired, AND `secret_hash` equal to the
current secret's hash. today's count in the rotation command checks
expiry only. that is not enough : `verify_session` returns on a secret
mismatch BEFORE its expiry check, so records ended by a rotation are
never moved to `expired/`. without the hash an ended 1y manual token
stays 'live' for a year, and old interactive records would hold a
`:when-gone:` for a full ttl after they already stopped working.

- the current hash = `chk-sum.bmw.L13-str( web.auth.secret )`. only
  v7-zenki can compute it [ it reads the root 0600 host configs ] ; it
  passes the hash in, never the secret.
- **the rotation run cleans up** : after the read-back it moves every
  record it ended [ old `secret_hash` ] to `expired/` through
  `plugin.web.auth.destroy_session`, so the store matches what verifies.

### who does what

the sessions zenka drops to `<system.amos-zenka-user>`, is on-demand and
not restarted ; it cannot rewrite root 0600 host configs nor restart
zenki. the split :

| part | owner |
|---|---|
| class rules + counting [ `sessions.store.*` modules ] , listing, the p7 surface | sessions namespace |
| writing the secret, read-back, restart, cleanup, the pending record, the epoch re-check | v7-zenki [ as now ] |
| minting [ holds the secret ] | web [ `create_session` ] |

one direction only, no call cycle : v7-zenki **loads** the counting
modules from the `sessions.*` namespace [ module reuse, as `cube-13`
loads `cube` modules ] and runs them itself with the current hash -- it
already reads the store as root today. it never calls the sessions zenka
at runtime, so the epoch re-check works when sessions is not running.
`sessions.rotate` forwards to `v7-zenki.rotate-web-auth-secret` with the
flags and relays its reply [ an async reply : the command answers when
v7-zenki has ]. the sessions zenka's own listing uses the same modules
without the hash and shows 'secret : current \ old \ unknown' only when
v7-zenki supplied the hash with the last check.

## 3. restart-safe pending rotation

a pending `:when-gone:` must survive a v7-zenki restart [ R4F ]. it is a
small record, written by v7-zenki into its own var dir :

```
file.zenka_dir.write( 'rotation-pending.json', \$json, '>', 0600 )
-> <var_P7>/v7-zenki/rotation-pending.json

{ requested_at : <ntime>, requested_by : <user>, key : web.auth.secret,
  targets : [ httpd, httpsd, web ], restart : 1,
  waits_for : [ interactive ] }
```

- **the record never holds the secret.** the secret is generated when
  the rotation runs [ `base.prng.chars-anum` in the command, as today ]
  -- nothing secret waits on disk.
- **re-arm at init.** `v7-zenki.init_code` loads the record
  [ `file.zenka_dir.load` ] and arms the epoch check. guarded by
  `$reinit` : a reload cancels the old timer before arming a new one,
  the same pattern as `plugin.usage.claude.init_code`'s watchdog.
- **the run unlinks it** [ `file.zenka_dir.unlink_file` ] after the
  read-back.
- **a crash between the host.cfg writes and the unlink** only rotates
  twice : the next start finds the record and counts against the NEW
  secret's hash. usually nothing was minted under it yet -> the check
  passes at once and a second new secret is written. if people logged in
  under the new secret meanwhile, the second rotation drains them like
  any other -- still harmless. the read-back checks that every file
  carries one value either way.
- targets are re-read at run time from `/etc/protocol-7/*/host.cfg`
  [ the record's list is for the status line only ] : a config added or
  removed while waiting is handled as a direct run would.
- a second `:when-gone:` while one is pending replaces the record
  [ newest request wins, one line logged ] ; `sessions.rotate :cancel:`
  unlinks it.
- a status line shows a pending rotation : in v7-zenki and in
  `sessions.rotation` [ requested at, by, waiting for N interactive
  sessions, next check at ].

## 4. renewal path for machine tokens

goal : no hand-minted long-lived tokens. a holder fetches its own token,
renews it before expiry and on a 401, so ttls can be short [ hours to a
day instead of a year ].

```
holder host [ jobsite ]                       issuer host [ httpd \ web ]
sessions zenka                                web zenka
  |  ~2/3 ttl timer, or a 401 reported           |
  |-- external.<link>.web.auth-renew ----------->|  caller identity -> grant
  |                                               |  create_session( class
  |<-- token + expires_at_epoch -----------------|    renewable:<holder> )
  |  keep in memory [ or 0600 in var dir ]       |  old token destroyed
  |  jobsite.sync.token_for_url asks sessions    |  after a short overlap
```

- **transport** : an authenticated p7 link [ auth-keypair v2 + server pin,
  AUTH-LINK-BINDING.md ]. the permanent link supervisor is todo 3W5
  [ host-edit records, ssh forward ] -- renewal depends on it. until
  then the holder can only renew on the same host.
- **prerequisite : who is calling.** a routed command reaches web with
  the cube router as its ambient caller -- `web.cmd.auth-issue`'s admin
  gate relies on exactly that, cube has already applied its own access
  table. no field on the routed call carrying the origin user was found
  [ `$call` holds args, reply_id, session_id .. ]. so web cannot tell
  WHICH link user asks. two ways, to decide before stage 4 :
  - cube forwards the authenticated origin user with the routed call
    [ a new field ; also useful for audit lines ] -> one `web.auth-renew`,
    grants keyed by that user
  - without it : one pinned command per holder [ `web.auth-renew-<holder>`
    or a fixed argument ], granted in cube `access.users` to that one link
    user only -- the grant is the access line itself
- **the renew command is narrow.** `web.auth-renew` takes NO `user_id` :
  the user and ttl come from a grant keyed by the caller identity
  [ e.g. `auth.renew.<link-user> = jobsite-push 21600` in the web
  host.cfg ]. no grant -> refused. otherwise renew would be
  `auth-issue` with another name.
- **one live token per holder** : a renewal destroys the previous token
  after a short overlap [ in-flight requests ], so a stolen copy dies at
  the next renewal at the latest.
- **when** : at ~2/3 of the ttl, and at once when the consumer reports a
  401 [ jobsite : `sync-response` learns to tell a 401 apart and calls
  `sessions` instead of only logging ]. after a rotation the 401 path
  renews within one push cycle. bounded retry with backoff ; after N
  failures one level 0 line naming the holder and the issuer.
- **where the token lives** :

| place | survives | cost |
|---|---|---|
| sessions parent memory | nothing -- the zenka is on-demand and not restarted | a re-fetch on every start ; fine, a renewable token IS re-fetchable |
| 0600 file in the holder's var dir [ `file.zenka_dir.write` ] | restarts, reboots | a token at rest [ short ttl limits it ] |

  memory is the default ; the file is the fallback for a host whose
  holder must push before the link is up.
- **timers live in the parent.** the holder children have no Event.pm ;
  renewal timers, the 401 hook and the link call run in the sessions
  parent. a child holds the value only.
- **`sessions.secret.child` cannot hold it as is** : `RELEASE` returns the
  secret and ends the child. a renewable slot needs `READ` [ non-
  destructive ] and `REPLACE` ops, or a second child kind.
- **settle the holder first** : two key-holding child implementations
  exist [ `cred-mesh.key_holder.*` and `sessions.holder.*`, todo 6C6 ].
  one holder is chosen before renewal is wired onto either.

### outside-sourced tokens [ usage ]

the same shape with another source : `renewable:usage` [ source
`claude` ] renews by running the provider's cli, not by a p7 call. what
moves into sessions is the generic part -- the watchdog timer, the 401
-> renew -> one retry rule, the status line. what stays in the plugin is
the source adapter [ `refresh_token` : how this provider renews, where
its file is ].
web.auth rotation never touches these.

| step | source p7 | source claude \ kimi |
|---|---|---|
| fetch | `web.auth-renew` over a link | provider adapter [ cli on a pty ] |
| proactive | ~2/3 ttl | before the claimed expiry [ claude : not trustworthy ] |
| reactive | 401 from the consumer | 401 from the probe |
| stored by | sessions [ memory \ 0600 ] | the outside cli [ its own file ] |

## 5. p7 command surface

existing names stay : `status` [ holder child ], `secrets`, `hold`,
`release`, `sign`, `pubkey`, `spawn` .. `stop`. `list` is taken
[ `base.cmd.list` ]. new verbs [ candidates, harmony check pending ] :

| command | does |
|---|---|
| `sessions.by-class [ <class> ]` | counts per class, or the sessions of one class [ user, created, expires, holder ; never a token ] |
| `sessions.session <token_hash>` | one record : class, user, expiry, holder, deployed_to |
| `sessions.rotation` | pending rotation, last rotation, what it waits for |
| `sessions.rotate [:when-gone:\|:force-now:\|:cancel:] [:no-restart:]` | forwards to v7-zenki, relays its reply [ async ] |
| `sessions.renew <holder>` | renew a renewable token now [ any source ] |
| `sessions.renewals` | each renewable holder [ per source ] : expires, next renewal, last result |

`by-class`, `session` and `rotation` read only ; `rotate` and `renew`
change state and are granted to admin users only [ cube
`access.users` ]. `web.auth-renew` lives on web, granted per link
identity [ section 4 ].

## 6. staged plan

0. **decide the holder** [ 6C6 ] : cred-mesh `key_holder` vs
   `sessions.holder` -- one implementation, with read \ replace ops.
1. **class at mint** : `create_session` takes `class` ; `web.auth-issue`
   writes `manual` ; records without a class read as manual ; refuse
   records without `secret_hash`. read-only `sessions.by-class` \
   `sessions.session` over the shared store.
2. **class-aware rotation** : v7-zenki loads the `sessions.store.*`
   counting modules and counts with the current secret hash ; ended
   records move to `expired/` ; renewable end freely, manual listed
   apart, interactive refused unless `:when-gone:` \ `:force-now:`.
3. **pending rotation** : `rotation-pending.json` in v7-zenki's var dir,
   epoch re-check, `$reinit`-guarded re-arm, unlink after the run, status
   line.
4. **renewal** : the caller-identity prerequisite, `web.auth-renew` with
   its grants, the sessions holder slot + timers,
   `jobsite.sync.token_for_url` asking sessions, 401 in `sync-response`.
   needs 3W5 links for the cross-host case. first machine token minted
   this way, never by hand [ R4F : build this before the first machine
   token ].
5. **outside sources** [ renewable:usage ] : usage's watchdog \ retry
   rule moved behind a source adapter ; `sessions.renewals` lists them.
6. **interactive** : arrives with the login verifier of
   WEB-UI-USER-LOGIN.md.

tests per stage like `test-v7-zenki-optional-dependencies.pl` : a temp
store with one session of each class, a rotation with each flag, a
crash between write and unlink [ record left behind -> second rotation,
one value read back ].

## open

- names : `by-class`, `session`, `rotation`, `rotate`, `renew`,
  `renewals`, `web.auth-renew`, `rotation-pending.json` -- harmony check
- caller identity on routed commands [ section 4 prerequisite ] : cube
  forwards the origin user, or one pinned renew command per holder
- the grant format for `web.auth-renew` : host.cfg key vs an access file
- overlap length after a renewal before the old token is destroyed
- default renewable ttl [ 6h ? 24h ? ] and the 401 retry bound
- does `web.auth.secret` itself become a `held` value in the sessions
  holder instead of root 0600 host.cfg lines [ R4F : 'perhaps' ] -- that
  would move the write step out of v7-zenki and change section 2's split
- links : list only, or also end them [ `sessions.end <id>`
  routed to cube ] -- and whether a link has a renewable credential at all
- should `:when-gone:` wait for the epoch boundary or also re-check on
  each logout [ `destroy_session` -> notify ] for a faster run

#,,.,,.,,,,,.,.,.,..,,...,,,.,.,,,..,,,,.,,,.,..,,...,...,,..,,..,.,,,,..,...,
#A73YMVI2ZIZ67SJ5X2ABGRLKRVZ33AUEGAXV3FCVWJSW3GFNIMFJMICW3JLH7PHZGKJ4TNJTOUQFK
#\\\|5G4EWPVFNEKHQBWHUCTATZYZDBUHO5LPUT7HQRUPWBWN73ROSZI \ / AMOS7 \ YOURUM ::
#\[7]4LTAZXYKEVRM3LIUQPHHYNDV6M6EPO3HT3FLCVNYG44WEV27UEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
