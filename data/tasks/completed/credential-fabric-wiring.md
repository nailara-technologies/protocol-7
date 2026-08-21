# task: credential fabric — wire proxy + transport + fabric end to end

## dispatch
wire the three infrastructure zenki (credential_fabric, transport, proxy)
into one working request path. read first:
`data/md/design/CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md` (part 1);
`src/proxy.handler.connection`, `src/proxy.handler.request`,
`src/proxy.handler.passthrough_reply`, `src/proxy.auth.lookup`,
`src/proxy.transport.select`;
`src/transport.select`, `src/transport.profile.load`,
`src/transport.handle.direct-tcp`,
`src/transport.handle.hysteria-socks5`,
`src/transport.handle.udt-tunnel`;
`src/credential_fabric.resolve`, `src/credential_fabric.register`,
`src/credential_fabric.handler.rotation_strm`,
`src/credential_fabric.request-authorization`,
`src/credential_fabric.handler.auth-relay-reply`.
do NOT touch signatures, code-style, or unrelated logic. lowercase comments,
`[ word ]` bracket annotations.

## problem
the three zenki each register their interfaces, and the proxy already calls
through `proxy.auth.lookup` (→ `credential_fabric.resolve`) and
`proxy.transport.select` (→ `transport.select`), but:

1. **the outbound socket bypasses the transport handle.** `proxy.handler.
   passthrough_reply` and the connect-tunnel path use `clients.http.request`
   (or open their own socket) without consulting the handle returned by
   `transport.select`. selecting a transport currently does nothing.
2. **no slot is ever registered** on a fresh install. the registry is
   loaded from `var/credential_fabric/registry.yaml` which does not exist
   until something calls `credential_fabric.register` — and nothing does.
3. **per-transport credential refs are not resolved.** transport profile
   entries declare `credential: <slot>` (e.g. `atom.udt-psk`) but neither
   `transport.handle.udt-tunnel` nor `transport.handle.hysteria-socks5`
   calls `credential_fabric.resolve` before connecting. the field is read
   and ignored.
4. **rotation invalidation has no subscribers.** the fabric pushes
   `credential.rotated.<slot>` via `credential_fabric.handler.rotation_strm`
   but neither the proxy template selector cache nor the transport profile
   cache subscribes.
5. **the auth-relay flow targets a non-existent module.** `credential_
   fabric.request-authorization` currently routes to `web-browser.
   dialog.show` which does not exist. the working surface already
   shipped in `protocol-7-menu.cmd.input-text` and `protocol-7-menu.cmd.
   input-password` — styled gtk3 modal dialogs gated behind
   `<protocol-7-menu.init-graphical>`. read these two modules before
   editing the relay path. they have not previously been invoked
   cross-zenka so cube routing of the `cmd.*` namespace is unconfirmed
   for this caller.

## changes

### 1. new helper module — `src/proxy.outbound.connect_or_use`
single entry point used by every outbound path in the proxy. receives the
proxy's request context hash. checks `context.transport.handle` (set by
`proxy.handler.request` after calling `proxy.transport.select`). if present
and the handle exposes a connected socket, returns it directly. if not,
falls back to opening a direct tcp socket tagged with
`type='direct-tcp-fallback'`. returns a hashref:
```perl
{ socket => $sock, type => $tag, transport => $handle_or_undef }
```
update `proxy.handler.passthrough_reply` and the connect-tunnel path in
`proxy.handler.connection` (and any other call site in `proxy.handler.*`)
to call this helper instead of opening their own socket. **do not change**
the `clients.http.*` modules — keep the helper as the proxy-side adapter.

### 2. seed the registry from a yaml file
add `src/credential_fabric.seed_registry` called once at end of
`credential_fabric.init_code` (only on first init, guarded by
`<credential_fabric.seed.loaded>`). reads `var/credential_fabric/seed.yaml`
if present and calls `credential_fabric.register` once per entry. yaml
shape:
```yaml
slots:
  - slot:        openweathermap.api-key
    owner:       weather
    type:        api-key
    sensitivity: low
    storage:     local
  - slot:        atom.udt-psk
    owner:       transport
    type:        psk
    sensitivity: high
    storage:     local
```
also ship a checked-in example `cfg/zenki/credential_fabric/
seed.yaml.example` documenting the format. the live file at
`var/credential_fabric/seed.yaml` stays operator-controlled; do not
commit it.

### 3. resolve credential refs in transport handles
in `transport.handle.direct-tcp` no change is needed (credential is `~`).

in `transport.handle.hysteria-socks5` and `transport.handle.udt-tunnel`,
before the connect/handshake step, if the profile entry carries a
`credential:` field, call `credential_fabric.resolve` synchronously. on
`{ mode => 'true', data => $auth }` use the `data` payload according to
type — `psk` for udt, `bearer-token` for hysteria. on undef or
`{ mode => 'false' }` log and return a transport-error result so the
selector demotes the entry.

the auth payload itself stays inside the handle module — do not leak it
into the context hash. only the success/failure outcome propagates.

### 4. rotation subscribers
two thin handlers — `src/proxy.handler.cred_rotated` and
`src/transport.handler.cred_rotated`. each registers as a strm
consumer for `credential.rotated.*` via the same pattern radio uses
(`base.strm.local.register`). on event, walks the local cache (proxy
template selector cache, transport profile + handle cache) and removes
entries that referenced the rotated slot.

register in each zenka's `init_code` once, after the relevant cache has
been initialised. confirm `credential_fabric.handler.rotation_strm`
publishes on the channel name `credential.rotated.<slot>` and not a
generic channel; if it does not, fix it there (one-line change).

### 5. auth-relay surface — gtk primary, console fallback

edit `credential_fabric.request-authorization` to route to the
existing `protocol-7-menu` gtk dialog as the primary path:

```perl
## pick dialog type by credential sensitivity / kind
my $dialog_cmd = $high_sensitivity
    ? 'protocol-7-menu.cmd.input-password'
    : 'protocol-7-menu.cmd.input-text';

<[protocol-7.route-send]>->(
    {   'command'   => $dialog_cmd,
        'call_args' => { 'args' => "authorize: $domain" },
        'reply'     => {
            'handler' => 'credential_fabric.handler.auth-relay-reply',
            'params'  => { 'req_id' => $req_id },
        },
    }
);
```

confirm the cube `command` field encoding for `cmd.*` modules during
implementation — no existing zenka invokes `protocol-7-menu.cmd.input-*`
cross-zenka, so this is new territory. likely the command string is
exactly `protocol-7-menu.cmd.input-password` (matching the `# name =`
header in the module). if cube strips the `cmd.` segment by convention
elsewhere, mirror that convention here.

edit `credential_fabric.handler.auth-relay-reply` to branch on the
reply mode:

```
reply.mode == 'true'  → reply.data is the payload typed by user
                        → call existing approval-completion path
                        → clear pending entry
reply.mode == 'false' && reply.data =~ /graphical mode not enabled/
                      → headless: kick off console fallback (below)
reply.mode == 'false' && reply.data eq 'input cancelled'
                      → user dismissed the dialog: propagate failure,
                        clear pending entry, log at level 1
```

**console fallback** (only when graphical mode not enabled):
- write pending entry to `<credential_fabric.auth_relay_pending>->{$req_id}`
  (already done) plus append to file `var/credential_fabric/relay_
  pending.yaml` so external tooling sees the queue
- emit one log line at level 0:
  `auth relay pending [req_id] domain=$domain — approve with: p7c credential_fabric.approve $req_id <payload>`
- when the proxy zenka observes a pending-mode reply for the same
  request id (from the original `proxy.auth.lookup` async path), the
  proxy emits a 407 with the req_id in the body for clients that can
  surface it

add a new command module `src/credential_fabric.cmd.approve` taking
`{ req_id => '...', payload => '...' }`. looks up the pending entry,
calls the existing approval-completion path with a synthesised reply
matching what the dialog would have returned. on success, clears the
pending entry and the file row.

[ note: a single console approve path is reused for both fallback
  scenarios — direct console-only operation and post-cancellation
  recovery. the gtk surface is preferred whenever available. ]

### 6. transport handle in context
in `proxy.handler.request`, after `proxy.transport.select` succeeds,
copy the chosen handle into `context.transport.handle` (a reference,
not a deep copy). currently `context.transport` is set up with stubs
only (`type='direct'`, `quality=1.0`). the existing stub fields stay;
add `handle` next to them. that field is what `proxy.outbound.
connect_or_use` reads in step 1.

## configuration changes

add to `cfg/zenki/credential_fabric/zenka.v7` (create if absent):
- load `credential_fabric` modules
- run `credential_fabric.init_code` (which now seeds the registry)
- on-demand zenka, no idle timeout (already required by design)

add to `cfg/zenki/proxy/zenka.v7`:
- load `proxy.outbound.connect_or_use` alongside other proxy modules

verify `cfg/zenki/cube/access.zenki` allows:
- proxy → credential_fabric.resolve, credential_fabric.request-authorization
- transport → credential_fabric.resolve
- credential_fabric → protocol-7-menu.cmd.input-text, protocol-7-menu.cmd.input-password
- credential_fabric → proxy.handler.cred_rotated (strm push)
- credential_fabric → transport.handler.cred_rotated (strm push)

note: the credential_fabric → protocol-7-menu edges are new — no other
zenka has needed them. confirm the access.zenki entry format for the
`cmd.*` suffix (some entries omit it, some include it — match whatever
the existing format requires for cube to route the call).

## harmony checks
```
harmony proxy.outbound.connect_or_use
harmony proxy.handler.cred_rotated
harmony transport.handler.cred_rotated
harmony credential_fabric.seed_registry
harmony credential_fabric.cmd.approve
```

re-run harmony on touched modules (`proxy.handler.connection`,
`proxy.handler.request`, `proxy.handler.passthrough_reply`,
`transport.handle.hysteria-socks5`, `transport.handle.udt-tunnel`,
`credential_fabric.request-authorization`, `credential_fabric.init_code`).

## acceptance
- proxy started against a fresh `var/` with a seed.yaml registering a
  test api-key slot. `p7c credential_fabric.list` (or equivalent
  query) shows the seeded slots.
- proxy intercepts a GET; the chosen transport handle's socket is the
  outbound socket. confirm via debug log in `proxy.outbound.connect_or_use`.
- proxy intercepts a GET to a domain with a seeded `session.$domain`
  slot. injected header reaches the upstream server (use httpbin
  echo or a local listener to verify).
- forced rotation via `p7c credential_fabric.rotate
  openweathermap.api-key` results in both proxy and transport cache
  log entries showing flush.
- on-demand auth: hit a domain with no slot, observe 407 (or pending
  log line), call `p7c credential_fabric.approve <req_id> <payload>`,
  retry original request, succeed.

## signatures note
do not modify or regenerate any AMOS7 signature lines. the signing
system handles all footer blocks — leave them untouched. **do not add
the `#,,..` stub line** to new files — the signing system writes it.

#,,..,...,,,.,.,,,,,,..,,...,..,,,,,,,,.,,,,,..,,...,..,,,,,,...,,...,,..,...,

#,,..,.,.,...,...,.,.,,,,,,,,,...,,..,,.,,,.,,..,,...,...,,,.,...,,,.,..,,...,
#BOSGQYVNA6PHXZROEIYFBNLNG6FA575AQK32OTWDSANKISEEGVPTERC2VBOATJUREPLLSGMTMIWTE
#\\\|GAFY2NVKHQMEO5UR63GR2HTCU5BHGCOOICGBMSXKXKIWVSLCSJV \ / AMOS7 \ YOURUM ::
#\[7]TL6NCGMQYNHGQMNANB6IIAC6645NO6RTR7AQ4HAHENBPYU54D2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
