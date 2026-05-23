# task: credential fabric — zenka ownership model + storage tiers

## context

the proxy zenka and transport selector both need credential resolution.
the credential system is not a monolithic vault — it is a fabric where
each zenka can own credential slots and the storage backend is tiered,
starting with local encrypted storage and expanding toward holographic
cube-fragment distribution.

the key architectural property: for sensitive credentials, the owning
zenka performs the auth operation itself. the credential value never
crosses zenka boundaries. the proxy receives only the result of the auth
operation (e.g. a signed request, an injected header) not the secret.

design reference: `data/md/design/TEMPLATE-RESOLUTION-ENGINE.md`
design reference: `data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md`

## zenka ownership model

credentials are not global. each zenka owns specific credential slots:

```
weather-zenka      owns: openweathermap.api-key
jobsite-zenka      owns: stepstone.session-cookie, linkedin.session-cookie
proxy-zenka        owns: general http sessions (low-sensitivity)
transport-zenka    owns: atom.udt-psk, atom.hysteria-auth
```

registration: a zenka registers its credential slots with the credential
fabric at init time:

```perl
<[credential.register]>->({
    slot    => 'openweathermap.api-key',
    owner   => 'weather',               ## this zenka's name
    type    => 'api-key',               ## see types below
    storage => 'local',                 ## tier preference
    rotate  => { interval => '30d' },   ## optional rotation policy
});
```

resolution: any zenka (including the proxy) requests a credential by slot
name. the fabric routes the request to the owning zenka:

```perl
## caller (proxy, transport, etc):
my $result = <[credential.resolve]>->({
    slot    => 'openweathermap.api-key',
    context => $request_context,
});
## → opaque handle or auth result
## → owning zenka performed the auth operation
## → secret never left the owning zenka
```

## auth operation containment

for sensitive credentials, the owning zenka handles the auth operation
and returns only the result. the proxy never sees the secret:

```
proxy needs auth for openweathermap.com
    ↓
credential.resolve slot='openweathermap.api-key' context=$ctx
    ↓
credential fabric routes to weather-zenka (owner)
    ↓
weather-zenka signs/injects the request with its local key
    ↓
returns: { inject_header => { 'X-API-Key' => '...' } }
    ↓
proxy injects header — secret never left weather-zenka
```

for low-sensitivity credentials (session cookies, bearer tokens) the
fabric can return the value directly. the owner declares sensitivity
level at registration time.

## credential types

```
api-key          → static secret, injected as header or query param
bearer-token     → JWT or opaque token, Authorization: Bearer header
session-cookie   → browser session, injected as Cookie header
basic-auth       → username+password, Authorization: Basic header
tls-client-cert  → certificate + key, used at TLS handshake level
psk              → pre-shared key for tunnel auth (UDT, WireGuard)
oauth-token      → OAuth2 access+refresh token pair, auto-refresh
```

## storage tiers

storage tier is declared per slot at registration. the fabric chooses
the best available tier if `auto` is specified:

### tier 1 — local encrypted (implement now)

twofish encryption with C25519 key. stored in the credential zenka's
private data directory. this is the baseline tier — all other tiers
build on top of it.

```
credential zenka holds: { slot → encrypted_blob }
key held by:            detached key-holder child process
decryption happens:     in child process, result passed to owner via pipe
plaintext never in:     main zenka memory (only in child)
```

### tier 2 — holographic cube fragments (future)

the credential is split into fragments using a threshold scheme.
fragments are distributed across cube nodes addressed by BMW384 geometry.
reconstruction requires a quorum of fragment-holding nodes:

```
credential → split into N fragments (threshold K of N to reconstruct)
fragments  → distributed to K+redundancy cube nodes
             node selection by BMW384 address of (slot_name + ntime_epoch)
reconstruct → collect K fragments, derive original
```

no single cube node holds enough to reconstruct. compromise of K-1 nodes
reveals nothing.

### tier 3 — distributed across cube groups (future)

fragments distributed across multiple cube groups (not just nodes).
group-level threshold scheme. suitable for long-lived credentials that
survive individual node failure.

### tier selection config

```yaml
slot: atom.udt-psk
  storage: local        ## explicit tier 1

slot: identity.master-key
  storage: holographic  ## explicit tier 2 (when available)
  threshold: { k: 3, n: 5 }

slot: session.general
  storage: auto         ## best available tier
```

## STRM notification — credential rotation

owning zenki subscribe to rotation events for their slots. when a credential
rotates (scheduled, forced, or detected as compromised), the fabric pushes
a STRM notification to all subscribers:

```perl
## owning zenka registers:
<[credential.subscribe_rotation]>->({
    slot    => 'openweathermap.api-key',
    handler => 'weather.handler.credential_rotated',
});

## fabric pushes on rotation:
## → weather.handler.credential_rotated fires
## → weather-zenka refreshes its local copy
## → any cached auth results are invalidated
```

the proxy's template selector caches zenka assertion results with
`invalidate_on: STRM:credential.rotated.<slot>` — this hooks into
the same rotation event.

## on-demand handling

some credentials are not pre-registered but requested on-demand by the
proxy when a domain requires auth it has no session for:

```
proxy intercepts request to authenticated.site.com
    ↓
credential.resolve → no slot found for this domain
    ↓
credential.request-authorization domain=$domain context=$ctx
    ↓
web-browser zenka shows approval dialog to user
    ↓
user approves → credential fabric performs login via browser zenka
    ↓
session stored in tier-1 storage
    ↓
future requests to same domain: session found, injected silently
```

this is the auth relay pattern from `P7-NATIVE-WEB.md`. the user sees
seamless authentication. the credential private key never leaves the
detached key holder child process.

## modules to create

- `modules/credential.init_code` — initialize storage, load slot registry
- `modules/credential.register` — zenka registers a credential slot
- `modules/credential.resolve` — resolve slot to auth result or handle
- `modules/credential.store.local` — tier 1: twofish+C25519 storage
- `modules/credential.store.local.key-holder` — detached child: holds key,
  performs decrypt operations, returns results via pipe
- `modules/credential.subscribe_rotation` — register STRM rotation handler
- `modules/credential.rotate` — perform rotation, notify subscribers
- `modules/credential.request-authorization` — on-demand auth relay flow
- `modules/credential.handler.auth-relay-reply` — handle browser approval response

## storage location

`var/credential/` — private to credential zenka user (not world-readable)
slot registry: `var/credential/registry.yaml` (slot metadata, no secrets)
encrypted blobs: `var/credential/store/` (one file per slot, encrypted)

## configuration

`configuration/zenki/credential/start` — standard zenka start file,
runs as dedicated user with restricted filesystem access
`configuration/zenki/credential/access.zenki` — which zenki can call
`credential.resolve` and `credential.register`

credential zenka is on-demand with no idle timeout — always available
once started, never auto-stopped (credentials must always be resolvable).

## integration with proxy zenka

the proxy skeleton (`proxy-zenka-skeleton.md`) has a stub at:

```perl
<[proxy.auth.lookup]>->($context)   ## → { has_session, slots } or undef
```

this task replaces that stub. the proxy calls `credential.resolve` for
each domain it needs auth for. the interface is fixed.

## integration with transport selector

the transport selector (`transport-selector.md`) references credential
slots per transport entry. it calls `credential.resolve` at connection
time. the interface is the same `credential.resolve` call.

## harmony checks

```
harmony credential.init_code
harmony credential.register
harmony credential.resolve
harmony credential.store.local
harmony credential.rotate
harmony credential.request-authorization
```

## signatures note

do not modify or regenerate any AMOS7 signature lines. the signing system
handles all footer blocks — leave them untouched.

#,,.,,..,,.,,,.,.,...,...,.,,,..,,.,,,,,.,,,.,..,,...,...,...,..,,.,,,,,,,.,.,
#CJ42HJNMRMJEXTXMT2JXJNCVAUANM7JNK2KKXXUW4VDYEI5ONBIYOO6EIZTEUGSFJRWIDKO6PI7NM
#\\\|MRTSI6K6Z6QEOXJZYR7KVCGCIOSTIK53SGKUDHNG6C2PHNQDKHD \ / AMOS7 \ YOURUM ::
#\[7]FTIT6M6XDSXAVH73THXYFISERGWIGV7OCK3USESCYZY3AJTKE6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
