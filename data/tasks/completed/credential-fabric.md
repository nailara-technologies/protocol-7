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

- `src/credential.init_code` — initialize storage, load slot registry
- `src/credential.register` — zenka registers a credential slot
- `src/credential.resolve` — resolve slot to auth result or handle
- `src/credential.store.local` — tier 1: twofish+C25519 storage
- `src/credential.store.local.key-holder` — detached child: holds key,
  performs decrypt operations, returns results via pipe
- `src/credential.subscribe_rotation` — register STRM rotation handler
- `src/credential.rotate` — perform rotation, notify subscribers
- `src/credential.request-authorization` — on-demand auth relay flow
- `src/credential.handler.auth-relay-reply` — handle browser approval response

## storage location

`var/credential/` — private to credential zenka user (not world-readable)
slot registry: `var/credential/registry.yaml` (slot metadata, no secrets)
encrypted blobs: `var/credential/store/` (one file per slot, encrypted)

## configuration

`cfg/zenki/credential/zenka.v7` — standard zenka start file,
runs as dedicated user with restricted filesystem access
`cfg/zenki/credential/access.zenki` — which zenki can call
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

## codebase findings

### existing patterns to reuse

**C25519 implementation (`src/crypt.C25519.*` — 63 modules):**
- `crypt.C25519.pre_init` — loads `Crypt::Ed25519`, `AMOS7::Twofish`, `Crypt::Curve25519`
- `crypt.C25519.sign_data` — `Crypt::Ed25519::sign($msg, $pub, $priv)`
- `crypt.C25519.verify_sign` — `Crypt::Ed25519::verify($msg, $pub, decode_b32r($sig))`
- `crypt.C25519.compute_shared` — `Crypt::Curve25519::shared_secret($our_secret, $their_public)` → 32-byte DH shared secret
- `crypt.C25519.load_keys_from_secret` — loads `.secret` file, decrypts with Twofish if encrypted
- `crypt.C25519.decrypt_secret_key` — decrypts 32-byte secret key using `AMOS7::Twofish` + `AMOS7::13::key_32($password)`
- `crypt.C25519.decrypt_priv_keystr` — decrypts 64-byte private key using same Twofish path
- `crypt.C25519.write_keys` — writes key files to disk; accepts optional encryption password
- Memory locking: `IO::AIO::aio_mlock` on private (64B) and secret (32B) keys
- Secure deletion: `/usr/bin/shred -n 42` on key backup files

**Symmetric encryption:**
- `AMOS7::Twofish` — primary cipher, loaded by `crypt.C25519.pre_init`, `keys.init_code`, `credentials.init_code`
- API pattern:
  ```perl
  my $key_32 = AMOS7::13::key_32(\$password);
  AMOS7::Twofish::key_init($key_32, qw| decryption C25519 |);
  my $dec_ref = AMOS7::Twofish::decrypt(qw| C25519 |, \$data);
  AMOS7::Twofish::delete_table_entry(qw| decryption C25519 |);
  ```
- ChaCha20-Poly1305 (`Crypt::AuthEnc::ChaCha20Poly1305`) — used for session link encryption in `protocol.protocol-7.encryption.init`, NOT for at-rest storage.
- **No AES modules found.**

**Hashing:**
- `Digest::BMW` (224/256/384/512) — used throughout
- `blake2b_384_b64` — used by `plugin.auth.zenka` for session key hashing

**Existing credentials system (`src/credentials.*` — 14 modules):**
- `credentials.init_code` — loads `AMOS7::13`, `AMOS7::Twofish`. Sets store dir `/var/protocol-7/credentials/`, session TTL 3600s, archive block size 13K. Starts cleanup timer every 5 min.
- `credentials.load` — decrypts credential archive (`$cred_name.yaml.enc`) using Twofish (password = `$cred_name . ':' . $instance_id`)
- `credentials.save` — encrypts and writes credential archive with same derivation
- `credentials.cmd.request_session` — **cube-authenticated caller requests credential access.** Checks `authorized_zenki` list. Returns api-key, smtp/imap creds, or spawns web-session token.
- `credentials.spawn_web_session` — generates session token ID, stores in `%credentials.session` with TTL
- `credentials.handler.session_cleanup` — purges expired tokens
- `credentials.read_archive` / `write_archive_file` — Twofish-encrypted archive I/O with randomized offset padding and 13K entropy padding
- `credentials.audit` — audit logging

**Key holder / child process patterns:**
- **Pattern A (`socketpair` + `fork`):** `letsencr.base.fork_letsencr_child` — `socketpair()`, `<[base.fork]>`, child closes one end, parent closes the other, child loads runtime modules and creates session over pipe.
- **Pattern B (`IPC::Open3::open3`):** `coding.spawn_inference_server` — external binary, non-blocking pipes, event loop IO watchers.
- **Pattern C (`IPC::Open2::open2`):** `kimi.session.start_api_child` — inline perl child.
- **Pattern D (background daemonization):** `base.process-into-background` — `fork`, `IO::AIO::reinit`, `POSIX::setsid`, redirect stdio to `/dev/null`.
- Common infrastructure: `base.fork`, `base.zenki.report_child_pid`, `v7.handler.zenka_output`, `base.waitpid`.

**Session infrastructure:**
- `base.session.init`, `base.session.init_code`, `base.session.shutdown`, `base.session.calc_cmd_stats`
- `base.handler.read.encryption-wrapper` / `base.handler.write.encryption-wrapper` — ChaCha20-Poly1305 session wrappers
- `protocol.protocol-7.encryption.init` — derives 32-byte session key from C25519 DH shared secret via `AMOS7::13::key_32`

**Auth modules:**
- `auth.zenka.authenticate` — client-side zenka auth using `session_key`, securely erases key from memory after use
- `plugin.auth.zenka` — server-side zenka auth. Compares `blake2b_384_b64($key_str)` against `$keys{'auth'}{'zenka'}{$user}`. Single-use keys (deleted after success).
- `plugin.auth.twofish` — Twofish/C25519 auth protocol handler. Commands: `get-version`, `get-srv-key`, `get-key-sig`, `set-key`.

**Keys zenka (`cfg/zenki/keys/`):**
- Configures the standalone `keys` zenka — a privileged console tool for key generation, encryption, backup, signing, splitting, renaming.
- Loads modules `crypt.C25519 terminal keys`.
- **This is NOT a runtime "key holder" service for other zenki.** It is a human-operated management zenka.

### integration points confirmed

**Proxy zenka stub replacement:**
- The proxy task defines `proxy.auth.lookup` as a stub returning `{ has_session => FALSE }`.
- The credential fabric should register at `credential.resolve` (or alias `proxy.auth.lookup` → `credential.resolve` during transition).
- Interface: `credential.resolve` receives `{ slot => '...', context => $request_context }` and returns an opaque handle or auth result.

**Transport selector integration:**
- Transport profiles reference credential slots (e.g., `atom.udt-psk`).
- The transport selector calls `credential.resolve` at connection time.
- The credential fabric must resolve these slots even though they are owned by the transport zenka.

**Existing credentials directory:**
- `/var/protocol-7/credentials/` is already used by `src/credentials.*`.
- The new credential fabric should either extend this directory or use a separate path to avoid collisions.

### naming conflicts or overlaps

- **`src/credentials.*` (plural, 14 modules) already exists.** The task proposes `src/credential.*` (singular). This is a **critical naming collision.** The existing `credentials` system handles SMTP/IMAP/API creds, web sessions, and encrypted archives. The new task's `credential` fabric is a broader, multi-owner system with STRM rotation, tiered storage, and zenka ownership.
   - **Options:** (a) merge into existing `credentials.*` namespace, (b) use distinct prefix like `cred-mesh.*` or `auth.fabric.*`, (c) rename existing `credentials.*` to something else (invasive).
   - **Recommendation:** the new system should use `cred-mesh.*` or `cred_fabric.*` as its module prefix to avoid collision, and explicitly call out how it relates to (and may eventually subsume) `credentials.*`.
- `cfg/zenki/keys/` — the standalone `keys` zenka is for human key management. The new "detached key-holder child process" is a runtime component, not the same thing. Names should not collide: use `credential.key_holder.child` or similar, not `keys.child`.
- `crypt.C25519.*` namespace is safe to call into. No collision.

### gaps in the task spec

1. **The existing `credentials.*` system is ignored.** There are 14 modules, active storage at `/var/protocol-7/credentials/`, session tokens, and `authorized_zenki` access control. The task spec does not mention whether the new fabric replaces, wraps, or coexists with this system. This is a **blocking architectural question.**
2. **No `var/credential/` directory exists.** The task proposes this path. The existing system uses `/var/protocol-7/credentials/`. If both systems run, they need distinct paths. If the new system replaces the old, migration must be planned.
3. **Twofish is the only symmetric cipher available.** The task says "twofish encryption with C25519 key" for tier 1. This is correct — `AMOS7::Twofish` is available and already used for credential archives. However, the task does not specify the key derivation. The existing pattern uses `AMOS7::13::key_32(\$password)` where password is derived from slot name + instance ID. The fabric needs a derivation scheme for the encryption key.
4. **Detached key-holder child process — pipe protocol is unspecified.** The task says "result passed to owner via pipe." What format? JSON? Protocol-7 SIZE? Base32? The existing child patterns use Protocol-7 sessions over socketpair (letsencr) or raw line protocol (kimi-api child). The fabric needs to define its pipe protocol.
5. **Memory locking and secure erasure patterns are not mentioned.** The existing C25519 code uses `IO::AIO::aio_mlock` and `/usr/bin/shred`. The credential fabric should adopt the same patterns for the key-holder child.
6. **BMW384 content-addressing is mentioned in `PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md` but not in the task.** The task says "stored in tier-1 storage" without specifying the addressing scheme. The design doc says credentials are content-addressed by BMW384. This should be explicit in the task.
7. **`credential.subscribe_rotation` STRM integration is underspecified.** How does a zenka subscribe? Via `protocol-7.route-send`? Via a direct data tree registration? The existing STRM system uses `base.strm.local.register` (as seen in `plugin.httpd.radio.handler.strm_open`). The fabric should specify the STRM registration mechanism.
8. **`credential.request-authorization` auth relay flow needs the web-browser zenka.** The task says "web-browser zenka shows approval dialog." This requires the web-browser zenka to expose a command for showing dialogs and returning user input. Does such a command exist? `web-browser.*` modules are GTK3/WebKit — they likely have dialog primitives, but the exact command name is not specified.
9. **`cfg/zenki/credential/access.zenki` format is unspecified.** The task mentions this file for access control but doesn't define its format. The existing `authorized_zenki` check in `credentials.cmd.request_session` uses a list or hash — the format should match.

### suggested refinements

1. **Resolve the `credential` vs `credentials` naming collision immediately.** Options ranked:
   - **(Recommended)** Use `cred-mesh.*` as the module prefix. e.g., `src/cred-mesh.init_code`, `cred-mesh.resolve`, `cred-mesh.store.local`. This is unambiguous and leaves `credentials.*` untouched during transition.
   - Merge the new modules into `credentials.*` by adding `credentials.fabric.*` sub-modules. This is cleaner long-term but risks breaking the existing SMTP/IMAP session code.
   - Keep `credential.*` (singular) and rename existing `credentials.*` to `legacy.credentials.*`. Highly invasive, not recommended.

2. **Reuse `credentials.read_archive` / `write_archive_file` for tier-1 storage.** The existing Twofish-encrypted archive I/O with randomized offset padding is exactly what tier 1 needs. Wrap it rather than rewrite:
   ```perl
   ## in cred-mesh.store.local:
   my $data = <[credentials.read_archive]>->($slot_name, $encryption_key);
   <[credentials.write_archive_file]>->($slot_name, $data, $encryption_key);
   ```
   The encryption key is derived from the C25519 key-holder child's private key, not from a password.

3. **Use the `letsencr` socketpair+fork pattern for the key-holder child.** It is the most mature child-process IPC pattern in the codebase:
   ```perl
   socketpair(my $child_pipe, my $parent_pipe, AF_UNIX, SOCK_STREAM, PF_UNSPEC);
   <credential.key_holder.child.pid> = <[base.fork]>;
   ## child loads only crypt.C25519 + minimal modules
   ## parent communicates via Protocol-7 commands over the socketpair
   ```
   This gives the child its own memory space, its own module set, and a clean protocol boundary.

4. **Derive the tier-1 encryption key via C25519 DH, not a password.** The design doc says "twofish encryption with C25519 key." The natural implementation:
   - Key-holder child holds the C25519 private key.
   - Fabric generates an ephemeral public key per slot.
   - Shared secret = `Crypt::Curve25519::shared_secret($ephemeral_secret, $child_public)`.
   - Twofish key = `AMOS7::13::key_32(\$shared_secret)`.
   - Ephemeral secret discarded after encryption.
   This matches the session encryption pattern in `protocol.protocol-7.encryption.init`.

5. **Content-address tier-1 storage by BMW384.** Follow the design doc:
   ```perl
   my $addr = AMOS7::Digest::BMW::bmw384($credential_bytes);
   my $b32_addr = encode_b32r($addr);
   ## file path: var/cred-mesh/store/$b32_addr.enc
   ```
   This removes the need for a plaintext filename-to-slot index.

6. **For the auth relay flow, delegate to `web-browser` zenka via `protocol-7.route-send`.** The exact command should be negotiated with the web-browser zenka owner, but the pattern is:
   ```perl
   <[protocol-7.route-send]>->(
       {   'command'   => 'web-browser.dialog.show',
           'call_args' => { 'type' => 'auth_approval', 'domain' => $domain },
           'reply'     => { 'handler' => 'cred-mesh.handler.auth_relay_reply' },
       }
   );
   ```

7. **Add `cred-mesh.handler.rotation_strm` for STRM subscription.** When a credential rotates, the fabric pushes a STRM notification:
   ```perl
   <[base.strm.push]>->('credential.rotated.' . $slot, { slot => $slot, ntime => $ntime });
   ```
   Subscribing zenki use `base.strm.local.register` (same pattern as radio stream consumers).

## refined module list

**Namespace change (critical):**
- All modules renamed from `credential.*` to `cred-mesh.*` to avoid collision with existing `credentials.*` (14 modules).

**Additions:**
- `src/cred-mesh.key_holder.child` — the detached child process that holds the C25519 private key and performs decrypt/sign operations (replaces the underspecified `credential.store.local.key-holder`)
- `src/cred-mesh.key_holder.parent` — parent-side IPC over socketpair, dispatches operations to child
- `src/cred-mesh.encrypt` — encrypt a credential blob using C25519-derived Twofish key (shared secret pattern)
- `src/cred-mesh.decrypt` — decrypt a credential blob
- `src/cred-mesh.handler.rotation_strm` — pushes STRM notifications on rotation

**Removals / merges:**
- `src/credential.store.local.key-holder` → merged into `cred-mesh.key_holder.child` + `cred-mesh.key_holder.parent`
- `src/credential.store.local` → keep but renamed to `cred-mesh.store.local`, and have it delegate encryption/decryption to the key-holder pair rather than doing it inline

**Relationship to existing `credentials.*`:**
- `cred-mesh.store.local` should wrap `credentials.read_archive` / `credentials.write_archive_file` for the actual file I/O, passing the C25519-derived key instead of the old password-derived key.
- `credentials.cmd.request_session` and `credentials.spawn_web_session` remain in use for SMTP/IMAP/web sessions until the fabric subsumes them.

#,,.,,.,.,.,.,,..,,.,,.,.,,.,,.,,,.,.,,,.,,..,..,,...,...,,..,.,.,.,,,...,,,.,
#24XXITLGXE42WOGS6DWXWW2UJDNIMAMIV6F6V2ZEO3ASNL6DFZJTTVA3L6FQ3BQ6UPREKXBBEKCVY
#\\\|KCELENPYSCXEWLXIET2VSOQ6ORCK3OO6P3YYRI5AX5C6EFK7EHH \ / AMOS7 \ YOURUM ::
#\[7]T5PB2B2ZRDJJBFTHJEXGFXEP5EI7XFBOYE3CYMY4EZY5OA5W7GDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
